# Task: bar edge marker draws over the health text

In the Medallions HUD (seen in `docs/media/marketing/show_crop_dock.jpg`, the hud_reference render), the player health bar's white edge marker (spark or fill-edge line at the health fraction) is drawn over the health text "2.7K / 3.3K". Text must always read above bar decorations. Reproduce at default settings in Frames, Orbs and Medallions at all four sizes (player, target, focus, party/raid where bars carry text), find where the marker's draw layer or frame level sits above the text, and fix it with the smallest change (layer/sublevel or text parent level) so text sits above every bar decoration. Only the marker/text stacking may change: show before/after crops at four sizes; nothing else moves. Regression in the stubs (draw order: text above the marker) that fails today. Lint, python, unit/group frame tests, `test-taint-scan`, `test-perf-path-budgets`; hosted CI green. One PR to `staging`, `fix(unitframes): ...`, `Fixed:` changelog line. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_GroupFrames/**`, `Core/Widgets/**` (only if the marker lives there), `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
