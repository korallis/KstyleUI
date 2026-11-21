-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.2.11 (2026-11-21)", {
		L["Thanks to Baine, Zygor Guides Viewer sits on the story rail like RestedXP, under Window Skins > Zygor."],
		L["Zygor takes the KstyleUI theme: the forged window card and a themed header, controls, progress bar and waypoint arrow."],
		L["Medallions crest jewels are richer cut gems that flare when you gain a point and drain when you spend one."],
		L["At the maximum the whole crest ring glows in the resource's colour; Glow at max is on by default."],
		L["Hawk perches show each Summon Hawk hawk and its time left on the Medallions crest, an idea from Baine."],
	} },
	{ "v0.2.10 (2026-11-21)", {
		L["KstyleUI draws less every frame, up to a quarter less area, with no change in how it looks."],
		L["Medallions switches for Low-health vignette and Ambient hub effects trade effects for frame rate, both on by default."],
		L["Thanks to Baine, /kstyle perf records your frame rate and KstyleUI's Lua time for frame-rate reports."],
		L["Party frames can follow the raid's settings, and indicators can be coloured squares or bars that drain."],
		L["Party and raid frames gain a shield edge, a raid size of your own and tank frames that can leave you out."],
	} },
	{ "v0.2.9.2 (2026-11-21)", {
		L["Tooltips on the top data bar open clear of the bar, so every button stays reachable."],
	} },
}
