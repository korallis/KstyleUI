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

function Geometry.Party(s)
	local growth = Clean(s.growth)
	local count = s.showPlayer == false and PARTY_MAX - 1 or PARTY_MAX
	local w, h = Block(growth, count, s.width, s.height, s.spacing)
	local point, x, y = Geometry.Grow(growth, s.spacing)
	return { width = w, height = h, count = count, corner = Geometry.Corner(growth), point = point, xOffset = x, yOffset = y }
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
	local w, h = Block(growth, shown, s.width, s.height, s.spacing)
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

local ICONS_ACROSS = 3

local function Centred(span, start, size)
	return start + (span - size) / 2
end

local function Indicators(out, w, h, o, pad, gap)
	local size = floor(min(o.iconSize, (w - (ICONS_ACROSS + 1) * gap) / ICONS_ACROSS, h - 2 * gap))
	size = max(MIN_PART, size)
	local icons = { size = size }
	out.icons = icons
	local health = out.health
	icons.role = Rect(w - gap - size, gap, size, size)
	icons.leader = Rect(out.portrait and 0 or gap, -gap, size, size)
	local textLeft, textRight = health.left, health.left + health.width
	if o.leader and not out.portrait then
		textLeft = max(textLeft, icons.leader.left + size + gap)
	end
	if o.role then
		textRight = min(textRight, icons.role.left - gap)
	end
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

function Geometry.Button(w, h, o)
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
	if o.nameAbove and rest - nameHeight - gap >= MIN_PART * 2 then
		out.nameInside = false
		out.name = Rect(left, top, width, nameHeight)
		local barTop, barHeight = top + nameHeight + gap, rest - nameHeight - gap
		local pill = o.pill
		if pill and barHeight > pill then
			local rise = o.pillRise or 0
			barTop, barHeight = barTop + barHeight - pill - rise, pill
		end
		out.health = Rect(left, barTop, width, barHeight)
	else
		out.health = Rect(left, top, width, rest)
		out.name = out.health
	end
	if o.iconSize then
		Indicators(out, w, h, o, pad, gap)
	end
	return out
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

function Geometry.AuraLine(columns, size, spacing)
	return Line(columns, size, spacing)
end

local function DebuffsReach(h, health, a)
	local cells = a.debuffColumns * a.debuffRows
	local total = min(a.debuffCount, cells) + min(a.dispelCount, cells)
	if total <= 0 then
		return nil
	end
	local columns = min(a.debuffColumns, total)
	local block = Line(ceil(total / columns), a.debuffSize, a.spacing)
	local top = a.inset
	if a.debuffPosition:find("^BOTTOM") then
		top = h - a.inset - block
	end
	local centre = health.top + health.height / 2
	if top < centre + a.size / 2 and centre - a.size / 2 < top + block then
		return columns
	end
end

function Geometry.HealIcons(w, h, health, a)
	local side, limit = "RIGHT", health.width - 2 * a.inset
	local position = a.debuffPosition
	local columns = a.debuffs and AURA_INSIDE[position] and DebuffsReach(h, health, a)
	if columns then
		local strip = a.inset + Line(columns, a.debuffSize, a.spacing) + a.gap
		if position:find("LEFT$") then
			limit = health.left + health.width - a.inset - strip
		else
			side = "LEFT"
			limit = w - strip - health.left - a.inset
		end
	end
	local count = a.count
	while count > 0 and Line(count, a.size, a.spacing) > limit do
		count = count - 1
	end
	return side, count
end
