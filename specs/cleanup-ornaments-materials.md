# Task: delete the dead forged ornaments and card materials (follow-ups 1 and 3 of #695)

KstyleUI is Medallions only (#695 merged). Its PR body lists follow-ups: (1) forged ornaments (Core/Widgets/Ornaments.lua, OrnamentData/Ink, the 219 textures in Media/Textures/ForgedOrnaments, Widgets "ornaments" setting remnants, Tools/media/ornaments.py, ornament_ink.py, painted_ornaments.py, their Python tests and ~80 Lua tests) and (3) card-material frames and grain (Tokens.Material, forgedFrame/bracket art). The visible settings are already gone. First prove each is unreachable under Medallions (no Medallions code path calls it; show the grep), then delete the code, art, tools, tests and docs that only they use. Keep anything Medallions reaches. Saved keys they used: drop via the existing retired-keys path from #695.

PR to `staging`: `refactor: remove the dead forged ornaments and card materials`, label `no changelog` (no player-visible change). Report lines and bytes removed.

**Rules**: minimal code, prefer deleting; Medallions pixel-identical to staging except where the fix intends (prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160); a regression test per fix that fails on staging; lint, python, the module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: any addon file, `Media/**`, `Core/**`, `Tools/media/**`, `Tools/tests/**`, `Tools/regression/**`, `Tools/render/**`, `docs/**`.
