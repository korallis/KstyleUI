# Task: fix the flaky test-widgets-kit allocation check on hosted Linux

`Tools/regression/test-widgets-kit.lua` fails intermittently on hosted Ubuntu CI with "chrome colour setters allocated 1.40625 KB" (seen on PR #745 run 45107913339 attempt 1, shard 6/8, and twice on PR #746 before head 0964a3214). It passes locally on Windows and on reruns. It looks sensitive to memory layout or GC timing, not a real allocation in the code.

Find the cause (pull the failing job logs with `gh run view --log-failed`), then make the check deterministic without weakening it: for example a full `collectgarbage("collect")` and a warm-up call before measuring, or measuring the median of several runs. If the code really does allocate on some path, fix the code instead. Prove it: run the test 50 times in a loop under PUC Lua 5.1 locally, and get two green hosted CI runs.

**Files it may edit**: `Tools/regression/test-widgets-kit.lua` and, only if the allocation is real, the setter in `Core/Widgets/**`.

**PR**: `test(widgets): make the chrome setter allocation check deterministic`, label `no changelog`. Do not merge.

**Constraints**: minimal code; Beast speed rule (no full local suite).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run ids and the cause.
