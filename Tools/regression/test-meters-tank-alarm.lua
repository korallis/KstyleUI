local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New()
local rows = {
	{ unit = "player", isPlayer = true, tanking = true, threat = 1000000 },
	{ unit = "party1", threat = 900000 },
}
assert(not ns.Threat.AlarmWanted(rows, 2), "90% itself is not yet passing 90%")
rows[2].threat = 900001
assert(ns.Threat.AlarmWanted(rows, 2), "a player passing 90% must raise the tank alarm")
rows[2].threat = env.Secret(950000)
assert(not ns.Threat.AlarmWanted(rows, 2), "never compare secret threat")
rows[2].threat, rows[2].unit = 950000, "partypet1"
assert(not ns.Threat.AlarmWanted(rows, 2), "the tank alarm watches other players")
rows[1].tanking = env.Secret(true)
assert(not ns.Threat.AlarmWanted(rows, 2), "secret tanking is not inferred")
rows[1].tanking, rows[2].unit = false, "party1"
assert(ns.Threat.AlarmWanted(rows, 2, true), "a known tank keeps the alarm after losing aggro")
env._group.size = 2
local tank = { name = "Tank", class = "WARRIOR" }
env._units.player, env._units.party1 = tank, { name = "Mage", class = "MAGE" }
env._units.target = { name = "Boss", hostile = true }
env._threat.player, env._threat.party1 = { true, 3, 100, 100, 1000000 }, { false, 2, 91, 91, 910000 }
M.Enable(env, K)
assert(ns.Threat.alarm, "the real threat event path raises the tank alarm")
local want = { K.Tokens.Color("hostile") }
local title = M.Last(ns.Threat.list.title, "SetTextColor")
assert(title[1] == want[1] and title[2] == want[2] and title[3] == want[3], "the alarm colours the card title hostile")
K.Layout.Update("meters.damage", { width = 300 })
env.RunTimers()
title = M.Last(ns.Threat.list.title, "SetTextColor")
assert(title[1] == want[1] and title[2] == want[2] and title[3] == want[3], "resizing the paired cards must preserve the tank alarm")
assert(ns.Threat.list.alarmFlash:IsPlaying(), "the alarm starts its flash")
local alpha = ns.Threat.list.alarmFlash._anims[1]
assert(alpha:GetDuration() == 0.2, "the alarm flash lasts 200 ms")
env.UnitGroupRolesAssigned = function() return "TANK" end
env._threat.player[1] = false
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(ns.Threat.alarm, "the known tank keeps the alarm after losing aggro")
env._threat.party1[5] = 800000
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(not ns.Threat.alarm, "the alarm clears when the other player falls below 90%")
assert(#env._errors == 0, tostring(env._errors[1]))

env._threat.party1[5] = 910000
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
assert(ns.Threat.alarm)
K.Options.Write("Meters", "threat.tankAlarm", false)
env.RunTimers()
assert(not ns.Threat.alarm and not ns.Threat.list.alarmFlash:IsPlaying(), "Tank alarm off restores the previous quiet title and edge")
K.Options.Write("Meters", "threat.tankAlarm", true)
env.RunTimers()
assert(ns.Threat.alarm, "Tank alarm can be turned back on")
assert(#env._errors == 0, tostring(env._errors[1]))

print("tank alarm ok")
