-- Geometry.lua: where a unit frame's portrait, glass panel, bars and texts sit, as pure maths over its settings and size.
local _, ns = ...

local Format = ns.Format

local Geometry = {}
ns.Geometry = Geometry

local max, min, ceil, floor = math.max, math.min, math.ceil, math.floor

local PORTRAIT_GAP = 2
local PAD_X, PAD_TOP, PAD_BOTTOM = 6, 4, 2
local INNER_SHARE, OUTER_SHARE = 0.12, 0.18
local TOP_SHARE, GAP_SHARE, BOTTOM_SHARE = 0.15, 0.09, 0.035
local LINE_GAP = 2
local PAD_LIMIT = 0.4
local COMPACT_PAD = 3
local GAP = 2
local ROW_GAP = 1
local TEXT_GAP = 4
local TEXT_INSET = 2
local NAME_EXTRA = 3
local ROW_SHARE = 0.85
local GLYPH_SHARE = 0.7
local DETAIL_SHARE = 0.85
local FULL_MIN_HEIGHT = 36
local GLASS_INSET = 2
local BADGE_SHARE = 0.34
local BADGE_MIN = 14
local LEVEL_COLUMN = 2.6
local MIN_HEALTH = 2
local MAX_COLUMN_SHARE = 0.5

Geometry.TEXT_GAP = TEXT_GAP
Geometry.FULL_MIN_HEIGHT = FULL_MIN_HEIGHT
Geometry.DETAIL_SHARE = DETAIL_SHARE
Geometry.BOSS_COUNT, Geometry.BOSS_GAP = 5, 10

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

local function ColumnX(out, s, height)
	local inner, outer = max(PAD_X, INNER_SHARE * height), max(PAD_X, OUTER_SHARE * height)
	local left, right = outer, outer
	if out.portrait and s.portraitSide == "RIGHT" then
		right = inner
	elseif out.portrait then
		left = inner
	end
	local limit = PAD_LIMIT * out.panel.w
	if left + right > limit then
		left, right = left * limit / (left + right), right * limit / (left + right)
	end
	return out.panel.x + left, max(0, out.panel.w - left - right)
end

local function Full(out, s, scale, height)
	local glass = out.glass
	local ix, iw = ColumnX(out, s, height)
	local top = glass.y
	local bottom = glass.y + glass.h - max(PAD_BOTTOM, floor(BOTTOM_SHARE * height + 0.5))
	local room = max(0, bottom - top)
	local powerH = PowerHeight(s, max(0, room - PAD_TOP))
	local healthSize, powerSize = Size(s, "health", scale), Size(s, "power", scale)
	local healthText = (s.healthText or "none") ~= "none"
	local trackMin = healthText and max(MIN_HEALTH, ceil(healthSize * ROW_SHARE)) or MIN_HEALTH
	local detail = s.healthText == "both"
	local powerText = powerH > 0 and (s.powerText or "none") ~= "none"
	local rowH = ceil(max(detail and healthSize * DETAIL_SHARE or 0, powerText and powerSize or 0) * ROW_SHARE)
	local nameSize = s.name and Size(s, "name", scale) or 0
	local nameH = ceil(nameSize * ROW_SHARE)
	local function Need(pad, gap, name, row)
		local n = pad + trackMin
		if powerH > 0 then
			n = n + gap + powerH
		end
		if name > 0 then
			n = n + name + gap
		end
		if row > 0 then
			n = n + row + gap
		end
		return n
	end
	if rowH > 0 and Need(PAD_TOP, ROW_GAP, nameH, rowH) > room then
		rowH = 0
	end
	if nameH > 0 and Need(PAD_TOP, ROW_GAP, nameH, rowH) > room then
		nameH = room - Need(PAD_TOP, ROW_GAP, 0, rowH) - ROW_GAP
		if nameH < ceil(nameSize * GLYPH_SHARE) then
			nameH = 0
		end
	end
	local pad, gap = max(PAD_TOP, TOP_SHARE * height), max(ROW_GAP, GAP_SHARE * height)
	local over = Need(pad, gap, nameH, rowH) - room
	if over > 0 then
		local gaps = (powerH > 0 and 1 or 0) + (nameH > 0 and 1 or 0) + (rowH > 0 and 1 or 0)
		local slack = pad - PAD_TOP + gaps * (gap - ROW_GAP)
		local t = slack > 0 and max(0, 1 - over / slack) or 0
		pad, gap = PAD_TOP + (pad - PAD_TOP) * t, ROW_GAP + (gap - ROW_GAP) * t
	end
	local y = bottom
	if powerH > 0 then
		y = y - powerH
		out.power = Rect(ix, y, iw, powerH)
		y = y - gap
	end
	local tx, tw = ix + TEXT_INSET, max(0, iw - 2 * TEXT_INSET)
	if rowH > 0 then
		local rowY = y - rowH
		local half = max(0, (tw - TEXT_GAP) / 2)
		if detail then
			local w = powerText and half or tw
			out.healthSub = TextRow(tx + tw - w, w, rowY, rowH, healthSize * DETAIL_SHARE, height)
		end
		if powerText then
			out.powerText = TextRow(tx, detail and half or tw, rowY, rowH, powerSize, height)
		end
		y = rowY - gap
	end
	local trackTop = top + pad
	if nameH > 0 then
		local nameW = iw
		if s.level and not out.portrait then
			local levelSize = Size(s, "level", scale)
			local levelCol = ceil(LEVEL_COLUMN * levelSize)
			nameW = iw - levelCol - TEXT_GAP
			out.levelText = TextRow(ix + iw - levelCol, levelCol, trackTop, nameH, levelSize, height)
		end
		out.name = TextRow(ix, nameW, trackTop, nameH, nameSize, height)
		trackTop = trackTop + nameH + gap
	end
	out.health = Rect(ix, trackTop, iw, y - trackTop)
	if healthText then
		out.healthText = TextRow(tx, tw, out.health.y, out.health.h, healthSize, height)
	end
	if (rowH > 0 or powerH > 0) and gap >= LINE_GAP + 1 then
		out.trackLine = Rect(ix, y + LINE_GAP, iw, 1)
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
