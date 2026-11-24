-- worldmap_routes.lua: client destination search and a straight route in the real world map skin, over a game plate.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local M = dofile("Tools/regression/worldmap_env.lua")

return Common.Run(function()
	local map, state
	local env, K, ns = M.S.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Skins" }),
		setup = Gallery.Setup,
		before = function(e)
			map = M.Windows.Build("worldmap", e, M.S.Blizzard(e))
			state = M.Setup(e, map)
			map:ClearAllPoints()
			map:SetPoint("CENTER", e.UIParent, "CENTER", -165, 0)
		end,
	}))
	-- RENDER_MAP_ZONE=orgrimmar|kalimdor names the nav bar's breadcrumbs in the scene's locale and paints RENDER_MAP_ART
	-- (client-extracted Kalimdor art) on the canvas, cropped to Orgrimmar's corner for the city.
	local zone, art = os.getenv("RENDER_MAP_ZONE"), os.getenv("RENDER_MAP_ART")
	if zone then
		local crumbs = (env.GetLocale() == "deDE" and "Welt" or "World") .. "  >  Kalimdor" .. (zone == "orgrimmar" and "  >  Orgrimmar" or "")
		select(1, map.NavBar.home:GetRegions()):SetText(crumbs)
		for _, pin in pairs(state.pins) do pin:Hide() end
		env.C_Map.GetMapInfo = function() return { mapType = zone == "kalimdor" and 2 or 3 } end
		if art then
			local texture = map:GetCanvas():CreateTexture(nil, "BACKGROUND")
			texture:SetAllPoints(map:GetCanvas())
			texture:SetTexture(art)
			if zone == "orgrimmar" then texture:SetTexCoord(0.52, 0.66, 0.24, 0.45) end
		end
	end
	-- RENDER_MAP_MAX=1 maximizes the map as WorldMapMixin:Maximize and UpdateMaximizedSize do (Blizzard_WorldMap.lua:60-74, 470-484).
	if os.getenv("RENDER_MAP_MAX") == "1" then
		local width, height = env.UIParent:GetSize()
		local unclamped = (height - 67) * 702 / (534 - 67)
		local clamped = math.min(width - 30, unclamped)
		map:SetSize(math.floor(clamped), math.floor((height - 67) * clamped / unclamped + 67))
		map:ClearAllPoints()
		map:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
		map.NavBar:SetPoint("TOPLEFT", map.TitleCanvasSpacerFrame, "TOPLEFT", 8, -25)
	end
	K.Modules.Enable("Skins")
	M.S.LoadAddOn(env, "Blizzard_WorldMap")
	M.S.Show(map)
	M.S.Show(env.QuestMapFrame)
	env.RunTimers()
	M.S.W.Settle(env)
	local R = ns.WorldMapRoutes
	local search = os.getenv("RENDER_MAP_SEARCH")
	R.search:SetText("")
	if os.getenv("RENDER_MAP_BEFORE") == "1" then
		for _, key in ipairs({ "routes", "dungeonLevels", "zoneLevels", "entrances" }) do K.Options.Write("Skins", "worldMap." .. key, false) end
	elseif search then
		-- rest leaves the box idle; open focuses it, which lists the nearest pickers.
		if search == "open" then R.search:GetScript("OnEditFocusGained")(R.search) end
	else
		R.Pick(R.Search("Chasm")[1])
		R.search:GetScript("OnEditFocusGained")(R.search)
		R.search:SetText("Ragefire")
		R.search:GetScript("OnTextChanged")(R.search, true)
	end
	M.S.W.Settle(env)
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = (zone and art and "Client-extracted Kalimdor art" .. (zone == "orgrimmar" and ", cropped to Orgrimmar's corner, stands in for the city map" or "") or "Blizzard map canvas is a stand-in")
		.. "; game backdrop is the real forest/town plate. Breadcrumbs are one text stand-in for Blizzard's nav buttons; the tracking button is a flat stand-in. Destination data is a client-shaped fixture."
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return scene
end)
