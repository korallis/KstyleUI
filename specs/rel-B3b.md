# Task: v0.2.7 release blocker B3b: re-running setup with Right rail keeps the old readout

**Goal**: the final readiness recheck (`C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md`, section "B3b") returned NO-GO on three small items. Fix B3b on the latest `origin/staging` (c5bda80e). Read the section and its evidence: logs, pictures and measurements.

**Scope**: If Right rail is already chosen when Setup runs (/kstyle setup), Setup sets strip.menus back to true, so the rail frame grows to 278x88 and the readout rises about 70 units, under the tracked-buff column. Setup must keep strip.menus off while the placement is rail. Fix `test-databars-rail.lua` so it asserts a height of 12 and menus off right after Setup.Apply, without re-writing the placement (today's second write hides the bug). Prove it in all three styles.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes.
- The `test-hud-reach-*` family and the overlap matrix pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix. Strict renders of the affected scene at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B3b/`). Open a PR (not a draft) against `staging` titled `fix: re-running setup with Right rail keeps the old readout` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. **This is the last thing blocking the release, so be fast.**

**Files it may edit**: `Core/Setup/**`, `KstyleUI_DataBars/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
