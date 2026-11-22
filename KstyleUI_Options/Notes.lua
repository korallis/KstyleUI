-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.12 (2026-11-22)", {
		L["KstyleUI is now Medallions only: Frames and Orbs are gone, your HUD moves over on update and setup is shorter."],
		L["Class crowns rise over the crest for rogues, druids, warriors, priests, mages and hunters, on by default."],
		L["Shamans get Spirit Poles, a totem bar on the crest with Ghost Wolf and Call, and Storm Orbs for Lightning Shield."],
		L["Cast bars sit on their frames: yours under the player frame and your target's under the target frame."],
		L["Your own settings now win over the Medallions look, and your buffs no longer show twice on the player frame."],
		L["Key presses, pet cooldowns, target changes and currency updates do less work, with no change in look."],
	} },
	{ "v0.2.11.1 (2026-11-22)", {
		L["With Blizzard's Cooldown Manager switched off, KstyleUI no longer shows its own cooldown icons."],
	} },
	{ "v0.2.11 (2026-11-21)", {
		L["Thanks to Baine, Zygor Guides Viewer sits on the story rail like RestedXP, under Window Skins > Zygor."],
		L["Zygor takes the KstyleUI theme: the forged window card and a themed header, controls, progress bar and waypoint arrow."],
		L["Medallions crest jewels are richer cut gems that flare when you gain a point and drain when you spend one."],
		L["At the maximum the whole crest ring glows in the resource's colour; Glow at max is on by default."],
		L["Hawk perches show each Summon Hawk hawk and its time left on the Medallions crest, an idea from Baine."],
	} },
}
