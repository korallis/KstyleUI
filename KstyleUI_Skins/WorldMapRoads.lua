-- WorldMapRoads.lua: lazy continent graphs and time-weighted road and travel routes.
local _, ns = ...
local Roads = {}
ns.WorldMapRoads = Roads
local graphs = {}
local floor = math.floor

function Roads.Graph(continent)
	if continent ~= 0 and continent ~= 1 then return end
	if graphs[continent] then return graphs[continent] end
	local data = rawget(_G, "KstyleUI_RouteData")
	if not data and type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
		C_AddOns.LoadAddOn("KstyleUI_Routes")
	end
	data = rawget(_G, "KstyleUI_RouteData")
	local factory = data and data[continent]
	if type(factory) ~= "function" then return end
	local graph = factory()
	graphs[continent], data[continent] = graph, nil
	return graph
end

function Roads.Snap(graph, x, y)
	local best, yards
	for _, node in ipairs(graph.nodes) do
		if not node.map or node.map == graph.map then
			local dx, dy = node.x - x, node.y - y
			local d = dx * dx + dy * dy
			if not yards or d < yards then best, yards = node, d end
		end
	end
	return best, yards and math.sqrt(yards)
end

local function Index(graph)
	if graph.adj then return end
	graph.adj, graph.byID = {}, {}
	for _, node in ipairs(graph.nodes) do
		graph.byID[node.id] = node
		graph.adj[node.id] = {}
	end
	for _, edge in ipairs(graph.edges) do
		local a, b = graph.byID[edge.a], graph.byID[edge.b]
		if a and b and (not a.map or a.map == graph.map) and (not b.map or b.map == graph.map) then
			local foot = edge.kind == "walk" and edge.len / 7 or edge.kind == "swim" and edge.len / 4.7 or edge.seconds
			local mounted = edge.kind == "walk" and foot / 2 or foot
			edge.cost, edge.mounted = foot, mounted
			local list = graph.adj[a.id]
			local n = #list
			list[n + 1], list[n + 2], list[n + 3], list[n + 4] = b.id, foot, mounted, edge
			if edge.kind ~= "flight" and not edge.directed then
				list = graph.adj[b.id]
				n = #list
				list[n + 1], list[n + 2], list[n + 3], list[n + 4] = a.id, foot, mounted, edge
			end
		end
	end
end

local function Push(heap, id, cost)
	local ids, times = heap.ids, heap.times
	local i = heap.n + 1
	heap.n = i
	while i > 1 do
		local parent = floor(i / 2)
		if times[parent] <= cost then break end
		ids[i], times[i], i = ids[parent], times[parent], parent
	end
	ids[i], times[i] = id, cost
end

local function Pop(heap)
	local ids, times, n = heap.ids, heap.times, heap.n
	local first, time, last, cost = ids[1], times[1], ids[n], times[n]
	ids[n], times[n], n = nil, nil, n - 1
	heap.n = n
	if n > 0 then
		local i = 1
		while i * 2 <= n do
			local child = i * 2
			if child < n and times[child + 1] < times[child] then child = child + 1 end
			if cost <= times[child] then break end
			ids[i], times[i], i = ids[child], times[child], child
		end
		ids[i], times[i] = last, cost
	end
	return first, time
end

local function Find(graph, start, goal, speed, flights, timeOnly)
	local costs, previous, edges = { [start] = 0 }, {}, {}
	local adjacency = graph.adj
	local heap = { ids = {}, times = {}, n = 0 }
	local weight = speed == 14 and 2 or 1
	Push(heap, start, 0)
	while heap.n > 0 do
		local id, cost = Pop(heap)
		if id == goal then return cost, previous, edges end
		if cost == costs[id] then
			local links = adjacency[id]
			for i = 1, #links, 4 do
				local nextID, edge = links[i], links[i + 3]
				if edge.kind ~= "flight" or (flights and flights[id] and flights[nextID]) then
					local nextCost = cost + links[i + weight]
					if not costs[nextID] or nextCost < costs[nextID] then
						costs[nextID] = nextCost
						if not timeOnly then previous[nextID], edges[nextID] = id, edge end
						Push(heap, nextID, nextCost)
					end
				end
			end
		end
	end
	return goal == nil and costs or nil
end

function Roads.Times(graph, x, y, mounted, flights)
	Index(graph)
	local start, first = Roads.Snap(graph, x, y)
	if not start then return end
	local speed = mounted and 14 or 7
	local costs = Find(graph, start.id, nil, speed, flights, true)
	return function(tx, ty)
		local node, last = Roads.Snap(graph, tx, ty)
		local cost = node and costs[node.id]
		return cost and cost + (first + last) / speed
	end
end

function Roads.Solve(graph, x, y, tx, ty, mounted, flights)
	Index(graph)
	local start, first = Roads.Snap(graph, x, y)
	local goal, last = Roads.Snap(graph, tx, ty)
	if not start or not goal then return end
	local speed = mounted and 14 or 7
	local seconds, previous, edges = Find(graph, start.id, goal.id, speed, flights)
	if not seconds then return end
	local path, id, flight = {}, goal.id, false
	while id ~= start.id do
		path[#path + 1] = { edge = edges[id], from = previous[id], to = id }
		flight = flight or edges[id].kind == "flight"
		id = previous[id]
	end
	local route = { graph = graph, start = start, last = last, legs = {}, yards = first + last, seconds = seconds + (first + last) / speed, dashed = first > 60 or last > 60 }
	local function Connector(ax, ay, bx, by, len, name)
		if len > 0 or #route.legs == 0 then route.legs[#route.legs + 1] = { kind = "walk", to = name, len = len, seconds = len / speed, dashed = len > 60, pts = { ax, ay, bx, by } } end
	end
	Connector(x, y, start.x, start.y, first, start.name)
	for i = #path, 1, -1 do
		local hop = path[i]
		local edge, points = hop.edge, {}
		local stride = edge.kind == "lift" and 3 or 2
		local a, b, step = 1, #edge.pts, stride
		if hop.from ~= edge.a then a, b, step = #edge.pts - stride + 1, 1, -stride end
		for p = a, b, step do points[#points + 1] = edge.pts[p]; points[#points + 1] = edge.pts[p + 1] end
		route.legs[#route.legs + 1] = { kind = edge.kind, len = edge.len, seconds = mounted and edge.mounted or edge.cost, pts = points,
			from = graph.byID[hop.from].name, to = graph.byID[hop.to].name, turn = true,
			stop = graph.byID[hop.to].kind ~= "junction" and graph.byID[hop.to].kind ~= "crossing" }
		route.yards = route.yards + edge.len
	end
	Connector(goal.x, goal.y, tx, ty, last)
	if flight then
		local walking = Find(graph, start.id, goal.id, speed, nil, true)
		if walking and walking - seconds >= 60 then route.saved = math.floor((walking - seconds) / 60) end
	end
	return route
end

function Roads.MoveStart(route, x, y, mounted)
	local start, yards = Roads.Snap(route.graph, x, y)
	if start ~= route.start then return false end
	local leg = route.legs[1]
	local seconds = yards / (mounted and 14 or 7)
	route.yards, route.seconds = route.yards + yards - leg.len, route.seconds + seconds - leg.seconds
	leg.len, leg.seconds, leg.dashed = yards, seconds, yards > 60
	leg.pts[1], leg.pts[2] = x, y
	route.dashed = leg.dashed or route.last > 60
	return true
end
