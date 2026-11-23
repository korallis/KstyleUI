# Task: CI PR 1: run lint, Lua and python/package in parallel and drop verdict

**Goal**: cut KstyleUI's pull-request time to green (baseline median 351 s, p90 588 s) by removing the lint-first chain and the `verdict` job.

**Target**: KstyleUI repository (GitHub `korallis/KstyleUI`), branch from `origin/staging`. The approved plan is `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`: read section 1 and section "R2: parallel jobs (PR 1)" in full; that section is your Change. Raw measurements are in `CI-RESEARCH-2026-11-16.json` beside it.

**Change** (from the plan, R2):
- `.github/workflows/checks.yml`: three job kinds start at once with no `needs:` between them: `lua i/2` (runs `ci_scope.py lua` itself, fetch-depth 2 is enough) and one `lint, python and package` job (runs `ci_scope.py all`, then `gate.sh lint`, `gate.sh python`, the packager and `check-package.sh`; every step after lint has `if: ${{ !cancelled() && <scope> }}`). Keep the fork guard on every job, the self-hosted runner labels, the toolchain version checks, and the concurrency group. Delete `verdict`; each job gets a last step `if: failure() && github.event_name == 'push'` that emits the "staging is red" annotation that `verdict` emits today. Lua jobs get `timeout-minutes: 15`.
- `Tools/tests/test_workflows.py`: replace the assertions on `verdict` and `needs: pre-commit` with: no `needs:` between suite jobs; the fork guard on each job; `!cancelled()` on steps after lint; the push failure annotation; Lua timeout 15.
- `Tools/hooks/ci_scope.py` and `Tools/tests/test_ci_scope.py` only if a job needs a scope mode it lacks.
- `docs/DEVELOPING.md` (the CI paragraph, around lines 52-60) and the CI wording in `AGENTS.md`: a PR is green when every `checks` job and `pr-rules` are green.
- Do NOT add the run_all.py progress line (moved to a later PR) and do not touch `release.yml` or `pr-rules.yml`.

**Playbook**: none.

**Constraints**:
- `.github/workflows/` is a sensitive path: the PR body says why it changes (job graph and timeout).
- CI runs only on the owner's self-hosted runners (owner rule in #293): never add hosted runners.
- Pin any new action by full commit SHA with a version comment, like the existing ones.
- Windows machine (Beast). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; set `KSTYLEUI_PYTHON=python`.
- You may push your branch and open a **draft** pull request against `staging` to get the CI run that is your evidence: title `ci(checks): run lint, Lua and python/package in parallel and drop verdict`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). End the body with the attribution line `🤖 Generated with [Claude Code](https://claude.com/claude-code)` only if you are Claude; otherwise no attribution. Do not merge it, do not mark it ready.

**Files it may edit**: `.github/workflows/checks.yml`, `Tools/tests/test_workflows.py`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `docs/DEVELOPING.md`, `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: the `lua` and `python` groups (see AGENTS.md "Known failing"). On Windows the bar is `bash scripts/gate.sh lint` exit 0 plus `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope` exit 0; CI on the draft PR runs the rest on the Macs.

**Evidence of done**:
- `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope -v` output, exit 0, and the same new workflow tests failing against `origin/staging`'s `checks.yml` (red then green).
- The draft PR's `checks` run: `gh run view <id> --json jobs` showing the suite jobs started within seconds of each other with no `verdict` job, every job green, and its created-to-completed time next to the 351 s baseline.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode (delete the comments, list MUST KILL flags, skip its greeting). Commit with Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED (worker_done `--outcome failed`) with next steps. Report commit SHA, base SHA, PR URL, run id, Gate output and evidence output.
