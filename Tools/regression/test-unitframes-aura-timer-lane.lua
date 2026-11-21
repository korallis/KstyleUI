-- test-unitframes-aura-timer-lane.lua: with Debuffs and buffs and timers under their icons, the buff row starts below the debuff timers, as the engine spaces a forced new line by groupLineSpacing (0 unless set).
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K, ns = U.New()
local view = ns.Frames.Get("target").views[1]
U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = {
	{ id = 1, icon = 135813, left = 9, harmful = true, mine = true },
	{ id = 2, icon = 136026, left = 3, harmful = true, mine = true },
	{ id = 3, icon = 136207, left = 30, harmful = false, mine = false },
	{ id = 4, icon = 136118, left = 12, harmful = false, mine = false },
} })
env.SetTarget(true)
K.Options.Write("UnitFrames", "target.auraFilter", "both")
env.RunTimers()
Engine.Install(env)
assert(ns.Auras.TimerRoom("target") > 0, "the target's timers sit under their icons by default")

local drawn = {}
for _, item in ipairs(Scene.Build(env).items) do drawn[item.object] = item.rect end
local function rect(region)
	local r = assert(drawn[region], "the region is drawn")
	return { top = r[2], bottom = r[2] + r[4] }
end
local timers, buffs = {}, {}
for _, entry in ipairs(view.auras.buttons) do
	if entry.button:IsVisible() then
		if entry.buff then
			buffs[#buffs + 1] = rect(entry.icon)
		elseif entry.timer:IsVisible() then
			timers[#timers + 1] = rect(entry.timer)
		end
	end
end
assert(#timers == 2 and #buffs == 2, "two debuffs with timers and two buffs show, got " .. #timers .. " and " .. #buffs)
local lowest, highest = -math.huge, math.huge
for _, t in ipairs(timers) do lowest = math.max(lowest, t.bottom) end
for _, b in ipairs(buffs) do highest = math.min(highest, b.top) end
assert(lowest <= highest + 0.01, string.format("the debuff timers end at %.2f, over the buff row that starts at %.2f", lowest, highest))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("ok: debuff timers end at " .. string.format("%.2f", lowest) .. ", the buff row starts at " .. string.format("%.2f", highest))
