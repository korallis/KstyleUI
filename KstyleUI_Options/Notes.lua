-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.14 (2026-11-22)", {
		L["Flask reminder: in a raid, the reminder card names a flask in your bags while no flask is on you. Off by default."],
		L["Low mana at ready checks: the card warns while your mana is under 80 percent. Off by default."],
		L["Party and raid frames: paladin blessing reminders, pets beside their owners, your own place in the party and more."],
		L["Player and target aura settings stay as you set them in every aura layout."],
		L["RestedXP's Active Targets and Active Items boxes stay still when the guide updates."],
		L["Shapeshifting, target changes, RestedXP, Zygor and opening windows do less work, with no change in look."],
	} },
	{ "v0.2.13.1 (2026-11-22)", {
		L["Smoother frame rate with RestedXP and Questie."],
		L["Minimap buttons stay put in the drawer with less work when other addons move them."],
		L["The minimap, auras, chat and meters do less work while you stand still."],
	} },
	{ "v0.2.13 (2026-11-22)", {
		L["Frames is back alongside Medallions, with class crowns, Spirit Poles, Ghost Wolf and Lightning Shield storm orbs."],
		L["RestedXP and Zygor guides move to a card in the top left corner, above the party frames, where a whole step fits."],
		L["The quest log keeps the story rail under the minimap to itself, at its own height."],
		L["The threat meter keeps its own place instead of following the guide card."],
		L["Raid and boss warnings sit in the upper part of MacBook and other 3:2 screens, clear of the boss frames."],
		L["Setup's Apply fits 16 tracked buff icons and a Tank's 6 tracked bars in Edit Mode at Interface size 1."],
	} },
}
