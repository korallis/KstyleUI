-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.5.4 (2026-11-27)", {
		L["Cooldown viewers an older setup placed follow the HUD again when you change its width or switch Centred and Spread."],
	} },
	{ "v0.3.5.3 (2026-11-27)", {
		L["A new switch in General > Size lets KstyleUI follow the game's UI Scale instead of its pixel-perfect size."],
		L["Setup offers it too, and windows it placed stay put as the UI Scale changes; old damage meters need setup again."],
	} },
	{ "v0.3.5.2 (2026-11-27)", {
		L["A bar shape that cannot fit beside the others no longer shrinks the whole HUD below its usual size."],
		L["Two-row action bars lift the frames above them by a row, so the bars no longer cover the player frame."],
	} },
}
