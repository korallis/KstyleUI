-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.8.5 (2026-11-21)", {
		L["With Debuffs and buffs, the target's aura rows stay clear of the target cast bar and the target of target."],
		L["On Medallions party frames, your heal icons no longer cover the health percent or the indicator icons."],
		L["The unit frame preview in the settings window shows the target's debuff and buff rows."],
	} },
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
}
