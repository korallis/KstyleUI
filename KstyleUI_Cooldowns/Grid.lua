-- Grid.lua: pure maths that places icons and bars in a holder by cell size, spacing, columns, rows, growth, wrap, two rows of their own count and icon size (never under the smallest icon) and, for a vertical grid, columns filled top to bottom: inside the same box, its columns placed by growth, or turned on its side when the row is free of the HUD.
local _, ns = ...

local Grid = {}
ns.Grid = Grid

local floor, max = math.floor, math.max
local MIN_ICON = 16

local function Whole(value, low)
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return max(low, floor(value + 0.5))
end

local function Dims(cfg)
	local columns = Whole(cfg.columns, 1)
	local rows = Whole(cfg.rows, 1)
	local spacing = cfg.spacing
	if type(spacing) ~= "number" or spacing ~= spacing or spacing < 0 then
		spacing = 0
	end
	return columns, rows, spacing, cfg.cellWidth or 0, cfg.cellHeight or 0
end

local function Two(cfg)
	local base, a, b = cfg.baseCount or 0, cfg.baseSize or 0, cfg.secondSize or 0
	if base == 0 and a == 0 and b == 0 or cfg.vertical then return nil end
	local columns, rows, spacing, cw, ch = Dims(cfg)
	if rows ~= 2 then return nil end
	a, b = max(a, MIN_ICON - cw), max(b, MIN_ICON - cw)
	return base > 0 and math.min(base, columns) or columns, columns, spacing, cw + a, ch + a, cw + b, ch + b
end

function Grid.Capacity(cfg)
	local first, columns = Two(cfg)
	if first then return first + columns end
	local cols, rows = Dims(cfg)
	return cols * rows
end

function Grid.Cell(index, cfg)
	local first, _, _, aw, _, bw = Two(cfg)
	if not first then return cfg.cellWidth end
	return index <= first and aw or bw
end

function Grid.Size(cfg)
	local first, columns2, gap, aw, ah, bw, bh = Two(cfg)
	if first then
		return max(first * (aw + gap), columns2 * (bw + gap)) - gap, ah + bh + gap
	end
	local columns, rows, spacing, cw, ch = Dims(cfg)
	if cfg.vertical and cfg.free then
		return rows * cw + (rows - 1) * spacing, columns * ch + (columns - 1) * spacing
	end
	return columns * cw + (columns - 1) * spacing, rows * ch + (rows - 1) * spacing
end

local function Line(index, count, cfg, columns, rows, spacing, along, across)
	local capacity = columns * rows
	if index < 1 or index > capacity then
		return nil
	end
	if count > capacity then
		count = capacity
	end
	local row = floor((index - 1) / columns)
	local column = (index - 1) % columns
	local inRow = count - row * columns
	if inRow > columns then
		inRow = columns
	end
	local width = columns * along + (columns - 1) * spacing
	local used = inRow * along + (inRow - 1) * spacing
	local x
	if cfg.growth == "left" then
		x = width - along - column * (along + spacing)
	elseif cfg.growth == "rightAligned" then
		x = width - used + column * (along + spacing)
	elseif cfg.growth == "right" then
		x = column * (along + spacing)
	else
		x = (width - used) / 2 + column * (along + spacing)
	end
	local y
	if cfg.wrap == "up" then
		y = (rows - 1 - row) * (across + spacing)
	else
		y = row * (across + spacing)
	end
	return x, y
end

function Grid.Offset(index, count, cfg)
	local first, columns2, gap, aw, ah, bw, bh = Two(cfg)
	if first then
		if index < 1 or index > first + columns2 then return nil end
		local second = index > first
		local slots, along = second and columns2 or first, second and bw or aw
		local x = Line(second and index - first or index, second and count - first or count, cfg, slots, 1, gap, along, 0)
		local share = cfg.growth == "right" and 0 or (cfg.growth == "center" and 0.5 or 1)
		x = x + (Grid.Size(cfg) - slots * (along + gap) + gap) * share
		if cfg.wrap == "up" then return x, second and 0 or bh + gap end
		return x, second and ah + gap or 0
	end
	local columns, rows, spacing, cw, ch = Dims(cfg)
	if cfg.vertical and cfg.free then
		local y, x = Line(index, count, cfg, columns, rows, spacing, ch, cw)
		return x, y
	elseif cfg.vertical then
		if index < 1 or index > columns * rows then
			return nil
		end
		local used = math.ceil(math.min(count, columns * rows) / rows)
		return Line(floor((index - 1) / rows) + 1, used, cfg, columns, 1, spacing, cw, ch), (index - 1) % rows * (ch + spacing)
	end
	return Line(index, count, cfg, columns, rows, spacing, cw, ch)
end
