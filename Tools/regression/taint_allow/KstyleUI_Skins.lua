-- KstyleUI_Skins.lua: reviewed taint-scan exceptions for KstyleUI_Skins/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Skins/Character.lua"] = {
		why = "The paper doll's sidebar tabs (stats, titles, equipment sets, pet) are plain check buttons that Blizzard anchors flush against each other (PaperDollFrame_UpdateSidebarTabLayout), so their rims would cross; the skin re-anchors the first, third and pet tabs a gapSmall from the middle one, inside their own holder, and does it again after Blizzard's layout through hooksecurefunc. CharacterFrame is not protected and the tabs run no secure code, so the re-anchor taints nothing that matters.",
		calls = {
			["PaperDollSidebarTab1:ClearAllPoints"] = 1,
			["PaperDollSidebarTab1:SetPoint"] = 1,
			["PaperDollSidebarTab3:ClearAllPoints"] = 1,
			["PaperDollSidebarTab3:SetPoint"] = 1,
			["PaperDollSidebarTab4:ClearAllPoints"] = 1,
			["PaperDollSidebarTab4:SetPoint"] = 1,
		},
	},
	["KstyleUI_Skins/PartB/GameMenu.lua"] = {
		why = "The game menu's title is a font string on DialogHeaderTemplate, a plate Blizzard hangs 11 units above the frame; the skin anchors the text inside the glass's header band. GameMenuFrame is not protected and the header runs no secure code, so the re-anchor taints nothing that matters.",
		calls = {
			["GameMenuFrame.Header.Text:ClearAllPoints"] = 1,
			["GameMenuFrame.Header.Text:SetPoint"] = 1,
		},
	},
}
