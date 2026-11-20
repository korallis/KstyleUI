-- test-leatrix-helpers.lua: real helper startup yields before restoring chat, collecting buttons or automating loot, repair, quests and camera at every supported screen size.
local Q = dofile("Tools/regression/qol_env.lua")
local C = dofile("Tools/regression/chat_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")
local function Leatrix(env)
	env.LeaPlusDB = { RestoreChatMessages = "On", MinimapModder = "On", CombineAddonButtons = "On", FasterLooting = "On", AutoRepairGear = "On", AutomateQuests = "On", MaxCameraZoom = "On" }
	env.C_AddOns = { IsAddOnLoaded = function(name) return name == "Leatrix_Plus" end }
end
for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local width, height = unpack(screen)
	local env, K = Q.New({ width = width, height = height, saved = { version = 2, profiles = { Default = { QoL = { enabled = true, autoQuests = true } } } }, setup = Leatrix })
	env._loot = { {}, {} }
	env._repair.cost, env._repair.money = 1234, 5000
	env.FireEvent("LOOT_READY", true)
	env.FireEvent("MERCHANT_SHOW")
	env.FireEvent("QUEST_DETAIL", 0)
	env.RunTimers()
	for _, call in ipairs({ "LootSlot", "RepairAllItems", "AcceptQuest", "SetCVar" }) do
		assert(#Q.Calls(env, call) == 0, "Leatrix Plus must switch off the matching QoL helper before startup or events call " .. call)
	end
	C.W.CoreEnv.Logout(env)
	local resumed, resumedK = Q.New({ width = width, height = height, saved = env.KstyleUIDB })
	resumed._loot = { {}, {} }
	resumed.FireEvent("LOOT_READY", true)
	assert(resumedK.Store.Module("QoL").fastLoot and #Q.Calls(resumed, "LootSlot") == 2,
		"after Leatrix is removed, fast loot must resume at login before the first loot event")
	assert(#resumed._errors == 0, tostring(resumed._errors[1]))
	K.Options.Write("QoL", "fastLoot", true)
	env.SetTime(env.GetTime() + 1)
	env.FireEvent("LOOT_READY", true)
	assert(#Q.Calls(env, "LootSlot") == 2, "the player's Faster auto loot switch must override the Leatrix yield")
	assert(#env._errors == 0, tostring(env._errors[1]))

	local lib
	local map, mapK, ns = M.New({ width = width, height = height, enabled = true, setup = function(e)
		Leatrix(e)
		lib = M.FakeLibDBIcon(e)
		lib:Add("LeatrixTest")
	end })
	assert(not ns.Map.drawer.active and lib.objects.LeatrixTest:GetParent() == map.Minimap,
		"Leatrix's minimap button bag is on: yield column.drawer before adopting any button")
	local holder = ns.Map.holder
	local point, relative, relativePoint, x, y = holder:GetPoint()
	mapK.Options.Write("Minimap", "column.drawer", true)
	assert(ns.Map.drawer.active and lib.objects.LeatrixTest:GetParent() ~= map.Minimap, "the player can turn KstyleUI's drawer back on")
	local a, b, c, d, e = holder:GetPoint()
	assert(point == a and relative == b and relativePoint == c and x == d and y == e, "yielding or overriding the drawer must never move the saved minimap position")
	assert(#map._errors == 0, tostring(map._errors[1]))

	local chat, chatK = C.New({ width = width, height = height, saved = { version = 2, profiles = { Default = { Chat = { enabled = true } } } } })
	chat.ChatFrame1:AddMessage("Leatrix overlap history marker")
	C.W.CoreEnv.Logout(chat)
	local restored, restoredK = C.New({ width = width, height = height, saved = chat.KstyleUIDB, setup = Leatrix })
	assert(restoredK.Store.Module("Chat").history == false, "yield Keep chat across sessions before History.Start")
	for _, line in ipairs(C.Lines(restored.ChatFrame1)) do
		assert(not line:find("Leatrix overlap history marker", 1, true), "Leatrix chat restore is on: do not replay KstyleUI history too")
	end
	assert(chatK.Store.Module("Chat").history and #restored._errors == 0, "only the session with Leatrix enabled yields chat history")
end
print("Leatrix real helpers ok at 1080p, 1440p, ultrawide and 4K")
