-- Geometry.lua: where a unit frame's portrait, glass panel, bars and texts sit, as pure maths over its settings and size.
local _, ns = ...

local Format = ns.Format

local Geometry = {}
ns.Geometry = Geometry

local max, min, ceil, floor = math.max, math.min, math.ceil, math.floor

local PORTRAIT_GAP = 2
local PAD_X, PAD_TOP, PAD_BOTTOM = 6, 4, 2
local COMPACT_PAD = 3
local GAP = 2
local ROW_GAP = 1
local TEXT_GAP = 4
local TEXT_INSET = 2
local NAME_EXTRA = 3
local ROW_SHARE = 0.85
local GLYPH_SHARE = 0.7
local DETAIL_SHARE = 0.75
local FULL_MIN_HEIGHT = 36
local GLASS_INSET = 2
local BADGE_SHARE = 0.36
local BADGE_MIN = 14
local LEVEL_COLUMN = 2.6
local MIN_HEALTH = 2
local MAX_COLUMN_SHARE = 0.5

Geometry.TEXT_GAP = TEXT_GAP
Geometry.FULL_MIN_HEIGHT = FULL_MIN_HEIGHT
Geometry.DETAIL_SHARE = DETAIL_SHARE

local function Rect(x, y, w, h)
	return { x = x, y = y, w = max(0, w), h = max(0, h) }
end

local function Size(s, element, scale)
	local fonts = s.fonts and s.fonts[element]
	return (fonts and fonts.size or 11) * scale
end

local function Column(format, size, room)
	return min(Format.ColumnWidth(format or "none", size), max(0, floor(room * MAX_COLUMN_SHARE)))
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

local function Glass(out, s, width, height)
	local portrait = out.portrait
	if not portrait then
		return Rect(0, 0, width, height)
	end
	local inset = out.compact and 0 or min(GLASS_INSET, height / 4)
	local centre = portrait.x + portrait.w / 2
	if s.portraitSide == "RIGHT" then
		return Rect(0, inset, centre, height - 2 * inset)
	end
	return Rect(centre, inset, width - centre, height - 2 * inset)
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

local function PowerHeight(s, room)
	if not s.power then
		return 0
	end
	return max(0, min(s.powerHeight or 0, room - MIN_HEALTH - GAP))
end

local function PowerRoom(powerH)
	return powerH > 0 and powerH + GAP or 0
end

local function TextRow(x, w, slotY, slotH, size, height)
	local h = min(size + NAME_EXTRA, height)
	local y = max(0, min(slotY + slotH / 2 - h / 2, height - h))
	return Rect(x, y, w, h)
end

local function Full(out, s, scale, height)
	local panel, glass = out.panel, out.glass
	local ix, iw = panel.x + PAD_X, max(0, panel.w - 2 * PAD_X)
	local top, bottom = glass.y + PAD_TOP, glass.y + glass.h - PAD_BOTTOM
	local powerH = PowerHeight(s, max(0, bottom - top))
	local healthSize, powerSize = Size(s, "health", scale), Size(s, "power", scale)
	local healthText = (s.healthText or "none") ~= "none"
	local trackMin = healthText and max(MIN_HEALTH, ceil(healthSize * ROW_SHARE)) or MIN_HEALTH
	local y = bottom
	if powerH > 0 then
		y = y - powerH
		out.power = Rect(ix, y, iw, powerH)
		y = y - ROW_GAP
	end
	if s.name then
		local nameSize = Size(s, "name", scale)
		local nameH = min(ceil(nameSize * ROW_SHARE), y - top - trackMin - ROW_GAP)
		if nameH >= ceil(nameSize * GLYPH_SHARE) then
			local nameW = iw
			if s.level and not out.portrait then
				local levelSize = Size(s, "level", scale)
				local levelCol = ceil(LEVEL_COLUMN * levelSize)
				nameW = iw - levelCol - TEXT_GAP
				out.levelText = TextRow(ix + iw - levelCol, levelCol, top, nameH, levelSize, height)
			end
			out.name = TextRow(ix, nameW, top, nameH, nameSize, height)
			top = top + nameH + ROW_GAP
		end
	end
	local detail = s.healthText == "both"
	local powerText = powerH > 0 and (s.powerText or "none") ~= "none"
	local rowH = ceil(max(detail and healthSize * DETAIL_SHARE or 0, powerText and powerSize or 0) * ROW_SHARE)
	local trackEnd = y
	local tx, tw = ix + TEXT_INSET, max(0, iw - 2 * TEXT_INSET)
	if rowH > 0 and y - rowH - ROW_GAP - top >= trackMin then
		local rowY = y - rowH
		trackEnd = rowY - ROW_GAP
		local half = max(0, (tw - TEXT_GAP) / 2)
		if detail then
			local w = powerText and half or tw
			out.healthSub = TextRow(tx + tw - w, w, rowY, rowH, healthSize * DETAIL_SHARE, height)
		end
		if powerText then
			out.powerText = TextRow(tx, detail and half or tw, rowY, rowH, powerSize, height)
		end
	end
	out.health = Rect(ix, top, iw, trackEnd - top)
	if healthText then
		out.healthText = TextRow(tx, tw, out.health.y, out.health.h, healthSize, height)
	end
end

local function Compact(out, s, scale, left, right, height)
	local ix, iw = left + COMPACT_PAD, right - left - 2 * COMPACT_PAD
	local top, bottom = COMPACT_PAD, height - COMPACT_PAD
	local healthCol = Column(s.healthText, Size(s, "health", scale), iw)
	local powerH = PowerHeight(s, max(0, bottom - top))
	local healthH = max(0, bottom - top - PowerRoom(powerH))
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
	out.glass = Glass(out, s, width, height)
	if out.compact then
		Compact(out, s, scale, left, right, height)
	else
		Badge(out, s)
		Full(out, s, scale, height)
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
