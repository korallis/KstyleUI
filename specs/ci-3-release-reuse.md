# Task: CI PR 3: the release reuses the staging result for the tagged commit

**Goal**: stop `release.yml` re-running the Lua suite on a commit staging already proved green (release baseline 442 s, target about 175-190 s), and run the changelog test that today never runs with a tag.

**Target**: KstyleUI repository (GitHub `korallis/KstyleUI`), branch from `origin/staging` (it has PR 1's parallel layout and PR 2's per-tree/per-area green/red markers on push runs). The approved plan is `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`: read section "R3: release reuses staging (PR 3)"; that is your Change.

**Change** (plan R3):
- `.github/workflows/release.yml`: the `lua` job keeps its matrix. Its first step after checkout runs `python3 Tools/hooks/ci_scope.py proven-sha`, which needs the newest completed `checks.yml` **push** run for `GITHUB_SHA` (`GET /repos/{owner}/{repo}/actions/runs?head_sha=<sha>&event=push`, workflow `checks.yml`, same repository) to have conclusion `success`. A push run that skipped areas because their tree passed on the PR counts (it concluded success). Missing, cancelled, failed, in progress, or any API error means unproven, and the shards run. Print which run proved it, or why not.
- The skip is a step decision, not a job-level `if:`, so the `lua` job always ends success or failure and `release` (`needs: [check, lua]`) can never run after a failed `check` or a skipped proof.
- Add `python3 -m unittest Tools.tests.test_release_changelog` to the `check` job (it checks the tag's CHANGELOG section only when `GITHUB_REF_NAME` is a tag).
- `Tools/tests/test_workflows.py`: replace the "sharded release Lua at least 20 minutes" assertions with: the upload job cannot run unless the shards ran or `proven-sha` succeeded; the changelog test runs in `check`; the proof is a step, not a job `if:`. `Tools/tests/test_ci_scope.py`: proven-sha cases (success push run, failed, cancelled, none, in progress, another workflow, a fork, API error).
- Update AGENTS.md "Releases"/CI text if it names the release's Lua shards.

**Playbook**: none.

**Constraints**:
- `.github/workflows/` is a sensitive path: the PR body says why (stop re-running a suite on a SHA staging proved). `release` stays the only job with `contents: write`; the `lua` job needs only `actions: read` and `contents: read`. Never print or commit a token. Self-hosted runners only (owner rule #293).
- You cannot push a tag. Prove the release path with tests plus a live dry run of `ci_scope.py proven-sha` against real runs (`GITHUB_TOKEN=$(gh auth token)`, `GITHUB_SHA` set to a staging commit whose push run succeeded, one whose push run failed, e.g. from runs 43770631744 / 43854437996, and a SHA with no push run).
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.
- You may push your branch and open a **draft** PR against `staging`: title `ci(release): reuse the staging result for the tagged commit`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it or mark it ready.

**Files it may edit**: `.github/workflows/release.yml`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `Tools/tests/test_workflows.py`, `AGENTS.md`, `docs/DEVELOPING.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md). Windows bar: `bash scripts/gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope Tools.tests.test_release_changelog` exit 0; the draft PR's CI runs the rest.

**Evidence of done**: new tests red on `origin/staging` and green after (paste both); the live `proven-sha` dry-run outputs for proven, failed, cancelled and missing; the draft PR's `checks` run green.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode (delete the comments, list MUST KILL flags, skip its greeting). Commit with Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED (worker_done `--outcome failed`). Report commit SHA, base SHA, PR URL, run id, Gate output and evidence output.

**Also in this PR (from PR 2's verify)**: add a `Tools/tests/test_ci_scope.py` case for a start marker and a green marker with the same timestamp on the same tree and area: the push must run (surviving mutant S8 in `C:\Users\leeba\AppData\Roaming\orca\chat-scratch\af84108d565c543b2acefb706d2aabd9\verify-ea6273ea.md`). Show it failing against a mutant that treats the tie as green.
