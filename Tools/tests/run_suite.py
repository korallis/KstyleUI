"""Run the Python suite one process per test file, a few at a time: run_suite.py [BASE] [--dir FOLDER] [--skip NAME]...

scripts/gate.sh starts this from the repository root. With BASE, a tool test in TOOL_TESTS runs only when its
tool, its own file or a suite helper changed against BASE; KSTYLEUI_RELEASE=1 (the release gate) or no BASE runs
every file. KSTYLEUI_PY_JOBS sets how many files run at once (4 by default). A file in WIDE starts several
processes of its own, so it runs alone, before the others. --skip leaves out a named file; pull request checks leave out
the render comparisons, which the nightly run keeps.
"""

import argparse
import fnmatch
import os
import re
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent

JOBS = 4
WIDE = ("test_affected.py", "test_render_deterministic.py", "test_run_all.py", "test_run_suite.py")
HELPERS = ("Tools/tests/run_suite.py", "Tools/tests/subprocess_budget.py")
TOOL_TESTS = {
    "test_affected.py": ("Tools/regression/*.py", "Tools/regression/run-all.sh", "Tools/regression/trace.lua",
                         "Tools/regression/fs.lua", "Tools/regression/load_files.lua"),
    "test_check_package.py": ("Tools/hooks/check-package.sh",),
    "test_check_pr.py": ("Tools/hooks/check-pr.sh", ".github/PULL_REQUEST_TEMPLATE.md"),
    "test_crlf.py": ("Tools/dev/crlf.py", ".gitattributes"),
    "test_gate.py": ("scripts/*", ".pre-commit-config.yaml", "Tools/regression/run-all.sh"),
    "test_link_addons.py": ("Tools/dev/link-addons.sh",),
    "test_run_all.py": ("Tools/regression/*.py", "Tools/regression/run-all.sh", "Tools/regression/cpu_allowances.tsv",
                        "Tools/regression/weights.json"),
    "test_run_suite.py": (),
}


def select(names, changes):
    """Return (names to run, tool tests left out). changes is {path: status}, or None to run every file."""
    if changes is None or any(path in changes for path in HELPERS):
        return list(names), []
    run, skipped = [], []
    for name in names:
        tools = TOOL_TESTS.get(name)
        if tools is None or "Tools/tests/" + name in changes or any(
                fnmatch.fnmatchcase(path, pattern) for path in changes for pattern in tools):
            run.append(name)
        else:
            skipped.append(name)
    return run, skipped


ALIVE = {"lock": threading.Lock(), "now": 0, "peak": 0}


def run_file(folder, name):
    with ALIVE["lock"]:
        ALIVE["now"] += 1
        ALIVE["peak"] = max(ALIVE["peak"], ALIVE["now"])
    try:
        return run_counted(folder, name)
    finally:
        with ALIVE["lock"]:
            ALIVE["now"] -= 1


def run_counted(folder, name):
    start = time.monotonic()
    done = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", str(folder), "-p", name],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    ran = re.search(r"^Ran (\d+) tests? in", done.stderr, re.MULTILINE)
    skips = re.search(r"^(?:OK|FAILED) \(.*?skipped=(\d+)", done.stderr, re.MULTILINE)
    return {"name": name, "ok": done.returncode == 0, "tests": int(ran.group(1)) if ran else 0,
            "skipped": int(skips.group(1)) if skips else 0,
            "seconds": time.monotonic() - start, "output": done.stdout + done.stderr}


def results(run, jobs, start):
    """Yield start(name) for each file: the WIDE ones one at a time, then the rest jobs at a time, in order."""
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        for name in run:
            if name in WIDE:
                yield start(name)
        yield from pool.map(start, [name for name in run if name not in WIDE])


def main(argv):
    parser = argparse.ArgumentParser(prog="run_suite.py", description="Run the Python suite.")
    parser.add_argument("base", nargs="?", help="leave out the tool tests whose tool is unchanged against this ref")
    parser.add_argument("--dir", default=str(HERE), help="the folder of test_*.py files (default Tools/tests)")
    parser.add_argument("--skip", action="append", default=[], metavar="NAME", help="leave out this test file")
    args = parser.parse_args(argv)
    folder = Path(args.dir)
    names = sorted(path.name for path in folder.glob("test_*.py"))
    unknown = [name for name in args.skip if name not in names]
    if unknown:
        parser.error("--skip names no test file: " + ", ".join(unknown))
    names = [name for name in names if name not in args.skip]
    if args.skip:
        print("python suite: left out {0} by request: {1}".format(len(args.skip), ", ".join(args.skip)), flush=True)
    changes = None
    if args.base and os.environ.get("KSTYLEUI_RELEASE") != "1":
        sys.path.insert(0, str(HERE.parent / "regression"))
        import affected
        try:
            changes = affected.changed_files(args.base)[1]
        except (OSError, RuntimeError) as error:
            print("python suite: cannot compare with {0} ({1}); running every test file".format(args.base, error))
    run, skipped = select(names, changes)
    jobs = int(os.environ.get("KSTYLEUI_PY_JOBS") or JOBS)
    print("python suite: {0} of {1} test files, {2} at a time".format(len(run), len(names), jobs), flush=True)
    if skipped:
        print("python suite: left out {0} tool tests whose tools did not change against {1}: {2}; "
              "the nightly run runs them all".format(len(skipped), args.base, ", ".join(skipped)), flush=True)
    start = time.monotonic()
    failed, tests, unchecked = [], 0, 0
    for result in results(run, jobs, lambda name: run_file(folder, name)):
        tests += result["tests"] - result["skipped"]
        unchecked += result["skipped"]
        if result["ok"]:
            print("ok   {0} ({1} tests, {2} skipped, {3:.1f} s)".format(
                result["name"], result["tests"] - result["skipped"], result["skipped"], result["seconds"]), flush=True)
        else:
            failed.append(result["name"])
            print("FAIL {0}\n{1}".format(result["name"], result["output"].rstrip()), flush=True)
    print("python suite: ran {0} tests and skipped {1} in {2} files in {3:.1f} s, at most {4} files at once; failed files: {5}".format(
        tests, unchecked, len(run), time.monotonic() - start, ALIVE["peak"], ", ".join(failed) or "none"))
    return 1 if failed or not run else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
