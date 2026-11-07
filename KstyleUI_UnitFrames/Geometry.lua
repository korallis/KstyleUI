-- Geometry.lua: where a unit frame's portrait, panel, bars and texts sit, as pure maths over its settings and size.
local _, ns = ...

local Format = ns.Format

local Geometry = {}
ns.Geometry = Geometry

local max, min, ceil = math.max, math.min, math.ceil

local PORTRAIT_GAP = 2
local PAD_X, PAD_Y = 6, 5
local COMPACT_PAD = 3
local GAP = 2
local TEXT_GAP = 4
local NAME_EXTRA = 3
local FULL_MIN_HEIGHT = 36
local BADGE_SHARE = 0.36
local BADGE_MIN = 14
local LEVEL_COLUMN = 2.6
local MIN_HEALTH = 2

Geometry.TEXT_GAP = TEXT_GAP
Geometry.FULL_MIN_HEIGHT = FULL_MIN_HEIGHT

local function Rect(x, y, w, h)
	return { x = x, y = y, w = max(0, w), h = max(0, h) }
end

local function Size(s, element, scale)
	local fonts = s.fonts and s.fonts[element]
	return (fonts and fonts.size or 11) * scale
end

local function Columns(s, scale)
	local healthCol = Format.ColumnWidth(s.healthText or "none", Size(s, "health", scale))
	local powerCol = s.power and Format.ColumnWidth(s.powerText or "none", Size(s, "power", scale)) or 0
	return healthCol, powerCol
end

local function Portrait(out, s, width, height)
	if not s.portrait then
		return 0, width
	end
	local size = max(0, min(height, width / 2))
	if s.portraitSide == "RIGHT" then
		out.portrait = Rect(width - size, 0, size, size)
		return 0, width - size - PORTRAIT_GAP
	end
	out.portrait = Rect(0, 0, size, size)
	return size + PORTRAIT_GAP, width
end

local function Badge(out, s)
	local portrait = out.portrait
	if not (portrait and s.level) then
		return
	end
	local size = max(BADGE_MIN, ceil(portrait.w * BADGE_SHARE))
	local x = portrait.x
	if s.portraitSide == "RIGHT" then
		x = portrait.x + portrait.w - size
	end
	out.badge = Rect(x, portrait.y + portrait.h - size, size, size)
end

local function BarHeights(s, top, bottom)
	local powerH = s.power and (s.powerHeight or 0) or 0
	local healthH = bottom - top
	if powerH > 0 then
		healthH = healthH - powerH - GAP
	end
	healthH = max(min(MIN_HEALTH, bottom - top), healthH)
	return powerH, healthH
end

local function Full(out, s, scale, left, right, height)
	local ix, iw = left + PAD_X, right - left - 2 * PAD_X
	local top, bottom = PAD_Y, height - PAD_Y
	local healthCol, powerCol = Columns(s, scale)
	if s.name then
		local nameRow = Size(s, "name", scale) + NAME_EXTRA
		local nameW = iw
		if s.level and not out.portrait then
			local levelCol = ceil(LEVEL_COLUMN * Size(s, "level", scale))
			nameW = iw - levelCol - TEXT_GAP
			out.levelText = Rect(ix + iw - levelCol, top, levelCol, nameRow)
		end
		out.name = Rect(ix, top, nameW, nameRow)
		top = top + nameRow + GAP
	end
	local powerH, healthH = BarHeights(s, top, bottom)
	local healthW = healthCol > 0 and iw - healthCol - TEXT_GAP or iw
	out.health = Rect(ix, top, healthW, healthH)
	if healthCol > 0 then
		out.healthText = Rect(ix + iw - healthCol, top, healthCol, healthH)
	end
	if powerH > 0 then
		local y = top + healthH + GAP
		local powerW = powerCol > 0 and iw - powerCol - TEXT_GAP or iw
		out.power = Rect(ix, y, powerW, powerH)
		if powerCol > 0 then
			local textH = Size(s, "power", scale) + NAME_EXTRA
			out.powerText = Rect(ix + iw - powerCol, y + powerH / 2 - textH / 2, powerCol, textH)
		end
	end
end

local function Compact(out, s, scale, left, right, height)
	local ix, iw = left + COMPACT_PAD, right - left - 2 * COMPACT_PAD
	local top, bottom = COMPACT_PAD, height - COMPACT_PAD
	local healthCol = Format.ColumnWidth(s.healthText or "none", Size(s, "health", scale))
	local powerH, healthH = BarHeights(s, top, bottom)
	out.health = Rect(ix, top, iw, healthH)
	local textRight = ix + iw - COMPACT_PAD
	if healthCol > 0 then
		local w = min(healthCol, max(0, iw - 2 * COMPACT_PAD))
		out.healthText = Rect(textRight - w, top, w, healthH)
		textRight = textRight - w - GAP
	end
	if s.name then
		local x = ix + COMPACT_PAD
		out.name = Rect(x, top, textRight - x, healthH)
	end
	if powerH > 0 then
		out.power = Rect(ix, top + healthH + GAP, iw, powerH)
	end
end

function Geometry.Frame(s, width, height, fontScale)
	local scale = fontScale or 1
	local out = { compact = height < FULL_MIN_HEIGHT }
	local left, right = Portrait(out, s, width, height)
	out.panel = Rect(left, 0, right - left, height)
	if out.compact then
		Compact(out, s, scale, left, right, height)
	else
		Badge(out, s)
		Full(out, s, scale, left, right, height)
	end
	return out
end

function Geometry.Slots(count, gap, width, height)
	local slot = max(0, (height - gap * (count - 1)) / count)
	local out = {}
	for i = 1, count do
		out[i] = Rect(0, (i - 1) * (slot + gap), width, slot)
	end
	return out
end
