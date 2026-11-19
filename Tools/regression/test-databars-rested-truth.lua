-- test-databars-rested-truth.lua: rested experience past one level reads as the game's figures give it (GetXPExhaustion against UnitXPMax), in the caption and in the tooltip.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

-- A fully rested character holds a level and a half of rested experience.
local env, K, ns = D.New({ game = { xp = 37000, xpMax = 50000, rested = 75000 } })
W.Settle(env)
local Format = ns.Format
local DOT = " \194\183 "

local caption = Format.BarText("levelRested", 37000, 50000, "Level 8", "XP", 75000)
assert(caption == "Level 8" .. DOT .. "74%" .. DOT .. "rested 150%", "75,000 rested of a 50,000 level is 150%, KstyleUI shows " .. caption)
assert(Format.BarText("percentRested", 37000, 50000, nil, nil, 75000) == "74%" .. DOT .. "rested 150%", "and so in the short caption")
assert(Format.Percent(60000, 50000) == 100, "a bar's own progress still stops at 100%")

W.Enter(ns.Bars.views.xp.holder)
local lines = {}
for _, line in ipairs(K.Widgets.Tooltip().used) do
	lines[#lines + 1] = tostring(line.right and line.right:GetText())
end
local all = table.concat(lines, "|")
assert(all:find("75,000 (150%)", 1, true), "the tooltip gives 75,000 rested as 150% of the level: " .. all)
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databars rested truth ok")
