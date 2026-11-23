# Task: UnitFrames UNIT_FLAGS per-call headroom keeps failing on Mac CI

`test-perf-frames` fails on the Mac mini repeatedly (runs 44990248483, 45014482670): `UnitFrames UNIT_FLAGS: budget 95 us is 4.2 times the 22.4 us Lua 5.1 CPU time; set it to at least 112 us (5 times)`. The idle Mac passed once at load 1.7; under the usual load (4-9) it fails. This blocks releases. Find what the UNIT_FLAGS handler does per call (it costs ~22 us; #651 made it cheaper before; later merges such as #695/#699/#706/#707 may have added work) and make it cheaper with pixel-identical results so 95 us keeps at least 5x headroom with margin. Only if the work is necessary, raise the budget per the README rule with a one-line reason. Read `Tools/regression/README.md` (calibration).

Prove on Mac CI: push the branch and `gh workflow run checks.yml --ref <branch>`; report the run id and the measured UNIT_FLAGS time. PR to `staging`: `perf(unitframes): cheaper UNIT_FLAGS`, label `no changelog` unless player-visible. Do not merge.

**Files it may edit**: `KstyleUI_UnitFrames/**`, `KstyleUI_Nameplates/**` (only if the same handler is shared), `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the cause in one line, PR, SHA, run ids.
