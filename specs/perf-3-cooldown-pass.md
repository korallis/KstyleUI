# Task: one cooldown pass per frame on the action bars (perf fix 3 of 5)

**Goal**: each global cooldown stops walking every action button twice (`SPELL_UPDATE_COOLDOWN` 73.5-77 us plus `ACTIONBAR_UPDATE_COOLDOWN` 26.5-27.5 us over 48 buttons) and empty buttons stop clearing an already clear cooldown (171 `Cooldown:Clear` calls/s in a rogue fight); every sweep, charge ring and flash looks exactly the same.

**Target**: KstyleUI on the latest `origin/staging` (includes #445 /kb). `KstyleUI_ActionBars/Module.lua:274-291,366-367`; `KstyleUI_ActionBars/Button.lua:126-164`; `Core/Widgets/IconButton.lua` (`ClearCooldown`, `ClearChargeCooldown`).

**Change**:
1. Run the trusted pass (`OnSpellCooldown`) for whichever of `SPELL_UPDATE_COOLDOWN` and `ACTIONBAR_UPDATE_COOLDOWN` comes first in a `GetTime()` frame, and return early for the second, only if both events read the same state within one frame (check the Forever UI source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`, local clone `C:\Users\leeba\.cache\wow-ui-source`, for when each fires; name the files). If one of them can carry state the other cannot, keep that path.
2. Skip `ClearCooldown` and `ClearChargeCooldown` when KstyleUI's own Lua-side state says the cooldown is already clear (keep that state yourself; never read it back from the Cooldown region). Any path that sets a cooldown must mark it not clear.
3. Tests: a behaviour test for cooldown, charge and GCD flag state after the pair (in both orders, and when only one fires), compared to today's; a perf entry in `Tools/regression/perf/KstyleUI_ActionBars.lua` firing the pair.

**Pixel-proof scenes**: `hud_reference` in combat in Frames, Orbs and Medallions (cooldown sweeps visible), and the action-bar scenes the feature map lists.

**Files it may edit**: `KstyleUI_ActionBars/Module.lua`, `KstyleUI_ActionBars/Button.lua`, `Core/Widgets/IconButton.lua` (the cleared flag only), `Tools/regression/**`.

**Evidence of done**: per-GCD us and Clear calls/s before/after under lua5.1; behaviour test; pixel proof; green `checks` run.

**Owner constraint (binding)**: "We don't want to change how it looks at all, just optimise better." The rendered result must stay pixel-identical: no dropped pieces, no changed defaults, no simplified art. If a pixel differs anywhere, the change is wrong; fix it or stop and report.

**Pixel proof (required)**: render before (on the base SHA, e.g. a detached `git worktree` of `origin/staging` under `C:\Users\leeba\.cache\`) and after with `Tools/render/shoot.sh` (see AGENTS.md "App driver" and `docs/feature-map.md`) at `RENDER_SCREEN` 5120x1440 (`--ppu 1.3333333333`), 3456x2234 (`--ppu 2.0685185185`) and 1920x1080 (`--ppu 1`), and compare every PNG pair with a zero-tolerance pixel diff (Python + Pillow outside the repo is fine). Scenes: listed in the task above. Put the diff table (scene, variables, differing pixels = 0) in the PR body under `## Pixel proof`.

**Research**: the measured baseline and reasoning are in `C:\Users\leeba\.cache\kstyleui-perf-research\REPORT.md` (read the ranked-table row and the task section for this fix; its probes are in `C:\Users\leeba\.cache\kstyleui-perf-research\probes\`). Use PUC `lua5.1` for every timing, never LuaJIT.

**Playbook**: perf -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\perf-issue.md` steps 4-6 (the measurement is done) + `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\benchmark-checklist\SKILL.md`. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, secret values, combat lockdown, one event handler per owner, Forever API grep). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging` with `## Summary` (reference #443, the player's performance report), `## Changelog` (`Changed: ...` in player words), `## In-game checks`, `## Pixel proof`, `## Measurements` (before/after with the commands). Do not merge.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output, before/after numbers and the pixel-diff table.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
