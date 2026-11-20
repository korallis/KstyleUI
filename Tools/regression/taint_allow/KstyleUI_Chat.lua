-- KstyleUI_Chat.lua: reviewed taint-scan exceptions for KstyleUI_Chat/. Tools/regression/README.md has the format.
return {
	["KstyleUI_Chat/Frames.lua"] = {
		why = "Blizzard chat tab fade animations call SetAlpha each animation tick; chat addons may also change it. The hook checks the module/readability switches and pins only a changed alpha under recursion guards, retaining the original alpha.",
		calls = {
			["tab:SetAlpha"] = 1,
		},
	},
	["KstyleUI_Chat/Messages.lua"] = {
		why = "With Link tooltips on hover on, GameTooltip shows a hovered chat link's tooltip and hides when the pointer leaves the link, only while the tooltip is still owned by that chat window, as Blizzard's own hyperlink tooltips do. GameTooltip is not a layout frame and is never protected.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_Chat/Panel.lua"] = {
		why = "Blizzard and chat addons set the edit-box and tab alpha on focus and fade ticks: the alpha hooks retain the wanted alpha and follow the fade under guards. Blizzard docking, Edit Mode and KstyleUI layout call chat SetPoint on dock, drag, resize and reload; Schedule coalesces placement and exits during its own placement.",
		calls = {
			["frame.editBox:SetAlpha"] = 1,
			["chat:SetPoint"] = 1,
			["tab:SetAlpha"] = 1,
		},
	},
}
