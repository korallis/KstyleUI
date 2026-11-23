# Task: filter UNIT_TARGETABLE_CHANGED to boss units (perf fix 5 of 5)

**Goal**: boss frames stop refreshing (60-67 us each time) for every unit whose targetable state changes; boss frames behave exactly as today.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_UnitFrames/Frames.lua:813-816` registers `UNIT_TARGETABLE_CHANGED` without a unit filter and runs `RefreshKind("boss", true)` and `Frames.MarkTargets()` for any unit.

**Change**:
1. Return early unless the unit is `boss1`-`boss8` (check the Forever source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`, local clone `C:\Users\leeba\.cache\wow-ui-source`, for `MAX_BOSS_FRAMES` and which tokens fire this event; name the file). Keep `INSTANCE_ENCOUNTER_ENGAGE_UNIT` as is. If `MarkTargets` must still run for some non-boss unit, prove why from the source and keep that path.
2. Behaviour test: the event for `raid7` or `nameplate3` does not refresh boss frames; for `boss1` it does, with the same resulting frame state as today. Add a perf entry in `Tools/regression/perf/KstyleUI_UnitFrames.lua` for a non-boss unit.

**Pixel-proof scenes**: the boss-frame scene and `hud_reference` per the feature map, in Frames, Orbs and Medallions.

**Files it may edit**: `KstyleUI_UnitFrames/Frames.lua`, `Tools/regression/**`.

**Evidence of done**: per-event us before/after under lua5.1; behaviour test; pixel proof; green `checks` run.

**Owner constraint (binding)**: "We don't want to change how it looks at all, just optimise better." The rendered result must stay pixel-identical: no dropped pieces, no changed defaults, no simplified art. If a pixel differs anywhere, the change is wrong; fix it or stop and report.

**Pixel proof (required)**: render before (on the base SHA, e.g. a detached `git worktree` of `origin/staging` under `C:\Users\leeba\.cache\`) and after with `Tools/render/shoot.sh` (see AGENTS.md "App driver" and `docs/feature-map.md`) at `RENDER_SCREEN` 5120x1440 (`--ppu 1.3333333333`), 3456x2234 (`--ppu 2.0685185185`) and 1920x1080 (`--ppu 1`), and compare every PNG pair with a zero-tolerance pixel diff (Python + Pillow outside the repo is fine). Scenes: listed in the task above. Put the diff table (scene, variables, differing pixels = 0) in the PR body under `## Pixel proof`.

**Research**: the measured baseline and reasoning are in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md` (read the ranked-table row and the task section for this fix; its probes are in `C:\Users\leeba\.cache\kstyleui-perf-research\probes\`). Use PUC `lua5.1` for every timing, never LuaJIT.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 4-6 (the measurement is done) + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, secret values, combat lockdown, one event handler per owner, Forever API grep). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with `## Summary` (reference #443, the player's performance report), `## Changelog` (`Changed: ...` in player words), `## In-game checks`, `## Pixel proof`, `## Measurements` (before/after with the commands). Do not merge.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output, before/after numbers and the pixel-diff table.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
