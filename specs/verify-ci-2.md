# Verify: CI PR 2 (skip staging areas whose tree passed on the PR)

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out SHA `de268ecb05730df21d7c19c7dcb112e35856091d` (draft PR https://github.com/korallis/KstyleUI/pull/414). Base is `8326aab1f465e22300355d93434506a15e4e7832`. Edit nothing, push nothing, comment nothing.

**Spec the author worked from**: `C:\Projects\KstyleUI\specs\ci-2-skip-proven-push.md` (it names plan section R1 in `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`). Author's report: `C:\Users\leeba\.cache\kstyleui-ci-pr2\report.txt`.

**Allowed files**: `.github/workflows/checks.yml`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `Tools/tests/test_workflows.py`, `AGENTS.md`, `docs/DEVELOPING.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md). Windows bar: `bash scripts/gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**The central risk**: this change lets a staging push skip suites. Your job is to find any way a broken tree reaches staging green. Try at least: a PR whose merge-commit tree differs from the squash commit's tree (staging moved between the PR run and the merge); a PR run that passed, then a rerun that failed or was cancelled; one Lua shard marker missing or from a different `N`; a marker from another workflow or a fork PR; a marker artifact name collision across PRs with the same tree; an area that `ci_scope.py` skipped on the PR (no marker) but has work on push; the artifact list being paginated or expired (retention 7 days); API rate limit or 5xx; a change to `checks.yml` itself; the push's `actions: read` permission scope. For each, show from code, tests or a live dry run (`ci_scope.py` in push mode with `GITHUB_TOKEN=$(gh auth token)` and the env a push run would have) whether the suite runs.

**Other checks**:
- `git diff --stat <base>..<sha>`: files outside the allowed list; suppressions grep.
- Tests: apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`; run the new tests at base (fail for the intended reason) and at the SHA (pass); paste both. Do a few mutations of the skip logic and show the tests catch them.
- CI evidence: `gh run view 43904504841 --json jobs,headSha,conclusion` and its artifacts list; confirm the SHA and the five markers.
- Actions pinned by full SHA; permissions minimal per job.
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY on the diff; skip its greeting.
- Blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified de268ecb"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
