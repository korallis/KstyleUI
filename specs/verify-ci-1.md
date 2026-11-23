# Verify: CI PR 1 (parallel jobs, verdict dropped)

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out SHA `aaa044426ddf639924813db44ddc738e590cb48e` (branch `korallis/ci-parallel-lint-lua`, draft PR https://github.com/korallis/KstyleUI/pull/412). Base is `076f267b6bb9cc7d69deb9ff9c99aa1c435c3e89`. Edit nothing, push nothing, comment nothing.

**The task spec the author worked from**: `C:\Projects\KstyleUI\specs\ci-1-parallel-jobs.md` (read it; it names the plan section R2 in `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`). Author's report: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PR1-EVIDENCE\report.txt`.

**Allowed files**: `.github/workflows/checks.yml`, `Tools/tests/test_workflows.py`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `docs/DEVELOPING.md`, `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Known failing on Windows: `lua` and `python` groups (AGENTS.md). On Windows the bar is `bash scripts/gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- `git diff --stat <base>..<sha>`: flag files outside the allowed list; grep the diff for suppressions (`noqa|luacheck: *ignore|# *type: *ignore|\.skip\(`).
- Read the new `checks.yml` against the spec's Change line by line. In particular prove, from the YAML and GitHub Actions semantics: (a) a lint failure cannot hide the python or package result (`!cancelled()` on later steps) and cannot make the job green; (b) a scope that skips a suite still leaves every required job reporting a conclusion, and a push to staging that fails any job emits the "staging is red" annotation; (c) the fork guard is on every job; (d) nothing now runs only through `verdict` (e.g. a required status check, `pr-rules.yml`, `release.yml`, `Tools/hooks/check-pr.sh` or docs that name `verdict` or `pre-commit` as the result to read); grep the repo for `verdict` and `needs.pre-commit`. (e) concurrency and permissions unchanged or tightened.
- Tests: apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`. Run the new `test_workflows` tests at the SHA (pass) and with `.github/workflows/checks.yml` from the base (must fail for the intended reason). Paste both.
- CI evidence: `gh run view 43898611526 -R korallis/KstyleUI --json jobs,createdAt,updatedAt,conclusion` and confirm the author's 242 s and job start times; confirm the run is for the reported SHA.
- Comments: follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY on the diff; skip its greeting.
- Blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified aaa04442"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
