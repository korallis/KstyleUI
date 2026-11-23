# Verify: CI PR 3 (release reuses the staging result) at 509353d7

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `509353d7cf6c273c98bc2189e9efba1302117be2` (draft PR https://github.com/korallis/KstyleUI/pull/415). Base is `d70a3f5e76ba7f1bd57ec07a8f6be37086c7fc75`. Edit nothing, push nothing, comment nothing, never push a tag.

**Spec the author worked from**: `C:\Projects\KstyleUI\specs\ci-3-release-reuse.md`. Author's report: `C:\Users\leeba\AppData\Roaming\orca\chat-scratch\6b9c1c7d045de176cf964b25798ee303\ci-release-evidence\report.md`.

**Allowed files**: `.github/workflows/release.yml`, `Tools/hooks/ci_scope.py`, `Tools/tests/test_ci_scope.py`, `Tools/tests/test_workflows.py`, `AGENTS.md`, `docs/DEVELOPING.md`.

**Gate**: `bash scripts/gate.sh`; known failing on Windows: `lua` and `python` groups. Windows bar: `gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows Tools.tests.test_ci_scope Tools.tests.test_release_changelog` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**The central risk**: a release uploads a zip whose commit was never proven green. Try to break it: a tag on a commit whose newest push run failed, was cancelled, is in progress, or does not exist; a newer failed rerun after an older success; a push run from another workflow or a fork; a SHA where the push run skipped areas (PR 2's markers) whose PR proof was itself wrong; API errors; the `lua` job ending skipped instead of success/failure; `release` running after a failed `check`; permissions (`release` is the only `contents: write` job; no token printed). Show from YAML semantics, tests and live dry runs of `ci_scope.py proven-sha` (`GITHUB_TOKEN=$(gh auth token)`) what happens in each case.

**Other checks**: `git diff --stat <base>..<sha>` against the allowed files; suppressions grep; new tests red at base and green at the SHA (apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`); a few mutants of the proof logic, including S8 (start/green tie); CI runs 43917080931 and 43917083723 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 509353d7"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
