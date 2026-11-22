-- test-databars-readouts.lua: the shared readouts, secrets, API fallbacks, protected clicks, throttles, account gold and ordered module controls.
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")
local Load = dofile("Tools/regression/load_files.lua")
local M = dofile("Tools/regression/minimap_env.lua")

local function eq(a, b) assert(a == b, tostring(a) .. " differs from " .. tostring(b)) end
local function tooltip(ns, K, id)
	ns.Strip.ShowTooltip(ns.Strip.view.items[id])
	local lines = {}
	for _, row in ipairs(K.Widgets.Tooltip().used) do
		lines[#lines + 1] = (row.left:GetText() or "") .. "=" .. (row.right:GetText() or "")
	end
	return table.concat(lines, "|"):gsub("\226\128\137", "")
end

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local e, kit, bar = D.New({ enable = false, width = screen[1], height = screen[2], size = "auto", setup = Fixture })
	local s = kit.Store.Module("DataBars").strip
	local listening = {}
	local register, unregister = kit.Events.Register, kit.Events.UnregisterAll
	kit.Events.Register = function(owner, event, fn)
		if owner:match("^DataBars%.Readouts%.") then listening[owner] = true end
		return register(owner, event, fn)
	end
	kit.Events.UnregisterAll = function(owner)
		listening[owner] = nil
		return unregister(owner)
	end
	s.enabled = false
	kit.Modules.Enable("DataBars")
	assert(next(bar.Strip.view.items) == nil, "defer readout frames while the bar is disabled")
	assert(next(listening) == nil, "register no readout events while the bar is disabled")
	for _, entry in ipairs(s.modules) do entry.shown = entry.id == "fps" end
	kit.Options.Write("DataBars", "strip.enabled", true)
	assert(bar.Strip.view.items.fps and not bar.Strip.view.items.bags, "build only the module the bar first shows")
	assert(next(listening) == nil, "off readouts must not register events beside the event-free fps readout")
	local fps = bar.Strip.view.items.fps
	for _, entry in ipairs(s.modules) do if entry.id == "bags" then entry.shown = true end end
	kit.Options.Write("DataBars", "strip.modules", s.modules)
	assert(bar.Strip.view.items.bags and bar.Strip.view.items.fps == fps, "add a newly shown module and reuse existing readouts")
	assert(listening["DataBars.Readouts.bags"], "first showing bags registers its events")
	kit.Options.Write("DataBars", "strip.enabled", false)
	assert(next(listening) == nil, "turning the bar off unregisters every readout event")
	assert(#e._errors == 0 and kit.ErrorCount() == 0)
end

local game
local env, K, ns = D.New({ setup = function(e) D.Menus(e); game = Fixture(e) end })
Load({ "KstyleUI_ActionBars/TravelData.lua" }, env)
ns.Strip.Refresh()
local Budget = dofile("Tools/regression/path_budget.lua")
ns.Bars.Disable()
ns.Menus.Disable()
for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "PLAYER_XP_UPDATE", "UPDATE_FACTION", "BAG_UPDATE_DELAYED", "CALENDAR_UPDATE_PENDING_INVITES", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED", "CURRENCY_DISPLAY_UPDATE", "HEARTHSTONE_BOUND" }) do
	local cost = Budget.Count(env, function() env.FireEvent(event, "player") end)
	Budget.Check(cost, 20000, 1, "Value-only " .. event .. ": use Strip.Update, not Strip.Refresh")
end
ns.Bars.Enable()
ns.Menus.Enable()
local function sameColor(region, token)
	local r, g, b = K.Tokens.Color(token)
	local ar, ag, ab = region:GetTextColor()
	assert(ar == r and ag == g and ab == b, "readout values use text and units use labelMuted")
end
for id, unit in pairs({ fps = "fps", latency = "ms", durability = "armour", guild = "guild", friends = "friends", bags = "free" }) do
	local item = ns.Strip.view.items[id]
	eq(item.label:GetText(), unit)
	sameColor(item.value, "text")
	sameColor(item.label, "labelMuted")
end
local values, settings = ns.Strip.VALUES, ns.Settings().strip
eq(values.time(settings), "14:32")
eq(values.bags(settings), "22")
eq(values.spec(settings), "Elemental")
eq(values.hearth(settings), "ready Stormwind")
eq(values.guild(settings), "17")
eq(values.friends(settings), "7")
eq(values.currencies(settings), "1250 Honor \194\183 350 Justice")
assert(tooltip(ns, K, "time"):find("Pending invites=2", 1, true))
assert(tooltip(ns, K, "bags"):find("Free slots=22", 1, true))
assert(tooltip(ns, K, "spec"):find("Specialization=Elemental", 1, true))
assert(tooltip(ns, K, "hearth"):find("Home=Stormwind", 1, true))
assert(tooltip(ns, K, "guild"):find("Online=17", 1, true))
assert(tooltip(ns, K, "friends"):find("Battle.net=3", 1, true))
assert(tooltip(ns, K, "currencies"):find("Honor=1250", 1, true))
game.duration, game.start, game.now = 1800, 20, 100
eq(values.hearth(settings), "29m Stormwind")
game.now = 1775
eq(values.hearth(settings), "45s Stormwind")
game.now = 1820
eq(values.hearth(settings), "ready Stormwind")

eq(game.requests, 1)
game.now = 120
for _ = 1, 20 do ns.Readouts.RequestRoster(); env.FireEvent("GUILD_ROSTER_UPDATE") end
eq(game.requests, 1)
game.now = 161
ns.Readouts.RequestRoster()
eq(game.requests, 2)
game.guild = false
env.FireEvent("PLAYER_GUILD_UPDATE", "player")
assert(not ns.Strip.view.items.guild.button:IsShown())
eq(game.requests, 2)
game.groups = 1
env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
assert(not ns.Strip.view.items.spec.button:IsShown())
game.groups, game.guild = 2, true
env.FireEvent("PLAYER_GUILD_UPDATE", "player")

assert(not ns.Click.Target("spec"), "switchable spec uses the ordinary click")
ns.Strip.ACTIONS.spec(nil, "LeftButton")
eq(game.group, 2)
env.SetCombat(true)
ns.Strip.ACTIONS.spec(nil, "LeftButton")
eq(game.group, 2)
for _, id in ipairs({ "spec", "hearth", "bags", "time" }) do
	assert(not ns.Click.Attach(ns.Strip.view.items[id]))
	assert(tooltip(ns, K, id):find("combat", 1, true), id .. " explains the protected click")
end
env.SetCombat(false)
assert(ns.Click.Attach(ns.Strip.view.items.hearth))
eq(ns.Click.proxy:GetAttribute("type1"), "item")
eq(ns.Click.proxy:GetAttribute("item1"), "item:6948")
assert(ns.Click.Attach(ns.Strip.view.items.bags))
eq(ns.Click.proxy:GetAttribute("type1"), "click")
eq(ns.Click.proxy:GetAttribute("item1"), nil)
env.C_SpecializationInfo.SetActiveSpecGroup = nil
eq(ns.Click.Target("spec"), env.TalentMicroButton)

local account, key = K.Store.Account(), K.Store.CharacterKey()
assert(account.databarGold == nil, "account gold waits for its tooltip or a money event")
tooltip(ns, K, "gold")
eq(account.databarGold[key], env._game.money)
account.databarGold["Alt-OtherRealm"] = 1000000
assert(tooltip(ns, K, "gold"):find("Alt-OtherRealm=100g", 1, true))
env._game.money = 2000000
env.FireEvent("PLAYER_MONEY")
eq(account.databarGold[key], 2000000)
env._game.money = env.Secret(999)
env.FireEvent("PLAYER_MONEY")
eq(account.databarGold[key], 2000000)
env.FireEvent("PLAYER_LOGOUT")
local saved = D.CoreEnv.DeepCopy(env.KstyleUIDB)
local _, reloaded = D.New({ saved = saved })
eq(reloaded.Store.Account().databarGold["Alt-OtherRealm"], 1000000)

game.spec, game.bind, game.duration = env.Secret("Elemental"), env.Secret("Stormwind"), env.Secret(1)
game.guildOnline, game.friends, game.battle, game.invites = env.Secret(2), env.Secret(3), env.Secret(4), env.Secret(5)
game.currencies = { { name = env.Secret("Honor"), quantity = env.Secret(8) }, env.Secret({}) }
env.C_Container.CalculateTotalNumberOfFreeBagSlots = function() return env.Secret(5) end
for _, id in ipairs({ "bags", "spec", "guild", "friends" }) do eq(values[id](settings), "--") end
eq(values.hearth(settings), "-- --")
eq(values.currencies(settings), "-- -- \194\183 --")
for _, id in ipairs({ "bags", "spec", "guild", "friends", "hearth", "currencies", "time" }) do
	assert(tooltip(ns, K, id):find("--", 1, true), id .. " tooltip guards secrets")
end
env.GetGameTime = function() return env.Secret(1), env.Secret(2) end
env.date = function() return env.Secret("10") end
eq(values.time(settings), nil)
env.C_Calendar, env.C_Container, env.C_SpecializationInfo, env.C_GuildInfo = nil, nil, nil, nil
env.C_FriendList, env.BNGetNumFriends, env.GetNumGuildMembers, env.C_CurrencyInfo = nil, nil, nil, nil
env.C_Item, env.GetBindLocation, env.date, env.GetGameTime = nil, nil, nil, nil
for _, id in ipairs({ "bags", "spec", "guild", "friends", "currencies" }) do eq(values[id](settings), "--") end
eq(values.hearth(settings), "-- --")
eq(values.time(settings), nil)
env.C_Container = { GetContainerNumFreeSlots = function() return 3 end }
eq(values.bags(settings), "15")

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local e, kit, bar = D.New({ width = screen[1], height = screen[2], size = "auto", setup = function(e) D.Menus(e); Fixture(e); M.Blizzard(e, {}) end })
	Load({ "KstyleUI_Options/Model.lua" }, e)
	local model = e._addons.KstyleUI_Options.Model
	local items = model.SchemaItems("DataBars", kit.Options.Get("DataBars"), "DataBars")
	local entries = {}
	for _, item in ipairs(model.Visible(items)) do if item.entry then entries[item.entry] = item end end
	for _, entry in ipairs(bar.Settings().strip.modules) do
		assert(entries[entry.id], entry.id .. " is in the real ordered list")
		eq(entry.shown, not ({ xp = 1, location = 1, itemLevel = 1, coords = 1, combat = 1, played = 1, audio = 1, prof1 = 1, prof2 = 1, broker = 1, spacer = 1, reagents = 1 })[entry.id])
	end
	entries.micro.set({ shown = false })
	assert(not bar.Menus.Visible("micro"))
	entries.micro.set({ shown = true })
	assert(bar.Menus.Visible("micro"))
	eq(entries.time.get().zone, "centre")
	eq(entries.hearth.get().zone, "left")
	eq(entries.gold.get().zone, "right")
	Load(M.Files(), e)
	kit.Modules.Enable("Minimap")
	local clock = e._addons.KstyleUI_Minimap.Map.face.clock
	assert(not clock:IsShown(), "the bar owns the clock by default")
	entries.time.set({ shown = false })
	assert(clock:IsShown() and not bar.Strip.view.items.time.button:IsShown())
	entries.time.set({ shown = true, zone = "left" })
	assert(not clock:IsShown())
	eq(bar.Strip.view.items.time.button._points[1][2], bar.Strip.view.zones.left)
	entries.time.move(-1)
	eq(bar.Settings().strip.modules[3].id, "time")
	entries.time.move(1)
	eq(bar.Settings().strip.modules[4].id, "time")
	kit.Options.Write("DataBars", "strip.enabled", false)
	assert(clock:IsShown())
	kit.Options.Write("DataBars", "strip.enabled", true)
	assert(not clock:IsShown())
	local dock = bar.Settings().strip.dockModules
	for _, entry in ipairs(dock) do if entry.id == "time" then entry.shown = false end end
	kit.Options.Write("DataBars", "strip.dockModules", dock)
	assert(clock:IsShown(), "the minimap clock returns when the independent dock clock is off")
	assert(not clock:IsShown(), "the top bar retains its own enabled clock")
	assert(#e._errors == 0 and kit.ErrorCount() == 0, tostring(e._errors[1]))
end
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databar readouts ok: values, tooltips, secrets, fallbacks, proxy, throttle, gold, ordered controls and clock on four screens")
