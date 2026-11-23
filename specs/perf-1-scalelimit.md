# Task: make the HUD scale search cheap; the result stays bit-identical (perf fix 1 of 5)

**Goal**: login, /reload, UI-scale, display-size and HUD-style changes stop spending 31-155 ms of Lua and 15-82 MB of garbage in the cold `Layouts.ScaleLimit` search, with the returned scale bit-identical.

**Target**: KstyleUI on the latest `origin/staging`. `Core/Scale.lua:151,187` calls `Layouts.ScaleLimit`; `Core/Setup/Layouts.lua:1297-1350` (search), `:1165` (`Fits`), `:598-633` (`Story`), `:513-523` (`Get`).

**Change**:
1. In `Layouts.Story`, index the module-local `layouts[name]` instead of `Layouts.Get` (which copies). Keep `Get` copying for its other callers: a prototype that handed the stored table to everyone changed later results.
2. Memoise `Story` per exact `(name, rootHeight, guide, style, rootWidth, shown)` inside one `ScaleLimit` call.
3. Make `Layouts.Fits` allocation-free: reuse scratch arrays for `rects` and `boxes`; compute per-element footprints, `Aspect`, `Style` and `StyleSize` once per search; avoid the `Ties` closures.
4. Add no top-level local to `Layouts.lua` (`test-layouts-locals.lua`): put new state on `Layouts` or in `do` blocks.
5. New `Tools/regression/test-scalelimit-identity.lua`: a fixture copy of the previous implementation vs the new one for every preset x {frames, orbs, medallions} x {5120x1440, 3440x1440, 3456x2234, 2560x1440, 1920x1080}, asserting `string.format("%.17g")` equality. Add a perf entry in `Tools/regression/perf/Core.lua` with a time budget and 0 B on addon lines (budget at least 5x measured Lua 5.1 CPU time, per AGENTS.md).

**Pixel-proof scenes**: `hud_reference` with `RENDER_HUD_STYLE` Frames, Orbs and Medallions, `RENDER_LAYOUT=DPS`, `RENDER_SIZE=auto`, both `RENDER_ARRANGEMENT` values.

**Files it may edit**: `Core/Setup/Layouts.lua`, `Core/Scale.lua` (only if needed), `Tools/regression/**`.

**Evidence of done**: identity test green; before/after time and garbage per cold call under lua5.1 at 5120x1440 and 3456x2234 for all three styles; pixel proof; green `checks` run.

**Owner constraint (binding)**: "We don't want to change how it looks at all, just optimise better." The rendered result must stay pixel-identical: no dropped pieces, no changed defaults, no simplified art. If a pixel differs anywhere, the change is wrong; fix it or stop and report.

**Pixel proof (required)**: render before (on the base SHA, e.g. a detached `git worktree` of `origin/staging` under `C:\Users\leeba\.cache\`) and after with `Tools/render/shoot.sh` (see AGENTS.md "App driver" and `docs/feature-map.md`) at `RENDER_SCREEN` 5120x1440 (`--ppu 1.3333333333`), 3456x2234 (`--ppu 2.0685185185`) and 1920x1080 (`--ppu 1`), and compare every PNG pair with a zero-tolerance pixel diff (Python + Pillow outside the repo is fine). Scenes: listed in the task above. Put the diff table (scene, variables, differing pixels = 0) in the PR body under `## Pixel proof`.

**Research**: the measured baseline and reasoning are in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md` (read the ranked-table row and the task section for this fix; its probes are in `C:\Users\leeba\.cache\kstyleui-perf-research\probes\`). Use PUC `lua5.1` for every timing, never LuaJIT.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 4-6 (the measurement is done) + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, secret values, combat lockdown, one event handler per owner, Forever API grep). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with `## Summary` (reference #443, the player's performance report), `## Changelog` (`Changed: ...` in player words), `## In-game checks`, `## Pixel proof`, `## Measurements` (before/after with the commands). Do not merge.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output, before/after numbers and the pixel-diff table.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
