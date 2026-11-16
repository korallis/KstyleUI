"""Run every Tools/regression/test-*.lua in parallel under CI's interpreter, with a time and memory budget per file.

run-all.sh starts this from the repository root. Tools/regression/README.md describes the interpreter
choice, the budgets, the output, --shard (one slice of the files, for CI) and --affected (only the files a change can reach).
"""

import argparse
import json
import os
import random
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import affected
import runner_platform

HERE = Path(__file__).resolve().parent

TIME_BUDGET = 20.0
MEMORY_BUDGET_MB = 4096
HANG_GUARD = 120.0
TAIL_LINES = 5
SLOWEST = 5
AFFECTED_LINES = 40
MARGIN = 0.2
SLOT_POLL = 0.25

LUA51_HELP = "Install Lua 5.1 with bash Tools/dev/install-lua51.sh, or set LUA."


def interpreter():
    """Return (command, label), or (None, message) when no Lua is found."""
    chosen = os.environ.get("LUA")
    if chosen:
        command = shlex.split(chosen, posix=os.name != "nt")
        if not command:
            return None, LUA51_HELP
        executable = command[0].strip('"')
        found = shutil.which(executable)
        if not found:
            return None, "{0} not found. {1}".format(command[0], LUA51_HELP)
        command[0] = found
        if Path(command[0]).name.startswith("luajit") and "-joff" not in command[1:]:
            return command, ("LUA={0}: fast mode, not CI-equivalent. The JIT runs some tests 100 times faster than "
                             "CI's Lua 5.1, so the times and the budget do not predict CI. Run without LUA before a push.").format(chosen)
        return command, "LUA={0}".format(chosen)
    found = shutil.which("lua5.1")
    home = Path(os.environ.get("HOME", "~")).expanduser() / ".local" / "bin" / ("lua5.1.exe" if os.name == "nt" else "lua5.1")
    if not found and os.access(home, os.X_OK):
        found = str(home)
    if found:
        return [found], "lua: {0} (Lua 5.1, as CI runs)".format(found)
    found = shutil.which("luajit")
    if found:
        return [found, "-joff"], ("lua: luajit -joff (no JIT, close to CI's Lua 5.1 in speed). "
                                     "For CI's exact interpreter: bash Tools/dev/install-lua51.sh")
    return None, "No Lua found: lua5.1, ~/.local/bin/lua5.1 and luajit are missing. " + LUA51_HELP


def budgets():
    return float(os.environ.get("TEST_TIME_BUDGET", TIME_BUDGET)), float(os.environ.get("TEST_MEMORY_BUDGET", MEMORY_BUDGET_MB))


def budgeted(command):
    if "LUA" in os.environ:
        return False
    try:
        probe = subprocess.run(command + ["-v", "-e", 'print(_VERSION); print(jit == nil)'],
                               capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return probe.returncode == 0 and probe.stdout.splitlines() == ["Lua 5.1", "true"] and probe.stderr.startswith("Lua 5.1.5 ")


class Children:
    """The test processes this run owns."""

    def __init__(self):
        self.lock = threading.Lock()
        self.children = set()
        self.stopping = False

    def start(self, args, out, env=None):
        with self.lock:
            if self.stopping:
                raise KeyboardInterrupt
            child = subprocess.Popen(args, stdout=out, stderr=subprocess.STDOUT, start_new_session=not runner_platform.WINDOWS, env=env)
            self.children.add(child)
            return child

    def done(self, child):
        with self.lock:
            self.children.discard(child)

    def stop_all(self):
        with self.lock:
            self.stopping = True
            for child in self.children:
                runner_platform.kill(child)


CHILDREN = Children()


class Slots:
    """One OS-held lock per machine-wide worker slot; process exit releases it."""

    def __init__(self, folder, count):
        self.folder, self.count = Path(folder), count
        self.held = {}
        self.lock = threading.Lock()
        self.waited = 0.0
        self.peak_others = 0

    def probe(self, index):
        guard = open(self.folder / "worker-slot-{0}.lock".format(index), "a+b")
        if runner_platform.try_lock(guard):
            return guard
        guard.close()
        return None

    def others(self):
        with self.lock:
            return self.scan()[1]

    def scan(self):
        free, others = None, 0
        for index in range(self.count):
            if index in self.held:
                continue
            guard = self.probe(index)
            if guard is None:
                others += 1
            else:
                guard.close()
                if free is None:
                    free = index
        return free, others

    def acquire(self):
        """Wait for a free slot and return (token, slots held by other runs)."""
        started = time.monotonic()
        while True:
            if CHILDREN.stopping:
                raise KeyboardInterrupt
            with self.lock:
                index, others = self.scan()
                self.peak_others = max(self.peak_others, others)
                if index is not None:
                    guard = self.probe(index)
                    if guard is not None:
                        self.held[index] = guard
                        self.waited += time.monotonic() - started
                        return index, others
            time.sleep(SLOT_POLL + random.random() * SLOT_POLL)

    def release(self, token):
        with self.lock:
            self.held.pop(token).close()


def make_slots():
    """Return the Slots for this run, or (None, why) when the limit is off or its folder cannot be made."""
    if os.environ.get("CI") == "true" and os.environ.get("RUNNER_ENVIRONMENT") != "self-hosted":
        return None, "worker slots: off in CI"
    cpus = os.cpu_count() or 2
    count = int(os.environ.get("KSTYLEUI_SLOTS") or max(2, cpus // 3))
    if count <= 0:
        return None, "worker slots: off (KSTYLEUI_SLOTS=0)"
    folder = Path(os.environ.get("KSTYLEUI_SLOT_DIR") or Path.home() / ".cache" / "kstyleui")
    try:
        folder.mkdir(parents=True, exist_ok=True)
        slots = Slots(folder, count)
        slots.others()
    except OSError as error:
        return None, "worker slots: off, cannot use {0} ({1})".format(folder, error)
    return slots, None


def load_now():
    try:
        return os.getloadavg()[0]
    except (OSError, AttributeError):
        return None


def run_one(command, path, log, limit, trace=None, slots=None):
    token, others = slots.acquire() if slots else (None, 0)
    try:
        return run_held(command, path, log, limit, trace, load_now(), others)
    finally:
        if slots:
            slots.release(token)


def run_held(command, path, log, limit, trace, load, others):
    start = time.monotonic()
    env = None
    if trace:
        env = dict(os.environ, LUA_INIT="@" + str(HERE / "trace.lua"), KSTYLEUI_TRACE=trace)
    with open(log, "wb") as out:
        child = CHILDREN.start(command + [path], out, env)
    stopped = []

    def stop():
        stopped.append(True)
        runner_platform.kill(child)

    timer = threading.Timer(limit, stop)
    timer.start()
    try:
        mb, cpu = runner_platform.wait(child)
    finally:
        timer.cancel()
        timer.join()
        CHILDREN.done(child)
    return {"seconds": time.monotonic() - start, "mb": mb, "cpu": cpu, "ok": child.returncode == 0, "stopped": bool(stopped),
            "load": load, "others": others, "hang_limit": limit}


def fmt(seconds):
    if seconds is None:
        return "n/a"
    return "{0:g}".format(round(seconds, 1))


def memory_text(mb):
    return "{0:.0f}".format(mb) if mb is not None else "n/a"


def problems(name, result, seconds, megabytes):
    lines = []
    if result["stopped"]:
        lines.append("FAIL {0}: stopped by the {1} s wall-clock hang guard.".format(name, fmt(result.get("hang_limit", HANG_GUARD))))
    elif seconds is not None and result["cpu"] is not None and result["cpu"] > seconds:
        lines.append("FAIL {0}: used {1:.2f} CPU s, over the {2} CPU s budget. Make the test cheaper.".format(name, result["cpu"], fmt(seconds)))
    if megabytes is not None and result["mb"] is not None and result["mb"] > megabytes:
        lines.append("FAIL {0}: peaked at {1:.0f} MB, over the {2:.0f} MB budget. Make the test use less memory.".format(name, result["mb"], megabytes))
    return lines


def near_budget(result, seconds, megabytes):
    return ((seconds is not None and result["cpu"] is not None and result["cpu"] >= seconds * (1 - MARGIN)) or
            (megabytes is not None and result["mb"] is not None and result["mb"] >= megabytes * (1 - MARGIN)))


def hang_limit(seconds):
    return max(HANG_GUARD, 5 * seconds) if seconds is not None else HANG_GUARD


def load_allowances():
    path = HERE / "cpu_allowances.tsv"
    lines = path.read_text(encoding="ascii").splitlines() if path.exists() else []
    base_ref = "HEAD^1" if os.environ.get("GITHUB_ACTIONS") == "true" else "origin/staging"
    ref = subprocess.run(["git", "cat-file", "-e", base_ref], capture_output=True)
    if ref.returncode:
        raise ValueError("fetch {0} before checking the shrinking CPU allowance list".format(base_ref))
    entry = subprocess.run(["git", "ls-tree", base_ref, "--", "Tools/regression/cpu_allowances.tsv"],
                           capture_output=True, text=True)
    if entry.returncode:
        raise ValueError("cannot read origin/staging CPU allowance baseline")
    base = subprocess.run(["git", "show", base_ref + ":Tools/regression/cpu_allowances.tsv"],
                          capture_output=True, text=True) if entry.stdout else None
    if base is not None and base.returncode:
        raise ValueError("cannot read origin/staging CPU allowance baseline")
    if base is not None and not set(lines).issubset(base.stdout.splitlines()):
        raise ValueError("cpu_allowances.tsv may only shrink; make the test cheaper (LEE-5827)")
    allowances = {}
    for line in lines:
        name, seconds, ticket = line.split()
        if ticket != "LEE-5827" or int(seconds) <= TIME_BUDGET or name in allowances:
            raise ValueError("cpu_allowances.tsv needs unique names, measured allowances above 20 and LEE-5827")
        allowances[name] = int(seconds)
    return allowances


def load_weights():
    try:
        data = json.loads((HERE / "weights.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return {name: float(seconds) for name, seconds in data.items()}


def weigh(tests, weights):
    """Return {test path: expected seconds}; a file with no weight gets the median of the others."""
    known = sorted(weights.values())
    default = known[len(known) // 2] if known else 1.0
    return {test: weights.get(Path(test).name, default) for test in tests}


def shard(tests, index, count, weights):
    """Return the tests of slice index (1-based) of count: heaviest first, each to the lightest slice so far."""
    weight = weigh(tests, weights)
    loads, slices = [0.0] * count, [[] for _ in range(count)]
    for test in sorted(tests, key=lambda test: (-weight[test], test)):
        lightest = loads.index(min(loads))
        loads[lightest] += weight[test]
        slices[lightest].append(test)
    return sorted(slices[index - 1])


def parse_args(argv):
    parser = argparse.ArgumentParser(prog="run-all.sh", description="Run the Lua regression tests.")
    parser.add_argument("--shard", metavar="I/N", help="run slice I of N (1-based); CI splits the files across jobs this way")
    parser.add_argument("--affected", metavar="BASE", nargs="?", const="origin/staging",
                        help="run only the files that load something changed against BASE (default origin/staging)")
    parser.add_argument("--margins", action="store_true",
                        help="run the files one at a time and list those within 20%% of the time or memory budget")
    parser.add_argument("--write-weights", action="store_true",
                        help="run every file and write Tools/regression/weights.json, the times --shard balances by")
    args = parser.parse_args(argv)
    args.slice = None
    if args.shard:
        try:
            index, count = (int(part) for part in args.shard.split("/"))
        except ValueError:
            index = count = 0
        if not 1 <= index <= count:
            parser.error("--shard takes I/N with 1 <= I <= N, for example 2/4")
        args.slice = (index, count)
    if args.write_weights and (args.shard or args.affected or args.margins):
        parser.error("--write-weights needs every file: do not combine it with --shard, --affected or --margins")
    return args


def plan_affected(tests, base):
    """Return (tests to run, lines to print, changed paths or None when they cannot be known) for --affected."""
    try:
        merge_base, changes = affected.changed_files(base)
    except (OSError, RuntimeError) as error:
        return tests, ["affected: cannot compare with {0} ({1}); running every test file".format(base, error)], None
    chosen, notes = affected.select(tests, changes, affected.load_cache(affected.cache_path()))
    lines = ["affected: {0} files changed against {1} (merge base {2})".format(len(changes), base, merge_base[:9])]
    lines += ["affected: " + note for note in notes]
    run = [test for test in tests if test in chosen]
    lines.append("affected: running {0} of {1} test files; the other {2} load nothing that changed".format(
        len(run), len(tests), len(tests) - len(run)))
    reasons = [Path(test).stem + ": " + chosen[test] for test in run]
    lines += ["  " + reason for reason in reasons[:AFFECTED_LINES]]
    if len(reasons) > AFFECTED_LINES:
        lines.append("  and {0} more".format(len(reasons) - AFFECTED_LINES))
    return run, lines, changes


def locale_check(changes):
    """Return (lines, ok) for the string tables, or ([], True) when no addon Lua or locale file changed.

    CI's Python job fails test_locale_strings on an L[...] key the English base lacks; this is its cheap part.
    """
    script = Path("Tools/locale/strings.py")
    if not script.exists():
        return [], True
    if changes is not None and not any(
            (path.endswith(".lua") and not path.startswith(("Tools/", "docs/"))) or path.startswith("Tools/locale/")
            for path in changes):
        return [], True
    done = subprocess.run([sys.executable, str(script), "check"], capture_output=True, text=True)
    if done.returncode == 0:
        return ["locale: the string tables match the code"], True
    found = done.stdout.splitlines() or done.stderr.splitlines()[-TAIL_LINES:]
    lines = ["FAIL locale: {0} problems in the string tables".format(len(found))] + ["  " + line for line in found[:AFFECTED_LINES]]
    if len(found) > AFFECTED_LINES:
        lines.append("  and {0} more".format(len(found) - AFFECTED_LINES))
    lines.append("Fix: python3 Tools/locale/strings.py sync, then commit Tools/locale and Core/Locales. A format, space or glyph problem in a translation is fixed in its Tools/locale/<code>.json.")
    return lines, False


def jobs_for(args):
    if args.margins:
        return 1
    explicit = os.environ.get("JOBS")
    if explicit:
        return int(explicit)
    cpus = os.cpu_count() or 2
    return max(2, cpus // 3) if args.affected else cpus


def main(argv):
    args = parse_args(argv)
    command, label = interpreter()
    if command is None:
        print(label)
        return 2
    every = sorted(path.as_posix() for path in Path("Tools/regression").glob("test-*.lua"))
    if not every:
        print("no tests found in Tools/regression")
        return 1
    seconds, megabytes = budgets()
    measured = budgeted(command)
    try:
        allowances = load_allowances() if measured else {}
    except (OSError, ValueError) as error:
        print("FAIL " + str(error))
        return 1
    jobs = jobs_for(args)
    slots, off = make_slots()
    if slots:
        jobs = min(jobs, slots.count)
    print(label)
    print(("budget {0} CPU s and {1:.0f} MB per test file".format(fmt(seconds), megabytes) if measured else
           "not budgeted: requires default PUC Lua 5.1.5 (_VERSION=Lua 5.1, jit=nil); LUA overrides are not budgeted") +
          "; wall-clock hang guard max({0} s, 5 x file CPU limit)".format(fmt(HANG_GUARD)), flush=True)
    if not measured:
        seconds = megabytes = None
    start_load = load_now()
    print("machine load {0} on {1} CPUs; {2}".format(fmt(start_load), os.cpu_count() or 0, off or (
        "worker slots: {0} for every run on this machine, {1} held by other runs".format(slots.count, slots.others()))), flush=True)

    tests, weights = every, load_weights()
    if args.slice:
        tests = shard(tests, args.slice[1] + 1 - args.slice[0], args.slice[1], weights)
        print("shard {0}/{1}: {2} of {3} test files".format(*args.slice, len(tests), len(every)))
    calibration = ['test-ornament-surfaces-minimap-subtle.lua', 'test-ornament-surfaces-minimap-full.lua', 'test-render-story-guard-tank.lua', 'test-render-scenes-gallery.lua', 'test-text-pixels-hud.lua', 'test-pixel-grid-16.lua', 'test-render-story-guard-healer.lua', 'test-pixel-grid-3.lua', 'test-groupframes-rows.lua', 'test-pixel-grid-8.lua', 'test-pixel-grid-2.lua', 'test-pixel-grid-15.lua', 'test-pixel-grid-12.lua', 'test-render-scenes-classes.lua', 'test-pixel-grid-9.lua', 'test-render-story-guard-dps.lua', 'test-perf.lua', 'test-pixel-grid-14.lua', 'test-hud-material-tank.lua', 'test-pixel-grid-10.lua', 'test-pixel-grid-1.lua', 'test-pixel-grid-11.lua', 'test-pixel-grid-4.lua', 'test-type-roles.lua', 'test-pixel-grid-13.lua', 'test-pixel-grid-7.lua', 'test-pixel-grid-6.lua', 'test-text-floor.lua', 'test-pixel-grid-5.lua', 'test-setup-collisions.lua']
    if os.environ.get("CI") == "true" and all((HERE / name).exists() for name in calibration):
        tests = [(HERE / name).relative_to(Path.cwd()).as_posix() for name in calibration]
        print("CPU CALIBRATION ONLY: same 30 files on both assigned Mac runners; final full-suite run follows", flush=True)
    locale_lines, locale_ok = [], True
    if args.affected:
        tests, lines, changes = plan_affected(tests, args.affected)
        print("\n".join(lines), flush=True)
        locale_lines, locale_ok = locale_check(changes)
    expected = weigh(tests, weights)
    order = sorted(tests, key=lambda test: -expected[test])

    start = time.monotonic()
    records = {}
    with tempfile.TemporaryDirectory() as logs:
        progress_lock = threading.Lock()
        completed = 0

        def task(path):
            nonlocal completed
            stem = Path(path).stem
            trace = os.path.join(logs, stem + ".trace") if args.affected else None
            result = run_one(command, path, os.path.join(logs, stem + ".out"),
                             hang_limit(allowances.get(Path(path).name, seconds)), trace, slots)
            with progress_lock:
                completed += 1
                print("progress: {0}/{1} test files done".format(completed, len(tests)), flush=True)
            return result

        pool = ThreadPoolExecutor(max_workers=jobs)
        try:
            results = dict(zip(order, pool.map(task, order)))
        except BaseException:
            CHILDREN.stop_all()
            pool.shutdown(wait=True, cancel_futures=True)
            raise
        pool.shutdown()
        wall = time.monotonic() - start

        passed = failed = 0
        for path in tests:
            name, result = Path(path).stem, results[path]
            print("usage: {0} cpu={1} wall={2} peak_mb={3}".format(
                Path(path).name, "{0:.6f}".format(result["cpu"]) if result["cpu"] is not None else "n/a",
                "{0:.6f}".format(result["seconds"]), memory_text(result["mb"])))
            if measured and (result["cpu"] is None or result["mb"] is None):
                print("not budgeted: {0}: OS CPU or peak memory measurement unavailable".format(name))
            allowance = allowances.get(Path(path).name)
            lines = problems(name, result, allowance if allowance is not None else seconds, megabytes)
            if args.affected and result["ok"]:
                try:
                    with open(os.path.join(logs, name + ".trace"), encoding="utf-8", errors="replace") as trace:
                        records[path] = dict(affected.record_from_trace(trace.read(), os.getcwd()), sha=affected.fingerprint(path))
                except OSError:
                    pass
            if result["ok"] and not lines:
                passed += 1
                continue
            failed += 1
            if not result["ok"] and not result["stopped"]:
                print("FAIL " + name)
                with open(os.path.join(logs, name + ".out"), encoding="utf-8", errors="replace") as log:
                    tail = log.read().splitlines()[-TAIL_LINES:]
                for line in tail:
                    print(line)
            for line in lines:
                print(line)

    if locale_lines:
        print("\n".join(locale_lines))
    failed += 0 if locale_ok else 1

    if records:
        try:
            affected.save_cache(affected.cache_path(), records)
        except OSError as error:
            print("affected: could not save what the tests load to {0}: {1}".format(affected.cache_path(), error))

    print("slowest:")
    ranked = sorted(tests, key=lambda path: results[path]["seconds"], reverse=True)
    for path in ranked[:SLOWEST]:
        print("  {0:6.1f} s {1:>6} MB  {2}".format(results[path]["seconds"], memory_text(results[path]["mb"]), Path(path).stem))
    if args.margins:
        near = [path for path in ranked if near_budget(results[path], allowances.get(Path(path).name, seconds), megabytes)]
        print("within {0:.0f}% of the budget, run alone:".format(MARGIN * 100) + ("" if near else " none"))
        for path in near:
            result = results[path]
            limit = allowances.get(Path(path).name, seconds)
            print("  {0} CPU s ({1}%) {2:>6} MB ({3}%), load {4}  {5}".format(
                fmt(result["cpu"]), fmt(100 * result["cpu"] / limit) if result["cpu"] is not None else "n/a", memory_text(result["mb"]),
                fmt(100 * result["mb"] / megabytes) if result["mb"] is not None else "n/a",
                fmt(result["load"]), Path(path).stem))
    total = sum(result["seconds"] for result in results.values())
    print("total {0:.1f} s of test time in {1:.1f} s, {2} at a time".format(total, wall, jobs))
    loads = [result["load"] for result in results.values() if result["load"] is not None]
    seen = "machine load {0} at the start, {1} at the end, {2} at most when a test started".format(
        fmt(start_load), fmt(load_now()), fmt(max(loads, default=start_load)))
    if slots:
        seen += "; waited {0:.1f} s for worker slots, other runs held up to {1} of {2}".format(slots.waited, slots.peak_others, slots.count)
    print(seen)
    if args.write_weights and failed == 0:
        measured = {Path(path).name: round(results[path]["seconds"], 1) for path in tests}
        (HERE / "weights.json").write_text(json.dumps(measured, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
        print("wrote {0} weights to {1}".format(len(measured), HERE / "weights.json"))
    summary = "passed {0}, failed {1}".format(passed, failed)
    if args.affected:
        summary += " (affected mode: {0} of {1} test files ran; the other {2} did not, and CI runs them all)".format(
            len(tests), len(every), len(every) - len(tests))
    print(summary)
    return 0 if failed == 0 else 1


def terminated(signum, frame):
    raise SystemExit(128 + signum)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, terminated)
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
