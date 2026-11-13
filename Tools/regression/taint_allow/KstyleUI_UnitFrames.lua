-- KstyleUI_UnitFrames.lua: reviewed taint-scan exceptions for KstyleUI_UnitFrames/. Tools/regression/README.md has the format.
return {
	["KstyleUI_UnitFrames/Orbs.lua"] = {
		why = "The Orbs tray is KstyleUI's own frame. It moves between KstyleUI's root and the action bar 1 holder, a KstyleUI frame that Layout owns, so it shows, hides and fades with bar 1. No Blizzard frame is reparented. In combat the move waits for Combat.Queue.",
		calls = {
			["tray:SetParent"] = 1,
		},
	},
}
