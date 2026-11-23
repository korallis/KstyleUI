# Task: PR #566: replace the wall-clock perf asserts with instruction counts

PR https://github.com/korallis/KstyleUI/pull/566, branch at `523002a7cf39bdbfe0e1150f69b13a6a76d2f0b8`.

`Tools/regression/test-perf-worldmap-roads.lua` asserts on `os.clock`:
- `:26`, a 5 ms query cap;
- `:60`, a 1.5 ms tick cap.

That measures wall time on Windows and varies with runner load. It already failed once on hosted CI (8.68 ms), so it will flake. The repository's rule is that instruction-count checks are deterministic and fatal everywhere, and CPU time is budgeted per file by the runner.

**Fix**:
- Replace both asserts with instruction-count budgets using `debug.sethook` counting, the way `Tools/regression/test-perf-path-budgets.lua` does.
- Measure the current cost of the worst query and of the moving tick in instructions. Set each budget at about 1.5x today's measured count, with a failure message that names the fix (as today's messages do).
- Keep the timing numbers only as printed information, not asserts.

**Re-run**: the world map tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Push to the same branch. Do not merge.

**Constraints**: minimal code. Beast speed rule.

**Files it may edit**: `Tools/regression/test-perf-worldmap-roads.lua`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, run id and the instruction numbers.
