# Task: fix issues 4, 5, 6 and 7 from the owner's gameplay video

Read `C:/Users/leeba/.cache/kstyleui-evidence/video-1120/report.md`, section 3, issues **4, 5, 6 and 7**. The crops are in that folder. Recorded on v0.2.7, Medallions HUD, 5120x1440; check against current `origin/staging`.

These are Layout Mode overlaps:
- the Essential Cooldowns mover over Utility Cooldowns, with its label on the position readout;
- the toolbar covering the Boss Announcements mover;
- the Experience Bar mover over Action Bar 1, with the clock jammed under it;
- the CHAT mover label over the chat tab.

Some may be real element overlaps in the default Medallions layout at 5120x1440, rather than label placement only: check `test-setup-collisions` and the layout presets, and fix the layout if the elements themselves overlap. Mover labels and readouts must never sit on each other or on game text.

**For each issue**:
- find the root cause with file:line;
- write a regression test that fails on the old code;
- fix it with minimal code, in one consistent style;
- use strict renders at 1920x1080 and 5120x1440 (plus 2560x1440 and 3840x2160 where layout is involved) over real game backdrops, with before and after crops;
- if an issue no longer happens on staging, prove it with a render and say so.

Evidence goes to `C:/Users/leeba/.cache/kstyleui-evidence/video-fix-layoutmode/` and is never committed.

**PR**: open a PR (not a draft) against `staging` titled `fix(layout): Layout Mode movers and labels never overlap`. Include `## Changelog` (`Fixed:` lines), `## In-game checks` and `## Before and after`. Do not merge.

**Constraints**:
- Minimal code. CRLF/ASCII; locales synced if strings change.
- Perf changes must be pixel-identical.
- Beast speed rule: no full local Lua suite, at most 2 renders at a time.

**Gate**: lint, python, the touched modules' tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Send worker_done once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
