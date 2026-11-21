-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.8.4 (2026-11-21)", {
		L["With the meter on Both, the threat card no longer covers the stance bar or the Medallions second bar and XP bar."],
		L["Target debuff timers no longer draw over the target's buffs."],
		L["The minimap and unit frame previews in the settings window keep their proper sizes."],
	} },
	{ "v0.2.8.3 (2026-11-21)", {
		L["Character sheet quality borders and selected tabs are thin rings again."],
		L["The stance bar backing fits the stances and forms you have."],
		L["Medallions minimap coordinates sit centred on their plate."],
	} },
	{ "v0.2.8.2 (2026-11-20)", {
		L["RestedXP's guide card shows every line of the current step again, so you can tick it and skip it."],
		L["Ten small fixes, from typing 50 into a percent setting to accented bag and map search and the setup's Modules page."],
		L["Welcome text, the French and German Options footer, the 1080p data bar and colour-vision health bars read right."],
		L["New options for frames, nameplates, cooldowns, auras, chat, minimap, tooltips and Layout Mode, keeping today's look."],
		L["World map routes follow roads, passes, flights and boats, with travel steps and time."],
		L["KstyleUI loads faster after a reload."],
	} },
}
