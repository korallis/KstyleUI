# Task: add GitHub-hosted runners to CI so PRs stop queueing

**Goal**: the owner wants cloud runners wherever they speed CI up, so many parallel PRs don't bottleneck on the three self-hosted Mac runners (`mac-KstyleUI-1` on the Mac mini, which also hosts other repos' runners; `-2` and `-3` on the MacBook). Today every job in `checks.yml`, `pr-rules.yml` and `release.yml` runs on `[self-hosted, mac-ci, KstyleUI]`, and around six PRs are queued. The repository is **public**, so GitHub-hosted `ubuntu-latest` and macOS runners cost nothing.

**Do it in this order, with measurements**:
1. **Move the light jobs to `ubuntu-latest`**:
   - `pr-rules` and any scope, marker or upload job;
   - the "lint, python and package" job, which runs `scripts/gate.sh lint`, `python` and the package checks. Install Lua 5.1, luacheck and pre-commit, and use the Python venv the gate expects (`KSTYLEUI_PYTHON`), with `actions/cache` for the tool installs.

   These have no CPU budget, so they can leave the Macs safely. Prove each job passes on hosted runners and is not slower end to end than today.
2. **Lua shards.** The AGENTS.md Budget rule makes Mac CI the CPU budget of record: default PUC Lua 5.1.5 files get 20 CPU s, or the measured LEE-5827 allowances. Measure one full `run-all.sh` on `macos-latest` (hosted, Apple silicon) and on `ubuntu-latest`, with per-file CPU times against the budgets (see `Tools/regression/README.md`). Then pick the option that keeps the budget honest and queues least, and justify it with the numbers:
   - **(a)** more shards, split between self-hosted Macs and hosted runners, with hosted CPU overruns only warning while every file still runs under budget on a self-hosted Mac somewhere;
   - **(b)** hosted runners take the shards when no self-hosted runner is free;
   - **(c)** keep Lua on the self-hosted Macs only, if the hosted numbers make budgets meaningless there.

   Do not weaken a budget, and do not let any file escape budget enforcement.
3. **Keep the green and red marker system and the staging-push skip logic** (AGENTS.md "The gate" section) working, including the start markers. Update `Tools/hooks/ci_scope.py`, `Tools/tests/` workflow tests and AGENTS.md or `Tools/regression/README.md` only where they describe the runners.
4. **Release.** Leave `release.yml` on the self-hosted Macs unless a job is clearly safe and faster hosted. Say which in the PR.

**Proof**: run the new workflows on this PR and show green runs on the hosted runners. Compare queue-plus-run time against a recent self-hosted run of the same scope, and give the per-file CPU table for the hosted Lua measurement. Because this PR touches `scripts/gate.sh` or `Tools/regression/run-all.sh` only if needed, AGENTS.md applies: if you change those, show the native Windows exit codes for `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected origin/staging`.

**Constraints**: minimal change. `.github/workflows/` changes are the task, so say why in the PR body. Never print or commit secrets, and keep release secrets in the `release` environment. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/ci-hosted/`). Open a **draft** PR against `staging` titled `ci: hosted runners take the light jobs` (adjust it if the Lua shards move too), with the `no changelog` label and `## In-game checks` (none: CI only). Do not merge.

**Files it may edit**: `.github/workflows/**`, `Tools/hooks/ci_scope.py`, `Tools/tests/**`, `Tools/regression/README.md`, `AGENTS.md` (the gate and Budget rule text only, if the runners change), `scripts/gate.sh` and `Tools/regression/run-all.sh` (only if needed).

**Gate**: lint and python locally; green CI on the new runners is the proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run ids, the timing comparison and the option chosen for the Lua shards.
