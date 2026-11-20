-- worldmap_roads_env.lua: world-yard conversions and lazy graph loading for road tests and renders.
local M = dofile("Tools/regression/worldmap_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local R = { M = M }

function R.Install(env, state, graph)
	env.CreateVector2D = M.Vector
	env.C_Map.GetBestMapForUnit = function() return state.playerMap or 1 end
	env.C_Map.GetWorldPosFromMapPos = function(id, point)
		local x, y = point:GetXY()
		return id == 2 and 0 or 1, M.Vector(x * 1000, y * 1000)
	end
	env.C_Map.GetMapPosFromWorldPos = function(continent, point, id)
		local x, y = point:GetXY()
		return id, M.Vector(x / 1000, y / 1000)
	end
	env.C_AddOns.LoadAddOn = function(name)
		assert(name == "KstyleUI_Routes")
		state.loads = (state.loads or 0) + 1
		if graph then
			env.KstyleUI_RouteData = { [1] = function() state.constructs = (state.constructs or 0) + 1; return graph end }
		else
			Load({ "KstyleUI_Routes/Init.lua", "KstyleUI_Routes/EasternKingdoms.lua", "KstyleUI_Routes/Kalimdor.lua" }, env)
		end
		return true
	end
end

function R.Graph()
	local graph = { map = 1, nodes = {
		{ id = 1, name = "Razor Hill", x = 300, y = 700, kind = "flight" },
		{ id = 2, name = "Mountain pass", x = 300, y = 300, kind = "junction" },
		{ id = 3, name = "Crossroads", x = 720, y = 360, kind = "flight" },
	}, edges = {} }
	graph.edges = {
		{ a = 1, b = 2, kind = "walk", len = 700, pts = { 300, 700, 200, 500, 300, 300 } },
		{ a = 2, b = 3, kind = "walk", len = 700, pts = { 300, 300, 500, 200, 720, 360 } },
		{ a = 1, b = 3, kind = "flight", len = 600, seconds = 40, about = true, directed = true, pts = { 300, 700, 500, 400, 720, 360 } },
	}
	return graph
end

return R
