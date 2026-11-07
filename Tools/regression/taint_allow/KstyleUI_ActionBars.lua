-- KstyleUI_ActionBars.lua: reviewed taint-scan exceptions for KstyleUI_ActionBars/. Tools/regression/README.md has the format.
return {
	["KstyleUI_ActionBars/Button.lua"] = {
		why = "GameTooltip is hidden when the pointer leaves a KstyleUI action button that showed it, and only while that button owns it, as Blizzard's own action buttons do. GameTooltip is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_ActionBars/Flyout.lua"] = {
		why = "GameTooltip is hidden when the pointer leaves a KstyleUI flyout button that showed it, and only while that button owns it. GameTooltip is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
}
