# Task: RestedXP and Zygor guides on the left; the quest log keeps the story rail

The owner (2026-11-22): "Ideally Zygor and RestedXP would be on the left and the quest log in the story rail." Today the guide card (RestedXP or Zygor, whichever shows last, `KstyleUI_Skins/Guide.lua`) takes the story rail's guide slot under the minimap, which at the automatic size is only ~70 units tall against the ~166-169 one guide step needs, so the card runs ~100 units over action bars 4/5 (measured in PR #709's body). Move the guide card to the left side of the screen in Medallions, in a slot that holds a whole step at every screen (left of/above the chat card or wherever the left column has room: measure Layouts and every reach screen), and give the quest log the story rail (the quest card takes the freed guide slot plus its own column). Keep the Skins guide arbitration, the whole-step behaviour, drag-away handing back, and saved positions. Update `Core/Setup/Layouts.lua` placements (no new top-level locals), Fits/reach planning, Edit Mode tracked spots if they used the slot, docs, the feature map and the setup statechart if the flow changes.

Evidence also as before/after crops of the left column and story rail with RestedXP (step 11 fixture) and Zygor, at all sizes. PR: `feat(skins): guides on the left, quests on the story rail`, `Changed:` line.

**Rules**: minimal code; one forged look; prove with --strict renders over real backdrops at 1920x1080, 2560x1440, 5120x1440, 3840x2160 plus 3456x2234 and 2383x1540; saved positions respected; regression tests that fail on staging; lint, python, module tests, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; hosted CI green. Max 2 renders at a time. Do not merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and evidence paths.

**Files it may edit**: `KstyleUI_Skins/**`, `Core/Setup/Layouts.lua`, `Core/Setup/EditMode.lua` (only if a spot used the slot), `Core/Layout/**`, `Core/Locales/*`, `Tools/locale/*`, `docs/**`, `Tools/regression/**`, `Tools/render/**`.
