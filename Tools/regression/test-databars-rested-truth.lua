-- test-databars-rested-truth.lua: rested experience past one level reads as the game's figures give it (GetXPExhaustion against UnitXPMax), in the caption and in the tooltip, and a whole share reads as that whole number.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local _, _, plain = D.New({ enable = false })
local Format = plain.Format
local DOT = " \194\183 "

-- A fully rested character holds more than a level of rested experience.
local caption = Format.BarText("levelRested", 37000, 50000, "Level 8", "XP", 75000)
assert(caption == "Level 8" .. DOT .. "74%" .. DOT .. "rested 150%", "75,000 rested of a 50,000 level is 150%, KstyleUI shows " .. caption)
assert(Format.BarText("percentRested", 37000, 50000, nil, nil, 75000) == "74%" .. DOT .. "rested 150%", "and so in the short caption")
assert(Format.Percent(60000, 50000) == 100, "a bar's own progress still stops at 100%")

-- The share rounds up to a whole percent, and a share that is a whole percent reads as it: 57,500 of 50,000 is 115%.
for _, case in ipairs({ { 57500, 115 }, { 58000, 116 }, { 57499, 115 }, { 50000, 100 }, { 49999, 100 }, { 500, 1 }, { 499, 1 } }) do
	local shown = Format.Percent(case[1], 50000, true)
	assert(shown == case[2], case[1] .. " rested of a 50,000 level is " .. case[2] .. "%, KstyleUI shows " .. shown .. "%")
end
caption = Format.BarText("levelRested", 37000, 50000, "Level 8", "XP", 57500)
assert(caption == "Level 8" .. DOT .. "74%" .. DOT .. "rested 115%", "57,500 rested of a 50,000 level is 115%, KstyleUI shows " .. caption)
for _, earned in ipairs({ 29, 57, 58 }) do
	assert(Format.Percent(earned, 100) == earned, earned .. " of 100 is " .. earned .. "%, KstyleUI shows " .. Format.Percent(earned, 100) .. "%")
end

for _, case in ipairs({ { 75000, "75,000 (150%)" }, { 57500, "57,500 (115%)" } }) do
	local env, K, ns = D.New({ game = { xp = 37000, xpMax = 50000, rested = case[1] } })
	W.Settle(env)
	W.Enter(ns.Bars.views.xp.holder)
	local lines = {}
	for _, line in ipairs(K.Widgets.Tooltip().used) do
		lines[#lines + 1] = tostring(line.right and line.right:GetText())
	end
	local all = table.concat(lines, "|")
	assert(all:find(case[2], 1, true), "the tooltip gives the rested share as " .. case[2] .. ": " .. all)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("databars rested truth ok")
