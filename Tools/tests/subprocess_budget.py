"""Captured test commands with child CPU accounting and a separate hang guard."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

from Tools.regression import runner_platform


def hang_limit(cpu_budget):
    return max(120, 5 * cpu_budget) if cpu_budget is not None else 120


def run(command, *, cpu_budget, input=None, text=True, capture_output=True, **kwargs):
    if not text or not capture_output:
        raise ValueError("budgeted test commands require text=True, capture_output=True")
    executable = Path(command[0]).name.lower()
    if executable.startswith("luajit") or (executable.startswith("lua") and "LUA" in os.environ):
        cpu_budget = None
    limit = hang_limit(cpu_budget)
    start = time.monotonic()
    stopped = threading.Event()
    with (tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace") as source,
          tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace") as out,
          tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace") as err):
        if input is not None:
            source.write(input)
        source.seek(0)
        child = subprocess.Popen(command, stdin=source, stdout=out, stderr=err,
                                 start_new_session=os.name != "nt", **kwargs)

        def stop():
            stopped.set()
            runner_platform.kill(child)

        timer = threading.Timer(limit, stop)
        timer.start()
        try:
            _, cpu = runner_platform.wait(child)
        except BaseException:
            runner_platform.kill(child)
            child.wait()
            raise
        finally:
            timer.cancel()
            timer.join()
        wall = time.monotonic() - start
        out.seek(0)
        err.seek(0)
        result = subprocess.CompletedProcess(command, child.returncode, out.read(), err.read())
    result.cpu_seconds, result.wall_seconds = cpu, wall
    usage = f"cpu={cpu:.3f} s" if cpu is not None else "cpu=n/a"
    usage += f" wall={wall:.3f} s; "
    usage += f"budget={cpu_budget:g} CPU s" if cpu_budget is not None else "not budgeted"
    print(f"usage: {command[0]} {usage}", flush=True)
    if stopped.is_set():
        raise AssertionError(f"hang guard: stopped after {limit:g} wall s; {usage}\n{result.stdout}{result.stderr}")
    if cpu_budget is not None and cpu is None and os.environ.get("CI") == "true" and sys.platform == "darwin":
        raise AssertionError(f"Cannot measure child CPU time: {usage}. Restore child CPU accounting.")
    if cpu_budget is not None and cpu is not None and cpu > cpu_budget:
        message = f"CPU budget exceeded: {usage}. Make the test cheaper.\n{result.stdout}{result.stderr}"
        if os.environ.get("CI") == "true" and sys.platform == "darwin":
            raise AssertionError(message)
        print("WARN " + message, file=sys.stderr, flush=True)
    if result.returncode:
        result.stderr += f"\n{usage}\n"
    return result
