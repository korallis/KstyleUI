-- test-actionbars-crest-melee-reach.lua: at 1280x720 and 1920x1080 the warrior's, paladin's and rogue's cooldown rail at its widest, with its bursts, flares and lifts swept through their run and every second-rail medal's flight to the crown and back, draws no pixel at a quarter strength or more on an action slot, the level badge, a unit frame, a cast bar or the cooldown row, on the arc (cast bars on the unit frames) and on the low row (centred cast bars), one call each, measured alone (their armory pieces are measured by test-actionbars-crest-armory), so the rail is checked at six screens with the 1440 and wide files, each kept to two screens to stay inside the test runner's hang guard (Tools/regression/ranged_reach.lua; the other screens are test-actionbars-crest-melee-reach-1440.lua and test-actionbars-crest-melee-reach-wide.lua).
local Reach = dofile("Tools/regression/ranged_reach.lua")
for _, low in ipairs({ false, true }) do
	Reach.Check({ { 1280, 720 }, { 1920, 1080 } }, low, { "WARRIOR", "PALADIN", "ROGUE" }, nil, "crestRail")
end
print("actionbars crest melee reach ok")
