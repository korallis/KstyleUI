-- KstyleUI_Minimap.lua: reviewed taint-scan exceptions for KstyleUI_Minimap/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Minimap/Map.lua"] = {
		why = "Minimap is the one minimap renderer the game has: an addon cannot build a replacement, so KstyleUI hosts it. "
			.. "It is not a protected frame and no Blizzard code moves, sizes or reparents it on Forever, only sets its mask. "
			.. "Adopt moves it into KstyleUI's frame once, out of Edit Mode; Fit gives it one CENTER point on the map square and "
			.. "an explicit SetSize adjusted for its scale (on adopt, refresh and resize, out of combat or queued), because the engine "
			.. "renders the terrain at the size SetSize gave, not the anchored rect: anchors alone left Blizzard's 198 render "
			.. "in the 217 square (ingame-18). Release puts it back in MinimapContainer with its saved points and size when the "
			.. "module turns off. The rest of the cluster is hidden through Safe.HideBlizzard. "
			.. "Fit uses SetScale to keep map pins at least their native size unless compact icons are chosen, and Release "
			.. "restores the saved scale; both check Widgets.MayMove and queue through Combat before any protected change "
			.. "(SimpleFrameAPIDocumentation.lua: SetScale; test-minimap-icon-size.lua covers the combat deferral). "
			.. "QueueStatusButton is faded with alpha, not hidden, because its own context menu closes when its owner is "
			.. "not visible (Blizzard_Menu/Menu.lua). It sits on KstyleUI's map by its Edit Mode anchor to Minimap, so its "
			.. "mouse is turned off while it is faded and back on when the column's queue button is off. It is not protected. "
			.. "The SetAlpha hook on it fades it again when other code sets its alpha; nothing in Blizzard_QueueStatusFrame does, "
			.. "so it guards against an addon that would, and compares one number. holder is KstyleUI's own map frame: only Layout places it, on a "
			.. "move or a rescale, and the SetPoint hook lays the map out again only when the point changed.",
		calls = {
			["QueueStatusButton:EnableMouse"] = 1,
			["QueueStatusButton:SetAlpha"] = 1,
			["holder:SetPoint"] = 1,
			["Minimap:SetParent"] = 2,
			["Minimap:ClearAllPoints"] = 2,
			["Minimap:SetPoint"] = 2,
			["Minimap:SetSize"] = 2,
			["Minimap:SetScale"] = 2,
		},
	},
	["KstyleUI_Minimap/Column.lua"] = {
		why = "button is one of KstyleUI's own crystal buttons, never a Blizzard frame. With Buttons only on hover on, Layout moves the tracking, "
			.. "calendar and drawer buttons into the face's hover group, and back to the always-shown host when it is off.",
		calls = {
			["self.buttons[?]:SetParent"] = 1,
		},
	},
	["KstyleUI_Minimap/Pins.lua"] = {
		why = "pin is another addon's map pin that HereBeDragons-Pins-2.0 placed. The library calls SetPoint on every active "
			.. "pin on every frame while the player moves or the map turns (drawMinimapPin), so Check returns after two reads "
			.. "while edge pins are kept or the module is off. While they are faded out it reads the pin's point and the map's "
			.. "size, and changes the pin only when it crosses the edge; test-minimap-pins.lua holds the instruction budget.",
		calls = {
			["pin:SetPoint"] = 1,
		},
	},
	["KstyleUI_Minimap/Drawer.lua"] = {
		why = "button is a LibDBIcon button that another addon made on Minimap, never a Blizzard frame. "
			.. "Adopt moves it into the drawer, skipping a protected button in combat; Stop hands it back to its first "
			.. "parent and asks LibDBIcon to place it again when the module turns off. "
			.. "The SetPoint, SetAlpha, Show and Hide hooks go once on a collected button. LibDBIcon and the addons that draw "
			.. "their own button call these when the player drags the button, on the button's fade and on a refresh, never every "
			.. "frame: SetPoint puts that one button back in its slot, SetAlpha keeps it opaque, and Show and Hide lay the drawer "
			.. "out only when the button's shown state changed. The frames addons do move every frame, map pins and gathering "
			.. "nodes, never get these hooks: Collect skips a HereBeDragons pin, held or released, and a Button with no click "
			.. "script (test-minimap-pins.lua).",
		calls = {
			["button:SetParent"] = 2,
			["button:SetPoint"] = 1,
			["button:SetAlpha"] = 1,
			["button:Show"] = 1,
			["button:Hide"] = 1,
		},
	},
}
