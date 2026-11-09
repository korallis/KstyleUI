-- Geometry.lua: where a unit frame's portrait, glass panel, bars and texts sit, as pure maths over its settings and size.
local _, ns = ...

local Format = ns.Format

local Geometry = {}
ns.Geometry = Geometry

local max, min, ceil, floor = math.max, math.min, math.ceil, math.floor

local PORTRAIT_GAP = 0
local PAD_X, PAD_TOP, PAD_BOTTOM = 6, 4, 2
local GAP_SHARE, BOTTOM_SHARE = 0.1, 0.14
local POWER_SHARE = 0.37
local LINE_GAP = 2
local PAD_LIMIT = 0.4
local COMPACT_PAD = 3
local GAP = 2
local ROW_GAP = 1
local TEXT_GAP = 4
local NAME_EXTRA = 3
local ROW_SHARE = 0.85
local GLYPH_SHARE = 0.7
local DETAIL_SHARE = 0.85
local FULL_MIN_HEIGHT = 36
local BADGE_MIN = 14
local SHAPE = {
	chamfered = { share = 0.36, across = 0.19, up = 0.125, inner = 0.147, outer = 0.2, inset = 2, top = 0.15 },
	round = { share = 0.37, across = 0.196, up = 0.196, inner = 0.085, outer = 0.15, insetShare = 0.06, top = 0.095, textShare = 0.28 },
}

local function Shape(s)
	return SHAPE[s.portraitShape] or SHAPE.chamfered
end
local LEVEL_COLUMN = 2.6
local MIN_HEALTH = 2
local MAX_COLUMN_SHARE = 0.5

Geometry.TEXT_GAP = TEXT_GAP
Geometry.FULL_MIN_HEIGHT = FULL_MIN_HEIGHT
Geometry.DETAIL_SHARE = DETAIL_SHARE
Geometry.BOSS_COUNT, Geometry.BOSS_GAP = 5, 6

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
	local shape = Shape(s)
	local inset = out.compact and 0 or min(shape.inset or shape.insetShare * height, height / 4)
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
	local shape = Shape(s)
	local size = max(BADGE_MIN, ceil(portrait.w * shape.share))
	local across, up = shape.across * portrait.w, shape.up * portrait.h
	local x = portrait.x + across - size / 2
	if s.portraitSide == "RIGHT" then
		x = portrait.x + portrait.w - across - size / 2
	end
	out.badge = Rect(x, portrait.y + portrait.h - up - size / 2, size, size)
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
	local shape = Shape(s)
	local inner, outer = max(PAD_X, shape.inner * height), max(PAD_X, shape.outer * height)
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
	local glass, shape = out.glass, Shape(s)
	local ix, iw = ColumnX(out, s, height)
	local top = glass.y
	local bottom = glass.y + glass.h - max(PAD_BOTTOM, floor(BOTTOM_SHARE * glass.h + 0.5))
	local room = max(0, bottom - top)
	local powerH = PowerHeight(s, max(0, room - PAD_TOP))
	local healthSize, powerSize = Size(s, "health", scale), Size(s, "power", scale)
	local healthText = (s.healthText or "none") ~= "none"
	local trackMin = healthText and max(MIN_HEALTH, ceil(healthSize * ROW_SHARE)) or MIN_HEALTH
	local detail = s.healthText == "both"
	local powerText = powerH > 0 and (s.powerText or "none") ~= "none"
	local rowH = max(ceil(max(detail and healthSize * DETAIL_SHARE or 0, powerText and powerSize or 0) * ROW_SHARE), powerH)
	local nameSize = s.name and Size(s, "name", scale) or 0
	local nameH = ceil(nameSize * ROW_SHARE)
	local function Need(pad, gap, name, row)
		local n = pad + trackMin
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
	local pad, gap = max(PAD_TOP, shape.top * glass.h), max(ROW_GAP, GAP_SHARE * glass.h)
	local over = Need(pad, gap, nameH, rowH) - room
	if over > 0 then
		local gaps = (nameH > 0 and 1 or 0) + (rowH > 0 and 1 or 0)
		local slack = pad - PAD_TOP + gaps * (gap - ROW_GAP)
		local t = slack > 0 and max(0, 1 - over / slack) or 0
		pad, gap = PAD_TOP + (pad - PAD_TOP) * t, ROW_GAP + (gap - ROW_GAP) * t
	end
	local y = bottom
	if rowH > 0 then
		local rowY = y - rowH
		local left, right = ix, ix + iw
		if powerH > 0 then
			local powerW = floor(iw * POWER_SHARE)
			out.power = Rect(ix, rowY + (rowH - powerH) / 2, powerW, powerH)
			left = ix + powerW + TEXT_GAP
		end
		local rest = max(0, right - left)
		local half = max(0, (rest - TEXT_GAP) / 2)
		if detail then
			local w = powerText and half or rest
			out.healthSub = TextRow(right - w, w, rowY, rowH, healthSize * DETAIL_SHARE, height)
		end
		if powerText then
			out.powerText = TextRow(left, detail and half or rest, rowY, rowH, powerSize, height)
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
	local trackW = iw
	if healthText then
		local col = Column(Format.Shown(s.healthText, detail and rowH > 0), healthSize, iw)
		if shape.textShare then
			col = max(col, floor(iw * shape.textShare))
		end
		if iw - col - TEXT_GAP >= iw * MAX_COLUMN_SHARE then
			trackW = iw - col - TEXT_GAP
			out.healthText = TextRow(ix + iw - col, col, trackTop, y - trackTop, healthSize, height)
		else
			out.healthText = TextRow(ix, iw, trackTop, y - trackTop, healthSize, height)
		end
	end
	out.health = Rect(ix, trackTop, trackW, y - trackTop)
	if rowH > 0 and gap >= LINE_GAP + 1 then
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

local V = { ring = 62, ringGap = 16 / 62, disc = 22 / 62, discOut = 4 / 62, health = 12, pillGap = 4, nameGap = 7, captionMin = 300 }
local CAST_LINE, CAST_GAP, BOLD_LINE = 12, 6, 16
local GEM, GEM_GAP = 7, 14
local SIGIL = { line = 1, bar = 8, cast = 8, castShare = 0.6 }
local CARD = { padX = 18, top = 16, bottom = 14, capGap = 10, nameGap = 6, health = 10, powerGap = 3, powerMax = 6, castGap = 10, gemGap = 8, compact = 84 }
local ROW = { pill = 6, gap = 1, power = 3 }

Geometry.CAST_LINE, Geometry.BOLD_LINE, Geometry.GEM = CAST_LINE, BOLD_LINE, GEM

local function TextH(size)
	return size + NAME_EXTRA
end

local function Above(x, w, bottom, size)
	local h = TextH(size)
	local y = max(0, bottom - h)
	return Rect(x, y, w, max(0, bottom - y))
end

local function ValueFormats(format)
	if format == "both" or format == "currentMax" then
		return "current", true
	end
	return format or "none", false
end

local function Vitals(out, s, width, height, scale)
	local castRoom = s.castbar and CAST_LINE + CAST_GAP or 0
	local foot = max(0, height - castRoom)
	local x0 = 0
	if s.portrait then
		local size = max(0, min(foot, floor(width / 3)))
		out.portrait = Rect(0, 0, size, size)
		x0 = size + floor(size * V.ringGap + 0.5)
		if s.level then
			local disc = max(BADGE_MIN, ceil(size * V.disc))
			local edge = size + size * V.discOut
			out.badge = Rect(edge - disc, edge - disc, disc, disc)
		end
		foot = size
	end
	local colW = max(0, width - x0)
	out.panel = Rect(x0, 0, colW, foot)
	local y = foot
	local powerH = PowerHeight(s, max(0, foot - MIN_HEALTH - V.pillGap))
	if powerH > 0 then
		out.power = Rect(x0, y - powerH, colW, powerH)
		y = y - powerH - V.pillGap
	end
	local healthH = max(0, min(V.health, y))
	out.health = Rect(x0, y - healthH, colW, healthH)
	local nameSize, valueSize, captionSize = Size(s, "name", scale), Size(s, "health", scale), Size(s, "level", scale)
	local rowBottom = max(0, y - healthH - V.nameGap)
	rowBottom = max(rowBottom, min(out.health.y, TextH(max(nameSize, valueSize))))
	local main, split = ValueFormats(s.healthText)
	local valueW = 0
	if main ~= "none" then
		local subW = split and Format.ColumnWidth("current", captionSize) or 0
		local curW = Format.ColumnWidth(main, valueSize)
		if split then
			out.healthSub = Above(x0 + colW - subW, subW, rowBottom, captionSize)
		end
		out.healthText = Above(x0 + colW - subW - curW, curW, rowBottom, valueSize)
		valueW = subW + curW + TEXT_GAP
	end
	local nameW = max(0, colW - valueW)
	if s.name then
		out.name = Above(x0, nameW, rowBottom, nameSize)
		if colW >= V.captionMin then
			out.nameAuto = true
			out.caption = Above(x0, nameW, rowBottom, captionSize)
		end
	end
	if s.castbar then
		out.cast = Rect(x0, height - CAST_LINE, colW, CAST_LINE)
	end
end

local function Sigil(out, s, width, height, scale)
	local nameH = s.name and TextH(Size(s, "name", scale)) or 0
	local captionH = s.level and TextH(Size(s, "level", scale)) or 0
	local healthH = min(V.health, height)
	local castH = s.castbar and BOLD_LINE or 0
	local barGap, castGap = SIGIL.bar, castH > 0 and SIGIL.cast or 0
	local text = nameH + (nameH > 0 and SIGIL.line or 0) + captionH
	local over = text + barGap + healthH + castGap + castH - height
	if over > 0 then
		local slack = barGap + castGap - 2 * SIGIL.line
		local t = slack > 0 and max(0, 1 - over / slack) or 0
		barGap = SIGIL.line + (barGap - SIGIL.line) * t
		castGap = castH > 0 and SIGIL.line + (castGap - SIGIL.line) * t or 0
	end
	local y = 0
	if nameH > 0 then
		out.name = Rect(0, 0, width, min(nameH, height))
		y = nameH + SIGIL.line
	end
	if captionH > 0 then
		out.caption = Rect(0, min(y, max(0, height - captionH)), width, min(captionH, height))
		y = y + captionH
	end
	y = min(y + barGap, height - healthH)
	local inset = GEM + GEM_GAP
	out.health = Rect(inset, y, width - 2 * inset, healthH)
	local gemY = y + healthH / 2 - GEM / 2
	out.gemLeft = Rect(0, gemY, GEM, GEM)
	out.gemRight = Rect(width - GEM, gemY, GEM, GEM)
	y = y + healthH + castGap
	if castH > 0 and y + castH <= height + 1e-6 then
		local w = floor(width * SIGIL.castShare)
		out.cast = Rect((width - w) / 2, y, w, castH)
	end
end

local function Card(out, s, width, height, scale)
	local padX = min(CARD.padX, floor(width * 0.08))
	local colW = max(0, width - 2 * padX)
	local nameSize, valueSize, capSize = Size(s, "name", scale), Size(s, "health", scale), Size(s, "level", scale)
	local capH, rowH, healthH = TextH(capSize), TextH(max(nameSize, valueSize)), CARD.health
	if height < CARD.compact then
		capH = 0
	end
	local powerH = s.power and min(s.powerHeight or 0, CARD.powerMax) or 0
	local castH = s.castbar and BOLD_LINE or 0
	local gaps = { CARD.top, capH > 0 and CARD.capGap or 0, CARD.nameGap, powerH > 0 and CARD.powerGap or 0, castH > 0 and CARD.castGap or 0, CARD.bottom }
	local fixed = capH + rowH + healthH + powerH + castH
	local sum = 0
	for _, g in ipairs(gaps) do
		sum = sum + g
	end
	if fixed + sum > height and castH > 0 and fixed > height - 2 then
		castH, gaps[5] = 0, 0
		fixed = fixed - BOLD_LINE
	end
	if fixed > height then
		fixed, capH, gaps[2] = fixed - capH, 0, 0
	end
	if fixed > height then
		fixed, rowH, gaps[3] = fixed - rowH, 0, 0
	end
	if fixed > height then
		fixed, powerH, gaps[4] = fixed - powerH, 0, 0
	end
	healthH = max(0, min(healthH, height))
	local t = 1
	if fixed + sum > height and sum > 0 then
		t = max(0, (height - min(fixed, height)) / sum)
	end
	local function gap(i)
		return gaps[i] * t
	end
	local y = gap(1)
	if capH > 0 then
		out.cap = Rect(padX, y, colW, capH)
		out.capGem = Rect(padX, y + capH / 2 - GEM / 2, GEM, GEM)
		out.capLabel = Rect(padX + GEM + CARD.gemGap, y, floor(colW / 2), capH)
		out.caption = Rect(padX + floor(colW / 2), y, colW - floor(colW / 2), capH)
	end
	y = y + capH + gap(2)
	local main = Format.Main(s.healthText)
	local pctW = main ~= "none" and Column(main, valueSize, colW) or 0
	if rowH > 0 and pctW > 0 then
		out.healthText = Rect(padX + colW - pctW, y, pctW, rowH)
	end
	if rowH > 0 and s.name then
		out.name = Rect(padX, y, max(0, colW - pctW - (pctW > 0 and TEXT_GAP or 0)), rowH)
	end
	y = min(y + rowH + gap(3), height - healthH)
	out.health = Rect(padX, y, colW, healthH)
	y = y + healthH
	if powerH > 0 then
		y = y + gap(4)
		out.power = Rect(padX, y, colW, powerH)
		y = y + powerH
	end
	if castH > 0 then
		out.rest = min(height, y + gap(6))
		y = y + gap(5)
		out.cast = Rect(padX, y, colW, castH)
	end
	out.panel = Rect(padX, 0, colW, height)
end

local function PillRow(out, s, width, height, scale)
	local powerH = s.power and min(s.powerHeight or 0, ROW.power) or 0
	local pill = min(ROW.pill, floor(height / 3))
	local bottom = height
	if powerH > 0 then
		out.power = Rect(0, height - powerH, width, powerH)
		bottom = height - powerH - ROW.gap
	end
	out.health = Rect(0, bottom - pill, width, pill)
	local textH = max(0, out.health.y - ROW.gap)
	local col = 0
	if (s.healthText or "none") ~= "none" then
		col = Column(s.healthText, Size(s, "health", scale), width)
		out.healthText = Rect(width - col, 0, col, textH)
	end
	if s.name then
		out.name = Rect(0, 0, max(0, width - col - (col > 0 and GAP or 0)), textH)
	end
end

local LUMEN = { vitals = Vitals, sigil = Sigil, card = Card, row = PillRow }

function Geometry.Frame(s, width, height, fontScale)
	local scale = fontScale or 1
	local lumen = LUMEN[s.form]
	if lumen then
		local out = { form = s.form, compact = s.form == "row", chrome = s.form == "card" }
		out.glass = Rect(0, 0, width, height)
		out.panel = Rect(0, 0, width, height)
		lumen(out, s, width, height, scale)
		return out
	end
	local out = { compact = height < FULL_MIN_HEIGHT, form = "plate", chrome = true }
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
