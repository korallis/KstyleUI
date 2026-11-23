-- test-worldmap-services.lua: the service recorder, map pins, the nearest picker on the road graph and click-a-quest routes.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M

local function Boot()
	local env, K, R, state, map = M.New()
	Fixture.Install(env, state, Fixture.Graph())
	env.C_Map.GetMapInfo = function() return { mapType = 3 } end
	env.Enum.PlayerInteractionType = { Merchant = 5, Trainer = 7, Banker = 8, Binder = 20, Auctioneer = 21 }
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
local function Visit(name, id, x, y, event, payload)
	npc.name, npc.id, npc.repair, npc.items, npc.binder = name, id, nil, nil, nil
	state.playerX, state.playerY = x / 1000, y / 1000
	return function(extra)
		for k, v in pairs(extra or {}) do npc[k] = v end
		env.FireEvent(event, payload)
	end
end
local function Saved(kind) return (K.Store.Account().mapServices or {})[kind] or {} end
local function Count(list) local n = 0; for _ in pairs(list) do n = n + 1 end; return n end
local function Shown() local n = 0; for _, pin in ipairs(Services.pins) do if pin:IsShown() then n = n + 1 end end; return n end

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

Visit("Innkeeper Grosk", 6928, 650, 450, "GOSSIP_SHOW")({ binder = true })
local inn = Saved("inn")["6928"]
assert(inn and inn.name == "Innkeeper Grosk" and inn.map == 1 and inn.continent == 1 and inn.wx == 650 and inn.wy == 450, "talking to an innkeeper records it")
Visit("Innkeeper Kauth", 6747, 300, 260, "CONFIRM_BINDER")()
assert(Saved("inn")["6747"], "choosing to bind records the innkeeper")
Visit("Gennia", 3000, 300, 300, "GOSSIP_SHOW")()
assert(Count(Saved("inn")) == 2, "an NPC without the binder interaction is not an innkeeper")
Visit("Shadowmage", 3328, 310, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
Visit("Bank of Orgrimmar", 3309, 320, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)()
Visit("Auctioneer", 9856, 330, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 21)()
Visit("Smith", 3356, 340, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)({ repair = true, items = { 1, 17030 } })
Visit("Grocer", 3312, 350, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)({ items = { 1, 2 } })
assert(Saved("trainer")["3328"] and Saved("bank")["3309"] and Saved("auction")["9856"], "trainer, bank and auction windows record their NPC")
assert(Saved("repair")["3356"] and Saved("reagent")["3356"] and Count(Saved("repair")) == 1 and Count(Saved("reagent")) == 1,
	"a merchant counts as repair or reagent only when the client says it repairs or sells reagent-class items")
Visit(env.Secret("Hidden"), 1, 360, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
Visit("Nowhere", 2, 370, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", env.Secret(7))()
assert(Count(Saved("trainer")) == 1, "secret names and payloads are ignored")
local position = env.C_Map.GetPlayerMapPosition
env.C_Map.GetPlayerMapPosition = function() end
Visit("Lost", 3, 0, 0, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
assert(Count(Saved("trainer")) == 1, "no player position, no record")
assert(R.Pick({ nearest = "inn" }) == nil and R.note:GetText() == "Your position is unavailable here.", "nearest without a position says so")
env.C_Map.GetPlayerMapPosition = position
R.Clear()

assert(Shown() == 7, "every recorded service on this zone has a pin, got " .. Shown())
local pin = Services.pins[1]
pin:GetScript("OnClick")(pin)
assert(R.card:IsShown() and state.waypoint and state.waypoint.uiMapID == 1, "clicking a pin routes to it")
R.Clear()
function map:OnCanvasScaleChanged() state.scaled = (state.scaled or 0) + 1 end
map:SetMapID(1)
map:SetMapID(1)
local moves, setPoint = 0, pin.SetPoint
pin.SetPoint = function(self, ...) moves = moves + 1; return setPoint(self, ...) end
map:OnCanvasScaleChanged()
assert(state.scaled == 1 and moves == 1, "pins follow a canvas scale change through one hook")
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
K.Options.Write("Skins", "worldMap.questRoutes", false)
R.Quest(11)
assert(not R.card:IsShown() and not state.waypoint, "quest routes off leaves the click as it was")
K.Options.Write("Skins", "worldMap.questRoutes", true)

K.Options.Write("Skins", "worldMap.services", false)
assert(Shown() == 0 and #R.Search("") == 0 and #R.Search("inn") == 0 and #R.Search("Grosk") == 0, "services off hides pins, pickers and service rows")
R.Pick({ nearest = "inn" })
assert(not R.card:IsShown(), "services off ignores a nearest row")
local before = Count(Saved("trainer"))
Visit("Late trainer", 4, 380, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
assert(Count(Saved("trainer")) == before, "services off records nothing")
K.Options.Write("Skins", "worldMap.services", true)
assert(Shown() == 7)
K.Modules.Disable("Skins")
assert(Shown() == 0, "module off removes the pins")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

local again = { Boot() }
env, K, state, npc, Services = again[1], again[2], again[4], again[6], again[7]
K.Options.Write("Skins", "worldMap.services", false)
Visit("Trainer", 5, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
assert(K.Store.Account().mapServices == nil and #Services.pins == 0, "a session with services off saves nothing and builds no pins")
for _, api in ipairs({ "C_PlayerInteractionManager", "C_Item", "UnitGUID", "CanMerchantRepair", "GetMerchantItemID" }) do env[api] = nil end
K.Options.Write("Skins", "worldMap.services", true)
Visit("Keeper", nil, 300, 300, "GOSSIP_SHOW")({ binder = true })
Visit("Smith", nil, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)({ repair = true, items = { 17030 } })
Visit("Keeper", nil, 300, 300, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7)()
assert(Saved("trainer").Keeper and Count(Saved("repair")) == 0 and Count(Saved("inn")) == 0, "missing APIs degrade to name keys and skip what they cannot prove")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map services, nearest picker and quest routes ok")
