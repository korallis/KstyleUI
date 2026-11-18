-- test-aura-endings.lua: aura timers retain a positive final second, plates and auras share the same safe expiring colour, and swipe flashes can be restored.
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local env, K, ns = A.New()
local D = K.Widgets.Duration
for _, kind in ipairs({ "short", "long" }) do
	assert(D.Format(0.01, kind, true) == "1s", "round a positive last second up")
	assert(D.Format(0.01, kind, false) == "0s", "off restores the original rounding")
end
assert(D.Format(0.01, "decimal", true) == "0.1", "a positive final tenth must not read zero")
assert(D.Format(0, "short", true) == "0s", "expired timers still read zero")
assert(D.Format(env.Secret(0.4), "short", true) == "", "secret durations stay entirely in engine bindings")
assert(ns.Model.FormatTime(0.4, "short") == "1s", "aura samples use the new ending by default")
K.Options.Write("Auras", "timer.cleanEndings", false)
assert(ns.Model.FormatTime(0.4, "short") == "0s", "the aura option restores its previous look")
local binding = D.ExpiringColor(5)
assert(binding and binding.property == env.Enum.DurationTextBindingProperty.RemainingDuration, "bind expiring colour to the engine's remaining duration")
assert(D.ExpiringColor(0) == nil, "zero disables the existing colour warning")
env.C_CurveUtil = nil
assert(D.ExpiringColor(5) == nil, "missing curve APIs keep a single colour")
env, K, ns = N.New()
N.Add(env, "nameplate1")
local plate = ns.Plates.Get("nameplate1")
local button = plate.auras:GetAuraGroupFrame("debuffs", 1)
local function bling()
	for _, object in ipairs(A.Descendants(button)) do
		if object:GetObjectType() == "Cooldown" then return N.Last(object, "SetDrawBling") end
	end
end
assert(bling() and bling()[1] == false, "plate aura swipes disable the finishing flash by default")
K.Options.Write("Nameplates", "debuffs.cleanEndings", false)
env.RunTimers()
assert(bling()[1] == true, "off restores the original finishing flash")
assert(#env._errors == 0, tostring(env._errors[1]))
print("aura endings ok")
