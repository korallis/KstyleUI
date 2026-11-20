-- KstyleUI_UnitFrames.lua: reviewed taint-scan exceptions for KstyleUI_UnitFrames/. Tools/regression/README.md has the format.
return {
	["KstyleUI_UnitFrames/Orbs.lua"] = {
		why = "The Orbs tray is KstyleUI's own frame. It moves between KstyleUI's root and the action bar 1 holder, a KstyleUI frame that Layout owns, so it shows, hides and fades with bar 1. No Blizzard frame is reparented. In combat the move waits for Combat.Queue.",
		calls = {
			["tray:SetParent"] = 1,
		},
	},
	["KstyleUI_UnitFrames/Auras.lua"] = {
		why = "KstyleUI unit-frame range and visibility fades call holder SetAlpha on range updates and every fade tick. The hook forwards that alpha once to the private aura host so restricted aura children follow the unit frame; Blizzard and other addons do not drive this holder.",
		calls = {
			["view.uf.holder:SetAlpha"] = 1,
		},
	},
}
