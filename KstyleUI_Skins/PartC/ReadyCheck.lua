-- ReadyCheck.lua: the ready check skin: the question dialog on a glass panel with a heading, body text and restyled ready and not ready buttons.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Style, Skins, Kit = ns.Style, ns.Skins, ns.PartC

local KEY = "readyCheck"
local BUTTONS = { "YesButton", "NoButton" }

local function Apply()
	local dialog = Kit.Frame(KEY, "ReadyCheckListenerFrame")
	if not dialog then
		return
	end
	Kit.Window(dialog)
	if dialog.Text then
		Style.Text(dialog.Text, "body", "textEmphasis")
	end
	Kit.Each(KEY, dialog, BUTTONS, Kit.Button)
end

Skins.Add({
	key = KEY,
	label = L["Ready check"],
	help = L["Restyles the ready check question and its two buttons."],
	frame = "ReadyCheckFrame",
	Apply = Apply,
})
