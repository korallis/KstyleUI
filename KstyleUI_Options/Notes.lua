-- Notes.lua: the highlights of the newest three versions in CHANGELOG.md, shown under About > What's new; test-options-notes keeps them in step.
local _, ns = ...
local L = KstyleUI.L
ns.NOTES = {
	{ "v0.3.5.3 (2026-11-27)", {
		L["A new switch in General > Size lets KstyleUI follow the game's UI Scale instead of its pixel-perfect size."],
		L["Setup offers it too, and windows it placed stay put as the UI Scale changes; old damage meters need setup again."],
	} },
	{ "v0.3.5.2 (2026-11-27)", {
		L["A bar shape that cannot fit beside the others no longer shrinks the whole HUD below its usual size."],
		L["Two-row action bars lift the frames above them by a row, so the bars no longer cover the player frame."],
	} },
	{ "v0.3.5.1 (2026-11-26)", {
		L["Click the quest card's header to fold the card down to that one row, and click again to open it."],
		L["The chat edit box opens in its own strip under the newest line, no longer over your messages."],
		L["You can train again after choosing another spell, and the Train all button the game refused is gone."],
		L["Settings sliders save when you let go, a bad import keeps your text and Layout Mode's Discard puts things back."],
		L["Healer cues stay on raid frames, and nameplates, channels and boss auras read clearer in crowded fights."],
		L["Consumable keys, guide text, tooltips and item readouts get fixes, and the HUD does less work in busy moments."],
	} },
}
