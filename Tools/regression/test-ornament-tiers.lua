-- test-ornament-tiers.lua: a piece the reach table did not ship resolves to the nearest smaller shipped tier or is dropped, never a missing texture.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local widgets, assets = K.Widgets, K.Widgets.OrnamentAssets
local profile = K.Store.Module("Widgets")
profile.ornaments, profile.cardMaterial = "Full", "ForgedBrackets"
local shipped = {}
for name, spec in pairs(assets) do
	shipped[name] = spec
end
local function restore()
	for name in pairs(assets) do
		assets[name] = nil
	end
	for name, spec in pairs(shipped) do
		assets[name] = spec
	end
end
local function drawn(handle, label)
	local names = {}
	for i = 1, handle.used do
		local t = handle.textures[i]
		if t:IsShown() then
			local path = t:GetTexture()
			local name = assert(type(path) == "string" and path:match("ForgedOrnaments\\(%w+)%.png$"), label .. ": not an ornament path " .. tostring(path))
			assert(assets[name], label .. ": draws " .. name .. ", which is not shipped")
			local file = io.open("Media/Textures/ForgedOrnaments/" .. name .. ".png", "rb")
			assert(file, label .. ": draws " .. name .. ", which has no file")
			file:close()
			names[#names + 1] = name
		end
	end
	return names
end
local function find(names, family)
	for _, name in ipairs(names) do
		local n = name:match("^" .. family .. "(%d+)$")
		if n then
			return tonumber(n)
		end
	end
end
local function largest(family, ceiling, floor)
	local best
	for name in pairs(assets) do
		local n = tonumber(name:match("^" .. family .. "(%d+)$"))
		if n and n <= ceiling and n >= (floor or 0) and (not best or n > best) then
			best = n
		end
	end
	return best
end

local root = K.Scale.Root()
local frame = env.CreateFrame("Frame", nil, root)
local pixel = K.Scale.Pixel(1) / widgets.ScaleFactor(frame)
frame:SetPoint("TOPLEFT", root, "TOPLEFT", 240 * pixel, -220 * pixel)
local ring = widgets.Ornament(frame, "ring")
local HOLES = { 14, 17, 20, 24, 28, 32, 38, 44, 52, 60, 70, 80 }
local checked, bands, pendants, pieces = 0, 0, 0, 0
for side = 24, 160 do
	frame:SetSize(side * pixel, side * pixel)
	local even = math.floor((side + 1) / 2) * 2
	local function band()
		return assets["Ring" .. side] and side or largest("Ring", even, 25)
	end
	for _, rank in ipairs({ "elite", "boss" }) do
		ring.player, ring.elite, ring.boss = false, true, rank == "boss"
		local family = rank == "boss" and "BossPendantR" or "ElitePendantR"
		local hole = side / 2 + 1
		local ideal = HOLES[#HOLES]
		for i = #HOLES, 1, -1 do
			if HOLES[i] >= hole then
				ideal = HOLES[i]
			end
		end
		ring:Restyle()
		local names = drawn(ring, rank .. " " .. side)
		local ringTier = find(names, "Ring")
		assert(ringTier == band(), rank .. " " .. side .. ": the band is its exact authored ring or the nearest shipped tier at or below Ring" .. even .. ", got " .. tostring(ringTier))
		local pendant = find(names, family)
		bands, pendants = bands + (ringTier and 1 or 0), pendants + (pendant and 1 or 0)
		local expected = largest(family, ideal, HOLES[1])
		assert(pendant == expected, rank .. " " .. side .. ": the pendant is the nearest shipped tier at or below " .. ideal .. ", got " .. tostring(pendant))
		if ringTier then
			assets["Ring" .. ringTier] = nil
			ring:Restyle()
			local again = find(drawn(ring, rank .. " " .. side .. " without Ring" .. ringTier), "Ring")
			assert(again == band() and (again == nil or again <= even), rank .. " " .. side .. ": without Ring" .. ringTier .. " the band steps down to the next shipped tier, got " .. tostring(again))
			restore()
		end
		if pendant then
			assets[family .. pendant] = nil
			ring:Restyle()
			local again = find(drawn(ring, rank .. " " .. side .. " without " .. family .. pendant), family)
			assert(again == largest(family, ideal, HOLES[1]), rank .. " " .. side .. ": without " .. family .. pendant .. " the pendant steps down, got " .. tostring(again))
			restore()
		end
		for name in pairs(shipped) do
			if name:find("^" .. family) or name:find("^Ring") then
				assets[name] = nil
			end
		end
		ring:Restyle()
		local bare = drawn(ring, rank .. " " .. side .. " with no shipped tier")
		assert(not find(bare, "Ring") and not find(bare, family), rank .. " " .. side .. ": with no shipped tier the band and pendant are dropped")
		restore()
		checked = checked + 1
	end
end

local bar = env.CreateFrame("Frame", nil, root)
bar:SetPoint("TOPLEFT", root, "TOPLEFT", 500 * pixel, -300 * pixel)
local caps = widgets.Ornament(bar, "bar")
local names = {}
for name in pairs(shipped) do
	names[#names + 1] = name
end
table.sort(names)
math.randomseed(23)
for trial = 1, 40 do
	for _, name in ipairs(names) do
		if math.random() < 0.35 then
			assets[name] = nil
		end
	end
	for _, level in ipairs({ "Subtle", "Full" }) do
		profile.ornaments = level
		for _, height in ipairs({ 4, 6, 8, 10, 13, 16, 22, 30 }) do
			bar:SetSize(140 * pixel, height * pixel)
			caps:Restyle()
			pieces = pieces + #drawn(caps, "trial " .. trial .. " " .. level .. " bar " .. height)
		end
		for _, side in ipairs({ 30, 47, 64, 99, 140 }) do
			frame:SetSize(side * pixel, side * pixel)
			ring.elite, ring.boss = trial % 2 == 0, trial % 3 == 0
			ring:Restyle()
			pieces = pieces + #drawn(ring, "trial " .. trial .. " " .. level .. " ring " .. side)
		end
	end
	restore()
end
assert(bands > checked * 0.9 and pendants > checked / 2 and pieces > 1000, "the cases draw: " .. bands .. " bands, " .. pendants .. " pendants, " .. pieces .. " thinned pieces")
print("ok ornament tiers: " .. checked .. " ring and pendant cases step down or drop, and 40 thinned asset tables drew " .. pieces .. " pieces, all shipped")
