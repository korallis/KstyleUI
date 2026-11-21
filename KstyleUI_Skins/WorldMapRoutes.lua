-- WorldMapRoutes.lua: client destinations, road routes and travel steps beside the world map.
local _, ns = ...

local K = KstyleUI
local Widgets, L = K.Widgets, K.L
local Skins, Style, Lumen = ns.Skins, ns.Style, ns.Lumen
local Routes = {}
ns.WorldMapRoutes = Routes
local Roads = ns.WorldMapRoads

local map, panel, search, card, title, distance, note, clear
local active, previousCVar, previousWaypoint, previousTrack, ownsWaypoint
local target, canvas, elapsed = nil, nil, 0
local routeX, routeY, routeMap, routeTarget, routeMounted, routeRoads
local routePlayerMap, routePlayerX, routePlayerY
local routeWidth, routeHeight, routeScale, routeContinent
local steps, stepChild, chip
local results, dots, startDots, zones, stepRows, stepAmounts = {}, {}, {}, {}, {}, {}
local hooked = setmetatable({}, { __mode = "k" })
local CVAR = "showDungeonEntrancesOnMap"

local function Secret(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Plain(value, kind)
	if not Secret(value) and type(value) == kind then return value end
end

local function Field(value, key, kind)
	value = Plain(value, "table")
	return value and Plain(value[key], kind)
end

local function Call(api, name, ...)
	if type(api) == "table" and type(api[name]) == "function" then return api[name](...) end
end

local function Number(value)
	value = Plain(value, "number")
	if value and value == value and math.abs(value) < math.huge then return value end
end

local function XY(position)
	if not Plain(position, "table") or type(position.GetXY) ~= "function" then return end
	local x, y = position:GetXY()
	x, y = Number(x), Number(y)
	if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function On(key)
	return active and Skins.Setting("worldMap", key) == true
end

local function MapID()
	return map and type(map.GetMapID) == "function" and Number(map:GetMapID()) or nil
end

function Routes.Levels(id)
	if not Number(id) or id <= 0 then return end
	local low, high = Call(C_Map, "GetMapLevels", id)
	low, high = Number(low), Number(high)
	if low and high and low > 0 and high >= low then return string.format(L["Level %d-%d"], low, high) end
end

function Routes.DungeonLevels(info)
	local id = Field(info, "journalInstanceID", "number")
	if not Number(id) or type(EJ_GetInstanceInfo) ~= "function" then return end
	local area = select(7, EJ_GetInstanceInfo(id))
	return Routes.Levels(area)
end

local function Add(list, kind, id, name, x, y)
	if not Number(id) or not Plain(name, "string") or name == "" then return end
	x, y = Number(x), Number(y)
	if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
	list[#list + 1] = { kind = kind, mapID = id, name = name, x = x, y = y }
end

function Routes.Search(query)
	local list, id = {}, MapID()
	if not On("routes") or not id or not Plain(query, "string") or query == "" then return list end
	local factions = type(Enum) == "table" and Plain(Enum.FlightPathFaction, "table")
	local faction = type(UnitFactionGroup) == "function" and Plain(UnitFactionGroup("player"), "string")
	for _, source in ipairs({
		{ C_TaxiMap, "GetTaxiNodesForMap", "flight" },
		{ C_EncounterJournal, "GetDungeonEntrancesForMap", "dungeon" },
		{ C_Map, "GetMapLinksForMap", "link" },
	}) do
		if source[3] ~= "flight" or Plain(Call(C_TaxiMap, "ShouldMapShowTaxiNodes", id), "boolean") == true then
			for _, info in ipairs(Plain(Call(source[1], source[2], id), "table") or {}) do
				local nodeFaction = Field(info, "faction", "number")
				if source[3] ~= "flight" or (factions and nodeFaction and
					(nodeFaction ~= factions.Horde or faction == "Horde") and (nodeFaction ~= factions.Alliance or faction == "Alliance")) then
					local x, y = XY(Field(info, "position", "table"))
					Add(list, source[3], id, Field(info, "name", "string"), x, y)
				end
			end
		end
	end
	for _, poi in ipairs(Plain(Call(C_AreaPoiInfo, "GetAreaPOIForMap", id), "table") or {}) do
		if Number(poi) then
			local info = Call(C_AreaPoiInfo, "GetAreaPOIInfo", id, poi)
			local x, y = XY(Field(info, "position", "table"))
			Add(list, "poi", id, Field(info, "name", "string"), x, y)
		end
	end
	local quests = {}
	for _, info in ipairs(Plain(Call(C_QuestLog, "GetQuestsOnMap", id), "table") or {}) do
		local quest = Field(info, "questID", "number")
		if Number(quest) then quests[quest] = info end
	end
	local count = Number(Call(C_QuestLog, "GetNumQuestWatches")) or 0
	for i = 1, count do
		local quest = Number(Call(C_QuestLog, "GetQuestIDForQuestWatchIndex", i))
		if quest then quests[quest] = quests[quest] or {} end
	end
	for quest, info in pairs(quests) do
		local watch = Call(C_QuestLog, "GetQuestWatchType", quest)
		if not Secret(watch) and watch ~= nil then
			local questMap, x, y = Call(C_QuestLog, "GetNextWaypoint", quest)
			if not Number(questMap) or not Number(x) or not Number(y) then
				questMap, x, y = info.mapID, info.x, info.y
			end
			Add(list, "quest", questMap, Call(C_QuestLog, "GetTitleForQuestID", quest), x, y)
		end
	end
	for _, guid in ipairs(Plain(Call(C_VignetteInfo, "GetVignettes"), "table") or {}) do
		if Plain(guid, "string") then
			local info = Call(C_VignetteInfo, "GetVignetteInfo", guid)
			if Field(info, "onWorldMap", "boolean") == true then
				local x, y = XY(Call(C_VignetteInfo, "GetVignettePosition", guid, id))
				Add(list, "vignette", id, Field(info, "name", "string"), x, y)
			end
		end
	end
	local found = {}
	query = K.Locale.Lower(query)
	for _, row in ipairs(list) do
		if K.Locale.Lower(row.name):find(query, 1, true) then found[#found + 1] = row end
	end
	table.sort(found, function(a, b) return a.name < b.name end)
	return found
end

function Routes.Measure(x, y, tx, ty, width, height, mounted)
	if not Number(x) or not Number(y) or not Number(tx) or not Number(ty) or not Number(width) or not Number(height) then return end
	if width <= 0 or height <= 0 then return end
	local dx, dy = (tx - x) * width, (ty - y) * height
	local yards = math.sqrt(dx * dx + dy * dy)
	return yards, yards / (mounted == true and 14 or 7) / 60
end

local function Hide(list)
	for _, region in ipairs(list) do region:Hide() end
end

local function DrawRoute(x, y, tx, ty, road, continent, moving)
	Hide(startDots)
	if not moving then Hide(dots) end
	if not canvas or (not x and not road) then return end
	local width, height = Number(canvas:GetWidth()), Number(canvas:GetHeight())
	if not width or not height or width <= 0 or height <= 0 then return end
	local count, pool = 0, dots
	local unit = Lumen.Size(canvas, 1)
	local function Dot(px, py, kind, turn)
		if px < 0 or px > 1 or py < 0 or py > 1 or count >= 1800 then return end
		count = count + 1
		local outline, dot = pool[count * 2 - 1], pool[count * 2]
		if not dot then
			outline = canvas:CreateTexture(nil, "ARTWORK", nil, -2)
			dot = canvas:CreateTexture(nil, "ARTWORK", nil, -1)
			pool[count * 2 - 1], pool[count * 2] = outline, dot
		end
		dot:SetColorTexture(Lumen.Color(kind == "walk" and "textEmphasis" or kind == "swim" and "questDisc" or kind == "flight" and "questGold" or "gilt"))
		outline:SetColorTexture(Lumen.Color("edgeOuter"))
		local size = (turn and 7 or 3) * unit
		for i = 1, 2 do
			local region = i == 1 and outline or dot
			region:SetSize(region == dot and size or size + 2 * unit, region == dot and size or size + 2 * unit)
			region:SetRotation(turn and math.pi / 4 or 0)
			region:ClearAllPoints()
			region:SetPoint("CENTER", canvas, "TOPLEFT", px * width, -py * height)
			region:Show()
		end
	end
	local function Segment(ax, ay, bx, by, kind, dashed)
		local dx, dy, low, high = bx - ax, by - ay, 0, 1
		if dx == 0 then
			if ax < 0 or ax > 1 then return end
		else
			local a, b = -ax / dx, (1 - ax) / dx
			low, high = math.max(low, math.min(a, b)), math.min(high, math.max(a, b))
		end
		if dy == 0 then
			if ay < 0 or ay > 1 then return end
		else
			local a, b = -ay / dy, (1 - ay) / dy
			low, high = math.max(low, math.min(a, b)), math.min(high, math.max(a, b))
		end
		if low > high then return end
		local n = math.min(640, math.max(1, math.ceil(math.sqrt((dx * width) ^ 2 + (dy * height) ^ 2) * (high - low) / (2 * unit))))
		for i = 0, n do
			if not dashed or i % 4 < 2 then
				local t = low + (high - low) * i / n
				Dot(ax + dx * t, ay + dy * t, kind)
			end
		end
	end
	if not road then Segment(x, y, tx, ty, "walk", true); return end
	for index, leg in ipairs(road.legs) do
		if moving and index > 1 then break end
		pool, count = index == 1 and startDots or dots, index <= 2 and 0 or count
		local px, py
		for i = 1, #leg.pts, 2 do
			local mapID, point = Call(C_Map, "GetMapPosFromWorldPos", continent, CreateVector2D(leg.pts[i], leg.pts[i + 1]), MapID())
			local ax, ay
			if Number(mapID) == MapID() and Plain(point, "table") and type(point.GetXY) == "function" then
				ax, ay = point:GetXY()
				ax, ay = Number(ax), Number(ay)
			end
			if ax and ay and px then Segment(px, py, ax, ay, leg.kind, leg.dashed or leg.kind == "flight" or leg.kind == "boat") end
			px, py = ax, ay
		end
		if leg.turn and px then Dot(px, py, leg.kind, true) end
	end
end

local function World(id, x, y)
	if type(CreateVector2D) ~= "function" then return end
	local continent, point = Call(C_Map, "GetWorldPosFromMapPos", id, CreateVector2D(x, y))
	if Number(continent) and Plain(point, "table") and type(point.GetXY) == "function" then
		local wx, wy = point:GetXY()
		wx, wy = Number(wx), Number(wy)
		if wx and wy then return continent, wx, wy end
	end
end

local function RoadRoute(mounted, playerMap, x, y, moving)
	if not x then return nil, L["Player position unavailable."] end
	local continent, wx, wy = World(playerMap, x, y)
	if moving and continent and continent == routeContinent and Roads.MoveStart(Routes.road, wx, wy, mounted) then return Routes.road, nil, continent, true end
	local targetContinent, tx, ty = World(target.mapID, target.x, target.y)
	if not continent or not targetContinent then return nil, L["Road coordinates unavailable."] end
	if continent ~= targetContinent then return nil, L["Destination is on another continent."] end
	local graph = Roads.Graph(continent)
	if not graph then return nil, L["Road data unavailable for this continent."] end
	if not graph.flights then
		graph.flights = {}
		for _, node in ipairs(graph.nodes) do if node.kind == "flight" then graph.flights[#graph.flights + 1] = node end end
	end
	local flights, faction = {}, type(UnitFactionGroup) == "function" and Plain(UnitFactionGroup("player"), "string")
	local factions = type(Enum) == "table" and Plain(Enum.FlightPathFaction, "table")
	local continentMap = playerMap
	local continentType = type(Enum) == "table" and Field(Enum.UIMapType, "Continent", "number")
	if not continentType then continentMap = nil end
	while continentMap do
		local info = Call(C_Map, "GetMapInfo", continentMap)
		if Field(info, "mapType", "number") == continentType then break end
		local parent = Field(info, "parentMapID", "number")
		continentMap = Number(parent) and parent > 0 and parent ~= continentMap and parent or nil
	end
	for _, info in ipairs(continentMap and Plain(Call(C_TaxiMap, "GetTaxiNodesForMap", continentMap), "table") or {}) do
		local side = Field(info, "faction", "number")
		if factions and side and Field(info, "isUndiscovered", "boolean") == false and
			(side == factions.Neutral or side == factions.Horde and faction == "Horde" or side == factions.Alliance and faction == "Alliance") then
			local name = Field(info, "name", "string")
			local mx, my = XY(Field(info, "position", "table"))
			local taxiContinent, fx, fy
			if mx then taxiContinent, fx, fy = World(continentMap, mx, my) end
			for _, node in ipairs(graph.flights) do
				if node.name == name or (taxiContinent == continent and (node.x - fx) ^ 2 + (node.y - fy) ^ 2 <= 3600) then flights[node.id] = true end
			end
		end
	end
	local route = Roads.Solve(graph, wx, wy, tx, ty, mounted, flights)
	return route, not route and L["No connected road route."] or nil, continent
end

local RefreshRoute
local function Tick(_, delta)
	elapsed = elapsed + delta
	if elapsed >= 0.25 then elapsed = 0; RefreshRoute() end
end

RefreshRoute = function()
	if not card then return end
	local show = On("routes") and target ~= nil
	card:SetShown(show)
	panel:SetScript("OnUpdate", show and Tick or nil)
	if not show then routeMap = nil; DrawRoute() return end
	title:SetText(target.name)
	distance:SetText(L["Distance unavailable"])
	local mounted = type(IsMounted) == "function" and Plain(IsMounted(), "boolean") or false
	local playerMap = Number(Call(C_Map, "GetBestMapForUnit", "player"))
	local playerX, playerY
	if playerMap then playerX, playerY = XY(Call(C_Map, "GetPlayerMapPosition", playerMap, "player")) end
	local x, y
	local id = MapID()
	local width, height = canvas and Number(canvas:GetWidth()), canvas and Number(canvas:GetHeight())
	local scale = canvas and Widgets.ScaleFactor(canvas)
	if id == target.mapID then
		if playerMap == target.mapID then x, y = playerX, playerY
		else x, y = XY(Call(C_Map, "GetPlayerMapPosition", target.mapID, "player")) end
	end
	local reusable = target == routeTarget and mounted == routeMounted and On("followRoads") == routeRoads and playerMap == routePlayerMap
	local moving = reusable and id == routeMap and width == routeWidth and height == routeHeight and scale == routeScale
	if not moving or playerX ~= routePlayerX or playerY ~= routePlayerY or x ~= routeX or y ~= routeY then
		local road, reason, continent, startOnly
		if On("followRoads") then road, reason, continent, startOnly = RoadRoute(mounted, playerMap, playerX, playerY, reusable and Routes.road ~= nil) end
		Routes.road = road
		DrawRoute(x, y, target.x, target.y, road, continent, startOnly and moving)
		steps:SetShown(road ~= nil)
		chip:SetText(road and road.saved and string.format(L["Flight path saves %d min"], road.saved) or "")
		note:SetText(reason or (road and (road.dashed and L["The ground may block this."] or L["Follow the marked roads and travel stops."])) or L["Straight line - terrain may block the way."])
		if road then Routes.ShowSteps(road) else
			Hide(stepRows); Hide(stepAmounts)
			card:SetSize(280, 142)
			title:SetWidth(250); distance:SetWidth(250); note:SetSize(250, 18)
		end
		routeX, routeY, routeMap, routeTarget, routeMounted, routeRoads = x, y, id, target, mounted, On("followRoads")
		routePlayerMap, routePlayerX, routePlayerY = playerMap, playerX, playerY
		routeWidth, routeHeight, routeScale, routeContinent = width, height, scale, continent
	end
	if Routes.road then
		distance:SetText(string.format(L["%d yd - about %d min"], math.floor(Routes.road.yards + 0.5), math.max(1, math.ceil(Routes.road.seconds / 60))))
	elseif x then
		local worldWidth, worldHeight = Call(C_Map, "GetMapWorldSize", target.mapID)
		local yards, minutes = Routes.Measure(x, y, target.x, target.y, worldWidth, worldHeight, mounted)
		if yards then distance:SetText(string.format(L["%d yd - about %d min"], math.floor(yards + 0.5), math.max(1, math.ceil(minutes)))) end
	end
end

function Routes.Clear()
	local current = Call(C_Map, "GetUserWaypoint")
	local x, y = XY(Field(current, "position", "table"))
	local own = ownsWaypoint and target and Field(current, "uiMapID", "number") == target.mapID and x == target.x and y == target.y
	if own then
		if previousWaypoint then Call(C_Map, "SetUserWaypoint", previousWaypoint) else Call(C_Map, "ClearUserWaypoint") end
		if previousTrack ~= nil then Call(C_SuperTrack, "SetSuperTrackedUserWaypoint", previousTrack) end
	end
	target = nil
	ownsWaypoint, previousWaypoint, previousTrack = nil, nil, nil
	RefreshRoute()
end

function Routes.Pick(row)
	if not On("routes") or not Plain(row, "table") or not Number(row.mapID) or not Number(row.x) or not Number(row.y) or not Plain(row.name, "string") then return end
	if row.mapID <= 0 or row.x < 0 or row.x > 1 or row.y < 0 or row.y > 1 then return end
	if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.SetSuperTrackedUserWaypoint) ~= "function" then return end
	if type(UiMapPoint) ~= "table" or type(UiMapPoint.CreateFromCoordinates) ~= "function" then return end
	local can = Call(C_Map, "CanSetUserWaypointOnMap", row.mapID)
	if Secret(can) or can == false then return end
	local waypoint = UiMapPoint.CreateFromCoordinates(row.mapID, row.x, row.y)
	local old = Call(C_Map, "GetUserWaypoint")
	local tracked = Plain(Call(C_SuperTrack, "IsSuperTrackingUserWaypoint"), "boolean")
	local set = Call(C_Map, "SetUserWaypoint", waypoint)
	if Secret(set) or set ~= true then return end
	if not ownsWaypoint then previousWaypoint, previousTrack = Plain(old, "table"), tracked end
	ownsWaypoint, target = true, row
	Call(C_SuperTrack, "SetSuperTrackedUserWaypoint", true)
	Hide(results)
	if search then search:ClearFocus() end
	RefreshRoute()
end

local function Text(parent, role, size, color)
	local text = Widgets.FontString(parent, "OVERLAY")
	Style.Text(text, role, nil, function() return Lumen.Size(parent, size) end)
	text:SetTextColor(Lumen.Color(color or "textEmphasis"))
	text:SetJustifyH("LEFT")
	return text
end

function Routes.ShowSteps(road)
	local rows = {}
	for _, leg in ipairs(road.legs) do
		if leg.len > 0 then
			local last = rows[#rows]
			if last and not last.stop and last.kind == leg.kind and (leg.kind == "walk" or leg.kind == "swim") and not leg.dashed and not last.dashed then
				last.to, last.len, last.seconds = leg.to or last.to, last.len + leg.len, last.seconds + leg.seconds
				last.stop = leg.stop
			else rows[#rows + 1] = { kind = leg.kind, from = leg.from, to = leg.to, len = leg.len, seconds = leg.seconds, dashed = leg.dashed, stop = leg.stop } end
		end
	end
	local top = 0
	for i, leg in ipairs(rows) do
		local text = stepRows[i] or Text(stepChild, "body", 11, "text")
		if not stepRows[i] then Style.MetricText(text) end
		stepRows[i] = text
		local amount = stepAmounts[i] or Text(stepChild, "number", 13)
		stepAmounts[i] = amount
		local label
		if leg.kind == "flight" then label = string.format(L["Flight from %s to %s"], leg.from, leg.to)
		elseif leg.kind == "boat" then label = string.format(L["Boat to %s"], leg.to)
		elseif leg.kind == "lift" then label = string.format(L["Lift to %s"], leg.to)
		elseif leg.kind == "swim" then label = L["Swim"]
		else label = string.format(leg.dashed and L["Off road to %s"] or L["Road to %s"], leg.to or target.name) end
		text:ClearAllPoints()
		text:SetPoint("TOPLEFT", 0, -top)
		text:SetWidth(274)
		text:SetText(i .. ". " .. label)
		local height = math.max(16, Number(text:GetStringHeight()) or 16)
		text:SetHeight(height)
		amount:ClearAllPoints()
		amount:SetPoint("TOPLEFT", 0, -top - height)
		amount:SetSize(274, 18)
		amount:SetText(string.format(L["%d yd - about %d min"], math.floor(leg.len + 0.5), math.max(1, math.ceil(leg.seconds / 60))))
		amount:Show()
		height = height + 26
		text:Show()
		top = top + height
	end
	for i = #rows + 1, #stepRows do stepRows[i]:Hide(); stepAmounts[i]:Hide() end
	card:SetWidth(310)
	title:SetWidth(282); distance:SetWidth(282); note:SetSize(282, 32)
	local offset = road.saved and 144 or 118
	steps:ClearAllPoints()
	steps:SetPoint("TOPLEFT", 14, -offset)
	stepChild:SetHeight(math.max(1, top))
	steps:SetHeight(math.min(158, math.max(36, top)))
	card:SetHeight(offset + 46 + steps:GetHeight())
	steps:SetVerticalScroll(math.min(steps:GetVerticalScroll(), math.max(0, top - steps:GetHeight())))
end

local function SearchChanged(query)
	Hide(results)
	for i, row in ipairs(Routes.Search(query)) do
		if i > 6 then break end
		local button = results[i]
		if not button then
			button = CreateFrame("Button", nil, panel)
			button:SetSize(280, 28)
			button:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -(i - 1) * 28 - 3)
			local fill = button:CreateTexture(nil, "BACKGROUND")
			fill:SetAllPoints(button)
			fill:SetColorTexture(Lumen.Color("surface"))
			local wash = button:CreateTexture(nil, "ARTWORK")
			wash:SetAllPoints(button)
			wash:SetAtlas("questlog-quest-glow-yellow")
			wash:Hide()
			button:SetScript("OnEnter", function() wash:Show() end)
			button:SetScript("OnLeave", function() wash:Hide() end)
			local text = Widgets.FontString(button, "OVERLAY")
			Style.Text(text, "body")
			text:SetJustifyH("LEFT")
			text:SetPoint("LEFT", 10, 0)
			text:SetPoint("RIGHT", -10, 0)
			button.Text = text
			results[i] = button
		end
		button.Text:SetText(row.name)
		button:SetScript("OnClick", function() Routes.Pick(row) end)
		button:Show()
	end
end

local function Build()
	if panel then return end
	panel = CreateFrame("Frame", nil, map)
	panel:SetAllPoints(map)
	panel:SetFrameLevel(map:GetFrameLevel() + 30)
	search = Widgets.EditBox(panel, { width = 280, height = 28, placeholder = L["Search the map"], onChange = SearchChanged,
		onEscape = function() Hide(results) end, onEnter = function(query) Routes.Pick(Routes.Search(query)[1]) end })
	search:SetPoint("TOPLEFT", map.ScrollContainer or map, "TOPLEFT", 12, -12)
	card = CreateFrame("Frame", nil, map)
	card:SetFrameLevel(map:GetFrameLevel() + 25)
	card:SetSize(280, 142)
	card:SetPoint("BOTTOMRIGHT", map.ScrollContainer or map, "BOTTOMRIGHT", -12, 12)
	card.chrome = Widgets.Chrome(card, { shape = "window", fill = "surface" })
	local cap = Text(card, "caps", 12, "gilt")
	cap:SetPoint("TOPLEFT", 14, -14)
	cap:SetText(L["Route"])
	title = Text(card, "body", 13, "questGold")
	title:SetPoint("TOPLEFT", 14, -36)
	title:SetSize(250, 18)
	distance = Text(card, "number", 13)
	distance:SetPoint("TOPLEFT", 14, -61)
	distance:SetSize(250, 18)
	note = Text(card, "body", 11, "text")
	note:SetPoint("TOPLEFT", 14, -85)
	note:SetSize(250, 18)
	note:SetText(L["Straight line - terrain may block the way."])
	chip = Text(card, "body", 11, "questGold")
	chip:SetPoint("TOPLEFT", 14, -118)
	chip:SetSize(282, 18)
	steps = CreateFrame("ScrollFrame", nil, card)
	steps:SetPoint("TOPLEFT", 14, -144)
	steps:SetSize(282, 158)
	stepChild = CreateFrame("Frame", nil, steps)
	stepChild:SetSize(282, 1)
	steps:SetScrollChild(stepChild)
	steps:SetVerticalScroll(0)
	steps:EnableMouseWheel(true)
	steps:SetScript("OnMouseWheel", function(self, delta)
		self:SetVerticalScroll(math.max(0, math.min(stepChild:GetHeight() - self:GetHeight(), self:GetVerticalScroll() - delta * 40)))
	end)
	clear = Widgets.Button(card, { width = 80, height = 24, text = L["Clear"], onClick = Routes.Clear })
	clear:SetPoint("BOTTOMRIGHT", -12, 10)
	panel:SetScript("OnHide", function() panel:SetScript("OnUpdate", nil) end)
	panel:SetScript("OnShow", RefreshRoute)
	Routes.panel, Routes.search, Routes.card, Routes.distance, Routes.note, Routes.chip, Routes.steps = panel, search, card, distance, note, chip, stepRows
end

local function RefreshZones()
	Hide(zones)
	local id = MapID()
	local info = id and Call(C_Map, "GetMapInfo", id)
	local continent = type(Enum) == "table" and type(Enum.UIMapType) == "table" and Enum.UIMapType.Continent
	if not On("zoneLevels") or not canvas or not continent or Field(info, "mapType", "number") ~= continent then return end
	local count = 0
	local zoneType = Enum.UIMapType.Zone
	if not Number(zoneType) then return end
	for _, child in ipairs(Plain(Call(C_Map, "GetMapChildrenInfo", id, zoneType), "table") or {}) do
		local childID = Field(child, "mapID", "number")
		local label = Routes.Levels(childID)
		if label then
			local left, right, top, bottom = Call(C_Map, "GetMapRectOnMap", childID, id)
			if Number(left) and Number(right) and Number(top) and Number(bottom) then
				count = count + 1
				local text = zones[count] or Text(canvas, "number", 12)
				zones[count] = text
				text:ClearAllPoints()
				text:SetPoint("CENTER", canvas, "TOPLEFT", (left + right) * 0.5 * canvas:GetWidth(), -(top + bottom) * 0.5 * canvas:GetHeight())
				text:SetText(label)
				text:Show()
			end
		end
	end
end

local function HookPins()
	if type(map.EnumeratePinsByTemplate) ~= "function" then return end
	for _, template in ipairs({ "DungeonEntrancePinTemplate", "FlightPointPinTemplate", "MapLinkPinTemplate" }) do
		for pin in map:EnumeratePinsByTemplate(template) do
			if not hooked[pin] then
				hooked[pin] = true
				if type(pin.OnMouseClickAction) == "function" then
					hooksecurefunc(pin, "OnMouseClickAction", function(self, button)
						if not On("routes") or Secret(button) or button ~= "LeftButton" then return end
						local info = type(self.GetPoiInfo) == "function" and self:GetPoiInfo()
						local x, y = XY(Field(info, "position", "table"))
						local list = {}
						Add(list, "pin", MapID(), Field(info, "name", "string"), x, y)
						ownsWaypoint, previousWaypoint, previousTrack = nil, nil, nil
						target = Plain(Call(C_SuperTrack, "IsSuperTrackingAnything"), "boolean") == true and list[1] or nil
						RefreshRoute()
					end)
				end
				if template == "DungeonEntrancePinTemplate" and type(pin.CheckShowTooltip) == "function" then
					hooksecurefunc(pin, "CheckShowTooltip", function(self)
						if not On("dungeonLevels") then return end
						local info = type(self.GetPoiInfo) == "function" and self:GetPoiInfo()
						local levels = Routes.DungeonLevels(info)
						local tooltip = type(GetAppropriateTooltip) == "function" and GetAppropriateTooltip()
						if levels and type(tooltip) == "table" and type(tooltip.AddLine) == "function" then
							tooltip:AddLine(levels)
							tooltip:Show()
						end
					end)
				end
			end
		end
	end
end

local function Refresh()
	if not map or type(map.GetMapID) ~= "function" or type(map.GetCanvas) ~= "function" then return end
	canvas = map:GetCanvas()
	if On("routes") then Build() end
	if panel then panel:SetShown(On("routes")) end
	if not On("routes") then Routes.Clear() end
	RefreshZones()
	HookPins()
	RefreshRoute()
end

local function EntranceFilter()
	if On("entrances") then
		if previousCVar ~= nil then return end
		previousCVar = Plain(Call(C_CVar, "GetCVar", CVAR), "string")
		if previousCVar and previousCVar ~= "1" then Call(C_CVar, "SetCVar", CVAR, "1") end
	elseif previousCVar then
		Call(C_CVar, "SetCVar", CVAR, previousCVar)
		previousCVar = nil
	end
end

local def = Skins.Get("worldMap")
def.defaults = def.defaults or {}
def.rows = def.rows or {}
for _, row in ipairs({
	{ "routes", L["Search and routes"], L["Search client destinations and show a route with estimated travel time."] },
	{ "followRoads", L["Follow roads"], L["Follow roads, flights and boats when connected; use a straight line otherwise."] },
	{ "dungeonLevels", L["Dungeon level ranges"], L["Show the client's level range in dungeon and raid entrance tooltips."] },
	{ "zoneLevels", L["Zone level ranges"], L["Show zone level ranges on continent maps."] },
	{ "entrances", L["Dungeon entrances"], L["Show Blizzard's dungeon and raid entrance pins on the map."] },
}) do
	def.defaults[row[1]] = true
	def.rows[#def.rows + 1] = { type = "toggle", key = row[1], label = row[2], help = row[3] }
end

local apply, setting, switch = def.Apply, def.OnSetting, def.OnSwitch
def.Apply = function(self)
	apply(self)
	map = WorldMapFrame
	if type(map.GetMapID) ~= "function" or type(map.GetCanvas) ~= "function" then return end
	active = true
	EntranceFilter()
	for _, method in ipairs({ "SetMapID", "RefreshAllDataProviders" }) do
		if type(map[method]) == "function" then hooksecurefunc(map, method, function() Refresh() end) end
	end
	if type(map.AcquirePin) == "function" then hooksecurefunc(map, "AcquirePin", HookPins) end
	map:HookScript("OnShow", Refresh)
	Refresh()
end
def.OnSetting = function(self, key, value)
	if setting then setting(self, key, value) end
	if key == "entrances" then EntranceFilter() end
	Refresh()
end
def.OnSwitch = function(self, on)
	if switch then switch(self, on) end
	active = on
	EntranceFilter()
	Refresh()
end
