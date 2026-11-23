-- test-worldmap-reopen.lua: open the map, search, view a sibling zone or the continent, close and reopen; no stale search list comes back.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, state, map = M.New()

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

R.search:SetText("")
for _, other in ipairs({ 2, 12 }) do
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
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map reopen ok")
