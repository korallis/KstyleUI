-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.9 (2026-11-21)", {
		L["Combo points, holy power and soul shards glow as jewels on the Medallions crest, on by default."],
		L["New options for unit, party and raid frames, nameplates, cooldowns and auras, each keeping today's look."],
		L["A second data bar, a second damage window with reports, a forged Medallions dock and new bag views."],
		L["Alerts, a cursor ring, a crosshair, raid tools and /way waypoints, all off until you turn them on."],
		L["Share whole profiles with your layouts, and read each release's highlights under About > What's new."],
		L["KstyleUI loads faster after a reload."],
	} },
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
}
