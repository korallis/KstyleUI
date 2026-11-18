-- test-quality-boundaries.lua: module palette switches never change unscoped quality colours used by loot and native skin rims.
local T = dofile("Tools/regression/tooltips_env.lua")
local env, K = T.New()
local profile = K.Store.Profile()
local original = { K.Theme.QualityColor(2, false) }
for _, tooltip in ipairs({ false, true }) do
	for _, bag in ipairs({ false, true }) do
		profile.Tooltips = profile.Tooltips or {}
		profile.Bags = profile.Bags or {}
		profile.Tooltips.qualityColors, profile.Bags.qualityColors = tooltip, bag
		local plain = { K.Theme.QualityColor(2) }
		for i = 1, 3 do assert(plain[i] == original[i], "loot feed and skin rims retain their original palette regardless of module switches") end
		local refined = { K.Theme.QualityColor(2, true) }
		local named = { K.Tokens.Color("uncommon") }
		for i = 1, 3 do assert(refined[i] == named[i], "explicit module consumers can select the refined palette") end
	end
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("quality boundaries: module switches are explicit and unscoped colours stay original")
