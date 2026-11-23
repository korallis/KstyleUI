# Task: make the consumables clearance tests fit the Mac CPU budget (staging CI is red)

**Problem**: staging pushes run the Mac CPU budget of record: 20 CPU s per test file, fatal. These fail intermittently:
- `test-consumables-clearance-orbs-tank`: 20.78-21.20 s;
- `test-consumables-clearance-tank`: 20.77-20.90 s;
- `test-consumables-clearance-healer`: 20.03-20.23 s.

They failed on staging runs 44719957397, 44725301296, 44727010547 and 44729595758, and their siblings are probably close behind. Hosted PR shards only warn, which is how this got through. Read `Tools/regression/README.md` (budgets and calibration) and `Tools/regression/consumables_clearance_lib.lua`.

**Fix**: make these tests cheaper; **do not** raise budgets or add allowances.
- Profile where the CPU goes in the shared lib, for example repeated full boots per screen size or HUD style, redundant layout applies, or per-pixel scans.
- Remove the waste, for example by booting once per file and reusing it across screen sizes, or caching footprints. Every assertion must still be checked; do not drop coverage.
- If one file is inherently big, split it along a natural seam (by screen sizes, for example) so each file has clear headroom.
- **Target:** every `test-consumables-clearance*` file at or under about 14 CPU s under PUC Lua 5.1 on Beast, which tracks the Mac closely; report before and after for each file.

Check the other files the review lists near the limit too: run `run-all.sh` timing output only for the `test-consumables-*` and `test-hud-caith-*` families, and report any above 16 s.

**Re-run**: lint, python and every `test-consumables-*` file under PUC Lua 5.1 with their CPU seconds, then hosted CI. After merge the staging Mac run is the proof, so say which numbers to watch.

**PR**: open a PR (not a draft) against `staging` titled `test(consumables): clearance tests fit the CPU budget`, with the `no changelog` label. Do not merge.

**Constraints**: minimal code; LF is fine for Tools files. Beast speed rule: no full local Lua suite.

**Files it may edit**: `Tools/regression/test-consumables-*.lua`, `Tools/regression/consumables_clearance_lib.lua`, plus new split test files.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the per-file CPU table.
