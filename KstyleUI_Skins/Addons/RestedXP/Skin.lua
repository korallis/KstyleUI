-- Skin.lua: the RestedXP switch: once RestedXP Guides has loaded it draws RestedXP's guide in the KstyleUI theme without touching RestedXP's settings, restyles RestedXP's windows as they appear, puts the guide in the layout's story rail and docks the quests under it as one card.
local _, ns = ...

local K = KstyleUI
local L = K.L
local RestedXP = ns.RestedXP

ns.Skins.Add({
	key = "restedXP",
	label = L["RestedXP"],
	help = L["Gives RestedXP Guides the KstyleUI theme and restyles its windows."],
	addon = "RXPGuides",
	defaults = { rail = true, dock = true },
	rows = {
		{
			type = "toggle", key = "rail", label = L["Story rail"],
			help = L["Places the guide in the layout's story rail, above the quests. Drag it away to keep your spot."],
		},
		{
			type = "toggle", key = "dock", label = L["One card with the quests"],
			help = L["Runs the guide's glass down over the quest tracker when Apply put the tracker under the guide."],
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
		if field == "dock" then
			if ns.Skins.Setting("restedXP", "dock") == true then
				RestedXP.Rail.Schedule()
			else
				RestedXP.Rail.Undock()
			end
		end
	end,
})
