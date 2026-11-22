-- test-perf-minimap-triggers.lua: work the minimap does because something else wrote, at four screen sizes and both HUD styles: a library moving a collected button puts back only the geometry it changed (anchor, size, icon), a placement that is already the slot costs no write, a secret scale raises nothing, and the coordinates ticker writes nothing while the player moves without the shown coordinates changing.
local M = dofile("Tools/regression/minimap_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local CALLS = 60

-- Cost(env, run) -> widget writes, the methods written, addon instructions for run.
local function Cost(env, run)
	local before = {}
	for _, frame in ipairs(env._frames) do
		before[frame] = #frame._calls
		for _, region in ipairs(frame._regions) do before[region] = #region._calls end
	end
	local result = Budget.Count(env, run)
	local writes, by = 0, {}
	for o, start in pairs(before) do
		for k = start + 1, #o._calls do
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

-- Run(style, width, height) -> the drawer's writes and instructions for one library move.
local function Run(style, width, height)
	local lib
	local env, K, ns = M.New({
		enabled = true,
		width = width,
		height = height,
		setup = function(e)
			lib = M.FakeLibDBIcon(e)
			for _, name in ipairs({ "Alpha", "Bravo", "Charlie" }) do lib:Add(name) end
		end,
	})
	K.Options.Write("HudStyle", "style", style)
	M.Settle(env)
	local where = style .. " " .. width .. "x" .. height
	assert(env.GetMinimapShape() == (style == "frames" and "SQUARE" or "ROUND"), where .. " is the HUD style")
	local drawer, alpha, icon = ns.Map.drawer, lib.objects.Alpha, lib.objects.Alpha.icon

	local function Spot()
		local point, relative, relativePoint, x, y = alpha:GetPoint(1)
		local iconPoint, iconTo, iconToPoint, ix, iy = icon:GetPoint(1)
		return table.concat({ alpha:GetNumPoints(), point, tostring(relative), relativePoint, x, y, alpha:GetWidth(), alpha:GetHeight(),
			icon:GetNumPoints(), iconPoint, tostring(iconTo), iconToPoint, ix or 0, iy or 0, icon:GetWidth(), icon:GetHeight() }, " ")
	end

	-- The library's Move is ClearAllPoints and SetPoint; the drawer's answer is one ClearAllPoints and one SetPoint more.
	local spot = Spot()
	lib:Move("Alpha")
	local writes, by, instructions = Cost(env, function()
		for _ = 1, CALLS do lib:Move("Alpha") end
	end)
	local own = writes / CALLS - 2
	assert(own <= 2, string.format("%s: a library moving a collected button cost the drawer %.1f writes a call (%s over %d calls); put back only the anchor, size and icon that differ from the slot (KstyleUI_Minimap/Drawer.lua Fit)", where, own, by, CALLS))
	assert(instructions / CALLS <= 600, string.format("%s: a library moving a collected button cost the drawer %d addon instructions a call, budget 600; check the slot Place last gave it instead of reading the settings again (KstyleUI_Minimap/Drawer.lua OnMoved)", where, instructions / CALLS))
	assert(Spot() == spot and select(2, alpha:GetPoint(1)) == drawer.panel, where .. ": the button is back on its slot at its size: " .. Spot() .. " / " .. spot)

	-- An owner placing the button where it already is costs the drawer nothing.
	local current = { alpha:GetPoint(1) }
	writes, by = Cost(env, function()
		for _ = 1, 10 do alpha:SetPoint(unpack(current)) end
	end)
	assert(writes == 10, string.format("%s: 10 placements on the button's own slot cost the drawer %d writes (%s); return when the slot already holds", where, writes - 10, by))
	writes, by = Cost(env, function()
		for _ = 1, 10 do drawer:Place(alpha) end
	end)
	assert(writes == 0, string.format("%s: 10 Drawer:Place calls on a button already in its slot wrote %d times (%s); compare the icon with its snapped fill before Widgets.Size (KstyleUI_Minimap/Drawer.lua Fit)", where, writes, by))

	-- An owner resizing the button and moving its icon, then moving it, gets the whole slot back.
	alpha:SetSize(79, 79)
	icon:SetSize(73, 73)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", alpha, "TOPLEFT", 2, -3)
	lib:Move("Alpha")
	assert(Spot() == spot, where .. ": a resized button and its moved icon go back to the slot's size and centre: " .. Spot() .. " / " .. spot)

	K.Options.Write("Minimap", "drawer.direction", "down")
	assert(Spot() ~= spot, where .. ": the new direction moves the button")
	spot = Spot()
	lib:Move("Alpha")
	assert(Spot() == spot, where .. ": after a relayout the button goes back to its new slot: " .. Spot() .. " / " .. spot)
	local x = select(4, alpha:GetPoint(1))
	alpha:SetScale(2)
	lib:Move("Alpha")
	assert(M.W.Near(select(4, alpha:GetPoint(1)), x / 2), where .. ": a button its addon scaled is placed again for its scale")
	alpha._scale = env.Secret(1)
	lib:Move("Alpha")
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": a secret scale raised " .. tostring(env._errors[1]))
	alpha:SetScale(1)
	lib:Move("Alpha")
	assert(Spot() == spot, where .. ": and back at scale 1")
	K.Options.Write("Minimap", "drawer.direction", "auto")

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
	assert(writes == 0, string.format("%s: one second of moving with the coordinates unchanged wrote %d times (%s); a tick whose text is the one shown returns before Face:SetCoords (KstyleUI_Minimap/Map.lua UpdateCoords)", where, writes, by))
	env._position = { 0.512, 0.612 }
	ticker.fn(ticker)
	assert(ns.Map.face.coords:GetText() ~= text and ns.Map.face.coords:GetText():find("51.2", 1, true), "new coordinates still show on the next tick")
	env.FireEvent("PLAYER_STOPPED_MOVING")
	assert(ticker.cancelled, "stopping cancels the ticker")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	return own, instructions / CALLS
end

local report = {}
for _, run in ipairs({ { "medallions", 1920, 1080 }, { "medallions", 2560, 1440 }, { "medallions", 5120, 1440 }, { "medallions", 3840, 2160 }, { "frames", 1920, 1080 } }) do
	local own, instructions = Run(run[1], run[2], run[3])
	report[#report + 1] = string.format("%s %dx%d %.0f writes and %d instructions", run[1], run[2], run[3], own, instructions)
end
print("minimap triggers ok: a library move costs the drawer " .. table.concat(report, ", ") .. "; a placement on the slot and moving on the same coordinates write nothing")
