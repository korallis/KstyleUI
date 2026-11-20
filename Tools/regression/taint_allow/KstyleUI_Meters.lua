-- KstyleUI_Meters.lua: reviewed taint-scan exceptions for KstyleUI_Meters/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Meters/BarList.lua"] = {
		why = "GameTooltip shows a spell's tooltip while the pointer is over a spell row in the damage meter's spell list and hides on mouse-out or when the row changes to another spell or source, only while that row owns it, as Blizzard's own buttons do. GameTooltip is not a layout frame and is never protected.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_Meters/DamageSkin.lua"] = {
		why = "Blizzard damage-meter layout refreshes set decorative region alpha when the session, display or window changes; other skins may also set it. Rehush restores zero with a recursion guard to keep the replacement chrome visible.",
		calls = {
			["region:SetAlpha"] = 1,
		},
	},
	["KstyleUI_Meters/Swing.lua"] = {
		why = "Blizzard refreshes the native swing frames on swing state changes; a fading addon can set alpha each fade tick. Rehold records the requested alpha and restores zero only while KstyleUI holds the native timer, under a recursion guard.",
		calls = {
			["_G[?]:SetAlpha"] = 1,
		},
	},
}
