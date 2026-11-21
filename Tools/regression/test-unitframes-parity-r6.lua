-- test-unitframes-parity-r6.lua: parity round 6 keeps v0.2.8 frames, then turns on, probes after events and turns off the status icons' corner places, the PvP flag timer's places and the boss values' two decimals, and checks the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local LANES = { "name", "healthText", "healthSub", "powerText", "levelText", "caption", "cast" }
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local PLACED = { "leader", "pvp", "combat", "elite", "marker" }

local function boot(style, wh)
	local saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = style and { style = style } or nil } }, characters = {} }
	return U.New({ saved = saved, width = wh and wh[1], height = wh and wh[2], size = wh and "auto", fit = wh and true })
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function rect(region)
	local p, s = W.LastCall(region, "SetPoint"), W.LastCall(region, "SetSize")
	assert(p and s and p[1] == "CENTER" and p[3] == "TOPLEFT", "a placed icon is centred from the frame's top left")
	return { x = p[4] - s[1] / 2, y = -p[5] - s[2] / 2, w = s[1], h = s[2] }
end

local function overlaps(a, b)
	local t = 0.01
	return a.x + t < b.x + b.w and b.x + t < a.x + a.w and a.y + t < b.y + b.h and b.y + t < a.y + a.h
end

local function region(view, key)
	if key == "marker" then return view.marker end
	if key == "elite" then return view.extraIcon end
	return view.icons[key]
end

local function views(ns)
	local out = {}
	for _, kind in ipairs(U.KINDS) do
		local uf = ns.Frames.Get(kind)
		if uf and uf.active and uf.views[1] and uf.views[1].geometry then out[#out + 1] = uf.views[1] end
	end
	return out
end

local function marks(view, slots)
	local out = {}
	for _, key in ipairs(slots) do out[key] = W.LastCall(view.icons[key], "SetPoint") end
	return out
end

-- 1. A v0.2.8-shaped profile keeps every icon in the status row, the timer after the icons and boss values at one decimal.
local env, K, ns = boot()
local Settings = ns.Settings
for _, kind in ipairs(U.KINDS) do
	for _, key in ipairs({ "leaderPlace", "pvpPlace", "combatPlace", "markerPlace" }) do
		assert(Settings.Value(kind, key) == "", kind .. "." .. key .. " starts in the status row")
	end
end
assert(Settings.Value("player", "pvpTimerPlace") == "" and Settings.Value("target", "elitePlace") == "" and Settings.defaults.player.elitePlace == nil and Settings.defaults.pet.elitePlace == nil, "the timer and elite places start as today")
assert(Settings.Module().healthDecimalPercentOnly == true and not Settings.Snapshot("boss").healthValues, "boss values keep one decimal")
local rows = {}
for _, row in ipairs(Settings.Schema()) do
	if row.key then rows[row.key] = row end
end
for _, key in ipairs({ "player.leaderPlace", "player.pvpPlace", "player.combatPlace", "player.markerPlace", "target.elitePlace", "boss.elitePlace", "player.pvpTimerPlace", "healthDecimalPercentOnly" }) do
	assert(rows[key] and rows[key].help and #rows[key].help < 100, key .. " has a row with help")
end
assert(not rows["player.elitePlace"] and not rows["pet.elitePlace"] and not rows["target.pvpTimerPlace"], "the rows show only where they work")
local module = K.Store.Module("UnitFrames")
assert(not rows["healthDecimalPercentOnly"].showWhen(module), "the boss values switch waits for the boss two decimals")
assert(not rows["player.pvpTimerPlace"].showWhen(module), "the timer place waits for the timer")
local before = {}
for _, view in ipairs(views(ns)) do before[view.kind] = marks(view, ns.Indicators.SLOTS) end
clean(env, K)

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

-- 2. A corner closes the row: the role icon takes the crown's spot, and off puts every icon back exactly.
local player = ns.Frames.Get("player").views[1]
local crown = W.LastCall(player.icons.leader, "SetPoint")
write("player.leaderPlace", "TOPLEFT")
local role = W.LastCall(player.icons.role, "SetPoint")
assert(role[4] == crown[4] and role[5] == crown[5], "the role icon moves up into the crown's place")
assert(rect(player.icons.leader).x < rect(player.icons.role).x, "the crown sits at the left end")
write("player.leaderPlace", "")
for key, call in pairs(before.player) do
	local now = W.LastCall(player.icons[key], "SetPoint")
	assert(now[4] == call[4] and now[5] == call[5], key .. " returns to its exact place")
end

-- 2b. The text bar counts as the frame's text: a corner on its edge steps past it.
for _, place in ipairs({ "BOTTOM", "TOP" }) do
	write("player.textBar", true)
	write("player.textBarPlace", place)
	write("player.combatPlace", place .. "LEFT")
	assert(player.barRect and not overlaps(rect(player.icons.combat), player.barRect), place .. ": the swords keep off the text bar")
end
write("player.combatPlace", "")
write("player.textBarPlace", "BOTTOM")
write("player.textBar", false)

-- 3. Every corner on every frame and HUD style, and at the four test screens: placed icons never cross the frame's text
-- and no two icons overlap, with the PvP timer's room beside the badge.
local function sweep(e, k, n, label)
	local W2 = function(key, value) k.Options.Write("UnitFrames", key, value) end
	for _, view in ipairs(views(n)) do
		n.Indicators.Extra(view, nil, view.kind == "pet" and 3 or "elite")
		for _, corner in ipairs(CORNERS) do
			for _, key in ipairs(PLACED) do
				if n.Settings.defaults[view.kind][key .. "Place"] ~= nil then W2(view.kind .. "." .. key .. "Place", corner) end
			end
			e.RunTimers()
			local g, boxes = view.geometry, {}
			for _, key in ipairs(PLACED) do
				local r = region(view, key)
				if r and view.spots[key] and n.Settings.defaults[view.kind][key .. "Place"] ~= nil then
					local box = rect(r)
					for _, lane in ipairs(LANES) do
						assert(not (g[lane] and g[lane].w > 0 and overlaps(box, g[lane])), label .. " " .. view.kind .. " " .. corner .. ": " .. key .. " crosses the " .. lane)
					end
					boxes[#boxes + 1] = { key, box }
				end
			end
			for _, key in ipairs(n.Indicators.SLOTS) do
				if n.Settings.defaults[view.kind][key .. "Place"] == nil then boxes[#boxes + 1] = { key, rect(view.icons[key]) } end
			end
			for i = 1, #boxes do
				for j = i + 1, #boxes do
					assert(not overlaps(boxes[i][2], boxes[j][2]), label .. " " .. view.kind .. " " .. corner .. ": " .. boxes[i][1] .. " overlaps " .. boxes[j][1])
				end
			end
		end
		for _, key in ipairs(PLACED) do
			if n.Settings.defaults[view.kind][key .. "Place"] ~= nil then W2(view.kind .. "." .. key .. "Place", "") end
		end
	end
	e.RunTimers()
	clean(e, k)
end
sweep(env, K, ns, "frames")
for _, style in ipairs({ "medallions", "orbs" }) do
	local e, k, n = boot(style)
	sweep(e, k, n, style)
end
for _, wh in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local e, k, n = boot(nil, wh)
	sweep(e, k, n, wh[1] .. "x" .. wh[2])
end

-- 4. Events: an elite target arriving after the layout takes its corner, and a style switch keeps the corners clear.
local fresh, FK, fn = boot()
FK.Options.Write("UnitFrames", "target.elite", true)
FK.Options.Write("UnitFrames", "target.elitePlace", "BOTTOMRIGHT")
fresh.RunTimers()
U.SetUnit(fresh, "target", { name = "Ogre", level = 62, health = 50, healthMax = 100, reaction = 2, canAttack = true, classification = "elite" })
fresh.FireEvent("PLAYER_TARGET_CHANGED")
local tv = fn.Frames.Get("target").views[1]
assert(tv.extraIcon and tv.extraIcon:IsShown(), "the elite badge shows")
local spot = tv.spots.elite
local box = rect(tv.extraIcon)
assert(math.abs(box.x + box.w / 2 - spot.x) < 1 and math.abs(box.y + box.h / 2 - spot.y) < 1, "a badge made after the layout sits on its corner")
FK.Options.Write("HudStyle", "style", "medallions")
fresh.RunTimers()
box = rect(tv.extraIcon)
assert(math.abs(box.x + box.w / 2 - tv.spots.elite.x) < 1, "a style switch moves the badge to the new frame's corner")
FK.Options.Write("HudStyle", "style", "frames")
FK.Options.Write("UnitFrames", "target.elitePlace", "")
fresh.RunTimers()
assert(W.LastCall(tv.extraIcon, "SetAllPoints") and not tv.spots.elite, "off puts the badge back in the resting slot")
clean(fresh, FK)

-- 5. A cornered raid marker leaves the name whole; off cuts the name's lane again where the marker meets it.
local boss = ns.Frames.Get("boss").views[1]
U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 41270, healthMax = 100000, reaction = 2, canAttack = true, raidTarget = 8 })
env.GetRaidTargetIndex = function(token) return token == "boss1" and 8 or nil end
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.FireEvent("RAID_TARGET_UPDATE")
assert(boss.marker:IsShown(), "the boss shows its marker")
local cut = boss.geometry.markedName ~= nil and boss.markerCut == true
write("boss.markerPlace", "TOPRIGHT")
env.FireEvent("RAID_TARGET_UPDATE")
assert(boss.marker:IsShown() and not boss.markerCut, "a cornered marker leaves the name whole")
box = rect(boss.marker)
assert(math.abs(box.x + box.w / 2 - boss.spots.marker.x) < 1, "the marker sits on its corner")
write("boss.markerPlace", "")
env.FireEvent("RAID_TARGET_UPDATE")
assert((boss.markerCut == true) == cut, "off restores the marker's own place and the name's cut")

-- 6. PvP timer places: beside the badge the row makes room; above and below take the outside where text would be crossed.
local me = env._units.player
me.pvp, me.faction = true, "Alliance"
env.IsPVPTimerRunning, env.GetPVPTimer = function() return true end, function() return 272000 end
write("player.pvpTimer", true)
env.FireEvent("PVP_TIMER_UPDATE", "player")
assert(player.pvpTimer:IsShown() and U.Shown(env, player.pvpTimer) == "4:32", "the timer counts down")
local after = W.LastCall(player.pvpTimer, "SetPoint")
assert(after[2] == player.icons.resting, "by default the timer follows the status icons")
local room = (2.2 * Settings.Value("player", "pvpTimerSize") * K.Theme.FontScale())
for _, side in ipairs({ "LEFT", "RIGHT" }) do
	write("player.pvpTimerPlace", side)
	local p = W.LastCall(player.pvpTimer, "SetPoint")
	assert(p[2] == player.icons.pvp and p[1] == (side == "LEFT" and "RIGHT" or "LEFT"), side .. ": the timer sits beside the badge")
	local badge = rect(player.icons.pvp)
	local neighbour = side == "LEFT" and rect(player.icons.combat) or rect(player.icons.role)
	local free = side == "LEFT" and badge.x - (neighbour.x + neighbour.w) or neighbour.x - (badge.x + badge.w)
	assert(free >= room + 2 - 1, side .. ": the row leaves the timer its room: " .. free)
end
write("player.pvpTimerPlace", "BOTTOM")
local g = player.geometry
local below = { x = player.spots.pvp.x - room / 2, y = player.spots.pvp.y + player.spots.pvp.size / 2 + 2, w = room, h = room / 2.2 }
local crosses = false
for _, lane in ipairs(LANES) do crosses = crosses or g[lane] and g[lane].w > 0 and overlaps(below, g[lane]) end
assert(player.timerSide == (crosses and "TOP" or "BOTTOM"), "below the top-edge badge the timer takes the outside only where text would be crossed")
write("player.pvpPlace", "BOTTOMLEFT")
write("player.pvpTimerPlace", "TOP")
assert(player.timerSide == "BOTTOM", "above a bottom-corner badge crosses the power text, so the timer goes below")
local p = W.LastCall(player.pvpTimer, "SetPoint")
assert(p[1] == "TOP" and p[3] == "BOTTOM" and p[2] == player.icons.pvp, "the timer hangs under the badge")
write("player.pvpTimerX", 5)
assert(W.LastCall(player.pvpTimer, "SetPoint")[4] > p[4], "the timer's offsets still move it")
write("player.pvpTimerX", 0)

-- 7. No hot-path work: unit events do not place icons or the timer again.
local function count()
	local n = #W.Calls(player.pvpTimer, "SetPoint")
	for _, key in ipairs(ns.Indicators.SLOTS) do n = n + #W.Calls(player.icons[key], "SetPoint") end
	return n
end
local placed = count()
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION", "PLAYER_FLAGS_CHANGED", "PVP_TIMER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	env.FireEvent(event, "player")
end
env.RunTimers()
assert(count() == placed, "unit events place nothing again")

-- 8. The preview shows the corners and the timer's place.
write("player.leaderPlace", "TOPLEFT")
write("edit", "player")
local pane = ns.Preview.Build(env.UIParent)
pane:Refresh()
local sample = pane.views.player
assert(sample.spots.leader.x < sample.spots.role.x and sample.spots.pvp.y > sample.geometry.glass.y and sample.timerSide == "BOTTOM", "the preview takes the corners and the timer's side")
assert(sample.pvpTimer and sample.pvpTimer:IsShown() and W.LastCall(sample.pvpTimer, "SetPoint")[2] == sample.icons.pvp, "the preview's timer sits by the badge")
for _, key in ipairs({ "player.leaderPlace", "player.pvpPlace", "player.pvpTimerPlace" }) do write(key, "") end
pane:Refresh()
assert(sample.spots.leader.x > sample.spots.role.x and sample.spots.pvp.y == sample.geometry.glass.y and W.LastCall(sample.pvpTimer, "SetPoint")[2] == sample.icons.resting, "off restores the preview")
write("player.pvpTimer", false)
assert(not player.pvpTimer:IsShown(), "the timer goes with its switch")
for key, call in pairs(before.player) do
	local now = W.LastCall(player.icons[key], "SetPoint")
	assert(now[4] == call[4] and now[5] == call[5], key .. " ends where it began")
end
clean(env, K)

-- 9. Boss values: two decimals with the switch off, live, after health changes, secret and queued in combat; one when on.
write("boss.healthText", "currentMax")
write("healthDecimalBoss", true)
assert(rows["healthDecimalPercentOnly"].showWhen(module), "the switch shows with the boss two decimals")
assert(U.Shown(env, boss.healthText) == "41.2K / 100K", "percentages only keeps one decimal: " .. U.Shown(env, boss.healthText))
local narrow = boss.geometry.healthText.w
env.SetCombat(true)
write("healthDecimalPercentOnly", false)
assert(U.Shown(env, boss.healthText) == "41.2K / 100K", "a change in combat waits")
env.SetCombat(false)
env.RunTimers()
assert(U.Shown(env, boss.healthText) == "41.27K / 100K", "values take two decimals: " .. U.Shown(env, boss.healthText))
assert(boss.geometry.healthText.w > narrow, "the value column widens for the second decimal")
env._units.boss1.health = 240550
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(env.issecretvalue(env.UnitHealth("boss1")), "the boss's health reaches the text as a secret")
assert(U.Shown(env, boss.healthText) == "240.55K / 100K", "a secret value takes two decimals: " .. U.Shown(env, boss.healthText))
assert(U.Shown(env, ns.Frames.Get("target").views[1].healthText):find("%.%d%dK") == nil, "other frames keep one decimal")
write("edit", "boss")
pane:Refresh()
assert(U.Shown(env, pane.views.boss.healthText) == "72.43K / 100.6K", "the preview shows the boss values' two decimals: " .. U.Shown(env, pane.views.boss.healthText))
write("healthDecimalPercentOnly", true)
pane:Refresh()
assert(U.Shown(env, boss.healthText) == "240.5K / 100K" and boss.geometry.healthText.w == narrow, "on restores one decimal and the column")
assert(U.Shown(env, pane.views.boss.healthText) == "72K / 100K", "and the preview's sample: " .. U.Shown(env, pane.views.boss.healthText))
clean(env, K)

-- 10. A formatter that cannot write two decimals keeps secret values at one; plain values still take two.
local odd, OK, on = U.New({ saved = { version = U.DbVersion(), characters = {}, profiles = { Default = { UnitFrames = { enabled = true, healthDecimalBoss = true, healthDecimalPercentOnly = false, boss = { healthText = "currentMax" } } } } } })
local game = odd.AbbreviateNumbers
odd.AbbreviateNumbers = function(value, options)
	if options and options.breakpointData and options.breakpointData[3].fractionDivisor == 100 then return "240.550K" end
	return game(value, options)
end
U.SetUnit(odd, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 240550, healthMax = 1250000, reaction = 2, canAttack = true })
odd.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(U.Shown(odd, on.Frames.Get("boss").views[1].healthText) == "240.5K / 1.25M", "a refused probe keeps the secret at one decimal: " .. U.Shown(odd, on.Frames.Get("boss").views[1].healthText))
clean(odd, OK)

-- 11. Review probes (c8668917), switched on: each failed before its fix.
local file = assert(io.open("KstyleUI_UnitFrames/Format.lua", "rb"))
local source = file:read("*a")
file:close()
assert(not source:find("and TwoPlaces%b() or") and not source:find("and AbbreviateNumbers%b() or"), "a secret formatter result meets a boolean test: branch on the option, then return the formatter's result")
local e2, k2, n2 = boot()
local function set(key, value)
	k2.Options.Write("UnitFrames", key, value)
	e2.RunTimers()
end
local pv = n2.Frames.Get("player").views[1]
local sink = { SetText = function() end, SetFormattedText = function() end }
U.SetUnit(e2, "focus", { name = "Ogre", classification = "elite", level = 62, health = 240550, healthMax = 1250000, reaction = 2, canAttack = true, combat = true })
n2.Indicators.Layout(pv, pv.geometry, pv.s)
n2.Format.Health(sink, "focus", "currentMax")
local Budget = dofile("Tools/regression/instruction_budget.lua")
Budget(function() for _ = 1, 100 do n2.Indicators.Layout(pv, pv.geometry, pv.s) end end, 210000, "skip the corner work while no icon is cornered")
Budget(function() for _ = 1, 2000 do n2.Format.Health(sink, "focus", "currentMax") end end, 315000, "choose the value formatter once per write")
for _, pair in ipairs({ { "focus.combat", true }, { "focus.elite", true }, { "focus.iconSize", 32 } }) do set(pair[1], pair[2]) end
e2.FireEvent("PLAYER_FOCUS_CHANGED")
e2.FireEvent("UNIT_FLAGS", "focus")
local fv = n2.Frames.Get("focus").views[1]
assert(fv.extraIcon:IsShown() and fv.icons.combat:IsShown(), "the focus shows its elite badge and combat swords")
for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT" }) do
	set("focus.elitePlace", corner)
	for _, key in ipairs(n2.Indicators.SLOTS) do
		assert(not overlaps(rect(fv.extraIcon), rect(fv.icons[key])), corner .. ": the elite badge keeps clear of the status row's " .. key)
	end
end
local tv2 = n2.Frames.Get("target").views[1]
U.SetUnit(e2, "target", { name = "Ogre", classification = "elite", level = 62, health = 50, healthMax = 100, reaction = 2, canAttack = true })
e2.GetRaidTargetIndex = function() return 8 end
e2.FireEvent("PLAYER_TARGET_CHANGED")
set("target.markerPlace", "TOPRIGHT")
local alone = W.LastCall(tv2.marker, "SetPoint")[4]
set("target.elite", true)
set("target.elitePlace", "TOPRIGHT")
assert(W.LastCall(tv2.marker, "SetPoint")[4] ~= alone, "the elite badge shares the marker's corner")
set("target.elite", false)
assert(W.LastCall(tv2.marker, "SetPoint")[4] == alone, "a switched-off icon leaves its corner's run")
clean(e2, k2)
print("test-unitframes-parity-r6: ok")
