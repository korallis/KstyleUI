# Verify: CI PR 3b (#419, package push runs regardless of tags) at 66eacdbe

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `66eacdbeb4a7dd38112b93fb2f0fd0a4d6943535` (draft PR https://github.com/korallis/KstyleUI/pull/419). Base is `3a8d93f2366118a37b1d219fc90d94c6cfe4d66c`. Edit nothing, push nothing, comment nothing, never push or delete a remote tag.

**Spec**: `C:\Projects\KstyleUI\specs\ci-3b-packager-tags.md`. Author evidence: `C:/Users/leeba/.cache/kstyleui-verify/ci-pr3b/evidence.md`. Allowed files: `.github/workflows/checks.yml`, `Tools/tests/test_workflows.py`.

**Gate**: `bash scripts/gate.sh`; known failing on Windows per AGENTS.md. Windows bar: `gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- The tag cleanup touches only local refs in the runner's checkout (never the remote), only on the path the spec names, and cannot change what `release.yml` packages or which version a release zip carries. Prove from the YAML and by reproducing one historical push SHA yourself (tag present at HEAD: packager fails before, zip passes `Tools/hooks/check-package.sh` after).
- The release-wait interaction: with this change, a tag pushed during the staging push run no longer makes that run fail, so `ci_scope.py proven-sha` in `release.yml` (merged #415) can reuse it. Show from the code path.
- PR 2's markers and skip logic in `checks.yml` are unchanged; no new permissions; actions pinned by SHA.
- New assertions red on base and green at the SHA; a couple of mutants of the cleanup step.
- CI runs 43927863396 and 43928891590 green for the SHA; `git diff --stat` within the allowed files; suppressions grep.
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 66eacdbe"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
