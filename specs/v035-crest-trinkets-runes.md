# Task (v0.3.5): equipped trinkets on the crest's cooldown rim, and a Dark/Demonic Rune kind

Two crest follow-ups from the crest research (`specs/crest-research/` on branch `handoff/coordinator-state`, worktree `../ks-handoff`):

1. **Trinkets on the cooldown rim**: an equipped on-use trinket (slots 13 and 14) burns its cooldown on the crest's cooldown rim next to the class's major cooldowns, using the shared rim families in `KstyleUI_ActionBars/SlabTrackers.lua` (as the racial and potion families do). Prove the item cooldown API from the Forever source (`GetInventoryItemCooldown`, `C_Container`/`C_Item` as the client has them) and only show a trinket that has an on-use effect (`GetItemSpell` or equivalent); update when gear changes (PLAYER_EQUIPMENT_CHANGED), out of combat sizing only (the crest's locked rules from #799 apply: nothing under an engine aura button is written in combat). Do not rely on the trinket's buff (that was in-game check 7). Its own switch, on by default, in both HUD styles (Frames row too).
2. **Dark/Demonic Rune** as a consumable kind next to the potion family (shared cooldown with Dark Rune and Demonic Rune items), proven from the client data.

Regressions for both (equip/unequip, cooldown start/end, no on-use trinket shows nothing, in-combat no forbidden writes). Evidence: crest and Frames row with a trinket cooling down, at 1920x1080 and 5120x1440, 2x crops, in `C:/Users/leeba/.cache/kstyleui-evidence/v035-crest-trinkets-runes/`. Update `docs/medallions-effects.md`.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**` (the switches), `Core/Locales/*`, `Tools/locale/*`, `Tools/regression/**`, `Tools/render/**`, `docs/medallions-effects.md`, `docs/feature-map.md`.

**PR**: `feat(crest): trinkets and runes on the cooldown rim` with a `## Changelog` `Added:` line and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; strings via `strings.py sync`; Beast speed rule (at most 2 renders at once).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
