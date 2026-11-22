-- test-shell-parity-followup.lua: the next shell options apply, reverse and preserve v0.2.8-shaped profiles.
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
	env._position = { 0.4532, 0.6218 }
	env.FireEvent("ZONE_CHANGED")
	M.Settle(env)
	assert(ns.Map.face.coords:IsShown() and K.Store.Module("Minimap").zone.size == 17)
	write(env, K, "Minimap", "clock.shown", false)
	write(env, K, "Minimap", "coords.hover", true)
	assert(not ns.Map.face.coords:IsShown())
	assert(not ns.Map.face.plaques[2].chrome.fill[5]:IsShown(), "hide the empty lower plaque when hover coordinates and the clock are hidden")
	ns.Map.holder._mouseOver = true
	env.Minimap:GetScript("OnEnter")(env.Minimap)
	M.Settle(env)
	assert(ns.Map.face.coords:IsShown(), "entering the map reveals coordinates")
	assert(ns.Map.face.plaques[2].chrome.fill[5]:IsShown(), "entering the map reveals the coordinate plaque")
	ns.Map.holder._mouseOver = false
	env.Minimap:GetScript("OnLeave")(env.Minimap)
	M.Settle(env)
	assert(not ns.Map.face.coords:IsShown(), "leaving the map hides coordinates")
	assert(not ns.Map.face.plaques[2].chrome.fill[5]:IsShown(), "leaving the map hides the empty coordinate plaque")
	write(env, K, "Minimap", "clock.shown", true)
	assert(ns.Map.face.plaques[2].chrome.fill[5]:IsShown(), "the visible clock keeps its plaque without coordinates")
	write(env, K, "Minimap", "coords.hover", false)
	assert(ns.Map.face.coords:IsShown())
	clean(env, K)
end

do
	local D = dofile("Tools/regression/databars_env.lua")
	local reads = 0
	local env, K, ns = D.New({ saved = saved("DataBars", { enabled = true, strip = { clock24 = false } }), setup = function(e)
		e.GetAverageItemLevel = function() reads = reads + 1; return 62.875, 58.375 end
	end })
	assert(reads == 0 and K.Store.Module("DataBars").strip.clock24 == false, "item level stays lazy and the old clock choice survives")
	for _, list in ipairs({ "dockModules", "railModules" }) do
		local entries = K.Store.Module("DataBars").strip[list]
		for _, entry in ipairs(entries) do if entry.id == "itemLevel" then assert(not entry.shown); entry.shown = true end end
		write(env, K, "DataBars", "strip." .. list, entries)
	end
	local function value() return ns.Strip.view.items.itemLevel.value:GetText() end
	assert(value() == "58")
	write(env, K, "DataBars", "strip.itemLevelDecimals", 2)
	assert(value() == "58.38")
	write(env, K, "DataBars", "strip.itemLevelSource", "overall")
	assert(value() == "62.88")
	write(env, K, "DataBars", "strip.itemLevelDecimals", 1)
	assert(value() == "62.9")
	env.GetAverageItemLevel = function() return env.Secret(63), 58 end
	env.FireEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
	assert(value() == "--", "secret overall level stays unread")
	write(env, K, "DataBars", "strip.itemLevelSource", "equipped")
	write(env, K, "DataBars", "strip.itemLevelDecimals", 0)
	assert(value() == "58")
	env.GetAverageItemLevel = nil
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED")
	assert(value() == "--")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 500)
	local preview = K.Options.Preview("DataBars")(parent)
	assert(preview.strip.items.itemLevel.value:GetText() == "58", "the preview keeps a fixed sample without the live API")
	write(env, K, "DataBars", "strip.itemLevelDecimals", 2)
	preview:Refresh()
	assert(preview.strip.items.itemLevel.value:GetText() == "58.30", "preview decimals format the fixed sample")
	clean(env, K)
end

do
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K, ns = C.New({ saved = saved("Chat", { enabled = true, fontSize = 16 }) })
	env.RunTimers()
	local chat, box = env.ChatFrame1, env.ChatFrame1.editBox
	local oldTop = ns.Panel.Geometry(chat).top
	assert(K.Store.Module("Chat").fontSize == 16 and not K.Store.Module("Chat").inputOnTop)
	assert(select(3, box:GetPoint(1)) == "BOTTOMLEFT")
	write(env, K, "Chat", "inputOnTop", true)
	assert(select(1, box:GetPoint(1)) == "BOTTOMLEFT" and select(3, box:GetPoint(1)) == "TOPLEFT")
	assert(ns.Panel.Geometry(chat).top > oldTop, "reserve space below the tabs for the input")
	write(env, K, "Chat", "editBox", "always")
	assert(select(3, box:GetPoint(1)) == "TOPLEFT")
	chat.IsProtected = function() return true end
	env.SetCombat(true)
	write(env, K, "Chat", "inputOnTop", false)
	assert(select(3, box:GetPoint(1)) == "TOPLEFT", "protected chat waits in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(select(3, box:GetPoint(1)) == "BOTTOMLEFT")
	assert(ns.Panel.Geometry(chat).top == oldTop)
	clean(env, K)
end

do
	local B = dofile("Tools/regression/bags_env.lua")
	local env, K, ns = B.New({ saved = saved("Bags", { enabled = true, columns = 7 }), bags = { [0] = { size = 4, items = { B.Item("potion") } } } })
	env.ToggleAllBags()
	env.RunTimers()
	local win, slot = ns.Inventory.window, ns.Inventory.Slot(0, 1)
	assert(K.Store.Module("Bags").columns == 7 and win.panel:GetFrameStrata() == "MEDIUM")
	assert(win.free:GetText():lower() == "3/4 free", tostring(win.free:GetText()))
	local crop = B.W.LastCall(slot.icon, "SetTexCoord")
	assert(crop[1] == 0.07 and math.abs(crop[2] - 0.93) < 1e-8, tostring(crop[1]) .. "," .. tostring(crop[2]))
	assert(K.Layout.Set(win.spec.key, "strata", "LOW"))
	win:Layout(true)
	assert(win.panel:GetFrameStrata() == "LOW", "Layout Strata survives bag refreshes")
	write(env, K, "Bags", "slotCount", "usedTotal")
	assert(win.free:GetText():lower() == "1/4 used")
	write(env, K, "Bags", "slotCount", "free")
	assert(win.free:GetText():lower() == "3 free")
	write(env, K, "Bags", "iconZoom", 12)
	assert(B.W.LastCall(slot.icon, "SetTexCoord")[1] == 0.12)
	assert(K.Layout.Set(win.spec.key, "strata", "MEDIUM"))
	write(env, K, "Bags", "slotCount", "freeTotal")
	write(env, K, "Bags", "iconZoom", 7)
	assert(win.free:GetText():lower() == "3/4 free" and win.panel:GetFrameStrata() == "MEDIUM")
	assert(B.W.LastCall(slot.icon, "SetTexCoord")[1] == 0.07)
	clean(env, K)
end

do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K = T.New({ saved = saved("Tooltips", { enabled = true, iconSize = 28 }), setup = function(e)
		e.UnitTokenFromGUID = function() return "mouseover" end
		e.UnitIsPlayer = function() return true end
		e.UnitName = function() return "Valerin" end
	end })
	K.Modules.Enable("Tooltips")
	local function title()
		local tip = env.GameTooltip
		tip:ClearLines()
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		tip:AddLine("Valerin the Explorer")
		T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Unit, guid = "Player-1-1" })
		return T.Lines(tip)[1][1]
	end
	assert(K.Store.Module("Tooltips").iconSize == 28 and title() == "Valerin the Explorer")
	write(env, K, "Tooltips", "playerTitles", false)
	assert(title() == "Valerin")
	env.UnitName = function() return env.Secret("hidden") end
	assert(title() == "Valerin the Explorer")
	env.UnitName = nil
	assert(title() == "Valerin the Explorer")
	write(env, K, "Tooltips", "playerTitles", true)
	assert(title() == "Valerin the Explorer")
	clean(env, K)
end

do
	local Q = dofile("Tools/regression/qol_env.lua")
	local stops, playing, reads = 0, true, 0
	local env, K, ns = Q.New({ saved = saved("QoL", { enabled = true, questModifier = "CTRL" }), setup = function(e)
		e.C_CurrencyInfo = e.C_CurrencyInfo or {}
		e.C_CurrencyInfo.GetCoinTextureString = function(copper) reads = reads + 1; return "coin:" .. copper end
		e.StopCinematic = function() stops = stops + 1 end
		e.InCinematic = function() return playing end
	end })
	Q.Enable(env, K)
	assert(K.Store.Module("QoL").questModifier == "CTRL" and not ns.Get("coinIcons") and ns.Get("skipDelay") == 0)
	env.FireEvent("CHAT_MSG_MONEY", "You loot 14 Copper")
	Q.W.Settle(env)
	local line = ns.Feed.lines[1]
	local plain = line.name:GetText()
	assert(plain:find("14c", 1, true) and reads == 0)
	write(env, K, "QoL", "coinIcons", true)
	assert(line.name:GetText() == "coin:14")
	env.C_CurrencyInfo.GetCoinTextureString = function() return env.Secret("hidden") end
	write(env, K, "QoL", "coinIcons", false)
	write(env, K, "QoL", "coinIcons", true)
	assert(line.name:GetText() == plain, "a secret coin string falls back to letters")
	env.C_CurrencyInfo.GetCoinTextureString = nil
	write(env, K, "QoL", "coinIcons", false)
	assert(line.name:GetText() == plain)
	write(env, K, "QoL", "skipCinematics", true)
	write(env, K, "QoL", "skipDelay", 5)
	env.FireEvent("CINEMATIC_START", true)
	assert(stops == 0)
	env.Release()
	assert(stops == 1)
	env.FireEvent("CINEMATIC_START", true)
	playing = false
	env.Release()
	assert(stops == 1, "finished cinematics invalidate their delayed skip")
	playing = true
	env.FireEvent("CINEMATIC_START", true)
	write(env, K, "QoL", "skipCinematics", false)
	env.Release()
	assert(stops == 1, "turning off cancels pending skips")
	write(env, K, "QoL", "skipCinematics", true)
	env.FireEvent("CINEMATIC_START", true)
	env._modifiers.shift = true
	env.Release()
	assert(stops == 1, "Shift also cancels a delayed skip")
	env._modifiers.shift = false
	write(env, K, "QoL", "skipDelay", 0)
	env.FireEvent("CINEMATIC_START", true)
	assert(stops == 2, "zero retains immediate skipping")
	clean(env, K)
end

print("shell parity follow-up ok: nine controls apply, reverse and preserve v0.2.8 settings")
