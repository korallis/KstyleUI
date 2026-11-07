-- Format.lua: pure helpers for the minimap: coordinate and clock text, zone colours, wheel zoom steps and the map's place in its element.
local _, ns = ...

local Format = {}
ns.Format = Format

local floor, format, min = math.floor, string.format, math.min

local COORD_FORMATS = { [0] = "%d, %d", [1] = "%.1f, %.1f", [2] = "%.2f, %.2f" }
local DEFAULT_PRECISION = 1
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

function Format.MapRect(width, height, side)
	local size = min(width, height)
	if side == "right" then
		return 0, size
	end
	return width - size, size
end
