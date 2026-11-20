"""Post or edit one branded Discord embed for a release; --dry-run never sends."""

import argparse
import json
import os
import re
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GITHUB = "https://github.com/korallis/KstyleUI"
RAW = "https://raw.githubusercontent.com/korallis/KstyleUI"
DOWNLOAD = "[CurseForge](https://www.curseforge.com/wow/addons/kstyleui) · [Wago](https://addons.wago.io/addons/kstyleui)"


def release_section(changelog, tag):
    heading = re.search(r"^## %s \((\d{4}-\d{2}-\d{2})\)$" % re.escape(tag), changelog, re.M)
    if not heading:
        raise ValueError("Missing release section: " + tag)
    section = re.split(r"^## ", changelog[heading.end():], maxsplit=1, flags=re.M)[0].strip()
    return section, heading.group(1)


def github_notes(changelog, tag):
    return release_section(changelog, tag)[0] + "\n\n**Download:** " + DOWNLOAD + "\n"


def characters(text):
    return len(text.encode("utf-16-le")) // 2


def shorten(text, limit=120, sentence=True):
    # Treat inline Markdown as whole words, so a cut never leaves an open link or delimiter.
    atoms = []

    def protect(match):
        atoms.append(match.group())
        return "\0" + str(len(atoms) - 1) + "\0"

    text = re.sub(r"\[[^\]]+\]\((?:[^()]|\([^()]*\))*\)|`[^`]+`|\*\*.+?\*\*|__.+?__|~~.+?~~|\*[^*]+\*|_[^_]+_", protect, text)
    words = [re.sub(r"\0(\d+)\0", lambda m: atoms[int(m.group(1))], word) for word in text.split()]
    result = ""
    for index, word in enumerate(words):
        candidate = (result + " " + word).strip()
        if characters(candidate) + (1 if index < len(words) - 1 else 0) > limit:
            return result.rstrip(",;:") + "…"
        result = candidate
        if sentence and re.search(r"[.!?][*_`~]*$", word):
            break
    return result


def release_payload(changelog, tag, release_notes="", readme=""):
    section, date = release_section(changelog, tag)
    groups = re.split(r"^### (\w+)\s*$", section, flags=re.M)
    lists = {name: re.findall(r"^- (.+)$", body, re.M)
             for name, body in zip(groups[1::2], groups[2::2])}
    intro = groups[0].split("Highlights:", 1)
    summary = intro[0].strip().split("\n\n", 1)[0]
    highlights = re.findall(r"^- (.+)$", intro[1], re.M)[:6] if len(intro) > 1 else []
    highlights = highlights or (lists.get("Added", []) + lists.get("Fixed", []))[:5]
    name = re.search(r"^## %s: (.+?)(?: \(\d{4}-\d{2}-\d{2}\))?$" % re.escape(tag.removeprefix("v")),
                     release_notes, re.M)
    title = f"KstyleUI {tag}" + (" — " + name.group(1) if name else "")
    url = f"{GITHUB}/releases/tag/{tag}"
    raw = f"{RAW}/{tag}"
    gold = re.search(r'\bgilt = \{ "([0-9a-f]{6})"', (ROOT / "Core/Tokens.lua").read_text()).group(1)
    counts = " · ".join(f"{len(lists.get(label, []))} {label.lower()}" for label in ("Added", "Changed", "Fixed") if lists.get(label))
    description = (shorten(summary, 2400, sentence=False) + "\n\n**Highlights**\n"
                   + "\n".join("- " + shorten(line) for line in highlights) + ("\n\n" + counts if counts else ""))
    fields = [
        {"name": "Download", "value": f"{DOWNLOAD} · [GitHub]({url})"},
        {"name": "Full notes", "value": f"[Read the release notes]({url})"},
    ]
    if lists.get("Upgrading"):
        lines = ["- " + shorten(line) for line in lists["Upgrading"]]
        while characters("\n".join(lines)) > 1024:
            lines.pop()
        fields.append({"name": "Upgrading", "value": "\n".join(lines)})
    logo = f"{raw}/Media/Logo/Logo256.png"
    embed = {"title": shorten(title, 256, sentence=False), "url": url, "color": int(gold, 16),
             "author": {"name": "KstyleUI", "url": GITHUB, "icon_url": logo},
             "description": description, "fields": fields,
             "footer": {"text": "KstyleUI for WoW Forever · " + date}}
    hero = re.search(r"!\[[^\]]*\]\((?:https://raw\.githubusercontent\.com/korallis/KstyleUI/[^/]+/)?(docs/[^)]+)\)", readme)
    if hero and (ROOT / hero.group(1)).is_file():
        embed["image"] = {"url": f"{raw}/{hero.group(1)}"}
    payload = {"embeds": [embed], "flags": 4096, "allowed_mentions": {"parse": []}}
    totals = character_totals(payload)
    if totals["description"] > 4096 or totals["total"] > 6000 or any(characters(f["value"]) > 1024 for f in fields):
        raise ValueError("Release exceeds Discord embed limits")
    return payload


def character_totals(payload):
    embed = payload["embeds"][0]
    totals = {"title": characters(embed["title"]), "description": characters(embed["description"]),
              "fields": [characters(f["name"]) + characters(f["value"]) for f in embed["fields"]],
              "author": characters(embed["author"]["name"]), "footer": characters(embed["footer"]["text"])}
    totals["total"] = sum(value if isinstance(value, int) else sum(value) for value in totals.values())
    return totals


def send(webhook, payload, message_ids=""):
    ids = message_ids.split(",") if message_ids else []
    if any(not re.fullmatch(r"[0-9]+", value) for value in ids) or len(set(ids)) != len(ids):
        raise ValueError("message_ids must be distinct comma-separated Discord message IDs")
    base = urllib.parse.urlsplit(webhook)
    headers = {"Content-Type": "application/json", "User-Agent": "KstyleUI-release"}
    endpoint = urllib.parse.urlunsplit(base._replace(path=base.path.rstrip("/") + "/messages/" + ids[0])) if ids else webhook
    request = urllib.request.Request(endpoint, data=json.dumps(dict(payload, content="", flags=0) if ids else payload).encode(),
                                     method="PATCH" if ids else "POST",
                                     headers=headers)
    with urllib.request.urlopen(request, timeout=30):
        pass
    for message_id in ids[1:]:
        endpoint = urllib.parse.urlunsplit(base._replace(path=base.path.rstrip("/") + "/messages/" + message_id))
        with urllib.request.urlopen(urllib.request.Request(endpoint, method="DELETE", headers=headers), timeout=30):
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edit", action="store_true", help="edit the first message and delete the remaining IDs")
    parser.add_argument("tag")
    parser.add_argument("message_ids", nargs="?", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--notes", action="store_true", help="print the GitHub release text instead")
    args = parser.parse_args()
    if args.edit != bool(args.message_ids):
        parser.error("--edit requires message_ids; message_ids requires --edit")
    if args.notes:
        print(github_notes((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), args.tag), end="")
        return
    webhook = os.environ.get("DISCORD_RELEASE_WEBHOOK", "").strip()
    if not webhook and not args.dry_run:
        print("::notice::Discord release post skipped: webhook is not set.")
        return
    payload = release_payload((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), args.tag,
                              (ROOT / "docs/RELEASE_NOTES.md").read_text(encoding="utf-8"),
                              subprocess.check_output(["git", "show", args.tag + ":README.md"], cwd=ROOT).decode("utf-8"))
    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        print("Character totals: " + json.dumps(character_totals(payload)))
    else:
        send(webhook, payload, args.message_ids)


if __name__ == "__main__":
    main()
