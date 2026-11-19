-- test-actionbars-travel.lua: crest actions, filtered travel, hidden empty groups, secure combat clicks and deferred inventory changes.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Fixture = dofile("Tools/regression/travel_fixture.lua")
local env, K, ns = AB.New({ class = "MAGE" })
local data = Fixture.Install(env, true)
env._resolveRects = true
AB.Enable(env, K)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
local travel = ns.Travel
local file = assert(io.open("Tools/data/travel-items.json", "rb"))
local curated = file:read("*a")
file:close()
local ids = {}
for id in curated:gmatch('"(%d+)"%s*:') do ids[tonumber(id)] = true end
for _, id in ipairs(ns.TRAVEL_ITEMS) do assert(ids[id], "regenerate TravelItems.lua with python Tools/data/travel-items.py"); ids[id] = nil end
assert(next(ids) == nil, "regenerate TravelItems.lua with python Tools/data/travel-items.py")
assert(travel.crest and travel.crest:IsShown(), AB.Errors(env))
assert(travel.crest:GetAttribute("type1") == "item" and travel.crest:GetAttribute("item1") == "item:6948")
AB.Click(env, travel.crest, "LeftButton", false)
assert(env._game.used[#env._game.used] == "item:6948", "left click must use the item ID, never a bag slot")
assert(#travel.groups[1].buttons == 1 and #travel.groups[2].buttons == 14 and #travel.groups[3].buttons == 1)
assert(travel.groups[1].buttons[1].medFrame:GetTexture() == ns.bars.bar1.buttons[1].medFrame:GetTexture(), "travel must wear the action bars' own Medallions sockets")
assert(travel.groups[2]:GetAttribute("pages") == 2, "long groups page inside the narrow menu")
assert(travel.groups[2].pages[1]:IsShown() and not travel.groups[2].pages[2]:IsShown())
env.SetCombat(true)
AB.Click(env, travel.crest, "RightButton", true)
assert(not travel.menu:IsShown(), "toggle once on release with either keydown CVar")
AB.Click(env, travel.crest, "RightButton", false)
assert(travel.menu:IsShown(), "right click opens securely in combat")
AB.Click(env, travel.groups[2].nextPage, "LeftButton", false)
assert(travel.groups[2].pages[2]:IsShown() and not travel.groups[2].pages[1]:IsShown())
AB.Click(env, travel.groups[2].buttons[13], "LeftButton", false)
assert(not travel.menu:IsShown(), "a secure action closes after use")
assert(not AB.PressKey(env, "ESCAPE"), "closing removes the Escape override")
AB.Click(env, travel.crest, "RightButton", false)
assert(AB.PressKey(env, "ESCAPE") and not travel.menu:IsShown(), "Escape closes in combat")
AB.Click(env, travel.crest, "RightButton", false)
AB.Click(env, travel.crest, "RightButton", false)
assert(not travel.menu:IsShown(), "second right click closes")
data.items = {}
env.FireEvent("BAG_UPDATE_DELAYED")
assert(travel.crest:GetAttribute("type1") == "item", "inventory mutations wait for Combat.Queue")
K.Options.Write("ActionBars", "crestTravel", false)
assert(travel.crest:IsShown(), "disabling protected clicks waits for combat to end")
assert(#env._blocked == 0, table.concat(env._blocked, ", "))
env.SetCombat(false)
assert(not travel.crest:IsShown() and not travel.menu:IsShown(), "off restores click-through artwork")
K.Options.Write("ActionBars", "crestTravel", true)
assert(travel.crest:GetAttribute("type1") == nil, "without a Hearthstone left click does nothing")
AB.W.Enter(travel.crest)
local tip, missing = K.Widgets.Tooltip(), false
for _, line in ipairs(tip.used) do if line.left:GetText() == K.L["No Hearthstone in your bags."] then missing = true end end
assert(tip:IsOwned(travel.crest) and missing, "use the kit tooltip and explain the missing Hearthstone")
AB.W.Leave(travel.crest)
assert(not travel.groups[1]:IsShown() and not travel.groups[3]:IsShown(), "empty groups hide")
assert(travel.groups[2]:IsShown(), "known class travel remains")
data.spells = {}
env.FireEvent("SPELLS_CHANGED")
assert(not travel.groups[2]:IsShown() and not travel.menu:GetAttribute("hasTravel"))
AB.Click(env, travel.crest, "RightButton", false)
assert(not travel.menu:IsShown(), "no empty flyout")
data.items = { env.Secret({}), { itemID = env.Secret(6948) } }
data.cooldown = { env.Secret(0), env.Secret(3600) }
local bind, cooldown = ns.TravelData.Hearth()
assert(bind == "Stormwind City" and cooldown == "--", "secret cooldowns stay unread")
env.FireEvent("BAG_UPDATE_DELAYED")
assert(travel.crest:GetAttribute("type1") == nil, "secret bag records and IDs never get indexed or compared")
env.C_MountJournal = { GetMountIDs = function() return { 1, 2, 3, 4 } end, GetMountInfoByID = function(id)
	return "Mount", 470 + id, 132261, false, id ~= 2, 0, false, false, nil, id == 4, id ~= 3
end }
local groups = ns.TravelData.Read()
assert(#groups[3] == 1 and groups[3][1].id == 471, "optional journal filters unusable, uncollected and hidden mounts")
env.C_MountJournal.GetMountIDs = function() return env.Secret({}) end
assert(#ns.TravelData.Read()[3] == 0)
K.Options.Write("HudStyle", "style", "frames")
assert(not travel.crest:IsShown(), "other HUD styles stay click-through")
assert(#env._blocked == 0 and #env._errors == 0, AB.Errors(env))
print("ok crest travel")
