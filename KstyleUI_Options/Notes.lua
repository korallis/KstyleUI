-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
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
	{ "v0.3.4.4 (2026-11-24)", {
		L["Aura timers and stack counts on your Medallions player, target and focus frames sit clear of the portrait rim."],
		L["The Options preview matches, and Frames looks just as it did."],
		L["The store pages and README have fresh pictures of the crest on every class."],
	} },
}
