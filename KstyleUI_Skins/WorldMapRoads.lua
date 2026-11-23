-- WorldMapRoads.lua: lazy continent graphs and time-weighted road, transport, hearth and teleport routes.
local _, ns = ...
local Roads = {}
ns.WorldMapRoads = Roads
local graphs = {}
local floor = math.floor

local function Path(id)
	return tonumber(tostring(id):match("^b(%d+)_"))
end

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
	local function ID(id) return type(id) == "number" and id + continent * 100000 or id end
	for _, node in ipairs(graph.nodes) do node.id, node.map = ID(node.id), node.map or continent end
	local travel = data.travel or {}
	local zeppelins = travel.zeppelins or {}
	for _, edge in ipairs(graph.edges) do
		edge.a, edge.b = ID(edge.a), ID(edge.b)
		if edge.kind == "boat" and (zeppelins[Path(edge.a)] or zeppelins[Path(edge.b)]) then edge.zeppelin = true end
	end
	local tram = travel.tram
	if tram and tram.map == continent then
		local p = tram.pts
		local a, b = Roads.Snap(graph, p[1], p[2]), Roads.Snap(graph, p[3], p[4])
		local len = math.sqrt((a.x - p[1]) ^ 2 + (a.y - p[2]) ^ 2) + math.sqrt((p[3] - p[1]) ^ 2 + (p[4] - p[2]) ^ 2) + math.sqrt((b.x - p[3]) ^ 2 + (b.y - p[4]) ^ 2)
		graph.edges[#graph.edges + 1] = { a = a.id, b = b.id, kind = "tram", len = len, seconds = tram.seconds, travel = true, pts = { a.x, a.y, p[1], p[2], p[3], p[4], b.x, b.y } }
	end
	graphs[continent], data[continent] = graph, nil
	return graph
end

function Roads.World()
	if graphs.world then return graphs.world end
	local east, west = Roads.Graph(0), Roads.Graph(1)
	if not east or not west then return end
	local world = { nodes = {}, edges = {} }
	for _, graph in ipairs({ east, west }) do
		local here = {}
		for _, node in ipairs(graph.nodes) do
			if node.map == graph.map then here[node.id] = true; world.nodes[#world.nodes + 1] = node end
		end
		for _, edge in ipairs(graph.edges) do
			if here[edge.a] then world.edges[#world.edges + 1] = edge end
		end
	end
	graphs.world = world
	return world
end

function Roads.Snap(graph, x, y, continent)
	local best, yards
	local want = continent or graph.map
	for _, node in ipairs(graph.nodes) do
		if (node.map or want) == want then
			local dx, dy = node.x - x, node.y - y
			local d = dx * dx + dy * dy
			if not yards or d < yards then best, yards = node, d end
		end
	end
	return best, yards and math.sqrt(yards)
end

local function Dock(graph, node)
	if node.label then return node.label end
	local town, area, near, far
	for _, other in ipairs(graph.nodes) do
		if other.map == node.map then
			local d = (other.x - node.x) ^ 2 + (other.y - node.y) ^ 2
			if (other.kind == "flight" or other.kind == "settlement" or other.kind == "hub") and d <= 250000 and (not near or d < near) then town, near = other, d end
			if other.kind == "area" and (not far or d < far) then area, far = other, d end
		end
	end
	local name = (town or area or node).name
	node.label = name:match("^(.-),") or name
	return node.label
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
		if a and b and (not graph.map or (a.map or graph.map) == graph.map and (b.map or graph.map) == graph.map) then
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

local function Find(graph, sources, goal, speed, flights, travel, timeOnly)
	local costs, previous, edges = {}, {}, {}
	local adjacency = graph.adj
	local heap = { ids = {}, times = {}, n = 0 }
	local weight = speed == 14 and 2 or 1
	for id, cost in pairs(sources) do costs[id] = cost; Push(heap, id, cost) end
	while heap.n > 0 do
		local id, cost = Pop(heap)
		if id == goal then return cost, previous, edges end
		if cost == costs[id] then
			local links = adjacency[id]
			for i = 1, #links, 4 do
				local nextID, edge = links[i], links[i + 3]
				if (edge.kind ~= "flight" or (flights and flights[id] and flights[nextID])) and (travel or not edge.travel) then
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
	local costs = Find(graph, { [start.id] = 0 }, nil, speed, flights, nil, true)
	return function(tx, ty)
		local node, last = Roads.Snap(graph, tx, ty)
		local cost = node and costs[node.id]
		return cost and cost + (first + last) / speed
	end
end

function Roads.Solve(graph, x, y, tx, ty, mounted, flights, travel)
	Index(graph)
	local start, first = Roads.Snap(graph, x, y, travel and travel.continent)
	local goal, last = Roads.Snap(graph, tx, ty, travel and travel.target)
	if not start or not goal then return end
	local speed = mounted and 14 or 7
	local sources, via = { [start.id] = first / speed }, {}
	for _, option in ipairs(travel and travel.options or {}) do
		local node, yards = Roads.Snap(graph, option.x, option.y, option.map)
		local cost = node and option.seconds + yards / speed
		if cost and cost < (sources[node.id] or math.huge) then sources[node.id], via[node.id] = cost, { option = option, node = node, yards = yards } end
	end
	local seconds, previous, edges = Find(graph, sources, goal.id, speed, flights, travel)
	if not seconds then return end
	local path, id, flight = {}, goal.id, false
	while previous[id] do
		path[#path + 1] = { edge = edges[id], from = previous[id], to = id }
		flight = flight or edges[id].kind == "flight"
		id = previous[id]
	end
	local hop = via[id]
	local near = hop and hop.yards or first
	local route = { graph = graph, continent = travel and travel.continent, start = start, last = last, legs = {}, yards = near + last, seconds = seconds + last / speed, dashed = near > 60 or last > 60 }
	local function Name(node) return travel and node.kind == "dock" and Dock(graph, node) or node.name end
	local function Connector(ax, ay, bx, by, len, name, map)
		if len > 0 or #route.legs == 0 then route.legs[#route.legs + 1] = { kind = "walk", to = name, len = len, seconds = len / speed, dashed = len > 60, pts = { ax, ay, bx, by }, map = map } end
	end
	if hop then
		local option = hop.option
		route.option = option
		route.legs[1] = { kind = option.kind, to = option.name, len = 0, seconds = option.seconds, pts = { option.x, option.y }, map = option.map, turn = true, stop = true }
		Connector(option.x, option.y, hop.node.x, hop.node.y, hop.yards, Name(hop.node), option.map)
	else
		Connector(x, y, start.x, start.y, first, Name(start), start.map)
	end
	for i = #path, 1, -1 do
		hop = path[i]
		local edge, points = hop.edge, {}
		local from, to = graph.byID[hop.from], graph.byID[hop.to]
		local stride = edge.kind == "lift" and 3 or 2
		local a, b, step = 1, #edge.pts, stride
		if hop.from ~= edge.a then a, b, step = #edge.pts - stride + 1, 1, -stride end
		for p = a, b, step do points[#points + 1] = edge.pts[p]; points[#points + 1] = edge.pts[p + 1] end
		if from.map ~= to.map then points = { to.x, to.y } end
		route.legs[#route.legs + 1] = { kind = travel and edge.zeppelin and "zeppelin" or edge.kind, len = edge.len, seconds = mounted and edge.mounted or edge.cost, pts = points,
			from = Name(from), to = Name(to), turn = true, map = to.map, stop = to.kind ~= "junction" and to.kind ~= "crossing" }
		route.yards = route.yards + edge.len
	end
	Connector(goal.x, goal.y, tx, ty, last, nil, goal.map)
	if flight then
		local walking = Find(graph, sources, goal.id, speed, nil, travel, true)
		if walking and walking - seconds >= 60 then route.saved = math.floor((walking - seconds) / 60) end
	end
	return route
end

function Roads.MoveStart(route, x, y, mounted)
	local start, yards = Roads.Snap(route.graph, x, y, route.continent)
	if start ~= route.start then return false end
	if route.option then return true end
	local leg = route.legs[1]
	local seconds = yards / (mounted and 14 or 7)
	route.yards, route.seconds = route.yards + yards - leg.len, route.seconds + seconds - leg.seconds
	leg.len, leg.seconds, leg.dashed = yards, seconds, yards > 60
	leg.pts[1], leg.pts[2] = x, y
	route.dashed = leg.dashed or route.last > 60
	return true
end
