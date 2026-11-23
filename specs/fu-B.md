# Task: follow-up batch B: fix(style): bar sparks and tracked bars match

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: (1) Party bars draw a fill-end spark, but tooltip and tracked bars don't. Pick one rule for every bar of that kind (the shared bar language, #496/#527) and apply it. (2) Blizzard's fallback tracked bars stay about 24 px (Edit Mode) against the mirror's 12; match them to the shared bar height when KstyleUI owns their look.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-B/`). Open a PR (not a draft) against `staging` titled `fix(style): bar sparks and tracked bars match` with `## Changelog` (`Fixed: ...`), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `KstyleUI_Tooltips/**`, `KstyleUI_Cooldowns/**`, `Core/Widgets/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
