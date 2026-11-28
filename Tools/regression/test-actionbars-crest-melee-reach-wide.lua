-- test-actionbars-crest-melee-reach-wide.lua: test-actionbars-crest-melee-reach.lua's check at 5120x1440 and 3840x2160 in both layouts (Tools/regression/ranged_reach.lua).
local Reach = dofile("Tools/regression/ranged_reach.lua")
for _, low in ipairs({ false, true }) do
	Reach.Check({ { 5120, 1440 }, { 3840, 2160 } }, low, { "WARRIOR", "PALADIN", "ROGUE" }, nil, "crestRail")
end
print("actionbars crest melee reach wide ok")
