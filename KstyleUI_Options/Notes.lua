-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.4.2 (2026-11-24)", {
		L["The world map keeps its terrain art after you view another zone, close the map and open it again."],
		L["The /kstyle setup window no longer shows a Lua error when you press Next on the first page."],
		L["Setup's Welcome, Modules and Your addons lists draw every row straight away, no scroll needed."],
		L["Thanks to Baine for finding and testing these."],
	} },
	{ "v0.3.4.1 (2026-11-24)", {
		L["Party and raid frames show each buff once, so Find Minerals or a zone buff no longer turns up twice on a member."],
		L["The External and Big defensives indicators stay empty for now, as Forever doesn't report defensives yet."],
		L["Thanks to Baine for spotting this."],
	} },
	{ "v0.3.4 (2026-11-23)", {
		L["Every class now has its own crest: your buffs, procs, debuffs and cooldowns, one place to look."],
		L["Major cooldowns burn round the rim, and mana users see the five-second rule round the level badge."],
		L["Each piece has its own switch, on by default, and Frames shows them in a row above the stance bar."],
		L["Warlocks see their Soul Shards from the bags as wisps on the crest."],
		L["Stings and Rapid Fire on the hunter crest, thanks to the hunters in Discord."],
		L["World map fixes thanks to Baine: search sits top-right, clears on close, and zone labels keep their size."],
	} },
}
