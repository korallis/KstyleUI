-- test-worldmap-routes.lua: client search sources, EJ levels, waypoint ownership, route maths and live map options.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, state, map = M.New()

assert(state.cvar == "1", "entrance filter defaults on")
state.cvar = "0"
map:SetMapID(2)
assert(state.id == 2, "the hooked map switch still runs Blizzard's method")
map:SetMapID(1)
map:RefreshAllDataProviders()
assert(state.refreshes == 1, "the hooked data refresh still runs Blizzard's method")
assert(state.cvar == "0" and state.cvarWrites == 1, "map refresh must leave Blizzard's entrance filter alone")
assert(R.DungeonLevels(state.dungeon) == "Level 13-18")
assert(state.queries[#state.queries] == 389, "EJ seventh return is the map passed to GetMapLevels")
state.levels = { 0, 0 }
assert(R.DungeonLevels(state.dungeon) == nil, "unknown levels stay blank")
state.levels = { 13, 18 }
local sources = { flight = "flight master", dungeon = "Chasm", link = "Barrens", poi = "Skull", quest = "Patrol", vignette = "treasure" }
for kind, query in pairs(sources) do
	local rows = R.Search(query)
	assert(#rows == 1 and rows[1].kind == kind, "search source " .. kind)
end
assert(#R.Search("Harpies") == 1, "watched quest absent from GetQuestsOnMap uses GetNextWaypoint")
assert(#R.Search("Untracked") == 0, "unwatched quests are excluded")
assert(#R.Search("[literal pattern") == 0, "search is literal")
local taxiNodes = env.C_TaxiMap.GetTaxiNodesForMap
env.C_TaxiMap.GetTaxiNodesForMap = function()
	return {
		{ name = "Enemy flight", position = M.Vector(0.2, 0.3), faction = 2 },
		{ name = "Neutral flight", position = M.Vector(0.2, 0.3), faction = 0 },
		state.flight,
	}
end
assert(#R.Search("flight") == 2 and #R.Search("Enemy") == 0, "apply Blizzard's flight faction filter")
env.C_TaxiMap.ShouldMapShowTaxiNodes = function() return false end
assert(#R.Search("flight") == 0, "hide taxi nodes on maps Blizzard excludes")
env.C_TaxiMap.ShouldMapShowTaxiNodes = nil
assert(#R.Search("flight") == 0, "missing taxi visibility API degrades silently")
env.C_TaxiMap.ShouldMapShowTaxiNodes = function() return true end
env.C_TaxiMap.GetTaxiNodesForMap = taxiNodes
R.search:SetText("Ragefire")
R.search:GetScript("OnTextChanged")(R.search, true)
local result
for _, frame in ipairs({ R.panel:GetChildren() }) do
	if frame:GetObjectType() == "Button" and frame.Text and frame.Text:GetText() == "Ragefire Chasm" then result = frame end
end
assert(result and result:IsShown(), "typing builds a selectable search result")
assert(result.Text:GetJustifyH() == "LEFT" and result.Text:GetFont() == K.Tokens.Font("body"), "search list uses the quest rows' body face and left alignment")
local highlight
for _, region in ipairs({ result:GetRegions() }) do
	if region:GetObjectType() == "Texture" and region:GetAtlas() == "questlog-quest-glow-yellow" then highlight = region end
end
assert(highlight and not highlight:IsShown(), "search row uses the native quest list highlight")
result:GetScript("OnEnter")(result)
assert(highlight:IsShown())
result:GetScript("OnLeave")(result)
assert(not highlight:IsShown())
result:GetScript("OnClick")(result)
assert(R.card:IsShown() and not result:IsShown(), "picking the visible result opens its route and closes results")
R.Clear()

local yards, minutes = R.Measure(0, 0, 0.3, 0.4, 1000, 1000, false)
assert(yards == 500 and math.abs(minutes - 500 / 420) < 0.000001)
local _, mountedMinutes = R.Measure(0, 0, 0.3, 0.4, 1000, 1000, true)
assert(mountedMinutes == minutes / 2)
assert(R.Measure(0, 0, 1, 1, nil, 1000) == nil, "unavailable map size is safe")
assert(R.Measure(0, 0, 1, 1, 0 / 0, 1000) == nil, "NaN size is safe")

local native = state.pins.DungeonEntrancePinTemplate
native:CheckShowTooltip()
assert(state.tooltip[1] == "Level 13-18")
K.Options.Write("Skins", "worldMap.dungeonLevels", false)
native:CheckShowTooltip()
assert(#state.tooltip == 0, "tooltip off preserves Blizzard's tooltip")
K.Options.Write("Skins", "worldMap.dungeonLevels", true)
state.levels = { 0, 0 }
native:CheckShowTooltip()
assert(#state.tooltip == 0)
state.levels = { 13, 18 }

local old = env.UiMapPoint.CreateFromCoordinates(1, 0.1, 0.2)
state.waypoint = old
env.SetCombat(true)
native:OnMouseClickAction("LeftButton")
assert(state.nativeClicks == 1, "Blizzard click still runs in combat")
assert(state.waypoint == old and not state.tracked and state.nativeTracked == native and R.card:IsShown(), "pin route preserves native tracking without a duplicate waypoint")
assert(R.distance:GetText():find("about", 1, true))
native:OnMouseClickAction("LeftButton")
assert(not state.nativeTracked and not state.tracked and not R.card:IsShown(), "second pin click untracks and clears our route")
native:OnMouseClickAction("RightButton")
assert(not R.card:IsShown(), "right click does not pick a route")
local acquired = map:AcquirePin("DungeonEntrancePinTemplate", state.dungeon)
acquired:OnMouseClickAction("LeftButton")
assert(state.nativeTracked == acquired and R.card:IsShown(), "pins acquired by a provider event get route hooks immediately")
R.Clear()
assert(state.waypoint == old and not state.tracked and not R.card:IsShown(), "clear restores the prior Blizzard waypoint")
R.Pick(R.Search("Chasm")[1])
local dot
for _, region in ipairs({ map:GetCanvas():GetRegions() }) do
	if region:GetObjectType() == "Texture" and region:IsShown() then dot = region; break end
end
assert(dot, "route draws dots")
local points, setPoint = 0, dot.SetPoint
dot.SetPoint = function(self, ...) points = points + 1; return setPoint(self, ...) end
local tick = R.panel:GetScript("OnUpdate")
tick(R.panel, 0.25)
tick(R.panel, 0.25)
assert(points == 0, "stationary OnUpdate must not redraw route textures")
state.playerX = 0.31
tick(R.panel, 0.25)
assert(points == 1, "moving player redraws the route")
env.SetCombat(false)
map:SetMapID(2)
assert(not dot:IsShown(), "changing map clears the old route line")
map:SetMapID(1)
assert(dot:IsShown(), "returning to the route map redraws while stationary")
R.Clear()
env.SetCombat(true)
env.C_QuestLog.GetNextWaypoint = function(id) if id == 11 then return 2, 0.65, 0.3 end end
local crossMap = R.Search("Harpies")[1]
R.Pick(crossMap)
assert(state.id == 1 and state.waypoint.uiMapID == 2 and state.tracked, "combat selection sets the waypoint without changing Blizzard's map")
assert(R.card:IsShown() and R.distance:GetText() == "Distance unavailable", "another map has no line or distance on the current canvas")
env.SetCombat(false)
R.Pick(crossMap)
assert(state.id == 2, "out of combat selection may navigate to the destination map")
R.Clear()
map:SetMapID(1)

local zone
for _, region in ipairs({ map:GetCanvas():GetRegions() }) do
	if region:GetObjectType() == "FontString" and region:GetText() == "Level 13-18" then zone = region end
end
assert(zone and zone:IsShown(), "continent shows child zone level ranges")
K.Options.Write("Skins", "worldMap.zoneLevels", false)
assert(not zone:IsShown(), "zone toggle removes its labels")
K.Options.Write("Skins", "worldMap.entrances", false)
assert(state.cvar == "0", "entrance filter off hides native entrances")
assert(#R.Search("Chasm") == 1, "search also finds filtered destinations")
R.Pick(R.Search("Chasm")[1])
K.Options.Write("Skins", "worldMap.routes", false)
assert(not R.card:IsShown() and not R.panel:IsShown() and state.waypoint == old)
K.Options.Write("Skins", "worldMap.routes", true)
K.Options.Write("Skins", "worldMap.entrances", true)
K.Modules.Disable("Skins")
assert(state.cvar == "0" and not zone:IsShown() and not R.panel:IsShown(), "module off restores Blizzard")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

env, _, R, state = M.New()
for _, api in ipairs({ "C_TaxiMap", "C_EncounterJournal", "C_AreaPoiInfo", "C_VignetteInfo", "C_QuestLog", "C_Map" }) do
	env[api] = nil
	assert(type(R.Search("a")) == "table", "missing " .. api .. " degrades silently")
end
assert(R.DungeonLevels(state.dungeon) == nil)
R.Pick({ name = "Missing", mapID = 1, x = 0.5, y = 0.5 })
assert(not state.waypoint and not state.tracked and not R.card:IsShown(), "missing waypoint API must not change tracking or open a route")

env, _, R, state = M.New()
R.Pick(R.Search("Chasm")[1])
local external = env.UiMapPoint.CreateFromCoordinates(1, 0.9, 0.9)
state.waypoint = external
R.Clear()
assert(state.waypoint == external, "clear leaves a waypoint another addon or the player set afterward")
K = env.KstyleUI
K.Options.Write("Skins", "worldMap.entrances", false)
state.cvar = "1"
K.Options.Write("Skins", "worldMap.entrances", true)
K.Options.Write("Skins", "worldMap.entrances", false)
assert(state.cvar == "1", "turning entrances off restores a previously enabled Blizzard filter")
local saved = env.C_Map.GetMapLevels
env.C_Map.GetMapLevels = function() return env.Secret(13), env.Secret(18) end
assert(R.DungeonLevels(state.dungeon) == nil, "secret levels stay blank")
env.C_Map.GetMapLevels = saved
env.C_TaxiMap.GetTaxiNodesForMap = function() return { { name = env.Secret("secret"), position = M.Vector(0.2, 0.3) } } end
assert(#R.Search("secret") == 0, "secret destination names are ignored")
env.EJ_GetInstanceInfo = nil
assert(R.DungeonLevels(state.dungeon) == nil, "missing EJ degrades silently")
print("world map destinations, ranges, routes and toggles ok")
