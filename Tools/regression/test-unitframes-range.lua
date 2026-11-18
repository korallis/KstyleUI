local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
local view = ns.Frames.Get("target").views[1]
env.UnitInRange = function() return false, true end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
U.W.Settle(env)
assert(view.name:GetAlpha() == 0.55 and view.portrait:GetAlpha() == 0.55, "an out-of-range target name and portrait fade to 55%")
env.UnitInRange = function() return true, true end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
U.W.Settle(env)
assert(view.name:GetAlpha() == 1 and view.portrait:GetAlpha() == 1, "returning to range restores them")
env.UnitInRange = function() return env.Secret(false), env.Secret(true) end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
assert(env.Reveal(view.name:GetAlpha()) == 0.55, "secret range goes to SetAlphaFromBoolean without comparison")
env.UnitInRange = function() return env.Secret(false), env.Secret(false) end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
assert(env.Reveal(view.name:GetAlpha()) == 1, "the engine also gates secret unchecked ranges")
env.UnitInRange = function() return false, false end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
U.W.Settle(env)
assert(view.name:GetAlpha() == 1, "an unchecked range never dims the target")
env.UnitInRange = function() return false, true end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
env.UnitInRange = function() return env.Secret(true), env.Secret(true) end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
U.W.Settle(env)
assert(env.Reveal(view.name:GetAlpha()) == 1 and env.Reveal(view.portrait:GetAlpha()) == 1, "a secret update cancels the old plain range tween")
assert(#env._errors == 0, tostring(env._errors[1]))

K.Options.Write("UnitFrames", "target.rangeFade", false)
env.UnitInRange = function() return env.Secret(false), env.Secret(true) end
env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
U.W.Settle(env)
assert(view.name:GetAlpha() == 1 and view.portrait:GetAlpha() == 1, "range fading off restores the previous opaque target")
K.Options.Write("UnitFrames", "target.rangeFade", true)
assert(env.Reveal(view.name:GetAlpha()) == 0.55, "range fading can be turned back on immediately")
assert(#env._errors == 0, tostring(env._errors[1]))

print("unit frame range ok")
