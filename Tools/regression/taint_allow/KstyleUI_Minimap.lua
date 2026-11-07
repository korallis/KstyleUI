-- KstyleUI_Minimap.lua: reviewed taint-scan exceptions for KstyleUI_Minimap/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Minimap/Map.lua"] = {
		why = "Minimap is the one minimap renderer the game has: an addon cannot build a replacement, so KstyleUI hosts it. "
			.. "It is not a protected frame and no Blizzard code moves, sizes or reparents it on Forever, only sets its mask. "
			.. "Adopt moves it into KstyleUI's frame once, out of Edit Mode, and anchors it to the map square with SetAllPoints, "
			.. "so later resizes never touch it. Release puts it back in MinimapContainer with its saved points and size when the "
			.. "module turns off. The rest of the cluster is hidden through Safe.HideBlizzard. "
			.. "QueueStatusButton is faded with alpha, not hidden, because its own context menu closes when its owner is "
			.. "not visible (Blizzard_Menu/Menu.lua). It sits on KstyleUI's map by its Edit Mode anchor to Minimap, so its "
			.. "mouse is turned off while it is faded and back on when the column's queue button is off. It is not protected.",
		calls = {
			["QueueStatusButton:EnableMouse"] = 1,
			["Minimap:SetParent"] = 2,
			["Minimap:ClearAllPoints"] = 2,
			["Minimap:SetAllPoints"] = 1,
			["Minimap:SetPoint"] = 1,
			["Minimap:SetSize"] = 1,
		},
	},
}
