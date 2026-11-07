-- KstyleUI_Cooldowns.lua: reviewed taint-scan exceptions for KstyleUI_Cooldowns/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Cooldowns/Style.lua"] = {
		why = "GameTooltip shows a spell's tooltip while the pointer is over a KstyleUI cooldown icon and hides on mouse-out, only while the tooltip is owned by that icon, as Blizzard's own cooldown items do. GameTooltip is not a layout frame and is never protected.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
}
