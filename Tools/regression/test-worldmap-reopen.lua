-- test-worldmap-reopen.lua: view another zone or the continent, resize, close and reopen; no open fade, no stale search list, and zone labels sized for the map's reset zoom.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, state, map = M.New(true)
local canvas = map:GetCanvas()
state.minZoom = 0.6
canvas:SetScale(state.minZoom)
-- Zones 1 (the player's) and 3 sit on continent 12. The dropdown, a click and the zoom-out button all end in SetMapID
-- (Blizzard_WorldMapTemplates.lua:523-525, Blizzard_MapCanvas.lua:1045-1060).
env.C_Map.GetMapInfo = function(id) return { mapType = id == 12 and 2 or 3 } end
local scans, children = 0, env.C_Map.GetMapChildrenInfo
env.C_Map.GetMapChildrenInfo = function(...) scans = scans + 1; return children(...) end

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
local function Screen() return Size() * map.ScrollContainer:GetEffectiveScale() * state.minZoom end
-- Blizzard_WorldMap.xml:67 makes WorldMapFrame a frame buffer. A reopen on another zone reloads the zone's tiles, which
-- Blizzard_MapCanvasDetailLayer.lua:46-104 and MapExplorationDataProvider.lua:85-103 hold at alpha 0 until IsObjectLoaded;
-- with an alpha animation on the frame buffer in game they stayed hidden, so the map opens without one.
local function Fading()
	for _, group in ipairs(map._groups or {}) do
		if group:IsPlaying() then return true end
	end
end

Open()
R.Pick({ kind = "quest", mapID = 1, name = "Target", x = 0.6, y = 0.4 })
R.search:SetText("")
for _, other in ipairs({ 3, 12 }) do
	R.search:GetScript("OnEditFocusGained")(R.search)
	assert(Listed() == 6 and not R.card:IsShown(), "focusing the empty search opens the nearest picker, which hides the route card it would cut through")
	R.search:SetText("Chasm")
	R.search:GetScript("OnTextChanged")(R.search, true)
	assert(Listed() == 1, "typing lists the map's destinations")
	map:SetMapID(other)
	Close()
	Open()
	assert(state.id == 1 and map:IsVisible() and not Size(), "the map reopens on the player's zone, which shows no zone level labels")
	assert(not Fading(), "after viewing map " .. other .. ", the reopened map plays no animation on WorldMapFrame, whose new tiles wait at alpha 0 to load")
	assert(Listed() == 0 and R.card:IsShown(), "after viewing map " .. other .. ", closing and reopening, no old search list is left and the route card is back")
	assert(R.search:GetText() == "", "closing the map clears its search, as Blizzard clears the quest search")
	R.search:GetScript("OnEditFocusGained")(R.search)
	assert(Listed() == 6, "the nearest picker still opens after the reopen")
	R.search:GetScript("OnEscapePressed")(R.search)
	assert(Listed() == 0 and R.card:IsShown(), "Escape closes the list and brings the route card back")
end

scans = 0
map:SetMapID(12)
assert(scans == 1 and Size(), "a switch to the continent reads its zones once and labels them")
local windowed, size = Screen(), Size()
canvas:SetScale(0.73)
map:RefreshAllDataProviders()
assert(Size() == size, "a refresh while zoomed in keeps the labels' size on the canvas, so they grow with the map")
-- Maximizing (Blizzard_WorldMap.lua:60-74) calls OnFrameSizeChanged, which resets the zoom after OnCanvasSizeChanged.
state.minZoom = 0.9
map:OnFrameSizeChanged()
assert(math.abs(Screen() - windowed) < 1e-6, "maximized, the zone labels keep their windowed size on screen at the reset zoom: " .. Screen() .. " vs " .. windowed)
map:SetMapID(3)
assert(not Size(), "a sibling zone shows no zone level labels")
map:SetMapID(12)
Close()
Open()
map:SetMapID(12)
assert(math.abs(Screen() - windowed) < 1e-6, "after a zone, the continent, a close and a reopen the labels still fit the maximized map")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map reopen ok")
