# Task: CI PR 6: the Python suite runs green on Windows; Tools/docs stay LF; small CI follow-ups

**Goal**: `bash scripts/gate.sh python` exits 0 natively on Windows 11 (Git Bash + python.org Python) and on the Mac CI runners, so the Windows gate's Python group is no longer "Known failing".

**Target**: KstyleUI, branch from `origin/staging` (it has #416's portable runner and #413's fs.lua). Plan: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`, the Python rows of section 3 and PR 6's row in section 4.

**Change**:
- Fix every Windows failure in `python -m unittest discover -s Tools/tests` (about 27 failures plus errors; list them first): POSIX path assumptions (`posixpath`, separator-dependent asserts), umask and symlink tests (skip only where the OS lacks the feature, with a printed reason), `sys.executable` fakes, CSV `newline=""`, and `test_iconset.GenerateTest.test_ctrl_c_cancels_the_queued_icons_and_keeps_the_running_one`, whose real SIGINT ends the interpreter on Windows: use `_thread.interrupt_main()` or the shim so the suite completes.
- Fix the flaky timing-margin Python tests (LEE-1537): find which tests assert on wall-clock margins, make them use an injected clock or a margin that cannot flake, and prove it with 20 consecutive runs.
- Python writers that emit CRLF on Windows (`run_all.py` writes, `Tools/locale/strings.py:115`, `Tools/media/medallions.py`, `Tools/media`): open with `newline="\n"`. Extend `Tools/dev/crlf.py --check` to fail on CRLF in `Tools/` and `docs/` text files with a message naming `newline="\n"`; prove it fails on a planted CRLF file.
- `scripts/gate.sh`: run `check-suppressions.sh` with `SUPPRESSION_BASELINES=Tools/regression/pixel_allow.tsv` so baseline growth needs its `Baseline-Growth:` trailer.
- `Tools/tests/test_workflows.py`: make the #419 tag-cleanup assertion an exact match, not a substring (an appended command must fail it).
- AGENTS.md: remove the Python part of "Known failing" once the group passes on Windows.

**Playbook**: refactor -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\refactoring.md`, steps 1, 4, 5, 6, 8 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**: stdlib only; never weaken an assertion to pass on Windows (skip only when the platform lacks the feature, with a reason). Do not edit `Tools/regression/*.lua` or `perf_runner.lua`, and edit `Tools/regression/run_all.py` only at its write calls (PR 7 owns budgets). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH. You may push your branch and open a **draft** PR against `staging`: title `test(tools): run the Python suite on Windows and keep Tools files LF`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/tests/**` except `Tools/tests/test_run_all.py` (PR 7 runs in parallel and owns it), `Tools/dev/crlf.py`, `Tools/locale/strings.py`, `Tools/media/**` (write calls only), `Tools/regression/run_all.py` (write calls only), `Tools/regression/affected.py`, `scripts/gate.sh`, `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Windows bar for this PR: `gate.sh lint` and `gate.sh python` exit 0; the `lua` group's 20 s wall-budget overruns and the four known Lua files remain for PR 7.

**Evidence of done**: `gate.sh python` on Windows before (failure list) and after (exit 0, test count); 20 consecutive passes of the formerly flaky tests; the planted-CRLF check failing; the draft PR's green `checks` run with the Mac Python job's test count unchanged or higher.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
