"""Run every Tools/regression/test-*.lua in parallel under CI's interpreter, with a time and memory budget per file.

run-all.sh starts this from the repository root. Tools/regression/README.md describes the interpreter
choice, the budgets, the output, --shard (one slice of the files, for CI) and --affected (only the files a change can reach).
"""

import argparse
import contextlib
import fcntl
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

HERE = Path(__file__).resolve().parent

# Measured on 2026-11-09: CI's ubuntu-24.04 runner (4 CPUs, 16 GB) runs a test about 4 times slower
# under lua5.1 than an Apple M5 Max runs it under Lua 5.1.5 or luajit -joff. The slowest file then
# took 9.8 s and the largest peaked at 2.8 GB.
TIME_BUDGET = 20.0
CI_SLOWDOWN = 4
MEMORY_BUDGET_MB = 4096
STOP_AFTER = 3
TAIL_LINES = 5
SLOWEST = 5
AFFECTED_LINES = 40
MARGIN = 0.2
SLOT_POLL = 0.25
SLOT_SLACK = 30.0

LUA51_HELP = "Install Lua 5.1 with bash Tools/dev/install-lua51.sh, or set LUA."
SLOW_FIX = "Make the test cheaper; CI runs Lua 5.1, about {0} times slower than this Mac.".format(CI_SLOWDOWN)
BIG_FIX = "Make the test use less memory; CI runs 4 test files at once on 16 GB."


def interpreter():
    """Return (command, label), or (None, message) when no Lua is found."""
    chosen = os.environ.get("LUA")
    if chosen:
        command = shlex.split(chosen)
        if not shutil.which(command[0]):
            return None, "{0} not found. {1}".format(command[0], LUA51_HELP)
        if Path(command[0]).name.startswith("luajit") and "-joff" not in command[1:]:
            return command, ("LUA={0}: fast mode, not CI-equivalent. The JIT runs some tests 100 times faster than "
                             "CI's Lua 5.1, so the times and the budget do not predict CI. Run without LUA before a push.").format(chosen)
        return command, "LUA={0}".format(chosen)
    found = shutil.which("lua5.1")
    home = Path(os.environ.get("HOME", "~")).expanduser() / ".local" / "bin" / "lua5.1"
    if not found and os.access(home, os.X_OK):
        found = str(home)
    if found:
        return [found], "lua: {0} (Lua 5.1, as CI runs)".format(found)
    if shutil.which("luajit"):
        return ["luajit", "-joff"], ("lua: luajit -joff (no JIT, close to CI's Lua 5.1 in speed). "
                                     "For CI's exact interpreter: bash Tools/dev/install-lua51.sh")
    return None, "No Lua found: lua5.1, ~/.local/bin/lua5.1 and luajit are missing. " + LUA51_HELP


def budgets():
    seconds = os.environ.get("TEST_TIME_BUDGET")
    if seconds:
        seconds = float(seconds)
    else:
        seconds = TIME_BUDGET * (CI_SLOWDOWN if os.environ.get("CI") == "true" else 1)
    return seconds, float(os.environ.get("TEST_MEMORY_BUDGET", MEMORY_BUDGET_MB))


def peak_mb(usage):
    # ru_maxrss is in bytes on macOS and in kilobytes on Linux.
    return usage.ru_maxrss / (1 << 20) if sys.platform == "darwin" else usage.ru_maxrss / 1024


class Children:
    """The running tests' process groups. Each test runs in its own group so a stop kills what it started."""

    def __init__(self):
        self.lock = threading.Lock()
        self.groups = set()
        self.stopping = False

    def start(self, args, out, env=None):
        with self.lock:
            if self.stopping:
                raise KeyboardInterrupt
            child = subprocess.Popen(args, stdout=out, stderr=subprocess.STDOUT, start_new_session=True, env=env)
            self.groups.add(child.pid)
            return child

    def done(self, child):
        with self.lock:
            self.groups.discard(child.pid)

    def stop_all(self):
        with self.lock:
            self.stopping = True
            for group in self.groups:
                try:
                    os.killpg(group, signal.SIGKILL)
                except ProcessLookupError:
                    pass


CHILDREN = Children()


class Slots:
    """The machine-wide limit on running test files.

    Every local run takes one slot while a test file runs, so all the runs on the Mac together never run more files
    than there are slots. The holders live in one JSON file behind a flock; a holder whose process is gone, or whose
    lease (the time a test may take, plus slack) has run out, is dropped by the next run to look. Nothing is killed.
    """

    def __init__(self, folder, count, lease):
        self.folder, self.count, self.lease = Path(folder), count, lease
        self.table = self.folder / "worker-slots.json"
        self.lock = threading.Lock()
        self.waited = 0.0
        self.peak_others = 0

    @contextlib.contextmanager
    def locked(self):
        with open(self.folder / "worker-slots.lock", "a") as guard:
            fcntl.flock(guard, fcntl.LOCK_EX)
            yield

    def holders(self):
        try:
            rows = json.loads(self.table.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return []
        live = []
        for row in rows if isinstance(rows, list) else []:
            try:
                if row["until"] < time.time():
                    continue
                os.kill(row["pid"], 0)
            except ProcessLookupError:
                continue
            except PermissionError:
                pass
            except (KeyError, TypeError, ValueError, OverflowError):
                continue
            live.append(row)
        return live

    def save(self, rows):
        scratch = self.table.with_name("worker-slots.{0}.tmp".format(os.getpid()))
        scratch.write_text(json.dumps(rows), encoding="utf-8")
        os.replace(scratch, self.table)

    def others(self):
        with self.locked():
            return sum(1 for row in self.holders() if row["pid"] != os.getpid())

    def acquire(self):
        """Wait for a free slot and return (token, slots held by other runs)."""
        token = "{0}-{1}-{2}".format(os.getpid(), threading.get_ident(), time.monotonic_ns())
        started = time.monotonic()
        while True:
            if CHILDREN.stopping:
                raise KeyboardInterrupt
            with self.locked():
                rows = self.holders()
                others = sum(1 for row in rows if row["pid"] != os.getpid())
                with self.lock:
                    self.peak_others = max(self.peak_others, others)
                if len(rows) < self.count:
                    rows.append({"pid": os.getpid(), "token": token, "until": time.time() + self.lease})
                    self.save(rows)
                    with self.lock:
                        self.waited += time.monotonic() - started
                    return token, others
            time.sleep(SLOT_POLL + random.random() * SLOT_POLL)

    def release(self, token):
        with self.locked():
            self.save([row for row in self.holders() if row["token"] != token])


def make_slots(lease):
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
        slots = Slots(folder, count, lease)
        slots.others()
    except OSError as error:
        return None, "worker slots: off, cannot use {0} ({1})".format(folder, error)
    return slots, None


def load_now():
    try:
        return os.getloadavg()[0]
    except (OSError, AttributeError):
        return 0.0


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
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    timer = threading.Timer(limit, stop)
    timer.start()
    _, status, usage = os.wait4(child.pid, 0)
    timer.cancel()
    CHILDREN.done(child)
    child.returncode = os.waitstatus_to_exitcode(status)
    return {"seconds": time.monotonic() - start, "mb": peak_mb(usage), "ok": child.returncode == 0, "stopped": bool(stopped),
            "load": load, "others": others}


def fmt(seconds):
    return "{0:g}".format(round(seconds, 1))


def problems(name, result, seconds, megabytes):
    lines = []
    seen = " Machine load was {0:.1f} when it started; run it alone before you call it load.".format(result["load"])
    if result["stopped"]:
        lines.append("FAIL {0}: stopped after {1} s, {2} times the {3} s budget. {4}{5}".format(
            name, fmt(seconds * STOP_AFTER), STOP_AFTER, fmt(seconds), SLOW_FIX, seen))
    elif result["seconds"] > seconds:
        lines.append("FAIL {0}: took {1:.1f} s, over the {2} s budget. {3}{4}".format(name, result["seconds"], fmt(seconds), SLOW_FIX, seen))
    if result["mb"] > megabytes:
        lines.append("FAIL {0}: peaked at {1:.0f} MB, over the {2:.0f} MB budget. {3}".format(name, result["mb"], megabytes, BIG_FIX))
    return lines


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
    every = sorted(str(path) for path in Path("Tools/regression").glob("test-*.lua"))
    if not every:
        print("no tests found in Tools/regression")
        return 1
    seconds, megabytes = budgets()
    jobs = jobs_for(args)
    slots, off = make_slots(seconds * STOP_AFTER + SLOT_SLACK)
    if slots:
        jobs = min(jobs, slots.count)
    print(label)
    print("budget {0} s and {1:.0f} MB per test file".format(fmt(seconds), megabytes), flush=True)
    start_load = load_now()
    print("machine load {0:.1f} on {1} CPUs; {2}".format(start_load, os.cpu_count() or 0, off or (
        "worker slots: {0} for every run on this machine, {1} held by other runs".format(slots.count, slots.others()))), flush=True)

    tests, weights = every, load_weights()
    if args.slice:
        tests = shard(tests, *args.slice, weights)
        print("shard {0}/{1}: {2} of {3} test files".format(*args.slice, len(tests), len(every)))
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
        def task(path):
            stem = Path(path).stem
            trace = os.path.join(logs, stem + ".trace") if args.affected else None
            return run_one(command, path, os.path.join(logs, stem + ".out"), seconds * STOP_AFTER, trace, slots)

        pool = ThreadPoolExecutor(max_workers=jobs)
        try:
            results = dict(zip(order, pool.map(task, order)))
        except BaseException:
            # Ctrl-C or SIGTERM: the tests are in their own groups and get no signal, so kill them.
            CHILDREN.stop_all()
            pool.shutdown(wait=True, cancel_futures=True)
            raise
        pool.shutdown()
        wall = time.monotonic() - start

        passed = failed = 0
        for path in tests:
            name, result = Path(path).stem, results[path]
            lines = problems(name, result, seconds, megabytes)
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
        print("  {0:6.1f} s {1:6.0f} MB  {2}".format(results[path]["seconds"], results[path]["mb"], Path(path).stem))
    if args.margins:
        near = [path for path in ranked if results[path]["seconds"] >= seconds * (1 - MARGIN) or results[path]["mb"] >= megabytes * (1 - MARGIN)]
        print("within {0:.0f}% of the budget, run alone:".format(MARGIN * 100) + ("" if near else " none"))
        for path in near:
            result = results[path]
            print("  {0:6.1f} s ({1:3.0f}%) {2:6.0f} MB ({3:3.0f}%), load {4:.1f}  {5}".format(
                result["seconds"], 100 * result["seconds"] / seconds, result["mb"], 100 * result["mb"] / megabytes,
                result["load"], Path(path).stem))
    total = sum(result["seconds"] for result in results.values())
    print("total {0:.1f} s of test time in {1:.1f} s, {2} at a time".format(total, wall, jobs))
    loads = [result["load"] for result in results.values()]
    seen = "machine load {0:.1f} at the start, {1:.1f} at the end, {2:.1f} at most when a test started".format(
        start_load, load_now(), max(loads, default=start_load))
    if slots:
        seen += "; waited {0:.1f} s for worker slots, other runs held up to {1} of {2}".format(slots.waited, slots.peak_others, slots.count)
    print(seen)
    if args.write_weights and failed == 0:
        measured = {Path(path).name: round(results[path]["seconds"], 1) for path in tests}
        (HERE / "weights.json").write_text(json.dumps(measured, indent=1, sort_keys=True) + "\n", encoding="utf-8")
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
