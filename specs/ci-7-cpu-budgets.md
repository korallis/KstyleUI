# Task: CI PR 7: budget Lua test files by CPU time and peak memory, not wall time

**Goal**: a busy machine stops failing tests, the same budget verdict holds on the Mac runners and on Windows, and the Windows `lua` group can go green.

**Target**: KstyleUI, branch from `origin/staging` (it has #416's portable runner with `runner_platform.py` and #413's fs.lua). Plan: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md` section "R4: CPU-time and RSS budgets" and PR 7's row in section 4. The owner approved R4.

**Change** (plan R4):
- Budget of record: process CPU time (user + system) from `wait4` on POSIX and `GetProcessTimes` on Windows (through `runner_platform.py`), plus OS peak memory (`ru_maxrss` / `PeakPagefileUsage`) for the 4096 MB budget. Keep a wall-clock hang guard (about 120 s) everywhere.
- Interpreter rule: a budget verdict only when the run reports PUC Lua 5.1.5 (`_VERSION == "Lua 5.1"`, `jit == nil`); `luajit -joff` and `LUA=` overrides print "not budgeted".
- Calibration: measure per-file CPU time on both Mac runners (from a CI run's logs) and on this Windows PC; set the 20 s CPU budget from the Mac numbers; if Windows CPU time for a file exceeds the budget where the Mac passes, set a measured per-platform factor (never guessed) and record it in `Tools/regression/README.md`.
- Delete `CI_SLOWDOWN`, `SLOW_FIX`, `BIG_FIX` (`run_all.py`) and `TARGET_HEADROOM`/`onCI` in `perf_runner.lua`. The perf tests stay on wall time; on Windows `HeadroomProblem` is skipped with a printed note (MSVC `os.clock` measures wall time), so `test-perf*.lua` pass or skip honestly there.
- `test-lua-runtime.lua` fails by design on Windows because MSVC `rand()` differs from the Mac: decide with evidence between (a) a Windows Lua 5.1.5 build whose `math.random` matches the Mac, or (b) making the probe record the platform's sequence and fail only when a test that depends on `math.random` would diverge; implement the smaller correct one.
- AGENTS.md: replace the Windows "Known failing" Lua entry with the budget rule; `test-perf` budgets must stay at least 5 times the Lua 5.1 CPU time.

**Playbook**: none.

**Constraints**: stdlib only; Mac CI shard wall time unchanged within about 5%; never raise a budget to hide a slow file without the measured numbers. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. You may push your branch and open a **draft** PR against `staging`: title `test(regression): budget test files by CPU time and peak memory`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/regression/run_all.py`, `Tools/regression/runner_platform.py`, `Tools/regression/perf_runner.lua`, `Tools/regression/test-perf*.lua`, `Tools/regression/test-lua-runtime.lua`, `Tools/regression/README.md`, `Tools/tests/test_run_all.py`, `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Windows bar for this PR: `gate.sh lint` exit 0 and `gate.sh lua --affected origin/staging` exit 0 (or every remaining failure explained and owned by PR 6's Python scope).

**Evidence of done**: the calibration table (Mac runner A, Mac runner B, Windows CPU seconds for the 20 slowest files); a load test showing a CPU-bound file keeps its verdict under heavy parallel load where wall time would have failed; "not budgeted" printed under LuaJIT; `gate.sh lua` on Windows before and after; the draft PR's green `checks` run with shard wall times next to staging's.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
