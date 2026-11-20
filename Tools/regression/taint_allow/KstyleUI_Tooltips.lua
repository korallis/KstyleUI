-- KstyleUI_Tooltips.lua: reviewed taint-scan exceptions for KstyleUI_Tooltips/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Tooltips/Anchor.lua"] = {
		why = "KstyleUI widget hover handlers call Show on the shared private tooltip on hover and content refresh, never on a per-frame driver. The hook places it away from the minimap for the current owner; other addons do not own this tooltip.",
		calls = {
			["tooltip:Show"] = 1,
		},
	},
}
