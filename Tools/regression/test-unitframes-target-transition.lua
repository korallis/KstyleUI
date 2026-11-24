-- test-unitframes-target-transition.lua: target visuals change and leave at once with no fade, and a dying target settles to grey before it leaves.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K, ns = U.New()
local view = ns.Frames.Get("target").views[1]
local function target(name)
	U.SetUnit(env, "target", { name = name, level = 10, health = 80, healthMax = 100, reaction = 2, canAttack = true })
	env.SetTarget(true)
end
local function settle()
	W.Tick(env, 0.06)
	W.Tick(env, 0.06)
end
target("Wolf")
W.Tick(env, 0.2)
local body = view.body
assert(body and body:IsShown() and body:GetAlpha() == 1, "E5: a new target shows its visual body whole")
env._units.target = nil
env.SetTarget(false)
assert(not body:IsShown(), "E5: target loss hides the visual body at once, with no fade")
target("Wolf")
W.Tick(env, 0.2)
local old = view.body
target("Boar")
assert(view.body == old and old:IsShown() and old:GetAlpha() == 1 and U.Shown(env, view.name) == "BOAR", "E5: a target change shows the new target at once on the real slab, with no fade")
target("Fox")
assert(U.Shown(env, view.name) == "FOX" and old:GetAlpha() == 1, "E5: a rapid replacement shows the newest target")
target("Boar")
settle()
env._units.target.dead = true
env.FireEvent("UNIT_HEALTH", "target")
W.Tick(env, 0.1)
local portrait = view.medallion.portrait
local desaturation = W.LastCall(portrait, "SetDesaturation")
assert(desaturation and desaturation[1] > 0 and desaturation[1] < 1, "E5: death desaturates over 200 ms")
W.Tick(env, 0.1)
local r, g, b = K.Tokens.Color("medDead")
local c = W.LastCall(view.health, "SetStatusBarColor")
assert(c[1] == r and c[2] == g and c[3] == b, "E5: the dead target's bar settles to grey")
env.FireEvent("UNIT_FLAGS", "target")
c = W.LastCall(view.health, "SetStatusBarColor")
assert(c[1] == r and c[2] == g and c[3] == b, "E5: a later flags event keeps the dead bar grey")
target("Wolf")
settle()
local pending = {}
env.C_Timer.After = function(seconds, fn) pending[#pending + 1] = { seconds, fn } end
env._units.target.dead = true
env.FireEvent("UNIT_HEALTH", "target")
local dying = view.body
env._units.target = nil
env.SetTarget(false)
assert(pending[#pending][1] == 0.2 and dying:IsShown() and dying:GetAlpha() == 1, "E5: death finishes its 200 ms grey transition before the target leaves")
W.Tick(env, 0.2)
pending[#pending][2]()
assert(not dying:IsShown(), "E5: the dying target leaves at once after its grey transition")
target("Wolf")
settle()
local t = env._time
view.targetFlipAt = t
local flip = view.medallion.FlipIn
local flips = 0
view.medallion.FlipIn = function() flips = flips + 1 end
ns.Slab.FlipIn(view)
assert(flips == 0, "E5: do not replay a flip before its halfway point")
env._time = t + 0.1
ns.Slab.FlipIn(view)
assert(flips == 1, "E5: a flip may replay after its halfway point")
view.medallion.FlipIn = flip
local plain = { view.health:GetStatusBarColor() }
env._units.target.dead = true
env.FireEvent("UNIT_HEALTH", "target")
W.Tick(env, 0.1)
K.Options.Write("UnitFrames", "target.transitions", false)
W.Tick(env, 0.2)
c = W.LastCall(view.health, "SetStatusBarColor")
assert(c[1] == plain[1] and c[2] == plain[2] and c[3] == plain[3], "E5: switching off during death stops the tween and restores the original bar colour")
assert(W.LastCall(view.medallion.portrait, "SetDesaturated")[1], "E5: switching off during death settles the original dead portrait")
env._units.target = nil
env.SetTarget(false)
assert(not view.body:IsShown(), "E5: off restores immediate target loss")
target("Wolf")
local same = view.body
target("Boar")
assert(view.body == same and same:GetAlpha() == 1, "E5: off restores immediate target changes")
local before = { view.health:GetStatusBarColor() }
env._units.target.dead = true
env.FireEvent("UNIT_HEALTH", "target")
c = W.LastCall(view.health, "SetStatusBarColor")
assert(c[1] == before[1] and c[2] == before[2] and c[3] == before[3], "E5: off preserves the original bar colour on death")
assert(W.LastCall(view.medallion.portrait, "SetDesaturated")[1], "E5: off restores immediate portrait desaturation")
K.Motion.SetLevel("off")
K.Options.Write("UnitFrames", "target.transitions", true)
target("Wolf")
target("Boar")
assert(view.body == same and view.body:IsShown() and view.body:GetAlpha() == 1, "E5: Motion Off settles target changes immediately on the real slab")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
do
	local e, kit, frames = U.New({ setup = function(client)
		U.SetUnit(client, "target", { name = "Wolf", level = 10, health = 80, healthMax = 100, reaction = 2 })
	end })
	local targetView = frames.Frames.Get("target").views[1]
	local previous = targetView.body
	U.SetUnit(e, "target", { name = "Boar", level = 10, health = 60, healthMax = 100, reaction = 2 })
	e.SetTarget(true)
	assert(targetView.body == previous and previous:GetAlpha() == 1 and U.Shown(e, targetView.name) == "BOAR", "E5: the first replacement shows at once when the addon starts with an existing target")
	e.UnitInRange = function() return false, true end
	e.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
	W.Tick(e, 0.2)
	U.SetUnit(e, "target", { name = "Fox", level = 10, health = 50, healthMax = 100, reaction = 2 })
	e.SetTarget(true)
	W.Tick(e, 0.06)
	W.Tick(e, 0.06)
	assert(targetView.name:GetAlpha() == 0.55, "E5: a replacement slab preserves the target's range fade")
	assert(#e._errors == 0 and kit.ErrorCount() == 0, tostring(e._errors[1]))
end
print("target transition ok")
