-- WorldMap.lua: the world map and quest log skins: the map window's chrome, whose glass docks the quest log beside the map, and the quest list and details on it.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local ADDON = "Blizzard_WorldMap"
local FRAME = "WorldMapFrame"
local BORDER_ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleContainer", "InsetBorderTop" }
local QUEST_POOLS = { "headerFramePool", "campaignHeaderFramePool", "campaignHeaderMinimalFramePool", "covenantCallingsHeaderFramePool" }
local DETAIL_BUTTONS = { "AbandonButton", "ShareButton", "TrackButton" }

local WEAK = { __mode = "k" }
local done = setmetatable({}, WEAK)
local navigation

local function Number(value)
	return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
		and value == value and value > -math.huge and value < math.huge
end

local function Has(object, ...)
	if type(object) ~= "table" then return false end
	for i = 1, select("#", ...) do
		if type(object[select(i, ...)]) ~= "function" then return false end
	end
	return true
end

local function NavigationOn(field)
	return navigation and navigation.on and Skins.Setting("worldMap", field) == true
end

local function ZoomMode()
	if not navigation then return end
	local scroll = navigation.scroll
	local smooth = NavigationOn("smoothZoom")
	local mode = smooth and MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_SMOOTH or MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL
	if Number(mode) and Has(scroll, "SetMouseWheelZoomMode", "SetShouldZoomInstantly") then
		scroll:SetMouseWheelZoomMode(mode)
		scroll:SetShouldZoomInstantly(not smooth)
	end
end

local function SaveZoom()
	if not NavigationOn("rememberZoom") then return end
	local scroll = navigation.scroll
	local id = scroll.mapID
	if not Number(id) or id ~= navigation.mapID then return end
	local scale, x, y = scroll.targetScale, scroll.targetScrollX, scroll.targetScrollY
	if not Number(scale) or not Number(x) or not Number(y) then return end
	local zooms = K.Store.Module("Skins").worldMap.zooms
	if type(zooms) ~= "table" then return end
	local saved = type(zooms[id]) == "table" and zooms[id] or {}
	zooms[id] = saved
	saved[1], saved[2], saved[3] = scale, x, y
end

local function RestoreZoom(scroll)
	navigation.mapID = scroll.mapID
	navigation.preloaded = nil
	if not NavigationOn("rememberZoom") or not Number(scroll.mapID)
		or not Has(scroll, "InstantPanAndZoom", "GetScaleForMinZoom", "GetScaleForMaxZoom") then return end
	local zooms = K.Store.Module("Skins").worldMap.zooms
	local saved = type(zooms) == "table" and zooms[scroll.mapID]
	local low, high = scroll:GetScaleForMinZoom(), scroll:GetScaleForMaxZoom()
	if type(saved) == "table" and Number(saved[1]) and Number(saved[2]) and Number(saved[3])
		and Number(low) and Number(high) then
		scroll:InstantPanAndZoom(math.max(low, math.min(high, saved[1])), saved[2], saved[3], true)
	end
end

local function Wheel(scroll, delta)
	SaveZoom()
	if not NavigationOn("wheelMaps") or not Number(delta) or delta == 0 then return end
	local map, api = navigation.map, C_Map
	local id = scroll.mapID
	if not Number(id) or not Has(api, "GetMapInfoAtPosition")
		or not Has(scroll, "GetNormalizedCursorPosition") then return end
	local x, y = scroll:GetNormalizedCursorPosition()
	local child
	if Number(x) and Number(y) then child = api.GetMapInfoAtPosition(id, x, y) end
	local childID = type(child) == "table" and child.mapID
	if Number(childID) and childID ~= id and childID ~= navigation.preloaded
		and Has(api, "RequestPreloadMap") then
		api.RequestPreloadMap(childID)
		navigation.preloaded = childID
	end
	if delta > 0 and navigation.atMax and Number(childID) and childID ~= id
		and Number(child.parentMapID) and child.parentMapID == id and Has(map, "SetMapID") then
		map:SetMapID(childID)
	elseif delta < 0 and navigation.atMin and Has(api, "GetMapInfo") and Has(map, "NavigateToParentMap") then
		local info = api.GetMapInfo(id)
		local parent = type(info) == "table" and info.parentMapID
		if not Number(parent) or parent <= 0 then return end
		local left, right, top, bottom
		if Has(api, "GetMapRectOnMap") then left, right, top, bottom = api.GetMapRectOnMap(id, parent) end
		map:NavigateToParentMap()
		if scroll.mapID ~= parent or not NavigationOn("smoothZoom")
			or not Has(scroll, "InstantPanAndZoom", "SetZoomTarget", "SetPanTarget", "GetScaleForMinZoom", "GetScaleForMaxZoom") then return end
		local low, high = scroll:GetScaleForMinZoom(), scroll:GetScaleForMaxZoom()
		if Number(left) and Number(right) and Number(top) and Number(bottom)
			and right > left and bottom > top and Number(low) and Number(high) then
			local scale = math.min(high, low / math.max(right - left, bottom - top))
			scroll:InstantPanAndZoom(scale, (left + right) / 2, (top + bottom) / 2, true)
			scroll:SetZoomTarget(low)
			scroll:SetPanTarget(.5, .5)
		end
	end
end

local function ApplyNavigation(map)
	local scroll = map.ScrollContainer
	if navigation or type(hooksecurefunc) ~= "function" or not Has(scroll, "ResetZoom") then return end
	navigation = { map = map, scroll = scroll, mapID = scroll.mapID, on = true }
	hooksecurefunc(scroll, "ResetZoom", RestoreZoom)
	if Has(scroll, "ShouldAdjustTargetPanOnMouseWheel", "GetCanvasScale", "GetScaleForMinZoom", "GetScaleForMaxZoom", "OnMouseWheel") then
		hooksecurefunc(scroll, "ShouldAdjustTargetPanOnMouseWheel", function()
			local scale = scroll:GetCanvasScale()
			navigation.atMin = Number(scale) and scale == scroll:GetScaleForMinZoom()
			navigation.atMax = Number(scale) and scale == scroll:GetScaleForMaxZoom()
		end)
		hooksecurefunc(scroll, "OnMouseWheel", Wheel)
	end
	for _, method in ipairs({ "OnUpdate", "OnMouseUp", "OnHide" }) do
		if Has(scroll, method) then hooksecurefunc(scroll, method, SaveZoom) end
	end
	ZoomMode()
	RestoreZoom(scroll)
end

local function Log(key, message)
	K.DevTest.Log("Skins", key .. ": " .. message)
end

local function ApplyMap()
	local map = _G[FRAME]
	ApplyNavigation(map)
	local border = map.BorderFrame
	Skin.Backdrop(map, { shape = "window", fill = "surface", shadow = true })
	Skin.OpenMotion(map)
	local title
	if type(border) == "table" then
		Skin.Strip(border, { children = BORDER_ART })
		Skin.CloseButton(border.CloseButton)
		title = type(border.TitleContainer) == "table" and border.TitleContainer.TitleText or nil
		if title then
			Style.Title(title)
			Parts.TitleCap(map, title, border.CloseButton)
		end
		local maxMin = border.MaximizeMinimizeFrame
		if type(maxMin) == "table" then
			Parts.Glyph(maxMin.MaximizeButton, "glyphChevron", { flip = true })
			Parts.Glyph(maxMin.MinimizeButton, "glyphChevron")
		end
	else
		Log("worldMap", "BorderFrame is missing; the map keeps Blizzard's frame")
	end
	local nav = map.NavBar
	if type(nav) == "table" then
		Skin.Strip(nav, { children = { "overlay" } })
		Skin.Backdrop(nav, { shape = "tile", fill = "surface", shadow = false })
	else
		Log("worldMap", "NavBar is missing; skipped")
	end
	local log = _G.QuestMapFrame
	if type(log) == "table" then
		Parts.Dock(map, { log }, { title = title })
	else
		Log("worldMap", "QuestMapFrame is missing; the map's glass stops at the map")
	end
end

local function QuestRow(row)
	if done[row] then
		return
	end
	done[row] = true
	local text = row.Text or row.ButtonText or row.Name
	if text then
		Style.Text(text, "body")
	end
end

local function QuestRows()
	local scroll = _G.QuestScrollFrame
	if type(scroll) ~= "table" then
		return
	end
	for _, key in ipairs(QUEST_POOLS) do
		local pool = scroll[key]
		if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
			for header in pool:EnumerateActive() do
				QuestRow(header)
			end
		end
	end
	local titles = scroll.titleFramePool
	if type(titles) == "table" and type(titles.EnumerateActive) == "function" then
		for title in titles:EnumerateActive() do
			QuestRow(title)
		end
	end
end

local function ApplyQuestLog()
	local log = _G.QuestMapFrame
	if type(log) ~= "table" then
		Log("questLog", "QuestMapFrame is missing; skipped")
		return
	end
	local quests = log.QuestsFrame
	if type(quests) == "table" then
		local scroll = quests.ScrollFrame
		if type(scroll) == "table" then
			Parts.Hush(scroll.Background)
			Parts.Hush(scroll.Edge)
			Skin.ScrollBar(scroll.ScrollBar)
			Skin.EditBox(scroll.SearchBox)
			if type(scroll.BorderFrame) == "table" then
				Skin.Strip(scroll.BorderFrame)
			end
			Skin.Backdrop(scroll, { shape = "tile", fill = "surface", shadow = false })
		end
		local details = quests.DetailsFrame
		if type(details) == "table" then
			if type(details.BorderFrame) == "table" then
				Skin.Strip(details.BorderFrame)
			end
			local back = type(details.BackFrame) == "table" and details.BackFrame
			if back then
				Skin.Strip(back)
				Skin.Button(back.BackButton)
			end
			for _, key in ipairs(DETAIL_BUTTONS) do
				if type(details[key]) == "table" then
					Skin.Button(details[key])
				end
			end
			if type(details.ScrollFrame) == "table" then
				Skin.ScrollBar(details.ScrollFrame.ScrollBar)
			end
		end
	end
	Skin.Strip(log)
	if type(QuestLogQuests_Update) == "function" then
		hooksecurefunc("QuestLogQuests_Update", QuestRows)
	else
		Log("questLog", "QuestLogQuests_Update is missing; quest rows keep Blizzard's font")
	end
	QuestRows()
end

Skins.Add({
	key = "worldMap",
	label = L["World map"],
	help = L["Restyles the world map's frame, title bar, buttons and navigation bar."],
	addon = ADDON,
	frame = FRAME,
	sweepSkip = { "ScrollContainer", "QuestLog.DetailsFrame" },
	metrics = true,
	defaults = { smoothZoom = true, rememberZoom = true, wheelMaps = true, zooms = {} },
	rows = {
		{ type = "toggle", key = "smoothZoom", label = L["Smooth zoom"], help = L["Ease mouse wheel zoom and pan. Off restores instant zoom in full steps."] },
		{ type = "toggle", key = "rememberZoom", label = L["Remember zoom"], help = L["Remember zoom and position for each map, including after a reload."] },
		{ type = "toggle", key = "wheelMaps", label = L["Wheel between maps"], help = L["Wheel out past a map's edge to its parent, or in over a zone to open it."] },
	},
	OnSetting = ZoomMode,
	OnSwitch = function(_, on)
		if navigation then navigation.on = on end
		ZoomMode()
	end,
	Apply = ApplyMap,
})

Skins.Add({
	key = "questLog",
	label = L["Quest log"],
	help = L["Restyles the quest list and quest details beside the world map."],
	frame = "QuestMapFrame",
	sweepSkip = { "DetailsFrame" },
	metrics = true,
	Apply = ApplyQuestLog,
})
