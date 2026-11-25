-- test-percent-unit-text.lua: readable health and power percentages round up on all HUD surfaces; secrets keep the existing engine formatting.
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local G = dofile("Tools/regression/group_env.lua")
local cases = { 0.4, 24.4, 24.5, 24.6, 99.6, 100 }

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = U.New({ enabled = false, width = screen[1], height = screen[2] })
	local text = K.Widgets.FontString(env.UIParent, "OVERLAY")
	for _, value in ipairs(cases) do
		local expected = math.ceil(value) .. "%"
		assert(K.Widgets.WholePercent(value) == math.ceil(value), "Forever TextStatusBar.lua:197 rounds up")
		local secret = env.Secret(value)
		assert(rawequal(K.Widgets.WholePercent(secret), secret), "a secret must pass through unchanged")
		env.UnitHealthPercent = function() return value end
		env.UnitPowerPercent = function() return value end
		local health, maximum = env.UnitHealth, env.UnitHealthMax
		env.UnitHealth = function() error("percent read current health") end
		env.UnitHealthMax = function() error("percent read maximum health") end
		ns.Format.Health(text, "player", "percent")
		env.UnitHealth, env.UnitHealthMax = health, maximum
		assert(U.Shown(env, text) == expected, "health: " .. value .. " must read " .. expected)
		ns.Format.Power(text, "player", "percent", 0)
		assert(U.Shown(env, text) == expected, "mana: " .. value .. " must read " .. expected)
		ns.Format.Sample(text, "percent", value, 100)
		assert(U.Shown(env, text) == math.ceil(value / 100 * 100) .. "%", "unit previews use the same formula")
		K.Widgets.TagText(text, "[hp:pct] / [pp:pct]", "player")
		assert(U.Shown(env, text) == expected .. " / " .. expected, "readable percent tags round up")
		K.Widgets.TagText(text, "[hp:pct]", nil, { health = value, healthMax = 100 })
		assert(U.Shown(env, text) == math.ceil(value / 100 * 100) .. "%", "preview tags round up")
		env.UnitHealthPercent = function() return secret end
		ns.Format.Health(text, "player", "percent")
		assert(U.Shown(env, text) == string.format("%.0f%%", value), "secret health keeps the engine's existing format")
		K.Widgets.TagText(text, "[hp:pct]", "player")
		assert(U.Shown(env, text) == env.Reveal(K.Widgets.ShortNumber(secret) .. "%"), "secret tags keep their existing abbreviation path")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

	local e, P, n = N.New({ width = screen[1], height = screen[2] })
	N.Add(e, "nameplate1")
	P.Options.Write("Nameplates", "healthText.show", true)
	e.RunTimers()
	local plate = n.Plates.Get("nameplate1")
	for _, value in ipairs(cases) do
		e.UnitHealthPercent = function() return value end
		plate:UpdateHealthText()
		assert(U.Shown(e, plate.healthText) == math.ceil(value) .. "%", "nameplate health rounds up")
		plate.sample = { health = value / 100 }
		plate:UpdateHealthText()
		assert(U.Shown(e, plate.healthText) == math.ceil(value / 100 * 100) .. "%", "nameplate samples round up")
		plate.sample = nil
	end
	assert(#e._errors == 0 and P.ErrorCount() == 0, tostring(e._errors[1]))

	local g, C, group = G.New({ width = screen[1], height = screen[2] })
	G.SetRoster(g, "party", { { name = "Tank", class = "WARRIOR", health = 24.4, maxHealth = 100 } })
	C.Modules.Enable("GroupFrames")
	C.Options.Write("GroupFrames", "party.healthText", "PERCENT")
	g.RunTimers()
	local frame
	for _, f in ipairs(group.Unit.frames) do if f.unit == "party1" then frame = f end end
	assert(frame, "party1 must have a frame")
	for _, value in ipairs(cases) do
		g.UnitHealthPercent = function() return value end
		group.Unit.OnEvent(frame, "UNIT_HEALTH")
		assert(U.Shown(g, frame.healthText) == math.ceil(value) .. "%", "group health rounds up")
	end
	assert(#g._errors == 0 and C.ErrorCount() == 0, tostring(g._errors[1]))
end

print("percent unit text ok")
