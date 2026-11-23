# Task: Group frames Options raid preview overlap ("Orrin")

The Group frames Options page raid preview fails `--strict` at 1920x1080: a sample name ("Orrin") overlaps a neighbouring element (LumenShape) in the raid preview. It has failed on staging for several rounds (seen by the #630, #642 and #654 workers). Reproduce with the Group frames Options scene at 1920x1080, find the cause (sample text, cell size or ornament placement in `KstyleUI_GroupFrames/Preview.lua`), and fix it with the smallest change so the Options renders pass `--strict` at all four sizes. Live frames unchanged (0-pixel HUD diffs). Remove any guard allow line that only existed for this. Regression if cheap. Lint, python, Group frames tests, `test-taint-scan`, `test-perf-path-budgets`; hosted CI green. One PR to `staging`, `fix(groupframes): ...`. Do not merge.

**Files it may edit**: `KstyleUI_GroupFrames/Preview.lua`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
