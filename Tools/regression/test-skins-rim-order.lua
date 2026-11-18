-- test-skins-rim-order.lua: an item quality rim stays above its fill even when hidden chrome builds after the rim.
local S = dofile("Tools/regression/skins_env.lua")

for _, hidden in ipairs({ false, true }) do
	local env, K, ns = S.New()
	local window = env.CreateFrame("Frame", nil, K.Scale.Root())
	window:SetShown(not hidden)
	local item = env.CreateFrame("Frame", nil, window)
	item:SetSize(40, 40)
	local holder = ns.Parts.Rim(item)
	holder:SetRimColor(0.2, 0.4, 0.8, 1)
	if hidden then assert(not holder.chrome.fill, "a hidden item must retain deferred chrome") end
	window:Show()
	local role, regions, order = {}, {}, {}
	for _, region in ipairs(holder.chrome.fill) do role[region] = "fill" end
	for _, region in ipairs(holder.rim) do role[region] = "rim" end
	for i, region in ipairs(holder._regions) do
		order[region] = i
		if role[region] then regions[#regions + 1] = region end
	end
	table.sort(regions, function(a, b)
		local al, az = a:GetDrawLayer()
		local bl, bz = b:GetDrawLayer()
		assert(al == "BACKGROUND" and bl == al, "item fill and quality rim must stay on BACKGROUND")
		if az ~= bz then return az < bz end
		return order[a] < order[b]
	end)
	assert(#regions == 18, "compare every fill and quality-rim piece")
	for i, region in ipairs(regions) do
		assert(role[region] == (i <= 9 and "fill" or "rim"), "Parts.Rim must draw fill < quality rim; reserve a sublevel above the deferred fill")
	end
end

print("skins rim order ok")
