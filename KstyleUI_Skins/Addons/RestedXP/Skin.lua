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
	defaults = { rail = true },
	rows = {
		{
			type = "toggle", key = "rail", label = L["Story rail"],
			help = L["Puts the guide in its own card on the story rail. Drag the guide away to keep your spot."],
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
		RestedXP.Rail.Switch(on and ns.Skins.Setting("restedXP", "rail") == true)
	end,
	OnSetting = function(_, field)
		if field == nil or field == "rail" then
			RestedXP.Rail.Switch(ns.Skins.Setting("restedXP", "rail") == true)
		end
	end,
})
