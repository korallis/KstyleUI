# Task: finish outside contributor Baine's PR #668 (/kstyle perf)

PR https://github.com/korallis/KstyleUI/pull/668 from the fork `Baine/KstyleUI`, branch `feat/kstyle-perf` (head `75db8eaa`). Baine allows maintainer edits and asked us to make the changes ourselves. Our review is on the PR (`gh pr view 668 --comments` and the review body) and in `C:/Users/leeba/.cache/kstyleui-evidence/task_5335b94aafae/report.md` with probes beside it.

**Do**: check out the PR (`gh pr checkout 668`), rebase onto `origin/staging`, fix every finding with a regression built from the probes committed before each fix, apply the optional cuts, and keep Baine's authorship on his commits (add ours on top).
1. Zero cost while not recording: the event dispatcher and the Motion/Calm drivers call the plain handlers exactly as on staging when no window is open; swap the timing wrapper in only for the window and restore it after (prove: `test-perf-path-budgets`, `test-perf*`, `test-nameplates-text-cost` pass; instruction counts equal staging with profiling off).
2. Preserve return arity (`select('#', ...)`), count nested time once, clamp negative deltas from a reset `debugprofilestop`, reuse one sampler frame, no fabricated 1.0 s window, reject non-finite durations.
3. Lint, localisation of help/status lines with `strings.py sync`, a `docs/feature-map.md` row, and the `docs/PROFILING.md` corrections.

**Push** to the contributor's branch: `git push https://github.com/Baine/KstyleUI.git HEAD:feat/kstyle-perf` (maintainer edits are allowed; use force-with-lease against `75db8eaa` if you rebased). Fork PRs skip our CI, so also push the same commit to `contrib/pr-668` in our repo (force) and run `gh workflow run checks.yml --ref contrib/pr-668`; report that run.

**Checks**: lint, python, all touched module tests, `test-taint-scan`, `test-perf-path-budgets`, `test-perf*` under PUC Lua 5.1. Do not merge. Add a short PR comment summarising what we changed, thanking Baine.

**Files it may edit**: the files the PR touches, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the new head SHA and the checks run id.
