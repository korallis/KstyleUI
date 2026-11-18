-- Skin.lua: the RestedXP switch: once RestedXP Guides has loaded it draws RestedXP's guide in the KstyleUI theme without touching RestedXP's settings, restyles RestedXP's windows as they appear and puts the guide in a card of its own on the story rail.
local _, ns = ...

local K = KstyleUI
local L = K.L
local RestedXP = ns.RestedXP

ns.Skins.Add({
	key = "restedXP",
	label = L["RestedXP"],
	help = L["Gives RestedXP Guides the KstyleUI theme and restyles its windows."],
	addon = "RXPGuides",
	defaults = { rail = true, boxes = true, compose = true },
	rows = {
		{ type = "toggle", key = "compose", label = L["Align story cards"], help = L["Give story cards a shared lower edge and gutter. Off restores their previous sizes."] },
		{
			type = "toggle", key = "rail", label = L["Story rail"],
			help = L["Puts the guide in its own card on the story rail. Drag the guide away to keep your spot."],
		},
		{
			type = "toggle", key = "boxes", label = L["Dock RestedXP's boxes"],
			help = L["Docks RestedXP's target and item boxes under the guide's card. Drag one away to keep your spot."],
		},
	},
	Apply = function()
		local rxp = RestedXP.Addon()
		if not rxp then
			return
		end
		RestedXP.Theme.Start(rxp)
		RestedXP.Chrome.Start(rxp)
		RestedXP.Rail.Start(rxp)
	end,
	OnSwitch = function(_, on)
		RestedXP.Theme.Switch(on)
		local rxp = on and RestedXP.Addon()
		if rxp then
			RestedXP.Chrome.Start(rxp)
		end
		RestedXP.Chrome.SwitchArrow()
		RestedXP.Rail.Switch(on and ns.Skins.Setting("restedXP", "rail") == true)
	end,
	OnSetting = function(_, field)
		if field == nil or field == "rail" then
			RestedXP.Rail.Switch(ns.Skins.Setting("restedXP", "rail") == true)
		elseif field == "compose" then
			local rxp = RestedXP.Addon()
			if rxp then RestedXP.Chrome.Refit(rxp.RXPFrame) end
			if ns.Quests and ns.Quests.Replace then ns.Quests.Replace() end
			RestedXP.Rail.Schedule()
		elseif field == "boxes" then
			RestedXP.Rail.Schedule()
		end
	end,
})
