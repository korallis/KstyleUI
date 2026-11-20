-- Grid.lua: pure maths that places icons and bars in a holder by cell size, spacing, columns, rows, growth, wrap and, for a vertical grid, columns filled top to bottom.
local _, ns = ...

local Grid = {}
ns.Grid = Grid

local floor, max = math.floor, math.max

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

function Grid.Capacity(cfg)
	local columns, rows = Dims(cfg)
	return columns * rows
end

function Grid.Size(cfg)
	local columns, rows, spacing, cw, ch = Dims(cfg)
	if cfg.vertical then
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
	local columns, rows, spacing, cw, ch = Dims(cfg)
	if cfg.vertical then
		local y, x = Line(index, count, cfg, columns, rows, spacing, ch, cw)
		return x, y
	end
	return Line(index, count, cfg, columns, rows, spacing, cw, ch)
end
