-- Format.lua: pure helpers for the minimap: coordinate and clock text, zone colours, zoom steps and shares, the lens's place in its card and the rim buttons' arc.
local _, ns = ...

local Format = {}
ns.Format = Format

local ceil, floor, format, max, min = math.ceil, math.floor, string.format, math.max, math.min

local COORD_FORMATS = { [0] = "%d, %d", [1] = "%.1f, %.1f", [2] = "%.2f, %.2f" }
local DEFAULT_PRECISION = 1
local RIM = 6
local FOOT = 34
local COMPASS_PLATE = 22
local ARC_START = math.rad(52)
local HOURS_PER_DAY, MINUTES_PER_HOUR, NOON = 24, 60, 12

local PVP_TOKENS = {
	hostile = "hostile",
	arena = "hostile",
	combat = "hostile",
	friendly = "friendly",
	contested = "neutral",
	sanctuary = "rare",
}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsNumber(value)
	return not IsSecret(value) and type(value) == "number" and value == value
end

Format.IsNumber = IsNumber
Format.RIM = RIM
Format.FOOT = FOOT
Format.COMPASS_PLATE = COMPASS_PLATE
Format.ARC_START = ARC_START

function Format.Lens(width, height, rim, foot)
	local lens = max(0, min(width - 2 * rim, height - rim - foot))
	return (width - lens) / 2, rim + max(0, height - rim - foot - lens) / 2, lens
end

function Format.ArcStep(size, spacing, radius)
	if radius <= 0 then
		return 0
	end
	return (size + spacing) / radius
end

function Format.Arc(index, size, spacing, radius, side, up)
	local angle = ARC_START - (index - 1) * Format.ArcStep(size, spacing, radius)
	local x, y = math.cos(angle) * radius, math.sin(angle) * radius
	if up then
		y = -y
	end
	if side == "left" then
		x = -x
	end
	return x, y
end

function Format.Coords(x, y, precision)
	if not IsNumber(x) or not IsNumber(y) then
		return nil
	end
	local pattern = COORD_FORMATS[precision]
	if not pattern then
		precision, pattern = DEFAULT_PRECISION, COORD_FORMATS[DEFAULT_PRECISION]
	end
	x, y = x * 100, y * 100
	if precision == 0 then
		return format(pattern, floor(x + 0.5), floor(y + 0.5))
	end
	return format(pattern, x, y)
end

function Format.Time(hour, minute, use24)
	if not IsNumber(hour) or not IsNumber(minute) then
		return nil
	end
	if hour < 0 or hour >= HOURS_PER_DAY or minute < 0 or minute >= MINUTES_PER_HOUR then
		return nil
	end
	hour, minute = floor(hour), floor(minute)
	if use24 then
		return format("%02d:%02d", hour, minute)
	end
	local L = KstyleUI.L
	local suffix = hour < NOON and L["AM"] or L["PM"]
	local twelve = hour % NOON
	if twelve == 0 then
		twelve = NOON
	end
	return format("%d:%02d %s", twelve, minute, suffix)
end

function Format.ZoneToken(pvpType, mode)
	if mode == "accent" then
		return "accent"
	end
	if mode ~= "pvp" or IsSecret(pvpType) or type(pvpType) ~= "string" then
		return "textEmphasis"
	end
	return PVP_TOKENS[pvpType] or "textEmphasis"
end

function Format.NextZoom(current, levels, delta)
	if not IsNumber(current) or not IsNumber(levels) or not IsNumber(delta) or delta == 0 or levels < 1 then
		return nil
	end
	local last = levels - 1
	local from = min(current, last)
	local target = from + (delta > 0 and 1 or -1)
	if target < 0 or target > last then
		if from ~= current then
			return from
		end
		return nil
	end
	return target
end

function Format.ZoomShare(zoom, levels)
	if not IsNumber(zoom) or not IsNumber(levels) or levels < 2 then
		if IsNumber(zoom) and IsNumber(levels) then
			return 0
		end
		return nil
	end
	local last = levels - 1
	return max(0, min(zoom, last)) / last
end

function Format.ZoomAt(share, levels)
	if not IsNumber(share) or not IsNumber(levels) then
		return nil
	end
	local last = levels - 1
	if last < 1 then
		return 0
	end
	return max(0, min(last, floor(share * last + 0.5)))
end

local GRID_CORNER = { left = "TOPRIGHT", right = "TOPLEFT", down = "TOPLEFT", up = "BOTTOMLEFT" }
local DRAWER_ANCHORS = {
	left = { "TOPRIGHT", "TOPLEFT", -1, 0 },
	right = { "TOPLEFT", "TOPRIGHT", 1, 0 },
	down = { "TOPLEFT", "BOTTOMLEFT", 0, -1 },
	up = { "BOTTOMLEFT", "TOPLEFT", 0, 1 },
}

function Format.Direction(direction, side)
	if DRAWER_ANCHORS[direction] then
		return direction
	end
	return side == "left" and "right" or "left"
end

function Format.Grid(index, columns, size, spacing, direction, pad)
	columns = max(1, floor(columns))
	local step = size + spacing
	local col, row = (index - 1) % columns, floor((index - 1) / columns)
	local x, y = pad + col * step, pad + row * step
	if direction == "left" then
		x = -x
	end
	if direction ~= "up" then
		y = -y
	end
	return GRID_CORNER[direction] or GRID_CORNER.right, x, y
end

function Format.GridSize(count, columns, size, spacing, pad)
	if count < 1 then
		return 0, 0
	end
	columns = max(1, floor(columns))
	local cols = min(count, columns)
	local rows = ceil(count / columns)
	return 2 * pad + cols * size + (cols - 1) * spacing, 2 * pad + rows * size + (rows - 1) * spacing
end

function Format.DrawerAnchor(direction)
	local anchor = DRAWER_ANCHORS[direction] or DRAWER_ANCHORS.left
	return anchor[1], anchor[2], anchor[3], anchor[4]
end
