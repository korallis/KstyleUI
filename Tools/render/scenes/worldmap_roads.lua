-- worldmap_roads.lua: shipped continent routes on optional client map art and a real game backdrop.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local M = Fixture.M

return Common.Run(function()
	local map, state
	local env, K, ns = M.S.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Skins" }), setup = Gallery.Setup,
		before = function(e)
			map = M.Windows.Build("worldmap", e, M.S.Blizzard(e))
			state = M.Setup(e, map)
			map:ClearAllPoints()
			map:SetPoint("CENTER", e.UIParent, "CENTER", -165, 0)
		end,
	}))
	Fixture.Install(env, state)
	local graph = assert(ns.WorldMapRoads.Graph(1))
	local flight = os.getenv("RENDER_MAP_TRIP") == "flight"
	local from, to
	for _, node in ipairs(graph.nodes) do
		if node.name == (flight and "Orgrimmar" or "Razor Hill") then from = node end
		if node.name == (flight and "Thunder Bluff" or "The Crossroads") then to = node end
	end
	assert(from and to)
	local loX, hiX, loY, hiY = -4000, 3500, -10500, 500
	local function Project(x, y) return (hiY - y) / (hiY - loY), (hiX - x) / (hiX - loX) end
	state.playerX, state.playerY = Project(from.x, from.y)
	env.C_Map.GetWorldPosFromMapPos = function(_, point)
		local x, y = point:GetXY()
		return 1, M.Vector(hiX - y * (hiX - loX), hiY - x * (hiY - loY))
	end
	env.C_Map.GetMapPosFromWorldPos = function(_, point, id)
		return id, M.Vector(Project(point:GetXY()))
	end
	env.C_Map.GetMapWorldSize = function() return hiY - loY, hiX - loX end
	env.C_TaxiMap.GetTaxiNodesForMap = function()
		if not flight then return {} end
		return { { name = "Orgrimmar, Durotar", faction = 1, isUndiscovered = false }, { name = "Thunder Bluff, Mulgore", faction = 1, isUndiscovered = false } }
	end
	for _, pin in pairs(state.pins) do pin:Hide() end
	local art = os.getenv("RENDER_MAP_ART")
	if art then
		local texture = map:GetCanvas():CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints(map:GetCanvas())
		texture:SetTexture(art)
		texture:SetTexCoord((17066.6 - hiY) / 36799.81, (17066.6 - loY) / 36799.81, (12799.9 - hiX) / 24533.2, (12799.9 - loX) / 24533.2)
	end
	K.Modules.Enable("Skins")
	M.S.LoadAddOn(env, "Blizzard_WorldMap")
	M.S.Show(map)
	M.S.Show(env.QuestMapFrame)
	env.RunTimers()
	M.S.W.Settle(env)
	local R = ns.WorldMapRoutes
	if os.getenv("RENDER_MAP_BEFORE") == "1" then K.Options.Write("Skins", "worldMap.followRoads", false) end
	local x, y = Project(to.x, to.y)
	R.Pick({ mapID = 1, name = to.name, x = x, y = y })
	assert(os.getenv("RENDER_MAP_BEFORE") == "1" or R.road, "the render must exercise a real connected route")
	if flight and R.road then
		local found
		for _, leg in ipairs(R.road.legs) do found = found or leg.kind == "flight" end
		assert(found, "the capital journey must use a flight")
	end
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = art and "Client-extracted Kalimdor art, real shipped graph; player and discovered taxi state are fixtures." or "Map art unavailable; route uses the real shipped graph on the fixture canvas."
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return scene
end)
