-- Settings.lua: KstyleUI_QoL's defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K, L = ns.K, ns.L

ns.PAUSE_KEYS = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

ns.defaults = {
	enabled = false,
	fastLoot = true,
	lootFeed = true,
	autoRepair = true,
	guildRepair = false,
	autoQuests = false,
	questModifier = "SHIFT",
	maxCamera = true,
	quietErrors = false,
}

function ns.Get(key)
	local default = ns.defaults[key]
	local value = K.Store.Module(ns.MODULE)[key]
	if type(value) ~= type(default) then
		return default
	end
	if key == "questModifier" and not ns.PAUSE_KEYS[value] then
		return default
	end
	return value
end

local function isOff(settings)
	return not settings.enabled
end

local function repairOff(settings)
	return not (settings.enabled and settings.autoRepair)
end

local function questsOff(settings)
	return not (settings.enabled and settings.autoQuests)
end

local PAUSE_OPTIONS = {
	{ value = "SHIFT", label = L["Shift"] },
	{ value = "CTRL", label = L["Ctrl"] },
	{ value = "ALT", label = L["Alt"] },
}

ns.schema = {
	{ type = "header", label = L["Quality of Life"] },
	{ type = "toggle", key = "enabled", label = L["KstyleUI quality of life"], help = L["Small helpers for looting, merchants, quests, the camera and error text."] },
	{ type = "header", label = L["Loot"] },
	{ type = "toggle", key = "fastLoot", label = L["Faster auto loot"], help = L["When the game auto loots, take every item the moment the window opens."], disableWhen = isOff },
	{ type = "toggle", key = "lootFeed", label = L["Loot feed"], help = L["Short lines above the chat for what you loot, with icons, quality colours and coin colours."], disableWhen = isOff },
	{ type = "header", label = L["Merchants"] },
	{ type = "toggle", key = "autoRepair", label = L["Repair by itself"], help = L["Repair your gear at merchants and print the cost."], disableWhen = isOff },
	{ type = "toggle", key = "guildRepair", label = L["Guild funds first"], help = L["Pay from the guild bank when your rank allows it."], disableWhen = repairOff },
	{ type = "note", label = L["Junk selling lives on the Bags page, as Sell junk by itself."] },
	{ type = "header", label = L["Quests"] },
	{ type = "toggle", key = "autoQuests", label = L["Accept and turn in quests"], help = L["Accept quests and hand in finished ones. A choice of rewards stays yours."], disableWhen = isOff },
	{
		type = "dropdown", key = "questModifier", label = L["Pause key"], help = L["Hold this key as you talk to a quest giver to do it yourself."],
		options = PAUSE_OPTIONS, disableWhen = questsOff,
	},
	{ type = "header", label = L["Camera"] },
	{ type = "toggle", key = "maxCamera", label = L["Max camera distance"], help = L["Let the camera zoom out as far as the game allows."], disableWhen = isOff },
	{ type = "header", label = L["Alerts"] },
	{ type = "toggle", key = "quietErrors", label = L["Quiet error text"], help = L["Hide the red cooldown, range and resource errors that flood the screen in combat."], disableWhen = isOff },
}
