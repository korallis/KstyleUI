# Task: follow-up batch D: refactor(options): trim the lazy-schema leftovers

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: From the #532 review (`C:/Users/leeba/.cache/kstyleui-evidence/perf-headroom/verify-532.md`): remove the 10 dead memo guards and the 8 preview wrappers (about 40 lines), behaviour-identical. Prove options, preview, search and settings tests unchanged, renders pixel-identical, and reload no higher.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-D/`). Open a PR (not a draft) against `staging` titled `refactor(options): trim the lazy-schema leftovers` with `## Changelog` (`no changelog` label (no player change)), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `Core/Options.lua`, `KstyleUI_*/Settings.lua`, `KstyleUI_*/Module.lua`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
