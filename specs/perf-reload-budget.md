# Task: bring the reload cost back under its budget on staging (pixel-identical)

**Goal**: `origin/staging` (443f72ad or later) fails `Tools/regression/test-perf-path-budgets.lua:7`. The reload path costs about 15,714,900 VM instructions against a 15,700,000 budget, so every PR's CI now fails Lua shard 1. #507 (the ordered Options row) and the other recent merges pushed it over. The batch C worker measured the details in `C:/Users/leeba/.cache/kstyleui-evidence/compat-C/report.md`.

**Change**:
- Find what the recent merges added to the reload path (`git log 6fb6e279..origin/staging`, especially #507's Options code). Profile per function with the existing perf tooling (`Tools/regression/README.md`).
- Cut the cost so the reload is comfortably under budget. Aim for under 15.5M, which is a standing follow-up.
- **Never raise the budget.**
- The change must be **pixel-identical** (owner rule for performance work). Prove it with base and after render diffs of the gallery scenes the change touches, at 1920x1080 and 5120x1440.
- Prefer lazy work: build Options rows and schemas only when the Options window opens, not at reload, and stop recomputing what a reload doesn't need.

**Tests**: `test-perf-path-budgets.lua` passes with a margin. The touched modules' tests pass, and so do `test-options-order` and the Options tests.

**Constraints**: minimal code; AGENTS.md rules; evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/perf-reload/`). This blocks every open PR, so be quick. Open a PR (**not** a draft) against `staging` titled `perf(options): reload back under budget` with `## Changelog` (`Changed: Reloading the UI does a little less work.`), `## In-game checks` and `## Before and after` (the pixel diffs). Do not merge.

**Gate**: lint, python and the touched modules' tests plus `test-perf-path-budgets.lua` under PUC Lua 5.1 (never LuaJIT); green Mac CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the before and after instruction counts, SHA, PR URL and run id.
