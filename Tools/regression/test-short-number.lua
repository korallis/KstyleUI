-- test-short-number.lua: shared short-number boundaries, truncation, sign, scaled threat and secret formatting.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New()
local Short = K.Widgets.ShortNumber
assert(ns.Logic.Abbreviate == Short, "meters must use the shared formatter")
local cases = {
	{ 1, "1" }, { 412.7, "412" }, { 999.9, "999" }, { 1000, "1K" }, { 1240, "1.2K" },
	{ 9999, "9.9K" }, { 10000, "10K" }, { 12400, "12.4K" }, { 123456, "123.4K" },
	{ 999999, "999.9K" }, { 1000000, "1M" }, { 1240000, "1.2M" },
	{ 12400000, "12.4M" }, { 1000000000, "1B" }, { 12400000000, "12.4B" },
}
for _, unit in ipairs({ 1, 100 }) do
	for _, case in ipairs(cases) do
		local value = case[1] * unit
		assert(Short(value, unit) == case[2], value .. " / " .. unit .. " must read " .. case[2])
		local hidden = Short(env.Secret(value), unit)
		assert(env.issecretvalue(hidden), "secret numbers must remain secret through the engine")
		assert(env.Reveal(hidden) == case[2], "plain and secret formats must match at " .. value)
	end
end
for _, value in ipairs({ 0, 0.5, 0.999 }) do
	assert(Short(value) == "0", "a readable value under one must read 0")
end
for _, value in ipairs({ "12400", false, math.huge, -math.huge, 0 / 0 }) do
	assert(Short(value) == "", "invalid numbers must show nothing")
end
assert(Short(-12345) == "-12.3K" and Short(-0.5) == "0", "negative public numbers keep their sign without negative zero")
assert(Short(nil) == "", "a missing number must show nothing")
assert(#env._errors == 0 and K.ErrorCount() == 0, "formatting must not raise a Lua error")

local missing, missingK = M.New({ game = function(e)
	e.AbbreviateNumbers, e.AbbreviateLargeNumbers = nil, nil
end })
assert(missingK.Widgets.ShortNumber(12400) == "12.4K", "readable numbers need no engine formatter")
assert(missingK.Widgets.ShortNumber(missing.Secret(12400)) == "", "without an engine, a hidden number must show nothing")

local hiddenProbe, probeK = M.New({ game = function(e)
	local game = e.AbbreviateNumbers
	e.AbbreviateNumbers = function(value, options)
		if options and not e.issecretvalue(value) then return e.Secret("probe") end
		return game(value, options)
	end
end })
assert(hiddenProbe.Reveal(probeK.Widgets.ShortNumber(hiddenProbe.Secret(2840))) == "2.84K", "a hidden probe must fall back without comparing its text")
print("short-number contract ok")
