# Task: two player-visible layout bugs on staging

**1. Docked threat card overlaps HUD parts.** With Meters set to show damage and threat together ("Both"), the 250-unit threat card docked beside the damage card overlaps (measured on staging after #621, same for DPS/Tank/Healer, Orbs none):
- 1920x1080: Frames stance bar 15x96; Medallions bar 2 20x34 and XP strip 20x3.
- 2560x1440: Medallions bar 2 69x34 and XP strip 69x3.
- 3840x2160: Frames stance bar 15x96; Medallions bar 2 53x34 and XP strip 53x3.
- 5120x1440: none.

Fix the default place so the docked threat card clears every HUD element at all four sizes, in all three styles and layouts, with the smallest change (e.g. width or anchor of the docked slot). Saved positions the player moved stay where they are. Add the case to the Meters default-place check (`test-meters-parity-r1`'s HUD-clear check covers the second window and the story rail; extend it to the docked threat in Both) so it fails on today's staging.

**2. Options BAGS title clipped.** `shell_parity` at 2560x1440 and 5120x1440 exits 3 under `--strict`: the Options BAGS heading is clipped by 1.9 units. Find why (font, width or tracking at those sizes) and fix it so the heading fits everywhere; the scene passes `--strict` at all four sizes. Add a regression if a cheap one exists.

**Evidence**: before/after renders at all four sizes (`--strict`, game backdrop), and zero pixel change anywhere except the threat card and the heading. Lint, python, Meters and Options tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `fix(meters,options): ...`, with `Fixed:` changelog lines in player words. Do not merge.

**Files it may edit**: `KstyleUI_Meters/**`, `KstyleUI_Options/**`, `Core/Setup/Layouts.lua` (no new top-level locals), `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
