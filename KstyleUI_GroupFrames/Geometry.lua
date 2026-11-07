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

function Geometry.Party(s)
	local growth = Clean(s.growth)
	local count = s.showPlayer == false and PARTY_MAX - 1 or PARTY_MAX
	local w, h = Block(growth, count, s.width, s.height, s.spacing)
	local point, x, y = Geometry.Grow(growth, s.spacing)
	return { width = w, height = h, count = count, corner = Geometry.Corner(growth), point = point, xOffset = x, yOffset = y }
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
		out.health = Rect(left, top + nameHeight + gap, width, rest - nameHeight - gap)
	else
		out.health = Rect(left, top, width, rest)
		out.name = out.health
	end
	return out
end
