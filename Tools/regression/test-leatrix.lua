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
local function Boot(toggles, loaded, saved, beforeLogin)
	local env, K = W.New({ boot = false, saved = saved, setup = function(env)
		env.LeaPlusDB = toggles
		env.C_AddOns = { IsAddOnLoaded = function(name) return name == "Leatrix_Plus" and loaded == true end }
	end })
	for module, values in pairs(defaults) do K.Modules.Register(Core.Module(module, { defaults = values })) end
	Core.LoadSaved(env)
	if beforeLogin then beforeLogin(env, K) end
	Core.Login(env)
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
for _, feature in ipairs(features) do
	local toggle, module, key = unpack(feature)
	for _, absent in ipairs({ false, true }) do
		local env = Boot({ [toggle] = "On", MinimapModder = "On" }, true)
		Core.Logout(env)
		local restored, K = Boot(absent and nil or { [toggle] = "Off", MinimapModder = "On" }, not absent, env.KstyleUIDB, function(e, core)
			for _, addon in ipairs({ "KstyleUI_QoL", "Unrelated", "Leatrix_Plus" }) do e.FireEvent("ADDON_LOADED", addon) end
			assert(not Get(core, module, key) and core.Store.Module("Integrations").leatrix[toggle], "restore " .. key .. " only at PLAYER_LOGIN, after all addons load")
		end)
		assert(Get(K, module, key), "Leatrix no longer handles " .. key .. ": restore it at the next login")
		assert(not K.Store.Module("Integrations").leatrix[toggle], "clear the restored helper's Leatrix latch")
		assert(Core.Printed(restored, "is back on now that Leatrix Plus no longer handles it."), "explain the restored helper once")
		local count = #restored._printed
		restored.FireEvent("ADDON_LOADED", "Unrelated")
		restored.FireEvent("PLAYER_LOGIN")
		assert(#restored._printed == count and Get(K, module, key), "restoring " .. key .. " must not repeat notices or flip across addon events")
		assert(#restored._errors == 0, tostring(restored._errors[1]))
	end
	local env, K = Boot({ [toggle] = "On", MinimapModder = "On" }, true)
	K.Options.Write(module, key, true)
	Core.Logout(env)
	local restored, nextK = Boot({ [toggle] = "Off" }, true, env.KstyleUIDB)
	assert(Get(nextK, module, key) and not nextK.Store.Module("Integrations").leatrix[toggle], "clear the latch without changing a manual override")
	assert(not Core.Printed(restored, "Leatrix Plus"), "a helper already turned on manually needs no restoration notice")
end
do
	local env = Boot({ CombineAddonButtons = "On", MinimapModder = "On" }, true)
	Core.Logout(env)
	local _, K = Boot({ CombineAddonButtons = "On", MinimapModder = "Off" }, true, env.KstyleUIDB)
	assert(Get(K, "Minimap", "column.drawer"), "turning Leatrix's minimap modder off restores the drawer")
end
do
	local env, K = Boot({ FasterLooting = "On" }, true)
	K.Options.Write("Integrations", "notices", false)
	Core.Logout(env)
	local restored, nextK = Boot(nil, false, env.KstyleUIDB)
	assert(Get(nextK, "QoL", "fastLoot") and not Core.Printed(restored, "Leatrix Plus"), "notices off hides the restoration notice, not the restoration")
end
print("Leatrix feature yields and login restoration ok")
