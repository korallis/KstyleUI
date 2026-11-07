-- test-meters-logic.lua: the Meters module's pure rules: readable numbers, percentages, swing progress, threat sorting and threat warnings.
local M = dofile("Tools/regression/meters_env.lua")

local env, _, ns = M.New()
local Logic = ns.Logic
assert(type(Logic) == "table", "KstyleUI_Meters exposes its rules as ns.Logic")
local S = env.Secret

-- Plain: only a readable, finite number passes.
assert(Logic.Plain(5) == 5, "a plain number passes")
assert(Logic.Plain(0) == 0, "zero passes")
assert(Logic.Plain(S(5)) == nil, "a secret number never passes")
assert(Logic.Plain("5") == nil, "a string is not a number")
assert(Logic.Plain(0 / 0) == nil, "NaN does not pass")
assert(Logic.Plain(math.huge) == nil, "infinity does not pass")
assert(Logic.Plain(nil) == nil, "nil does not pass")

-- Percent: a whole percentage of readable values only.
assert(Logic.Percent(25, 100) == 25, "25 of 100 is 25%")
assert(Logic.Percent(1, 3) == 33, "a third rounds to 33%")
assert(Logic.Percent(2, 3) == 67, "two thirds round to 67%")
assert(Logic.Percent(5, 0) == nil, "no total gives no percentage")
assert(Logic.Percent(S(5), 100) == nil, "a secret part gives no percentage")
assert(Logic.Percent(5, S(100)) == nil, "a secret total gives no percentage")
assert(Logic.FormatPercent(42) == "42%", "a percentage reads 42%")
assert(Logic.FormatPercent(nil) == "", "no percentage reads as empty text")

-- Abbreviate: the game's AbbreviateNumbers for plain and secret numbers alike.
assert(Logic.Abbreviate(2840) == "~2840", "a plain number goes through AbbreviateNumbers")
assert(env.issecretvalue(Logic.Abbreviate(S(2840))), "a secret goes through AbbreviateNumbers whole")
assert(Logic.Abbreviate(nil) == "", "nothing reads as empty text")
local abbreviate = env.AbbreviateNumbers
env.AbbreviateNumbers = nil
assert(Logic.Abbreviate(2840.4) == "2840", "without AbbreviateNumbers a plain number is rounded")
assert(Logic.Abbreviate(S(2840)) == "", "without AbbreviateNumbers a secret shows nothing")
env.AbbreviateNumbers = abbreviate

-- SwingProgress(start, duration, now) -> fraction, remaining, done.
local f, left, done = Logic.SwingProgress(10, 2, 11)
assert(f == 0.5 and left == 1 and done == false, "halfway through a 2 s swing")
f, left, done = Logic.SwingProgress(10, 2, 12.5)
assert(f == 1 and left == 0 and done == true, "a swing past its end is done")
f, left, done = Logic.SwingProgress(10, 2, 9)
assert(f == 0 and left == 2 and done == false, "a clock before the start counts as the start")
assert(Logic.SwingProgress(10, 0, 11) == nil, "a zero duration has no progress")
assert(Logic.SwingProgress(10, S(2), 11) == nil, "a secret duration has no Lua progress")
assert(Logic.FormatSeconds(1.04) == "1.0", "seconds read with one decimal")

-- Sizes.
assert(Logic.FitRows(98, 18, 2) == 5, "five 18-unit rows with 2-unit gaps fit in 98 units")
assert(Logic.FitRows(97, 18, 2) == 4, "a unit short fits one row fewer")
assert(Logic.FitRows(-4, 18, 2) == 0, "no room fits no row")
assert(Logic.Split(8, 1, 1) == 8, "one bar takes the whole height")
assert(Logic.Split(8, 2, 1) == 3.5, "two bars share the height around one gap")
assert(Logic.Split(8, 0, 1) == 0, "no bars take no room")

-- ThreatAmount: Blizzard's threat values are a hundred times the threat points.
assert(Logic.ThreatAmount(3240000) == 32400, "raw threat reads in threat points")
assert(Logic.ThreatAmount(S(5)) == nil, "secret threat has no Lua amount")

-- SortRows(rows, order, count, field) sorts order by the field, highest first, keeping ties in place.
local rows = {
	{ id = "a", scaled = 20 }, { id = "b", scaled = 80 }, { id = "c", scaled = 50 }, { id = "d", scaled = 80 },
}
local order = { 1, 2, 3, 4 }
assert(Logic.SortRows(rows, order, 4, "scaled") == true, "readable values sort")
local ids = {}
for i = 1, 4 do
	ids[i] = rows[order[i]].id
end
assert(table.concat(ids) == "bdca", "highest first, ties keep their order: " .. table.concat(ids))

rows[3].scaled = nil
order = { 1, 2, 3, 4 }
Logic.SortRows(rows, order, 4, "scaled")
assert(rows[order[4]].id == "c", "a missing value sorts last")

rows[1].scaled = S(99)
order = { 1, 2, 3, 4 }
assert(Logic.SortRows(rows, order, 4, "scaled") == false, "a secret value stops the sort")
assert(order[1] == 1 and order[2] == 2 and order[3] == 3 and order[4] == 4, "the order stays as it was")

order = { 3, 1, 2, 4 }
assert(Logic.SortRows(rows, order, 2, "scaled") == false, "a secret among the counted rows stops the sort")

-- ThreatWarning(rows, count, warnAt, dangerAt) -> 0 none, 1 warn, 2 danger.
local function threat(list)
	return Logic.ThreatWarning(list, #list, 80, 95)
end
assert(threat({ { isPlayer = true, tanking = false, scaled = 50 } }) == 0, "50% is calm")
assert(threat({ { isPlayer = true, tanking = false, scaled = 85 } }) == 1, "85% warns")
assert(threat({ { isPlayer = true, tanking = false, scaled = 96 } }) == 2, "96% is danger")
assert(threat({ { isPlayer = true, tanking = false, scaled = 80 } }) == 1, "the warning starts at its threshold")
assert(threat({ { isPlayer = true, tanking = false, scaled = S(99) } }) == 0, "a secret percentage never warns")
assert(threat({ { isPlayer = true, tanking = S(false), scaled = 99 } }) == 0, "a secret tanking flag never warns")
assert(threat({ { isPlayer = false, tanking = false, scaled = 99 } }) == 0, "no player row, no warning")
assert(threat({
	{ isPlayer = true, tanking = true, scaled = 100 },
	{ isPlayer = false, tanking = false, scaled = 90 },
}) == 1, "a tank is warned when another member nears aggro")
assert(threat({
	{ isPlayer = true, tanking = true, scaled = 100 },
	{ isPlayer = false, tanking = false, scaled = 70 },
	{ isPlayer = false, tanking = false, scaled = 99 },
}) == 2, "a tank is in danger when another member is about to pull")
assert(threat({
	{ isPlayer = true, tanking = true, scaled = 100 },
	{ isPlayer = false, tanking = false, scaled = S(99) },
}) == 0, "a secret percentage of another member is skipped")
assert(Logic.ThreatWarning({ { isPlayer = true, tanking = false, scaled = 87 } }, 1, 90, 85) == 0,
	"danger never starts below the warning threshold")
assert(Logic.ThreatWarning({ { isPlayer = true, tanking = false, scaled = 92 } }, 1, 90, 85) == 2,
	"when the warning threshold is above danger, crossing it is danger")
assert(Logic.ThreatWarning({ { isPlayer = true, tanking = false, scaled = 99 } }, 0, 80, 95) == 0,
	"rows past the count are ignored")

print("meters logic ok")

-- Combat paths allocate nothing: setting reads, colours, sorting and warnings. LuaJIT's trace
-- compiler allocates GC objects of its own, so the measurement runs with the JIT off.
local K = env.KstyleUI
K.Modules.Enable("Meters")
env.RunTimers()
local warm = { { isPlayer = true, tanking = false, scaled = 85 }, { isPlayer = false, tanking = true, scaled = 100 } }
local warmOrder = { 1, 2 }
local function Work()
	ns.Get("damage.color")
	ns.Get("swing.time")
	ns.Get("threat.warnAt")
	ns.Get("damage.meter")
	ns.BarColor("damage", "WARRIOR", "friendly")
	ns.BarColor("threat", "", "hostile")
	Logic.SortRows(warm, warmOrder, 2, "scaled")
	Logic.ThreatWarning(warm, 2, 80, 95)
	Logic.Percent(25, 100)
	Logic.SwingProgress(10, 2, 11)
end
Work()
local jit = rawget(_G, "jit")
if jit then
	jit.off()
	jit.flush()
end
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 1000 do
	Work()
end
local grown = collectgarbage("count") - before
collectgarbage("restart")
if jit then
	jit.on()
end
assert(grown == 0, "the meters' combat-path helpers allocate nothing, grew " .. grown .. " KB")

print("meters allocation ok")
