-- Skin.lua: the RestedXP switch: once RestedXP Guides has loaded it draws RestedXP's guide in the KstyleUI theme without touching RestedXP's settings, restyles RestedXP's windows as they appear and puts the guide in a card of its own in the top left corner.
local _, ns = ...

local K = KstyleUI
local L = K.L
local RestedXP = ns.RestedXP

ns.Guide.Add("restedXP", {
	addon = "RXPGuides",
	Enabled = function()
		return RestedXP.Addon() ~= nil and ns.Skins.IsOn("restedXP") and ns.Skins.Setting("restedXP", "rail") == true
	end,
	Visible = function()
		return RestedXP.Rail.Shown()
	end,
	Schedule = RestedXP.Rail.Schedule,
})

ns.Skins.Add({
	key = "restedXP",
	label = L["RestedXP"],
	help = L["Gives RestedXP Guides the KstyleUI theme and restyles its windows."],
	addon = "RXPGuides",
	defaults = { rail = true, boxes = true, compose = true, fit = true, arrowYields = true },
	rows = {
		{ type = "toggle", key = "compose", label = L["Trim the guide card"], help = L["Ends the guide card under its steps. Off ends it at RestedXP's own window foot."] },
		{ type = "toggle", key = "fit", label = L["Fit guide to its steps"], help = L["Lets the guide card shrink to its steps. Off keeps it at least as tall as the quest card."] },
		{
			type = "toggle", key = "rail", label = L["Guide card"],
			help = L["Puts the guide in its own card in the top left corner. Drag the guide away to keep your spot."],
		},
		{
			type = "toggle", key = "boxes", label = L["Dock RestedXP's boxes"],
			help = L["Docks RestedXP's target and item boxes under the guide's card. Drag one away to keep your spot."],
		},
		{
			type = "toggle", key = "arrowYields", label = L["Arrow text makes way for zone names"],
			help = L["Hides the guide arrow's step text while the game shows the name of the zone you enter."],
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
		if field == nil or field == "arrowYields" then
			RestedXP.Chrome.SwitchArrow()
		end
		if field == nil or field == "rail" then
			RestedXP.Rail.Switch(ns.Skins.Setting("restedXP", "rail") == true)
		elseif field == "compose" or field == "fit" then
			K.Combat.Queue(function()
				local rxp = RestedXP.Addon()
				if rxp then RestedXP.Chrome.Refit(rxp.RXPFrame) end
				if ns.Quests and ns.Quests.Replace then ns.Quests.Replace() end
				RestedXP.Rail.Schedule()
			end)
		elseif field == "boxes" then
			RestedXP.Rail.Schedule()
		end
	end,
})
