-- test-worldmap-reopen.lua: view another zone or the continent, resize, close and reopen; no stale search list, and zone labels sized for the map's reset zoom.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, state, map = M.New(true)
local canvas, low = map:GetCanvas(), 0.6
canvas:SetScale(low)
-- Blizzard_MapCanvas.lua:944 and MapCanvas_ScrollContainerMixin.lua:236-242: the reset zoom's scale, and the canvas size callback.
function map:GetScaleForMinZoom() return low end
function map:OnCanvasSizeChanged() end
env.C_Map.GetMapInfo = function(id) return { mapType = id == 3 and 3 or 2 } end

-- Blizzard_WorldMap.lua:369-384: WorldMapMixin:OnShow puts the map back on the player's zone and refreshes its data.
local function Open()
	M.S.Show(map)
	map:SetMapID(1)
	map:RefreshAllDataProviders()
end
-- Hiding the map fires OnHide on its shown descendants in the client; the stub only flips the flag.
local function Close()
	map:Hide()
	R.panel:GetScript("OnHide")(R.panel)
end
local function Listed()
	local n = 0
	for _, frame in ipairs({ R.panel:GetChildren() }) do
		if frame:GetObjectType() == "Button" and frame:IsVisible() then n = n + 1 end
	end
	return n
end
local function Size()
	for _, region in ipairs({ canvas:GetRegions() }) do
		if region:GetObjectType() == "FontString" and region:IsShown() and region:GetText() == "Level 13-18" then return select(2, region:GetFont()) end
	end
end
-- The label's height on screen at the reset zoom, where the canvas scale is the map's lowest.
local function Screen() return Size() * map.ScrollContainer:GetEffectiveScale() * low end

Open()
R.search:SetText("")
for _, other in ipairs({ 3, 12 }) do
	R.search:GetScript("OnEditFocusGained")(R.search)
	assert(Listed() == 6, "focusing the empty search opens the nearest picker")
	R.search:SetText("Chasm")
	R.search:GetScript("OnTextChanged")(R.search, true)
	assert(Listed() == 1, "typing lists the map's destinations")
	map:SetMapID(other)
	Close()
	Open()
	assert(state.id == 1 and map:IsVisible(), "the map reopens on the player's zone")
	assert(Listed() == 0, "after viewing map " .. other .. ", closing and reopening, no search list from before the close is left under the box")
	assert(R.search:GetText() == "", "closing the map clears its search, as Blizzard clears the quest search")
	R.search:GetScript("OnEditFocusGained")(R.search)
	assert(Listed() == 6, "the nearest picker still opens after the reopen")
	R.search:GetScript("OnEscapePressed")(R.search)
end

local windowed, size = Screen(), Size()
canvas:SetScale(1.2)
map:RefreshAllDataProviders()
assert(Size() == size, "zooming in keeps the zone labels' size on the canvas, so they grow with the map")
-- Maximizing (Blizzard_WorldMap.lua:60-74) resizes the frame; the canvas gets a new reset zoom and Blizzard calls OnCanvasSizeChanged.
low = 0.9
canvas:SetScale(low)
map:SetSize(1600, 1000)
map:OnCanvasSizeChanged()
assert(math.abs(Screen() - windowed) < 1e-6, "maximized, the zone labels keep their windowed size on screen at the reset zoom: " .. Screen() .. " vs " .. windowed)
map:SetMapID(3)
map:SetMapID(12)
Close()
Open()
assert(math.abs(Screen() - windowed) < 1e-6, "after a zone, the continent, a close and a reopen the labels still fit the maximized map")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map reopen ok")
