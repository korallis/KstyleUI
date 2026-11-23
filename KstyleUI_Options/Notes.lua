-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.3.1 (2026-11-23)", {
		L["Setup's picked HUD style and role cards show a clean accent edge, and picking Tank now marks its card."],
		L["Setup's tabs fit long German and French labels, and the HUD style pictures sit evenly in their cards."],
		L["No more grey dots on the Medallions player frame: a status socket shows only when its icon is lit."],
		L["The crest minimap's N sits on the forged ring, and the minimap buttons stay inside the round ring."],
		L["Proc glows match the rim of the buttons beside them and can't stay invisible."],
		L["Thanks to Baine for spotting the setup cards and tabs, the grey dots and the compass N."],
	} },
	{ "v0.3.3 (2026-11-23)", {
		L["Party frames are a quarter larger on ultrawide, and their names and health percentages stay readable."],
		L["Medallions player and target frames dock into the crest, with even bars and status icons in steel sockets."],
		L["Incoming heals show in the health bar's own colour instead of a green chunk."],
		L["A polish pass over bars, nameplates, the minimap, chat, bags, tooltips, meters, quests, skins and Options."],
		L["The RestedXP skin works again with RestedXP 4.11.39."],
	} },
	{ "v0.3.2 (2026-11-23)", {
		L["While you play with a gamepad, your keybinds show its Xbox, PlayStation or Switch buttons instead of key names."],
		L["Pick Keyboard or Gamepad in setup or on the General page; Gamepad sets up bars 1 and 2 for a controller."],
		L["Shaman totem fans open on a dark forged band in the element's colour, and each choice wears its element."],
		L["The consumables bar starts at button size 26 with no gap between buttons."],
		L["Setup and Options pages no longer open blank in game."],
	} },
}
