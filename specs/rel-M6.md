# Task: v0.2.7 polish M6: the Medallions quest card and guide card tops line up

**Goal**: the final release gate passed (GO), but listed small style issues. The owner's rule is one consistent style, so fix M6 on the latest `origin/staging` (f3542cbd) before the release. Evidence is in `C:/Users/leeba/.cache/kstyleui-evidence/release-0.2.7/recheck.md` (minor item "M6") and the sheets it cites.

**Scope**: With the default Crest medallion minimap, the quest card's top sits about 50 units below the RestedXP guide card's top, so the two sibling cards aren't top-aligned (Classic aligns them). The coordinates plaque also rests on the guide card's top edge with no gap. Top-align the two cards, as in Classic, with the plaque clear above both at the standard gap, without bringing back B2 (whole quest lines) or B6. Check with Crest medallion, Crest ring and Classic, with and without RestedXP, at all four sizes.

**Rules**:
- Change defaults only; never move a saved position.
- `test-perf-path-budgets` passes (reload is about 15.43M against 15.7M, so add nothing measurable).
- The overlap matrix and the `test-hud-reach-*` family pass.

**Tests**: a regression test that fails today and passes after. Strict renders of the affected scene at 1920x1080 and 5120x1440.

**Constraints**: minimal code; CRLF/ASCII. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/rel-M6/`). Open a PR (not a draft) against `staging` titled `fix: the Medallions quest card and guide card tops line up` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after`. Do not merge. Be fast: the release waits on this.

**Files it may edit**: `Core/Setup/Layouts.lua` (defaults only; no new top-level local), `KstyleUI_Skins/Quests/**` (only if needed), `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched and reach tests under PUC Lua 5.1. Send worker_done with the hosted CI run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
