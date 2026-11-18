-- test-combattext-calm.lua: five bounded lanes, 250 ms plain-number merging, secret isolation and 80 ms evictions, with the original behaviour available.
local CT = dofile("Tools/regression/combattext_env.lua")
local env, K, ns = CT.New()
CT.Enable(env, K)
local emitter = ns.Module.fieldEmitter
env._now = 10
CT.Hit(env, "player", "WOUND", "", 10, 1)
local first = emitter.active[1]
env._now = 10.25
CT.Hit(env, "player", "WOUND", "", 20, 1)
assert(#emitter.active == 1 and first.amount == 30, "merge matching ordinary hits within 250 ms")
assert(CT.Text(env, first) == "short(30)", "the merged number displays the sum")
assert(ns.Module.cfg.calmNumbers, "calmer combat numbers default on")
env._now = 10.251
CT.Hit(env, "player", "WOUND", "", 40, 1)
assert(#emitter.active == 2, "hits after the merge window stay separate")
ns.Display.Clear(emitter)
K.Options.Write("CombatText", "maxPerFrame", 5)
local lanes = {}
for i = 1, 5 do
	CT.Hit(env, "player", "WOUND", "", env.Secret(i), env.Secret(1))
	local number = emitter.active[i]
	assert(number and number.amount == nil, "secret amounts are never merged or retained")
	local _, _, _, x = number.frame:GetPoint(1)
	lanes[x] = true
	assert(math.abs(x) <= emitter.frame:GetWidth() / 2 + K.Scale.Pixel(1), "keep five lanes within the field while preserving the original lane spacing")
end
local count = 0
for _ in pairs(lanes) do count = count + 1 end
assert(count == 5, "spread five consecutive numbers over five lanes")
first = emitter.active[1]
CT.Hit(env, "player", "HEAL", "", env.Secret(7), 2)
assert(first.live and first.retiring and first.frame:IsShown(), "an evicted number stays visible during its fade")
local fade = first.eviction._anims[1]
assert(CT.LastCall(fade, "SetDuration") == 0.08, "eviction fades for 80 ms")
CT.Finish(first)
assert(first.live and first.frame:GetAlpha() == 0, "a natural ending never flashes a retiring number back at its origin")
first.eviction:GetScript("OnFinished")(first.eviction)
assert(not first.live and not first.frame:IsShown(), "an eviction releases its number after the fade")
ns.Display.Clear(emitter)
assert(#ns.Module.pool.active == 0, "clearing an emitter releases fading numbers too")
K.Options.Write("CombatText", "calmNumbers", false)
for i = 1, 6 do CT.Hit(env, "player", "WOUND", "", i, 1) end
assert(#emitter.active == 5 and #ns.Module.pool.active == 5, "off restores separate numbers and immediate eviction")
lanes = {}
for _, number in ipairs(emitter.active) do
	local _, _, _, x = number.frame:GetPoint(1)
	lanes[x] = true
end
count = 0
for _ in pairs(lanes) do count = count + 1 end
assert(count == 3, "off restores the original three lanes")
K.Options.Write("CombatText", "calmNumbers", true)
K.Motion.SetLevel("off")
ns.Display.Clear(emitter)
for i = 1, 6 do CT.Hit(env, "player", "WOUND", "", env.Secret(i), 1) end
assert(#ns.Module.pool.active == 5, "Motion Off makes room immediately without leaving fading numbers")
K.Motion.SetLevel("reduced")
first = emitter.active[1]
CT.Hit(env, "player", "HEAL", "", env.Secret(1), 2)
assert(first.retiring and first.eviction:IsPlaying(), "Reduced keeps the quiet eviction fade")
ns.Display.Clear(emitter)
assert(#ns.Module.pool.active == 0, "clearing also cleans up a Reduced eviction")
assert(#env._errors == 0, tostring(env._errors[1]))
print("combattext calm ok")
