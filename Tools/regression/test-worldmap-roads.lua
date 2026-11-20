-- test-worldmap-roads.lua: time-weighted paths, directed flights, off-road legs and deferred data.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M
local env, K, R, state, map = M.New()
local Roads = env._addons.KstyleUI_Skins.WorldMapRoads
local graph = Fixture.Graph()
assert(env.KstyleUI_RouteData == nil and not graph.adj, "login and opening the map must not construct a road graph")
Fixture.Install(env, state, graph)
assert(not state.loads, "installing the client APIs does not load graph data")

local road = Roads.Solve(graph, 300, 700, 720, 360, false)
assert(road.yards == 1400 and road.seconds == 200 and #road.legs == 2, "follow the pass edges; never invent the straight mountain shortcut")
assert(road.legs[1].pts[3] == 200 and road.legs[2].to == "Crossroads", "preserve road polyline bends and junctions")
local mounted = Roads.Solve(graph, 300, 700, 720, 360, true)
assert(mounted.seconds == 100, "mounted roads use 14 yards per second")
local flights = { [1] = true, [3] = true }
local flight = Roads.Solve(graph, 300, 700, 720, 360, false, flights)
assert(#flight.legs == 1 and flight.legs[1].kind == "flight" and flight.seconds == 40 and flight.saved == 2, "choose a faster discovered flight and show whole-minute savings")
assert(Roads.Solve(graph, 300, 700, 720, 360, true, flights).saved == 1, "a flight saving exactly one minute qualifies")
graph.edges[3].seconds = 41
graph.adj = nil
assert(not Roads.Solve(graph, 300, 700, 720, 360, true, flights).saved, "a flight saving less than one minute has no savings chip")
graph.edges[3].seconds = 40
graph.adj = nil
local reverse = Roads.Solve(graph, 720, 360, 300, 700, false, flights)
assert(reverse.seconds == 200 and reverse.legs[1].kind == "walk", "flights remain directed while road polylines reverse")
assert(reverse.legs[1].pts[1] == 720 and reverse.legs[1].pts[3] == 500)
local snapped = Roads.Solve(graph, 240, 700, 720, 360, false)
assert(not snapped.dashed and not snapped.legs[1].dashed, "a connector of 60 yards snaps solidly")
snapped = Roads.Solve(graph, 239, 700, 800, 360, false)
assert(snapped.dashed and snapped.legs[1].dashed and snapped.legs[#snapped.legs].dashed, "connectors over 60 yards at either end are dashed")
local swim = Fixture.Graph()
swim.edges = { { a = 1, b = 3, kind = "swim", len = 470, pts = { 300, 700, 720, 360 } } }
assert(Roads.Solve(swim, 300, 700, 720, 360, true).seconds == 100, "swimming always uses 4.7 yards per second")
swim.edges[1].kind, swim.edges[1].seconds = "boat", 85
swim.adj = nil
assert(Roads.Solve(swim, 300, 700, 720, 360, false).seconds == 85, "boat costs include the shipped travel/wait estimate")
swim.edges[1].kind, swim.edges[1].seconds, swim.edges[1].pts = "lift", 35, { 300, 700, 0, 720, 360, 100 }
swim.adj = nil
local lift = Roads.Solve(swim, 300, 700, 720, 360, false)
assert(lift.seconds == 35 and #lift.legs[1].pts == 4 and lift.legs[1].pts[3] == 720, "lift height is not a map coordinate")

R.Pick({ mapID = 1, name = "Crossroads", x = 0.72, y = 0.36 })
assert(state.loads == 1 and state.constructs == 1 and R.road, "the first route loads and constructs its continent once")
assert(R.road.seconds == 200 and R.steps[1]:GetText():find("Road to Crossroads", 1, true), "road steps combine bends into a readable destination")
local diamond
for _, region in ipairs({ map:GetCanvas():GetRegions() }) do
	if region:IsShown() and region:GetWidth() == 5 then diamond = region end
end
assert(diamond, "draw diamond junction markers")
local oldX = select(4, diamond:GetPoint(1))
map:SetWidth(1000)
R.panel:GetScript("OnUpdate")(R.panel, 0.25)
assert(select(4, diamond:GetPoint(1)) ~= oldX, "maximizing or resizing redraws a stationary route at the new canvas size")
state.playerX = 0.2
R.panel:GetScript("OnUpdate")(R.panel, 0.25)
assert(state.loads == 1 and state.constructs == 1 and R.note:GetText() == "The ground may block this.", "moving off-road reuses the graph and labels the dashed connector")
K.Options.Write("Skins", "worldMap.followRoads", false)
assert(not R.road and R.note:GetText():find("Straight line", 1, true), "toggle off restores batch two's direct route")
K.Options.Write("Skins", "worldMap.followRoads", true)
assert(R.road and state.loads == 1)
state.playerX = 0.3
env.C_TaxiMap.GetTaxiNodesForMap = function()
	return {
		{ name = "Razor Hill", isUndiscovered = false, faction = 1 },
		{ name = "Crossroads", isUndiscovered = false, faction = 1 },
	}
end
R.Clear()
R.Pick({ mapID = 1, name = "Crossroads", x = 0.72, y = 0.36 })
assert(R.road.seconds == 40 and R.chip:GetText() == "Flight path saves 2 min", "only discovered compatible flights appear in the card")
env.C_TaxiMap.GetTaxiNodesForMap = function()
	return { { name = "Localized start", position = M.Vector(0.3, 0.7), isUndiscovered = false, faction = 1 },
		{ name = "Localized goal", position = M.Vector(0.72, 0.36), isUndiscovered = false, faction = 1 } }
end
R.Clear(); R.Pick({ mapID = 1, name = "Crossroads", x = 0.72, y = 0.36 })
assert(R.road.seconds == 40, "localized taxi names match the graph by world position")
map:SetMapID(3)
local visible
for _, region in ipairs({ map:GetCanvas():GetRegions() }) do if region:IsShown() and region:GetWidth() == 5 then visible = true end end
assert(R.road and visible, "project the route onto the current map even when it is not the destination map")
map:SetMapID(1)
env.C_TaxiMap.GetTaxiNodesForMap = function() return { { name = "Razor Hill", isUndiscovered = false, faction = 1 }, { name = "Crossroads", isUndiscovered = true, faction = 1 } } end
R.Clear(); R.Pick({ mapID = 1, name = "Crossroads", x = 0.72, y = 0.36 })
assert(R.road.seconds == 200, "undiscovered flight endpoints are excluded")
env.C_TaxiMap.GetTaxiNodesForMap = function() return { { name = "Razor Hill", isUndiscovered = false, faction = 2 }, { name = "Crossroads", isUndiscovered = false, faction = 2 } } end
R.Clear(); R.Pick({ mapID = 1, name = "Crossroads", x = 0.72, y = 0.36 })
assert(R.road.seconds == 200, "enemy flight endpoints are excluded")
env.SetCombat(true)
R.Pick({ mapID = 2, name = "Other continent", x = 0.72, y = 0.36 })
assert(state.id == 1 and not R.road and R.note:GetText() == "Destination is on another continent.", "combat cross-continent fallback explains the missing road without SetMapID")
env.SetCombat(false)
graph.adj, graph.edges = nil, {}
R.Clear(); R.Pick({ mapID = 1, name = "Disconnected", x = 0.72, y = 0.36 })
assert(not R.road and R.note:GetText() == "No connected road route.", "disconnected graph falls back honestly")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

env, K, R, state = M.New()
Fixture.Install(env, state)
Roads = env._addons.KstyleUI_Skins.WorldMapRoads
local real = assert(Roads.Graph(1))
assert(type(env.KstyleUI_RouteData[0]) == "function" and env.KstyleUI_RouteData[1] == nil, "the other continent remains a constructor until requested")
assert(Roads.Graph(1) == real and state.loads == 1, "real graph loads only once")
assert(Roads.Graph(0).map == 0 and state.loads == 1, "the second continent constructs on its own first request")
assert(K.ErrorCount() == 0 and not R.road)
print("world map roads, travel, snapping and lazy loading ok")
