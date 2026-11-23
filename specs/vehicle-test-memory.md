# Task: bring test-actionbars-vehicle.lua under the 4096 MB per-file memory budget

**Goal**: the vehicle regression test (added by merged #423) passes the memory budget natively on Windows as well as on the Macs, without losing any assertion.

**Target**: KstyleUI, branch from the latest `origin/staging`. `Tools/regression/test-actionbars-vehicle.lua` peaks at 4268 MB on Windows (`PeakPagefileUsage`) against the 4096 MB budget in a native full-gate run on top of PR #422; it passes on the Mac CI runners. It boots the ActionBars environment for many style x screen x state cases.

**Change**: find where the memory goes (likely a fresh stub environment per case kept alive, render tables, or one process holding every case) and reduce it: release each case's environment before the next (drop references, `collectgarbage("collect")`), share what can be shared, or split the file into two or three files by HUD style if one process cannot hold all cases under the budget. Keep every case and assertion. Report the peak before and after on Windows (through `bash Tools/regression/run-all.sh Tools/regression/test-actionbars-vehicle.lua` or the runner's per-file report) and the CPU time.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 1-4 + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`; use Windows equivalents for Linux-only tools. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: never raise the memory budget or weaken a verdict; do not edit the runner. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. You may push your branch and open a **draft** PR against `staging`: title `test(actionbars): keep the vehicle test under the memory budget`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tests"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/regression/test-actionbars-vehicle*.lua`, plus `Tools/regression/` env helpers only if the leak is there (say which).

**Gate**: `bash scripts/gate.sh` (Windows: `gate.sh lint` exit 0 and the vehicle test(s) pass under `lua5.1` within 20 CPU s and 4096 MB).

**Evidence of done**: peak memory and CPU time before and after on Windows; assertion count before and after (equal or higher); the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
