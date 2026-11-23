-- test-worldmap-reveal.lua: unexplored overlays load and draw only when chosen with the map open, dimmed and laid out as Blizzard lays out explored ones.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M
local env, K, _, state, map = M.New()
Fixture.Install(env, state)
local explored, masks, refreshes = { { offsetX = 427, offsetY = 78 } }, 0, 0
local pin = env.CreateFrame("Frame", nil, map:GetCanvas())
pin.dataProvider = { GetDrawLayer = function() return "ARTWORK", 0 end }
function pin:RefreshOverlays() refreshes = refreshes + 1 end
state.pins.MapExplorationPinTemplate = pin
function map:GetCanvasContainer() return { GetCurrentLayerIndex = function() return 1 end } end
function map:AddMaskableTexture() masks = masks + 1 end
env.C_Map.GetMapArtLayers = function() return { { tileWidth = 256, tileHeight = 256 } } end
env.C_MapExplorationInfo = { GetExploredMapTextures = function(id) assert(id == 1411); return explored end }
state.id = 1411
map:Hide()
M.S.Show(map)
local function Shown()
	local list = {}
	for _, region in ipairs({ pin:GetRegions() }) do if region:IsShown() then list[#list + 1] = region end end
	return list
end
assert(not state.loads and #Shown() == 0, "off by default: no route data loads and the map shows only what Blizzard draws")

K.Options.Write("Skins", "worldMap.reveal", true)
local shown = Shown()
assert(state.loads == 1 and #shown == 11 and masks == 11, "Durotar's ten unexplored overlays draw as eleven tiles; the explored one stays Blizzard's")
local wide, partial
for _, texture in ipairs(shown) do
	local _, relative, _, x, y = texture:GetPoint(1)
	assert(relative == pin, "overlays sit on Blizzard's exploration pin, under its zoom and mask")
	local layer, sublevel = texture:GetDrawLayer()
	assert(layer == "ARTWORK" and sublevel == -1, "unexplored art draws just below explored art")
	local r, g, b = texture:GetVertexColor()
	local mr, mg, mb = K.Tokens.Color("muted")
	assert(r == mr and g == mg and b == mb, "unexplored overlays are dimmed with the muted token")
	if x == 500 and y == 0 then wide = texture end
	if x == 549 and y == -427 then partial = texture end
end
assert(wide and wide:GetTextureFileID() == 8074092, "a two-tile overlay places its second file one tile to the right")
assert(partial and partial:GetHeight() == 241, "a partial last tile keeps its own height")
local coords
for _, call in ipairs(partial._calls) do if call.method == "SetTexCoord" then coords = call.args end end
assert(coords and coords[4] == 241 / 256 and coords[2] == 1, "a partial tile crops to its power-of-two file as Blizzard's pin does")

explored[#explored + 1] = { offsetX = 549, offsetY = 427 }
pin:RefreshOverlays()
assert(refreshes == 1 and #Shown() == 10, "Blizzard's overlay refresh redraws, so newly explored areas lose their dim copy")
map:SetMapID(2)
pin:RefreshOverlays()
assert(#Shown() == 0, "a map without overlay data shows nothing extra")
map:SetMapID(1411)
pin:RefreshOverlays()
assert(#Shown() == 10 and state.loads == 1, "the overlay table loads once")
map:Hide()
pin:RefreshOverlays()
assert(#Shown() == 0, "a closed map draws nothing")
M.S.Show(map)
pin:RefreshOverlays()
K.Options.Write("Skins", "worldMap.reveal", false)
assert(#Shown() == 0, "switching it off removes every dimmed overlay")
local hides = 0
for _, region in ipairs({ pin:GetRegions() }) do
	local hide = region.Hide
	region.Hide = function(self) hides = hides + 1; return hide(self) end
end
pin:RefreshOverlays()
assert(hides == 0, "with reveal off, Blizzard's overlay refresh touches none of the hidden overlays")
K.Options.Write("Skins", "worldMap.reveal", true)
explored = { env.Secret({ offsetX = 427, offsetY = 78 }) }
local ok, err = pcall(pin.RefreshOverlays, pin)
assert(ok and #Shown() == 11, "a secret exploration record is skipped, not read: " .. tostring(err))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map reveal ok")
