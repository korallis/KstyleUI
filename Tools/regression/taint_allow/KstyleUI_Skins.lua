-- KstyleUI_Skins.lua: reviewed taint-scan exceptions for KstyleUI_Skins/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Skins/PartB/GameMenu.lua"] = {
		why = "The game menu's title is a font string on DialogHeaderTemplate, a plate Blizzard hangs 11 units above the frame; the skin anchors the text inside the glass's header band. GameMenuFrame is not protected and the header runs no secure code, so the re-anchor taints nothing that matters.",
		calls = {
			["GameMenuFrame.Header.Text:ClearAllPoints"] = 1,
			["GameMenuFrame.Header.Text:SetPoint"] = 1,
		},
	},
}
