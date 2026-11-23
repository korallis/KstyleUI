# Task: follow-up batch C: fix(core): login notice once, and recoloured hidden textures stay hidden

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: (1) The login chat notice 'KstyleUI: Turn on the Cooldown Manager in Options > Gameplay > Advanced Options...' prints on every login (11 times in one player's log). Show it once per account, and only when it applies: the Cooldowns module is on and the CVar is off. Do the same for any other one-off login notice. (2) Core Hush has no SetColorTexture hook for other textures. Check whether a recolour can revive a hidden texture there; if it can, hook it the same way as the existing hooks, minimally, and prove it with a test.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-C/`). Open a PR (not a draft) against `staging` titled `fix(core): login notice once, and recoloured hidden textures stay hidden` with `## Changelog` (`Fixed: The Cooldown Manager tip shows once instead of at every login.`), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `Core/**`, `KstyleUI_Cooldowns/**` (the notice only), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
