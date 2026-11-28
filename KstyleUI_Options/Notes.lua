-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.5.5 (2026-11-28)", {
		L["Setup keeps Replace this one and Apply on screen when every Edit Mode layout is in use, so you can pick one to replace."],
		L["Setup's Your addons step draws its switches and dropdowns whole the first time it opens."],
	} },
	{ "v0.3.5.4 (2026-11-28)", {
		L["Cooldown viewers an older setup placed follow the HUD again when you change its width or switch Centred and Spread."],
	} },
	{ "v0.3.5.3 (2026-11-27)", {
		L["A new switch in General > Size lets KstyleUI follow the game's UI Scale instead of its pixel-perfect size."],
		L["Setup offers it too, and windows it placed stay put as the UI Scale changes; old damage meters need setup again."],
	} },
}
