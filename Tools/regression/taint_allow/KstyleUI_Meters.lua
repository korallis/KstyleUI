-- KstyleUI_Meters.lua: reviewed taint-scan exceptions for KstyleUI_Meters/. Tools/regression/README.md has the format.
return {
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
