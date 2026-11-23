# Task: v0.2.7 polish M1: the Medallions dock readout and XP caption share one separator

**Goal**: the final release gate passed (GO), but listed small style issues. The owner's rule is one consistent style, so fix M1 on the latest `origin/staging` (f3542cbd) before the release. Evidence is in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md` (minor item "M1") and the sheets it cites.

**Scope**: On the Medallions dock, the right-hand line runs into the XP caption with no separator: '96% ARMOUR  0% · RESTED 5%'. Join them with the same middle dot and spacing every other readout uses (Widgets.DotGap), so the line reads '96% ARMOUR · 0% · RESTED 5%'. The overflow rule must still keep text inside the wing.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes (reload is about 15.43M against 15.7M, so add nothing measurable).
- The overlap matrix and the `test-hud-reach-*` family pass.

**Tests**: a regression test that fails today and passes after. Strict renders of the affected scene at 1920x1080 and 5120x1440.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-M1/`). Open a PR (not a draft) against `staging` titled `fix: the Medallions dock readout and XP caption share one separator` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. Be fast: the release waits on this.

**Files it may edit**: `KstyleUI_DataBars/**`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Send worker_done with the hosted CI run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
