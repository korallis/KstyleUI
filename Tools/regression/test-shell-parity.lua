-- test-shell-parity.lua: shell options preserve a v0.2.8 profile and apply through Options, with guarded game data and reversible switches.
local function saved(module, settings)
	return { version = 42, profiles = { Default = { [module] = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function write(env, K, module, key, value)
	assert(K.Options.Write(module, key, value) ~= false, module .. "." .. key .. " must write")
	env.RunTimers()
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local M = dofile("Tools/regression/minimap_env.lua")
	local env, K, ns = M.New({ saved = saved("Minimap", { enabled = true, zone = { size = 17 } }) })
	M.Settle(env)
	assert(K.Store.Module("Minimap").zone.size == 17 and ns.Settings.Get("zone.subzone") == true)
	assert(ns.Data.Zone() == env._zone.text, "default keeps the minimap's area name")
	env.GetZoneText = function() return "Elwynn Forest" end
	write(env, K, "Minimap", "zone.subzone", false)
	assert(ns.Map.face.zoneText == "Elwynn Forest", "zone choice applies to the live caption")
	env.GetZoneText = nil
	env.FireEvent("ZONE_CHANGED")
	assert(ns.Map.face.zone:GetText() == "", "missing zone API clears the caption")
	env.GetZoneText = function() return env.Secret("hidden") end
	env.FireEvent("ZONE_CHANGED")
	write(env, K, "Minimap", "zone.subzone", true)
	assert(ns.Map.face.zoneText == env._zone.text)
	clean(env, K)
end

do
	local D = dofile("Tools/regression/databars_env.lua")
	local calls = 0
	local env, K, ns = D.New({ saved = saved("DataBars", { enabled = true, strip = { clock24 = false } }), setup = function(e)
		e.GetZoneText = function() calls = calls + 1; return "Elwynn Forest" end
		e.GetAverageItemLevel = function() calls = calls + 1; return 62.8, 58.3 end
	end })
	assert(K.Store.Module("DataBars").strip.clock24 == false and calls == 0, "upgrade keeps the clock and defers off readouts")
	for _, list in ipairs({ "modules", "dockModules", "railModules" }) do
		local s = K.Store.Module("DataBars").strip
		local found = 0
		for _, entry in ipairs(s[list]) do
			if entry.id == "location" or entry.id == "itemLevel" then
				assert(entry.shown == false, "new readouts default off in every placement")
				found = found + 1
				entry.shown = true
			end
		end
		assert(found == 2)
		write(env, K, "DataBars", "strip." .. list, s[list])
	end
	assert(ns.Strip.view.items.location.value:GetText() == "Elwynn Forest")
	assert(ns.Strip.view.items.itemLevel.value:GetText() == "58", "equipped item level is rounded down")
	env.GetZoneText = function() return "Stormwind" end
	env.GetAverageItemLevel = function() return 66, 63 end
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	env.FireEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
	assert(ns.Strip.view.items.location.value:GetText() == "Stormwind" and ns.Strip.view.items.itemLevel.value:GetText() == "63")
	env.GetZoneText = function() return env.Secret("hidden") end
	env.GetAverageItemLevel = function() return 66, env.Secret(63) end
	env.FireEvent("ZONE_CHANGED")
	assert(ns.Strip.view.items.location.value:GetText() == "--" and ns.Strip.view.items.itemLevel.value:GetText() == "--")
	env.GetZoneText, env.GetAverageItemLevel = nil, nil
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED")
	local s = K.Store.Module("DataBars").strip
	for _, list in ipairs({ "modules", "dockModules", "railModules" }) do
		for _, entry in ipairs(s[list]) do if entry.id == "location" or entry.id == "itemLevel" then entry.shown = false end end
		write(env, K, "DataBars", "strip." .. list, s[list])
	end
	assert(not ns.Strip.view.items.location.button:IsShown() and not ns.Strip.view.items.itemLevel.button:IsShown())
	clean(env, K)
end

do
	local C = dofile("Tools/regression/chat_env.lua")
	local sounds = 0
	local env, K = C.New({ saved = saved("Chat", { enabled = true, timestamp = "%H:%M" }), setup = function(e)
		e.SOUNDKIT = { TELL_MESSAGE = 3081 }
		e.PlaySound = function() sounds = sounds + 1 end
	end })
	C.Enable(env, K)
	assert(K.Store.Module("Chat").timestamp == "%H:%M" and K.Store.Module("Chat").whisperSound == false)
	env.FireEvent("CHAT_MSG_WHISPER", "hello")
	assert(sounds == 0)
	write(env, K, "Chat", "whisperSound", true)
	env.FireEvent("CHAT_MSG_WHISPER", "hello")
	env.FireEvent("CHAT_MSG_BN_WHISPER", "hello")
	assert(sounds == 2, "both whisper kinds play once")
	env.SOUNDKIT.TELL_MESSAGE = env.Secret(3081)
	env.FireEvent("CHAT_MSG_WHISPER", "hello")
	assert(sounds == 2, "secret sound IDs are refused")
	env.SOUNDKIT.TELL_MESSAGE, env.PlaySound = 3081, nil
	env.FireEvent("CHAT_MSG_WHISPER", "hello")
	write(env, K, "Chat", "whisperSound", false)
	env.PlaySound = function() sounds = sounds + 1 end
	env.FireEvent("CHAT_MSG_WHISPER", "hello")
	assert(sounds == 2)
	clean(env, K)
end

do
	local B = dofile("Tools/regression/bags_env.lua")
	local env, K, ns = B.New({ saved = saved("Bags", { enabled = true, columns = 7 }), bags = { [0] = { size = 4, items = { B.Item("junk"), B.Item("potion") } } } })
	env.ToggleAllBags()
	env.RunTimers()
	assert(K.Store.Module("Bags").columns == 7 and ns.Settings.Get("desaturateJunk") == false)
	local junk, potion = ns.Inventory.Slot(0, 1), ns.Inventory.Slot(0, 2)
	local function grey(slot) return B.W.LastCall(slot.icon, "SetDesaturated")[1] end
	assert(not grey(junk))
	write(env, K, "Bags", "desaturateJunk", true)
	assert(grey(junk) and not grey(potion), "only sellable junk is desaturated")
	write(env, K, "Bags", "desaturateJunk", false)
	assert(not grey(junk), "turning off restores colour")
	ns.Slot.SetLocked(junk, true)
	assert(grey(junk), "locked items keep their independent state")
	clean(env, K)
end

do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local calls, stack = 0, 20
	local env, K = T.New({ saved = saved("Tooltips", { enabled = true, iconSize = 28 }), setup = function(e)
		e.C_Item.GetItemMaxStackSizeByID = function() calls = calls + 1; return stack end
	end })
	K.Modules.Enable("Tooltips")
	env.RunTimers()
	local tip = env.GameTooltip
	local function lines()
		tip:ClearLines()
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		tip:AddLine("Test item")
		T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 123 })
		for _, row in ipairs(T.Lines(tip)) do if row[1] == "Maximum stack" then return row[2] end end
	end
	assert(K.Store.Module("Tooltips").iconSize == 28 and not K.Store.Module("Tooltips").maxStack)
	assert(lines() == nil and calls == 0)
	write(env, K, "Tooltips", "maxStack", true)
	assert(lines() == "20")
	stack = env.Secret(20)
	assert(lines() == nil)
	stack = 1
	assert(lines() == nil, "unstackable items add no line")
	env.C_Item.GetItemMaxStackSizeByID = nil
	assert(lines() == nil)
	write(env, K, "Tooltips", "maxStack", false)
	assert(lines() == nil)
	clean(env, K)
end

do
	local Q = dofile("Tools/regression/qol_env.lua")
	local selected, stopped, inside = 0, 0, false
	local options = { { gossipOptionID = 7 } }
	local env, K = Q.New({ saved = saved("QoL", { enabled = true, questModifier = "CTRL" }), setup = function(e)
		e.IsInInstance = function() return inside end
		e.StopCinematic = function() stopped = stopped + 1 end
		e.C_GossipInfo.GetOptions = function() return options end
		e.C_GossipInfo.SelectOption = function(id) assert(id == 7); selected = selected + 1 end
	end })
	Q.Enable(env, K)
	local s = K.Store.Module("QoL")
	assert(s.questModifier == "CTRL" and not s.autoGossip and not s.skipCinematics and s.ignoreTrivial and s.questInstances)
	env.FireEvent("GOSSIP_SHOW")
	env.FireEvent("CINEMATIC_START", true)
	assert(selected == 0 and stopped == 0)
	for _, row in ipairs(K.Options.Get("QoL")) do
		if row.key == "questInstances" or row.key == "questModifier" then assert(row.disableWhen(s), "quest helpers off must disable the instance and pause-key controls") end
	end
	write(env, K, "QoL", "autoGossip", true)
	for _, row in ipairs(K.Options.Get("QoL")) do
		if row.key == "questInstances" or row.key == "questModifier" then assert(not row.disableWhen(s), "gossip alone enables the shared instance and pause-key controls") end
	end
	env.FireEvent("GOSSIP_SHOW")
	assert(selected == 1)
	env._modifiers.ctrl = true
	env.FireEvent("GOSSIP_SHOW")
	assert(selected == 1, "single gossip respects the saved pause key")
	env._modifiers.ctrl = false
	write(env, K, "QoL", "questInstances", false)
	inside = true
	env.FireEvent("GOSSIP_SHOW")
	assert(selected == 1)
	write(env, K, "QoL", "questInstances", true)
	env.FireEvent("GOSSIP_SHOW")
	assert(selected == 2)
	options = { { gossipOptionID = env.Secret(7) } }
	env.FireEvent("GOSSIP_SHOW")
	options = { { gossipOptionID = 7 }, { gossipOptionID = 8 } }
	env.FireEvent("GOSSIP_SHOW")
	assert(selected == 2, "secrets and multiple choices stay manual")
	write(env, K, "QoL", "autoGossip", false)
	write(env, K, "QoL", "autoQuests", true)
	env._quest.available = { { trivial = true } }
	env.FireEvent("QUEST_GREETING")
	assert(#Q.Calls(env, "SelectAvailableQuest") == 0)
	write(env, K, "QoL", "ignoreTrivial", false)
	env.FireEvent("QUEST_GREETING")
	assert(#Q.Calls(env, "SelectAvailableQuest") == 1)
	write(env, K, "QoL", "skipCinematics", true)
	env.FireEvent("CINEMATIC_START", true)
	assert(stopped == 1)
	env.FireEvent("CINEMATIC_START", env.Secret(true))
	env.FireEvent("CINEMATIC_START", false)
	env._modifiers.shift = true
	env.FireEvent("CINEMATIC_START", true)
	assert(stopped == 1, "forced, secret and Shift-held cinematics stay visible")
	env._modifiers.shift = false
	write(env, K, "QoL", "skipCinematics", false)
	env.FireEvent("CINEMATIC_START", true)
	assert(stopped == 1)
	clean(env, K)
end
print("shell parity ok: ten options apply, reverse and preserve v0.2.8 settings")
