-- test-unitframes-medallions-dock.lua: with the real action bars, a fitted player or target slab docks its arm only while the crest shows; moving action bar 1 hides the crest and the arms with it, and a reset brings both back.
local Suite = dofile("Tools/regression/suite_env.lua")
local env, K = Suite.New(nil, 1920, 1080)
local choice = K.Setup.NewChoice()
choice.hudStyle, choice.layout = "medallions", "DPS"
assert(K.Setup.Apply(choice))
env.RunTimers()
local frames, slab = env._addons.KstyleUI_UnitFrames.Frames, env._addons.KstyleUI_ActionBars.Slab

local function check(label, crest)
	env.RunTimers()
	assert(slab.hub:IsShown() == crest, label .. ": the crest shows " .. tostring(crest))
	for _, kind in ipairs({ "player", "target" }) do
		local arm = frames.Get(kind).views[1].dock
		assert(arm and arm:IsShown() == crest, label .. ": the " .. kind .. " arm follows the crest (" .. tostring(crest) .. ")")
	end
end

check("default", true)
local key = "actionbars.bar1"
assert(K.Layout.Set(key, "y", K.Layout.Get(key).y + 80))
check("bar 1 moved up 80", false)
K.Layout.Reset(key)
check("bar 1 reset", true)
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("unitframes medallions dock ok")
