# Task: set group-frame prediction ranges only when the max can change (perf fix 4 of 5)

**Goal**: in a 40-player raid, group frames stop calling `SetMinMaxValues` about 752 times a second; the bars look exactly the same.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_GroupFrames/Prediction.lua:161-196,216-220` (chained on `UNIT_HEALTH`); `Core/Widgets/StatusBar.lua:125-134`.

**Change**:
1. Move the four `SetBarRange(0, UnitHealthMax(unit))` calls out of the `UNIT_HEALTH` chain into the `UNIT_MAXHEALTH`, unit-change (roster update, frame unit swap) and full-refresh paths. Keep amount updates on `UNIT_HEALTH`. The max is a secret value: never compare it in Lua.
2. Find every path where the max can change without `UNIT_MAXHEALTH` (unit token reassignment, frame reuse, preview, test mode) and set the range there too. Grep the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; local clone `C:\Users\leeba\.cache\wow-ui-source`) for how Blizzard's CompactUnitFrame handles prediction ranges and name the file in the PR.
3. Behaviour test: drive health and max-health sequences (including a unit change and a max change) and assert bar values and ranges equal today's after every step. Add a raid-of-40 entry in `Tools/regression/perf/KstyleUI_GroupFrames.lua`.

**Pixel-proof scenes**: the party and raid group-frame scenes the feature map lists, in Frames, Orbs and Medallions.

**Files it may edit**: `KstyleUI_GroupFrames/Prediction.lua`, `Tools/regression/**`. Not `KstyleUI_GroupFrames/Style.lua` or `Preview.lua` (another task).

**Evidence of done**: `SetMinMaxValues`/s and addon ms/s before/after in the raid-40 scenario under lua5.1; behaviour test; pixel proof; green `checks` run.

**Owner constraint (binding)**: "We don't want to change how it looks at all, just optimise better." The rendered result must stay pixel-identical: no dropped pieces, no changed defaults, no simplified art. If a pixel differs anywhere, the change is wrong; fix it or stop and report.

**Pixel proof (required)**: render before (on the base SHA, e.g. a detached `git worktree` of `origin/staging` under `C:\Users\leeba\.cache\`) and after with `Tools/render/shoot.sh` (see AGENTS.md "App driver" and `docs/feature-map.md`) at `RENDER_SCREEN` 5120x1440 (`--ppu 1.3333333333`), 3456x2234 (`--ppu 2.0685185185`) and 1920x1080 (`--ppu 1`), and compare every PNG pair with a zero-tolerance pixel diff (Python + Pillow outside the repo is fine). Scenes: listed in the task above. Put the diff table (scene, variables, differing pixels = 0) in the PR body under `## Pixel proof`.

**Research**: the measured baseline and reasoning are in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md` (read the ranked-table row and the task section for this fix; its probes are in `C:\Users\leeba\.cache\kstyleui-perf-research\probes\`). Use PUC `lua5.1` for every timing, never LuaJIT.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 4-6 (the measurement is done) + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, secret values, combat lockdown, one event handler per owner, Forever API grep). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with `## Summary` (reference #443, the player's performance report), `## Changelog` (`Changed: ...` in player words), `## In-game checks`, `## Pixel proof`, `## Measurements` (before/after with the commands). Do not merge.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output, before/after numbers and the pixel-diff table.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
