-- Settings.lua: KstyleUI_QoL's defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K, L = ns.K, ns.L

ns.PAUSE_KEYS = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

ns.defaults = {
	enabled = false,
	fastLoot = true,
	lootFeed = true,
	coinIcons = false,
	autoRepair = true,
	guildRepair = false,
	autoQuests = false,
	autoGossip = false,
	ignoreTrivial = true,
	questInstances = true,
	skipCinematics = false,
	skipDelay = 0,
	questModifier = "SHIFT",
	maxCamera = true,
	quietErrors = false,
	autoDelete = false,
	autoResurrect = false,
}

function ns.Get(key)
	local default = ns.defaults[key]
	local value = K.Store.Module(ns.MODULE)[key]
	if type(value) ~= type(default) then
		return default
	end
	if key == "skipDelay" and (ns.IsSecret(value) or value ~= value or value < 0 or value > 30) then return default end
	if key == "questModifier" and not ns.PAUSE_KEYS[value] then
		return default
	end
	return value
end

function ns.Schema()
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
		{ type = "toggle", key = "coinIcons", label = L["Coin icons"], help = L["Show coin icons instead of gold, silver and copper letters in the loot feed."], disableWhen = function(s) return not (s.enabled and s.lootFeed) end },
		{ type = "header", label = L["Merchants"] },
		{ type = "toggle", key = "autoRepair", label = L["Repair by itself"], help = L["Repair your gear at merchants and print the cost."], disableWhen = isOff },
		{ type = "toggle", key = "guildRepair", label = L["Guild funds first"], help = L["Pay from the guild bank when your rank allows it."], disableWhen = repairOff },
		{ type = "note", label = L["Junk selling lives on the Bags page, as Sell junk by itself."] },
		{ type = "header", label = L["Quests"] },
		{ type = "toggle", key = "autoQuests", label = L["Accept and turn in quests"], help = L["Accept quests and hand in finished ones. A choice of rewards stays yours."], disableWhen = isOff },
		{ type = "toggle", key = "autoGossip", label = L["Select single gossip"], help = L["Choose a lone gossip option when the NPC offers no quests. The pause key still works."], disableWhen = isOff },
		{ type = "toggle", key = "ignoreTrivial", label = L["Ignore low-level quests"], help = L["Leave low-level quest offers for you to choose."], disableWhen = questsOff },
		{ type = "toggle", key = "questInstances", label = L["Quest helpers in instances"], help = L["Allow automatic quests and single gossip inside instances."], disableWhen = function(settings) return not (settings.enabled and (settings.autoQuests or settings.autoGossip)) end },
		{
			type = "dropdown", key = "questModifier", label = L["Pause key"], help = L["Hold this key as you talk to a quest giver to do it yourself."],
			options = PAUSE_OPTIONS, disableWhen = function(settings) return not (settings.enabled and (settings.autoQuests or settings.autoGossip)) end,
		},
		{ type = "header", label = L["Camera"] },
		{ type = "toggle", key = "skipCinematics", label = L["Skip cinematics"], help = L["Skip cancellable cinematics. Hold Shift to watch them."], disableWhen = isOff },
		{ type = "slider", key = "skipDelay", label = L["Skip after"], help = L["Seconds before skipping a cancellable cinematic; zero skips now. Hold Shift to watch."], min = 0, max = 30, step = 1, disableWhen = function(s) return not (s.enabled and s.skipCinematics) end },
		{ type = "toggle", key = "maxCamera", label = L["Max camera distance"], help = L["Let the camera zoom out as far as the game allows."], disableWhen = isOff },
		{ type = "header", label = L["Alerts"] },
		{ type = "toggle", key = "quietErrors", label = L["Quiet error text"], help = L["Hide the red cooldown, range and resource errors that flood the screen in combat."], disableWhen = isOff },
		{ type = "toggle", key = "autoDelete", label = L["Fill in the delete word"], help = L["Type the confirmation word when you delete a good item. You still click Yes."], disableWhen = isOff },
		{ type = "header", label = L["Resurrection"] },
		{ type = "toggle", key = "autoResurrect", label = L["Accept resurrection"], help = L["Accept a resurrection out of combat the moment it is offered, unless the game makes you wait."], disableWhen = isOff },
	}
	return ns.schema
end
