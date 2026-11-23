-- worldmap_reveal.lua: Durotar's unexplored overlays dimmed beside explored ones. RENDER_MAP_TILES lists the zone's twelve base art file ids (row-major, four wide) and the icon cache must hold them and the overlay tiles as <fileID>.png, all from the owner's client; RENDER_MAP_BEFORE=1 leaves the option off.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M

local function Place(frame, files, width, height, x, y, layer, sublevel, dim)
	local wide, tall = math.ceil(width / 256), math.ceil(height / 256)
	for row = 1, tall do
		for column = 1, wide do
			local texture = frame:CreateTexture(nil, layer, nil, sublevel)
			local w = column < wide and 256 or (width - 256 * (wide - 1))
			local h = row < tall and 256 or (height - 256 * (tall - 1))
			texture:SetSize(w, h)
			texture:SetTexCoord(0, w / 256, 0, h / 256)
			texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x + 256 * (column - 1), -(y + 256 * (row - 1)))
			texture:SetTexture(files[(row - 1) * wide + column])
			if dim then texture:SetVertexColor(dim, dim, dim) end
		end
	end
end

return Common.Run(function()
	local map, state
	local env, K = M.S.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Skins" }), setup = Gallery.Setup,
		before = function(e)
			map = M.Windows.Build("worldmap", e, M.S.Blizzard(e))
			state = M.Setup(e, map)
			map:ClearAllPoints()
			map:SetPoint("CENTER", e.UIParent, "CENTER", -165, 0)
		end,
	}))
	Fixture.Install(env, state)
	state.id = 1411
	for _, pin in pairs(state.pins) do pin:Hide() end
	local canvas = map:GetCanvas()
	local art, pin = env.CreateFrame("Frame", nil, canvas), env.CreateFrame("Frame", nil, canvas)
	for _, frame in ipairs({ art, pin }) do frame:SetSize(1002, 668); frame:SetPoint("TOPLEFT", canvas, "TOPLEFT") end
	pin.dataProvider = { GetDrawLayer = function() return "ARTWORK", 0 end }
	function pin:RefreshOverlays() end
	state.pins.MapExplorationPinTemplate = pin
	function map:GetCanvasContainer() return { GetCurrentLayerIndex = function() return 1 end } end
	function map:AddMaskableTexture() end
	env.C_Map.GetMapArtLayers = function() return { { tileWidth = 256, tileHeight = 256 } } end
	env.C_AddOns.LoadAddOn("KstyleUI_Routes")
	local overlays, explored = env.KstyleUI_RouteData.overlays()[1411], {}
	for i, overlay in ipairs(overlays) do
		if i % 2 == 1 then
			explored[#explored + 1] = { offsetX = overlay[3], offsetY = overlay[4] }
			Place(pin, { select(5, unpack(overlay)) }, overlay[1], overlay[2], overlay[3], overlay[4], "ARTWORK", 0)
		end
	end
	env.C_MapExplorationInfo = { GetExploredMapTextures = function() return explored end }
	local tiles = {}
	for id in (os.getenv("RENDER_MAP_TILES") or ""):gmatch("%d+") do tiles[#tiles + 1] = tonumber(id) end
	if #tiles == 12 then Place(art, tiles, 1024, 768, 0, 0, "BACKGROUND", 0) end
	K.Modules.Enable("Skins")
	M.S.LoadAddOn(env, "Blizzard_WorldMap")
	M.S.Show(map)
	M.S.Show(env.QuestMapFrame)
	env.RunTimers()
	M.S.W.Settle(env)
	local scale = canvas:GetWidth() / 1002
	art:SetScale(scale)
	pin:SetScale(scale)
	if os.getenv("RENDER_MAP_BEFORE") ~= "1" then K.Options.Write("Skins", "worldMap.reveal", true) end
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = (#tiles == 12 and "Client Durotar art and overlay tiles; " or "No base art; ") .. "odd overlays stand in for explored ones, as Blizzard's pin draws them, and the rest come from the shipped overlay table."
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return scene
end)
