-- test-qol-parity-r3b.lua: the EllesmereUI parity round 3b QoL options: a v0.2.8 profile keeps today's behaviour and claims no command, each option works switched on and follows the events that change it, nothing depends on a switch it does not name, turning an option off puts back exactly what it changed, and missing or secret game answers take the safe path.
local Q = dofile("Tools/regression/qol_env.lua")
local carried, locale -- Blizzard's saved auction filters and the client locale for the next boot

local function record(env, name, result)
	return function(...)
		env._calls[name] = env._calls[name] or {}
		table.insert(env._calls[name], { ... })
		if type(result) == "function" then return result(...) end
		return result
	end
end

local function stand(env)
	local frame = function(name, parent)
		local f = env.CreateFrame("Frame", name, parent or env.UIParent)
		f._blizzard = true
		if name then env[name] = f end
		return f
	end
	env._printed = {}
	env.print = function(text) env._printed[#env._printed + 1] = tostring(text) end
	env.GetFramerate = function() return env._fps or 59.6 end
	env.GetNetStats = function() return 1, 2, 42, 58 end
	env._map, env._pos = 1429, { x = 0.9, y = 0.9 }
	env._maps = { [1429] = { mapID = 1429, name = "Elwynn Forest", parentMapID = 13 }, [1430] = { mapID = 1430, name = "Westfall", parentMapID = 13 }, [13] = { mapID = 13, name = "Eastern Kingdoms", parentMapID = 0 } }
	env.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end }
	env.C_Map = {
		GetBestMapForUnit = function() return env._map end,
		GetMapInfo = function(id) return env._maps[id] end,
		GetMapChildrenInfo = function(id)
			local out = {}
			for _, info in pairs(env._maps) do if info.parentMapID == id then out[#out + 1] = info end end
			return out
		end,
		CanSetUserWaypointOnMap = function() return env._canPin ~= false end,
		SetUserWaypoint = record(env, "SetUserWaypoint", function(p) env._waypoint = p; env.FireEvent("USER_WAYPOINT_UPDATED"); return true end),
		GetUserWaypoint = function() return env._waypoint end,
		ClearUserWaypoint = record(env, "ClearUserWaypoint", function() env._waypoint = nil; env.FireEvent("USER_WAYPOINT_UPDATED") end),
		GetUserWaypointHyperlink = function() return "[Map Pin]" end,
		GetPlayerMapPosition = function() return env._pos end,
		GetMapWorldSize = function() return 1000, 1000 end,
	}
	env.C_SuperTrack = { SetSuperTrackedUserWaypoint = record(env, "SuperTrack") }
	env.Constants = env.Constants or {}
	env.Constants.MacroConsts = { MAX_ACCOUNT_MACROS = 3 }
	env._macros = {}
	env.GetMacroInfo = function(i) local m = env._macros[i]; if type(m) == "table" then return m[1], m[2], m[3] end return m end
	env.GetNumMacros = function() return #env._macros, 0 end
	env.CreateMacro = record(env, "CreateMacro", function(name, icon, body) env._macros[#env._macros + 1] = { name, icon, body }; return #env._macros end)
	env.PickupMacro = record(env, "PickupMacro")
	env.CooldownViewerSettings = { TogglePanel = record(env, "TogglePanel") }
	env.Enum = env.Enum or {}
	env.Enum.AuctionHouseFilter = { CurrentExpansionOnly = 3 }
	env.Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
	env._offered, env._filters = true, carried or { [3] = false }
	env.C_AuctionHouse = { GetFilterGroups = function() return { { category = 0, filters = env._offered and { 1, 3 } or { 1 } } } end }
	local filter = { GetFilters = function() return env._filters end, ToggleFilter = record(env, "ToggleFilter", function(_, id) env._filters[id] = not env._filters[id] end) }
	env.AuctionHouseFrame = frame("AuctionHouseFrame")
	env.AuctionHouseFrame.SearchBar = { FilterButton = filter }
	local map = frame("WorldMapFrame")
	map.BlackoutFrame = env.CreateFrame("Frame", nil, map)
	map.BlackoutFrame:EnableMouse(true)
	map.BlackoutFrame.Blackout = map.BlackoutFrame:CreateTexture()
	local comm = frame("CommunitiesFrame")
	comm.Chat = env.CreateFrame("Frame", nil, comm)
	comm.Chat.MessageFrame = env.CreateFrame("Frame", nil, comm.Chat)
	comm.Chat.MessageFrame:SetAlpha(0.9)
	comm.selected = 7
	comm.GetSelectedClubId = function(self) return self.selected end
	comm.OnClubSelected = function(self, id) self.selected = id end
	env.C_Club = { GetClubInfo = function(id) if env._clubSecret then return env.Secret({ clubType = 2 }) end return { clubType = id == 7 and 2 or 1 } end }
	env.C_PartyInfo = { DoReadyCheck = record(env, "DoReadyCheck"), DoCountdown = record(env, "DoCountdown") }
	env.InitiateRolePoll = record(env, "InitiateRolePoll")
	env.SetRaidTarget = record(env, "SetRaidTarget")
	env.GetRaidTargetIndex = function() return env._mark end
	env.UnitIsGroupLeader = function() return env._leader == true end
	env.UnitIsGroupAssistant = function() return false end
	env.HasLFGRestrictions = function() return env._lfg == true end
	env.UnitInBattleground = function() return nil end
	if locale then env.GetLocale = function() return locale end end
end

local function boot(settings, saved)
	saved = saved or { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = stand })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function said(env, text)
	for _, line in ipairs(env._printed) do
		if line:find(text, 1, true) then return true end
	end
end

local function shows(fs)
	for i = #fs._calls, 1, -1 do
		local call = fs._calls[i]
		if call.method == "SetText" then return call.args[1] end
		if call.method == "SetFormattedText" then return string.format(unpack(call.args, 1, call.args.n)) end
	end
end

local function click(button)
	button:GetScript("OnClick")(button, "LeftButton")
end

local function only(env, K, ids)
	local list = {}
	for _, entry in ipairs(K.Options.Read("QoL", "statsList")) do list[#list + 1] = { id = entry.id, shown = ids[entry.id] == true, zone = "left" } end
	Q.Write(env, K, "statsList", list)
end

-- Defaults: a v0.2.8 profile changes nothing, claims no command and builds no frame.
do
	local env, K, ns = boot({ enabled = true, fastLoot = true, stats = true })
	for key, value in pairs({ statsInterval = 1, statsNetLabels = true, wayCommand = false, wayPaste = false, wayArrival = true, wayManual = false, cdCommand = false, ahCurrent = false,
		mapSidebars = false, mapSidebarsOpacity = 0, mapClickThrough = true, guildCover = false, raidTools = "never", raidToolsCollapsed = false, raidToolsLayout = "row", raidToolsGrow = "downright", raidToolsReady = false }) do
		assert(ns.Get(key) == value, key .. " keeps today's behaviour by default")
	end
	assert(env.SLASH_KSTYLEQOLWAY1 == nil and env.SLASH_KSTYLEQOLPASTE1 == nil and env.SLASH_KSTYLEQOLCD1 == nil, "no command is claimed")
	assert(not ns.PasteWindow() and not env.KstyleUI_RaidTools, "no raid tools or paste window")
	local stats = ns.StatsFrame()
	for i = 1, stats.count do assert(not stats.lines[i].stat.fmt, "frame rate and latency are off by default") end
	env.FireEvent("AUCTION_HOUSE_SHOW")
	env.RunTimers()
	assert(#Q.Calls(env, "ToggleFilter") == 0 and env._filters[3] == false, "the auction filter is untouched")
	local blackout = env.WorldMapFrame.BlackoutFrame
	assert(blackout.Blackout:GetAlpha() == 1 and blackout:IsMouseEnabled(), "the map sidebars stay black and catch the mouse")
	assert(env.CommunitiesFrame.Chat.MessageFrame:GetAlpha() == 0.9 and select("#", env.CommunitiesFrame.Chat:GetChildren()) == 1, "guild chat is not covered")
	clean(env, K)
end

-- Frame rate and latency, on: lines with and without labels, a ticker at the chosen interval that refreshes them and stops with the stats.
do
	local env, K, ns = boot({ enabled = true, stats = true })
	only(env, K, { fps = true, home = true, world = true })
	local frame = ns.StatsFrame()
	assert(frame.count == 3, tostring(frame.count))
	assert(shows(frame.lines[1]):find("Frame rate", 1, true) and shows(frame.lines[1]):find("59", 1, true), shows(frame.lines[1]))
	assert(shows(frame.lines[2]):find("Home latency", 1, true) and shows(frame.lines[2]):find("42 ms", 1, true), shows(frame.lines[2]))
	assert(shows(frame.lines[3]):find("58 ms", 1, true), shows(frame.lines[3]))
	env._fps = 120
	env.RunTickers()
	assert(shows(frame.lines[1]):find("120", 1, true), "the ticker refreshes the frame rate")
	Q.Write(env, K, "statsNetLabels", false)
	assert(not shows(frame.lines[2]):find("Home", 1, true) and shows(frame.lines[2]):find("42 ms", 1, true) and shows(frame.lines[1]):find("Frame rate", 1, true), "only latency loses its label")
	Q.Write(env, K, "statsShort", true)
	assert(shows(frame.lines[1]):find("FPS", 1, true), "short labels")
	local made, new = {}, env.C_Timer.NewTicker
	env.C_Timer.NewTicker = function(interval, fn) made[#made + 1] = interval; return new(interval, fn) end
	Q.Write(env, K, "statsInterval", 4)
	assert(made[#made] == 4 and env.LiveTickers() == 1, "the interval follows the setting, with one ticker, never a pile")
	Q.Write(env, K, "stats", false)
	env._fps = 30
	env.RunTickers()
	assert(shows(frame.lines[1]):find("120", 1, true) and env.LiveTickers() == 0, "turning the stats off stops the ticker")
	only(env, K, { crit = true })
	Q.Write(env, K, "stats", true)
	env._fps = 15
	env.RunTickers()
	assert(not shows(frame.lines[1]):find("15", 1, true) and env.LiveTickers() == 0, "no frame rate line, no ticker")
	clean(env, K)
end

-- /way: claimed only while on and unowned, pins the player's map, a numbered map or a named zone, and says how to use it otherwise.
do
	local env, K = boot()
	Q.Write(env, K, "wayCommand", true)
	assert(env.SLASH_KSTYLEQOLWAY1 == "/way" and type(env.SlashCmdList.KSTYLEQOLWAY) == "function", "/way is claimed")
	env.SlashCmdList.KSTYLEQOLWAY("52.5, 40 The inn")
	local pin = env._waypoint
	assert(pin.uiMapID == 1429 and math.abs(pin.position.x - 0.525) < 1e-9 and pin.position.y == 0.4, "the player's map at 52.5, 40")
	assert(#Q.Calls(env, "SuperTrack") == 1 and said(env, "[Map Pin] The inn"), "tracked, and the link is printed")
	env.SlashCmdList.KSTYLEQOLWAY("#1430 10 20")
	assert(env._waypoint.uiMapID == 1430, "a numbered map")
	env.SlashCmdList.KSTYLEQOLWAY("westf 30 70")
	assert(env._waypoint.uiMapID == 1430 and env._waypoint.position.y == 0.7, "a zone by the start of its name")
	env.SlashCmdList.KSTYLEQOLWAY("Nowhere 30 70")
	assert(said(env, "No map for Nowhere."), "an unknown zone says so")
	env.SlashCmdList.KSTYLEQOLWAY("hello")
	assert(said(env, "/way x y"), "bad input shows the usage")
	env._canPin = false
	env.SlashCmdList.KSTYLEQOLWAY("10 10")
	assert(said(env, "cannot hold a pin") and env._waypoint.position.x == 0.3, "a map that refuses pins keeps the old pin")
	env._canPin = nil
	local hashed = env.SlashCmdList.KSTYLEQOLWAY
	Q.Write(env, K, "wayCommand", false)
	local before = #Q.Calls(env, "SetUserWaypoint")
	hashed("10 10")
	assert(#Q.Calls(env, "SetUserWaypoint") == before and said(env, "Turn /way on"), "off, the handler the chat code kept only says where to turn it on")
	clean(env, K)
	local env2, K2 = boot()
	env2.SLASH_TOMTOM_WAY1 = "/way"
	Q.Write(env2, K2, "wayCommand", true)
	assert(env2.SLASH_KSTYLEQOLWAY1 == nil and said(env2, "Another addon owns /way."), "another addon's /way is left alone")
	clean(env2, K2)
end

-- /kpaste and arrival: the list pins in order as you arrive, the last arrival clears the pin, and /kpaste macro reuses or creates one macro, out of combat.
do
	local env, K, ns = boot()
	Q.Write(env, K, "wayPaste", true)
	assert(env.SLASH_KSTYLEQOLPASTE1 == "/kpaste" and env.SLASH_KSTYLEQOLWAY1 == nil, "/kpaste does not need /way on")
	env.SlashCmdList.KSTYLEQOLPASTE("")
	local window = ns.PasteWindow()
	assert(window:IsShown(), "the paste window opens")
	window.area:SetText("/way 10 10 First\nsay hi\n/way #1430 20 20 Second\n")
	click(window.run)
	assert(not window:IsShown() and env._waypoint.position.x == 0.1 and said(env, "Pinned 2 waypoints"), "the first of two pins is set")
	env._pos = { x = 0.5, y = 0.5 }
	env.RunTickers()
	assert(env._waypoint.position.x == 0.1, "far away, nothing happens")
	env._pos = { x = 0.105, y = 0.1 }
	env.RunTickers()
	assert(said(env, "Arrived at First.") and env._waypoint.uiMapID == 1430, "arriving pins the next")
	env._pos = { x = 0.2, y = 0.2 }
	env.RunTickers()
	assert(said(env, "Arrived at Second.") and env._waypoint == nil and #Q.Calls(env, "ClearUserWaypoint") == 1, "the last arrival clears the pin")
	Q.Write(env, K, "wayArrival", false)
	ns.PasteWays("/way 30 30 Third\n/way 40 40 Fourth")
	env._pos = { x = 0.3, y = 0.3 }
	env.RunTickers()
	assert(not said(env, "Arrived at Third.") and env._waypoint.position.x == 0.4, "Arrival message off: no message, and the next pin still follows")
	Q.Write(env, K, "wayArrival", true)
	env._pos = { x = 0.4, y = 0.4 }
	env.C_Map.ClearUserWaypoint()
	assert(said(env, "Arrived at Fourth.") and env._waypoint == nil, "a pin the game clears beside you counts as arrival")
	env._pos = { x = 0.9, y = 0.9 }
	env.C_Map.ClearUserWaypoint()
	ns.PasteWays("/way 50 50 Fifth")
	env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1429, 0.6, 0.6))
	env._pos = { x = 0.5, y = 0.5 }
	env.RunTickers()
	assert(not said(env, "Arrived at Fifth."), "a pin the player replaced drops the list")
	env.SlashCmdList.KSTYLEQOLPASTE("macro")
	assert(#Q.Calls(env, "CreateMacro") == 1 and Q.Calls(env, "CreateMacro")[1][3] == "/kpaste" and Q.Calls(env, "PickupMacro")[1][1] == 1, "the macro is made and picked up")
	env.SlashCmdList.KSTYLEQOLPASTE(" Macro ")
	assert(#Q.Calls(env, "CreateMacro") == 1 and #Q.Calls(env, "PickupMacro") == 2, "the same macro is reused")
	env._macros = { "a", "b", "c" }
	env.SlashCmdList.KSTYLEQOLPASTE("macro")
	assert(said(env, "macros are full"), "a full list says so")
	env.SetCombat(true)
	env.SlashCmdList.KSTYLEQOLPASTE("macro")
	assert(#Q.Calls(env, "PickupMacro") == 2, "no macro in combat")
	env.SetCombat(false)
	Q.Write(env, K, "wayPaste", false)
	assert(not window:IsShown(), "turning it off closes the window")
	clean(env, K)
end

-- Arrival at your own pins: a pin you placed is announced once, and only while the switch is on.
do
	local env, K = boot()
	env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1429, 0.5, 0.5))
	env._pos = { x = 0.5, y = 0.5 }
	env.RunTickers()
	assert(not said(env, "Arrived"), "off by default")
	Q.Write(env, K, "wayManual", true)
	env.RunTickers()
	env.RunTickers()
	local function count()
		local n = 0
		for _, line in ipairs(env._printed) do if line:find("Arrived at your map pin.", 1, true) then n = n + 1 end end
		return n
	end
	assert(count() == 1, "announced once, not every second: " .. count())
	assert(env.LiveTickers() == 0, "nothing left to watch stops the ticker as the pin is announced")
	env._pos = nil
	env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1429, 0.7, 0.7))
	env.RunTickers()
	assert(count() == 1, "no position (an instance) announces nothing")
	clean(env, K)
end

-- /cd: toggles the cooldown manager settings out of combat only.
do
	local env, K = boot()
	Q.Write(env, K, "cdCommand", true)
	assert(env.SLASH_KSTYLEQOLCD1 == "/cd", "/cd is claimed")
	env.SlashCmdList.KSTYLEQOLCD("")
	assert(#Q.Calls(env, "TogglePanel") == 1, "the panel toggles")
	env.SetCombat(true)
	env.SlashCmdList.KSTYLEQOLCD("")
	assert(#Q.Calls(env, "TogglePanel") == 1 and said(env, "out of combat"), "refused in combat")
	env.SetCombat(false)
	env.CooldownViewerSettings = nil
	env.SlashCmdList.KSTYLEQOLCD("")
	clean(env, K)
end

-- Auction house: ticks the filter as it opens only when the game lists it, again after the player unticks it, and unticks only its own tick when turned off.
do
	local env, K = boot()
	Q.Write(env, K, "ahCurrent", true)
	assert(env._filters[3] == true and #Q.Calls(env, "ToggleFilter") == 1, "an open auction house is ticked at once")
	env._filters[3] = false
	env.FireEvent("AUCTION_HOUSE_SHOW")
	env.RunTimers()
	assert(env._filters[3] == true, "each opening ticks it again")
	Q.Write(env, K, "ahCurrent", false)
	assert(env._filters[3] == false, "off unticks its own tick")
	env._offered = false
	Q.Write(env, K, "ahCurrent", true)
	env.FireEvent("AUCTION_HOUSE_SHOW")
	env.RunTimers()
	assert(env._filters[3] == false, "a filter the game does not list is never ticked")
	Q.Write(env, K, "ahCurrent", false)
	assert(env._filters[3] == false, "and nothing is unticked")
	env._offered, env._filters[3] = true, true
	Q.Write(env, K, "ahCurrent", true)
	Q.Write(env, K, "ahCurrent", false)
	assert(env._filters[3] == true, "the player's own tick survives turning it off")
	clean(env, K)
end

-- World map sidebars: opacity and click-through on, and Blizzard's black, mouse-catching bars back when off.
do
	local env, K = boot()
	local blackout = env.WorldMapFrame.BlackoutFrame
	Q.Write(env, K, "mapSidebars", true)
	assert(blackout.Blackout:GetAlpha() == 0 and not blackout:IsMouseEnabled(), "clear and click-through")
	Q.Write(env, K, "mapSidebarsOpacity", 40)
	assert(math.abs(blackout.Blackout:GetAlpha() - 0.4) < 1e-9, "the opacity follows")
	Q.Write(env, K, "mapClickThrough", false)
	assert(blackout:IsMouseEnabled(), "click-through off catches the mouse")
	Q.Write(env, K, "mapClickThrough", true)
	Q.Write(env, K, "mapSidebars", false)
	assert(blackout.Blackout:GetAlpha() == 1 and blackout:IsMouseEnabled(), "off restores Blizzard's bars")
	Q.Write(env, K, "mapSidebarsOpacity", 70)
	assert(blackout.Blackout:GetAlpha() == 1, "the opacity alone does nothing while off")
	Q.Write(env, K, "mapSidebars", true)
	Q.Disable(env, K)
	assert(blackout.Blackout:GetAlpha() == 1 and blackout:IsMouseEnabled(), "the module off restores them too")
	clean(env, K)
end

-- Guild chat cover: covers guild chat only, a click lifts it until the window closes, a community stays visible, and off puts the messages' opacity back.
do
	local env, K = boot()
	local comm = env.CommunitiesFrame
	local messages = comm.Chat.MessageFrame
	Q.Write(env, K, "guildCover", true)
	local cover = select(2, comm.Chat:GetChildren())
	assert(cover:IsShown() and messages:GetAlpha() == 0, "guild chat is covered and faded")
	click(cover)
	assert(not cover:IsShown() and messages:GetAlpha() == 0.9, "a click shows it")
	comm:Hide()
	comm:GetScript("OnHide")(comm)
	comm:Show()
	assert(cover:IsShown() and messages:GetAlpha() == 0, "closing the window covers it again")
	comm:OnClubSelected(9)
	assert(not cover:IsShown() and messages:GetAlpha() == 0.9, "a community is not covered")
	env._clubSecret = true
	comm:OnClubSelected(9)
	assert(cover:IsShown(), "an unreadable club is covered, the private choice")
	env._clubSecret = nil
	comm:OnClubSelected(7)
	Q.Write(env, K, "guildCover", false)
	assert(not cover:IsShown() and messages:GetAlpha() == 0.9, "off restores the messages")
	clean(env, K)
end

-- Raid tools: the show rule and its events, collapsed start, layout, opening direction, ready check, the binding's button, combat refusal and the actions.
do
	local env, K = boot()
	Q.Write(env, K, "raidTools", "group")
	local holder = env.KstyleUI_RaidTools
	assert(holder and not holder:IsShown(), "built and named for the binding, hidden alone")
	env._group = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(holder:IsShown() and holder.panel:IsShown(), "shown open in a party")
	local width = holder.panel:GetWidth()
	Q.Write(env, K, "raidToolsLayout", "column")
	assert(holder.panel:GetWidth() < width and holder.panel:GetHeight() > holder.panel:GetWidth(), "a column")
	local point, anchor, relative = holder.panel:GetPoint(1)
	assert(point == "TOPLEFT" and anchor == holder and relative == "BOTTOMLEFT", "opens down and right")
	Q.Write(env, K, "raidToolsGrow", "upleft")
	point, anchor, relative = holder.panel:GetPoint(1)
	assert(point == "TOPLEFT" and anchor == holder and relative == "BOTTOMLEFT", "a column at the top left opens down and right where up and left would leave the screen")
	click(holder)
	assert(not holder.panel:IsShown(), "the button collapses it")
	env.FireEvent("READY_CHECK")
	assert(not holder.panel:IsShown(), "a ready check leaves it while Open on ready check is off")
	Q.Write(env, K, "raidToolsReady", true)
	env.FireEvent("READY_CHECK")
	assert(holder.panel:IsShown(), "a ready check opens it")
	click(holder.buttons[1])
	click(holder.buttons[2])
	click(holder.buttons[3])
	assert(#Q.Calls(env, "DoReadyCheck") == 1 and #Q.Calls(env, "InitiateRolePoll") == 1 and Q.Calls(env, "DoCountdown")[1][1] == 10, "ready check, role check, pull timer")
	click(holder.buttons[6])
	env._mark = 3
	click(holder.buttons[6])
	click(holder.buttons[12])
	local marks = Q.Calls(env, "SetRaidTarget")
	assert(marks[1][2] == 3 and marks[2][2] == 0 and marks[3][2] == 0, "a marker, the same marker clears, Clear clears")
	env.SetCombat(true)
	assert(not holder.buttons[4]:IsEnabled(), "dim in combat, even as combat starts")
	click(holder.buttons[1])
	assert(#Q.Calls(env, "DoReadyCheck") == 1, "refused in combat")
	click(holder)
	assert(not holder.panel:IsShown(), "it still opens and closes in combat")
	env.SetCombat(false)
	assert(holder.buttons[4]:IsEnabled(), "usable again after combat")
	env._group, env._raid = false, true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not holder:IsShown(), "in a raid, hidden from a plain member")
	env._leader = true
	env.FireEvent("PARTY_LEADER_CHANGED")
	assert(holder:IsShown(), "shown to the leader")
	Q.Write(env, K, "raidToolsCollapsed", true)
	env._raid = false
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env._raid = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(holder:IsShown() and not holder.panel:IsShown(), "Start collapsed shows only the button")
	Q.Write(env, K, "raidTools", "raid")
	env._raid, env._group, env._leader = false, true, false
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not holder:IsShown(), "In a raid hides it in a party")
	env._raid, env._leader = true, true
	Q.Write(env, K, "raidTools", "never")
	assert(not holder:IsShown(), "Never hides it")
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not holder:IsShown(), "and its events are gone")
	env._leader = nil
	env.UnitIsGroupLeader = function() return env.Secret(true) end
	Q.Write(env, K, "raidTools", "group")
	assert(not holder:IsShown(), "a secret leader answer hides it")
	clean(env, K)
end

-- The page: every new row writes and the live preview draws the frame rate and latency samples and the raid tools in their layout, dimmed while off.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(preview.raid:GetAlpha() < 1, "the raid tools sample is dimmed while off")
	for _, button in ipairs(preview.raid.buttons) do assert(not button:IsMouseEnabled(), "the sample's buttons do nothing") end
	local wide = preview.raid:GetWidth()
	for key, value in pairs({ statsInterval = 3, statsNetLabels = false, wayCommand = true, wayPaste = true, wayArrival = false, wayManual = true, cdCommand = true, ahCurrent = true,
		mapSidebars = true, mapSidebarsOpacity = 25, mapClickThrough = false, guildCover = true, raidTools = "group", raidToolsCollapsed = true, raidToolsLayout = "column", raidToolsGrow = "upright", raidToolsReady = true }) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
		Q.Write(env, K, key, value)
	end
	only(env, K, { fps = true, home = true })
	Q.Write(env, K, "stats", true)
	preview:Refresh()
	assert(preview.raid:GetAlpha() == 1 and preview.raid:GetWidth() < wide, "the preview follows the raid tools settings")
	assert(preview.raid.panel:GetAlpha() < 1 and preview.raid.star:GetPoint(1) == "BOTTOMLEFT" and preview.raid.panel:GetPoint(1) == "BOTTOMLEFT", "collapsed dims the panel, which opens up and right from its button")
	assert(preview.stats.count == 2 and shows(preview.stats.lines[1]):find("60", 1, true) and shows(preview.stats.lines[2]) == "|cff" .. shows(preview.stats.lines[2]):sub(5, 10) .. "42 ms|r", "samples, and latency without its label")
	clean(env, K)
end

-- Review of #638, raid tools on screen: from the default spot and from a spot dragged to the far corner, every layout and opening direction keeps the open panel inside the screen at every size, opening the other way only where the chosen way would leave it.
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = Q.New({ width = size[1], height = size[2], size = "auto", setup = stand })
	Q.Enable(env, K)
	env._group = true
	Q.Write(env, K, "raidTools", "group")
	local holder, root = env.KstyleUI_RaidTools, K.Scale.Root()
	local function inside(what)
		local p, k = holder.panel, holder.panel:GetEffectiveScale() / root:GetEffectiveScale()
		assert(p:GetLeft() * k >= root:GetLeft() - 0.5 and p:GetRight() * k <= root:GetRight() + 0.5 and p:GetBottom() * k >= root:GetBottom() - 0.5 and p:GetTop() * k <= root:GetTop() + 0.5,
			string.format("%dx%d %s: the open panel spans %.0f..%.0f x %.0f..%.0f", size[1], size[2], what, p:GetLeft() * k, p:GetRight() * k, p:GetBottom() * k, p:GetTop() * k))
	end
	for _, spot in ipairs({ {}, { anchor = "BOTTOMRIGHT", x = -16, y = 16 } }) do
		if spot.anchor then
			for field, value in pairs(spot) do assert(K.Layout.Set("qol.raidtools", field, value)) end
			env.RunTimers()
		end
		for _, layout in ipairs({ "row", "column" }) do
			for _, grow in ipairs({ "downright", "downleft", "upright", "upleft" }) do
				Q.Write(env, K, "raidToolsLayout", layout)
				Q.Write(env, K, "raidToolsGrow", grow)
				inside((spot.anchor or "default") .. " " .. layout .. " " .. grow)
			end
		end
	end
	local point = holder.panel:GetPoint(1)
	assert(point == "BOTTOMRIGHT", "in the bottom right corner, Up and left still opens up and left: " .. tostring(point))
	clean(env, K)
end

-- Review of #638, guild chat cover: turned off and on again it covers again even after a click lifted it, a club with no type or a secret selected ID is covered as private, and a secret ID never reaches the game.
do
	local env, K = boot()
	local comm, messages = env.CommunitiesFrame, env.CommunitiesFrame.Chat.MessageFrame
	Q.Write(env, K, "guildCover", true)
	local cover = select(2, comm.Chat:GetChildren())
	click(cover)
	Q.Write(env, K, "guildCover", false)
	Q.Write(env, K, "guildCover", true)
	assert(cover:IsShown() and messages:GetAlpha() == 0, "turned off and on again, guild chat is covered")
	env.C_Club.GetClubInfo = function() return {} end
	comm:OnClubSelected(9)
	assert(cover:IsShown() and messages:GetAlpha() == 0, "a club with no type is covered")
	local asked = 0
	env.C_Club.GetClubInfo = function() asked = asked + 1; return { clubType = 1 } end
	comm:OnClubSelected(env.Secret(9))
	assert(cover:IsShown() and asked == 0, "a secret club ID is covered without asking the game")
	clean(env, K)
end

-- Review of #638, waypoint switches: turning /kpaste off ends its list even while /way stays on, Arrival message off still follows the list silently, and a command switched off or the module off gives its name back.
do
	local env, K, ns = boot()
	Q.Write(env, K, "wayPaste", true)
	Q.Write(env, K, "wayCommand", true)
	ns.PasteWays("/way 10 10 First\n/way 20 20 Second")
	Q.Write(env, K, "wayPaste", false)
	env._pos = { x = 0.1, y = 0.1 }
	env.RunTickers()
	assert(env._waypoint.position.x == 0.1 and env.LiveTickers() == 0, "turning /kpaste off ends its list")
	Q.Write(env, K, "wayCommand", false)
	assert(env.SLASH_KSTYLEQOLWAY1 == nil and env.SlashCmdList.KSTYLEQOLWAY == nil, "turning /way off gives the name back")
	Q.Write(env, K, "wayCommand", true)
	assert(env.SLASH_KSTYLEQOLWAY1 == "/way" and type(env.SlashCmdList.KSTYLEQOLWAY) == "function", "on again claims it again")
	Q.Disable(env, K)
	assert(env.SLASH_KSTYLEQOLWAY1 == nil and env.SlashCmdList.KSTYLEQOLWAY == nil, "the module off gives it back too")
	clean(env, K)
	local env2, K2, ns2 = boot()
	Q.Write(env2, K2, "wayPaste", true)
	Q.Write(env2, K2, "wayArrival", false)
	ns2.PasteWays("/way 10 10 First\n/way 20 20 Second")
	env2._pos = { x = 0.1, y = 0.1 }
	env2.RunTickers()
	assert(env2._waypoint.position.x == 0.2 and not said(env2, "Arrived") and env2.LiveTickers() == 1, "Arrival message off still pins the next, silently")
	clean(env2, K2)
end

-- Review of #638, waypoint state: a new pin where you already arrived is watched again, your own pin's ticker stops as it is announced, and a pin the game refuses is never tracked, announced or counted.
do
	local env, K, ns = boot()
	Q.Write(env, K, "wayCommand", true)
	Q.Write(env, K, "wayPaste", true)
	env._pos = { x = 0.1, y = 0.1 }
	env.SlashCmdList.KSTYLEQOLWAY("10 10")
	env.RunTickers()
	env.SlashCmdList.KSTYLEQOLWAY("10 10")
	assert(env._waypoint and env.LiveTickers() == 1, "a new pin where you arrived is watched")
	env.RunTickers()
	assert(env._waypoint == nil and env.LiveTickers() == 0, "and cleared as you arrive again")
	Q.Write(env, K, "wayManual", true)
	env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1429, 0.1, 0.1))
	env.RunTickers()
	assert(said(env, "Arrived at your map pin.") and env.LiveTickers() == 0, "your own pin's ticker stops as it is announced")
	env.C_Map.ClearUserWaypoint()
	Q.Reset(env)
	env.C_Map.SetUserWaypoint = record(env, "SetUserWaypoint", function() return false end)
	assert(ns.PasteWays("/way 30 30 Bad\n/way 40 40 Bad") == 0 and not said(env, "Pinned 2") and #Q.Calls(env, "SuperTrack") == 0, "a refused pin is not counted, announced or tracked")
	env.SlashCmdList.KSTYLEQOLPASTE("")
	local window = ns.PasteWindow()
	env._canPin = false
	window.area:SetText("/way 10 10 Bad\n/way 20 20 Bad")
	click(window.run)
	assert(window:IsShown() and #Q.Calls(env, "SetUserWaypoint") == 1, "the window stays open while nothing was pinned")
	clean(env, K)
end

-- Review of #638, map calls: a missing call refuses instead of erroring, a map with no size never counts as arrival, and a zone name is not searched in combat.
do
	local env, K, ns = boot()
	Q.Write(env, K, "wayCommand", true)
	Q.Write(env, K, "wayPaste", true)
	local info, create, map = env.C_Map.GetMapInfo, env.UiMapPoint.CreateFromCoordinates, env.C_Map
	env.C_Map.GetMapInfo = nil
	env.SlashCmdList.KSTYLEQOLWAY("Westfall 20 20")
	env.C_Map.GetMapInfo, env.UiMapPoint.CreateFromCoordinates = info, nil
	env.SlashCmdList.KSTYLEQOLWAY("10 10")
	env.UiMapPoint.CreateFromCoordinates, env.C_Map = create, nil
	assert(ns.PasteWays("/way 10 10") == 0, "no map calls pin nothing")
	env.C_Map = map
	env.C_Map.GetMapWorldSize = function() return 0, 0 end
	env._pos = { x = 0.35, y = 0.43 }
	env.SlashCmdList.KSTYLEQOLWAY("90 90")
	env.RunTickers()
	assert(not said(env, "Arrived") and env._waypoint ~= nil, "a map with no size never counts as arrival")
	local scans = 0
	env.C_Map.GetMapChildrenInfo = function() scans = scans + 1; return {} end
	env.SetCombat(true)
	env.SlashCmdList.KSTYLEQOLWAY("Westfall 10 10")
	assert(scans == 0 and said(env, "out of combat"), "a zone name is not searched in combat")
	env.SetCombat(false)
	clean(env, K)
end

-- Review of #638, frame rate and latency: they follow only their interval, not the stat events, and one tick reads the frame rate and both latencies with one call each, and no other stat.
do
	local env, K = boot({ enabled = true, stats = true })
	local fps, crit, net = 0, 0, 0
	env.GetCritChance = function() crit = crit + 1; return 25 end
	env.GetFramerate = function() fps = fps + 1; return 60 end
	env.GetNetStats = function() net = net + 1; return 0, 0, 25, 30 end
	only(env, K, { fps = true, crit = true, home = true, world = true })
	Q.Write(env, K, "statsInterval", 5)
	fps, crit, net = 0, 0, 0
	for _ = 1, 10 do env.FireEvent("UNIT_AURA", "player") end
	env.RunTimers()
	assert(fps == 0 and net == 0 and crit == 1, string.format("ten aura events in one frame read fps %d, latency %d, crit %d", fps, net, crit))
	fps, crit, net = 0, 0, 0
	env.RunTickers()
	assert(fps == 1 and net == 1 and crit == 0, string.format("one tick reads fps %d, latency %d, crit %d", fps, net, crit))
	clean(env, K)
end

-- Idle-redundant-work finding 68: a burst of stat events reads each shown stat once on the next frame, an unchanged value is not drawn again, a changed one is, a secret one is drawn every time without being compared, and the stat events are registered only while a stat that needs them shows.
do
	local env, K, ns = boot()
	local crit = 12.5
	env.GetCritChance = function() return crit end
	env.GetSpellCritChance = function() return 8.25 end
	env.GetMeleeHaste = function() return 5 end
	env.GetSpellBonusDamage = function() return 321 end
	env.UnitArmor = function() return 900, 1000 end
	local live = {}
	local register, unit, unregister = K.Events.Register, K.Events.RegisterUnit, K.Events.Unregister
	K.Events.Register = function(owner, event, ...) if owner == "QoL.stats" then live[event] = true end; return register(owner, event, ...) end
	K.Events.RegisterUnit = function(owner, event, ...) if owner == "QoL.stats" then live[event] = true end; return unit(owner, event, ...) end
	K.Events.Unregister = function(owner, event) if owner == "QoL.stats" then live[event] = nil end; return unregister(owner, event) end
	Q.Write(env, K, "stats", true)
	local frame = ns.StatsFrame()
	local reads, read = 0, frame.read
	frame.read = function(...) reads = reads + 1; return read(...) end
	local function writes(line, from)
		local n = 0
		for i = from + 1, #line._calls do
			local method = line._calls[i].method
			if method == "SetText" or method == "SetFormattedText" then n = n + 1 end
		end
		return n
	end
	local function burst(events)
		local marks = {}
		for i, line in ipairs(frame.lines) do marks[i] = #line._calls end
		reads = 0
		for _ = 1, events do env.FireEvent("UNIT_AURA", "player") end
		env.RunTimers()
		local n = 0
		for i, line in ipairs(frame.lines) do n = n + writes(line, marks[i]) end
		return n
	end
	assert(frame.count == 5, tostring(frame.count))
	local drawn = burst(100)
	assert(reads == 5 and drawn == 0, string.format("100 unchanged aura events read %d stats and draw %d", reads, drawn))
	crit = 25
	drawn = burst(1)
	assert(reads == 5 and drawn == 1 and shows(frame.lines[1]):find("25.00%", 1, true), "a changed value draws its own line only: " .. drawn)
	env.GetCritChance = function() return env.Secret(30) end
	for _ = 1, 2 do
		drawn = burst(1)
		local last = frame.lines[1]._calls[#frame.lines[1]._calls]
		assert(drawn == 1 and last.method == "SetFormattedText" and env.issecretvalue(last.args[2]), "a secret value is drawn each time, never compared")
	end
	assert(next(live) ~= nil, "the stat events listen while a stat shows")
	only(env, K, { fps = true, home = true })
	assert(next(live) == nil, "the frame rate and latency alone listen to no stat event: " .. tostring(next(live)))
	only(env, K, { fps = true, crit = true })
	local n = 0
	for _ in pairs(live) do n = n + 1 end
	assert(n == 9, "a stat shown again listens again: " .. n)
	Q.Write(env, K, "stats", false)
	assert(next(live) == nil, "switching the stats off stops listening")
	clean(env, K)
end

-- Review of #638, raid tool permissions: a plain party member keeps the markers but not ready check, role check or pull timer; the leader gets them; a finder group refuses the role check as Blizzard's raid manager does; an unchanged roster repaints nothing; an unknown raid answer hides the tools.
do
	local env, K = boot()
	env._group = true
	Q.Write(env, K, "raidTools", "group")
	local holder = env.KstyleUI_RaidTools
	assert(holder:IsShown(), "shown in a party")
	for i = 1, 3 do assert(not holder.buttons[i]:IsEnabled(), "a plain member cannot use action " .. i) end
	assert(holder.buttons[4]:IsEnabled() and holder.buttons[12]:IsEnabled(), "a plain member marks")
	env._leader = true
	env.FireEvent("PARTY_LEADER_CHANGED")
	for i = 1, 3 do assert(holder.buttons[i]:IsEnabled(), "the leader uses action " .. i) end
	env._lfg = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not holder.buttons[2]:IsEnabled() and holder.buttons[1]:IsEnabled(), "a finder group refuses the role check")
	local writes = 0
	for _, button in ipairs(holder.buttons) do
		local set = button.SetEnabled
		button.SetEnabled = function(...) writes = writes + 1; return set(...) end
	end
	for _ = 1, 10 do env.FireEvent("GROUP_ROSTER_UPDATE") end
	assert(writes == 0, "an unchanged roster repaints nothing: " .. writes)
	env._leader = nil
	env.IsInRaid = nil
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not holder:IsShown(), "an unknown raid answer hides the tools")
	clean(env, K)
end

-- Review of #638, restoring: the map sidebars go back to the alpha and mouse they had, and a filter KstyleUI ticked is unticked after a reload, from Blizzard's saved filters, while the player's own tick stays.
do
	local env, K = boot()
	local blackout = env.WorldMapFrame.BlackoutFrame
	blackout:EnableMouse(false)
	blackout.Blackout:SetAlpha(0.6)
	Q.Write(env, K, "mapSidebars", true)
	Q.Write(env, K, "mapSidebars", false)
	assert(blackout.Blackout:GetAlpha() == 0.6 and not blackout:IsMouseEnabled(), "off puts back the sidebars as they were")
	clean(env, K)
	local saved = { version = 42, profiles = { Default = { QoL = { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env1, K1 = boot(nil, saved)
	Q.Write(env1, K1, "ahCurrent", true)
	assert(env1._filters[3] == true, "ticked")
	carried = env1._filters
	local env2, K2 = boot(nil, saved)
	carried = nil
	Q.Write(env2, K2, "ahCurrent", false)
	assert(env2._filters[3] == false, "after a reload, off unticks the tick KstyleUI made")
	carried = { [3] = true }
	local env3, K3 = boot(nil, saved)
	carried = nil
	Q.Write(env3, K3, "ahCurrent", true)
	Q.Write(env3, K3, "ahCurrent", false)
	assert(env3._filters[3] == true, "the player's own tick still survives")
	clean(env1, K1)
	clean(env2, K2)
	clean(env3, K3)
end

-- Review of #638, the macro, the latency text and the key binding: a macro of the same name with another body is not picked up, latency reads in the client's language, and the binding sits under the shared KstyleUI heading.
do
	local env, K = boot()
	Q.Write(env, K, "wayPaste", true)
	env.GetMacroInfo = function(i) if i == 1 then return "KstyleUI Waypoints", 1, "/say unrelated" end end
	env.SlashCmdList.KSTYLEQOLPASTE("macro")
	assert(#Q.Calls(env, "PickupMacro") == 0 and #Q.Calls(env, "CreateMacro") == 0 and said(env, "KstyleUI Waypoints"), "another macro with the name is reported, not picked up")
	env._group = true
	Q.Write(env, K, "raidTools", "group")
	local file = assert(io.open("KstyleUI_QoL/Bindings.xml", "rb"))
	local xml = file:read("*a")
	file:close()
	assert(xml:find('category="BINDING_HEADER_KSTYLEUI_ACTIONBARS"', 1, true) and env.BINDING_HEADER_KSTYLEUI_QOL == nil, "the binding sits under the shared KstyleUI heading")
	clean(env, K)
	locale = "zhCN"
	local env2, K2, ns2 = boot({ enabled = true, stats = true })
	locale = nil
	only(env2, K2, { home = true })
	assert(shows(ns2.StatsFrame().lines[1]):find("\230\175\171\231\167\146", 1, true), "latency in the client's language: " .. shows(ns2.StatsFrame().lines[1]))
	clean(env2, K2)
end

print("qol parity round 3b ok")
