-- test-unitframes-aura-timer-lane.lua: with Debuffs and buffs, the buff row starts below the debuff timers under their icons; without a timer lane (timers off, or two rows) it starts right under the debuffs' last row, as the engine's default groupLineSpacing (0) places it.
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Measure(settings)
	local env, K, ns = U.New()
	U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = {
		{ id = 1, icon = 135813, left = 9, harmful = true, mine = true },
		{ id = 2, icon = 136026, left = 3, harmful = true, mine = true },
		{ id = 3, icon = 136207, left = 6, harmful = true, mine = true },
		{ id = 4, icon = 136118, left = 30, harmful = false, mine = false },
	} })
	env.SetTarget(true)
	K.Options.Write("UnitFrames", "target.auraFilter", "both")
	for key, value in pairs(settings) do K.Options.Write("UnitFrames", "target." .. key, value) end
	env.RunTimers()
	Engine.Install(env)
	local drawn, solver = {}, Scene.RectSolver(env)
	for _, item in ipairs(Scene.Build(env).items) do drawn[item.object] = item.rect end
	local auras = ns.Frames.Get("target").views[1].auras
	local buffs = {}
	for _, button in ipairs(auras.container._groups.buffs.buttons) do buffs[button] = true end
	local m = { first = math.huge, last = -math.huge, low = -math.huge, timer = -math.huge, buff = math.huge }
	for _, entry in ipairs(auras.buttons) do
		if entry.button:IsVisible() then
			local _, top, _, height = Scene.RectIn(solver, entry.button)
			if buffs[entry.button] then
				m.buff = math.min(m.buff, top)
			else
				m.first, m.last, m.low = math.min(m.first, top), math.max(m.last, top), math.max(m.low, top + height)
				local t = entry.timer:IsVisible() and assert(drawn[entry.timer], "the timer is drawn")
				if t then m.timer = math.max(m.timer, t[2] + t[4]) end
			end
		end
	end
	assert(m.buff < math.huge and m.low > -math.huge, "debuffs and a buff show")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return m
end

local m = Measure({})
assert(m.timer > m.low and m.timer <= m.buff + 0.01, string.format("timers end at %.2f, over the buff row that starts at %.2f", m.timer, m.buff))
local off = Measure({ auraTimer = false })
assert(math.abs(off.buff - off.low) < 0.01, string.format("with timers off the buff row starts at %.2f, not right under the debuffs at %.2f", off.buff, off.low))
local wrap = Measure({ auraColumns = 2, auraRows = 2 })
assert(wrap.last > wrap.first and math.abs(wrap.buff - wrap.low) < 0.01, string.format("two rows without a timer lane: the buff row starts at %.2f, not right under the last at %.2f", wrap.buff, wrap.low))
print("ok: the buff row clears the debuff timers, and without a timer lane starts right under the debuffs' last row")
