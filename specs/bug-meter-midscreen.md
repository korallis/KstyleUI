# Task: the damage meter draws in the middle of the screen in hud_reference on staging

**Goal**: on current `origin/staging` (9e91fddd or later), the `hud_reference` render (Medallions, DPS, 1920x1080, `--ppu 1`, with or without `RENDER_SIZE=auto`) draws the damage meter mid-screen, over the nameplates: `meters.damage` sits at about x 1132, y 490. A minimap mockup worker spotted it. Find out whether this is a real regression, most likely from #500 ("damage and threat side by side") or the layout overlap guard's display clamp in `Core/Layout/Layout.lua`, or only a scene artefact. Fix it so the meter sits where the layout puts it.

**Steps**:
1. Render `hud_reference` at the four sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160) in all three HUD styles. Do the same on the commit before #500 (`git log --oneline -8 origin/staging`) and compare where the meter lands.
2. Find the cause and cite it with file:line. Check whether players' saved positions and fresh installs are both affected.
3. If it is a real bug, fix it with the smallest change and add a regression test that fails on the bug: the meter's rect at each size and style is where the layout preset puts it, clear of the nameplate band. If it is only a scene artefact, fix the scene.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/meter-midscreen/`). Open a **draft** PR against `staging` titled `fix(meters): ...` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after` (local paths). Do not merge.

**Files it may edit**: `KstyleUI_Meters/**`, `Core/Layout/**`, `Core/Setup/Layouts.lua` (no new top-level local), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id, cause and render paths.
