# Task: test_render_size no longer times out on a loaded Windows machine

**Goal**: three workers in one day hit the same failure in the native Python gate on Beast: two `Tools/tests/test_render_size.py` cases time out (fixed 90 s and 60 s subprocess timeouts around PUC Lua render runs) when other agents load the machine, and the same cases time out on unchanged staging. The gate must give a real answer under load without hiding hangs.

**Target**: KstyleUI on the latest `origin/staging`. `Tools/tests/test_render_size.py` and whatever helper launches its Lua subprocesses; the Lua runner's own CPU-time and hang-guard policy (AGENTS.md "Budget rule": CPU budgets count CPU seconds, the wall-clock hang guard is max(120 s, five times the CPU limit)); `Tools/regression/run_all.py` and `Tools/regression/README.md` for the existing approach.

**Change**: make these subprocess limits follow the repository's own budget rule: measure the child's CPU time rather than wall time where the OS allows (as run_all.py already does), keep a wall-clock hang guard of at least max(120 s, five times the CPU budget), and print the measured CPU and wall time when a case fails so a hang and a slow machine are told apart. Do not raise budgets for real slowness: if a case genuinely needs more CPU than its budget under Lua 5.1, report it. Find any other Python test with a fixed short wall-clock subprocess timeout and treat it the same way. The error message names the fix ("CPU budget exceeded" vs "hang guard").

**Constraints**: the gate's meaning stays the same on Mac CI. Python files in `Tools/` use LF. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with the `no changelog` label: title `test(render): CPU budgets, not wall clocks, for render-size subprocesses`, `## Summary`, `## Decisions`. Do not merge.

**Files it may edit**: `Tools/tests/**`, `Tools/regression/run_all.py` and its helpers only if shared code is reused, `Tools/regression/README.md`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: `bash scripts/gate.sh python` passes on Beast while other workers load the machine (report the load at the time), and a deliberately hung child is still caught by the hang guard (test); the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and Gate output.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
