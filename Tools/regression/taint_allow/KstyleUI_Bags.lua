-- KstyleUI_Bags.lua: reviewed taint-scan exceptions for KstyleUI_Bags/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Bags/Blizzard.lua"] = {
		why = "Release closes Blizzard's bag frames only while Safe keeps them under its hidden parent and they are shown but not visible. Hiding a frame that is not visible runs none of its scripts, so no Blizzard code runs in KstyleUI's context; it only clears the shown flag Blizzard's own toggle reads, so the next key press opens the bags.",
		calls = {
			["ContainerFrameCombinedBags:Hide"] = 1,
			["_G[?]:Hide"] = 1,
		},
	},
}
