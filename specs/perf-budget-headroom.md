# Task: stop the test-perf 5x-headroom check from flaking on normal noise

**Goal**: `test-perf-frames` (and the other `test-perf*` files) pass reliably on the Mac CI runners; the fivefold headroom rule keeps catching real slowdowns but not run-to-run noise.

**Target**: KstyleUI, branch from the latest `origin/staging` (it has #422's CPU budgets). CI run 44000011724 shard 1 failed only `test-perf-frames`: UnitFrames target change measured 218 us against a 1050 us budget, 4.8x instead of the required 5x. #422 set five budgets to the measured minimums that satisfied 5x on one run (UnitFrames target change 1050, Skins quest update 6500, ActionBars pet cooldown 170, GroupFrames UNIT_FLAGS 45, Meters raid damage 2100), so normal variance of a few percent fails them. See `Tools/regression/README.md` (calibration) and `AGENTS.md` (Budget rule: `test-perf` budgets remain at least five times measured Lua 5.1 CPU time).

**Change**: set every `test-perf*` budget from measured data with a noise margin: budget >= 5 x the worst measured time across recent Mac CI runs x 1.25 (gather the per-path times from the last several staging/PR CI logs; record the numbers and run ids in `Tools/regression/README.md`). Keep the fivefold rule as is. Keep `LEE-5831` next to the Skins quest update budget. Do not touch addon code or other budgets.

**Playbook**: none.

**Constraints**: Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `test(regression): give the perf budgets noise headroom`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tests"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/regression/perf/*.lua` or wherever the `test-perf*` budgets live (say which), `Tools/regression/README.md`.

**Gate**: `bash scripts/gate.sh` (lint exit 0; `test-perf*.lua` pass natively, Windows skips headroom).

**Evidence of done**: the table of per-path worst times with run ids and the new budgets; two consecutive green `checks` runs on the draft PR (rerun the Lua jobs once) with `test-perf-frames` passing both times.

**Before worker_done**: Conventional Commits subjects. Report SHA, base SHA, PR URL, run ids and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
