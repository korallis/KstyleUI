# Task: rebase PR #610 onto staging after #603

PR https://github.com/korallis/KstyleUI/pull/610 (forged plates and glyph segments for the Medallions dock, head `03fba01d`) conflicts with staging in `KstyleUI_DataBars/Strip.lua` (and locale files) because PR #603 (Data Bars parity round 1) just merged. Rebase onto `origin/staging`, keep both PRs' behaviour (read #603's squash commit and its README to understand what it changed), take both sides' locale strings and run `python3 Tools/locale/strings.py sync`.

**Prove nothing regressed**: every `test-databars-*`, `test-shell-parity*`, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; lint and python; 0 default pixel diffs staging-vs-PR for Frames and Orbs at 1920x1080 and 5120x1440; the Medallions forged dock render at all four sizes `--strict` compared with the pre-rebase PR head (pixel-identical apart from anything #603 itself changed, which you explain). Push to the same branch with force-with-lease; hosted CI green. Do not merge.

**Files it may edit**: the files either PR touches, plus `Tools/regression/**` and `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
