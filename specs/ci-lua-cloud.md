# Task: run pull-request Lua shards on cloud runners too, so the Macs stop being the bottleneck

**Goal**: the owner wants cloud runners used wherever they remove bottlenecks. #517 moved the light jobs to `ubuntu-latest`, but every PR's two Lua shards still queue on three self-hosted Macs: 15 runs were queued tonight, with 30-minute waits. The #517 measurement (`C:/Users/leeba/.cache/kstyleui-evidence/ci-hosted/completion-report.md`) showed hosted runners exceed the **per-file CPU-time** budget on 71 (macOS) or 92 (Ubuntu) of 650 files. That budget is machine-dependent. But the instruction-count budgets (`test-perf-path-budgets.lua` and the other path budgets), the memory limit and the hang guard are not machine-dependent, or are generous enough to hold anywhere.

**Change** (smallest that works):
- **On pull requests:**
  - Run the Lua suite on GitHub-hosted `ubuntu-latest`, split into enough shards to finish in about 5 minutes (measure; for example 4–6).
  - Every functional test, every instruction-count budget, the memory limit and the hang guard still fail the job there.
  - Only the per-file CPU-time overrun warns on hosted runners, as it already does on Windows and non-CI.
- **On staging pushes** (and `workflow_dispatch`): the self-hosted Macs run the full Lua suite as today, as the **CPU budget of record**, so every file is still CPU-checked on a Mac before a release. A CPU regression is caught at the staging push and fixed before tagging.
- **Releases:** `release.yml` keeps its Mac check job, so no release ships with a Mac CPU overrun.
- **Marker gap:** fix the queued gap (`specs/QUEUE.md`): a staging push must always run the instruction budgets (`test-perf-path-budgets.lua`) even when green markers would let it skip an area, because budgets add up across merges. If that's a few lines, do it here.
- Update the AGENTS.md "Budget rule" and gate text, `Tools/regression/README.md`, `docs/DEVELOPING.md` and `Tools/tests/test_workflows.py` to match.
  - Keep the guard that bans `sudo` and `apt` on Mac jobs.
  - Hosted Ubuntu jobs may install Lua 5.1 the way #517's light job does, with caching.

**Proof**:
- Green hosted Lua shards on this PR, with wall time from queue to finish compared with tonight's Mac queue.
- A deliberately failing test fails a hosted shard; show it once and then revert it.
- A test pushed over its instruction budget fails a hosted shard.
- The staging-push path still runs the Macs, shown with the workflow test or a `workflow_dispatch` run.

**Constraints**: minimal change; `.github/workflows/` is the task, so say why in the PR. Never print secrets. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/ci-lua-cloud/`). Open a PR (not a draft) against `staging` titled `ci: pull-request Lua shards run on cloud runners`, with the `no changelog` label and `## In-game checks` (none: CI only). Do not merge.

**Files it may edit**: `.github/workflows/**`, `Tools/hooks/ci_scope.py`, `Tools/tests/**`, `Tools/regression/run_all.py` and `run-all.sh` (only for the warn-on-hosted CPU switch and shard count), `Tools/regression/README.md`, `docs/DEVELOPING.md`, `AGENTS.md` (the gate and Budget rule text).

AGENTS.md: a PR touching `run_all.py`, `run-all.sh` or `gate.sh` shows the native Windows exit codes for `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected origin/staging`.

**Gate**: lint and python locally; green CI on this PR.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run ids and the timing comparison. Send worker_done once proof is in, without waiting for unrelated queues.
