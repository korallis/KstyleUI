-- worldmap_roads.lua: shipped continent routes, recorded-service pins and quest routes on optional client map art and a real game backdrop.
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
	local trip = os.getenv("RENDER_MAP_TRIP") or "foot"
	local flight = trip == "flight"
	local ends = ({ foot = { "Razor Hill", "The Crossroads" }, flight = { "Orgrimmar", "Thunder Bluff" }, hearth = { "Thunder Bluff", "Orgrimmar" }, zeppelin = { "Razor Hill", "The Undercity" } })[trip]
	local far = trip == "zeppelin" and assert(ns.WorldMapRoads.Graph(0)) or graph
	local from, to
	for _, node in ipairs(graph.nodes) do
		if node.name == ends[1] then from = node end
	end
	for _, node in ipairs(far.nodes) do
		if node.name == ends[2] then to = node end
	end
	assert(from and to)
	if trip == "hearth" then
		env.GetTime = function() return 1000 end
		env.GetBindLocation = function() return "Razor Hill" end
		env.C_Item = { GetItemCount = function() return 1 end, GetItemNameByID = function() return "Hearthstone" end, GetItemCooldown = function() return 0, 0 end }
	end
	local loX, hiX, loY, hiY = -4000, 3500, -10500, 500
	if os.getenv("RENDER_MAP_WIDE") == "1" then loX, hiX, loY, hiY = -8465, 3065, -9560, 6965 end
	local function Project(x, y) return (hiY - y) / (hiY - loY), (hiX - x) / (hiX - loX) end
	state.playerX, state.playerY = Project(from.x, from.y)
	env.C_Map.GetWorldPosFromMapPos = function(id, point)
		local x, y = point:GetXY()
		return id == 2 and 0 or 1, M.Vector(hiX - y * (hiX - loX), hiY - x * (hiY - loY))
	end
	env.C_Map.GetMapPosFromWorldPos = function(continent, point, id)
		if continent == 1 then return id, M.Vector(Project(point:GetXY())) end
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
	if os.getenv("RENDER_MAP_TRAVEL") == "0" then K.Options.Write("Skins", "worldMap.travelStops", false) end
	local x, y = Project(to.x, to.y)
	local services, quest, off = os.getenv("RENDER_MAP_SERVICES") == "1", os.getenv("RENDER_MAP_QUEST"), os.getenv("RENDER_MAP_OFF") == "1"
	if off then
		for _, key in ipairs({ "services", "questRoutes" }) do pcall(K.Options.Write, "Skins", "worldMap." .. key, false) end
	end
	if services then
		local saved = {}
		for _, row in ipairs({ { "inn", "Innkeeper Grosk", "Sen'jin Village" }, { "inn", "Innkeeper Boorand", "The Crossroads" },
			{ "trainer", "Shadow-Walker Zuru", "Razor Hill" }, { "repair", "Wuark", "Razor Hill" }, { "bank", "Karus", "Orgrimmar" }, { "auction", "Auctioneer Thathung", "Orgrimmar" } }) do
			for _, node in ipairs(graph.nodes) do
				if node.name == row[3] then
					local wx, wy = node.x + 2 * #row[2], node.y + 2 * #row[2]
					local px, py = Project(wx, wy)
					saved[row[1]] = saved[row[1]] or {}
					saved[row[1]][row[2]] = { name = row[2], map = 1, x = px, y = py, continent = 1, wx = wx, wy = wy, faction = "Horde" }
				end
			end
		end
		K.Store.Account().mapServices = saved
		env.C_Map.GetMapInfo = function() return { mapType = 3 } end
		map:RefreshAllDataProviders()
	end
	if quest and not off then
		env.C_QuestLog.GetNextWaypoint = function(id) if quest ~= "none" and id == 10 then return 1, x, y end end
		env.C_QuestLog.GetQuestsOnMap = function() return {} end
		R.Quest(10)
	elseif services and not off and not os.getenv("RENDER_MAP_TRIP") then
		R.Pick({ nearest = "inn" })
	else
		R.Pick({ mapID = trip == "zeppelin" and 2 or 1, name = to.name, x = x, y = y })
	end
	if services then
		R.search:SetText("")
		R.search:GetScript("OnEditFocusGained")(R.search)
	end
	if os.getenv("RENDER_MAP_REOPEN") == "1" then
		map:SetMapID(2)
		map:Hide()
		R.search:GetScript("OnEditFocusLost")(R.search)
		R.panel:GetScript("OnHide")(R.panel)
		M.S.Show(map)
		map:SetMapID(1)
		map:RefreshAllDataProviders()
	end
	assert(os.getenv("RENDER_MAP_BEFORE") == "1" or (quest == "none" and not off) or R.road, "the render must exercise a real connected route")
	if flight and R.road then
		local found
		for _, leg in ipairs(R.road.legs) do found = found or leg.kind == "flight" end
		assert(found, "the capital journey must use a flight")
	end
	if trip == "hearth" then assert(R.road and R.road.option, "the hearth journey must start with the hearthstone") end
	if trip == "zeppelin" then
		local found
		for _, leg in ipairs(R.road and R.road.legs or {}) do found = found or leg.kind == "zeppelin" end
		assert(found, "the Undercity journey must take the zeppelin")
	end
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = art and "Client-extracted Kalimdor art, real shipped graph; player and discovered taxi state are fixtures." or "Map art unavailable; route uses the real shipped graph on the fixture canvas."
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return scene
end)
