-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.4 (2026-11-23)", {
		L["Every class now has its own crest: your buffs, procs, debuffs and cooldowns, one place to look."],
		L["Major cooldowns burn round the rim, and mana users see the five-second rule round the level badge."],
		L["Each piece has its own switch, on by default, and Frames shows them in a row above the stance bar."],
		L["Warlocks see their Soul Shards from the bags as wisps on the crest."],
		L["Stings and Rapid Fire on the hunter crest, thanks to the hunters in Discord."],
		L["World map fixes thanks to Baine: search sits top-right, clears on close, and zone labels keep their size."],
	} },
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
}
