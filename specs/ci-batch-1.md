# Task: CI batch 1, faster CI with no coverage lost (shard weights, balanced Mac shards, AMD runner, duplicate screen)

The owner approved this from the two CI audits. Read `C:/Users/leeba/.cache/kstyleui-evidence/ci-audit/claude.md` and `codex.md`; they agree on these items.

**Change**:
1. **Refresh `weights.json`:** 381 of 834 test files have no weight, and shard 6/8 runs 316 s against 191-239 s for the others. Take the weights from a recent green Mac staging run's `usage:` lines, through the existing tooling if there is one. Document the one-command refresh in `Tools/regression/README.md`.
2. **Balance the staging and release Mac runs:** today it's 2 shards on hosts with 6 and 4 slots (252 s against 408 s). Use smaller, more numerous units (the audits suggest 3-5) so both Macs finish together. Measure, and pick the smallest change that gets within about 10%.
3. **The new AMD runner:** a self-hosted runner `amd-KstyleUI-1` is online, with labels `self-hosted, Linux, X64, amd, amd-ci, KstyleUI`. It's a Ryzen 7 7800X3D with 16 threads, 30 GB RAM, Lua 5.1 at `/usr/bin/lua5.1`, Python 3 and no luacheck. SSH is `ssh amd` from the dev box, user `lee`.
   - Measure the full Lua suite on it with appropriate slots (`run-all.sh`, its own slot count). On the dev box's single test runs, per-test CPU looks close to the Mac (hud-caith-dps-off 18.7 s against 17.7 s on the Mac).
   - If it beats the 8 hosted shards' wall time (about 5.8 min), run PR Lua on it, with a simple fallback to the hosted shards when the runner is offline or busy past a short timeout. Choose the smallest reliable mechanism and explain it.
   - Its CPU timing is stable, unlike hosted runners. If you can calibrate it against the Mac (the per-file ratio from the same tree) tightly enough, make PR CPU budgets **fatal on the AMD runner** with that calibrated factor, so slow tests fail on the PR instead of later on staging. If the ratio isn't tight, keep it warn-only and say why with the numbers.
   - Keep the Macs as the CPU budget of record on staging and release.
4. **Remove the duplicate screen:** the six `test-hud-caith-*-screens-3-4.lua` files run 5120x1440 twice (`hud_reach_lib.lua:145-146`; the sibling file already runs screens 1-3). Make them run screen 4 only, keeping every case.

**Constraints**:
- Never weaken a real guard: functional, instruction, memory and hang checks stay fatal.
- Minimal code. Say why `.github/workflows/` changes, as AGENTS.md requires.
- Don't break the PR markers or the scope logic.
- The AMD box is shared; use the runner, and only SSH for measuring.

**Proof**:
- a before/after table of wall time per PR (hosted, and AMD if used) and per staging push (Macs), from real runs: open the PR and use its runs, plus a `workflow_dispatch` on the branch for the Mac path;
- the AMD calibration table, if you made it fatal.

**PR**: open a PR (not a draft) against `staging` titled `build(ci): balanced shards, fresh weights and the AMD runner`, with the `no changelog` label. Do not merge.

**Files it may edit**: `.github/workflows/checks.yml` (and `release.yml` only for its Lua shard count), `Tools/regression/weights.json`, `Tools/regression/run_all.py` and `run-all.sh` (only for sharding or weights), `Tools/regression/hud_reach_lib.lua` and the six screens-3-4 files, `Tools/regression/README.md`, `Tools/tests/` (only the tests that pin shard counts), `AGENTS.md` (the CI description lines).

Another CI PR (batch 2: local run admission, `--affected` precision, clock asserts) runs in parallel and touches `run_all.py`. Keep your `run_all.py` change minimal and rebase before opening.

**Gate**: lint and python, then hosted CI and the measured runs.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run ids and the timing table.
