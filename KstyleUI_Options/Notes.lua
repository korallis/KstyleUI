-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.5.1 (2026-11-26)", {
		L["Click the quest card's header to fold the card down to that one row, and click again to open it."],
		L["The chat edit box opens in its own strip under the newest line, no longer over your messages."],
		L["You can train again after choosing another spell, and the Train all button the game refused is gone."],
		L["Settings sliders save when you let go, a bad import keeps your text and Layout Mode's Discard puts things back."],
		L["Healer cues stay on raid frames, and nameplates, channels and boss auras read clearer in crowded fights."],
		L["Consumable keys, guide text, tooltips and item readouts get fixes, and the HUD does less work in busy moments."],
	} },
	{ "v0.3.5 (2026-11-25)", {
		L["The crest comes alive: your buffs, procs and cooldowns are part of the crest now, no more little icons."],
		L["Ten new crest effects, from Unleashed cooldowns and rising heat to a cast ring, kill window and target lock."],
		L["Your cooldowns light engraved sigils, and on-use trinkets burn their cooldowns round the crest's rim."],
		L["Rogues and cat druids get an energy tick spark that sweeps the energy bar between ticks."],
		L["Aura timers about to run out turn a lighter red that stays readable over any scenery, on every frame."],
		L["Windows and pages show at once, no more invisible windows, plus RestedXP, loot-roll and Zygor fixes."],
	} },
	{ "v0.3.4.5 (2026-11-24)", {
		L["The crest no longer throws forbidden object Lua errors in combat, like Vanish or Stealth mid-fight."],
		L["Every crest piece keeps lighting, filling and counting through the fight, shaman storm clouds included."],
		L["Your first stance, form or Stealth switch in combat shows its crest pieces at once."],
		L["Medals snap back to whole pixels after you change the UI scale."],
	} },
}
