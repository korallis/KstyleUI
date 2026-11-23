# Task: fix issues 1 and 2-3 from the owner's gameplay video

Read `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/report.md`, section 3, issues **1 and 2-3**. The crops are in that folder. Recorded on v0.2.7, Medallions HUD, 5120x1440; check against current `origin/staging`.

1 is the data bar's first FPS sample after a loading screen reading 240000: ignore or clamp the first sample after a load. 2 and 3 are the duplicate "100%" under the player frame (the power percent outside the card chrome) and the Layout Mode Player Frame box not containing it: the percent belongs inside the card or is not shown twice, and the mover box covers the whole frame.

**For each issue**:
- find the root cause with file:line;
- write a regression test that fails on the old code;
- fix it with minimal code, in one consistent style;
- use strict renders at 1920x1080 and 5120x1440 (plus 2560x1440 and 3840x2160 where layout is involved) over real game backdrops, with before and after crops;
- if an issue no longer happens on staging, prove it with a render and say so.

Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/video-fix-hud/` and is never committed.

**PR**: open a PR (not a draft) against `staging` titled `fix(unitframes): no stray power percent, and no bogus FPS after loading`. Include `## Changelog` (`Fixed:` lines), `## In-game checks` and `## Before and after`. Do not merge.

**Constraints**:
- Minimal code. CRLF/ASCII; locales synced if strings change.
- Perf changes must be pixel-identical.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Send worker_done once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
