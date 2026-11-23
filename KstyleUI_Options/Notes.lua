-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.2 (2026-11-23)", {
		L["While you play with a gamepad, your keybinds show its Xbox, PlayStation or Switch buttons instead of key names."],
		L["Pick Keyboard or Gamepad in setup or on the General page; Gamepad sets up bars 1 and 2 for a controller."],
		L["Shaman totem fans open on a dark forged band in the element's colour, and each choice wears its element."],
		L["The consumables bar starts at button size 26 with no gap between buttons."],
		L["Setup and Options pages no longer open blank in game."],
	} },
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
}
