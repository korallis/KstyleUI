-- Skin.lua: the RestedXP switch: once RestedXP Guides has loaded it makes the KstyleUI theme RestedXP's active theme, restyles RestedXP's windows as they appear, and puts the guide in the layout's story rail.
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
			help = L["Places the guide in the layout's story rail, above the quests. Drag it away to keep your spot."],
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
