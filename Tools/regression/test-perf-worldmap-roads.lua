-- test-perf-worldmap-roads.lua: real continent queries stay below five milliseconds in the Lua 5.1 interpreter.
local Fixture = dofile("Tools/regression/worldmap_roads_env.lua")
local env, _, _, state = Fixture.M.New()
Fixture.Install(env, state)
local Roads = env._addons.KstyleUI_Skins.WorldMapRoads
for continent = 0, 1 do
	local graph = assert(Roads.Graph(continent))
	local flights, queries = {}, {}
	for _, node in ipairs(graph.nodes) do if node.kind == "flight" then flights[node.id] = true end end
	for i = 1, 8 do
		local a, b = graph.nodes[1 + i * 37], graph.nodes[#graph.nodes - i * 19]
		queries[i] = { a.x, a.y, b.x, b.y }
		Roads.Solve(graph, a.x, a.y, b.x, b.y, false, flights)
	end
	local total, worst = 0, 0
	for _, q in ipairs(queries) do
		local best = math.huge
		for _ = 1, 3 do
			collectgarbage("collect")
			local start = os.clock()
			for _ = 1, 10 do Roads.Solve(graph, q[1], q[2], q[3], q[4], false, flights) end
			best = math.min(best, (os.clock() - start) / 10)
		end
		total, worst = total + best, math.max(worst, best)
	end
	assert(worst < 0.005, string.format("cache graph adjacency and use the heap: continent %d costs %.3f ms per query, budget 5 ms", continent, worst * 1000))
	print(string.format("road queries: continent %d, %d nodes/%d edges, %.3f ms mean/%.3f ms worst query (including snaps, polylines and flight comparison)", continent, #graph.nodes, #graph.edges, total * 1000 / #queries, worst * 1000))
end
