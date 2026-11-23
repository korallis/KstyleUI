# Task: 3:2 raid warnings, Edit Mode viewer room and the boss debuff row (option A, HUD pixels unchanged)

The owner chose to keep the HUD's polish (no boss column move). From PR #702's "Follow-up for the owner" (read it: `gh pr view 702`): do **option A** — keep every HUD pixel as it is and fix the overlays instead:
- 3: raid warnings on 3:2 (3456x2234, 3024x1964, 2383x1540) sink 44% down under the boss box. Narrow the warnings lane (`EditMode.WARNING_LANE` 580 and the skin's frame width) where the root is under ~2025 units so it fits between the chat card and the boss box at the top of the band.
- 4: Edit Mode tracked viewers: add a second tracked-buff spot (two rows over the casts) so 16 buff icons fit at size 1, and a bar-viewer spot clear of the threat card's solo spot so Tank's 6 bars fit at 2383x1540 and 16:10.
- 6: the boss debuff row hangs 96 units outside the boss box: make Fits, Edit Mode and the warnings lane count the debuff row's real footprint (without moving the boss cards); narrow the 3:2 lane further only as needed.
- The 3024x1964 cap (0.8395 vs 0.8421): fix only if it falls out of the above without moving HUD elements; else leave it documented.

Default HUD pixel-identical to staging at every size. PR: `fix(layout): raid warnings and Edit Mode fit 3:2 screens`, `Fixed:` line.

**Rules**: minimal code; one forged look; prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160 plus 3456x2234 and 2383x1540; saved positions respected; regression tests that fail on staging; lint, python, module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `Core/Setup/EditMode.lua`, `Core/Setup/Layouts.lua` (no new top-level locals), `KstyleUI_Skins/**` (the warnings skin only), `KstyleUI_UnitFrames/**` (boss footprint reporting only), `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.
