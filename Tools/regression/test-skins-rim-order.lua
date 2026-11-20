-- test-skins-rim-order.lua: an item quality rim colours the socket's ring line only; no tinted fill covers the item, even when hidden chrome builds after the rim.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

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
	env.RunTimers()
	local ring = holder.chrome.rim
	assert(ring and #ring == 9, "the socket draws its ring line")
	for _, region in ipairs(ring) do
		assert(region:GetDrawLayer() == "BORDER", "the quality colour rides the ring line on BORDER")
		assert(W.SameColor(region, 0.2, 0.4, 0.8, 1), "the ring line wears the quality colour")
	end
	local fills = {}
	for _, region in ipairs(holder.chrome.fill) do fills[region] = true end
	for _, region in ipairs(holder._regions) do
		if region:GetDrawLayer() == "BACKGROUND" and not fills[region] and region:IsShown() then
			assert(not W.SameColor(region, 0.2, 0.4, 0.8), "Parts.Rim must not tint a filled shape over the socket; the quality colour belongs on the ring line")
		end
	end
	assert(W.SameRimColor(holder, 0.2, 0.4, 0.8), "GetRimColor reports the quality colour")
	holder:SetRimColor(nil)
	assert(holder:GetRimColor() == nil, "a cleared rim reports no colour")
	for _, region in ipairs(ring) do
		assert(not W.SameColor(region, 0.2, 0.4, 0.8), "a cleared rim returns the ring line to the socket edge")
	end
end

print("skins rim order ok")
