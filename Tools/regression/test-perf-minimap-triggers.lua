-- test-perf-minimap-triggers.lua: work the minimap does because something else wrote: a library moving a collected button puts it straight back with one anchor and no relayout, and the coordinates ticker writes nothing while the player moves without the shown coordinates changing.
local M = dofile("Tools/regression/minimap_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local CALLS = 60

local function Objects(env)
	local objects = {}
	for _, f in ipairs(env._frames) do
		objects[#objects + 1] = f
		for _, r in ipairs(f._regions) do objects[#objects + 1] = r end
	end
	return objects
end

-- Cost(env, run) -> widget writes, the methods written, addon instructions for run.
local function Cost(env, run)
	local objects, before = Objects(env), {}
	for i, o in ipairs(objects) do before[i] = #o._calls end
	local result = Budget.Count(env, run)
	local writes, by = 0, {}
	for i, o in ipairs(objects) do
		for k = before[i] + 1, #o._calls do
			local method = o._calls[k].method
			if not (method:find("^Get") or method:find("^Is") or method:find("^Has") or method:find("^Can")) then
				writes, by[method] = writes + 1, (by[method] or 0) + 1
			end
		end
	end
	local list = {}
	for method, n in pairs(by) do list[#list + 1] = method .. "=" .. n end
	table.sort(list)
	return writes, table.concat(list, " "), result.instructions
end

-- Run(style) -> the drawer's writes and instructions for one library move, under that HUD style.
local function Run(style)
	local lib
	local env, K, ns = M.New({
		enabled = true,
		setup = function(e)
			lib = M.FakeLibDBIcon(e)
			for _, name in ipairs({ "Alpha", "Bravo", "Charlie" }) do lib:Add(name) end
		end,
	})
	K.Options.Write("HudStyle", "style", style)
	M.Settle(env)
	assert(env.GetMinimapShape() == (style == "frames" and "SQUARE" or "ROUND"), style .. " is the HUD style")
	local drawer, alpha = ns.Map.drawer, lib.objects.Alpha

	local function Spot()
		local point, relative, relativePoint, x, y = alpha:GetPoint(1)
		return table.concat({ alpha:GetNumPoints(), point, tostring(relative), relativePoint, x, y, alpha:GetWidth(), alpha:GetHeight() }, " ")
	end

	-- The library's Move is ClearAllPoints and SetPoint; the drawer's answer is one ClearAllPoints and one SetPoint more.
	local spot = Spot()
	lib:Move("Alpha")
	local writes, by, instructions = Cost(env, function()
		for _ = 1, CALLS do lib:Move("Alpha") end
	end)
	local own = writes / CALLS - 2
	assert(own <= 2, string.format("%s: a library moving a collected button cost the drawer %.1f writes a call (%s over %d calls); put it back on the anchor Place last gave it, without re-placing the icon or resizing (KstyleUI_Minimap/Drawer.lua OnMoved)", style, own, by, CALLS))
	assert(instructions / CALLS <= 300, string.format("a library moving a collected button cost the drawer %d addon instructions a call, budget 300; reuse the anchor Place last gave it instead of reading the settings again (KstyleUI_Minimap/Drawer.lua OnMoved)", instructions / CALLS))
	assert(Spot() == spot and select(2, alpha:GetPoint(1)) == drawer.panel, "the button is back on its slot at its size: " .. Spot() .. " / " .. spot)
	K.Options.Write("Minimap", "drawer.direction", "down")
	assert(Spot() ~= spot, "the new direction moves the button")
	spot = Spot()
	lib:Move("Alpha")
	assert(Spot() == spot, "after a relayout the button goes back to its new slot: " .. Spot() .. " / " .. spot)
	local x = select(4, alpha:GetPoint(1))
	alpha:SetScale(2)
	lib:Move("Alpha")
	assert(M.W.Near(select(4, alpha:GetPoint(1)), x / 2), "a button its addon scaled is placed again for its scale")
	alpha:SetScale(1)
	lib:Move("Alpha")
	assert(Spot() == spot, "and back at scale 1")
	K.Options.Write("Minimap", "drawer.direction", "auto")
	local moves = { own = own, instructions = instructions / CALLS }

	-- Moving without the shown coordinates changing writes nothing: the coordinates ticker runs five times a second.
	env._position = { 0.467, 0.612 }
	env.FireEvent("PLAYER_STARTED_MOVING")
	local ticker
	for _, t in ipairs(env._tickers) do
		if not t.cancelled and t.interval == 0.2 then ticker = t end
	end
	assert(ticker, "moving starts the coordinates ticker")
	ticker.fn(ticker)
	local text = ns.Map.face.coords:GetText()
	writes, by = Cost(env, function()
		for _ = 1, 5 do ticker.fn(ticker) end
	end)
	assert(writes == 0, string.format("%s: one second of moving with the coordinates unchanged wrote %d times (%s); a tick whose text is the one shown returns before Face:SetCoords (KstyleUI_Minimap/Map.lua TickCoords)", style, writes, by))
	env._position = { 0.512, 0.612 }
	ticker.fn(ticker)
	assert(ns.Map.face.coords:GetText() ~= text and ns.Map.face.coords:GetText():find("51.2", 1, true), "new coordinates still show on the next tick")
	env.FireEvent("PLAYER_STOPPED_MOVING")
	assert(ticker.cancelled, "stopping cancels the ticker")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return moves
end

local report = {}
for _, style in ipairs({ "medallions", "frames" }) do
	local moves = Run(style)
	report[#report + 1] = string.format("%s %.0f writes and %d instructions", style, moves.own, moves.instructions)
end
print("minimap triggers ok: a library move costs the drawer " .. table.concat(report, ", ") .. "; moving on the same coordinates writes nothing")
