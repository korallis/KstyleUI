"""Generate, judge, bake and verify the Medallions art: a painted bust and badge for every race, class and sex, and a
painted crest for every race and class.

Usage (run with a Python that has Pillow, such as ~/.local/share/wow-dev/venv/bin/python; plan, status and verify
need none):
    medallions.py plan      [--kind bust|badge|crest] [--keys KEY ...] [--json]
    medallions.py anchors
    medallions.py generate  --kind bust|badge|crest --max-credits N [--keys KEY ... | --all] [--jobs 8] [--dry-run]
    medallions.py judge     [--kind ...] [--keys ...]
    medallions.py accept    KIND KEY [--attempt N] --note TEXT
    medallions.py reject    KIND KEY --note TEXT
    medallions.py adopt     KIND KEY --job JOB_ID --image PATH --prompt-file FILE [--reference JOB_ID ...] [--date D]
    medallions.py bake      [--kind ...] [--keys ...]
    medallions.py sheets    --out DIR [--kind ...] [--keys ...]
    medallions.py status
    medallions.py verify    [--complete]

docs/medallions.md has the design. In short: keys are the game's race file, class file and sex, lowercased
(nightelf_priest_female, troll_shaman), and tables.py holds the prompts table. Every generation references a locked
anchor (anchors.json, with 512 px copies in anchors/): busts the portrait anchor, badges their own bust and the badge
style anchor, crest edits their race master. Raw 1024 px images and one JSON record per asset live outside the
repository, in ~/.local/share/wow-dev/medallions/raw (MEDALLIONS_RAW overrides it), so a rerun skips finished work.

generate runs the Higgsfield CLI up to --jobs at a time, judges each image (imaging.py) and rerolls a rejected one
with the same prompt, at most three images per asset. It never spends more than --max-credits in one run, and reads
the balance before and after. accept and reject record a decision made by eye on a contact sheet; reject makes the
next generate reroll. adopt records an image another thread generated, with its job and prompt, as a new attempt.

bake writes every accepted asset at its shipped size into Media/Textures/Medallions (busts 128 px, badges 64 px,
crests and their glow and metal masks 256 px), then writes Tools/medallions/manifest.json, the Medallions section of
Media/PROVENANCE.md and Core/MedallionAssets.lua from it. verify checks all of that; Tools/tests/test_medallions.py
runs it, and --complete also requires every combination.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import tables  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
HERE = REPO / "Tools" / "medallions"
ANCHORS = HERE / "anchors.json"
MANIFEST = HERE / "manifest.json"
MEDIA = "Media/Textures/Medallions"
PROVENANCE = "Media/PROVENANCE.md"
LUA = "Core/MedallionAssets.lua"
RAW = Path(os.environ.get("MEDALLIONS_RAW", Path.home() / ".local" / "share" / "wow-dev" / "medallions" / "raw"))

MODEL = "gpt_image_2_6"
KINDS = ("bust", "badge", "crest")
SETTINGS = {
    "bust": {"aspect_ratio": "1:1", "resolution": "1k", "quality": "high"},
    "badge": {"aspect_ratio": "1:1", "resolution": "1k", "quality": "high"},
    "crest": {"aspect_ratio": "1:1", "resolution": "1k", "quality": "xhigh", "background": "transparent"},
}
COST = {"bust": 1.5, "badge": 1.5, "crest": 2.5}  # credits, from Higgsfield's cost preflight for these settings
SIZES = {"bust": 128, "badge": 64, "crest": 256}
FOLDERS = {"bust": "Busts", "badge": "Badges", "crest": "Crests"}
MASKS = ("glow", "metal")
MAX_IMAGES = 3
MAX_FAILURES = 2
MAX_JOBS = 12
DEFAULT_JOBS = 8  # the Higgsfield plus plan runs at most 8 jobs at once
RATE_LIMIT_WAIT = 15
RATE_LIMIT_TRIES = 40
ANCHOR_COPY = 512
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BEGIN = "<!-- medallions:begin (written by Tools/medallions/medallions.py bake) -->"
END = "<!-- medallions:end -->"


class GenerationError(RuntimeError):
    pass


class RateLimited(GenerationError):
    pass


def today():
    return datetime.date.today().isoformat()


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def text_sha256(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_json(path, default):
    path = Path(path)
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def save_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    tmp.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def keys_for(kind):
    return tables.crest_keys() if kind == "crest" else tables.portrait_keys()


# Records -----------------------------------------------------------------------------------------------------------

def record_path(raw, kind, key):
    return Path(raw) / kind / f"{key}.json"


def load_record(raw, kind, key):
    return load_json(record_path(raw, kind, key), {"kind": kind, "key": key, "attempts": []})


def save_record(raw, record):
    save_json(record_path(raw, record["kind"], record["key"]), record)


def accepted(record):
    """The attempt that ships: the latest accepted one."""
    for attempt in reversed(record["attempts"]):
        if attempt["verdict"] == "accepted":
            return attempt
    return None


def next_step(record):
    if accepted(record) is not None:
        return "done"
    tries = record["attempts"][record.get("rerollFrom", 0):]
    images = [a for a in tries if "image" in a]
    if len(images) >= MAX_IMAGES or len(tries) - len(images) >= MAX_FAILURES:
        return "exhausted"
    return "generate"


# Anchors and references --------------------------------------------------------------------------------------------

def anchor_copy(anchor, here=HERE):
    return Path(here) / anchor["copy"]


def master_anchor(anchors, race):
    return anchors["crests"].get(race)


def is_locked_master(anchors, key):
    return tables.is_master(key) and master_anchor(anchors, tables.split_key(key)[0]) is not None


def references_for(kind, key, anchors, raw):
    """Job ids the generation references, in prompt order. None while a prerequisite is not accepted."""
    if kind == "bust":
        return [anchors["portrait"]["job"]]
    if kind == "badge":
        bust = accepted(load_record(raw, "bust", key))
        return None if bust is None else [bust["job"], anchors["badge"]["job"]]
    race, _, _ = tables.split_key(key)
    if tables.is_master(key):
        return [anchors["crestStyle"]["job"]]
    master = master_anchor(anchors, race)
    return None if master is None else [master["job"]]


def prompt_for(kind, key):
    race, cls, sex = tables.split_key(key)
    if kind == "bust":
        return tables.bust_prompt(race, cls, sex)
    if kind == "badge":
        return tables.BADGE_PROMPT
    return tables.crest_prompt(race, cls)


def plan(kind, keys, anchors, raw):
    return [{"kind": kind, "key": key, "model": MODEL, "settings": SETTINGS[kind], "cost": COST[kind],
             "prompt": prompt_for(kind, key), "references": references_for(kind, key, anchors, raw),
             "step": "anchor" if kind == "crest" and is_locked_master(anchors, key)
             else next_step(load_record(raw, kind, key)),
             "file": shipped_path(kind, key)} for key in keys]


# Judging -----------------------------------------------------------------------------------------------------------

def make_judge(kind, key, anchors, raw, here=HERE):
    """A function from an image path to (metrics, reasons) for this asset, measured against the committed anchor
    copies (a badge against its own accepted bust)."""
    import imaging
    from PIL import Image

    if kind == "bust":
        reference = imaging.portrait_metrics(Image.open(anchor_copy(anchors["portrait"], here)))
        return lambda path: imaging.judge_portrait(Image.open(path), reference)
    if kind == "badge":
        bust = accepted(load_record(raw, "bust", key))
        if bust is None:
            raise GenerationError(f"badge {key}: its bust is not accepted")
        reference = imaging.portrait_metrics(Image.open(Path(raw) / "bust" / bust["image"]))
        return lambda path: imaging.judge_portrait(Image.open(path), reference, badge=True)
    race, cls, _ = tables.split_key(key)
    master = None if tables.is_master(key) else Image.open(anchor_copy(master_anchor(anchors, race), here))
    return lambda path: imaging.judge_crest(Image.open(path), tables.GLOW_HUES[cls], master)


# Credits -----------------------------------------------------------------------------------------------------------

class Budget:
    """Lets a job start only while this run's spend stays within its cap. A job that ends without an image still
    counts as spent, since the account may have charged it."""

    def __init__(self, cap, log=print):
        self.cap, self.log = float(cap), log
        self.spent = 0.0
        self.stopped = False
        self._lock = threading.Lock()

    def reserve(self, cost):
        with self._lock:
            if self.stopped or self.spent + cost > self.cap + 1e-9:
                if not self.stopped:
                    self.log(f"credits: stopping at this run's cap of {self.cap:g} ({self.spent:g} spent)")
                self.stopped = True
                return False
            self.spent += cost
            return True

    def release(self, cost):
        with self._lock:
            self.spent -= cost


# Generation --------------------------------------------------------------------------------------------------------

def _start_job(runner, kind, prompt, references, budget, sleep):
    for _ in range(RATE_LIMIT_TRIES):
        if not budget.reserve(COST[kind]):
            return None
        try:
            return runner(kind, prompt, references)
        except RateLimited:
            budget.release(COST[kind])
            sleep(RATE_LIMIT_WAIT)
    raise GenerationError(f"still rate limited after {RATE_LIMIT_TRIES} tries")


def _attempt(kind, key, raw, anchors, runner, fetch, judge_for, budget, log, sleep):
    record = load_record(raw, kind, key)
    while next_step(record) == "generate":
        refs = references_for(kind, key, anchors, raw)
        if refs is None:
            log(f"{kind} {key}: skipped, its reference is not accepted yet")
            return record
        n = len(record["attempts"]) + 1
        prompt = prompt_for(kind, key)
        attempt = {"n": n, "model": MODEL, "settings": SETTINGS[kind], "prompt": prompt, "references": refs,
                   "date": today()}
        try:
            job = _start_job(runner, kind, prompt, refs, budget, sleep)
        except GenerationError as error:
            job = None
            attempt.update(verdict="failed", error=str(error))
        if job is None and "error" not in attempt:
            return record
        if job is not None:
            image = f"{key}-{n}.png"
            path = Path(raw) / kind / image
            attempt.update(job=job["id"], url=job["url"])
            try:
                fetch(job["url"], path)
                metrics, reasons = judge_for(key)(path)
                attempt.update(image=image, rawSha256=sha256(path), metrics=metrics, reasons=reasons,
                               verdict="rejected" if reasons else "accepted", by="script")
            except (GenerationError, OSError, ValueError) as error:
                attempt.update(verdict="failed", error=str(error))
        record["attempts"].append(attempt)
        save_record(raw, record)
        detail = attempt.get("error") or ", ".join(attempt.get("reasons", [])) or "ok"
        log(f"{kind} {key}: attempt {n} {attempt['verdict']} ({detail})")
    return record


def generate(kind, keys, raw, anchors, *, runner, fetch, judge_for, budget, jobs=DEFAULT_JOBS, log=print,
             sleep=time.sleep):
    """Generate every listed asset that is not finished, at most jobs at a time; returns {key: step} afterwards.
    A locked race master is never generated."""
    todo = [key for key in keys if not (kind == "crest" and is_locked_master(anchors, key))
            and next_step(load_record(raw, kind, key)) == "generate"]
    (Path(raw) / kind).mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, min(MAX_JOBS, jobs))) as pool:
        futures = [pool.submit(_attempt, kind, key, raw, anchors, runner, fetch, judge_for, budget, log, sleep)
                   for key in todo]
        try:
            for future in futures:
                future.result()
        except BaseException:
            budget.stopped = True
            for future in futures:
                future.cancel()
            raise
    return {key: next_step(load_record(raw, kind, key)) for key in keys}


def _higgsfield(*args, timeout=900):
    result = subprocess.run(["higgsfield", *args], capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        if "rate_limit" in result.stderr:
            raise RateLimited("rate_limit_reached")
        raise GenerationError(f"higgsfield {' '.join(args[:2])} failed: {result.stderr.strip()[-300:]}")
    return json.loads(result.stdout)


def account_balance():
    return float(_higgsfield("account", "status", "--json", timeout=60)["credits"])


def higgsfield_runner(kind, prompt, references):
    command = ["generate", "create", MODEL, "--prompt", prompt]
    for name, value in SETTINGS[kind].items():
        command += [f"--{name}", value]
    for ref in references:
        command += ["--image-references", ref]
    try:
        jobs = _higgsfield(*command, "--wait", "--json")
    except subprocess.TimeoutExpired as error:
        raise GenerationError("timed out waiting for the job") from error
    job = jobs[0] if isinstance(jobs, list) and jobs else jobs if isinstance(jobs, dict) else {}
    if job.get("status") != "completed" or not job.get("result_url"):
        raise GenerationError(f"job {job.get('id')} ended {job.get('status')}")
    return {"id": job["id"], "url": job["result_url"]}


def download(url, path):
    if not url.startswith("https://"):
        raise GenerationError(f"refusing a non-https result URL: {url}")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    try:
        with urllib.request.urlopen(url, timeout=120) as response, open(tmp, "wb") as handle:
            handle.write(response.read())
    except OSError as error:
        raise GenerationError(f"download failed: {error}") from error
    if not tmp.read_bytes().startswith(PNG_SIGNATURE):
        tmp.unlink()
        raise GenerationError(f"not a PNG: {url}")
    os.replace(tmp, path)


# By-eye decisions and adoption -------------------------------------------------------------------------------------

def accept_by_eye(raw, kind, key, note, attempt=None):
    record = load_record(raw, kind, key)
    images = [a for a in record["attempts"] if "image" in a]
    chosen = next((a for a in images if a["n"] == attempt), None) if attempt else (images[-1] if images else None)
    if chosen is None:
        raise SystemExit(f"{kind} {key}: no such image")
    for other in images:
        if other is not chosen and other["verdict"] == "accepted":
            other.update(verdict="rejected", reasons=[f"superseded by attempt {chosen['n']}"], by="eye")
    chosen.update(overruled=chosen.get("reasons", []), reasons=[], verdict="accepted", by="eye", note=note,
                  reviewed=today())
    save_record(raw, record)
    return chosen


def reject_by_eye(raw, kind, key, note):
    record = load_record(raw, kind, key)
    chosen = accepted(record)
    if chosen is None:
        raise SystemExit(f"{kind} {key}: nothing accepted to reject")
    chosen.update(verdict="rejected", reasons=[f"rejected by eye: {note}"], by="eye", reviewed=today())
    record["rerollFrom"] = len(record["attempts"])
    save_record(raw, record)
    return chosen


def adopt(raw, kind, key, job, image, prompt, references, date, url="", judge=None):
    """Record an image generated elsewhere as a new attempt, judged like any other; without a judge it is a locked
    anchor and is accepted as one."""
    record = load_record(raw, kind, key)
    n = len(record["attempts"]) + 1
    name = f"{key}-{n}.png"
    target = Path(raw) / kind / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(Path(image).read_bytes())
    attempt = {"n": n, "model": MODEL, "settings": SETTINGS[kind], "prompt": prompt, "references": references,
               "date": date, "job": job, "url": url, "image": name, "rawSha256": sha256(target), "adopted": True}
    if judge is None:
        attempt.update(metrics={}, reasons=[], verdict="accepted", by="anchor")
    else:
        metrics, reasons = judge(target)
        attempt.update(metrics=metrics, reasons=reasons, verdict="rejected" if reasons else "accepted", by="script")
    record["attempts"].append(attempt)
    save_record(raw, record)
    return attempt


def anchor_items(anchors):
    items = [("portrait", anchors["portrait"]), ("badge", anchors["badge"])]
    return items + [(f"crest {race}", anchors["crests"][race]) for race in tables.RACES if race in anchors["crests"]]


def fetch_anchors(anchors, raw, fetch=download, here=HERE, log=print):
    """Put every locked anchor's original into the raw store, checked against its SHA-256, and write its 512 px copy
    beside anchors.json. Crest race masters become accepted crests; nothing is generated and nothing is spent."""
    import imaging
    from PIL import Image

    for label, anchor in anchor_items(anchors):
        original = Path(raw) / "anchors" / f"{anchor['job']}.png"
        if not original.exists():
            fetch(anchor["url"], original)
        if sha256(original) != anchor["sha256"]:
            raise SystemExit(f"anchor {label}: {original} does not match its SHA-256 in anchors.json")
        copy = anchor_copy(anchor, here)
        if not copy.exists():
            copy.parent.mkdir(parents=True, exist_ok=True)
            image = Image.open(original).convert("RGBA")
            small = imaging.resize_linear(image, (ANCHOR_COPY, ANCHOR_COPY), sharpen=False)
            (small if label.startswith("crest") else small.convert("RGB")).save(copy, optimize=True)
        if label.startswith("crest") and accepted(load_record(raw, "crest", anchor["key"])) is None:
            adopt(raw, "crest", anchor["key"], anchor["job"], original, anchor["prompt"], anchor["references"],
                  anchor["date"], url=anchor["url"])
        log(f"anchor {label}: {anchor['key']} ok")


# Bake --------------------------------------------------------------------------------------------------------------

def shipped_path(kind, key, mask=None):
    return f"{MEDIA}/{FOLDERS[kind]}/{key}{'_' + mask if mask else ''}.png"


def bake(raw, kinds, keys=None, repo=REPO, log=print):
    """Write every accepted asset at its shipped size; returns the manifest entries for the files written."""
    import imaging
    from PIL import Image

    entries = []
    for kind in kinds:
        for key in keys or keys_for(kind):
            attempt = accepted(load_record(raw, kind, key))
            if attempt is None:
                continue
            source = Image.open(Path(raw) / kind / attempt["image"])
            out = imaging.bake_crest(source, SIZES[kind]) if kind == "crest" else imaging.bake_portrait(source, SIZES[kind])
            files = [(shipped_path(kind, key), out)]
            if kind == "crest":
                files += list(zip((shipped_path(kind, key, m) for m in MASKS), imaging.crest_masks(out)))
            for rel, image in files:
                target = Path(repo) / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                image.save(target, optimize=True)
            main_file = files[0][0]
            entries.append({
                "file": main_file, "kind": kind, "key": key, "size": SIZES[kind], "sha256": sha256(Path(repo) / main_file),
                "job": attempt["job"], "url": attempt.get("url", ""), "model": attempt["model"],
                "settings": attempt["settings"], "references": attempt["references"], "prompt": attempt["prompt"],
                "promptSha256": text_sha256(attempt["prompt"]), "rawSha256": attempt["rawSha256"],
                "date": attempt["date"], "anchor": attempt.get("by") == "anchor",
                "judge": {"by": attempt.get("by", "script"), "metrics": attempt.get("metrics", {}),
                          "overruled": attempt.get("overruled", []), "note": attempt.get("note", "")}})
            for (rel, _), mask in zip(files[1:], MASKS):
                entries.append({"file": rel, "kind": f"crest_{mask}", "key": key, "size": SIZES[kind],
                                "sha256": sha256(Path(repo) / rel), "derivedFrom": main_file})
            log(f"{kind} {key}: baked {', '.join(rel for rel, _ in files)}")
    return entries


def merge_manifest(old, new):
    keep = {e["file"]: e for e in old}
    keep.update({e["file"]: e for e in new})
    return [keep[f] for f in sorted(keep)]


def _cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


WHAT = {"bust": "Painted bust portrait, pre-circled, with a procedural 1 px dark rim",
        "badge": "Flat badge cut of the bust for small frames, pre-circled, with a procedural 1 px dark rim",
        "crest": "Painted race and class crest with a procedural 1 px dark outline",
        "crest_glow": "The crest's glow mask (bright, saturated enamel and gems), white with the mask in alpha",
        "crest_metal": "The crest's metal mask (bright, unsaturated metal) for the sheen, white with the mask in alpha"}


def render_provenance(entries):
    lines = [BEGIN, "", "## Medallions (KSTY-89, 2026-11-15)", "",
             "The Medallions HUD style's portraits and crests. Each is original art generated with Higgsfield from an "
             "original prompt in `Tools/medallions/tables.py`, referenced only to this project's own locked anchors "
             "(`Tools/medallions/anchors.json`), then judged, cleaned and baked by `Tools/medallions/medallions.py`: "
             "a linear-light Lanczos reduction to the shipped size, an alpha cut, and every 1 px edge drawn "
             "procedurally at the shipped size. No other addon's image and no game file is an input. The full prompt, "
             "settings, references and judge measurements of every file are in `Tools/medallions/manifest.json`; "
             "this table gives the first 16 hex digits of each prompt's SHA-256.", "",
             "| File | Size | What it is | Made with | Job | Prompt SHA-256 | Date |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    by_file = {e["file"]: e for e in entries}
    for e in entries:
        source = by_file.get(e.get("derivedFrom"), e)
        if "derivedFrom" in e:
            made = f"Derived from `{e['derivedFrom']}` by `Tools/medallions/imaging.py`, no model"
        else:
            settings = ", ".join(f"{k} {v}" for k, v in sorted(e["settings"].items()))
            refs = ", ".join(f"`{r}`" for r in e["references"]) or "none"
            judged = "locked anchor" if e.get("anchor") else f"judged by {e['judge']['by']}"
            made = f"Higgsfield `{e['model']}` ({settings}), references {refs}; {judged}"
        lines.append(f"| `{e['file']}` | {e['size']}x{e['size']} | {_cell(WHAT[e['kind']])} | {_cell(made)} | "
                     f"`{source['job']}` | `{source['promptSha256'][:16]}` | {source['date']} |")
    lines += ["", END]
    return "\n".join(lines)


def write_provenance(entries, repo=REPO):
    path = Path(repo) / PROVENANCE
    text = path.read_text(encoding="utf-8")
    section = render_provenance(entries)
    if BEGIN in text:
        text = text[:text.index(BEGIN)] + section + text[text.index(END) + len(END):]
    else:
        text = text.rstrip("\n") + "\n\n" + section + "\n"
    path.write_text(text, encoding="utf-8")


def render_lua(entries):
    """Core/MedallionAssets.lua: ASCII with CRLF endings, as every addon file is."""
    portraits, crests = {}, {}
    for e in entries:
        race, cls, sex = tables.split_key(e["key"])
        if e["kind"] in ("bust", "badge"):
            portraits.setdefault(race, {}).setdefault(cls, {}).setdefault(sex, {})[e["kind"]] = e["file"]
        else:
            crests.setdefault(race, {}).setdefault(cls, {})[e["kind"].replace("crest_", "")] = e["file"]

    def path(rel):
        return 'DIR .. "' + rel[len(MEDIA) + 1:].replace("/", "\\\\") + '"'

    lines = ["-- MedallionAssets.lua: the Medallions portrait and crest files, written by Tools/medallions/medallions.py "
             "bake.", "local _, ns = ...", "",
             'local DIR = "Interface\\\\AddOns\\\\KstyleUI\\\\Media\\\\Textures\\\\Medallions\\\\"', "",
             "ns.MedallionAssets = {", "\tportraits = {"]
    for race in (r for r in tables.RACES if r in portraits):
        lines.append(f"\t\t{tables.RACE_FILES[race]} = {{")
        for cls in (c for c in tables.CLASSES if c in portraits[race]):
            lines.append(f"\t\t\t{cls.upper()} = {{")
            for sex in (s for s in tables.SEXES if s in portraits[race][cls]):
                parts = ", ".join(f"{k} = {path(v)}" for k, v in sorted(portraits[race][cls][sex].items()))
                lines.append(f"\t\t\t\t[{tables.UNIT_SEX[sex]}] = {{ {parts} }},")
            lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines += ["\t},", "\tcrests = {"]
    for race in (r for r in tables.RACES if r in crests):
        lines.append(f"\t\t{tables.RACE_FILES[race]} = {{")
        for cls in (c for c in tables.CLASSES if c in crests[race]):
            parts = ", ".join(f"{k} = {path(crests[race][cls][k])}" for k in ("crest", *MASKS) if k in crests[race][cls])
            lines.append(f"\t\t\t{cls.upper()} = {{ {parts} }},")
        lines.append("\t\t},")
    lines += ["\t},", "}", ""]
    return "\r\n".join(lines)


# Contact sheets ----------------------------------------------------------------------------------------------------

SHEET_SIZES = {"bust": (128, 64, 48, 32), "badge": (64, 47, 32, 24, 18), "crest": (256, 157, 118, 64)}


def contact_sheets(raw, kinds, keys, out_dir, log=print):
    """One sheet per kind: every image of the listed assets baked at the sizes it is shown at, with its verdict."""
    import imaging
    from PIL import Image

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for kind in kinds:
        bake_one = imaging.bake_crest if kind == "crest" else imaging.bake_portrait
        rows = []
        for key in keys or keys_for(kind):
            for attempt in (a for a in load_record(raw, kind, key)["attempts"] if "image" in a):
                image = Image.open(Path(raw) / kind / attempt["image"])
                label = f"{key} #{attempt['n']} {attempt['verdict']}"
                if attempt.get("reasons"):
                    label += ": " + "; ".join(attempt["reasons"])[:70]
                rows.append((label, [bake_one(image, s) for s in SHEET_SIZES[kind]]))
        if rows:
            path = out_dir / f"sheet-{kind}.png"
            imaging.contact_sheet(rows, SHEET_SIZES[kind], f"Medallions {kind}s, baked at the sizes they are shown at").save(path)
            written.append(path)
            log(f"wrote {path}")
    return written


# Verify ------------------------------------------------------------------------------------------------------------

def png_size(path):
    data = Path(path).read_bytes()[:24]
    if not data.startswith(PNG_SIGNATURE):
        return None
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def verify(repo=REPO, complete=False):
    """Problems with the Medallions files, the manifest, PROVENANCE, the Lua table and the anchors; [] when clean."""
    repo = Path(repo)
    here = repo / "Tools" / "medallions"
    problems = []
    entries = load_json(here / "manifest.json", [])
    anchors = load_json(here / "anchors.json", {})
    listed = {e["file"] for e in entries}
    media = repo / MEDIA
    on_disk = {p.relative_to(repo).as_posix() for p in media.rglob("*") if p.is_file()} if media.exists() else set()
    problems += [f"{f} has no manifest entry" for f in sorted(on_disk - listed)]
    problems += [f"the manifest lists {f}, which is missing" for f in sorted(listed - on_disk)]
    for e in entries:
        try:
            tables.split_key(e["key"])
        except ValueError as error:
            problems.append(f"{e['file']}: {error}")
            continue
        kind, mask = (("crest", e["kind"][6:]) if e["kind"].startswith("crest_") else (e["kind"], None))
        if e["file"] != shipped_path(kind, e["key"], mask):
            problems.append(f"{e['file']}: should be named {shipped_path(kind, e['key'], mask)}")
        path = repo / e["file"]
        if path.exists():
            size, want = png_size(path), SIZES[kind]
            if size != (want, want):
                problems.append(f"{e['file']}: {size} is not {want}x{want}")
            if want & (want - 1):
                problems.append(f"{e['file']}: {want} is not a power of two")
            if sha256(path) != e["sha256"]:
                problems.append(f"{e['file']}: SHA-256 differs from the manifest (run medallions.py bake)")
        if "derivedFrom" in e:
            if e["derivedFrom"] not in listed:
                problems.append(f"{e['file']}: derived from {e['derivedFrom']}, which the manifest does not list")
            continue
        if text_sha256(e["prompt"]) != e["promptSha256"]:
            problems.append(f"{e['file']}: its prompt SHA-256 does not match its prompt")
        if not e.get("job"):
            problems.append(f"{e['file']}: no Higgsfield job")
        if e["judge"]["by"] == "script" and e["judge"].get("overruled"):
            problems.append(f"{e['file']}: judged by script but has overruled reasons")
        if not e.get("anchor"):
            low = e["prompt"].lower()
            problems += [f"{e['file']}: its prompt names '{w}'" for w in tables.BANNED_WORDS if w in low]
    if render_provenance(entries) not in (repo / PROVENANCE).read_text(encoding="utf-8") and entries:
        problems.append(f"{PROVENANCE}: the Medallions section is stale (run medallions.py bake)")
    lua = repo / LUA
    if entries and (not lua.exists() or lua.read_bytes() != render_lua(entries).encode("ascii")):
        problems.append(f"{LUA} is stale (run medallions.py bake)")
    if lua.exists():
        for name in re.findall(r'DIR \.\. "([^"]+)"', lua.read_text(encoding="ascii")):
            if not (media / name.replace("\\\\", "/")).exists():
                problems.append(f"{LUA} names {name}, which is missing")
    if anchors:
        for label, anchor in [("crest style", anchors.get("crestStyle"))] + anchor_items(anchors):
            if not anchor:
                problems.append(f"anchors.json has no {label} anchor")
            elif not (here / anchor["copy"]).exists():
                problems.append(f"anchor {label}: {anchor['copy']} is missing")
            elif text_sha256(anchor["prompt"]) != anchor["promptSha256"]:
                problems.append(f"anchor {label}: its prompt SHA-256 does not match its prompt")
        missing = [r for r in tables.RACES if r not in anchors.get("crests", {})]
        problems += [f"anchors.json has no crest race master for {r}" for r in missing]
        for race, anchor in anchors.get("crests", {}).items():
            if anchor["key"] != tables.master_key(race):
                problems.append(f"anchors.json: the {race} master is {anchor['key']}, tables.py says {tables.master_key(race)}")
    else:
        problems.append("Tools/medallions/anchors.json is missing")
    if complete:
        have = {(e["kind"], e["key"]) for e in entries}
        wanted = [(kind, key) for kind in KINDS for key in keys_for(kind)]
        wanted += [(f"crest_{m}", key) for key in keys_for("crest") for m in MASKS]
        problems += [f"{kind} {key} is missing" for kind, key in wanted if (kind, key) not in have]
    return problems


# Command line ------------------------------------------------------------------------------------------------------

def _keys(args, kind):
    if not getattr(args, "keys", None):
        return keys_for(kind)
    for key in args.keys:
        tables.split_key(key)
        if (kind == "crest") != (len(key.split("_")) == 2):
            raise SystemExit(f"{key} is not a {kind} key")
    return args.keys


def _parser():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("plan", "judge", "bake", "sheets"):
        command = sub.add_parser(name)
        command.add_argument("--kind", choices=KINDS)
        command.add_argument("--keys", nargs="+")
        if name == "plan":
            command.add_argument("--json", action="store_true")
        if name == "sheets":
            command.add_argument("--out", required=True)
    command = sub.add_parser("generate")
    command.add_argument("--kind", choices=KINDS, required=True)
    command.add_argument("--keys", nargs="+")
    command.add_argument("--all", action="store_true")
    command.add_argument("--max-credits", type=float, required=True)
    command.add_argument("--jobs", type=int, default=DEFAULT_JOBS)
    command.add_argument("--dry-run", action="store_true")
    for name in ("accept", "reject"):
        command = sub.add_parser(name)
        command.add_argument("kind", choices=KINDS)
        command.add_argument("key")
        command.add_argument("--note", required=True)
        if name == "accept":
            command.add_argument("--attempt", type=int)
    command = sub.add_parser("adopt")
    command.add_argument("kind", choices=KINDS)
    command.add_argument("key")
    command.add_argument("--job", required=True)
    command.add_argument("--image", required=True)
    command.add_argument("--prompt-file", required=True)
    command.add_argument("--reference", action="append", default=[])
    command.add_argument("--url", default="")
    command.add_argument("--date", default=today())
    sub.add_parser("anchors")
    sub.add_parser("status")
    command = sub.add_parser("verify")
    command.add_argument("--complete", action="store_true")
    return parser


def main(argv=None):
    args = _parser().parse_args(argv)
    anchors = load_json(ANCHORS, {})
    kinds = (args.kind,) if getattr(args, "kind", None) else KINDS
    if args.command == "plan":
        rows = [row for kind in kinds for row in plan(kind, _keys(args, kind), anchors, RAW)]
        if args.json:
            print(json.dumps(rows, indent=1))
        else:
            for row in rows:
                print(f"{row['kind']} {row['key']}: {row['step']}, {row['cost']:g} credits, references {row['references']}")
            print(f"{len(rows)} assets, {sum(r['cost'] for r in rows if r['step'] == 'generate'):g} credits to generate")
    elif args.command == "anchors":
        fetch_anchors(anchors, RAW)
    elif args.command == "generate":
        if not args.keys and not args.all:
            raise SystemExit("name --keys or pass --all")
        keys = _keys(args, args.kind)
        if args.dry_run:
            for row in plan(args.kind, keys, anchors, RAW):
                print(f"--- {row['kind']} {row['key']} ({row['step']}), references {row['references']}\n{row['prompt']}")
            return 0
        before = account_balance()
        print(f"credits: {before:.2f}; this run's cap is {args.max_credits:g}")
        steps = generate(args.kind, keys, RAW, anchors, runner=higgsfield_runner, fetch=download,
                         judge_for=lambda key: make_judge(args.kind, key, anchors, RAW),
                         budget=Budget(args.max_credits), jobs=args.jobs)
        after = account_balance()
        print(f"credits: {after:.2f} ({before - after:.2f} spent)")
        for step in ("done", "generate", "exhausted"):
            names = [k for k, s in steps.items() if s == step]
            print(f"{step}: {len(names)} {' '.join(names)}".rstrip())
    elif args.command == "judge":
        for kind in kinds:
            for key in _keys(args, kind):
                record = load_record(RAW, kind, key)
                todo = [a for a in record["attempts"] if "image" in a and a.get("by") == "script"]
                if not todo:
                    continue
                judge = make_judge(kind, key, anchors, RAW)
                for attempt in todo:
                    metrics, reasons = judge(Path(RAW) / kind / attempt["image"])
                    attempt.update(metrics=metrics, reasons=reasons, verdict="rejected" if reasons else "accepted")
                    print(f"{kind} {key} #{attempt['n']}: {attempt['verdict']} ({', '.join(reasons) or 'ok'})")
                save_record(RAW, record)
    elif args.command == "accept":
        chosen = accept_by_eye(RAW, args.kind, args.key, args.note, args.attempt)
        print(f"{args.kind} {args.key}: attempt {chosen['n']} accepted by eye")
    elif args.command == "reject":
        chosen = reject_by_eye(RAW, args.kind, args.key, args.note)
        print(f"{args.kind} {args.key}: attempt {chosen['n']} rejected by eye; the next generate rerolls it")
    elif args.command == "adopt":
        tables.split_key(args.key)
        attempt = adopt(RAW, args.kind, args.key, args.job, args.image, Path(args.prompt_file).read_text(encoding="utf-8"),
                        args.reference, args.date, url=args.url, judge=make_judge(args.kind, args.key, anchors, RAW))
        print(f"{args.kind} {args.key}: adopted as attempt {attempt['n']}, {attempt['verdict']} "
              f"({', '.join(attempt['reasons']) or 'ok'})")
    elif args.command == "bake":
        entries = merge_manifest(load_json(MANIFEST, []), bake(RAW, kinds, args.keys))
        save_json(MANIFEST, entries)
        write_provenance(entries)
        (REPO / LUA).write_bytes(render_lua(entries).encode("ascii"))
        print(f"manifest: {len(entries)} files; wrote {PROVENANCE} and {LUA}")
    elif args.command == "sheets":
        contact_sheets(RAW, kinds, args.keys, args.out)
    elif args.command == "status":
        for kind in KINDS:
            steps = [next_step(load_record(RAW, kind, key)) for key in keys_for(kind)]
            print(f"{kind}: " + ", ".join(f"{s} {steps.count(s)}" for s in ("done", "generate", "exhausted")))
    elif args.command == "verify":
        problems = verify(complete=args.complete)
        for problem in problems:
            print(problem)
        print("ok" if not problems else f"{len(problems)} problems")
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
