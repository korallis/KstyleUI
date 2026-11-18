-- test-unitframes-target-percent.lua: the target slab leads with a percent and keeps current/max in a quiet number lane at the far end.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "target", { name = "Bandit", level = 12, health = 118, healthMax = 236, reaction = 2, creature = "Humanoid" })
env.SetTarget(true)
K.Options.Write("HudStyle", "style", "medallions")
local view = ns.Frames.Get("target").views[1]
assert(U.Shown(env, view.healthText) == "50%", "H3: the target slab leads with the target's percent")
assert(U.Shown(env, view.healthSub) == "118 / 236" and view.healthSub:IsShown(), "current and max remain visible")
assert(select(2, view.healthText:GetFont()) == 15 and select(2, view.healthSub:GetFont()) == math.max(10, K.Scale.TextFloor()), "percent 15, detail 10 subject to the reading floor")
assert((view.healthSub:GetFont()) == K.Tokens.Font("number"), "both use the number role")
K.Options.Write("UnitFrames", "target.percentLead", false)
assert(U.Shown(env, view.healthText) == "118 / 236" and U.Shown(env, view.healthSub) == "50%", "off restores the original current-first slab")
K.Options.Write("UnitFrames", "target.percentLead", true)
env._restricted = true
env.FireEvent("UNIT_HEALTH", "target")
assert(U.Shown(env, view.healthText) == "50%" and U.Shown(env, view.healthSub) == "118 / 236", "restricted health never enters Lua arithmetic")
env._units.target.dead = true
env.FireEvent("UNIT_HEALTH", "target")
assert(U.Shown(env, view.healthText) == "Dead" and U.Shown(env, view.healthSub) == "", "death does not leave a stale current/max")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("unitframes target percent ok")
