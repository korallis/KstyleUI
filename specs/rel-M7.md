# Task: v0.2.7 polish M7: Right rail shows the old readout list

**Goal**: the final release gate passed (GO), but listed small style issues. The owner's rule is one consistent style, so fix M7 on the latest `origin/staging` (f3542cbd) before the release. Evidence is in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md` (minor item "M7") and the sheets it cites.

**Scope**: On Right rail, the readout shows the whole top-bar list (8 readouts, against 3 in v0.2.6), and the line spills about 190 units left of its 278-unit frame. Right rail means 'the old readout', so on rail show the v0.2.6 readouts in their v0.2.6 order (the strip.slot1..5 defaults), or whatever fits the 278-unit frame, using the same whole-item overflow rule as the dock (whole items only, hidden ones listed in the tooltip). Text must never extend past the frame.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes (reload is about 15.43M against 15.7M, so add nothing measurable).
- The overlap matrix and the `test-hud-reach-*` family pass.

**Tests**: a regression test that fails today and passes after. Strict renders of the affected scene at 1920x1080 and 5120x1440.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-M7/`). Open a PR (not a draft) against `staging` titled `fix: Right rail shows the old readout list` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. Be fast: the release waits on this.

**Files it may edit**: `KstyleUI_DataBars/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Send worker_done with the hosted CI run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
