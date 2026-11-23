# Task: research why KstyleUI feels heavy in game, and rank the fixes (read-only)

**Goal**: a measured, ranked list of KstyleUI's biggest in-game CPU and memory costs, with a concrete fix for each, so the owner can fix "it takes a lot of resources ... I had to disable all my other addons ... yours is a monster" (player on CurseForge and GitHub #443: i7-14700K, RTX 5070 Ti, 32 GB, Samsung Odyssey ultrawide, likely 5120x1440, rogue). The owner sees about 250 fps on his own machine.

**Target**: KstyleUI on the latest `origin/staging`. Change no files in the repository; write your report and scratch only under `C:\Users\leeba\.cache\kstyleui-perf-research\`.

**Change** (research):
1. Inventory every per-frame and high-frequency path: `OnUpdate` scripts and `C_Timer` tickers (grep all modules), handlers for frequent events (`UNIT_AURA`, `UNIT_HEALTH`, `UNIT_POWER_*`, `COMBAT_LOG_EVENT_UNFILTERED`, `SPELL_UPDATE_COOLDOWN`, `ACTIONBAR_UPDATE_*`, `NAME_PLATE_UNIT_*`, `UPDATE_MOUSEOVER_UNIT`, `BAG_UPDATE*`), animation groups that loop, layout passes that run on events (re-layout of whole HUD), and anything that allocates tables or strings per call in those paths. Note the file and line, how often it runs (per frame, per event, per unit), and what it does.
2. Measure: use the existing perf harness (`Tools/regression/perf_runner.lua`, `test-perf*.lua`, `Tools/regression/perf/*.lua`) and write throwaway probes outside the repo to time the hot paths under PUC Lua 5.1 with realistic loads (a 25- and 40-player raid, 20 nameplates, a busy combat log, a rogue in stealth with many auras, the Medallions HUD with effects at Full). Measure Lua memory growth per minute of simulated combat (garbage churn), since GC pauses read as "heavy".
3. Check ultrawide-specific costs: anything that scales with screen width or pixel count at 5120x1440 (pixel snapping, ornaments, re-measuring on every update).
4. Check the Medallions effects (3D models, particles, looping animations) and their "Motion" setting defaults: what runs when idle.
5. Report in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md`: a ranked table (path, file:line, frequency, measured cost, why, proposed fix, expected saving, risk), the top 5 fixes as separate implementable task descriptions with the files each touches (so they can run as separate PRs without overlapping files), and any setting a player can change today to reduce the cost.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 1-4 + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`; use Windows equivalents for Linux-only tools. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: read-only for the repository; no PR. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH. Use PUC `lua5.1` for timings (not LuaJIT).

**Files it may edit**: none in the repository.

**Gate**: none (read-only).

**Evidence of done**: the REPORT.md with every number traced to a command you ran.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the report path and the top five findings.
