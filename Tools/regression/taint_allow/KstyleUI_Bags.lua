-- KstyleUI_Bags.lua: reviewed taint-scan exceptions for KstyleUI_Bags/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Bags/Blizzard.lua"] = {
		why = "Release closes Blizzard's bag frames only while Safe keeps them under its hidden parent and they are shown but not visible. Hiding a frame that is not visible runs none of its scripts, so no Blizzard code runs in KstyleUI's context; it only clears the shown flag Blizzard's own toggle reads, so the next key press opens the bags.",
		calls = {
			["ContainerFrameCombinedBags:Hide"] = 1,
			["_G[?]:Hide"] = 1,
		},
	},
	["KstyleUI_Bags/Window.lua"] = {
		why = "Adopt moves a slot's item button between KstyleUI's own bag frames when its item changes category. The button is KstyleUI's, made from Blizzard's template out of combat, and both parents are KstyleUI frames that carry the bag's ID, so no Blizzard frame moves and GetBagID still reads the right bag. In combat the move waits for Combat.Queue through Widgets.MayMove.",
		calls = {
			["slot.button:SetParent"] = 1,
		},
	},
}
