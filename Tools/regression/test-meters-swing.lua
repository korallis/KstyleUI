-- test-meters-swing.lua: the swing timer follows PLAYER_SWING for each hand, hides when idle, dims out of range, and holds Blizzard's swing timers at alpha 0 only while it runs.
local M = dofile("Tools/regression/meters_env.lua")

local env, K, ns = M.New()
local S = env.Secret
local MAIN, OFF, RANGED = M.SWING.MainHand, M.SWING.OffHand, M.SWING.Ranged
local blizzMain, blizzOff = env.SwingTimerMainHandFrame, env.SwingTimerOffHandFrame
blizzOff:SetAlpha(0.5)

M.Enable(env, K)
local Swing = ns.Swing
local main, off, ranged = Swing.bars[MAIN], Swing.bars[OFF], Swing.bars[RANGED]

-- Blizzard's swing timers fade out while KstyleUI's runs, and stay out when Blizzard sets their alpha.
assert(blizzMain:GetAlpha() == 0, "Blizzard's main-hand timer is held at alpha 0")
blizzMain:SetAlpha(1)
assert(blizzMain:GetAlpha() == 0, "Blizzard code cannot bring it back while the module runs")
assert(blizzOff:GetAlpha() == 0, "every Blizzard swing timer is held")
for _, frame in ipairs({ blizzMain, blizzOff }) do
	assert(M.Calls(frame, "Hide") == 0 and M.Calls(frame, "SetParent") == 0 and M.Calls(frame, "SetScript") == 0,
		"Blizzard's swing timers are faded, never hidden, reparented or scripted")
end

-- Idle out of combat: nothing shows.
assert(not Swing.content:IsShown(), "the bars hide out of combat while no swing runs")

-- In combat the main hand shows; there is no off-hand weapon.
env.SetCombat(true)
env.RunTimers()
assert(Swing.content:IsShown(), "the bars show in combat")
assert(main:IsShown(), "the main-hand bar shows")
assert(not off:IsShown(), "no off-hand weapon, no off-hand bar")
assert(not ranged:IsShown(), "no ranged weapon, no ranged bar")

-- A swing fills the bar over its duration, then clears it.
env.SetTime(100)
env.FireEvent("PLAYER_SWING", 2, MAIN)
assert(Swing.driver:GetScript("OnUpdate"), "a running swing drives an OnUpdate")
env.SetTime(101)
M.Tick(env)
assert(M.Last(main, "SetValue")[1] == 0.5, "halfway through the swing the bar is half full")
env.SetTime(102.5)
M.Tick(env)
assert(M.Last(main, "SetValue")[1] == 0, "a finished swing clears the bar")
assert(Swing.driver:GetScript("OnUpdate") == nil, "the OnUpdate stops when no swing runs")

-- The time text, when switched on.
M.Write(env, K, "swing.time", true)
env.SetTime(200)
env.FireEvent("PLAYER_SWING", 2.4, MAIN)
env.SetTime(201)
M.Tick(env)
assert(main.time:IsShown(), "the time shows")
assert(M.Last(main.time, "SetText")[1] == "1.4", "the time counts the seconds left")
M.Write(env, K, "swing.time", false)
assert(not main.time:IsShown(), "the time hides when switched off")

-- A weapon swap during a swing restarts it with the new weapon's speed, as Blizzard's timer does.
env.SetTime(250)
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
env._speeds[1] = 4
env.SetTime(251)
env.FireEvent("WEAPON_SLOT_CHANGED")
env.SetTime(253)
M.Tick(env)
assert(M.Last(main, "SetValue")[1] == 0.5, "the swing restarted with the 4-second weapon")
env.SetTime(260)
M.Tick(env)
env._speeds[1] = 2.6

-- An off-hand weapon adds a bar, and the bars share the element's height.
env._speeds[2] = 2.4
env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
env.RunTimers()
assert(off:IsShown(), "an off-hand weapon shows the off-hand bar")
local h1, h2 = main:GetHeight(), off:GetHeight()
assert(h1 == h2 and h1 < Swing.holder:GetHeight(), "two bars split the height: " .. tostring(h1))
env.SetTime(300)
env.FireEvent("PLAYER_SWING", 2, OFF)
env.SetTime(301)
M.Tick(env)
assert(M.Last(off, "SetValue")[1] == 0.5, "the off hand fills on its own swing")

-- A switched-off hand ignores its swings.
M.Write(env, K, "swing.offHand", false)
assert(not off:IsShown(), "a switched-off hand hides its bar")
local before = M.Calls(off, "SetValue")
env.FireEvent("PLAYER_SWING", 2, OFF)
M.Tick(env)
assert(M.Calls(off, "SetValue") == before, "a switched-off hand ignores its swings")
M.Write(env, K, "swing.offHand", true)

-- Out of range dims an idle bar; a nil range answer is not out of range.
env.SetTime(400)
M.Tick(env)
env._inRange[MAIN] = false
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(main:GetAlpha() < 1, "an idle bar dims while the target is out of range")
env._inRange[MAIN] = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(main:GetAlpha() == 1, "no range answer leaves the bar bright")
env.FireEvent("PLAYER_SWING_RANGE_UPDATE", MAIN, false, true)
assert(main:GetAlpha() < 1, "the range event dims the bar")
env.FireEvent("PLAYER_SWING_RANGE_UPDATE", MAIN, false, false)
assert(main:GetAlpha() == 1, "a range event that made no check leaves the bar bright")

-- A secret duration never reaches Lua arithmetic: the engine fills the bar from a duration object.
local durations = {}
env.C_DurationUtil = {
	CreateDuration = function()
		local d = {}
		function d:SetTimeFromStart(start, duration)
			durations[#durations + 1] = { start, duration }
		end
		return d
	end,
}
local secret = S(2.2)
env.FireEvent("PLAYER_SWING", secret, MAIN)
assert(#durations == 1 and durations[1][2] == secret, "the secret duration goes to a duration object")
assert(M.Calls(main, "SetTimerDuration") == 1, "the engine drives the bar")
assert(#env._errors == 0, "no Lua error with a secret duration: " .. tostring(env._errors[1]))
env.C_DurationUtil = nil
env.FireEvent("PLAYER_SWING", S(2.2), MAIN)
assert(M.Logged(env, "duration"), "without duration objects a secret swing is logged and skipped")

-- Leaving combat with nothing running hides the bars again.
env.SetTime(500)
M.Tick(env)
env.SetCombat(false)
env.RunTimers()
assert(not Swing.content:IsShown(), "the bars hide after combat")
M.Write(env, K, "swing.hideIdle", false)
assert(Swing.content:IsShown(), "with hide-when-idle off the bars stay")

-- Switching the swing timer off, or the module off, gives Blizzard's timers back.
M.Write(env, K, "swing.shown", false)
assert(blizzMain:GetAlpha() == 1, "switching the swing timer off restores Blizzard's main hand")
assert(blizzOff:GetAlpha() == 0.5, "and the off hand at the alpha Blizzard gave it")
blizzMain:SetAlpha(0.8)
assert(blizzMain:GetAlpha() == 0.8, "Blizzard controls its alpha again")
M.Write(env, K, "swing.shown", true)
assert(blizzMain:GetAlpha() == 0, "switching it on holds them again")
M.Disable(env, K)
assert(blizzMain:GetAlpha() == 0.8, "Disable gives Blizzard its alpha back")
assert(Swing.driver:GetScript("OnUpdate") == nil, "Disable stops the OnUpdate")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

-- No Blizzard swing timer on this client: the module still runs and logs it.
local env2, K2 = M.New({ noBlizzard = true })
M.Enable(env2, K2)
assert(K2.Modules.IsRunning("Meters"), "the module runs without Blizzard's swing timers")
assert(#env2._errors == 0, "no Lua error without Blizzard's swing timers: " .. tostring(env2._errors[1]))

-- No C_SwingTimer: the bars still follow PLAYER_SWING, without range checks.
local env3, K3, ns3 = M.New({ noSwing = true })
M.Enable(env3, K3)
env3.SetCombat(true)
env3.SetTime(10)
env3.FireEvent("PLAYER_SWING", 2, MAIN)
env3.FireEvent("PLAYER_TARGET_CHANGED")
env3.SetTime(11)
M.Tick(env3)
assert(M.Last(ns3.Swing.bars[MAIN], "SetValue")[1] == 0.5, "the bar fills without C_SwingTimer")
assert(#env3._errors == 0, "no Lua error without C_SwingTimer: " .. tostring(env3._errors[1]))

print("meters swing ok")
