# Task: test-options-preview-content-locales over its Mac CPU budget

Mac CI (run 44988069912, on PR #700's branch from staging c3a1538f5) fails `test-options-preview-content-locales: used 23.35 CPU s, over the 20 CPU s budget` (23.06 on a rerun). Split it into two or more files that each stay well under 20 CPU s on the Mac (as `groupframes_r3a.lua` H.boot / the parity-r4 split did), keeping every assertion; or make it cheaper without dropping checks. Update `Tools/regression/weights.json` and `cpu_allowances.tsv` if the split needs it. Read `Tools/regression/README.md` for calibration.

Prove it on Mac CI: push the branch and run `gh workflow run checks.yml --ref <branch>`; report the run id with the new files' CPU seconds. PR to `staging`: `test(options): split the preview locale test under the Mac CPU budget`, label `no changelog`. Do not merge.

**Files it may edit**: `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run ids.
