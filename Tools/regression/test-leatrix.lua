-- test-leatrix.lua: only active Leatrix Plus features switch their matching helper off once, and a player's override survives reloads.
local W = dofile("Tools/regression/widget_env.lua")
local Core = W.CoreEnv
local features = {
	{ "RestoreChatMessages", "Chat", "history" },
	{ "CombineAddonButtons", "Minimap", "column.drawer" },
	{ "FasterLooting", "QoL", "fastLoot" },
	{ "AutoRepairGear", "QoL", "autoRepair" },
	{ "AutoSellJunk", "Bags", "autoSellJunk" },
	{ "AutomateQuests", "QoL", "autoQuests" },
	{ "MaxCameraZoom", "QoL", "maxCamera" },
}
local defaults = {
	Chat = { history = true }, Minimap = { column = { drawer = true } },
	QoL = { fastLoot = true, autoRepair = true, autoQuests = true, maxCamera = true, lootFeed = true },
	Bags = { autoSellJunk = true },
}
local function Boot(toggles, loaded, saved)
	local env, K = W.New({ boot = false, saved = saved, setup = function(env)
		env.LeaPlusDB = toggles
		env.C_AddOns = { IsAddOnLoaded = function(name) return name == "Leatrix_Plus" and loaded == true end }
	end })
	for module, values in pairs(defaults) do K.Modules.Register(Core.Module(module, { defaults = values })) end
	Core.Boot(env)
	return env, K
end
local function Get(K, module, key)
	local node = K.Store.Module(module)
	for part in key:gmatch("[^.]+") do node = node[part] end
	return node
end
for _, feature in ipairs(features) do
	local toggle, module, key = unpack(feature)
	local env, K = Boot({ [toggle] = "On", MinimapModder = "On" }, true)
	assert(Get(K, module, key) == false, "Leatrix Plus " .. toggle .. " is on: switch off only " .. module .. "." .. key .. " before its helper starts")
	for _, other in ipairs(features) do
		if other ~= feature then assert(Get(K, other[2], other[3]) == true, "Leatrix Plus must leave unrelated helper " .. other[3] .. " on") end
	end
	assert(K.Store.Module("QoL").lootFeed, "the loot feed stays on beside faster looting")
	local count = #env._printed
	assert(Core.Printed(env, "Leatrix Plus"), "explain the yielded helper in one notice using the notices toggle")
	K.Options.Write(module, key, true)
	env.FireEvent("ADDON_LOADED", "Unrelated")
	assert(Get(K, module, key) and #env._printed == count, "the player can turn " .. key .. " back on without repeated notices")
	Core.Logout(env)
	local reloaded, nextK = Boot(env.LeaPlusDB, true, env.KstyleUIDB)
	assert(Get(nextK, module, key), "remember the player's " .. key .. " override across reloads")
	assert(not Core.Printed(reloaded, "Leatrix Plus"), "an override reload does not repeat the notice")
	assert(#env._errors == 0 and #reloaded._errors == 0, "Leatrix compatibility must run without errors")
end
for _, case in ipairs({ { nil, true }, { { FasterLooting = "Off" }, true }, { { FasterLooting = true }, true }, { { FasterLooting = "On" }, false }, { { CombineAddonButtons = "On", MinimapModder = "Off" }, true } }) do
	local env, K = Boot(case[1], case[2])
	for _, feature in ipairs(features) do assert(Get(K, feature[2], feature[3]), "an absent, disabled or inactive Leatrix option must leave KstyleUI on") end
	assert(not Core.Printed(env, "Leatrix Plus"), "no overlap means no notice")
end
do
	local saved = { version = 2, profiles = { Default = { Integrations = { notices = false } } } }
	local env, K = Boot({ FasterLooting = "On" }, true, saved)
	assert(not Get(K, "QoL", "fastLoot") and not Core.Printed(env, "Leatrix Plus"), "Other-addon notices off hides the notice, not the feature yield")
end
do
	local env, K = Boot(nil, false)
	env.LeaPlusDB = { FasterLooting = "On" }
	env.C_AddOns.IsAddOnLoaded = function(name) return name == "Leatrix_Plus" end
	env.FireEvent("ADDON_LOADED", "Leatrix_Plus")
	assert(not Get(K, "QoL", "fastLoot"), "a later Leatrix load must yield the matching helper")
	K.Options.Write("QoL", "fastLoot", true)
	assert(K.Store.CreateProfile("Other") and K.Store.SetProfile("Other"))
	assert(not Get(K, "QoL", "fastLoot"), "each profile gets its own first Leatrix choice")
	assert(K.Store.SetProfile("Default") and Get(K, "QoL", "fastLoot"), "profile changes must preserve the player's override")
	env.LeaPlusDB.AutoRepairGear = env.Secret("On")
	env.FireEvent("ADDON_LOADED", "Unrelated")
	assert(Get(K, "QoL", "autoRepair"), "never compare a secret Leatrix toggle")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("Leatrix feature yields ok")
