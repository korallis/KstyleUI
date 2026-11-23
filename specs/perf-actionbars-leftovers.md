# Task: action bar leftovers — crown pips, crest repaint, target-change rewrites

From #722's report: the crown pips write 5 times per form change, the slab crest repaints on every loading screen, and PLAYER_TARGET_CHANGED rewrites jewels and pet buttons that did not change. Make each do nothing when its inputs did not change. PR `perf(actionbars): crowns, crest and target changes do no repeat work`, label `no changelog` unless players feel it.

Both HUD styles exist (Medallions and Frames): fixes must hold in both. Pixel-identical unless the fix intends otherwise (prove with --strict renders or scene JSON at 1920x1080, 2560x1440, 5120x1440, 3840x2160). A regression test per fix that fails on staging. Lint, python, module tests, `test-perf*` (incl. `test-perf-fights`), `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted GitHub CI is the proof (no mid-task Mac runs). Minimal code. Do not merge. Before worker_done follow `C:/Users/leeba/orca-jev-router/WORKER.md`; report PR, SHA, run id.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_UnitFrames/Pips.lua`, `Core/Widgets/ClassPip.lua`, `Tools/regression/**`.
