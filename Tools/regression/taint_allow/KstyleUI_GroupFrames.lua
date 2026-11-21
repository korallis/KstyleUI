-- KstyleUI_GroupFrames.lua: reviewed taint-scan exceptions for KstyleUI_GroupFrames/. Tools/regression/README.md has the format.
return {
	["KstyleUI_GroupFrames/Button.lua"] = {
		why = "The unit tooltip is hidden when the pointer leaves a group frame that owns it, as Blizzard's unit frames do on OnLeave. GameTooltip is not a layout frame, and only a tooltip this frame opened is hidden.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_GroupFrames/Style.lua"] = {
		why = "Text above icons moves the frame's own name, health and extra font strings between its own two text layers, so only they rise over the icons; no Blizzard or Edit Mode frame is reparented.",
		calls = {
			["f[?]:SetParent"] = 1,
		},
	},
}
