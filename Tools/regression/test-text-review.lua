-- test-text-review.lua: review regressions keep saved orb text, filtered events, one paint and shared text rows.
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local failures = {}
local function check(ok, message)
	if not ok then failures[message] = true end
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = U.New({ width = screen[1], height = screen[2], plate = true })
	K.Options.Write("UnitFrames", "player.healthText", "none")
	env.FireEvent("UNIT_HEALTH", "player")
	check(U.Shown(env, ns.Orbs.Get("health").value) == "3.1K / 3.9K", "orb: a saved Frames None must preserve the blank-format orb preset")
	K.Options.Write("UnitFrames", "player.healthText", "both")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "[hp:abr]")
	env.RunTimers()
	local calls, paint = 0, K.Widgets.TagText
	K.Widgets.TagText = function(...) calls = calls + 1; return paint(...) end
	env.FireEvent("UNIT_HEALTH", "player")
	check(calls == 1, "paint: unit health events must paint each custom slot once")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "literal [pp]")
	env.RunTimers()
	local view = ns.Frames.Get("player").views[1]
	local before = U.Shown(env, view.healthText)
	env.FireEvent("UNIT_HEALTH", "player")
	check(U.Shown(env, view.healthText) == before, "paint: unrelated health updates must preserve custom power text")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "[hp:max]")
	env.RunTimers()
	env._units.player.healthMax = 8000
	env.FireEvent("UNIT_MAXHEALTH", "player")
	check(U.Shown(env, view.healthText) == "8000", "paint: maximum health events must refresh health tags")
	K.Options.Write("UnitFrames", "player.fonts.health.textFormat", "[pp:max]")
	env.RunTimers()
	env._units.player.powerMax = 120
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	check(U.Shown(env, view.healthText) == "120", "paint: power type events must refresh power tags")
	local lists, iterate = {}, env.ipairs
	env.ipairs = function(t)
		if t[1] == "name" and t[2] == "health" then lists[t] = true end
		return iterate(t)
	end
	env.FireEvent("UNIT_HEALTH", "player")
	env.FireEvent("UNIT_HEALTH", "player")
	local count = 0
	for _ in pairs(lists) do count = count + 1 end
	check(count == 1, "allocation: reuse the unit tag element list across events")
	U.SetUnit(env, "targettarget", { health = 3000, healthMax = 6000 })
	K.Options.Write("UnitFrames", "targettarget.fonts.health.textFormat", "[hp:abr]")
	env.FireEvent("UNIT_TARGET", "target")
	env.RunTimers()
	env._units.targettarget.health = 1500
	env.RunTickers()
	check(U.Shown(env, ns.Frames.Get("targettarget").views[1].healthText) == "1.5K",
		"paint: the existing target-of-target poll must refresh custom text")

	local e, P, n = N.New({ width = screen[1], height = screen[2] })
	N.Add(e, "nameplate1", { name = "Kobold", health = 100, maxHealth = 200, level = 10 })
	local plate = n.Plates.Get("nameplate1")
	local events = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_TARGET" }
	local function registered(event)
		for _, frame in ipairs(e._frames) do
			if frame._events[event] then return frame._events[event] end
		end
	end
	for _, event in ipairs(events) do check(not registered(event), "events: default plates must not subscribe to unused tag fields") end
	P.Options.Write("Nameplates", "healthText.show", true)
	P.Options.Write("Nameplates", "healthText.textFormat", "[hp:abr] [pp] [absorb] [target]")
	e.RunTimers()
	for _, event in ipairs(events) do
		local units = registered(event)
		check(type(units) == "table" and units[1] == "nameplate1", "events: optional tag subscriptions must filter their plate unit")
	end
	local paints, original = 0, P.Widgets.TagText
	P.Widgets.TagText = function(...) paints = paints + 1; return original(...) end
	e.FireEvent("UNIT_HEALTH", "nameplate1")
	check(paints == 1, "paint: plate health events must paint each custom slot once")
	paints = 0
	e.FireEvent("UNIT_POWER_UPDATE", "party1")
	check(paints == 0, "events: other units must not paint the plate")
	paints = 0
	plate:Refresh()
	check(paints == 1, "paint: plate refresh must paint each custom slot once")
	local seen, ipairsPlate = {}, e.ipairs
	e.ipairs = function(t)
		if t[1] == "name" and t[2] == "healthText" then seen[t] = true end
		return ipairsPlate(t)
	end
	e.FireEvent("UNIT_HEALTH", "nameplate1")
	e.FireEvent("UNIT_HEALTH", "nameplate1")
	count = 0
	for _ in pairs(seen) do count = count + 1 end
	check(count == 1, "allocation: reuse the plate tag element list across events")
	P.Options.Write("Nameplates", "healthText.textFormat", "")
	e.RunTimers()
	for _, event in ipairs(events) do check(not registered(event), "events: clearing formats must remove optional subscriptions") end

	local schema = P.Options.Get("Nameplates")
	local rows = {}
	for _, row in ipairs(schema) do if row.key then rows[row.key] = row end end
	for _, key in ipairs({ "font", "size", "outline" }) do
		local level, name = rows["level." .. key], rows["name." .. key]
		check(level and level.type == name.type and level.label == name.label and level.help == name.help,
			"level: use the shared text rows for font, size and outline")
	end
	local path = P.Tokens.FontPath("InterSemiBold")
	local wrote = pcall(P.Options.Write, "Nameplates", "level.font", path)
	e.RunTimers()
	check(wrote and U.W.LastCall(plate.levelText, "SetFont")[1] == path, "level: the shared Font row must apply live")
	P.Options.Write("Nameplates", "healthText.textFormat", "[pp]")
	e.RunTimers()
	N.Remove(e, "nameplate1")
	for _, event in ipairs(events) do check(not registered(event), "events: detached plates must unregister optional events") end
	check(#env._errors == 0 and #e._errors == 0, "review checks must exercise successful event paths")
end

do
	local _, K, ns = N.New({ enable = false })
	K.Store.Module("Nameplates").name = { colorMode = "bogus" }
	ns.Settings.Invalidate()
	check(ns.Settings.Get("name.colorMode") == "", "rules: saved dropdowns must validate against the same rows before the page opens")
	K.Options.Get("Nameplates")
	ns.Settings.Invalidate()
	check(ns.Settings.Get("name.colorMode") == "", "rules: opening options must not change validation")
end

local messages = {}
for message in pairs(failures) do messages[#messages + 1] = message end
table.sort(messages)
assert(#messages == 0, table.concat(messages, "\n"))
print("text review ok: saved orb preset, conditional unit events, single paints, reused lists, shared validation and Level rows at four screens")
