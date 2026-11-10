"""Run every Tools/regression/test-*.lua in parallel under CI's interpreter, with a time and memory budget per file.

run-all.sh starts this from the repository root. Tools/regression/README.md describes the interpreter
choice, the budgets, the output, --shard (one slice of the files, for CI) and --affected (only the files a change can reach).
"""

import argparse
import json
import os
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


def run_one(command, path, log, limit, trace=None):
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
    return {"seconds": time.monotonic() - start, "mb": peak_mb(usage), "ok": child.returncode == 0, "stopped": bool(stopped)}


def fmt(seconds):
    return "{0:g}".format(round(seconds, 1))


def problems(name, result, seconds, megabytes):
    lines = []
    if result["stopped"]:
        lines.append("FAIL {0}: stopped after {1} s, {2} times the {3} s budget. {4}".format(
            name, fmt(seconds * STOP_AFTER), STOP_AFTER, fmt(seconds), SLOW_FIX))
    elif result["seconds"] > seconds:
        lines.append("FAIL {0}: took {1:.1f} s, over the {2} s budget. {3}".format(name, result["seconds"], fmt(seconds), SLOW_FIX))
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
    if args.write_weights and (args.shard or args.affected):
        parser.error("--write-weights needs every file: do not combine it with --shard or --affected")
    return args


def plan_affected(tests, base):
    """Return (tests to run, lines to print) for --affected."""
    try:
        merge_base, changes = affected.changed_files(base)
    except (OSError, RuntimeError) as error:
        return tests, ["affected: cannot compare with {0} ({1}); running every test file".format(base, error)]
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
    return run, lines


def jobs_for(args):
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
    print(label)
    print("budget {0} s and {1:.0f} MB per test file".format(fmt(seconds), megabytes), flush=True)

    tests, weights = every, load_weights()
    if args.slice:
        tests = shard(tests, *args.slice, weights)
        print("shard {0}/{1}: {2} of {3} test files".format(*args.slice, len(tests), len(every)))
    if args.affected:
        tests, lines = plan_affected(tests, args.affected)
        print("\n".join(lines), flush=True)
    expected = weigh(tests, weights)
    order = sorted(tests, key=lambda test: -expected[test])

    start = time.monotonic()
    records = {}
    with tempfile.TemporaryDirectory() as logs:
        def task(path):
            stem = Path(path).stem
            trace = os.path.join(logs, stem + ".trace") if args.affected else None
            return run_one(command, path, os.path.join(logs, stem + ".out"), seconds * STOP_AFTER, trace)

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

    if records:
        try:
            affected.save_cache(affected.cache_path(), records)
        except OSError as error:
            print("affected: could not save what the tests load to {0}: {1}".format(affected.cache_path(), error))

    print("slowest:")
    ranked = sorted(tests, key=lambda path: results[path]["seconds"], reverse=True)
    for path in ranked[:SLOWEST]:
        print("  {0:6.1f} s {1:6.0f} MB  {2}".format(results[path]["seconds"], results[path]["mb"], Path(path).stem))
    total = sum(result["seconds"] for result in results.values())
    print("total {0:.1f} s of test time in {1:.1f} s, {2} at a time".format(total, wall, jobs))
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
