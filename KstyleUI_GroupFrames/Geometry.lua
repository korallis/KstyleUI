-- Geometry.lua: the group frames' layout maths: header attributes per growth, holder sizes, raid group slots and the parts inside one frame.
local _, ns = ...

local K = KstyleUI
local Tokens = K.Tokens
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local Geometry = {}
ns.Geometry = Geometry

local PARTY_MAX = 5
local RAID_GROUPS = 8
local GROUP_SIZE = 5
local RAID_MAX = 40
local MIN_PART = 1
Geometry.PAD = Tokens.Size("gapSmall")

local GROWTH = {
	DOWN = { point = "TOP", x = 0, y = -1, vertical = true, column = "TOP" },
	UP = { point = "BOTTOM", x = 0, y = 1, vertical = true, column = "BOTTOM" },
	RIGHT = { point = "LEFT", x = 1, y = 0, vertical = false, column = "LEFT" },
	LEFT = { point = "RIGHT", x = -1, y = 0, vertical = false, column = "RIGHT" },
}
Geometry.GROWTHS = { "DOWN", "UP", "RIGHT", "LEFT" }

local function Clean(growth, fallback)
	if GROWTH[growth] then
		return growth
	end
	return fallback or "DOWN"
end
Geometry.Clean = Clean

local function Clamp(v, low, high)
	if type(v) ~= "number" or v ~= v then
		return low
	end
	return min(max(v, low), high)
end
Geometry.Clamp = Clamp

function Geometry.IsVertical(growth)
	return GROWTH[Clean(growth)].vertical
end

function Geometry.Grow(growth, spacing)
	local g = GROWTH[Clean(growth)]
	return g.point, g.x * spacing, g.y * spacing
end

function Geometry.ColumnAnchor(growth)
	return GROWTH[Clean(growth, "RIGHT")].column
end

function Geometry.Offset(growth, distance)
	local g = GROWTH[Clean(growth)]
	return g.x * distance, g.y * distance
end

function Geometry.Corner(member, group)
	member, group = Clean(member), group and Clean(group)
	local up = member == "UP" or group == "UP"
	local left = member == "LEFT" or group == "LEFT"
	return (up and "BOTTOM" or "TOP") .. (left and "RIGHT" or "LEFT")
end

function Geometry.Perpendicular(member, group)
	member, group = Clean(member), Clean(group, "RIGHT")
	if GROWTH[member].vertical ~= GROWTH[group].vertical then
		return group
	end
	return GROWTH[member].vertical and "RIGHT" or "DOWN"
end

function Geometry.Wrap(member, group)
	member, group = Clean(member), Clean(group, "RIGHT")
	if GROWTH[member].vertical ~= GROWTH[group].vertical then
		return member
	end
	return GROWTH[group].vertical and "RIGHT" or "DOWN"
end

local function Line(count, size, spacing)
	if count <= 0 then
		return 0
	end
	return count * size + (count - 1) * spacing
end
Geometry.Line = Line

local function Block(growth, count, width, height, spacing)
	if GROWTH[growth].vertical then
		return width, Line(count, height, spacing)
	end
	return Line(count, width, spacing), height
end

local CARD_PAD = 20
local CARD_GAP = 8
Geometry.CARD_PAD = CARD_PAD
Geometry.CARD_GAP = CARD_GAP

function Geometry.Card(geo, cap)
	return geo.width + 2 * CARD_PAD, geo.height + CARD_PAD + cap + CARD_GAP + CARD_PAD, CARD_PAD, CARD_PAD + cap + CARD_GAP
end

local AURA_SIDES = { OUTSIDE_RIGHT = true, OUTSIDE_LEFT = true }
local LANE_KEEPS = 2
local SNAP_SLACK = 1

function Geometry.AuraLane(s, gap)
	if not AURA_SIDES[s.auraPosition] then
		return 0
	end
	gap = gap or Tokens.Size("gapSmall")
	local columns = max(1, min(s.auraColumns or 1, s.auraCount or 1))
	local lane = gap + Line(columns, s.auraSize or 0, s.auraSpacing or 0) + columns * SNAP_SLACK
	if s.width - lane < LANE_KEEPS * (s.height or 0) then
		return 0
	end
	return lane
end

function Geometry.MemberWidth(s, gap)
	return max(MIN_PART * 2, s.width - Geometry.AuraLane(s, gap))
end

local function Members(s, growth, count)
	local lane = Geometry.AuraLane(s)
	local memberWidth = s.width - lane
	local spacing = GROWTH[growth].vertical and s.spacing or s.spacing + lane
	local w, h = Block(growth, count, memberWidth, s.height, spacing)
	return w + lane, h, memberWidth, spacing, lane
end

function Geometry.Party(s)
	local growth = Clean(s.growth)
	local count = s.showPlayer == false and PARTY_MAX - 1 or PARTY_MAX
	local w, h, memberWidth, spacing, lane = Members(s, growth, count)
	local point, x, y = Geometry.Grow(growth, spacing)
	return {
		width = w, height = h, count = count, corner = Geometry.Corner(growth), point = point, xOffset = x, yOffset = y,
		memberWidth = memberWidth, lane = lane, laneSide = AURA_SIDES[s.auraPosition] and (s.auraPosition == "OUTSIDE_LEFT" and "LEFT" or "RIGHT") or nil,
	}
end

function Geometry.PartyShown(s, members)
	local most = s.showPlayer == false and PARTY_MAX - 1 or PARTY_MAX
	if type(members) ~= "number" or members ~= members then
		return most
	end
	local shown = members
	if members <= 0 then
		shown = s.showSolo and s.showPlayer ~= false and 1 or 0
	elseif s.showPlayer == false then
		shown = members - 1
	end
	return floor(Clamp(shown, 1, most))
end

function Geometry.PartyCard(s, cap, shown)
	local growth = Clean(s.growth)
	local w, h = Members(s, growth, shown)
	return Geometry.Card({ width = w, height = h }, cap)
end

function Geometry.RaidGroups(s)
	local member, group = Clean(s.growth), Clean(s.groupGrowth, "RIGHT")
	local wrap = Geometry.Wrap(member, group)
	local per = floor(Clamp(s.groupsPerRow, 1, RAID_GROUPS))
	local rows = ceil(RAID_GROUPS / per)
	local gw, gh = Block(member, GROUP_SIZE, s.width, s.height, s.spacing)
	local gap = s.groupSpacing
	local alongGroup = GROWTH[group].vertical and gh or gw
	local alongWrap = GROWTH[wrap].vertical and gh or gw
	local slots = {}
	for g = 0, RAID_GROUPS - 1 do
		local col, row = g % per, floor(g / per)
		local ax, ay = Geometry.Offset(group, col * (alongGroup + gap))
		local bx, by = Geometry.Offset(wrap, row * (alongWrap + gap))
		slots[g + 1] = { x = ax + bx, y = ay + by }
	end
	local extentGroup, extentWrap = Line(per, alongGroup, gap), Line(rows, alongWrap, gap)
	local w, h
	if GROWTH[group].vertical then
		w, h = extentWrap, extentGroup
	else
		w, h = extentGroup, extentWrap
	end
	local point, x, y = Geometry.Grow(member, s.spacing)
	return { width = w, height = h, slots = slots, corner = Geometry.Corner(member, group), point = point, xOffset = x, yOffset = y }
end

function Geometry.RaidFlow(s)
	local member = Clean(s.growth)
	local group = Geometry.Perpendicular(member, s.groupGrowth)
	local per = floor(Clamp(s.unitsPerColumn, 1, RAID_MAX))
	local columns = ceil(RAID_MAX / per)
	local cw, ch = Block(member, per, s.width, s.height, s.spacing)
	local w, h
	if GROWTH[group].vertical then
		w, h = cw, Line(columns, ch, s.groupSpacing)
	else
		w, h = Line(columns, cw, s.groupSpacing), ch
	end
	local point, x, y = Geometry.Grow(member, s.spacing)
	return {
		width = w, height = h, corner = Geometry.Corner(member, group), point = point, xOffset = x, yOffset = y,
		columnAnchorPoint = Geometry.ColumnAnchor(group), columnSpacing = s.groupSpacing,
		unitsPerColumn = per, maxColumns = columns, groupGrowth = group,
	}
end

local function Rect(left, top, width, height)
	return { left = left, top = top, width = max(MIN_PART, width), height = max(MIN_PART, height) }
end

local AURA_INSIDE_LANES = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local ICONS_ACROSS = 3
local BADGE_SHARE = 0.7

local function Centred(span, start, size)
	return start + (span - size) / 2
end

local MIN_ICON = 8
local MIN_BAR = 6
local INSET = Tokens.Size("gapTiny")
local BAR_GAP = 1
local BLOCK_SHARE = 0.45
local LEGIBLE = 12
local LANE_SLOTS = 2
Geometry.MIN_ICON = MIN_ICON
Geometry.INSET = INSET
Geometry.LEGIBLE = LEGIBLE
Geometry.LANE_SLOTS = LANE_SLOTS
local Overlay
local NAME_EM = 5.6

local function Whole(v, px)
	if px and px > 0 then
		return floor(v / px + 1e-6) * px
	end
	return floor(v)
end


local function HealsOnName(out, o, textLeft, textRight, keep, gap)
	local name = out.name
	if not o.healRow or (o.healCount or 0) <= 0 or out.nameInside or out.healRow then
		return textRight
	end
	local size = min(o.healRow, name.height)
	local spacing = o.healSpacing or 0
	local room = textRight - textLeft - keep - gap
	local count = min(o.healCount, floor((room + spacing) / (size + spacing)))
	if count < o.healCount and size > MIN_ICON then
		local shrunk = Whole((room - (o.healCount - 1) * spacing) / o.healCount, o.pixel)
		if shrunk >= MIN_ICON then
			size, count = min(size, shrunk), o.healCount
		end
	end
	if size < MIN_PART or count < 1 then
		return textRight
	end
	local width = Line(count, size, spacing)
	out.healRow = Rect(textRight - width, name.top + (name.height - size) / 2, width, size)
	out.healRow.side = "RIGHT"
	return textRight - width - gap
end

local function Indicators(out, w, h, o, pad, gap)
	local size = floor(min(o.iconSize, (w - (ICONS_ACROSS + 1) * gap) / ICONS_ACROSS, h - 2 * gap))
	size = max(MIN_PART, size)
	local icons = { size = size }
	out.icons = icons
	local health = out.health
	local row = out.nameInside and health or out.name
	local textLeft, textRight = row.left, row.left + row.width
	if not out.portrait and not out.nameInside and o.role then
		icons.role = Rect(gap, gap, size, size)
		local badge = max(MIN_PART, floor(size * BADGE_SHARE))
		icons.leader = Rect(0, 0, badge, badge)
		icons.badge = true
		textLeft = max(textLeft, icons.role.left + size + gap)
	else
		icons.role = Rect(w - gap - size, gap, size, size)
		icons.leader = Rect(out.portrait and 0 or gap, -gap, size, size)
		icons.roleInRing = o.roleRing and out.portrait ~= nil or nil
		if o.leader and not out.portrait then
			textLeft = max(textLeft, icons.leader.left + size + gap)
		end
		if o.role and not icons.roleInRing then
			textRight = min(textRight, icons.role.left - gap)
		end
	end
	textRight = HealsOnName(out, o, textLeft, textRight, (textRight - textLeft) / 2, pad)
	textRight = max(textRight, textLeft + MIN_PART)
	local markedRight = textRight
	if out.nameInside then
		icons.marker = Rect((w - size) / 2, min(-size / 2, pad - size), size, size)
	else
		local nameBottom = out.name.top + out.name.height
		local room = health.top - nameBottom
		if room >= size then
			icons.marker = Rect(Centred(health.width, health.left, size), Centred(room, nameBottom, size), size, size)
		else
			icons.marker = Rect(textRight - size, Centred(out.name.height, out.name.top, size), size, size)
			markedRight = max(textLeft + MIN_PART, textRight - size - gap)
			out.markerInRow = true
		end
	end
	if out.nameInside then
		local centre = health.top + health.height / 2
		if centre < gap + size then
			out.healthText = { center = (textLeft + textRight) / 2, width = textRight - textLeft, top = centre }
		else
			out.healthText = { center = health.left + health.width / 2, top = centre }
		end
	else
		out.name = Rect(textLeft, out.name.top, textRight - textLeft, out.name.height)
		out.healthText = { right = textRight, markedRight = markedRight, top = out.name.top }
	end
end


local function InsideBlock(a, aw, ah, laneGap, px)
	local count = max(0, min(a.count or 0, (a.columns or 1) * (a.rows or 1)))
	if count <= 0 then
		return nil
	end
	local spacing = a.spacing or 0
	local rows = max(1, min(a.rows or 1, count))
	local size = a.size
	while rows >= 1 do
		size = Whole(min(a.size, (ah - (rows - 1) * spacing) / rows), px)
		if size >= MIN_ICON or rows == 1 then
			break
		end
		rows = rows - 1
	end
	if size < MIN_PART then
		return nil
	end
	local columns = min(a.columns or 1, ceil(count / rows))
	while columns > 0 and aw - Line(columns, size, spacing) - laneGap < aw / 2 do
		columns = columns - 1
	end
	if columns <= 0 then
		return nil
	end
	rows = min(rows, ceil(count / columns))
	if rows > 1 and count < columns * rows then
		rows = max(1, floor(count / columns))
	end
	return { columns = columns, rows = rows, cells = columns * rows, size = size, width = Line(columns, size, spacing), height = Line(rows, size, spacing) }
end

local function Lanes(out, area, o, gap, laneGap)
	local aw, ah = area.right - area.left, area.bottom - area.top
	local a = o.aura
	local block = a and AURA_INSIDE_LANES[a.position] and InsideBlock(a, aw, ah, laneGap, o.pixel)
	local barLeft, barRight = area.left, area.right
	if block then
		local x = a.position:find("LEFT$") and area.left or area.right - block.width
		local y = a.position:find("^TOP") and area.top or area.bottom - block.height
		block.left, block.top, block.position = x, y, a.position
		if a.position:find("LEFT$") then
			barLeft = x + block.width + laneGap
		else
			barRight = x - laneGap
		end
		out.block = block
	end
	local barHeight = ah
	if o.healRow then
		local size = Whole(min(o.healRow, (ah - gap) / 2), o.pixel)
		if size >= MIN_ICON and ah - size - gap >= MIN_BAR then
			barHeight = ah - size - gap
			out.healRow = Rect(barLeft, area.top + barHeight + gap, barRight - barLeft, size)
		end
	end
	out.health = Rect(barLeft, area.top, barRight - barLeft, barHeight)
end

function Geometry.Button(w, h, o)
	if o.overlay and o.nameAbove then
		return Overlay(w, h, o)
	end
	local pad, gap = Tokens.Size("gapSmall"), Tokens.Size("gapTiny")
	local out = { nameInside = true }
	local left = pad
	if o.portrait and w - h - 2 * pad >= h then
		out.portrait = Rect(0, 0, h, h)
		left = h + pad
	end
	local width = w - left - pad
	local top, height = pad, h - 2 * pad
	local rest = height
	if o.power then
		local ph = min(o.powerHeight or 0, max(0, height - MIN_PART - gap))
		if ph > 0 then
			out.power = Rect(left, top + height - ph, width, ph)
			rest = height - ph - gap
		end
	end
	local nameHeight = o.nameHeight or 0
	local areaTop, areaHeight = top, rest
	if o.nameAbove and rest - nameHeight - gap >= MIN_PART * 2 then
		out.nameInside = false
		out.name = Rect(left, top, width, nameHeight)
		areaTop, areaHeight = top + nameHeight + gap, rest - nameHeight - gap
	end
	local inside = o.aura and AURA_INSIDE_LANES[o.aura.position]
	local pill = o.pill
	local pilled = not inside and pill and not out.nameInside and areaHeight > pill
	if pilled then
		local rise = o.pillRise or 0
		out.health = Rect(left, areaTop + areaHeight - pill - rise, width, pill)
	elseif inside or (o.healRow and out.nameInside) then
		local bottom = out.power and areaTop + areaHeight or h - gap
		Lanes(out, { left = left, right = left + width, top = areaTop, bottom = bottom }, o, gap, pad)
	else
		out.health = Rect(left, areaTop, width, areaHeight)
	end
	if out.nameInside then
		out.name = out.health
	end
	if o.iconSize then
		Indicators(out, w, h, o, pad, gap)
	elseif not out.nameInside then
		local right = HealsOnName(out, o, out.name.left, out.name.left + out.name.width, out.name.width / 2, pad)
		out.name = Rect(out.name.left, out.name.top, right - out.name.left, out.name.height)
	end
	return out
end

local function OverlayBlock(a, bar, room, px)
	local count = max(0, min(a.count or 0, (a.columns or 1) * (a.rows or 1)))
	if count <= 0 then
		return nil
	end
	local spacing = a.spacing or 0
	local rows = max(1, min(a.rows or 1, count))
	local size = a.size
	while rows >= 1 do
		size = Whole(min(a.size, (room.bottom - room.top - (rows - 1) * spacing) / rows), px)
		if size >= MIN_ICON or rows == 1 then
			break
		end
		rows = rows - 1
	end
	if size < MIN_PART then
		return nil
	end
	local columns = min(a.columns or 1, ceil(count / rows))
	while columns > 0 and Line(columns, size, spacing) > bar.width * BLOCK_SHARE do
		columns = columns - 1
	end
	if columns <= 0 then
		return nil
	end
	rows = min(rows, ceil(count / columns))
	if rows > 1 and count < columns * rows then
		rows = max(1, floor(count / columns))
	end
	local width, height = Line(columns, size, spacing), Line(rows, size, spacing)
	local right = a.position:find("RIGHT$") ~= nil
	local top
	if height <= bar.height then
		top = a.position:find("^TOP") and bar.top or bar.top + bar.height - height
	else
		top = max(room.top, min(bar.top, room.bottom - height))
	end
	return {
		columns = columns, rows = rows, cells = columns * rows, size = size, width = width, height = height,
		left = right and bar.left + bar.width - width or bar.left, top = top, position = a.position, right = right,
	}
end

function Overlay(w, h, o)
	local inset, gap = INSET, Tokens.Size("gapTiny")
	local out = { nameInside = false, overlay = true }
	local left, width = inset, w - 2 * inset
	local top, bottom = BAR_GAP, h - inset
	if o.power then
		local ph = min(o.powerHeight or 0, max(0, bottom - top - MIN_BAR - BAR_GAP))
		if ph > 0 then
			out.power = Rect(left, bottom - ph, width, ph)
			bottom = bottom - ph - BAR_GAP
		end
	end
	local nameHeight = max(MIN_PART, min(o.nameHeight or 0, bottom - top - MIN_BAR - BAR_GAP))
	out.name = Rect(left, top, width, nameHeight)
	local barTop = top + nameHeight + BAR_GAP
	local bar = Rect(left, barTop, width, bottom - barTop)
	out.health = bar
	local a = o.aura
	local block = a and AURA_INSIDE_LANES[a.position] and OverlayBlock(a, bar, { top = barTop - BAR_GAP, bottom = h - BAR_GAP }, o.pixel)
	out.block = block or nil
	local spanLeft, spanRight = bar.left, bar.left + bar.width
	if block then
		if block.right then
			spanRight = block.left - BAR_GAP
		else
			spanLeft = block.left + block.width + BAR_GAP
		end
	end
	if o.boss then
		local size = Whole(min(o.boss, bar.height - 2 * BAR_GAP), o.pixel)
		if size >= MIN_ICON then
			local x = bar.left + (bar.width - size) / 2
			x = max(spanLeft, min(x, spanRight - size))
			out.boss = Rect(x, bar.top + (bar.height - size) / 2, size, size)
		end
	end
	local cornerLeft = not (block and not block.right)
	local size = Whole(max(MIN_PART, min(o.iconSize or 0, (bar.height - BAR_GAP) / 2)), o.pixel)
	local icons = { size = size, badge = true }
	out.icons = icons
	local edge = cornerLeft and bar.left + BAR_GAP or bar.left + bar.width - BAR_GAP - size
	local step = cornerLeft and size + BAR_GAP or -(size + BAR_GAP)
	icons.role = Rect(edge, bar.top + BAR_GAP, size, size)
	local badge = max(MIN_PART, floor(size * BADGE_SHARE))
	icons.leader = Rect(cornerLeft and bar.left or bar.left + bar.width - badge, bar.top, badge, badge)
	icons.marker = Rect(o.role and edge + step or edge, bar.top + BAR_GAP, size, size)
	local line = o.healthLine or size
	local lane = { left = spanLeft + BAR_GAP, right = (out.boss and out.boss.left or spanRight) - INSET }
	if not cornerLeft then
		lane = { left = (out.boss and out.boss.left + out.boss.width or spanLeft) + INSET, right = spanRight - BAR_GAP }
	end
	local laneTop = bar.top + bar.height - line
	if (o.role or o.marker) and laneTop < icons.role.top + size then
		local beyond = icons.role.left + (o.role and o.marker and 2 or 1) * step
		if cornerLeft then
			lane.left = max(lane.left, beyond)
		else
			lane.right = min(lane.right, beyond + size)
		end
	end
	out.healthText = {
		overlay = true, left = lane.left, right = max(lane.left + MIN_PART, lane.right), top = max(bar.top, laneTop), height = line,
		center = bar.left + bar.width / 2, middle = bar.top + bar.height / 2, justify = cornerLeft and "LEFT" or "RIGHT",
	}
	local near = cornerLeft and bar.left or (out.boss and out.boss.left + out.boss.width or spanLeft) + BAR_GAP
	local far = cornerLeft and (out.boss and out.boss.left or spanRight) - BAR_GAP or bar.left + bar.width
	local laneSize = Whole(min(o.laneSize or LEGIBLE, out.healthText.top - BAR_GAP - bar.top, (far - near - (LANE_SLOTS - 1) * BAR_GAP) / LANE_SLOTS), o.pixel)
	if laneSize >= MIN_ICON then
		local span = Line(LANE_SLOTS, laneSize, BAR_GAP)
		out.lane = Rect(cornerLeft and near or far - span, bar.top, span, laneSize)
		out.lane.size, out.lane.count, out.lane.step, out.lane.fromRight = laneSize, LANE_SLOTS, laneSize + BAR_GAP, not cornerLeft
		out.lane.legible = laneSize > LEGIBLE - (o.pixel or 0) - 1e-6
	end
	local nameMin = o.nameMin or nameHeight
	local right = HealsOnName(out, o, left, left + width, NAME_EM * nameMin, gap)
	out.name = Rect(left, top, right - left, nameHeight)
	return out
end

function Geometry.LaneHeight(nameHeight, healthLine, powerHeight)
	return BAR_GAP + nameHeight + BAR_GAP + LEGIBLE + BAR_GAP + healthLine + INSET + (powerHeight and powerHeight > 0 and powerHeight + BAR_GAP or 0)
end

local AURA_INSIDE = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
local AURA_OUTSIDE = { OUTSIDE_RIGHT = "RIGHT", OUTSIDE_LEFT = "LEFT" }
Geometry.AURA_POSITIONS = { "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT", "OUTSIDE_RIGHT", "OUTSIDE_LEFT" }

function Geometry.AuraAnchor(position, growth, wrap, inset, gap)
	growth = growth == "LEFT" and "LEFT" or "RIGHT"
	wrap = wrap == "DOWN" and "DOWN" or "UP"
	local vertical = wrap == "UP" and "BOTTOM" or "TOP"
	local point = vertical .. (growth == "LEFT" and "RIGHT" or "LEFT")
	local side = AURA_OUTSIDE[position]
	if side then
		local x = side == "RIGHT" and gap or -gap
		return point, vertical .. side, x, 0
	end
	if not AURA_INSIDE[position] then
		position = "BOTTOMLEFT"
	end
	local x = position:find("LEFT$") and inset or -inset
	local y = position:find("^TOP") and -inset or inset
	return point, position, x, y
end

function Geometry.AuraPlace(s, lane)
	local side = AURA_OUTSIDE[s.auraPosition]
	if side then
		if lane and lane > 0 then
			return s.auraPosition, true
		end
		return (s.auraWrap == "UP" and "BOTTOM" or "TOP") .. side, false
	end
	if AURA_INSIDE[s.auraPosition] then
		return s.auraPosition, false
	end
	return "BOTTOMLEFT", false
end

function Geometry.AuraBlock(s, w, h, size, spacing, inset, lane)
	local count = max(0, min(s.auraCount or 0, (s.auraColumns or 1) * (s.auraRows or 1)))
	local position = s.auraPosition
	local side = AURA_OUTSIDE[position]
	if side and not (lane and lane > 0) then
		position = (s.auraWrap == "UP" and "BOTTOM" or "TOP") .. side
		side = nil
	elseif not side and not AURA_INSIDE[position] then
		position = "BOTTOMLEFT"
	end
	local width = side and lane or w - 2 * inset
	local height = side and h or h - 2 * inset
	size = max(MIN_PART, min(size, floor(min(width, height))))
	local step = size + spacing
	local fitColumns = step > 0 and floor((width + spacing) / step) or 0
	local fitRows = step > 0 and floor((height + spacing) / step) or 0
	local columns = max(0, min(s.auraColumns or 1, count, fitColumns))
	local rows = 0
	if columns > 0 then
		rows = max(0, min(s.auraRows or 1, ceil(count / columns), fitRows))
		if rows > 1 and count < columns * rows then
			rows = max(1, floor(count / columns))
		end
	end
	local cells = columns * rows
	return { position = position, columns = columns, rows = rows, cells = cells, size = size, width = Line(columns, size, spacing), height = Line(rows, size, spacing) }
end

function Geometry.AuraLine(columns, size, spacing)
	return Line(columns, size, spacing)
end
