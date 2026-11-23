# Task: CI PR 3b: package push runs regardless of a tag pushed alongside the merge

**Goal**: remove the false red staging runs where the BigWigs packager refuses to build because a release tag arrived with the merge.

**Target**: KstyleUI, branch from `origin/staging`. Plan: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md` section "R8: packager on push runs (PR 3b)". All 4 failed staging push runs failed this way: the packager printed `Found future tag "v0.2.2", not packaging`, then `check-package` failed with "no folder '.release'" (runs 43770631744, 43799726511, 43841426330, 43854437996).

**Change**: in `.github/workflows/checks.yml`, make the package step of the `lint, python and package` job build a zip on push runs whatever tags exist: for example check out without tags, or pass the packager an explicit version/`-d`-style override so a future tag cannot stop it (read the BigWigs packager's documented options; pin by full SHA as today). Do not change `release.yml` (PR 3, #415, owns it). Add `Tools/tests/test_workflows.py` assertions for the chosen mechanism. Prove it by re-running the package step's commands locally (Git Bash) on the trees of the 4 failed push runs with the tag present, or by a `workflow_dispatch`-free reproduction that shows the packager output before and after.

**Playbook**: bug -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\bug-fix.md`, intro + steps 1, 2, 4, 5 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: `.github/workflows/` is a sensitive path: say why in the PR body. Self-hosted runners only. PR 2's markers and skip logic in `checks.yml` stay intact. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. You may push your branch and open a **draft** PR against `staging`: title `ci(checks): package push runs regardless of tags pushed alongside the merge`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `.github/workflows/checks.yml`, `Tools/tests/test_workflows.py`.

**Gate**: `bash scripts/gate.sh`; known failing on Windows: `lua` and `python` groups. Windows bar: `gate.sh lint` exit 0 and `python -m unittest Tools.tests.test_workflows` exit 0; the draft PR's CI runs the rest.

**Evidence of done**: the packager failing with a future tag before the change and producing a zip that passes `Tools/hooks/check-package.sh` after (commands and output); new assertions red on `origin/staging` and green after; the draft PR's green `checks` run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
