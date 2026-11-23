# Task: Medallions layout bugs — Tank meters off-screen on MacBook, 3:2 screens

Pre-existing Medallions defects found during #695 (list: `C:/Users/leeba/.cache/kstyleui-evidence/medallions-defects/pr-695-possible-bugs.md`; helper reports beside it). Fix these, highest first:
1. Tank damage and threat meters land about 88 units off-screen at 3456x2234 (MacBook Pro; render reference scene). Also check 3024x1964 and 2560x1600.
2. Tank on 3:2 screens caps below the shipped Interface size (0.80 at 2383x1540).
3. Raid warnings on 3:2 screens (DPS, Tank) sit 44% down the screen.
4. Edit Mode holds 13-14 of 16 buff icons (24 max), and Tank 4 of 6 bars, at 2383x1540 size 1 and at 16:10.
5. Action bar 3 (off by default) stands left of the casts across the central play band at 16:9.
6. The boss box (Layouts.Style 332.5 wide) holds the cards only; the debuff row hangs 94 units outside it.

Add 3456x2234 and 2383x1540 to your evidence sizes. PR: `fix(layout): Medallions fits MacBook and 3:2 screens`, `Fixed:` line.

**Rules**: minimal code, prefer deleting; Medallions pixel-identical to staging except where the fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, the module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `Core/Setup/Layouts.lua` (no new top-level locals), `Core/Layout/**`, `KstyleUI_Meters/**`, `KstyleUI_UnitFrames/**` (boss box only), `KstyleUI_ActionBars/**` (bar 3 placement only), `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `Tools/regression/**`, `Tools/render/**`.
