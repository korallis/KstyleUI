# Task: test-pixel-grid-16 keeps going over its Mac CPU allowance

On the Mac mini `test-pixel-grid-16` used 33.76 and 33.86 CPU s against its 33 s allowance (staging run 44995167318, release run 45019088007), blocking releases. Split it (or make it cheaper) so each file stays comfortably under its allowance with margin under typical load, keeping every assertion; update `Tools/regression/weights.json` and `cpu_allowances.tsv` (remove the allowance if the parts fall under 16 s). Read `Tools/regression/README.md`. Prove on Mac CI with `gh workflow run checks.yml --ref <branch>`; report the new files' CPU seconds. PR `test(pixels): split pixel-grid-16 under the Mac budget`, label `no changelog`. Do not merge.

**Files it may edit**: `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run ids.
