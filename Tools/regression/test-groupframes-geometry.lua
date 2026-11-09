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

-- The status icons keep out of the texts: the role icon at the top right and the leader on the top-left corner
-- (over the portrait's corner when there is one); with the name above the bar, the marker sits inside the frame,
-- in the room between the name row and the bar when it fits there, else in the name row before the role icon, and
-- the row's text ends before it while it shows (markedRight), so it never sits on the edge between two frames or on
-- the bar where the debuffs and your heals go; with the name on the bar, the marker centres on the top edge,
-- ending at the name row.
-- A name row ends before the role icon, and a health text on the bar narrows to the span between the icons only
-- when its line reaches up into the band.
do
	local icons = { iconSize = 14, role = true, leader = true, marker = true }
	local b = Geo.Button(230, 46, { portrait = true, power = true, powerHeight = 4, nameAbove = true, nameHeight = 13, iconSize = 14, role = true, leader = true, marker = true })
	eq(b.icons.size, 14, "the party icons keep their size")
	rect(b.icons.role, 214, 2, 14, 14, "party role icon")
	rect(b.icons.leader, 0, -2, 14, 14, "party leader icon over the portrait corner")
	rect(b.icons.marker, 198, 3.5, 14, 14, "party marker in the name row, before the role icon")
	eq(b.healthText.markedRight, 196, "a marked row's text ends a gap before the marker")
	rect(b.name, 50, 4, 162, 13, "the party name row ends a gap before the role icon")
	eq(b.healthText.right, 212, "the party health text ends with the name row")
	eq(b.healthText.top, 4, "on the name row")

	b = Geo.Button(230, 46, { portrait = true, power = true, powerHeight = 4, nameAbove = true, nameHeight = 13, iconSize = 14, role = false, leader = true, marker = true })
	rect(b.name, 50, 4, 176, 13, "with role icons off the name row keeps the bar's width")
	eq(b.healthText.right, 226, "and the health text ends at the bar")

	b = Geo.Button(120, 46, { portrait = false, power = false, nameAbove = true, nameHeight = 13, iconSize = 14, role = true, leader = true, marker = true })
	rect(b.icons.leader, 2, -2, 14, 14, "without a portrait the leader icon sits on the top left corner, a gap in")
	rect(b.name, 18, 4, 84, 13, "and the name row runs from it to the role icon")
	rect(b.icons.marker, 88, 3.5, 14, 14, "the marker in the name row, off the bar")

	b = Geo.Button(278, 40, { portrait = true, power = false, nameAbove = true, nameHeight = 13, iconSize = 14, role = true, leader = true, marker = true, pill = 6, pillRise = 2 })
	rect(b.health, 44, 28, 230, 6, "a pill row draws the bar as a 6-unit pill two units off the row's foot")
	rect(b.icons.marker, 246, 3.5, 14, 14, "the marker sits in the name row, wholly inside the 40-unit row")

	b = Geo.Button(278, 46, { portrait = true, power = false, nameAbove = true, nameHeight = 13, iconSize = 14, role = true, leader = true, marker = true, pill = 6, pillRise = 2 })
	rect(b.icons.marker, 155, 18.5, 14, 14, "a taller row has room for the marker between the name and the pill")
	eq(b.healthText.markedRight, b.healthText.right, "so the row's text keeps its length")

	b = Geo.Button(77, 40, { portrait = false, power = false, nameAbove = true, nameHeight = 12, iconSize = 12, role = true, leader = true, marker = true })
	eq(b.nameInside, false, "a 77 by 40 raid tile puts the name above the bar")
	rect(b.name, 16, 4, 45, 12, "the raid name row runs from the leader icon to the role icon")
	rect(b.health, 4, 18, 69, 18, "and the bar fills the rest, clear of the name")
	eq(b.healthText.right, 61, "the missing health ends the name row, before the role icon")
	rect(b.icons.marker, 49, 4, 12, 12, "a raid marker sits in the name row, off the bar")
	eq(b.healthText.markedRight, 47, "and the missing health moves before it")

	b = Geo.Button(72, 40, { portrait = false, power = false, nameAbove = false, nameHeight = 12, iconSize = 12, role = true, leader = true, marker = true })
	rect(b.icons.role, 58, 2, 12, 12, "raid role icon")
	rect(b.icons.marker, 30, -8, 12, 12, "raid marker ends at the bar's top")
	eq(b.healthText.center, 36, "the raid health text centres on the bar")
	eq(b.healthText.width, nil, "at its natural width, since its line sits below the icons")
	eq(b.healthText.top, 20, "from the bar's middle")

	b = Geo.Button(40, 16, { portrait = false, power = false, nameAbove = false, nameHeight = 12, iconSize = 12, role = true, leader = true, marker = true })
	eq(b.icons.size, 10, "three icons fit across a 40-unit frame at 10 units")
	rect(b.icons.role, 28, 2, 10, 10, "small raid role icon")
	rect(b.icons.leader, 2, -2, 10, 10, "small raid leader icon")
	rect(b.icons.marker, 15, -6, 10, 10, "small raid marker")
	eq(b.healthText.width, 12, "a health text that reaches the icon band narrows to the span between the icons")
	eq(b.healthText.center, 20, "centred between them")

	b = Geo.Button(40, 16, { portrait = true, power = true, powerHeight = 4, nameAbove = true, nameHeight = 13, iconSize = 14, role = true, leader = true, marker = true })
	rect(b.portrait, 0, 0, 16, 16, "a 40 by 16 party frame keeps its portrait")
	eq(b.nameInside, true, "and puts the name on the bar")
	eq(b.healthText.width, 6, "the health text fits between the bar's left and the role icon")
	eq(b.healthText.center, 23, "centred in that span")
	assert(icons.iconSize == 14, "the shared options were not changed")
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

-- The party card holds only the rows the party shows: you and up to four others, at least one row, the whole
-- five when the count is unknown.
do
	local s = { width = 278, height = 40, spacing = 8, growth = "DOWN", showPlayer = true, showSolo = false }
	eq(Geo.PartyShown(s, 3), 3, "a party of three shows three rows")
	eq(Geo.PartyShown(s, 9), 5, "never more than five")
	eq(Geo.PartyShown(s, nil), 5, "an unknown count keeps the whole card")
	eq(Geo.PartyShown(s, 0), 1, "solo keeps one row, the card never folds to nothing")
	s.showSolo = true
	eq(Geo.PartyShown(s, 0), 1, "shown solo, one row for you")
	s.showPlayer, s.showSolo = false, false
	eq(Geo.PartyShown(s, 3), 2, "without yourself, a party of three shows the two others")
	eq(Geo.PartyShown(s, nil), 4, "and at most four")
	s.showPlayer = true
	local w3, h3 = Geo.PartyCard(s, 20, 3)
	local w5, h5 = Geo.PartyCard(s, 20, 5)
	eq(w3, 318, "the card keeps the rail width")
	eq(w5, 318, "at any count")
	eq(h5 - h3, 2 * (40 + 8), "two fewer rows is two rows and their gaps shorter")
	eq(h3, 3 * 40 + 2 * 8 + 20 + 20 + 8 + 20, "three rows, the padding, the cap and its gap")
	s.growth = "RIGHT"
	local wide3, tall3 = Geo.PartyCard(s, 20, 3)
	eq(wide3, 3 * 278 + 2 * 8 + 40, "growing sideways, the card narrows instead")
	eq(tall3, 40 + 20 + 20 + 8 + 20, "and keeps one row's height")
end

-- Your heals go to the bar's end away from the debuffs, and only as many as fit beside the debuff strip.
do
	local raid = { left = 4, top = 18, width = 64, height = 18 }
	local a = { inset = 2, gap = 4, size = 10, spacing = 1, count = 3, debuffs = true, debuffPosition = "BOTTOMLEFT", debuffSize = 12, debuffColumns = 2, debuffRows = 1, debuffCount = 2, dispelCount = 1 }
	local side, count = Geo.HealIcons(72, 40, raid, a)
	eq(side, "RIGHT", "debuffs at the bottom left put your heals at the bar's right end")
	eq(count, 3, "three 10-unit heals fit beside two 12-unit debuff columns on a 72-unit tile")
	a.debuffColumns = 3
	count = select(2, Geo.HealIcons(72, 40, raid, a))
	eq(count, 2, "beside three debuff columns only two fit")
	local strip = 2 + 3 * 12 + 2 + 4
	assert(raid.left + raid.width - 2 - Geo.AuraLine(count, 10, 1) >= strip, "and the two end before the debuff strip")
	a.debuffPosition = "BOTTOMRIGHT"
	side = Geo.HealIcons(72, 40, raid, a)
	eq(side, "LEFT", "debuffs at the bottom right put your heals at the bar's left end")
	a.debuffPosition, a.debuffColumns = "OUTSIDE_RIGHT", 3
	side, count = Geo.HealIcons(72, 40, raid, a)
	eq(side, "RIGHT", "debuffs outside the frame leave the bar to your heals")
	eq(count, 3, "all three")
	a.debuffPosition, a.debuffs = "BOTTOMLEFT", false
	count = select(2, Geo.HealIcons(72, 40, raid, a))
	eq(count, 3, "with debuffs off, nothing is reserved")
	a.debuffs, a.count, a.size = true, 6, 24
	count = select(2, Geo.HealIcons(72, 40, raid, a))
	eq(count, 0, "icons too big to fit beside the strip show none rather than cover it")
	a.count, a.size = 3, 10
	a.debuffPosition, a.debuffColumns, a.debuffCount, a.dispelCount = "TOPRIGHT", 2, 2, 0
	side, count = Geo.HealIcons(72, 40, raid, a)
	eq(side, "RIGHT", "one row of debuffs at the top right stays in the name band")
	eq(count, 3, "so it leaves your heals alone")
	a.debuffRows, a.debuffCount = 2, 4
	side, count = Geo.HealIcons(72, 40, raid, a)
	eq(side, "LEFT", "two rows of top-right debuffs reach the heal row, so your heals go to the left end")
	assert(count >= 1 and raid.left + 2 + Geo.AuraLine(count, 10, 1) <= 72 - (2 + Geo.AuraLine(2, 12, 1) + 4), "and end before the debuff columns")
end

print("groupframes geometry ok")
