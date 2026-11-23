# Task: fix issues 8, 9, 11 and 12 from the owner's gameplay video

Read `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/report.md`, section 3, issues **8, 9, 11 and 12**. The crops are in that folder. Recorded on v0.2.7, Medallions HUD, 5120x1440; check against current `origin/staging`.

- **8:** the RestedXP guide card is a fixed height, so it sits mostly empty beside the quest card, and it has a stray 1-px tick at its right edge. Size it to its content, keeping a sensible minimum.
- **9:** the durability doll sits on the guide card and under the minimap coordinate plate. Give it its own clear spot.
- **11:** the Options Tasks page is six rows with two-thirds empty and no preview column. Make it match the other pages' structure.
- **12:** the Options Text page's Live Preview shows boss timers. Show text that the page's settings actually change.

**For each issue**:
- find the root cause with file:line;
- write a regression test that fails on the old code;
- fix it with minimal code, in one consistent style;
- use strict renders at 1920x1080 and 5120x1440 (plus 2560x1440 and 3840x2160 where layout is involved) over real game backdrops, with before and after crops;
- if an issue no longer happens on staging, prove it with a render and say so.

Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/video-fix-cards-options/` and is never committed.

**PR**: open a PR (not a draft) against `staging` titled `fix(ui): guide card fits its steps, and the Options Tasks and Text pages`. Include `## Changelog` (`Fixed:` lines), `## In-game checks` and `## Before and after`. Do not merge.

**Constraints**:
- Minimal code. CRLF/ASCII; locales synced if strings change.
- Perf changes must be pixel-identical.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Send worker_done once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
