-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.1 (2026-11-23)", {
		L["Your character window and the inspect window show each piece of gear's item level, in its quality colour."],
		L["The trainer, Legacy, RestedXP and quest tracker bars KstyleUI restyles get the same lit glass finish."],
		L["World map routes name every step, and the last one names where you are going."],
		L["A debuff you can dispel tints party and raid frames lightly again instead of covering the name."],
	} },
	{ "v0.3.0 (2026-11-23)", {
		L["A clean screen at rest: out of combat with no target, your bars and player frame fade until you need them again."],
		L["One lit glass finish on every bar, and Medallions names, levels and cast names in one typeface."],
		L["Target and focus cast bars show who a spell is aimed at, and when your interrupt is back."],
		L["The world map finds the nearest innkeeper, bank or trainer you have visited and routes by zeppelin, tram or hearth."],
		L["Options search takes you straight to the setting, and the first run shows big pictures and one-click Looks."],
	} },
	{ "v0.2.15 (2026-11-22)", {
		L["Party and raid names can sit under the health and power bars, in Medallions and Frames. Off by default."],
		L["Your heal icons on party frames can sit outside the frame, so the name keeps its whole line. Off by default."],
		L["Party and raid frames can follow FrameSort's order while FrameSort is installed."],
	} },
}
