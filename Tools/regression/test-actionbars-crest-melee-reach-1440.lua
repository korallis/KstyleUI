-- test-actionbars-crest-melee-reach-1440.lua: test-actionbars-crest-melee-reach.lua's check at 2560x1440 and 3440x1440 in both layouts (Tools/regression/ranged_reach.lua).
local Reach = dofile("Tools/regression/ranged_reach.lua")
for _, low in ipairs({ false, true }) do
	Reach.Check({ { 2560, 1440 }, { 3440, 1440 } }, low, { "WARRIOR", "PALADIN", "ROGUE" }, nil, "crestRail")
end
print("actionbars crest melee reach 1440 ok")
