-- test-unitframes-medallions-dock.lua: with the real action bars, a fitted player or target slab docks its arm to the crest only while bars 1 and 2 stand at home; moving action bar 1 splits the bars, which keeps the crest on its own element (KSTY-171 part 1) but takes the arms away, and a reset docks them again.
local Suite = dofile("Tools/regression/suite_env.lua")
local env, K = Suite.New(nil, 1920, 1080)
local choice = K.Setup.NewChoice()
choice.hudStyle, choice.layout = "medallions", "DPS"
assert(K.Setup.Apply(choice))
env.RunTimers()
local frames, slab = env._addons.KstyleUI_UnitFrames.Frames, env._addons.KstyleUI_ActionBars.Slab

local function check(label, docked)
	env.RunTimers()
	assert(slab.hub:IsShown(), label .. ": the crest shows")
	for _, kind in ipairs({ "player", "target" }) do
		local arm = frames.Get(kind).views[1].dock
		assert(arm and arm:IsShown() == docked, label .. ": the " .. kind .. " arm docks " .. tostring(docked))
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
