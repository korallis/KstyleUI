# Task: v0.2.7 release blocker B6: the Crest ring minimap plaque clears the RestedXP guide header

**Goal**: the final readiness recheck (`C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md`, section "B6") returned NO-GO on three small items. Fix B6 on the latest `origin/staging` (c5bda80e). Read the section and its evidence: logs, pictures and measurements.

**Scope**: With Minimap frame set to Crest ring and RestedXP loaded, the minimap coordinates plaque (text y 287.4 to 300.6 at 1080p) covers the RestedXP guide card's header (y 298.4 to 311.6); the same happens on ultrawide. The cause is that `Layouts.Aspect` gives the story cards `slot.y - GAP - (MinimapCrest() and 52 or 0)`, which clears the Crest medallion's plaque but not the Crest ring's. Account for the Crest ring's actual plaque footprint (one value per frame choice, not a magic number). Add the Crest ring case to the quest-card or rails test.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes.
- The `test-hud-reach-*` family and the overlap matrix pass.
- One consistent style.

**Tests**: a regression test that fails on today's staging and passes after the fix. Strict renders of the affected scene at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-B6/`). Open a PR (not a draft) against `staging` titled `fix: the Crest ring minimap plaque clears the RestedXP guide header` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. **This is the last thing blocking the release, so be fast.**

**Files it may edit**: `Core/Setup/Layouts.lua` (defaults only; no new top-level local), `KstyleUI_Minimap/**` (footprint only), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Hosted CI is fast; send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
