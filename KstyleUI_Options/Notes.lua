-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.15 (2026-11-22)", {
		L["Party and raid names can sit under the health and power bars, in Medallions and Frames. Off by default."],
		L["Your heal icons on party frames can sit outside the frame, so the name keeps its whole line. Off by default."],
		L["Party and raid frames can follow FrameSort's order while FrameSort is installed."],
	} },
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
}
