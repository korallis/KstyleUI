-- test-worldmap-services.lua: the service recorder, map pins, the nearest picker on the road graph and click-a-quest routes.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M

local function Boot(hidden, graph)
	local env, K, R, state, map = M.New(hidden)
	Fixture.Install(env, state, graph or Fixture.Graph())
	env.C_Map.GetMapInfo = function() return { mapType = 3 } end
	env.Enum.PlayerInteractionType = { Merchant = 5, Trainer = 7, Banker = 8, Binder = 20, Auctioneer = 21, CharacterBanker = 67, AccountBanker = 68 }
	env.Enum.ItemClass = { Reagent = 5 }
	local npc = {}
	env.UnitName = function(unit) if unit == "npc" then return npc.name end end
	env.UnitGUID = function(unit) if unit == "npc" and npc.id then return "Creature-0-1-2-3-" .. npc.id .. "-00001" end end
	env.CanMerchantRepair = function() return npc.repair == true end
	env.GetMerchantNumItems = function() return #(npc.items or {}) end
	env.GetMerchantItemID = function(i) return npc.items[i] end
	env.C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", 0, id == 17030 and 5 or 0, 0 end }
	env.C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function(kind) return npc.binder == true and kind == 20 end }
	return env, K, R, state, map, npc, env._addons.KstyleUI_Skins.WorldMapServices
end

local env, K, R, state, map, npc, Services = Boot()
local function Visit(name, id, x, y, event, payload, extra)
	npc.name, npc.id, npc.repair, npc.items, npc.binder = name, id, nil, nil, nil
	state.playerX, state.playerY = x / 1000, y / 1000
	for k, v in pairs(extra or {}) do npc[k] = v end
	env.FireEvent(event, payload)
end
local function Saved(kind) return (K.Store.Account().mapServices or {})[kind] or {} end
local function Count(list) local n = 0; for _ in pairs(list) do n = n + 1 end; return n end
local function Shown() local n = 0; for _, pin in ipairs(Services.pins) do if pin:IsShown() then n = n + 1 end end; return n end
local function Results()
	local n = 0
	for _, frame in ipairs({ R.panel:GetChildren() }) do
		if frame:GetObjectType() == "Button" and frame:IsShown() then n = n + 1 end
	end
	return n
end

local rows = R.Search("")
assert(#rows == 6 and rows[1].nearest == "inn" and rows[6].nearest == "reagent", "an empty search lists the six nearest pickers")
R.search:SetText("")
R.search:GetScript("OnEditFocusGained")(R.search)
local listed = {}
for _, frame in ipairs({ R.panel:GetChildren() }) do
	if frame:GetObjectType() == "Button" and frame:IsShown() then listed[#listed + 1] = frame end
end
assert(#listed == 6 and listed[1].Text:GetText() == "Nearest innkeeper", "focusing the empty search opens the nearest picker")
listed[1]:GetScript("OnClick")(listed[1])
assert(not listed[1]:IsShown(), "picking a nearest row closes the list")
R.Clear()
R.Pick(rows[1])
assert(R.card:IsShown() and R.note:GetText():find("None recorded", 1, true) and not state.waypoint, "an unknown service says so and sets no waypoint")
R.Clear()

Visit("Innkeeper Grosk", 6928, 650, 450, "GOSSIP_SHOW", nil, { binder = true })
local inn = Saved("inn")["6928"]
assert(inn and inn.name == "Innkeeper Grosk" and inn.map == 1 and inn.continent == 1 and inn.wx == 650 and inn.wy == 450, "talking to an innkeeper records it")
Visit("Innkeeper Kauth", 6747, 300, 260, "CONFIRM_BINDER")
assert(Saved("inn")["6747"], "choosing to bind records the innkeeper")
Visit("Gennia", 3000, 300, 300, "GOSSIP_SHOW")
assert(Count(Saved("inn")) == 2, "an NPC without the binder interaction is not an innkeeper")
Visit("Shadowmage", 3328, 310, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
Visit("Bank of Orgrimmar", 3309, 320, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
Visit("Auctioneer", 9856, 330, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 21)
Visit("Smith", 3356, 340, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5, { repair = true, items = { 1, 17030 } })
Visit("Grocer", 3312, 350, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5, { items = { 1, 2 } })
assert(Saved("trainer")["3328"] and Saved("bank")["3309"] and Saved("auction")["9856"], "trainer, bank and auction windows record their NPC")
assert(Saved("repair")["3356"] and Saved("reagent")["3356"] and Count(Saved("repair")) == 1 and Count(Saved("reagent")) == 1,
	"a merchant counts as repair or reagent only when the client says it repairs or sells reagent-class items")
Visit(env.Secret("Hidden"), 1, 360, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
Visit("Nowhere", 2, 370, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", env.Secret(7))
assert(Count(Saved("trainer")) == 1, "secret names and payloads are ignored")
local position = env.C_Map.GetPlayerMapPosition
env.C_Map.GetPlayerMapPosition = function() end
Visit("Lost", 3, 0, 0, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(Count(Saved("trainer")) == 1, "no player position, no record")
assert(R.Pick({ nearest = "inn" }) == nil and R.note:GetText() == "Your position is unavailable here.", "nearest without a position says so")
env.C_Map.GetPlayerMapPosition = position
R.Clear()

assert(Shown() == 6, "one pin for each recorded NPC on this zone, got " .. Shown())
local smith
for _, each in ipairs(Services.pins) do
	if each:IsShown() and each.row.name == "Smith" then
		assert(not smith, "a merchant that repairs and sells reagents has one pin")
		smith = each
	end
end
local tip, lines = K.Widgets.Tooltip(), {}
local addLine = tip.AddLine
tip.AddLine = function(self, text, ...) lines[#lines + 1] = text; return addLine(self, text, ...) end
smith:GetScript("OnEnter")(smith)
tip.AddLine = addLine
assert(lines[1] == "Repair vendor" and lines[2] == "Reagent vendor", "its tooltip lists both services")
local pin = Services.pins[1]
pin:GetScript("OnClick")(pin)
assert(R.card:IsShown() and state.waypoint and state.waypoint.uiMapID == 1, "clicking a pin routes to it")
R.Clear()
function map:OnCanvasScaleChanged() state.scaled = (state.scaled or 0) + 1 end
map:SetMapID(1)
map:SetMapID(1)
local moves, setPoint = 0, pin.SetPoint
pin.SetPoint = function(self, ...) moves = moves + 1; return setPoint(self, ...) end
local project, projections = env.C_Map.GetMapPosFromWorldPos, 0
env.C_Map.GetMapPosFromWorldPos = function(...) projections = projections + 1; return project(...) end
for _ = 1, 20 do map:OnCanvasScaleChanged() end
assert(state.scaled == 20 and moves == 20 and projections == 0, "zoom frames move the pins through one hook without reprojecting them")
map:Hide()
Visit("Shadowmage", 3328, 312, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(projections == 0, "a visit behind the closed map draws nothing until the map opens")
M.S.Show(map)
assert(projections > 0 and Shown() == 6 and Count(Saved("trainer")) == 1, "opening the map draws the visit, which updated the same trainer")
env.C_Map.GetMapPosFromWorldPos = project
env.C_Map.GetMapInfo = function() return { mapType = 2 } end
map:SetMapID(1)
assert(Shown() == 0, "continent maps stay clear of service pins")
env.C_Map.GetMapInfo = function() return { mapType = 3 } end
map:SetMapID(1)

local found = R.Search("Grosk")
assert(#found == 1 and found[1].kind == "service" and found[1].name == "Innkeeper Grosk", "search finds recorded services by name")
found = R.Search("inn")
assert(found[1].nearest == "inn" and found[1].name == "Nearest innkeeper", "typing a service puts its nearest picker first")

state.playerX, state.playerY = 0.3, 0.7
assert(R.Pick({ nearest = "inn" }) == true and R.road and R.card:IsShown(), "nearest routes on the road graph")
assert(state.waypoint.position:GetXY() == 0.3 and select(2, state.waypoint.position:GetXY()) == 0.26, "by road the pass innkeeper is nearer than the straight-line one")
R.Clear()
K.Options.Write("Skins", "worldMap.followRoads", false)
R.Pick({ nearest = "inn" })
assert(state.waypoint.position:GetXY() == 0.65, "without roads the straight-line nearest wins")
R.Clear()
K.Options.Write("Skins", "worldMap.followRoads", true)
assert(R.Pick({ nearest = "auction" }) == true, "a recorded auctioneer on this continent routes")
R.Clear()

R.Quest(11)
assert(R.card:IsShown() and state.waypoint.uiMapID == 1 and state.waypoint.position:GetXY() == 0.65, "a quest with a client waypoint routes there")
R.Clear()
env.GetQuestUiMapID = function(id) return id == 10 and 1 or nil end
R.Quest(10)
assert(state.waypoint and state.waypoint.position:GetXY() == 0.5, "a quest without a waypoint routes to its map POI")
R.Clear()
R.Quest(99)
assert(R.card:IsShown() and R.note:GetText() == "The game gives no map position for this quest." and not state.waypoint, "a quest with no position says so")
R.Clear()
env.C_Map.CanSetUserWaypointOnMap = function() return false end
R.Quest(11)
assert(R.card:IsShown() and not state.waypoint and R.note:GetText() == "The game does not allow a waypoint there.", "a refused waypoint is not called a missing position")
env.C_Map.CanSetUserWaypointOnMap = function() return true end
R.Clear()
local waypoint, onMap = env.C_QuestLog.GetNextWaypoint, env.C_QuestLog.GetQuestsOnMap
env.C_QuestLog.GetNextWaypoint = function() return 1, env.Secret(0.1), 0.2 end
R.Quest(10)
assert(state.waypoint and state.waypoint.position:GetXY() == 0.5, "a waypoint with a secret coordinate falls back to the quest's map POI")
R.Clear()
env.C_QuestLog.GetNextWaypoint = function() end
env.C_QuestLog.GetQuestsOnMap = function() return { { questID = 10, isQuestStart = true, mapID = 1, x = 0.99, y = 0.99 } } end
R.Quest(10)
assert(not state.waypoint and R.note:GetText() == "The game gives no map position for this quest.", "a quest-start POI is not the quest's objective")
env.C_QuestLog.GetNextWaypoint, env.C_QuestLog.GetQuestsOnMap = waypoint, onMap
R.Clear()
R.Quest(11)
K.Options.Write("Skins", "worldMap.questRoutes", false)
assert(not R.card:IsShown() and not state.waypoint, "turning quest routes off clears the quest's route")
K.Options.Write("Skins", "worldMap.questRoutes", true)
R.Pick(R.Search("Thunder")[1])
K.Options.Write("Skins", "worldMap.questRoutes", false)
assert(R.card:IsShown() and state.waypoint, "turning quest routes off keeps a quest picked from the search")
R.Clear()
R.Quest(11)
assert(not R.card:IsShown() and not state.waypoint, "quest routes off leaves the click as it was")
K.Options.Write("Skins", "worldMap.questRoutes", true)

R.Pick({ nearest = "inn" })
K.Options.Write("Skins", "worldMap.services", false)
assert(not R.card:IsShown() and not state.waypoint, "turning services off clears its route")
K.Options.Write("Skins", "worldMap.services", true)
local grosk = R.Search("Grosk")[1]
R.Pick(R.Search("Skull")[1])
R.search:SetText("")
R.search:GetScript("OnEditFocusGained")(R.search)
assert(Results() == 6)
K.Options.Write("Skins", "worldMap.services", false)
assert(Results() == 0, "turning services off closes its picker")
assert(R.card:IsShown() and state.waypoint and state.waypoint.position:GetXY() == 0.54, "turning services off keeps an ordinary route")
assert(R.Pick(grosk) == nil and state.waypoint.position:GetXY() == 0.54, "a service row left from before does not route with services off")
R.search:SetText("Skull")
R.search:GetScript("OnEscapePressed")(R.search)
R.search:GetScript("OnEditFocusGained")(R.search)
assert(Results() == 0, "with services off, focus does not reopen a closed search")
R.Clear()
assert(Shown() == 0 and #R.Search("") == 0 and #R.Search("inn") == 0 and #R.Search("Grosk") == 0, "services off hides pins, pickers and service rows")
R.Pick({ nearest = "inn" })
assert(not R.card:IsShown(), "services off ignores a nearest row")
local before = Count(Saved("trainer"))
Visit("Late trainer", 4, 380, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(Count(Saved("trainer")) == before, "services off records nothing")
K.Options.Write("Skins", "worldMap.services", true)
assert(Shown() == 6)
K.Modules.Disable("Skins")
assert(Shown() == 0, "module off removes the pins")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

local graph = Fixture.Graph()
graph.nodes[4] = { id = 4, name = "Island", x = 900, y = 900, kind = "junction" }
env, K, R, state, map, npc, Services = Boot(true, graph)
K.Options.Write("Skins", "worldMap.services", false)
Visit("Trainer", 5, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(K.Store.Account().mapServices == nil and #Services.pins == 0, "a session with services off saves nothing and builds no pins")
K.Options.Write("Skins", "worldMap.services", true)
Visit("Early trainer", 50, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(Saved("trainer")["50"] and #Services.pins == 0, "the recorder runs from login; pins wait for the map to open")

local Roads, times = env._addons.KstyleUI_Skins.WorldMapRoads, 0
local realTimes = Roads.Times
Roads.Times = function(...) times = times + 1; return realTimes(...) end
assert(Services.Nearest("bank", true) == nil and times == 0, "with no recorded bank, nearest builds no road times")
Roads.Times = realTimes
local function Bank(name, x, y) return { name = name, map = 1, x = x / 1000, y = y / 1000, continent = 1, wx = x, wy = y, faction = "Horde" } end
K.Store.Account().mapServices.bank = { island = Bank("Island", 900, 900), pass = Bank("Pass", 300, 300) }
state.playerX, state.playerY = 0.3, 0.7
assert(Services.Nearest("bank", true).name == "Pass", "a bank the roads reach beats one they do not")
K.Store.Account().mapServices.bank = { island = Bank("Island", 900, 900) }
assert(Services.Nearest("bank", true).name == "Island", "with none reachable by road, the straight-line nearest is offered")
K.Store.Account().mapServices.bank = { pass = Bank("Pass", 300, 300), cross = Bank("Crossroads", 720, 360) }
env.C_Map.GetMapInfo = function() return { mapType = 2 } end
env.C_TaxiMap.GetTaxiNodesForMap = function() return { { name = "Razor Hill", faction = 1, isUndiscovered = false }, { name = "Crossroads", faction = 1, isUndiscovered = false } } end
assert(Services.Nearest("bank", true).name == "Crossroads", "nearest counts the flights this character knows, as the route does")
env.C_Map.GetMapInfo = function() return { mapType = 3 } end
env.UnitFactionGroup = function() return "Alliance" end
assert(Services.Nearest("bank", true) == nil, "another faction's services are not offered")
env.UnitFactionGroup = function() return "Horde" end

Visit("Spawned trainer", 60, 200, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
Visit("Spawned trainer", 60, 400, 700, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
Visit("Spawned trainer", 60, 205, 303, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
local spawns = 0
for _, row in pairs(Saved("trainer")) do if row.name == "Spawned trainer" then spawns = spawns + 1 end end
assert(spawns == 2, "two places of one NPC stay two services; a revisit a few yards off updates its place")
Visit("Vault", 70, 320, 310, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 67)
Visit("Warband vault", 71, 330, 310, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 68)
assert(Saved("bank")["70"] and Saved("bank")["71"], "character and account bankers record as banks")
Visit("Late stock", 72, 340, 310, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5, { items = {} })
npc.items = { 17030 }
env.FireEvent("MERCHANT_UPDATE")
assert(Saved("reagent")["72"], "reagents that arrive with MERCHANT_UPDATE record the vendor")
M.S.Show(map)
assert(Shown() > 0, "the first map open pins what was recorded before it")

for _, api in ipairs({ "C_PlayerInteractionManager", "C_Item", "UnitGUID", "CanMerchantRepair", "GetMerchantItemID" }) do env[api] = nil end
Visit("Keeper", nil, 300, 300, "GOSSIP_SHOW", nil, { binder = true })
Visit("Smith", nil, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5, { repair = true, items = { 17030 } })
Visit("Keeper", nil, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)
assert(Saved("trainer").Keeper and Count(Saved("repair")) == 0 and Count(Saved("inn")) == 0, "missing APIs degrade to name keys and skip what they cannot prove")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map services, nearest picker and quest routes ok")
