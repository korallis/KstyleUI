# Task: nothing on screen overlaps or is out of reach, and a test keeps it that way

**Goal**: a tester (0xDAB, 2026-11-19, after v0.2.6): "UI layouts especially: sometimes things overlap and are almost not reachable." The owner found the minimap clipping at 5120x1440 the same day. Build the lever: one layout test that fails on any overlap or unreachable element. Then fix what it finds.

**Target**: KstyleUI on latest `origin/staging`; the layout and render tests (`Tools/regression/test-hud-*`, `test-setup-layouts*`, `Tools/render/scenes/hud_reference.lua`, `Core/Setup/Layouts.lua`).

**Change**:
1. A regression test that sets up the full HUD with every module on, then checks the placed bounds of every element. It covers every combination of:
   - HUD style: Frames, Orbs or Medallions;
   - layout: DPS, Tank or Healer;
   - arrangement: Centred or Spread;
   - screen: 1920x1080, 2560x1440, 5120x1440 or 3840x2160, plus the other sizes the layout tests already use.

   For each element it asserts that:
   - (a) it lies inside the screen with the HUD's edge margin, including ornaments, plaques and overhangs;
   - (b) no two elements overlap, except pairs on an explicit, commented allow list (deliberate stacking);
   - (c) clickable parts are not covered by another element.

   Its failure message names the element pair and the fix.
2. Run it and list every failure, then fix them in the fewest lines by moving defaults only. Players' saved positions are kept unless they are off screen; in that case, clamp them on screen.
3. Wire the test into the normal suite so CI runs it, and add it to the Gate.

**Options**: placement fixes need no setting.

**Constraints**: minimal code; no new top-level local in `Core/Setup/Layouts.lua`; one consistent style. Another worker is fixing the minimap edge (#485) and the meters placement (damage/threat side by side): keep to other elements, and include those two in the test's checks. Open a **draft** PR against `staging`: `fix(layout): nothing overlaps or leaves the screen`, `## Summary` (the failures found and fixed), `## Changelog` (`Fixed: HUD parts no longer overlap or sit out of reach on any screen size.`), `## Before and after` (renders of each fix at the sizes where it failed). Do not merge.

**Files it may edit**: `Core/Setup/Layouts.lua`, `Core/Setup/EditMode.lua`, `Core/Store.lua` (one migration if defaults move), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the layout tests locally; green Mac CI is the full proof.

**Evidence of done**: the failure list before, the test red then green, the renders, and the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
