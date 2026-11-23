# Task: CI PR 2: skip on staging each area whose tree already passed on the pull request

**Goal**: stop the staging push from re-running suites on exactly the tree its pull request already proved green (about 80% of pushes; about 510 runner-seconds saved per merge).

**Target**: KstyleUI repository (GitHub `korallis/KstyleUI`), branch from `origin/staging` (which now has PR 1's parallel job layout: one `lint, python and package` job and `lua i/2` shards, no `verdict`). The approved plan is `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`: read section 1 and section "R1: one run per tree and area (PR 2)" in full; that section is your Change.

**Change** (plan R1):
- On `pull_request`, each area that ran and passed uploads a marker artifact `green-<tree>-<area>` as its last step with `if: success()`: `<tree>` is `git rev-parse HEAD^{tree}` of the PR merge commit; areas are `lint`, `lua-<i>-of-<N>` (`N = strategy.job-total`), `python`, `package`. Use `actions/upload-artifact` pinned by full SHA with a version comment, `retention-days: 7`. Each upload comes from the job that ran that area. An area that `ci_scope.py` skipped writes no marker.
- On `push` to staging, each job runs `ci_scope.py <area>` which, in push mode, lists artifacts for this tree and area (job `permissions: actions: read`), takes the newest, and requires its run to be `checks.yml`, `event == pull_request`, `conclusion == success`; then prints `tree X, area Y passed in run Z: skipping` and the job's later steps skip; otherwise prints `staging moved or no proof: running`. Any API error means the area runs. No extra serial job.
- `Tools/tests/test_ci_scope.py`: marker from a successful run skips; marker from a failed run runs; marker for only one shard runs the other shard; API error runs; pull_request event keeps today's behaviour. `Tools/tests/test_workflows.py`: marker names carry the shard index and total; uploads are `if: success()`; push skip is a step decision, not a job-level `if:`.
- Update the CI paragraph in `AGENTS.md` and `docs/DEVELOPING.md`.

**Playbook**: none.

**Constraints**:
- `.github/workflows/` is a sensitive path: the PR body says why (stop duplicate push runs). CI stays on the owner's self-hosted runners only (owner rule #293). Keep `permissions` minimal per job.
- The skip must never turn a real staging failure green: a staging tree that differs from the PR tree, a rerun that failed, a missing shard marker, or any API doubt all run the suite.
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.
- You may push your branch and open a **draft** PR against `staging`: title `ci(checks): skip on staging each area whose tree already passed on the pull request`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it or mark it ready. The push-side behaviour can only be observed after merge; prove it with tests plus a `workflow_dispatch`-free dry run of `ci_scope.py` in push mode against real artifacts from your draft PR's run (set the env vars a push run would have, with `GITHUB_TOKEN` from `gh auth token`), showing both the skip and the run path.

**Files it may edit**: `.github/workflows/checks.yml`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `Tools/tests/test_workflows.py`, `AGENTS.md`, `docs/DEVELOPING.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md). On Windows the bar is `bash scripts/gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope` exit 0; the draft PR's CI runs the rest.

**Evidence of done**: new tests red on `origin/staging` and green after (paste both); the draft PR's `checks` run green with the marker artifacts listed (`gh api repos/korallis/KstyleUI/actions/runs/<id>/artifacts`); the push-mode dry run output for the skip path (tree of your PR's merge commit) and the run path (a different tree, a failed run, and a forced API error).

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode (delete the comments, list MUST KILL flags, skip its greeting). Commit with Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED (worker_done `--outcome failed`). Report commit SHA, base SHA, PR URL, run id, Gate output and evidence output.
