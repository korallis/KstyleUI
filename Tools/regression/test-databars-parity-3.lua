-- test-databars-parity-3.lua: round 3 of the data bar's EllesmereUI parity (per-readout icons, text and icon colour, the second data bar, per-click travel text) keeps today's defaults, applies when on, restores when off, follows its events and reaches the preview.
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(a, b, why) assert(a == b, (why or "value") .. ": " .. tostring(a) .. " differs from " .. tostring(b)) end

local OLD = { "gold", "latency", "fps", "durability", "time", "spec", "guild", "friends", "bags", "currencies", "xp", "location", "itemLevel" }
local old = {}
for i, id in ipairs(OLD) do old[i] = { id = id, shown = i <= 10, zone = id == "time" and "centre" or "right" } end

local spells, readouts = {}, nil
local env, K, ns = D.New({
	saved = { version = 42, profiles = { Default = { DataBars = { enabled = true, strip = { modules = old } } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
	setup = function(e)
		D.Menus(e)
		readouts = Fixture(e)
		e.C_Spell = {
			GetSpellInfo = function(id) return ({ [556] = { name = "Astral Recall" }, [3561] = { name = "Teleport: Stormwind" } })[id] end,
			GetSpellCooldown = function(id) return spells[id] end,
		}
	end,
})
K.Safe.Side(K).travelData = {
	Hearth = function() return "Stormwind", "ready" end,
	Read = function() return { { { kind = "item", id = 6948, name = "Hearthstone" }, { kind = "spell", id = 556, name = "Astral Recall" } }, { { kind = "spell", id = 3561, name = "Teleport: Stormwind" } }, {} } end,
}

local function write(key, value) assert(K.Options.Write("DataBars", key, value) ~= false, key); env.RunTimers() end
local function item(id, view) return (view or ns.Strip.view).items[id] end
local function text(id, view) return item(id, view).value:GetText() end
local function settings() return K.Store.Module("DataBars") end
local function row(key) return K.Options.Row("DataBars", key) end
local function disabled(key) local r = row(key); return r.disableWhen ~= nil and r.disableWhen(settings()) == true end
local function hidden(key) local r = row(key); return r.showWhen ~= nil and r.showWhen(settings()) ~= true end
local function rgb(r, g, b) return string.format("%.3f %.3f %.3f", r, g, b) end
local function tint(texture) return rgb(texture:GetVertexColor()) end
local function rect(region) return Scene.Rect(env, region) end
local function show(ids, key)
	local s, want = settings().strip, {}
	key = key or "modules"
	for i, id in ipairs(ids) do want[id] = i end
	table.sort(s[key], function(a, b) return (want[a.id] or 99) < (want[b.id] or 99) end)
	for _, entry in ipairs(s[key]) do entry.shown = want[entry.id] ~= nil end
	write("strip." .. key, s[key])
end
local function apart(view)
	local order = view.order
	for i = 1, #order do
		for j = i + 1, #order do
			local ax, _, aw = rect(item(order[i], view).button)
			local bx, _, bw = rect(item(order[j], view).button)
			assert(ax + aw <= bx + 0.01 or bx + bw <= ax + 0.01, order[i] .. " overlaps " .. order[j])
		end
	end
end
local durabilityReads, durability = 0, env.GetInventoryItemDurability
env.GetInventoryItemDurability = function(...) durabilityReads = durabilityReads + 1 return durability(...) end
local function listens()
	local before = durabilityReads
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	return durabilityReads > before
end

-- Defaults keep today's look; a v0.2.8 profile loads with the second bar off and unbuilt, and its readout list filled.
local s = settings().strip
for id in pairs(ns.Strip.GLYPH_CELLS) do
	eq(s.blocks[id].show, "bar", id .. " show")
	eq(s.blocks[id].iconColor, "bar", id .. " icon colour")
end
eq(s.second, false, "second bar")
eq(s.hearthLeftText, "none", "left click text")
eq(s.hearthRightText, "none", "right click text")
eq(s.hearthMiddleText, "none", "middle click text")
eq(s.modules[1].id, "gold", "the saved order survives")
eq(#s.secondModules, #s.modules - 1, "the second list holds every readout but the micro menu")
for _, entry in ipairs(s.secondModules) do assert(not entry.shown and entry.id ~= "micro", entry.id .. " starts off in the second list") end
eq(ns.Strip.second, nil, "the second bar builds nothing until it is turned on")
eq(K.Layout.Element("databars.strip2"), nil, "nor registers its Layout element")
assert(K.Options.Get("DataBars"), "the schema builds with every new row")

-- Per-readout Shows: Icon and value gives one readout its glyph with the bar's icons off; Data bar's choice restores.
show({ "fps", "latency", "gold", "coords", "time" })
local widths = {}
for _, id in ipairs({ "fps", "latency", "gold" }) do widths[id] = item(id).button:GetWidth() end
assert(hidden("strip.blocks.durability.show") and not hidden("strip.blocks.latency.show"), "a readout's rows show while it is on")
write("strip.blocks.latency.show", "both")
assert(item("latency").icon and item("latency").icon:IsShown(), "latency shows its own glyph")
assert(item("latency").button:GetWidth() > widths.latency, "and widens for it")
assert(not (item("fps").icon and item("fps").icon:IsShown()), "the others keep the bar's choice")
eq(item("fps").button:GetWidth(), widths.fps, "fps keeps its width")
apart(ns.Strip.view)
write("strip.blocks.gold.show", "icon")
assert(item("gold").icon:IsShown() and not item("gold").value:IsShown(), "gold shows its glyph alone")
eq(item("gold").button:GetWidth(), item("gold").icon:GetWidth(), "and narrows to it")
apart(ns.Strip.view)
write("strip.icons", "beside")
write("strip.blocks.fps.show", "value")
assert(not item("fps").icon:IsShown() and item("coords").icon:IsShown(), "Value only drops one glyph while the bar shows icons")
eq(item("fps").button:GetWidth(), widths.fps, "and keeps the plain width")
apart(ns.Strip.view)
for _, id in ipairs({ "fps", "latency", "gold" }) do write("strip.blocks." .. id .. ".show", "bar") end
write("strip.icons", "off")
for _, id in ipairs({ "fps", "latency", "gold" }) do
	assert(not item(id).icon:IsShown() and item(id).value:IsShown(), id .. " restores")
	eq(item(id).button:GetWidth(), widths[id], id .. " width restores")
end

-- Per-readout icon colour overrides the bar's, independently of the bar's icons; Data bar's colour restores.
write("strip.blocks.latency.show", "both")
assert(not disabled("strip.blocks.latency.iconColor") and disabled("strip.blocks.gold.iconColor"), "the colour row follows the readout's own glyph")
eq(tint(item("latency").icon), rgb(item("latency").label:GetTextColor()), "the bar's colour is the label colour")
write("strip.blocks.latency.iconColor", "accent")
eq(tint(item("latency").icon), rgb(ns.Accent()), "accent glyph")
assert(hidden("strip.blocks.latency.iconCustom"), "the custom colour waits for Custom")
write("strip.blocks.latency.iconColor", "custom")
write("strip.blocks.latency.iconCustom", { r = 0, g = 1, b = 0, a = 1 })
eq(tint(item("latency").icon), "0.000 1.000 0.000", "custom glyph")
write("strip.iconColor", "accent")
eq(tint(item("latency").icon), "0.000 1.000 0.000", "the readout's own colour wins over the bar's")
write("strip.blocks.latency.iconColor", "bar")
eq(tint(item("latency").icon), rgb(ns.Accent()), "Data bar's colour follows the bar's choice again")
write("strip.iconColor", "label")
write("strip.blocks.latency.show", "bar")

-- Cells have no icons, so the per-readout rows turn off there; the dock keeps its own glyphs.
write("strip.placement", "rail")
write("strip.line", false)
assert(disabled("strip.blocks.fps.show") and disabled("strip.blocks.fps.iconColor"), "cells turn the rows off")
write("strip.line", true)
write("strip.placement", "top")

-- Travel text: the Hearthstone keeps its text; each click with its own spell or item adds its text after a middle dot.
show({ "hearth", "fps" })
eq(text("hearth"), "ready Stormwind", "today's text")
write("strip.hearthLeft", "spell:556")
eq(text("hearth"), "ready Stormwind", "a saved left click keeps the Hearthstone's text")
write("strip.hearthLeft", "")
assert(disabled("strip.hearthLeftText") and disabled("strip.hearthRightText") and disabled("strip.hearthMiddleText"), "a click's text waits for its click")
write("strip.hearthRight", "spell:556")
write("strip.hearthMiddle", "item:6948")
eq(text("hearth"), "ready Stormwind", "None adds nothing")
write("strip.hearthRightText", "location")
eq(text("hearth"), "ready Stormwind \194\183 Astral Recall", "the right click's destination")
spells[556] = { startTime = 50, duration = 900, isEnabled = true, isActive = true, modRate = 1 }
write("strip.hearthRightText", "smart")
eq(text("hearth"), "ready Stormwind \194\183 15m", "the right click's cooldown while it runs")
spells[556].isOnGCD = true
ns.Strip.Tick()
eq(text("hearth"), "ready Stormwind \194\183 15m", "Forever trusts isOnGCD only inside SPELL_UPDATE_COOLDOWN, so a stale flag never reads ready")
spells[556] = env.Secret({})
ns.Strip.Tick()
eq(text("hearth"), "ready Stormwind \194\183 --", "a secret cooldown reads --, never ready")
write("strip.hearthRightText", "cooldown")
eq(text("hearth"), "ready Stormwind \194\183 --", "the cooldown alone reads -- too")
spells[556] = nil
write("strip.hearthMiddleText", "both")
eq(text("hearth"), "ready Stormwind \194\183 -- \194\183 ready Stormwind", "the Hearthstone on the middle click reads its home")
write("strip.hearthLeft", "spell:3561")
write("strip.hearthLeftText", "location")
eq(text("hearth"), "ready Stormwind \194\183 Teleport: Stormwind \194\183 -- \194\183 ready Stormwind", "the left click adds its own text")
local calls, info = 0, env.C_Spell.GetSpellInfo
env.C_Spell.GetSpellInfo = function(id) calls = calls + 1 return info(id) end
ns.Strip.Tick()
ns.Strip.Tick()
eq(calls, 0, "names are read once, not every second")
env.C_Spell.GetSpellInfo = info
for _, key in ipairs({ "hearthLeft", "hearthRight", "hearthMiddle" }) do write("strip." .. key, "") end
for _, key in ipairs({ "hearthLeftText", "hearthRightText", "hearthMiddleText" }) do write("strip." .. key, "none") end
eq(text("hearth"), "ready Stormwind", "off restores today's text")

-- The second bar: built when turned on, a copy of the main bar's readouts, live in Layout Mode, and gone when off.
show({ "fps", "gold", "time" })
write("strip.second", true)
local second = ns.Strip.second
assert(second and second.frame:IsVisible(), "turning it on builds and shows the second bar")
assert(K.Layout.Element("databars.strip2") and K.Layout.Live("databars.strip2"), "it is live in Layout Mode")
eq(table.concat(second.order, ","), "fps,gold,time", "it starts as a copy of the main bar's readouts")
local sx, sy, sw, sh = rect(second.frame)
local crest = 0
for _, art in ipairs(ns.Strip.view.art) do
	local ax, ay, aw, ah = rect(art)
	if art:IsShown() and ax then
		crest = crest + 1
		assert(ax + aw <= sx or sx + sw <= ax or ay + ah <= sy or sy + sh <= ay, "the second bar's default place clears the top bar's crest and brackets")
	end
end
assert(crest > 0, "the forged top bar shows its crest")
assert(not hidden("strip.secondModules"), "its module list shows")
eq(text("gold", second), text("gold"), "the same values")
show({ "coords", "latency", "durability" }, "secondModules")
eq(table.concat(second.order, ","), "coords,latency,durability", "its own list")
eq(table.concat(ns.Strip.view.order, ","), "fps,gold,time", "the main bar keeps its list")
apart(second)
write("strip.placement", "rail")
write("strip.orientation", "VERTICAL")
local hx, hy, hw, hh = rect(second.frame)
for _, id in ipairs(second.order) do
	local bx, by, bw, bh = rect(item(id, second).button)
	assert(bx >= hx - 0.01 and by >= hy - 0.01 and bx + bw <= hx + hw + 0.01 and by + bh <= hy + hh + 0.01, id .. " stays inside the second bar's Layout Mode footprint while the main bar is a column")
end
write("strip.orientation", "HORIZONTAL")
write("strip.placement", "top")
show({ "currencies" }, "secondModules")
local refresh, refreshes = ns.Strip.Refresh, 0
ns.Strip.Refresh = function(...) refreshes = refreshes + 1 return refresh(...) end
env.FireEvent("CURRENCY_DISPLAY_UPDATE")
eq(refreshes, 0, "a currency event that changes no readout rebuilds neither bar")
local tracked = readouts.currencies
readouts.currencies = {}
env.FireEvent("CURRENCY_DISPLAY_UPDATE")
ns.Strip.Refresh = refresh
assert(not item("currencies", second).button:IsShown(), "untracking the last currency hides the second bar's readout")
readouts.currencies = tracked
show({ "fps" }, "secondModules")
write("strip.enabled", false)
local newTicker, scripts, ticked = env.C_Timer.NewTicker, {}, false
for _, child in ipairs({ K.Scale.Root():GetChildren() }) do scripts[child] = child:GetScript("OnUpdate") end
env.C_Timer.NewTicker = nil
write("strip.second", false)
write("strip.second", true)
for _, child in ipairs({ K.Scale.Root():GetChildren() }) do
	local script = child:GetScript("OnUpdate")
	if script and script ~= scripts[child] and child:IsVisible() then
		env._game.fps = 61
		script(child, 1)
		ticked = ticked or text("fps", second) == "61"
	end
end
assert(ticked, "without C_Timer.NewTicker a visible frame counts the seconds for the second bar while the main bar is off")
env.C_Timer.NewTicker = newTicker
write("strip.enabled", true)
show({ "coords", "latency", "durability" }, "secondModules")
assert(listens(), "the second bar's readouts listen for their events")
env._game.durability[1] = { 40, 100 }
env.FireEvent("UPDATE_INVENTORY_DURABILITY")
eq(text("durability", second), "40%", "and follow them")
write("strip.enabled", false)
assert(second.frame:IsVisible() and listens(), "the second bar does not need the main bar")
env._game.durability[1] = { 50, 100 }
env.FireEvent("UPDATE_INVENTORY_DURABILITY")
eq(text("durability", second), "50%", "its values update with the main bar off")
write("strip.enabled", true)
write("strip.blocks.durability.show", "both")
assert(item("durability", second).icon and item("durability", second).icon:IsShown(), "per-readout icons reach the second bar")
apart(second)
write("strip.blocks.durability.show", "bar")
local layout = K.Layout.Get("databars.strip2")
assert(K.Layout.Update("databars.strip2", { width = 400, height = layout.height }), "Layout Mode resizes it")
eq(second.frame:GetWidth(), 400, "the readouts follow the new width")
env.SetCombat(true)
write("strip.second", false)
assert(second.frame:IsShown(), "turning it off waits for combat to end")
env.SetCombat(false)
env.RunTimers()
assert(not second.frame:IsShown() and not K.Layout.Live("databars.strip2"), "off hides it and takes it out of Layout Mode")
assert(not listens(), "its readouts stop listening")
write("strip.second", true)
eq(table.concat(second.order, ","), "coords,latency,durability", "turning it on again keeps its own list")
write("strip.second", false)
local Layouts = K.Setup.Layouts
eq(Layouts.Enabled("DPS")["databars.strip2"], false, "every setup preset starts with the second bar off")

-- The Medallions dock keeps its own glyphs; a second bar's line takes the icon rows there.
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(ns.Strip.view.deco and disabled("strip.icons") and disabled("strip.blocks.fps.show") and disabled("strip.blocks.fps.iconColor"), "the dock keeps its own glyphs")
write("strip.second", true)
assert(not disabled("strip.icons") and not disabled("strip.blocks.coords.show"), "a second bar's line takes the icon rows")
write("strip.blocks.coords.show", "both")
assert(item("coords", second).icon:IsShown() and not disabled("strip.blocks.coords.iconColor"), "and draws them beside the dock")
apart(second)
write("strip.blocks.coords.show", "bar")
write("strip.second", false)
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()

-- The preview reflects the new options.
show({ "fps", "latency", "hearth" })
write("strip.blocks.latency.show", "both")
write("strip.hearthRight", "spell:556")
write("strip.hearthRightText", "location")
write("strip.second", true)
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(400, 600)
local preview = K.Options.Preview("DataBars")(parent)
assert(preview.strip.items.latency.icon and preview.strip.items.latency.icon:IsShown(), "preview per-readout icon")
eq(preview.strip.items.hearth.value:GetText(), "ready Stormwind \194\183 Astral Recall", "preview travel text")
assert(preview.second and preview.second.frame:IsShown(), "preview second bar")
eq(table.concat(preview.second.order, ","), "coords,latency,durability", "the preview's second bar shows its readouts")
write("strip.second", false)
preview:Refresh()
assert(not preview.second.frame:IsShown(), "preview second bar off")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databars parity 3 ok: per-readout icons, text and icon colour, the second data bar and per-click travel text keep defaults, apply, restore and follow events")
