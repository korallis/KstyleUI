-- worldmap_env.lua: Forever client destination fixtures shared by map behaviour tests and the render harness.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S
local M = { S = S, Windows = Windows }

function M.Vector(x, y)
	return { GetXY = function() return x, y end }
end

function M.Setup(env, map)
	local state = { id = 1, cvar = "0", mounted = false, tracked = false, levels = { 13, 18 }, queries = {} }
	local function Place(name, x, y, extra)
		extra = extra or {}
		extra.name, extra.position = name, M.Vector(x, y)
		return extra
	end

	map.ScrollContainer.Child = env.CreateFrame("Frame", nil, map.ScrollContainer)
	map.ScrollContainer.Child:SetAllPoints(map.ScrollContainer)
	function map:GetMapID() return state.id end
	function map:SetMapID(id) state.id = id end
	function map:GetCanvas() return self.ScrollContainer.Child end
	function map:RefreshAllDataProviders() state.refreshes = (state.refreshes or 0) + 1 end
	local dungeon = Place("Ragefire Chasm", 0.72, 0.36, { journalInstanceID = 42 })
	local flight = Place("Razor Hill flight master", 0.35, 0.55)
	local link = Place("Road to the Barrens", 0.14, 0.65)
	state.dungeon, state.flight, state.link = dungeon, flight, link
	state.pins = {}
	for _, pair in ipairs({ { "DungeonEntrancePinTemplate", dungeon }, { "FlightPointPinTemplate", flight }, { "MapLinkPinTemplate", link } }) do
		local pin = env.CreateFrame("Button", nil, map:GetCanvas())
		pin:SetSize(24, 24)
		pin:SetPoint("CENTER", map:GetCanvas(), "TOPLEFT", pair[2].position:GetXY())
		function pin:GetPoiInfo() return self._info end
		pin._info = pair[2]
		function pin:OnMouseClickAction() state.nativeClicks = (state.nativeClicks or 0) + 1 end
		function pin:CheckShowTooltip() state.tooltip = {} end
		state.pins[pair[1]] = pin
	end
	function map:EnumeratePinsByTemplate(template)
		local pin = state.pins[template]
		return function() local nextPin = pin; pin = nil; return nextPin end
	end
	env.GetAppropriateTooltip = function()
		return { AddLine = function(_, text) state.tooltip[#state.tooltip + 1] = text end, Show = function() end }
	end
	env.Enum = env.Enum or {}
	env.Enum.UIMapType = { Continent = 2, Zone = 3 }
	env.C_Map = {
		GetMapInfo = function() return { mapType = 2 } end,
		GetMapChildrenInfo = function() return { { mapID = 2, name = "Durotar" } } end,
		GetMapRectOnMap = function() return 0.2, 0.4, 0.4, 0.6 end,
		GetMapLevels = function(id) state.queries[#state.queries + 1] = id; return unpack(state.levels) end,
		GetMapLinksForMap = function() return { link } end,
		GetPlayerMapPosition = function() return M.Vector(0.3, 0.7) end,
		GetMapWorldSize = function() return 4000, 3000 end,
		CanSetUserWaypointOnMap = function() return true end,
		GetUserWaypoint = function() return state.waypoint end,
		SetUserWaypoint = function(point) state.waypoint = point; return true end,
		ClearUserWaypoint = function() state.waypoint = nil end,
	}
	env.C_TaxiMap = { GetTaxiNodesForMap = function() return { flight } end }
	env.C_EncounterJournal = { GetDungeonEntrancesForMap = function() return { dungeon } end }
	env.EJ_GetInstanceInfo = function(id) assert(id == 42); return "Ragefire Chasm", nil, nil, nil, nil, nil, 389 end
	env.C_AreaPoiInfo = {
		GetAreaPOIForMap = function() return { 100 } end,
		GetAreaPOIInfo = function() return Place("Skull Rock", 0.54, 0.4) end,
	}
	env.C_QuestLog = env.C_QuestLog or {}
	env.C_QuestLog.GetNumQuestWatches = function() return 2 end
	env.C_QuestLog.GetQuestIDForQuestWatchIndex = function(i) return i + 9 end
	env.C_QuestLog.GetQuestWatchType = function(id) return id ~= 12 and 1 or nil end
	env.C_QuestLog.GetQuestsOnMap = function()
		return { { questID = 10, mapID = 1, x = 0.5, y = 0.5 }, { questID = 12, mapID = 1, x = 0.8, y = 0.8 } }
	end
	env.C_QuestLog.GetTitleForQuestID = function(id) return ({ [10] = "The Lost Patrol", [11] = "Thunder Ridge Harpies", [12] = "Untracked quest" })[id] end
	env.C_QuestLog.GetNextWaypoint = function(id) if id == 11 then return 1, 0.65, 0.3 end end
	env.C_VignetteInfo = {
		GetVignettes = function() return { "live", "hidden" } end,
		GetVignetteInfo = function(guid) return { name = "Lost treasure", onWorldMap = guid == "live" } end,
		GetVignettePosition = function() return M.Vector(0.6, 0.4) end,
	}
	env.UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { uiMapID = id, position = M.Vector(x, y) } end }
	env.C_SuperTrack = env.C_SuperTrack or {}
	env.C_SuperTrack.SetSuperTrackedUserWaypoint = function(on) state.tracked = on end
	env.C_SuperTrack.IsSuperTrackingUserWaypoint = function() return state.tracked end
	env.C_CVar = { GetCVar = function() return state.cvar end, SetCVar = function(_, value) state.cvar = value end }
	env.IsMounted = function() return state.mounted end
	return state
end

function M.New()
	local map, state
	local env, K, ns = S.New({ before = function(e)
		map = Windows.Build("worldmap", e, S.Blizzard(e))
		state = M.Setup(e, map)
	end })
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_WorldMap")
	S.Show(map)
	return env, K, ns.WorldMapRoutes, state, map
end

return M
