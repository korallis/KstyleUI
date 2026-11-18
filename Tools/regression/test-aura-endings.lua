-- test-aura-endings.lua: aura timers retain a positive final second, plates and auras share the same safe expiring colour, and swipe flashes can be restored.
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local bands = {}
local env, K = A.New({ setup = function(e)
	e.AuraContainerInbound.GetDefaultAuraDurationFormatter().GetMaxIntervalCurve = function() return bands end
end })
local D = K.Widgets.Duration
K.Modules.Enable("Auras")
env.RunTimers()
local _, group = A.Container(env, "HELPFUL")
local button = group.frames[1]
A.Remaining(env, button, env.Secret(0.4))
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "the live bound 0.4-second aura timer rounds up")
assert(env.issecretvalue(button._aura.timer:GetText()), "live duration text stays engine-managed")
assert(button._aura.timerOptions.textFormatter.settings.SetMaxIntervalCurve == bands, "rounding preserves Blizzard's short-timer interval bands")
assert(K.Options.Row("Auras", "timer.cleanEndings") == nil, "remove the separate preview-only toggle")
assert(K.Appearance.Get("auraEndings"), "shared aura endings default on")
K.Options.Write("Appearance", "auraEndings", false)
env.RunTimers()
assert(env.Reveal(button._aura.timer:GetText()) == "0s", "shared endings off restores the old live formatter")
K.Options.Write("Appearance", "auraEndings", true)
env.RunTimers()
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "reenabling endings updates the existing live binding")
for _, kind in ipairs({ "long", "short" }) do
	K.Options.Write("Auras", "timer.format", kind)
	assert(env.Reveal(button._aura.timer:GetText()) == "1s", "live " .. kind .. " timers keep the final second")
end
local binding = D.ExpiringColor(5)
assert(binding and binding.property == env.Enum.DurationTextBindingProperty.RemainingDuration, "bind expiring colour to the engine's remaining duration")
assert(D.ExpiringColor(0) == nil, "zero disables the existing colour warning")
env.C_CurveUtil = nil
assert(D.ExpiringColor(5) == nil, "missing curve APIs keep a single colour")
local ns
env, K, ns = N.New()
N.Add(env, "nameplate1")
local plate = ns.Plates.Get("nameplate1")
button = plate.auras:GetAuraGroupFrame("debuffs", 1)
A.Remaining(env, button, env.Secret(0.4))
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "plates use the shared rounded formatter too")
local function bling()
	for _, object in ipairs(A.Descendants(button)) do
		if object:GetObjectType() == "Cooldown" then return N.Last(object, "SetDrawBling") end
	end
end
assert(bling() and bling()[1] == false, "plate aura swipes disable the finishing flash by default")
K.Options.Write("Appearance", "auraEndings", false)
env.RunTimers()
assert(bling()[1] == true, "off restores the original finishing flash")
assert(env.Reveal(button._aura.timer:GetText()) == "0s", "off restores the original plate timer")
assert(#env._errors == 0, tostring(env._errors[1]))
print("aura endings ok")
