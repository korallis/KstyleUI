# Task: bring test-options-search under the Mac CPU budget

Staging Mac CI run 45114976737 (shard 5/5) failed: `FAIL test-options-search: used 22.05 CPU s, over the 20 CPU s budget. Make the test cheaper.` (machine load 4.9 on 12 CPUs). This blocks the v0.3.0 release. #741 (Options search that takes you there, synonyms, jump and highlight) and the other v0.3.0 PRs added Options rows and search work, so the test got heavier.

Measure the test under PUC Lua 5.1 on staging and on the commit before #741 to see what grew. Then make it cheaper without weakening any assertion: share one Options boot across cases instead of booting per case, or split the file at a natural seam into two files each well under 10 CPU s (as `groupframes_r3a.lua` H.boot does). If the addon code's search itself got slow (for example rebuilding the index on every keystroke), fix the code instead and say so; that would also be a player-facing speed fix.

**Files it may edit**: `Tools/regression/test-options-search*.lua`, a shared helper beside it, and `KstyleUI_Options/Model.lua` / `Window.lua` only if the search code itself is the cost.

**Proof**: local PUC Lua 5.1 CPU times before and after for each file; hosted CI green. Then run the changed test files on the Mac mini via `gh workflow run checks.yml --ref <branch>` is NOT needed; staging's Mac run after merge is the proof.

**PR**: `test(options): keep the search test under the CPU budget` (or `perf(options): ...` if code changed, with a `Fixed:` changelog line), label `no changelog` for test-only. Do not merge.

**Constraints**: minimal code; Beast speed rule.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and before/after CPU.
