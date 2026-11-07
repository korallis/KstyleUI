-- test-meters-threat.lua: the threat meter lists the group's threat on the target, highest first, passes secret values only to widget setters, and warns on readable values.
local M = dofile("Tools/regression/meters_env.lua")

local env, K, ns = M.New()
local S = env.Secret

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local function Party()
	env._group = { raid = false, size = 3 }
	env._units.party1 = { name = "Kragar", class = "WARRIOR" }
	env._units.party2 = { name = "Sylaen", class = "PRIEST" }
	env._units.target = { name = "Magmatus", hostile = true }
	env._threat.player = { false, 1, 60, 50, 600000 }
	env._threat.party1 = { true, 3, 100, 100, 1000000 }
	env._threat.party2 = { false, 0, 30, 25, 300000 }
end

Party()
M.Enable(env, K)
local Threat = ns.Threat
local list = Threat.list
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()

assert(list.panel:IsShown(), "the meter shows in a group")
assert(list.count == 3, "three members are on the threat list, got " .. tostring(list.count))
assert(Text(list.rows[1].name) == "Kragar", "the tank is first")
assert(Text(list.rows[2].name) == "Tester", "the player is second")
assert(Text(list.rows[3].name) == "Sylaen", "the healer is last")
local range = M.Last(list.rows[1].bar, "SetMinMaxValues")
assert(range[1] == 0 and range[2] == 100, "bars run from 0 to 100% of aggro")
assert(M.Last(list.rows[1].bar, "SetValue")[1] == 100, "the tank's bar is full")
assert(Text(list.rows[1].value) == "~10000", "threat reads in threat points: " .. tostring(Text(list.rows[1].value)))
assert(Text(list.rows[1].percent) == "100%", "the tank holds 100%")
assert(list.warning == 0, "60% does not warn")

-- Classes colour the bars.
local r, g, b = K.Theme.ClassColor("WARRIOR")
local colour = M.Last(list.rows[1].bar, "SetStatusBarColor")
assert(colour[1] == r and colour[2] == g and colour[3] == b, "the warrior's bar takes the class colour")

-- Warnings follow the player's threat.
env._threat.player = { false, 2, 85, 80, 850000 }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(list.warning == 1, "85% warns")
env._threat.player = { false, 3, 97, 90, 970000 }
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
env.RunTimers()
assert(list.warning == 2, "97% is danger")
assert(list.glow and list.glow:IsPlaying(), "danger pulses the meter")
M.Write(env, K, "threat.warnings", false)
assert(list.warning == 0, "warnings switched off clear the warning")
M.Write(env, K, "threat.warnings", true)
M.Write(env, K, "threat.dangerAt", 100)
assert(list.warning == 1, "a higher danger threshold leaves a warning")
M.Write(env, K, "threat.dangerAt", 95)

-- A tank is warned when another member nears aggro.
env._threat.player = { true, 3, 100, 100, 1000000 }
env._threat.party1 = { false, 2, 92, 90, 920000 }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(list.warning == 1, "a tank is warned at another member's 92%")

-- Secret threat values reach only widget setters and never warn or sort.
local secretScaled = S(70)
env._threat.party2 = { S(false), S(1), secretScaled, S(65), S(700000) }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(#env._errors == 0, "secret threat raises no error: " .. tostring(env._errors[1]))
assert(Text(list.rows[3].name) == "Sylaen", "with a secret value the group keeps its order")
assert(M.Last(list.rows[3].bar, "SetValue")[1] == secretScaled, "the secret percentage goes straight to the bar")
assert(env.issecretvalue(Text(list.rows[3].percent)), "the secret percentage text passes through whole")
assert(M.Logged(env, "secret"), "the secret path is logged")
env._threat.party2 = { false, 0, 30, 25, 300000 }

-- The value setting picks the columns.
M.Write(env, K, "threat.value", "percent")
assert(not list.rows[1].value:IsShown(), "percent only hides the threat column")
assert(list.rows[1].percent:IsShown(), "percent only keeps the percentage")
M.Write(env, K, "threat.value", "threat")
assert(list.rows[1].value:IsShown() and not list.rows[1].percent:IsShown(), "threat only hides the percentage")
M.Write(env, K, "threat.value", "both")

-- No hostile target: a note and no rows. A friendly target falls back to its target.
env._units.target = { name = "Kragar", hostile = false }
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(list.count == 0 and list.note:IsShown(), "no hostile target shows the note")
env._units.targettarget = { name = "Magmatus", hostile = true }
env.FireEvent("UNIT_TARGET", "target")
env.RunTimers()
assert(list.count == 3, "a friendly target's hostile target is used")
env._units.targettarget = nil
env._units.target = { name = "Magmatus", hostile = true }

-- Pets join the list.
env._units.pet = { name = "Wolf", class = "HUNTER" }
env._threat.pet = { false, 0, 10, 8, 100000 }
env.FireEvent("UNIT_PET", "player")
env.RunTimers()
assert(list.count == 4, "the pet is listed")
M.Write(env, K, "threat.pets", false)
assert(list.count == 3, "pets switched off are left out")

-- A raid lists raid units, with the player once.
env._group = { raid = true, size = 3 }
env._units.raid1 = env._units.player
env._units.raid2 = env._units.party1
env._units.raid3 = env._units.party2
env._threat.raid1, env._threat.raid2, env._threat.raid3 = env._threat.player, env._threat.party1, env._threat.party2
env.FireEvent("GROUP_ROSTER_UPDATE")
env.RunTimers()
assert(Threat.count == 3, "the raid lists three members once each, got " .. tostring(Threat.count))
env._units.raidpet2 = { name = "Imp", class = "WARLOCK" }
env._threat.raidpet2 = { false, 0, 5, 4, 50000 }
M.Write(env, K, "threat.pets", true)
assert(Threat.count == 5, "raid pets join, with the player's pet once, got " .. tostring(Threat.count))
assert(list.count == list.capacity, "the meter shows as many rows as fit")
M.Write(env, K, "threat.pets", false)

-- Solo, the meter hides unless it may show alone.
env._group = { raid = false, size = 0 }
env.FireEvent("GROUP_ROSTER_UPDATE")
env.RunTimers()
assert(not list.panel:IsShown(), "the meter hides while alone")
M.Write(env, K, "threat.group", false)
assert(list.panel:IsShown(), "the meter shows alone when allowed")

-- The rows that fit follow the element's height.
local capacity = list.capacity
K.Layout.Set("meters.threat", "height", 60)
env.RunTimers()
assert(list.capacity < capacity, "a shorter meter fits fewer rows")

-- Without the threat API the meter says so and raises nothing.
local env2, K2, ns2 = M.New({ noThreat = true })
env2._group = { raid = false, size = 1 }
env2._units.target = { name = "Boar", hostile = true }
M.Enable(env2, K2)
env2.RunTimers()
assert(ns2.Threat.list.note:IsShown(), "no threat API shows the note")
assert(M.Logged(env2, "UnitDetailedThreatSituation"), "the missing API is logged")
assert(#env2._errors == 0, "no Lua error: " .. tostring(env2._errors[1]))
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

print("meters threat ok")
