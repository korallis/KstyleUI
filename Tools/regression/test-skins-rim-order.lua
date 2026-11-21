-- test-skins-rim-order.lua: an item quality rim colours the socket's shown ring line only, at every screen size; no tinted shape covers the item, and clearing restores the plain socket edge, even when hidden chrome builds after the rim.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, hidden in ipairs({ false, true }) do
		local env, K, ns = S.New({ width = screen[1], height = screen[2], size = "auto" })
		local window = env.CreateFrame("Frame", nil, K.Scale.Root())
		window:SetShown(not hidden)
		local item, plain = env.CreateFrame("Frame", nil, window), env.CreateFrame("Frame", nil, window)
		item:SetSize(40, 40)
		plain:SetSize(40, 40)
		local holder, bare = ns.Parts.Rim(item), ns.Parts.Rim(plain)
		holder:SetRimColor(0.2, 0.4, 0.8, 1)
		if hidden then assert(not holder.chrome.fill, "a hidden item must retain deferred chrome") end
		window:Show()
		env.RunTimers()
		local ring, isRing = holder.chrome.rim, {}
		assert(ring and #ring == 9, "the socket draws its ring line")
		for i, region in ipairs(ring) do
			isRing[region] = true
			assert(region:IsVisible() == (i ~= 5) and region:GetDrawLayer() == "BORDER", "the quality colour rides the shown ring line on BORDER, its transparent centre hidden")
			assert(W.SameColor(region, 0.2, 0.4, 0.8, 1), "the ring line wears the quality colour")
		end
		for _, region in ipairs(holder._regions) do
			if not isRing[region] and region:IsVisible() then
				assert(not W.SameRGB(region, 0.2, 0.4, 0.8), "Parts.Rim must not tint any shape over the socket, its fill included; the quality colour belongs on the ring line")
			end
		end
		assert(W.SameRimColor(holder, 0.2, 0.4, 0.8), "GetRimColor reports the quality colour")
		holder:SetRimColor(nil)
		assert(holder:GetRimColor() == nil, "a cleared rim reports no colour")
		for i, region in ipairs(ring) do
			assert(region:IsVisible() == (i ~= 5) and W.SameColor(region, bare.chrome.rim[i]:GetVertexColor()), "a cleared rim returns the ring line to the plain socket edge")
		end
	end
end

print("skins rim order ok")
