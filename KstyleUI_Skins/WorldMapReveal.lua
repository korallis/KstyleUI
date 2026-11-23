-- WorldMapReveal.lua: unexplored map overlays from the client's own overlay table, dimmed on Blizzard's exploration pin when chosen.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Skins, Lumen = ns.Skins, ns.Lumen

local map, pin, overlays, active
local textures, shown = {}, 0

local function Plain(value, kind)
	if not (type(issecretvalue) == "function" and issecretvalue(value)) and type(value) == kind then return value end
end

local function Size(total, tile, last)
	if not last then return tile, tile end
	local pixels = total % tile
	if pixels == 0 then pixels = tile end
	local file = 16
	while file < pixels do file = file * 2 end
	return pixels, file
end

local function Draw()
	for i = 1, shown do textures[i]:Hide() end
	shown = 0
	if not active or not pin or Skins.Setting("worldMap", "reveal") ~= true or not map:IsShown() then return end
	local id = Plain(map:GetMapID(), "number")
	if not overlays then
		if not rawget(_G, "KstyleUI_RouteData") and type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then C_AddOns.LoadAddOn("KstyleUI_Routes") end
		local data = rawget(_G, "KstyleUI_RouteData")
		if not data or type(data.overlays) ~= "function" then return end
		overlays, data.overlays = data.overlays(), nil
	end
	local list = id and overlays[id]
	local layers = list and type(C_Map) == "table" and type(C_Map.GetMapArtLayers) == "function" and Plain(C_Map.GetMapArtLayers(id), "table")
	local container = map.GetCanvasContainer and map:GetCanvasContainer()
	local layer = layers and container and container.GetCurrentLayerIndex and Plain(layers[container:GetCurrentLayerIndex()], "table")
	local tileWidth, tileHeight = layer and Plain(layer.tileWidth, "number"), layer and Plain(layer.tileHeight, "number")
	if not tileWidth or not tileHeight or type(C_MapExplorationInfo) ~= "table" or type(C_MapExplorationInfo.GetExploredMapTextures) ~= "function" then return end
	local explored = {}
	for _, info in ipairs(Plain(C_MapExplorationInfo.GetExploredMapTextures(id), "table") or {}) do
		info = Plain(info, "table") or {}
		local x, y = Plain(info.offsetX, "number"), Plain(info.offsetY, "number")
		if x and y then explored[x * 4096 + y] = true end
	end
	local drawLayer, subLevel = "ARTWORK", 0
	if type(pin.dataProvider) == "table" and type(pin.dataProvider.GetDrawLayer) == "function" then drawLayer, subLevel = pin.dataProvider:GetDrawLayer() end
	for _, overlay in ipairs(list) do
		local width, height, x, y = overlay[1], overlay[2], overlay[3], overlay[4]
		if not explored[x * 4096 + y] then
			local wide, tall = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
			for row = 1, tall do
				local pixelHeight, fileHeight = Size(height, tileHeight, row == tall)
				for column = 1, wide do
					local pixelWidth, fileWidth = Size(width, tileWidth, column == wide)
					shown = shown + 1
					local texture = textures[shown]
					if not texture then
						texture = pin:CreateTexture(nil, drawLayer, nil, math.max(-8, subLevel - 1))
						if type(map.AddMaskableTexture) == "function" then map:AddMaskableTexture(texture) end
						textures[shown] = texture
					end
					texture:SetSize(pixelWidth, pixelHeight)
					texture:SetTexCoord(0, pixelWidth / fileWidth, 0, pixelHeight / fileHeight)
					texture:ClearAllPoints()
					texture:SetPoint("TOPLEFT", pin, "TOPLEFT", x + tileWidth * (column - 1), -(y + tileHeight * (row - 1)))
					texture:SetTexture(overlay[4 + (row - 1) * wide + column], nil, nil, "TRILINEAR")
					texture:SetVertexColor(Lumen.Color("muted"))
					texture:Show()
				end
			end
		end
	end
end

local function Find()
	if pin or type(map.EnumeratePinsByTemplate) ~= "function" then return end
	for found in map:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
		if type(found.RefreshOverlays) == "function" then
			pin = found
			hooksecurefunc(pin, "RefreshOverlays", Draw)
			return
		end
	end
end

local def = Skins.Get("worldMap")
def.defaults.reveal = false
def.rows[#def.rows + 1] = { type = "toggle", key = "reveal", label = L["Reveal unexplored areas"], help = L["Show the map's unexplored areas, dimmed, from the game's own map art."] }

local apply, setting, switch = def.Apply, def.OnSetting, def.OnSwitch
def.Apply = function(self)
	apply(self)
	map = WorldMapFrame
	if type(map.GetMapID) ~= "function" then return end
	active = true
	map:HookScript("OnShow", function() if not pin then Find(); Draw() end end)
	Find()
	Draw()
end
def.OnSetting = function(self, key, value)
	if setting then setting(self, key, value) end
	if key == "reveal" and map then Draw() end
end
def.OnSwitch = function(self, on)
	if switch then switch(self, on) end
	active = on
	if map then Draw() end
end
