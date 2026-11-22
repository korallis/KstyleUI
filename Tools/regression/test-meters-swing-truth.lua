-- test-meters-swing-truth.lua: the swing timer shows what the game's own timer shows (Blizzard_SwingTimer/Blizzard_SwingTimer.lua) for each client event sequence, and nothing where the game hides the value.
local M = dofile("Tools/regression/meters_env.lua")

local env, K, ns = M.New()
local S = env.Secret
local MAIN, OFF, RANGED = M.SWING.MainHand, M.SWING.OffHand, M.SWING.Ranged

M.Enable(env, K)
M.Write(env, K, "swing.time", true)
local Swing = ns.Swing
local bars = Swing.bars

-- SwingTimerMixin:ResetSwingTimer and :OnUpdate: the bar is (duration - remaining) / duration and the text "%.1f" of
-- remaining, with remaining = swingEndTime - GetTime().
local function Game(start, duration, now)
	local remaining = start + duration - now
	return (duration - remaining) / duration, string.format("%.1f", remaining)
end

local function Shown(slot)
	local value, text = M.Last(bars[slot], "SetValue"), M.Last(bars[slot].time, "SetText")
	return value and value[1], text and text[1]
end

local function Same(slot, start, duration, now, what)
	env.SetTime(now)
	M.Tick(env)
	local value, text = Shown(slot)
	local wantValue, wantText = Game(start, duration, now)
	assert(math.abs(value - wantValue) < 1e-9 and text == wantText,
		what .. ": the game shows " .. wantValue .. " and " .. wantText .. ", KstyleUI shows " .. tostring(value) .. " and " .. tostring(text))
end

local function Running(slot)
	return Swing.state[slot].running or Swing.state[slot].engine
end

env.SetCombat(true)

-- Main hand, off hand and ranged each follow their own PLAYER_SWING.
env._speeds = { 2.6, 1.8, 2.9 }
env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
env.SetTime(100)
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
env.SetTime(100.4)
env.FireEvent("PLAYER_SWING", 1.8, OFF)
env.SetTime(100.7)
env.FireEvent("PLAYER_SWING", 2.9, RANGED)
Same(MAIN, 100, 2.6, 101.3, "main hand")
Same(OFF, 100.4, 1.8, 101.3, "off hand")
Same(RANGED, 100.7, 2.9, 101.3, "ranged")
env.SetTime(110)
M.Tick(env)

-- Haste mid-swing (UNIT_ATTACK_SPEED): the game's timer keeps the swing it was given until the next PLAYER_SWING.
env.SetTime(200)
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
env._speeds[1] = 2.0
env.SetTime(201)
env.FireEvent("UNIT_ATTACK_SPEED", "player")
Same(MAIN, 200, 2.6, 201.5, "haste mid-swing")
env._speeds[1] = 2.6

-- A swing the client signals early (parry haste, an on-next-swing ability, a reset) restarts the bar at that moment,
-- and so does a swing that missed, was dodged or was parried: the event carries no outcome.
env.SetTime(202)
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
Same(MAIN, 202, 2.6, 202, "an early swing")
Same(MAIN, 202, 2.6, 203.3, "an early swing")
env.SetTime(210)
M.Tick(env)

-- Another unit's attack speed changes nothing.
env.SetTime(300)
env.FireEvent("PLAYER_SWING", 1.8, OFF)
env._speeds[2] = nil
env.FireEvent("UNIT_ATTACK_SPEED", "target")
assert(Running(OFF), "another unit's attack speed leaves the off hand alone")
dofile("Tools/regression/instruction_budget.lua")(function()
	for i = 1, 40 do
		env.FireEvent("UNIT_ATTACK_SPEED", "raid" .. i)
		env.FireEvent("UNIT_INVENTORY_CHANGED", "raid" .. i)
	end
end, 1, "a raid's UNIT_ATTACK_SPEED and UNIT_INVENTORY_CHANGED ran Meters code; the swing timer reads only the player's, so register them for the player (KstyleUI_Meters/Swing.lua Apply)")

-- A hand that loses its weapon mid-swing (SwingTimerMixin:UpdateFrameState, ShouldClearSwing): the game clears that
-- hand's timer on UNIT_INVENTORY_CHANGED, UNIT_ATTACK_SPEED and PLAYER_ENTERING_WORLD, with no WEAPON_SLOT_CHANGED.
for _, event in ipairs({ "UNIT_INVENTORY_CHANGED", "UNIT_ATTACK_SPEED", "PLAYER_ENTERING_WORLD" }) do
	env._speeds = { 2.6, 1.8, 2.9 }
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	env.SetTime(env.GetTime() + 10)
	M.Tick(env)
	env.FireEvent("PLAYER_SWING", 2.6, MAIN)
	env.FireEvent("PLAYER_SWING", 1.8, OFF)
	env.FireEvent("PLAYER_SWING", 2.9, RANGED)
	env._speeds = { 2.6, nil, nil }
	env.SetTime(env.GetTime() + 0.5)
	env.FireEvent(event, event ~= "PLAYER_ENTERING_WORLD" and "player" or nil)
	M.Tick(env)
	for _, slot in ipairs({ OFF, RANGED }) do
		local value, text = Shown(slot)
		assert(not Running(slot) and not bars[slot]:IsShown() and value == 0 and text == "",
			event .. ": the game clears a hand with no weapon, KstyleUI shows " .. tostring(value) .. " and " .. tostring(text))
	end
	assert(Running(MAIN) and bars[MAIN]:IsShown(), event .. ": the main hand always has a swing")
end
env._speeds = { 2.6, 1.8, 2.9 }
env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
env.SetTime(env.GetTime() + 10)
M.Tick(env)

-- A secret attack speed (UnitAttackSpeed: SecretWhenUnitStatsRestricted) cannot say the weapon is gone: the swing the
-- client signalled runs on.
env.FireEvent("PLAYER_SWING", 1.8, OFF)
env._speeds = { S(2.6), S(1.8), nil }
env.FireEvent("UNIT_ATTACK_SPEED", "player")
assert(Running(OFF), "a secret off-hand speed leaves the off-hand swing running")
-- A weapon swap restarts the swing at the new weapon's speed (ResetSwingTimerForEquippedWeapon). A secret speed is
-- not a number KstyleUI may show, so that hand shows nothing until the next PLAYER_SWING.
env.FireEvent("WEAPON_SLOT_CHANGED")
M.Tick(env)
assert(not Running(OFF) and select(2, Shown(OFF)) == "", "a swap to a secret speed shows no swing and no number")
env._speeds = { 2.6, 1.8, 2.9 }
env.FireEvent("UNIT_INVENTORY_CHANGED", "player")

-- A secret swing duration goes to the engine, which draws the bar. The number KstyleUI wrote for the swing before
-- it is no longer the game's: the text is cleared.
env.C_DurationUtil = {
	CreateDuration = function()
		return { SetTimeFromStart = function() end }
	end,
}
env.SetTime(env.GetTime() + 10)
M.Tick(env)
local start = env.GetTime()
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
Same(MAIN, start, 2.6, start + 1.2, "before the secret swing")
env.FireEvent("PLAYER_SWING", S(2.6), MAIN)
env.SetTime(start + 2)
M.Tick(env)
assert(Swing.state[MAIN].engine, "the engine draws a secret swing")
assert(select(2, Shown(MAIN)) == "", "a secret swing shows no number, KstyleUI shows " .. tostring(select(2, Shown(MAIN))))
env.C_DurationUtil = nil

-- Leaving combat or losing the target mid-swing: the swing runs to its end, as the game's timer does.
env.SetCombat(false)
env.RunTimers()
env.SetTime(env.GetTime() + 10)
M.Tick(env)
env.SetCombat(true)
start = env.GetTime()
env.FireEvent("PLAYER_SWING", 2.6, MAIN)
env.FireEvent("PLAYER_TARGET_CHANGED")
env.SetCombat(false)
env.RunTimers()
Same(MAIN, start, 2.6, start + 1.3, "out of combat with no target")

assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))
print("meters swing truth ok")
