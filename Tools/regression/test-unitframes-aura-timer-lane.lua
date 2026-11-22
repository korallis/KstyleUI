-- test-unitframes-aura-timer-lane.lua: with Debuffs and buffs on the Medallions target, whose aura rows grow up from the frame, the buff row sits above the debuffs with its own timers ending clear of the debuff row, nudged down too; without a timer lane (timers off) it sits right on the debuffs, and over two rows it keeps the rows' own spacing, as the engine's default groupLineSpacing (0) places it.
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
	local m = { first = math.huge, last = -math.huge, low = -math.huge, timer = -math.huge, buff = math.huge, buffTimer = -math.huge }
	for _, entry in ipairs(ns.Frames.Get("target").views[1].auras.buttons) do
		if entry.button:IsVisible() then
			local _, top, _, height = Scene.RectIn(solver, entry.button)
			if entry.buff then
				m.buff, m.size = math.min(m.buff, top), height
				local t = entry.timer:IsVisible() and assert(drawn[entry.timer], "the timer is drawn")
				if t then m.buffTimer = math.max(m.buffTimer, t[2] + t[4]) end
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

for _, nudge in ipairs({ 0, -12 }) do
	local m = Measure({ auraTimerY = nudge })
	assert(m.timer > m.low, string.format("timers nudged %d sit under the debuff icons", nudge))
	assert(m.buffTimer > m.buff + m.size and m.buffTimer <= m.first + 0.01, string.format("the buff timers nudged %d end at %.2f, above the debuff row that starts at %.2f", nudge, m.buffTimer, m.first))
end
local off = Measure({ auraTimer = false })
assert(math.abs(off.buff + off.size - off.first) < 0.01, string.format("with timers off the buff row ends at %.2f, right on the debuffs at %.2f", off.buff + off.size, off.first))
local wrap = Measure({ auraColumns = 2, auraRows = 2, auraRowGap = 6 })
assert(wrap.last > wrap.first and math.abs((wrap.first - wrap.buff) - (wrap.last - wrap.first)) < 0.01, string.format("two rows without a timer lane: the buff row starts at %.2f, one row step above the top debuff row at %.2f", wrap.buff, wrap.first))
print("ok: the buff row clears the debuff row with its timers, nudged or not, and without a timer lane keeps the rows' own step")
