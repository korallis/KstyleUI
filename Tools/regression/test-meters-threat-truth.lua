-- test-meters-threat-truth.lua: a threat value the game hides reads the same on the threat meter as the same value in the open.
local M = dofile("Tools/regression/meters_env.lua")

local env, K, ns = M.New()
local S = env.Secret

-- C_StringUtil.RoundToNearestString (StringUtilDocumentation.lua: SecretArguments = "AllowedWhenTainted").
env.C_StringUtil = env.C_StringUtil or {}
env.C_StringUtil.RoundToNearestString = function(value)
	local text = string.format("%.0f", math.floor(env.Reveal(value) + 0.5))
	return env.issecretvalue(value) and S(text) or text
end

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	local text = args and args[1]
	return env.issecretvalue(text) and env.Reveal(text) or text
end

env._group = { raid = false, size = 2 }
env._units.party1 = { name = "Kragar", class = "WARRIOR" }
env._units.target = { name = "Magmatus", hostile = true }
env._threat.player = { false, 1, 99.6, 90, 1234500 }
env._threat.party1 = { true, 3, 100, 100, 1240000 }
M.Enable(env, K)
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
local list = ns.Threat.list

local function Row(name)
	for i = 1, list.count do
		if Text(list.rows[i].name) == name then
			return Text(list.rows[i].value), Text(list.rows[i].percent)
		end
	end
end

local openValue, openPercent = Row("Tester")
assert(openValue == "12K" and openPercent == "100%", "in the open 1,234,500 raw threat at 99.6% reads 12K and 100%: " .. tostring(openValue) .. ", " .. tostring(openPercent))

-- The same threat against a boss (UnitDetailedThreatSituation: SecretWhenUnitThreatValuesRestricted).
env._threat.player = { S(false), S(1), S(99.6), S(90), S(1234500) }
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
env.RunTimers()
local value, percent = Row("Tester")
assert(value == openValue, "hidden raw threat reads in threat points: the game's value shows as " .. openValue .. ", KstyleUI shows " .. tostring(value))
assert(percent == openPercent, "a hidden share of aggro rounds as it does in the open: " .. openPercent .. ", KstyleUI shows " .. tostring(percent))
assert(Text(list.column) == openPercent, "and so does the count in the cap: " .. tostring(Text(list.column)))

-- A client that refuses the threat breakpoints shows no figure, not one a hundred times too large.
local refusing, RK, rns = M.New({ game = function(e)
	e.AbbreviateNumbers = function()
		error("refused")
	end
end })
refusing._group = { raid = false, size = 2 }
refusing._units.target = { name = "Magmatus", hostile = true }
refusing._threat.player = { S(false), S(1), S(60), S(50), S(1234500) }
M.Enable(refusing, RK)
refusing.FireEvent("PLAYER_TARGET_CHANGED")
refusing.RunTimers()
local shown = M.Last(rns.Threat.list.rows[1].value, "SetText")[1]
assert(shown == "", "no threat breakpoints, no threat figure: " .. tostring(refusing.issecretvalue(shown) and refusing.Reveal(shown) or shown))

assert(#env._errors == 0 and #refusing._errors == 0, "no Lua error: " .. tostring(env._errors[1] or refusing._errors[1]))
print("meters threat truth ok")
