# Task: follow-up batch A: fix(skins): RestedXP and Questie cards, consistent headers

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: (1) The RestedXP skin's SectionCap and Path restyles share an unordered weak-key Style registry, so the same code produces two header heights depending on allocation order. Make the order deterministic. (2) The RestedXP guide card and the quest card heights only ever grow (base too); they should shrink back when content shrinks. (3) The Speedrun Guide and menu headers differ from KstyleUI's headers; make them use the shared header (consistency audit). (4) When the player picks Questie's tracker, card it in the KstyleUI style through Questie's own frames, like the RestedXP guide. Make it toggleable and ON. (5) First-time default: when Questie is detected for the first time, start the quest-tracker choice from Questie's current state, so KstyleUI never switches another addon's tracker off by itself (compat audit finding 6). An existing explicit choice is kept.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-A/`). Open a PR (not a draft) against `staging` titled `fix(skins): RestedXP and Questie cards, consistent headers` with `## Changelog` (`Fixed: ...` and `Added: ...` in player words), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Setup/Integrations.lua`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
