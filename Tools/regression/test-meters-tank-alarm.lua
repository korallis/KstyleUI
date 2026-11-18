local M = dofile("Tools/regression/meters_env.lua")
local env, _, ns = M.New()
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
assert(#env._errors == 0, tostring(env._errors[1]))
print("tank alarm ok")
