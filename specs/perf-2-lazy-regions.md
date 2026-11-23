# Task: build widget chrome, glow shadows and slot state layers on first use (perf fix 2 of 5)

**Goal**: about 16,000 textures and font strings that are created and never drawn (against 1,300-1,850 drawn) are no longer created until needed, cutting memory and load time, with every rendered pixel unchanged.

**Target**: KstyleUI on the latest `origin/staging`. `Core/Widgets/Base.lua:1340-1374` (`Widgets.Chrome`: 4 nine-slices = 36 textures, bevel and header at `:1660-1669`, gilt ticks at `:1332`); `Core/Widgets/Glow.lua:230` (a shadow nine-slice per glow); `Core/Widgets/Slot.lua:29,327,343` (press, hover and proc rings, halos and washes per slot); `Core/Widgets/Overflow.lua:108`.

**Change**:
1. Create a Chrome's nine-slices, ticks and bevel the first time the owner is shown or restyled while visible, not in `Widgets.Chrome`. Create the glow shadow slice on the first `Start`. Create a slot's hover, press and proc layers on first hover, press or proc.
2. Draw-order trap: textures on the same layer and sublevel draw in creation order. Keep each group created as one unit in its original order, or give each piece an explicit sublevel that reproduces today's order exactly. Every later setter (colour, alpha, size, texture, restyle) that today targets an eager region must reach a lazily built one too: record the wanted state and apply it on build, never read it back from regions.
3. Secure frames: never create regions on, or show, protected frames in combat in a way the client refuses; check what the stubs raise.
4. Do not touch `Widgets.ApplyFont` or other font code in `Base.lua` (another task is editing it); rebase on staging before opening the PR if it moved.
5. New `Tools/regression/test-widgets-lazy.lua`: a created-region-count assertion (baseline from the report's p3 probe), and a state-equality test: a widget built lazily then shown, hovered, pressed, proc'd and restyled ends with region states (points, sizes, textures, colours, alpha, layer, sublevel, shown) equal to an eagerly built one.

**Pixel-proof scenes**: `hud_reference` in Frames, Orbs and Medallions, idle and in combat (the feature map names the combat variable), plus `gallery_options` and the tooltip and databar scenes the feature map lists.

**Files it may edit**: `Core/Widgets/Base.lua` (Chrome, NewSlice, NewTicks, bevel and header build only), `Core/Widgets/Glow.lua`, `Core/Widgets/Slot.lua`, `Core/Widgets/Overflow.lua`, `Tools/regression/**`.

**Evidence of done**: created-region counts before/after per module at 5120x1440; state-equality test green; pixel proof; green `checks` run.

**Owner constraint (binding)**: "We don't want to change how it looks at all, just optimise better." The rendered result must stay pixel-identical: no dropped pieces, no changed defaults, no simplified art. If a pixel differs anywhere, the change is wrong; fix it or stop and report.

**Pixel proof (required)**: render before (on the base SHA, e.g. a detached `git worktree` of `origin/staging` under `C:\Users\leeba\.cache\`) and after with `Tools/render/shoot.sh` (see AGENTS.md "App driver" and `docs/feature-map.md`) at `RENDER_SCREEN` 5120x1440 (`--ppu 1.3333333333`), 3456x2234 (`--ppu 2.0685185185`) and 1920x1080 (`--ppu 1`), and compare every PNG pair with a zero-tolerance pixel diff (Python + Pillow outside the repo is fine). Scenes: listed in the task above. Put the diff table (scene, variables, differing pixels = 0) in the PR body under `## Pixel proof`.

**Research**: the measured baseline and reasoning are in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md` (read the ranked-table row and the task section for this fix; its probes are in `C:\Users\leeba\.cache\kstyleui-perf-research\probes\`). Use PUC `lua5.1` for every timing, never LuaJIT.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 4-6 (the measurement is done) + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, secret values, combat lockdown, one event handler per owner, Forever API grep). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with `## Summary` (reference #443, the player's performance report), `## Changelog` (`Changed: ...` in player words), `## In-game checks`, `## Pixel proof`, `## Measurements` (before/after with the commands). Do not merge.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output, before/after numbers and the pixel-diff table.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
