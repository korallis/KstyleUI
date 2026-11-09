-- KstyleUI_DataBars.lua: reviewed taint-scan exceptions for KstyleUI_DataBars/. Tools/regression/README.md has the format.
return {
	["KstyleUI_DataBars/Menus.lua"] = {
		why = "bars[?].content is KstyleUI's own plain frame that holds a menu bar's secure buttons, never a Blizzard "
			.. "frame. Menus.SetDock moves it between its Layout holder and the readout card's strip, and queues the move "
			.. "for PLAYER_REGEN_ENABLED when it is called in combat, so the secure buttons under it never move in combat.",
		calls = {
			["bars[?].content:SetParent"] = 2,
		},
	},
}
