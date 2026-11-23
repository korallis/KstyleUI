# Task: follow-up batch E: fix(compat): Leatrix Plus and BetterFriendlist, plus a hot-hook guard everywhere

**Goal**: v0.2.7 has shipped. This batch clears queued follow-ups from `specs/QUEUE.md` and the release reviews. Work on the latest `origin/staging`.

**Scope**: Compatibility audit batches E and F (`C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`). (1) Leatrix Plus, per feature: read its saved toggles for chat restore, the minimap button bag, faster loot, repair, junk, quests and camera, and switch off only the matching KstyleUI helper while that Leatrix option is on, with the existing one-line notice and the notices toggle. The player can turn the KstyleUI helper back on. (2) BetterFriendlist replaces the Friends frame, so the Friends window skin yields while it's loaded, through a 'yields' field in Skins.Add read by Registry.Arm. (3) Guard G1 everywhere: extend taint_scan.lua's hot-hook kind (Minimap entries already exist from #518) to every area. Flag hooksecurefunc on SetPoint, Show, Hide, SetShown or SetAlpha, and HookScript OnUpdate. List today's sites in taint_allow with a why for each, and make the failure message name the fix. Cite Leatrix's public source for the saved-variable keys; copy no code.

**Rules**:
- Owner rules apply: one consistent style; everything toggleable, ON by default; minimal code.
- Never move a saved position.
- `test-perf-path-budgets` stays under 15.7M (staging is at about 14.84M).
- Visual changes come with before and after strict renders at 1920x1080 and 5120x1440. Changes that should be invisible must be pixel-identical.

**Tests**: a regression test for each fix that fails before it, with a failure message that names the fix.

**Constraints**: CRLF/ASCII for addon files; locales synced with translations. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-E/`). Open a PR (not a draft) against `staging` titled `fix(compat): Leatrix Plus and BetterFriendlist, plus a hot-hook guard everywhere` with `## Changelog` (`Fixed: KstyleUI steps aside for the Leatrix Plus features you have on, and for BetterFriendlist's friends window.`), `## In-game checks` and `## Before and after` where visual. Do not merge.

**Files it may edit**: `Core/Setup/Integrations.lua`, `KstyleUI_QoL/**`, `KstyleUI_Chat/**`, `KstyleUI_Minimap/**` (yield only), `KstyleUI_Skins/Registry.lua` and the Friends skin, `Tools/regression/taint_*`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, the touched modules' READMEs.

**Gate**: lint, python and the touched tests under PUC Lua 5.1; CI is hosted and fast. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
