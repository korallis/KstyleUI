# Task: v0.2.7 release blocker B5: the data bar clock clears the centre gem at 14 units

**Goal**: the final readiness recheck (`C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md`, section "B5") returned NO-GO on three small items. Fix B5 on the latest `origin/staging` (c5bda80e). Read the section and its evidence: logs, pictures and measurements.

**Scope**: At the 14-unit default, the top bar's clock text (y 0.9 to 12.6) sits on the centre crest gem (LevelPlaque, y 4.5 to 22.5) and touches the top trim, at every size in Frames and Orbs. Fix it with the least change that keeps one consistent style. For example, the gem hangs just below the bar's bottom edge (as the level plaque hangs under the crest), so the clock is vertically centred in the 14-unit bar with clear space above and below; or another minimal arrangement. Keep the 14-unit height and the zero top inset (the Frames Auto size must stay at v0.2.6). Add a test that the clock's text rect doesn't intersect the gem or the trim at 14 and 20 units.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes.
- The `test-hud-reach-*` family and the overlap matrix pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix. Strict renders of the affected scene at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B5/`). Open a PR (not a draft) against `staging` titled `fix: the data bar clock clears the centre gem at 14 units` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. **This is the last thing blocking the release, so be fast.**

**Files it may edit**: `KstyleUI_DataBars/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
