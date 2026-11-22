-- test-databars-parity.lua: the data bar's EllesmereUI parity options keep today's defaults, apply when on, restore when off, follow their events and reach the preview.
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")

local function eq(a, b, why) assert(a == b, (why or "value") .. ": " .. tostring(a) .. " differs from " .. tostring(b)) end

local OLD = { "gold", "latency", "fps", "durability", "time", "spec", "guild", "friends", "bags", "currencies", "xp", "location", "itemLevel" }
local old = {}
for i, id in ipairs(OLD) do old[i] = { id = id, shown = i <= 10, zone = id == "time" and "centre" or "right" } end

local game, x = nil, {}
local env, K, ns = D.New({
	saved = { version = 42, profiles = { Default = { DataBars = { enabled = true, strip = { modules = old } } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
	setup = function(e)
		D.Menus(e)
		game = Fixture(e)
		local date = e.date
		x = { day = "2026-11-20", px = 0.4532, py = 0.6218, cvars = { Sound_EnableAllSound = "1", Sound_MasterVolume = "0.8", Sound_MusicVolume = "0.35" },
			profs = { { "Mining", 225, 300 }, { "Herbalism", 150, 300 } }, prof1 = 1, loadout = "Raid", broker = { text = "42 items", label = "Bags" } }
		e.date = function(f) if f == "%Y-%m-%d" then return x.day end return date(f) end
		e.C_Map = { GetBestMapForUnit = function() return 1429 end, GetPlayerMapPosition = function() return x.position or { GetXY = function() return x.px, x.py end } end }
		e.C_CVar = { GetCVar = function(n) return x.cvars[n] end, SetCVar = function(n, v) assert(not e.InCombatLockdown()); x.cvars[n] = v end }
		e.GetProfessions = function() return x.prof1, x.prof2 end
		e.GetProfessionInfo = function(i) local p = x.profs[i]; return p[1], 136240, p[2], p[3] end
		e.HasNewMail = function() return x.mail end
		e.IsResting = function() return x.resting end
		e.RequestTimePlayed = function() x.requested = true end
		e.C_ClassTalents = { GetLastSelectedSavedConfigID = function() return 7 end }
		e.C_Traits = { GetConfigInfo = function() return { name = x.loadout } end }
		e.GetZoneText = function() return "Elwynn Forest" end
		e.GetAverageItemLevel = function() return 62.8, 58.3 end
		local object = x.broker
		object.OnClick = function() x.clicked = true end
		local ldb = { GetDataObjectByName = function(_, name) return name == "Bagnon" and object or nil end }
		e.LibStub = { GetLibrary = function(_, name) return name == "LibDataBroker-1.1" and ldb or nil end }
	end,
})

local function write(key, value) assert(K.Options.Write("DataBars", key, value) ~= false, key); env.RunTimers() end
local function item(id) return ns.Strip.view.items[id] end
local function text(id) return item(id).value:GetText() end
local function shown(id) return item(id) ~= nil and item(id).button:IsShown() end
local function color(region) local r, g, b = region:GetTextColor(); return string.format("%.3f %.3f %.3f", r, g, b) end
local function token(name) local r, g, b = K.Widgets.Rgba(name, 1); return string.format("%.3f %.3f %.3f", r, g, b) end
local function disabled(key) local row = K.Options.Row("DataBars", key); return row.disableWhen ~= nil and row.disableWhen(K.Store.Module("DataBars")) == true end
local function show(ids)
	local list, want = K.Store.Module("DataBars").strip.dockModules, {}
	for _, id in ipairs(ids) do want[id] = true end
	for _, entry in ipairs(list) do entry.shown = want[entry.id] == true end
	write("strip.dockModules", list)
end
local function tooltip(id)
	ns.Strip.ShowTooltip(item(id))
	local lines = {}
	for _, row in ipairs(K.Widgets.Tooltip().used) do
		if row.left:IsShown() then lines[#lines + 1] = (row.left:GetText() or "") .. "=" .. (row.right:IsShown() and row.right:GetText() or "") end
	end
	ns.Strip.HideTooltip(item(id))
	return table.concat(lines, "|"):gsub("\226\128\137", "")
end

-- A v0.2.8 profile with a saved, reordered module list gains every absent readout switched off, as an absent entry was before;
-- an absent micro menu stays shown, as the menu treated it. The Great Vault waits for live Forever evidence.
local s = K.Store.Module("DataBars").strip
eq(#s.modules, #K.Options.Default("DataBars", "strip.modules"), "saved list gains the absent readouts")
eq(s.modules[1].id, "gold", "the saved order survives")
for i = #OLD + 1, #s.modules do eq(s.modules[i].shown, s.modules[i].id == "micro", s.modules[i].id .. " keeps its absent state") end
eq(ns.Strip.VALUES.vault, nil, "no Great Vault readout")
for _, key in ipairs({ "hover", "goldSession", "goldCharacters", "brokerLabel" }) do eq(s[key], true, key) end
for _, key in ipairs({ "labelCustom", "goldHistory", "specUpper", "specLoadout", "hearthOthers", "clockMail", "clockRest", "bagsReagent", "combatOnly", "playedTotal" }) do eq(s[key], false, key) end
assert(K.Options.Get("DataBars"), "the schema builds with every new row")

show({ "fps", "latency", "time", "spec", "bags", "xp", "itemLevel", "location", "gold", "hearth" })

-- Clock alerts: off by default even with mail and rest; on, they follow their events; off restores.
local clock = text("time")
x.mail, x.resting = true, true
env.FireEvent("UPDATE_PENDING_MAIL")
eq(text("time"), clock, "mail alert off")
write("strip.clockMail", true)
eq(text("time"), clock .. " mail", "mail alert on")
write("strip.clockRest", true)
eq(text("time"), clock .. " mail resting", "resting alert on")
x.mail = false
env.FireEvent("UPDATE_PENDING_MAIL")
eq(text("time"), clock .. " resting", "mail read clears the alert")
x.resting = false
env.FireEvent("PLAYER_UPDATE_RESTING")
eq(text("time"), clock, "leaving rest clears the alert")
write("strip.clockMail", false)
write("strip.clockRest", false)

-- Specialization: uppercase, loadout name and per-group text, refreshed on loadout and group changes.
eq(text("spec"), "Elemental")
write("strip.specUpper", true)
eq(text("spec"), "ELEMENTAL")
write("strip.specLoadout", true)
eq(text("spec"), "ELEMENTAL / RAID")
x.loadout = "Dungeon"
env.FireEvent("TRAIT_CONFIG_UPDATED")
eq(text("spec"), "ELEMENTAL / DUNGEON", "a loadout change refreshes")
write("strip.spec1Text", "Fire")
eq(text("spec"), "FIRE / DUNGEON")
eq(game.group, 1, "the fixture starts in group 1")
game.group = 2
env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
eq(text("spec"), "ELEMENTAL / DUNGEON", "group 2 keeps the name with no text of its own")
write("strip.spec2Text", "Earth")
eq(text("spec"), "EARTH / DUNGEON")
for _, key in ipairs({ "specUpper", "specLoadout" }) do write("strip." .. key, false) end
write("strip.spec1Text", "")
write("strip.spec2Text", "")
eq(text("spec"), "Elemental", "every spec option off restores the name")

-- Bags: display, reagent bag and the low-space warning, with the unit and colour restored when off.
local free = tostring(env.C_Container.CalculateTotalNumberOfFreeBagSlots())
eq(text("bags"), free, "the default keeps Blizzard's free count")
env.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 5 and 10 or 3 end
env.C_Container.GetContainerNumSlots = function(bag) return bag == 5 and 12 or 16 end
env.Constants = env.Constants or {}
env.Constants.InventoryConstants = { NumBagSlots = 4, NumReagentBagSlots = 1 }
write("strip.bagsDisplay", "used")
eq(text("bags"), "65")
eq(item("bags").label:GetText(), "used", "the unit follows the display")
write("strip.bagsDisplay", "usedTotal")
eq(text("bags"), "65/80")
write("strip.bagsReagent", true)
eq(text("bags"), "67/92", "the reagent bag counts when included")
write("strip.bagsDisplay", "freeTotal")
eq(text("bags"), "25/92")
eq(item("bags").label:GetText(), "free")
write("strip.bagsLow", 30)
eq(color(item("bags").value), token("hostile"), "low space turns the count red in plain colours")
env.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 5 and 12 or 6 end
env.FireEvent("BAG_UPDATE_DELAYED")
eq(text("bags"), "42/92", "a bag update refreshes the count")
eq(color(item("bags").value), token("medTextMuted"), "enough room clears the warning")
write("strip.bagsLow", 0)
write("strip.bagsReagent", false)
write("strip.bagsDisplay", "free")
eq(text("bags"), free, "off restores the default count")
local calc = env.C_Container.CalculateTotalNumberOfFreeBagSlots
env.C_Container.CalculateTotalNumberOfFreeBagSlots = nil
env.FireEvent("BAG_UPDATE_DELAYED")
eq(text("bags"), "30", "without Blizzard's total the free count still leaves the reagent bag out")
env.C_Container.CalculateTotalNumberOfFreeBagSlots = calc
env.FireEvent("BAG_UPDATE_DELAYED")

-- Experience: mode, values and context.
local xp = text("xp")
write("strip.xpText", "values")
assert(text("xp"):find(" / "), "values show current and maximum")
write("strip.xpFormat", "context")
assert(text("xp"):find("^Level %d+ "), "context names the level: " .. text("xp"))
write("strip.xpMode", "rep")
eq(text("xp"), ns.Readouts.XPText(s, ns.Sources.Reputation()), "reputation mode reads the watched faction")
for _, key in ipairs({ "xpText", "xpFormat", "xpMode" }) do write("strip." .. key, K.Options.Default("DataBars", "strip." .. key)) end
eq(text("xp"), xp, "the default restores")

-- Item level prefix and location width.
for value, want in pairs({ short = "ilvl 58", long = "Item level 58", none = "58" }) do
	write("strip.itemLevelPrefix", value)
	eq(text("itemLevel"), want, "prefix " .. value)
end
local average = env.GetAverageItemLevel
env.GetAverageItemLevel = function() return nil, 58 end
write("strip.itemLevelSource", "overall")
eq(text("itemLevel"), "--", "an unknown overall level is not swapped for the equipped one")
env.GetAverageItemLevel = average
write("strip.itemLevelSource", "equipped")
local zoneWidth = item("location").valueWidth
write("strip.locationWidth", "manual")
write("strip.locationMaxWidth", 60)
eq(item("location").valueWidth, 60, "a fixed location holds its width")
write("strip.locationMaxWidth", 200)
eq(item("location").valueWidth, 200)
write("strip.locationWidth", "auto")
eq(item("location").valueWidth, zoneWidth, "automatic follows the name again")

-- Gold tooltip sections and history; the session and character lists stay by default.
local tip = tooltip("gold")
assert(tip:find("This session="), "session line by default")
write("strip.goldSession", false)
assert(not tooltip("gold"):find("This session="), "session line off")
write("strip.goldCharacters", false)
assert(not tooltip("gold"):find(K.Store.CharacterKey(), 1, true), "character list off")
local account = K.Store.Account()
account.databarGoldHistory = {}
for day = 11, 19 do account.databarGoldHistory["2026-11-" .. day] = 1000000 end
assert(not tooltip("gold"):find("Since"), "no history lines while it is off")
write("strip.goldHistory", true)
tip = tooltip("gold")
assert(tip:find("Since 2026%-11%-19="), tip)
assert(tip:find("Since 2026%-11%-14="), "the oldest kept day is a week back: " .. tip)
eq(account.databarGoldHistory["2026-11-13"], nil, "history keeps seven days")
assert(account.databarGoldHistory["2026-11-20"], "today is recorded")
for _, key in ipairs({ "goldSession", "goldCharacters" }) do write("strip." .. key, true) end
write("strip.goldHistory", false)
assert(tooltip("gold"):find("This session="))

-- Hearthstone homes of other characters.
account.databarHearth = { ["Alt - Realm"] = "Ironforge" }
assert(not tooltip("hearth"):find("Ironforge"), "other homes stay hidden by default")
write("strip.hearthOthers", true)
assert(tooltip("hearth"):find("Alt %- Realm=Ironforge"), "other homes listed when on")
eq(account.databarHearth[K.Store.CharacterKey()], "Stormwind", "this character's home is kept")
write("strip.hearthOthers", false)

-- Strip-wide on the rail line, where the dock's muted ink and segments give way: hover highlight, custom label and value colours, padding.
write("strip.placement", "rail")
local label, plain = item("fps").label, token("text")
item("fps").button.Paint()
local base = color(label)
item("fps").button.hoverT = 1
item("fps").button.Paint()
eq(color(label), token("textHover"), "hover highlight by default")
write("strip.hover", false)
item("fps").button.hoverT = 1
item("fps").button.Paint()
eq(color(label), base, "no hover highlight when off")
write("strip.hover", true)
item("fps").button.hoverT = 0
write("strip.labelCustom", true)
write("strip.labelColor", { r = 1, g = 0, b = 0, a = 1 })
eq(color(label), "1.000 0.000 0.000", "custom label colour")
write("strip.labelCustom", false)
eq(color(label), base, "label colour restores")
write("strip.valueColor", "custom")
write("strip.valueCustom", { r = 0, g = 1, b = 0, a = 1 })
eq(color(item("latency").value), "0.000 1.000 0.000", "custom value colour")
write("strip.valueCustom", { r = 0, g = 0, b = 1, a = 1 })
eq(color(item("latency").value), "0.000 0.000 1.000", "a new custom colour repaints")
write("strip.valueColor", "plain")
eq(color(item("latency").value), plain, "plain restores")
local gap = select(4, item("latency").dot:GetPoint())
write("strip.padding", 6)
assert(select(4, item("latency").dot:GetPoint()) < gap - 5, "padding widens the room around the dots")
write("strip.padding", 0)
eq(select(4, item("latency").dot:GetPoint()), gap, "no padding restores the dots")

-- Cells: text alignment.
write("strip.line", false)
write("strip.labels", "full")
for _, align in ipairs({ "LEFT", "RIGHT", "CENTER" }) do
	write("strip.align", align)
	eq(item("latency").value:GetJustifyH(), align, "align " .. align)
end
write("strip.labels", "inline")
write("strip.align", "LEFT")
eq((item("latency").value:GetPoint()), "LEFT", "inline units align left")
write("strip.align", "CENTER")
eq((item("latency").value:GetPoint()), "CENTER", "centre restores")
write("strip.locationWidth", "manual")
assert(disabled("strip.locationWidth") and disabled("strip.locationMaxWidth") and disabled("strip.brokerWidth"), "fixed widths apply on one line only")
write("strip.locationWidth", "auto")
for _, entry in ipairs(s.railModules) do if entry.id == "spacer" then entry.shown = true end end
write("strip.railModules", s.railModules)
assert(not shown("spacer"), "cells part their readouts already; the spacer stays on one line")
write("strip.orientation", "VERTICAL")
assert(disabled("strip.align"), "a column keeps its values right-aligned, so Text align is off there")
assert(not shown("spacer"), "a column draws no spacer row")
write("strip.orientation", "HORIZONTAL")
for _, entry in ipairs(s.railModules) do if entry.id == "spacer" then entry.shown = false end end
write("strip.railModules", s.railModules)
write("strip.line", true)
write("strip.placement", "top")

-- New readouts: coordinates, combat, time played, audio, professions, DataBroker and spacer.
show({ "fps", "latency", "coords", "combat", "played", "audio", "prof1", "prof2", "broker", "time" })
eq(text("coords"), "45.3, 62.2")
write("strip.coordsDecimals", 2)
eq(text("coords"), "45.32, 62.18")
write("strip.coordsDecimals", 0)
x.px = 0.5
ns.Strip.Tick()
eq(text("coords"), "50, 62", "the ticker moves the coordinates")
x.position = env.Secret({})
ns.Strip.Tick()
eq(text("coords"), "--", "secret positions stay unread")
x.position = nil
write("strip.coordsDecimals", 1)
for _, entry in ipairs(s.railModules) do entry.shown = entry.id == "coords" end
show({ "bags" })
write("strip.railModules", s.railModules)
write("strip.placement", "rail")
x.px = 0.8
env.RunTickers()
eq(text("coords"), "80.0, 62.2", "a placement change starts the ticker its readouts need")
write("strip.placement", "top")
x.px = 0.5
show({ "fps", "latency", "coords", "combat", "played", "audio", "prof1", "prof2", "broker", "time" })

eq(text("combat"), "0:00")
env.SetCombat(true)
game.now = game.now + 42
ns.Strip.Tick()
eq(text("combat"), "0:42", "the fight timer counts")
env.SetCombat(false)
eq(text("combat"), "0:42", "the last fight stays")
write("strip.combatOnly", true)
assert(not shown("combat"), "hidden out of combat")
env.SetCombat(true)
assert(shown("combat"), "shown when the fight starts")
env.SetCombat(false)
assert(not shown("combat"), "hidden when it ends")
local started = text("combat")
env._combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
game.now = game.now + 4
ns.Strip.Tick()
assert(shown("combat"), "shown even when lockdown starts before the fight event")
eq(text("combat"), "0:04")
env.SetCombat(false)
assert(not shown("combat") and started ~= nil, "hidden again after the locked fight")
write("strip.combatOnly", false)
assert(shown("combat"), "off restores the readout")

eq(text("played"), "--")
ns.Strip.ACTIONS.played(item("played"), "LeftButton")
assert(x.requested, "a click asks the server")
env.FireEvent("TIME_PLAYED_MSG", 90061, 3700)
eq(text("played"), "1h 1m")
write("strip.playedTotal", true)
eq(text("played"), "1d 1h")
write("strip.playedTotal", false)
env.FireEvent("PLAYER_LEVEL_UP", 39)
eq(text("played"), "0m", "a level-up starts the level's time again")
assert(tooltip("played"):find("Total=1d 1h", 1, true), "the total survives a level-up")

eq(text("audio"), "80%")
write("strip.audioChannel", "Music")
eq(text("audio"), "35%")
x.cvars.Sound_MusicVolume = "0.5"
env.FireEvent("CVAR_UPDATE", "Sound_MusicVolume")
eq(text("audio"), "50%", "a volume change refreshes")
env.SetCombat(true)
ns.Strip.ACTIONS.audio(item("audio"), "LeftButton")
eq(x.cvars.Sound_EnableAllSound, "1", "muting waits for combat to end")
env.SetCombat(false)
ns.Strip.ACTIONS.audio(item("audio"), "LeftButton")
env.FireEvent("CVAR_UPDATE", "Sound_EnableAllSound")
eq(text("audio"), "muted")
ns.Strip.ACTIONS.audio(item("audio"), "LeftButton")
local cvars = x.cvars
x.cvars = {}
ns.Strip.ACTIONS.audio(item("audio"), "LeftButton")
eq(x.cvars.Sound_EnableAllSound, nil, "an unknown mute state is left alone")
x.cvars = cvars
write("strip.audioChannel", "Master")
eq(text("audio"), "80%")

eq(text("prof1"), "Mining")
assert(not shown("prof2"), "no second profession hides its readout")
write("strip.professionText", "values")
eq(text("prof1"), "Mining 225/300")
x.prof2 = 2
env.FireEvent("SKILL_LINES_CHANGED")
eq(text("prof2"), "Herbalism 150/300", "learning a profession shows it")
write("strip.professionText", "name")

-- Each event reaches only its readouts; option-only events wait for their option.
show({ "spec", "time", "itemLevel", "audio", "prof1", "prof2" })
local reads, refreshes, level, getSpec, refresh = 0, 0, env.GetAverageItemLevel, env.C_SpecializationInfo.GetSpecialization, ns.Strip.Refresh
env.GetAverageItemLevel = function(...) reads = reads + 1; return level(...) end
env.C_SpecializationInfo.GetSpecialization = function(...) reads = reads + 1; return getSpec(...) end
ns.Strip.Refresh = function(...) refreshes = refreshes + 1; return refresh(...) end
for _, event in ipairs({ "UPDATE_PENDING_MAIL", "PLAYER_UPDATE_RESTING", "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED" }) do env.FireEvent(event) end
env.FireEvent("CVAR_UPDATE", "cameraDistanceMaxZoomFactor", "1.9")
eq(reads, 0, "unrelated events and options that are off read no other readout")
env.FireEvent("SKILL_LINES_CHANGED")
eq(refreshes, 1, "one skill event refreshes the bar once")
env.GetAverageItemLevel, env.C_SpecializationInfo.GetSpecialization, ns.Strip.Refresh = level, getSpec, refresh
show({ "fps", "latency", "coords", "combat", "played", "audio", "prof1", "prof2", "broker", "time" })

assert(not shown("broker"), "no plugin named hides the readout")
write("strip.brokerPlugin", "Bagnon")
eq(text("broker"), "Bags 42 items")
write("strip.brokerLabel", false)
eq(text("broker"), "42 items")
x.broker.text = "43 items"
ns.Strip.Tick()
eq(text("broker"), "43 items", "the ticker follows the plugin")
write("strip.brokerWidth", 40)
eq(item("broker").valueWidth, 40)
write("strip.brokerWidth", 0)
assert(item("broker").valueWidth ~= 40, "zero follows the text")
ns.Strip.ACTIONS.broker(item("broker"), "LeftButton")
assert(x.clicked, "a click reaches the plugin")
x.clicked = nil
env.SetCombat(true)
ns.Strip.ACTIONS.broker(item("broker"), "LeftButton")
env.SetCombat(false)
eq(x.clicked, nil, "a plugin click waits for combat to end")
write("strip.brokerLabel", true)
write("strip.brokerPlugin", "")

write("strip.placement", "rail")
local list = s.railModules
for _, entry in ipairs(list) do entry.shown = entry.id == "fps" or entry.id == "spacer" or entry.id == "latency" end
local fps, spacer
for i, entry in ipairs(list) do if entry.id == "fps" then fps = i elseif entry.id == "spacer" then spacer = i end end
table.insert(list, fps + 1, table.remove(list, spacer))
write("strip.railModules", list)
assert(shown("spacer") and not item("spacer").dot:IsShown(), "the spacer draws no dot")
assert(not item(list[fps + 2].id).dot:IsShown(), "the readout after a spacer draws no dot")
write("strip.placement", "top")

-- Missing APIs take the safe path.
env.C_Map, env.C_CVar, env.GetProfessions = nil, nil, nil
show({ "coords", "audio", "prof1", "fps" })
eq(text("coords"), "--")
eq(text("audio"), "--")
assert(not shown("prof1"), "missing APIs hide what they cannot read")

-- The preview reflects the options.
show({ "spec", "time", "bags", "itemLevel" })
write("strip.specUpper", true)
write("strip.clockMail", true)
write("strip.bagsDisplay", "usedTotal")
write("strip.itemLevelPrefix", "short")
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(400, 600)
local preview = K.Options.Preview("DataBars")(parent)
local items = preview.strip.items
eq(items.spec.value:GetText(), "SPECIALIZATION")
assert(items.time.value:GetText():find(" mail$"), "preview mail alert")
eq(items.bags.value:GetText(), "58/80")
eq(items.itemLevel.value:GetText(), "ilvl 58")
write("strip.valueColor", "custom")
write("strip.valueCustom", { r = 0, g = 1, b = 0, a = 1 })
preview:Refresh()
eq(color(items.itemLevel.value), "0.000 1.000 0.000", "the preview paints the custom value colour")
write("strip.valueCustom", { r = 1, g = 0, b = 1, a = 1 })
preview:Refresh()
eq(color(items.itemLevel.value), "1.000 0.000 1.000", "the preview repaints a changed custom colour")
show({ "audio", "xp", "bags", "broker" })
write("strip.brokerPlugin", "Bagnon")
preview:Refresh()
local before = { items.audio.value:GetText(), items.xp.value:GetText(), items.bags.value:GetText() }
write("strip.audioChannel", "Music")
write("strip.xpMode", "rep")
write("strip.bagsReagent", true)
preview:Refresh()
for i, id in ipairs({ "audio", "xp", "bags" }) do assert(items[id].value:GetText() ~= before[i], id .. " in the preview follows its option") end
eq(items.broker.value:GetText(), "Bagnon 42", "the preview names the chosen plugin")
for _, key in ipairs({ "audioChannel", "xpMode", "bagsReagent", "brokerPlugin" }) do write("strip." .. key, K.Options.Default("DataBars", "strip." .. key)) end

-- A combat-only timer keeps the ticker even while it hides, so it counts once the fight starts.
write("strip.combatOnly", true)
show({ "combat", "spec" })
assert(not shown("combat"))
env.SetCombat(true)
game.now = game.now + 5
env.RunTickers()
eq(text("combat"), "0:05", "the timer counts in a fight with no other timed readout")
env.SetCombat(false)
write("strip.combatOnly", false)

-- The Medallions dock keeps its muted ink, says so by turning the custom colours off, keeps the low-space warning and draws no dot by a spacer.
env.RunTimers()
for _, entry in ipairs(s.dockModules) do entry.shown = entry.id == "bags" or entry.id == "spacer"; entry.zone = "right" end
write("strip.dockModules", s.dockModules)
write("strip.bagsLow", 50)
eq(item("bags").grade, "low")
eq(color(item("bags").value), token("hostile"), "the low-space warning shows in the dock")
assert(not item("spacer").dot:IsShown(), "no dot beside a spacer in the dock")
assert(disabled("strip.labelCustom") and disabled("strip.labelColor") and disabled("strip.valueCustom"), "the dock's custom colours are off, not silently ignored")
write("strip.bagsLow", 0)
write("strip.placement", "rail")
assert(not disabled("strip.labelCustom"), "the rail takes custom colours")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databars parity ok: new readouts and options keep defaults, apply, restore, follow events and reach the preview")
