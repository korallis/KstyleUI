-- test-groupframes-geometry.lua: the group frames' layout maths: header attributes per growth, the party and raid holder sizes, raid group slots, flow columns, and the parts inside one frame.
local G = dofile("Tools/regression/group_env.lua")

local _, _, ns = G.New({ boot = false })
local Geo = ns.Geometry
assert(type(Geo) == "table", "KstyleUI_GroupFrames must expose ns.Geometry")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function rect(got, left, top, width, height, what)
	assert(type(got) == "table", what .. ": expected a rect, got " .. type(got))
	eq(got.left, left, what .. ".left")
	eq(got.top, top, what .. ".top")
	eq(got.width, width, what .. ".width")
	eq(got.height, height, what .. ".height")
end

-- Header attributes per growth: the anchor point of the first frame and the offsets between frames.
do
	local point, x, y = Geo.Grow("DOWN", 10)
	eq(point, "TOP", "DOWN point")
	eq(x, 0, "DOWN x")
	eq(y, -10, "DOWN y")
	point, _, y = Geo.Grow("UP", 10)
	eq(point, "BOTTOM", "UP point")
	eq(y, 10, "UP y")
	point, x, y = Geo.Grow("RIGHT", 3)
	eq(point, "LEFT", "RIGHT point")
	eq(x, 3, "RIGHT x")
	eq(y, 0, "RIGHT y")
	point, x = Geo.Grow("LEFT", 3)
	eq(point, "RIGHT", "LEFT point")
	eq(x, -3, "LEFT x")
	point, _, y = Geo.Grow("SIDEWAYS", 4)
	eq(point, "TOP", "an unknown growth falls back to DOWN")
	eq(y, -4, "an unknown growth falls back to DOWN offsets")

	eq(Geo.ColumnAnchor("RIGHT"), "LEFT", "columns growing right anchor their left")
	eq(Geo.ColumnAnchor("LEFT"), "RIGHT", "columns growing left anchor their right")
	eq(Geo.ColumnAnchor("DOWN"), "TOP", "columns growing down anchor their top")
	eq(Geo.ColumnAnchor("UP"), "BOTTOM", "columns growing up anchor their bottom")

	eq(Geo.Corner("DOWN", "RIGHT"), "TOPLEFT", "down and right start top left")
	eq(Geo.Corner("UP", "RIGHT"), "BOTTOMLEFT", "up starts at the bottom")
	eq(Geo.Corner("DOWN", "LEFT"), "TOPRIGHT", "left starts at the right")
	eq(Geo.Corner("LEFT", nil), "TOPRIGHT", "a party growing left starts top right")
	eq(Geo.Corner("RIGHT", "UP"), "BOTTOMLEFT", "groups growing up start at the bottom")

	eq(Geo.Wrap("DOWN", "RIGHT"), "DOWN", "a row of groups wraps the way members grow")
	eq(Geo.Wrap("RIGHT", "DOWN"), "RIGHT", "a column of groups wraps the way members grow")
	eq(Geo.Wrap("DOWN", "DOWN"), "RIGHT", "groups in line with members wrap to the right")
	eq(Geo.Wrap("LEFT", "RIGHT"), "DOWN", "groups in line horizontally wrap downward")

	eq(Geo.Perpendicular("DOWN", "RIGHT"), "RIGHT", "a perpendicular column growth is kept")
	eq(Geo.Perpendicular("DOWN", "DOWN"), "RIGHT", "a parallel column growth turns right")
	eq(Geo.Perpendicular("RIGHT", "LEFT"), "DOWN", "a parallel horizontal column growth turns down")
end

-- Party: five 46-unit frames with 10-unit gaps fill the 230 x 270 footprint from element-keys.md.
do
	local p = Geo.Party({ width = 230, height = 46, spacing = 10, growth = "DOWN", showPlayer = true })
	eq(p.width, 230, "party width")
	eq(p.height, 270, "party height")
	eq(p.count, 5, "party with the player holds five")
	eq(p.corner, "TOPLEFT", "party corner")
	eq(p.point, "TOP", "party point")
	eq(p.xOffset, 0, "party xOffset")
	eq(p.yOffset, -10, "party yOffset")

	p = Geo.Party({ width = 230, height = 46, spacing = 10, growth = "RIGHT", showPlayer = false })
	eq(p.count, 4, "party without the player holds four")
	eq(p.width, 950, "a party growing right is four frames wide")
	eq(p.height, 46, "a party growing right is one frame tall")
	eq(p.point, "LEFT", "party right point")
	eq(p.xOffset, 10, "party right xOffset")

	p = Geo.Party({ width = 100, height = 20, spacing = 2, growth = "UP", showPlayer = true })
	eq(p.corner, "BOTTOMLEFT", "a party growing up starts at the bottom")
	eq(p.height, 108, "five 20-unit frames with 2-unit gaps")
end

-- Raid by group: eight groups of five 72 x 40 frames with 3-unit gaps fill the 597 x 212 footprint.
do
	local s = { width = 72, height = 40, spacing = 3, growth = "DOWN", groupGrowth = "RIGHT", groupSpacing = 3, groupsPerRow = 8 }
	local r = Geo.RaidGroups(s)
	eq(r.width, 597, "raid width")
	eq(r.height, 212, "raid height")
	eq(r.corner, "TOPLEFT", "raid corner")
	eq(r.point, "TOP", "raid point")
	eq(r.yOffset, -3, "raid yOffset")
	eq(#r.slots, 8, "eight group slots")
	eq(r.slots[1].x, 0, "group 1 x")
	eq(r.slots[1].y, 0, "group 1 y")
	eq(r.slots[2].x, 75, "group 2 sits one frame and one gap to the right")
	eq(r.slots[8].x, 525, "group 8 x")
	eq(r.slots[8].y, 0, "group 8 y")

	s.groupsPerRow = 4
	r = Geo.RaidGroups(s)
	eq(r.width, 297, "four groups per row")
	eq(r.height, 427, "two rows of groups")
	eq(r.slots[5].x, 0, "group 5 starts the second row")
	eq(r.slots[5].y, -215, "group 5 sits one group and one gap lower")

	r = Geo.RaidGroups({ width = 72, height = 40, spacing = 3, growth = "RIGHT", groupGrowth = "DOWN", groupSpacing = 3, groupsPerRow = 8 })
	eq(r.width, 372, "a group growing right is five frames wide")
	eq(r.height, 341, "eight groups stack downward")
	eq(r.slots[2].x, 0, "group 2 x when groups stack")
	eq(r.slots[2].y, -43, "group 2 y when groups stack")

	r = Geo.RaidGroups({ width = 72, height = 40, spacing = 3, growth = "UP", groupGrowth = "RIGHT", groupSpacing = 3, groupsPerRow = 8 })
	eq(r.corner, "BOTTOMLEFT", "members growing up start at the bottom")
	eq(r.point, "BOTTOM", "members growing up anchor their bottom")
	eq(r.slots[2].x, 75, "groups still go right")

	r = Geo.RaidGroups({ width = 72, height = 40, spacing = 3, growth = "DOWN", groupGrowth = "LEFT", groupSpacing = 3, groupsPerRow = 8 })
	eq(r.corner, "TOPRIGHT", "groups growing left start at the right")
	eq(r.slots[2].x, -75, "group 2 sits to the left")

	r = Geo.RaidGroups({ width = 72, height = 40, spacing = 3, growth = "DOWN", groupGrowth = "DOWN", groupSpacing = 3, groupsPerRow = 4 })
	eq(r.slots[2].y, -215, "groups in line with members chain downward")
	eq(r.slots[5].x, 75, "and wrap to the right")
	eq(r.width, 147, "two columns of groups")
	eq(r.height, 857, "four groups tall")

	r = Geo.RaidGroups({ width = 72, height = 40, spacing = 3, growth = "DOWN", groupGrowth = "RIGHT", groupSpacing = 3, groupsPerRow = 99 })
	eq(r.width, 597, "groups per row clamps to 8")
end

-- Raid by role or class: one header in columns.
do
	local s = { width = 72, height = 40, spacing = 3, growth = "DOWN", groupGrowth = "RIGHT", groupSpacing = 3, unitsPerColumn = 5 }
	local f = Geo.RaidFlow(s)
	eq(f.width, 597, "flow width")
	eq(f.height, 212, "flow height")
	eq(f.point, "TOP", "flow point")
	eq(f.columnAnchorPoint, "LEFT", "flow columns go right")
	eq(f.columnSpacing, 3, "flow column spacing")
	eq(f.unitsPerColumn, 5, "five per column")
	eq(f.maxColumns, 8, "eight columns hold forty")
	eq(f.corner, "TOPLEFT", "flow corner")

	s.unitsPerColumn = 10
	f = Geo.RaidFlow(s)
	eq(f.maxColumns, 4, "ten per column needs four columns")
	eq(f.width, 297, "four columns wide")
	eq(f.height, 427, "ten frames tall")

	s.unitsPerColumn = 5
	s.groupGrowth = "DOWN"
	f = Geo.RaidFlow(s)
	eq(f.columnAnchorPoint, "LEFT", "columns in line with members turn right")
	eq(f.width, 597, "turned columns keep the footprint")
end

-- The parts inside one frame, as { left, top, width, height } from its top left corner.
do
	local b = Geo.Button(230, 46, { portrait = true, power = true, powerHeight = 4, nameAbove = true, nameHeight = 13 })
	rect(b.portrait, 0, 0, 46, 46, "party portrait")
	rect(b.name, 50, 4, 176, 13, "party name row")
	rect(b.health, 50, 19, 176, 17, "party health bar")
	rect(b.power, 50, 38, 176, 4, "party power bar")
	eq(b.nameInside, false, "the party name sits above the bar")

	b = Geo.Button(72, 40, { portrait = false, power = false, nameAbove = false, nameHeight = 12 })
	eq(b.portrait, nil, "no portrait")
	eq(b.power, nil, "no power bar")
	rect(b.health, 4, 4, 64, 32, "raid health bar fills the frame")
	eq(b.nameInside, true, "the raid name sits on the bar")

	b = Geo.Button(100, 20, { portrait = false, power = true, powerHeight = 4, nameAbove = true, nameHeight = 13 })
	eq(b.nameInside, true, "a frame too short for a name row puts the name on the bar")
	rect(b.health, 4, 4, 92, 6, "the bar takes what the power bar leaves")

	b = Geo.Button(40, 120, { portrait = true, power = false, nameAbove = false, nameHeight = 12 })
	eq(b.portrait, nil, "a frame narrower than a portrait and a bar drops the portrait")
	rect(b.health, 4, 4, 32, 112, "the bar keeps the whole frame")

	b = Geo.Button(10, 6, { portrait = true, power = true, powerHeight = 4, nameAbove = false, nameHeight = 12 })
	assert(b.health.width >= 1 and b.health.height >= 1, "a tiny frame still has a bar of at least one unit")
end

-- Debuff icons: where the container sits and which way it fills.
do
	local point, rel, x, y = Geo.AuraAnchor("BOTTOMLEFT", "RIGHT", "UP", 2, 3)
	eq(point, "BOTTOMLEFT", "inside bottom left, growing right and up, anchors bottom left")
	eq(rel, "BOTTOMLEFT", "to the frame's bottom left")
	eq(x, 2, "inset right")
	eq(y, 2, "inset up")
	point, rel, x, y = Geo.AuraAnchor("TOPRIGHT", "LEFT", "DOWN", 2, 3)
	eq(point, "TOPRIGHT", "inside top right, growing left and down")
	eq(rel, "TOPRIGHT", "to the frame's top right")
	eq(x, -2, "inset left")
	eq(y, -2, "inset down")
	point, rel, x, y = Geo.AuraAnchor("OUTSIDE_RIGHT", "RIGHT", "DOWN", 2, 3)
	eq(point, "TOPLEFT", "outside right, growing right and down, anchors top left")
	eq(rel, "TOPRIGHT", "to the frame's top right")
	eq(x, 3, "one gap out")
	eq(y, 0, "level with the top")
	point, rel, x = Geo.AuraAnchor("OUTSIDE_LEFT", "LEFT", "UP", 2, 3)
	eq(point, "BOTTOMRIGHT", "outside left, growing left and up, anchors bottom right")
	eq(rel, "BOTTOMLEFT", "to the frame's bottom left")
	eq(x, -3, "one gap out to the left")
	point = Geo.AuraAnchor("NOWHERE", "UP", "SIDEWAYS", 2, 3)
	eq(point, "BOTTOMLEFT", "unknown values fall back to bottom left, right, up")
	eq(Geo.AuraLine(3, 20, 2), 64, "a line of three 20-unit icons with 2-unit gaps")
end

print("groupframes geometry ok")
