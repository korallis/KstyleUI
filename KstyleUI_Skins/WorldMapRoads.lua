-- WorldMapRoads.lua: lazy continent graphs and time-weighted road and travel routes.
local _, ns = ...
local Roads = {}
ns.WorldMapRoads = Roads
local graphs = {}

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
			local list = graph.adj[a.id]
			list[#list + 1] = { edge, b.id }
			if edge.kind ~= "flight" and not edge.directed then
				list = graph.adj[b.id]
				list[#list + 1] = { edge, a.id }
			end
		end
	end
end

local function Seconds(edge, speed)
	if edge.kind == "walk" then return edge.len / speed end
	if edge.kind == "swim" then return edge.len / 4.7 end
	return edge.seconds or math.huge
end

local function Push(heap, id, cost)
	local i = #heap + 1
	while i > 1 do
		local parent = math.floor(i / 2)
		if heap[parent][2] <= cost then break end
		heap[i], i = heap[parent], parent
	end
	heap[i] = { id, cost }
end

local function Pop(heap)
	local first, last = heap[1], table.remove(heap)
	if #heap > 0 then
		local i = 1
		while i * 2 <= #heap do
			local child = i * 2
			if child < #heap and heap[child + 1][2] < heap[child][2] then child = child + 1 end
			if last[2] <= heap[child][2] then break end
			heap[i], i = heap[child], child
		end
		heap[i] = last
	end
	return first[1], first[2]
end

local function Find(graph, start, goal, speed, flights)
	local costs, previous, heap = { [start] = 0 }, {}, {}
	Push(heap, start, 0)
	while #heap > 0 do
		local id, cost = Pop(heap)
		if id == goal then return cost, previous end
		if cost == costs[id] then
			for _, link in ipairs(graph.adj[id]) do
				local edge, nextID = link[1], link[2]
				if edge.kind ~= "flight" or (flights and flights[id] and flights[nextID]) then
					local nextCost = cost + Seconds(edge, speed)
					if nextCost < (costs[nextID] or math.huge) then
						costs[nextID], previous[nextID] = nextCost, { id, edge }
						Push(heap, nextID, nextCost)
					end
				end
			end
		end
	end
end

function Roads.Solve(graph, x, y, tx, ty, mounted, flights)
	Index(graph)
	local start, first = Roads.Snap(graph, x, y)
	local goal, last = Roads.Snap(graph, tx, ty)
	if not start or not goal then return end
	local speed = mounted and 14 or 7
	local seconds, previous = Find(graph, start.id, goal.id, speed, flights)
	if not seconds then return end
	local path, id, flight = {}, goal.id, false
	while id ~= start.id do
		local back = previous[id]
		path[#path + 1] = { edge = back[2], from = back[1], to = id }
		flight = flight or back[2].kind == "flight"
		id = back[1]
	end
	local route = { legs = {}, yards = first + last, seconds = seconds + (first + last) / speed, dashed = first > 60 or last > 60 }
	local function Connector(ax, ay, bx, by, len, name)
		if len > 0 then route.legs[#route.legs + 1] = { kind = "walk", to = name, len = len, seconds = len / speed, dashed = len > 60, pts = { ax, ay, bx, by } } end
	end
	Connector(x, y, start.x, start.y, first, start.name)
	for i = #path, 1, -1 do
		local hop = path[i]
		local edge, points = hop.edge, {}
		local stride = edge.kind == "lift" and 3 or 2
		local a, b, step = 1, #edge.pts, stride
		if hop.from ~= edge.a then a, b, step = #edge.pts - stride + 1, 1, -stride end
		for p = a, b, step do points[#points + 1] = edge.pts[p]; points[#points + 1] = edge.pts[p + 1] end
		route.legs[#route.legs + 1] = { kind = edge.kind, len = edge.len, seconds = Seconds(edge, speed), pts = points,
			from = graph.byID[hop.from].name, to = graph.byID[hop.to].name, turn = true,
			stop = graph.byID[hop.to].kind ~= "junction" and graph.byID[hop.to].kind ~= "crossing" }
		route.yards = route.yards + edge.len
	end
	Connector(goal.x, goal.y, tx, ty, last)
	if flight then
		local walking = Find(graph, start.id, goal.id, speed)
		if walking and walking - seconds >= 60 then route.saved = math.floor((walking - seconds) / 60) end
	end
	return route
end
