# Task: Options preview fit counts the aura tile rim and sizes names after the final fit

Follow-up from PR #706: `KstyleUI_Options` Preview.Fit does not count the aura tile rim (0.6 units past the pane clip at 5120x1440), and the preview name is sized before the final Fit (esES 1080 name over its caps), which is why the preview cast gap had to stay 4 instead of the live 2. Fix the fit so the rim is in bounds and names are sized after the final fit, then set the target preview cast gap to the live 2 units. Keep test-pixel-grid-6/7 and the locale tests green. PR `fix(options): previews fit their pane exactly`, `Fixed:` line.

Both HUD styles exist (Medallions and Frames): fixes must hold in both. Pixel-identical unless the fix intends otherwise (prove with --strict renders or scene JSON at 1920x1080, 2560x1440, 5120x1440, 3840x2160). A regression test per fix that fails on staging. Lint, python, module tests, `test-perf*` (incl. `test-perf-fights`), `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted GitHub CI is the proof (no mid-task Mac runs). Minimal code. Do not merge. Before worker_done follow `C:/Users/leeba/orca-jev-router/WORKER.md`; report PR, SHA, run id.

**Files it may edit**: `KstyleUI_Options/**`, `KstyleUI_UnitFrames/Preview.lua`, `Tools/regression/**`, `Tools/render/**`.
