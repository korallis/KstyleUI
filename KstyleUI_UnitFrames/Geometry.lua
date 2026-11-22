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
local VALUES_SHARE = 0.6

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

local function Column(s, format, size, room)
	return min(Format.ColumnWidth(format or "none", size, s.healthDecimal, s.healthValues), max(0, floor(room * (s.healthValues and VALUES_SHARE or MAX_COLUMN_SHARE))))
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
		local col = Column(s, Format.Shown(s.healthText, detail and rowH > 0), healthSize, iw)
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
	local healthCol = Column(s, s.healthText, Size(s, "health", scale), iw)
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

local CAST_LINE, BOLD_LINE = 12, 16
local GEM = 7

Geometry.CAST_LINE, Geometry.BOLD_LINE, Geometry.GEM = CAST_LINE, BOLD_LINE, GEM

local function TextH(size)
	return size + NAME_EXTRA
end

local SLAB = {
	player = { h = 58, d = 86, bar = 26, power = 6, name = 14, side = "LEFT", extra = "health" },
	target = { h = 58, d = 86, bar = 26, power = 6, name = 14, side = "RIGHT", extra = "caption" },
	focus = { h = 44, d = 62, bar = 15, side = "LEFT" },
	pet = { h = 34, d = 56, bar = 14, power = 3, side = "LEFT" },
	boss = { h = 48, d = 62, bar = 16, side = "RIGHT" },
	targettarget = { h = 34, bar = 14 },
	focustarget = { h = 34, bar = 14 },
}
local SLAB_PAD = { top = 5, outer = 9, inner = 6, centre = 2, power = 5, powerGap = 2, nameGap = 2, powerNameGap = 2, auraGap = 16, nameShare = 0.7, levelGap = 6, levelEm = 1.9, valuePad = 7 }
Geometry.SLAB, Geometry.SLAB_PAD = SLAB, SLAB_PAD

local function SlabFrame(out, s, width, height, scale)
	local spec = SLAB[s.kind] or SLAB.targettarget
	local k = height / spec.h
	local top, barH = SLAB_PAD.top * k, spec.bar * k
	local nameSize = Size(s, "name", scale)
	if not spec.d then
		local pad = SLAB_PAD.top * k
		out.health = Rect(pad, top, width - 2 * pad, barH)
		if s.name then
			out.name = Rect(pad, top + barH, width - 2 * pad, max(0, height - top - barH))
		end
		return
	end
	local d = spec.d * k
	local right = spec.side == "RIGHT"
	local cx = right and width - SLAB_PAD.centre * k or SLAB_PAD.centre * k
	out.medal = Rect(cx - d / 2, height / 2 - d / 2, d, d)
	out.medalSide = spec.side
	out.mirror = right
	local inner, outer = d / 2 + SLAB_PAD.inner * k, SLAB_PAD.outer * k
	local left = right and outer or inner
	local barW = max(0, width - inner - outer)
	out.health = Rect(left, top, barW, barH)
	local y = top + barH + SLAB_PAD.nameGap * k
	if s.power then
		local powerTop, powerH = top + barH + SLAB_PAD.powerGap * k, (spec.power or SLAB_PAD.power) * k
		out.power = Rect(left, powerTop, barW, powerH)
		y = powerTop + powerH + SLAB_PAD.powerNameGap * k
	end
	if (s.healthText or "none") ~= "none" then
		local pad = SLAB_PAD.valuePad * k
		out.healthText = Rect(left + pad, top, max(0, barW - 2 * pad), barH)
	end
	local rowH = max(TextH(nameSize), (spec.name or 0) * k)
	local powerText = s.power and (s.powerText or "none") ~= "none" and s.powerText ~= "legacy"
	if powerText and y + rowH > height then
		local shift = max(0, y + rowH - height - SLAB_PAD.powerNameGap * k)
		out.health.y, out.power.y = out.health.y - shift, out.power.y - shift
		if out.healthText then out.healthText.y = out.healthText.y - shift end
		y = height - rowH
	end
	local extra = powerText or spec.extra == "health" and s.healthText == "both"
	local room = extra and floor(barW * SLAB_PAD.nameShare) or barW
	if s.name then
		local levelSize = Size(s, "level", scale)
		out.name = Rect(right and left + barW - room or left, y, room, rowH)
		out.nameAuto, out.levelGap = true, SLAB_PAD.levelGap
		out.nameRoom = s.singleSlabLevel and room or max(0, room - ceil(SLAB_PAD.levelEm * levelSize) - SLAB_PAD.levelGap)
	end
	local extraW = max(0, barW - room - TEXT_GAP)
	local extraX = right and left or left + barW - extraW
	if extra then
		out[powerText and "powerText" or "healthSub"] = Rect(extraX, y, extraW, rowH)
	elseif spec.extra == "caption" then
		out.caption = Rect(extraX, y, extraW, rowH)
	end
	if s.rowsAbove and s.auraPosition == "ABOVE" then
		out.aura = { outer = true, x = right and out.medal.x + out.medal.w or out.medal.x, y = out.medal.y - 8 }
	elseif s.auras and s.auraPosition == "SIDE" then
		local line = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing
		out.aura = Rect(right and left + barW - line or left, -(s.auraSize + SLAB_PAD.auraGap), 0, 0)
	end
end

function Geometry.Reach(s)
	if s.form == "slab" then
		local spec = SLAB[s.kind]
		if not (spec and spec.d) then
			return 0, 0
		end
		local over = spec.d / 2 - SLAB_PAD.centre
		if spec.side == "RIGHT" then
			return 0, over
		end
		return over, 0
	end
	return 0, 0
end

local LUMEN = { slab = SlabFrame }

local MARKER_EXTRA, MARKER_GAP = 4, 4
Geometry.MARKER_EXTRA, Geometry.MARKER_GAP = MARKER_EXTRA, MARKER_GAP

function Geometry.Overlaps(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function Marker(out, s)
	if not s.raidMarker then
		return
	end
	local size = (s.markerSize or 0) > 0 and s.markerSize or (s.iconSize or 12) + MARKER_EXTRA
	if out.form == "slab" and out.medal then
		local medal = out.medal
		local x = out.mirror and medal.x + medal.w + MARKER_GAP or medal.x - size - MARKER_GAP
		out.marker = Rect(x, medal.y - MARKER_GAP, size, size)
		return
	end
	local anchor = out.portrait or out.panel
	local spot = Rect(anchor.x + anchor.w / 2 - size / 2, -size / 2, size, size)
	local name = out.name
	out.marker = spot
	if not (name and name.w > 0 and Geometry.Overlaps(spot, name)) then
		return
	end
	local cut = size + MARKER_GAP
	local centred = out.form == "sigil"
	out.marker = Rect(name.x, name.y + name.h / 2 - size / 2, size, size)
	out.markedName = Rect(name.x + cut, name.y, name.w - (centred and 2 or 1) * cut, name.h)
	out.markerCentred = centred
end

local function PowerLane(out, s)
	if out.powerText or not (s.power and out.power) or (s.powerText or "none") == "none" or s.powerText == "legacy" then return end
	local power = out.power
	out.powerText = Rect(power.x + TEXT_GAP, power.y, max(0, power.w - 2 * TEXT_GAP), power.h)
end

local SWAP = { "name", "healthText", "healthSub", "powerText", "levelText", "caption", "trackLine" }

local function PowerAbove(out, s)
	local h, p = out.health, out.power
	if not (s.powerAbove and h and p and out.form ~= "slab") or p.y < h.y then return end
	local gap = p.y - h.y - h.h
	local down, up = p.h + gap, h.h + gap
	for _, key in ipairs(SWAP) do
		local r = out[key]
		local mid = r and r.y + r.h / 2
		if mid and mid >= p.y and mid <= p.y + p.h then
			r.y = r.y - up
		elseif mid and mid > h.y and mid < h.y + h.h then
			r.y = r.y + down
		elseif mid and mid >= h.y + h.h and mid < p.y then
			r.y = r.y + down - up
		end
	end
	h.y, p.y = h.y + down, p.y - up
end

local DETACH_GAP, DETACH_BODY = 4, 12

local function Detached(s, width, height, scale)
	local h = max(0, min(s.powerHeight or 0, height - DETACH_GAP - DETACH_BODY))
	s.power = false
	local out = Geometry.Frame(s, width, height - h - DETACH_GAP, scale)
	s.power = true
	local top, seen = s.powerDetach == "ABOVE", {}
	for key, r in pairs(top and out or seen) do
		if type(r) == "table" and type(r.y) == "number" and not seen[r] and (key ~= "aura" or r.centred) then
			seen[r], r.y = true, r.y + h + DETACH_GAP
		end
	end
	local panel = out.panel
	local w = s.powerDetachWidth > 0 and s.powerDetachWidth or panel.w
	if h > 0 then
		out.power = Rect(panel.x + (panel.w - w) / 2 + s.powerDetachX, (top and 0 or height - h) - s.powerDetachY, w, h)
		PowerLane(out, s)
	end
	return out
end

function Geometry.Frame(s, width, height, fontScale)
	local scale = fontScale or 1
	if s.power and (s.powerDetach or "") ~= "" and s.form ~= "slab" then
		return Detached(s, width, height, scale)
	end
	local lumen = LUMEN[s.form]
	if lumen then
		local out = { form = s.form, compact = s.form == "row", chrome = false }
		out.glass = Rect(0, 0, width, height)
		out.panel = Rect(0, 0, width, height)
		lumen(out, s, width, height, scale)
		PowerLane(out, s)
		PowerAbove(out, s)
		Marker(out, s)
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
	PowerAbove(out, s)
	Marker(out, s)
	return out
end

function Geometry.Slots(count, gap, width, height, up)
	local slot = max(0, (height - gap * (count - 1)) / count)
	local out = {}
	for i = 1, count do
		local row = up and count - i or i - 1
		out[i] = Rect(0, row * (slot + gap), width, slot)
	end
	return out
end
