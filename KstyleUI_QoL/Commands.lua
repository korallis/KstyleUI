-- Commands.lua: the /way, /kpaste and /cd commands, the waypoint paste window and its macro, and the arrival message: each command is claimed the first time its switch is on, only when no other addon owns its name, and while its switch is off it only says where to turn it on; pins follow one another as you arrive, and arrival is watched by a one-second ticker only while a pin it announces is set.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY, MACRO = "QoL.commands", "qol.paste", "KstyleUI Waypoints"
local ARRIVE, WIDTH, HEIGHT = 10, 360, 240
local claimed, queue = {}, {}
local ticker, watched, done, window

local function Owned(alias)
	for name, value in pairs(_G) do
		if type(name) == "string" and name:match("^SLASH_.+%d+$") and not name:match("^SLASH_KSTYLEQOL") and type(value) == "string" and value:lower() == alias then return true end
	end
end

local function Point(p)
	local pos = type(p) == "table" and p.position
	local map, x, y = ns.Number(type(p) == "table" and p.uiMapID), type(pos) == "table" and ns.Number(pos.x), type(pos) == "table" and ns.Number(pos.y)
	if map and x and y then return map, x, y end
end

local function Current()
	local p = type(C_Map) == "table" and ns.Ask(C_Map.GetUserWaypoint)
	return Point(p) and p or nil
end

local function Same(a, b)
	local am, ax, ay = Point(a)
	local bm, bx, by = Point(b)
	return am ~= nil and am == bm and math.abs(ax - bx) < 1e-4 and math.abs(ay - by) < 1e-4
end

local function Yards(p)
	local map, x, y = Point(p)
	local pos = map and type(C_Map.GetPlayerMapPosition) == "function" and ns.Ask(C_Map.GetPlayerMapPosition, map, "player")
	local w, h
	if map and type(C_Map.GetMapWorldSize) == "function" then w, h = C_Map.GetMapWorldSize(map) end
	local px, py = type(pos) == "table" and ns.Number(pos.x), type(pos) == "table" and ns.Number(pos.y)
	if not (px and py and ns.Number(w) and ns.Number(h)) then return nil end
	return math.sqrt(((px - x) * w) ^ 2 + ((py - y) * h) ^ 2)
end

local function Set(p)
	local map, x, y = Point(p)
	if not (map and type(UiMapPoint) == "table" and type(C_Map.SetUserWaypoint) == "function") or ns.Ask(C_Map.CanSetUserWaypointOnMap, map) ~= true then
		K.Print(L["That map cannot hold a pin."])
		return false
	end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
	if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	local link = ns.Ask(C_Map.GetUserWaypointHyperlink)
	if type(link) == "string" then K.Print(link .. (p.name and " " .. p.name or "")) end
	return true
end

local Watch

local function Arrived(p)
	watched, done = nil, p
	local mine = queue[1] and Same(p, queue[1])
	K.Print(mine and queue[1].name and string.format(L["Arrived at %s."], queue[1].name) or L["Arrived at your map pin."])
	if not mine then return end
	table.remove(queue, 1)
	if queue[1] then Set(queue[1]) elseif type(C_Map.ClearUserWaypoint) == "function" then C_Map.ClearUserWaypoint() end
	Watch()
end

local function Check()
	local yards = watched and Yards(watched)
	if yards and yards <= ARRIVE then Arrived(watched) end
end

function Watch()
	local p = Current()
	if not p and watched then
		local yards = Yards(watched)
		if yards and yards <= 2 * ARRIVE then Arrived(watched) end
		p = Current()
	end
	local mine = p and queue[1] and Same(p, queue[1])
	if queue[1] and not mine then queue = {} end
	local want = ns.running and p and (mine and ns.Get("wayArrival") or not mine and ns.Get("wayManual"))
	watched = want and not Same(p, done) and p or nil
	if watched and not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then ticker = C_Timer.NewTicker(1, Check)
	elseif not watched and ticker then ticker:Cancel(); ticker = nil end
end

local function FindMap(name)
	local map = ns.Ask(C_Map.GetBestMapForUnit, "player")
	local info = ns.Number(map) and C_Map.GetMapInfo(map)
	while type(info) == "table" and ns.Number(info.parentMapID) and info.parentMapID > 0 do
		map, info = info.parentMapID, C_Map.GetMapInfo(info.parentMapID)
	end
	local list = ns.Number(map) and type(C_Map.GetMapChildrenInfo) == "function" and C_Map.GetMapChildrenInfo(map, nil, true)
	local prefix
	for _, child in ipairs(type(list) == "table" and list or {}) do
		local title = type(child.name) == "string" and not ns.IsSecret(child.name) and child.name:lower()
		if title == name then return child.mapID end
		if title and not prefix and title:sub(1, #name) == name then prefix = child.mapID end
	end
	return prefix
end

function ns.ParseWay(msg)
	local words = {}
	for word in tostring(msg):gsub(",", " "):gmatch("%S+") do words[#words + 1] = word end
	for i = 1, #words - 1 do
		local x, y = tonumber(words[i]), tonumber(words[i + 1])
		if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
			local zone, name = table.concat(words, " ", 1, i - 1), table.concat(words, " ", i + 2)
			local map = zone == "" and ns.Ask(C_Map.GetBestMapForUnit, "player") or zone:match("^#(%d+)$") and tonumber(zone:sub(2)) or FindMap(zone:lower())
			if not ns.Number(map) then return nil, zone == "" and L["That map cannot hold a pin."] or string.format(L["No map for %s."], zone) end
			return { uiMapID = map, position = { x = x / 100, y = y / 100 }, name = name ~= "" and name or nil }
		end
	end
	return nil, L["Use /way x y, or /way zone x y."]
end

local function Pin(list)
	queue = list
	if list[1] and Set(list[1]) then Watch() end
end

local function Way(msg)
	if type(C_Map) ~= "table" then return end
	local p, problem = ns.ParseWay(msg)
	if p then Pin({ p }) else K.Print(problem) end
end

function ns.PasteWays(text)
	local list = {}
	for line in tostring(text):gmatch("[^\r\n]+") do
		local rest = line:match("^%s*/k?t?way%s+(.+)$")
		local p = rest and ns.ParseWay(rest)
		if p then list[#list + 1] = p end
	end
	if #list > 1 then K.Print(string.format(L["Pinned %d waypoints; each follows the last as you arrive."], #list)) end
	Pin(list)
	return #list
end

local function Paste()
	if not window then
		window = Widgets.Panel(K.Scale.Root(), { title = L["Paste waypoints"], popup = true, close = true, escape = true, strata = "DIALOG" })
		Widgets.Size(window, WIDTH, HEIGHT)
		local content, gap = window.content, Tokens.Size("gapMedium")
		window.run = Widgets.Button(content, { text = L["Pin all"], onClick = function()
			if ns.PasteWays(window.area:GetText()) > 0 then window:Hide() end
		end })
		Widgets.Point(window.run, "BOTTOMRIGHT", content, "BOTTOMRIGHT")
		window.area = Widgets.TextArea(content, { text = "" })
		Widgets.Point(window.area, "TOPLEFT", content, "TOPLEFT")
		Widgets.Point(window.area, "BOTTOMRIGHT", window.run, "TOPRIGHT", 0, gap)
		window:Hide()
		Widgets.Place(window, KEY, { anchor = "CENTER", x = 0, y = 120 }, { label = L["Paste waypoints"], module = ns.MODULE })
	end
	window.area:SetText("")
	window:Open()
end

function ns.PasteWindow() return window end

function ns.CreateMacro()
	local max = type(Constants) == "table" and type(Constants.MacroConsts) == "table" and ns.Number(Constants.MacroConsts.MAX_ACCOUNT_MACROS)
	if ns.Ask(InCombatLockdown) ~= false or not max or type(CreateMacro) ~= "function" or type(PickupMacro) ~= "function" or type(GetMacroInfo) ~= "function" then return end
	local index
	for i = 1, max do
		if GetMacroInfo(i) == MACRO then index = i break end
	end
	if not index and (ns.Number(ns.Ask(GetNumMacros)) or max) < max then index = CreateMacro(MACRO, "INV_MISC_QUESTIONMARK", "/kpaste") end
	if ns.Number(index) then PickupMacro(index) else K.Print(L["Your account macros are full."]) end
end

local function Cooldowns()
	local frame = CooldownViewerSettings
	if ns.Ask(InCombatLockdown) ~= false then K.Print(L["Try again out of combat."])
	elseif type(frame) == "table" and type(frame.TogglePanel) == "function" then frame:TogglePanel() end
end

local COMMANDS = {
	{ "wayCommand", "/way", Way },
	{ "wayPaste", "/kpaste", function(msg) if tostring(msg):match("^%s*(.-)%s*$"):lower() == "macro" then ns.CreateMacro() else Paste() end end },
	{ "cdCommand", "/cd", Cooldowns },
}

local function Run(command, msg)
	if ns.running and ns.Get(command[1]) then command[3](msg) else K.Print(string.format(L["Turn %s on in KstyleUI, Quality of life."], command[2])) end
end

local function Claim()
	for i, command in ipairs(COMMANDS) do
		if ns.running and ns.Get(command[1]) and not claimed[i] and type(SlashCmdList) == "table" then
			claimed[i] = true
			if Owned(command[2]) then
				K.Print(string.format(L["Another addon owns %s."], command[2]))
			elseif i == 1 then
				SLASH_KSTYLEQOLWAY1 = command[2]
				SlashCmdList.KSTYLEQOLWAY = function(msg) Run(command, msg) end
			elseif i == 2 then
				SLASH_KSTYLEQOLPASTE1 = command[2]
				SlashCmdList.KSTYLEQOLPASTE = function(msg) Run(command, msg) end
			else
				SLASH_KSTYLEQOLCD1 = command[2]
				SlashCmdList.KSTYLEQOLCD = function(msg) Run(command, msg) end
			end
		end
	end
end

local function Sync()
	Claim()
	local on = ns.running and (ns.Get("wayCommand") or ns.Get("wayPaste") or ns.Get("wayManual"))
	for _, event in ipairs({ "USER_WAYPOINT_UPDATED", "PLAYER_ENTERING_WORLD" }) do
		if on then K.Events.Register(OWNER, event, Watch) else K.Events.Unregister(OWNER, event) end
	end
	if not on then queue = {} end
	if window and not (ns.running and ns.Get("wayPaste")) then window:Hide() end
	Watch()
end

local KEYS = { wayCommand = true, wayPaste = true, wayArrival = true, wayManual = true, cdCommand = true }

ns.AddPart({
	name = "commands",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or KEYS[key] then Sync() end
	end,
})
