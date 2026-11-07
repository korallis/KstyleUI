-- test-cooldowns-grid.lua: the Cooldowns grid places icons and bars by size, spacing, columns, rows, growth and wrap.
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local env = Load({ "KstyleUI_Cooldowns/Init.lua", "KstyleUI_Cooldowns/Grid.lua" }, Stubs.NewEnv())
local Grid = env._addons.KstyleUI_Cooldowns.Grid
assert(type(Grid) == "table", "Grid.lua must set ns.Grid")

local function cfg(fields)
	local out = { cellWidth = 40, cellHeight = 40, spacing = 3, columns = 6, rows = 1, growth = "center", wrap = "down" }
	for k, v in pairs(fields or {}) do
		out[k] = v
	end
	return out
end

local function same(a, b, what)
	assert(math.abs(a - b) < 1e-9, what .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local function at(index, count, c, x, y, what)
	local gx, gy = Grid.Offset(index, count, c)
	same(gx, x, what .. " x")
	same(gy, y, what .. " y")
end

-- The essential row's footprint: 6 icons of 40 with 3-unit gaps is 255 by 40.
local w, h = Grid.Size(cfg())
same(w, 255, "essential width")
same(h, 40, "essential height")
same(Grid.Capacity(cfg()), 6, "capacity of one row of 6")

-- The utility row: 6 icons of 30 is 195 by 30.
w, h = Grid.Size(cfg({ cellWidth = 30, cellHeight = 30 }))
same(w, 195, "utility width")
same(h, 30, "utility height")

-- Three 180 by 18 bars in one column with 3-unit gaps: 180 by 60.
w, h = Grid.Size(cfg({ cellWidth = 180, cellHeight = 18, columns = 1, rows = 3 }))
same(w, 180, "bars width")
same(h, 60, "bars height")

-- A full centred row starts at the left edge.
at(1, 6, cfg(), 0, 0, "full row, first icon")
at(6, 6, cfg(), 215, 0, "full row, last icon")

-- Four icons in a row of six sit in the middle: the row is 169 wide, so it starts at (255 - 169) / 2.
at(1, 4, cfg(), 43, 0, "centred four, first")
at(4, 4, cfg(), 172, 0, "centred four, last")

-- Growth right packs from the left; growth left packs from the right, first icon rightmost.
at(1, 4, cfg({ growth = "right" }), 0, 0, "right growth, first")
at(4, 4, cfg({ growth = "right" }), 129, 0, "right growth, fourth")
at(1, 4, cfg({ growth = "left" }), 215, 0, "left growth, first")
at(4, 4, cfg({ growth = "left" }), 86, 0, "left growth, fourth")

-- Two rows of three: wrap down puts the first row at the top, wrap up at the bottom.
local two = cfg({ columns = 3, rows = 2, growth = "right" })
same(select(2, Grid.Size(two)), 83, "two rows tall")
at(1, 5, two, 0, 0, "wrap down, first row")
at(4, 5, two, 0, 43, "wrap down, second row")
at(1, 5, cfg({ columns = 3, rows = 2, growth = "right", wrap = "up" }), 0, 43, "wrap up, first row at the bottom")
at(4, 5, cfg({ columns = 3, rows = 2, growth = "right", wrap = "up" }), 0, 0, "wrap up, second row above")

-- A short last row is centred on its own.
at(4, 5, cfg({ columns = 3, rows = 2 }), 21.5, 43, "short centred second row")

-- Bars stack in one column: growth up puts the first bar at the bottom.
local bars = cfg({ cellWidth = 180, cellHeight = 18, columns = 1, rows = 3, wrap = "up" })
at(1, 2, bars, 0, 42, "first bar at the bottom")
at(2, 2, bars, 0, 21, "second bar above it")

-- Capacity limits what fits; an index past it has no place.
same(Grid.Capacity(two), 6, "capacity of two rows of three")
assert(Grid.Offset(7, 7, two) == nil, "an icon past the capacity has no offset")

-- Bad numbers clamp instead of failing: no columns, no rows and a negative gap still give a grid.
w, h = Grid.Size(cfg({ columns = 0, rows = 0, spacing = -5 }))
same(w, 40, "columns clamp to 1")
same(h, 40, "rows clamp to 1")

print("cooldowns grid ok")
