# Task: Minimap preview restyle is path-dependent

Found by the #635 fixer (evidence: `C:/Users/leeba/.cache/kstyleui-evidence/author-635/fix`): the Minimap preview in Options keeps piece sizes from an earlier layout pass. Scaling it down and back up does not restore the button and ring sizes (every resized piece stays x1.1083; button 25.69 vs 23.64). Check whether the live minimap restyle has the same path dependence (resize the HUD scale or screen size down and back).

Fix it with the smallest change so any sequence of sizes ends in the same result as a fresh build. Regression that fails on staging (down-then-up equals fresh). Default renders pixel-identical at all four sizes; Minimap tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; lint, python; hosted CI green. One PR to `staging`, `fix(minimap): ...`, a `Fixed:` line if players can see it. Do not merge.

**Files it may edit**: `KstyleUI_Minimap/**`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
