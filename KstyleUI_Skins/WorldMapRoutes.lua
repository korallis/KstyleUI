-- WorldMapRoutes.lua: client destinations, optional level ranges and straight-line routes beside the world map.
local _, ns = ...

local K = KstyleUI
local Widgets, L = K.Widgets, K.L
local Skins, Style, Lumen = ns.Skins, ns.Style, ns.Lumen
local Routes = {}
ns.WorldMapRoutes = Routes

local map, panel, search, card, title, distance, note, clear
local active, previousCVar, previousWaypoint, previousTrack, ownsWaypoint
local target, canvas, elapsed = nil, nil, 0
local routeX, routeY, routeMap, routeTarget
local results, dots, zones = {}, {}, {}
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
	query = query:lower()
	for _, row in ipairs(list) do
		if row.name:lower():find(query, 1, true) then found[#found + 1] = row end
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

local function DrawRoute(x, y, tx, ty)
	Hide(dots)
	if not canvas or not x then return end
	local width, height = Number(canvas:GetWidth()), Number(canvas:GetHeight())
	if not width or not height or width <= 0 or height <= 0 then return end
	local dx, dy = (tx - x) * width, (ty - y) * height
	local steps = math.min(160, math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 6)))
	for i = 1, steps + 1 do
		local dot = dots[i]
		if not dot then
			dot = canvas:CreateTexture(nil, "OVERLAY")
			dots[i] = dot
		end
		dot:SetColorTexture(K.Theme.Accent())
		dot:SetSize(2, 2)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", canvas, "TOPLEFT", x * width + dx * (i - 1) / steps, -y * height - dy * (i - 1) / steps)
		dot:Show()
	end
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
	local x, y
	local id = MapID()
	if id == target.mapID then x, y = XY(Call(C_Map, "GetPlayerMapPosition", target.mapID, "player")) end
	if x ~= routeX or y ~= routeY or id ~= routeMap or target ~= routeTarget then
		DrawRoute(x, y, target.x, target.y)
		routeX, routeY, routeMap, routeTarget = x, y, id, target
	end
	if x then
		local width, height = Call(C_Map, "GetMapWorldSize", target.mapID)
		local mounted = type(IsMounted) == "function" and Plain(IsMounted(), "boolean") or false
		local yards, minutes = Routes.Measure(x, y, target.x, target.y, width, height, mounted)
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
	local combat = type(InCombatLockdown) ~= "function" or Plain(InCombatLockdown(), "boolean") ~= false
	if not combat and type(map.SetMapID) == "function" and MapID() ~= row.mapID then map:SetMapID(row.mapID) end
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
	clear = Widgets.Button(card, { width = 80, height = 24, text = L["Clear"], onClick = Routes.Clear })
	clear:SetPoint("BOTTOMRIGHT", -12, 10)
	panel:SetScript("OnHide", function() panel:SetScript("OnUpdate", nil) end)
	panel:SetScript("OnShow", RefreshRoute)
	Routes.panel, Routes.search, Routes.card, Routes.distance = panel, search, card, distance
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
	{ "routes", L["Search and routes"], L["Search client destinations and show a straight route with estimated walking time."] },
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
