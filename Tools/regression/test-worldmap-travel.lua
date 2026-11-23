-- test-worldmap-travel.lua: transports join the shipped continents, the tram and zeppelins are named, and hearth and teleports win only when faster.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M
local env, K, R, state = M.New()
Fixture.Install(env, state)
local Roads = env._addons.KstyleUI_Skins.WorldMapRoads
local world = assert(Roads.World())
assert(state.loads == 1 and type(env.KstyleUI_RouteData.overlays) == "function", "routes load once and keep the overlay data deferred")
local function Node(name)
	for _, node in ipairs(world.nodes) do if node.name == name then return node end end
	error("no shipped node " .. name)
end
for _, name in ipairs({ "Stormwind", "Ironforge", "The Undercity", "Darnassus", "Thunder Bluff", "Orgrimmar", "Nighthaven", "Dalaran" }) do Node(name) end
local function Trip(a, b)
	local route = assert(Roads.Solve(world, a.x, a.y, b.x, b.y, true, nil, { continent = a.map, target = b.map, options = {} }))
	local list = {}
	for _, leg in ipairs(route.legs) do if leg.kind ~= "walk" then list[#list + 1] = leg.kind .. ":" .. leg.to end end
	return table.concat(list, ","), route
end
local trip, route = Trip(Node("Orgrimmar"), Node("The Undercity"))
local zeppelin
for _, leg in ipairs(route.legs) do if leg.kind == "zeppelin" then zeppelin = leg end end
assert(trip == "zeppelin:Brill" and zeppelin.map == 0 and #zeppelin.pts == 2, "a flying transport is a zeppelin named after its tower's town, drawn only where it lands")
assert(Trip(Node("Ratchet"), Node("Booty Bay, Stranglethorn")) == "boat:Booty Bay", "boats cross between the continents by their shared dock ids")
trip, route = Trip(Node("Stormwind"), Node("Ironforge"))
local east = Roads.Graph(0)
local walking = Roads.Solve(east, Node("Stormwind").x, Node("Stormwind").y, Node("Ironforge").x, Node("Ironforge").y, true)
assert(trip:find("^tram:Ironforge") and route.seconds < walking.seconds - 300, "the Deeprun Tram beats the mountain road")
for _, leg in ipairs(walking.legs) do assert(leg.kind ~= "tram", "with travel stops off the tram stays out of the route") end

local loX, hiX, loY, hiY = -15000, 12000, -12000, 4000
local function Project(node) return (hiY - node.y) / (hiY - loY), (hiX - node.x) / (hiX - loX) end
env.C_Map.GetWorldPosFromMapPos = function(id, point)
	local x, y = point:GetXY()
	return id == 2 and 0 or 1, M.Vector(hiX - y * (hiX - loX), hiY - x * (hiY - loY))
end
env.C_Map.GetMapPosFromWorldPos = function(_, point, id)
	local x, y = point:GetXY()
	return id, M.Vector((hiY - y) / (hiY - loY), (hiX - x) / (hiX - loX))
end
local function Stand(name, map) state.playerMap = map; state.playerX, state.playerY = Project(Node(name)) end
local function Pick(name, map)
	local x, y = Project(Node(name))
	R.Clear()
	R.Pick({ mapID = map, name = name, x = x, y = y })
	local steps = {}
	for _, text in ipairs(R.steps) do if text:IsShown() then steps[#steps + 1] = text:GetText() end end
	return table.concat(steps, "|")
end
Stand("Orgrimmar", 1)
local steps = Pick("The Undercity", 2)
assert(R.road and steps:find("Zeppelin to Brill", 1, true), "the card names a cross-continent zeppelin in plain words")
K.Options.Write("Skins", "worldMap.travelStops", false)
assert(not R.road and R.note:GetText() == "Destination is on another continent.", "travel stops off restores the single-continent answer")
Stand("Stormwind", 2)
assert(not Pick("Ironforge", 2):find("Tram", 1, true), "travel stops off keeps the tram out")
K.Options.Write("Skins", "worldMap.travelStops", true)
assert(Pick("Ironforge", 2):find("Tram to Ironforge", 1, true), "travel stops on takes the tram")
Stand("Ironforge", 2)
local back = Pick("Stormwind", 2)
assert(back:find("Tram to Stormwind", 1, true), "the tram's Stormwind platform carries the city's name: " .. back)
local tram, ride = env.KstyleUI_RouteData.travel.tram
ride = math.sqrt((tram.pts[3] - tram.pts[1]) ^ 2 + (tram.pts[4] - tram.pts[2]) ^ 2)
for _, leg in ipairs(R.road.legs) do
	if leg.kind == "tram" then assert(leg.len - ride > 600 and math.abs(leg.seconds - tram.seconds - (leg.len - ride) / 7) < 1e-6, "the walk to and from the tram platforms costs walking time") end
end

local now, cooldown, known, usable = 1000, 0, {}, true
env.GetTime = function() return now end
env.GetBindLocation = function() return "Razor Hill" end
env.C_Item = { GetItemCount = function(id) return id == 6948 and 1 or 0 end, GetItemNameByID = function() return "Hearthstone" end,
	GetItemCooldown = function() return cooldown > 0 and now or 0, cooldown end }
env.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
env.C_Spell = { IsSpellUsable = function() return usable end, GetSpellCooldown = function() return { startTime = 0, duration = 0 } end,
	GetSpellInfo = function(id) return { name = id == 3567 and "Teleport: Orgrimmar" or "Astral Recall", castTime = 10000 } end }
Stand("The Undercity", 2)
steps = Pick("Razor Hill", 1)
assert(R.road.option and R.road.option.kind == "hearth" and steps:find("^1%. Hearthstone to Razor Hill"), "a ready hearthstone home is the plain first step")
local amount
for _, region in ipairs({ R.steps[1]:GetParent():GetRegions() }) do
	if region:GetObjectType() == "FontString" and region:IsShown() and region:GetText() == "About 1 min" then amount = true end
end
assert(amount, "a hearth step shows its time, not yards")
cooldown = 1800
steps = Pick("Razor Hill", 1)
assert(not R.road.option and steps:find("Zeppelin", 1, true), "a hearth on a long cooldown loses to the zeppelin")
local solves = 0
local solve = Roads.Solve
Roads.Solve = function(...) solves = solves + 1; return solve(...) end
local function Tick() R.panel:GetScript("OnUpdate")(R.panel, 0.25) end
Tick()
assert(solves == 0, "an unchanged stationary tick searches nothing")
cooldown = 0
Tick()
assert(R.road.option and R.road.option.kind == "hearth", "a hearthstone that becomes ready while the map stays open takes over the route")
local itemCooldown = env.C_Item.GetItemCooldown
env.C_Item.GetItemCooldown = function() return 1000, 120 end
Pick("Razor Hill", 1)
assert(R.road.option and R.road.option.seconds == 130, "a short cooldown is waited out")
now, solves = 1060, 0
Tick()
assert(solves == 1 and R.road.option.seconds == 70, "the hearth's remaining wait counts down on the card")
Tick()
assert(solves == 1, "the countdown searches once a minute, not every tick")
now, env.C_Item.GetItemCooldown = 1000, itemCooldown
cooldown = 60
assert(Pick("Razor Hill", 1):find("Hearthstone", 1, true), "waiting out a short cooldown still wins")
cooldown = 1800
known[3567] = true
assert(Pick("Orgrimmar", 1):find("^1%. Teleport: Orgrimmar"), "a known, ready teleport takes the player to its city")
usable = false
assert(not Pick("Orgrimmar", 1):find("Teleport", 1, true), "a teleport the player cannot cast is not offered")
local isUsable = env.C_Spell.IsSpellUsable
env.C_Spell.IsSpellUsable = nil
assert(not Pick("Orgrimmar", 1):find("Teleport", 1, true), "a teleport whose usability the client cannot confirm is not offered")
env.C_Spell.IsSpellUsable = isUsable
usable, known[3567], known[556] = true, nil, true
assert(Pick("Razor Hill", 1):find("^1%. Astral Recall to Razor Hill"), "Astral Recall goes to the bind point on its own cooldown")
env.GetBindLocation = function() return env.Secret("Razor Hill") end
local ok, err = pcall(Pick, "Razor Hill", 1)
assert(ok and not R.road.option, "a secret bind location offers no hearth or Astral Recall: " .. tostring(err))
cooldown, known[556] = 0, nil
env.C_Map.GetAreaInfo = function(id) return id == 362 and "Klingenhuegel" or "" end
env.GetBindLocation = function() return "Klingenhuegel" end
assert(Pick("Razor Hill", 1):find("^1%. Hearthstone to Klingenhuegel"), "a localized bind location finds its place through the client's area name")
env.GetBindLocation, known[556] = function() return "Razor Hill" end, true
Pick("Razor Hill", 1)
solves = 0
state.playerX = state.playerX + 0.00001
Tick()
assert(solves == 0 and R.road.option, "moving near the same start keeps a hearth route without another search")
Roads.Solve = solve
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map travel stops, transports, hearth and teleports ok")
