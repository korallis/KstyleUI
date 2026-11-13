-- Headers.lua: the secure group headers: one party header and eight raid headers in holder frames, their attributes from the settings, buttons made out of combat and visibility drivers.
local _, ns = ...

local K = KstyleUI
local Geometry, Style = ns.Geometry, ns.Style

local Headers = { raid = {}, holders = {}, cards = {}, built = false }
ns.Headers = Headers

local RAID_GROUPS = 8
local PARTY_BUTTONS = 5
local GROUP_BUTTONS = 5
local RAID_BUTTONS = 40
local TEMPLATE = "SecureGroupHeaderTemplate"
local BUTTON_TEMPLATE = "SecureUnitButtonTemplate"
local ALL_GROUPS = "1,2,3,4,5,6,7,8"
local ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"
local DRIVER_PARTY = "[group:raid] hide; [group] show; hide"
local DRIVER_PARTY_SOLO = "[group:raid] hide; show"
local DRIVER_RAID = "[group:raid] show; hide"
local DRIVER_HIDE = "hide"
local GRID = { "width", "height", "spacing", "groupSpacing" }

local CONFIG = [[
	local header = self:GetParent()
	self:SetWidth(header:GetAttribute("kstyle-width"))
	self:SetHeight(header:GetAttribute("kstyle-height"))
	self:SetAttribute("*type1", "target")
	self:SetAttribute("*type2", "togglemenu")
]]

local kinds = setmetatable({}, { __mode = "k" })

local function Px(kind, units)
	return K.Widgets.Snap(Headers.holders[kind], units)
end

local function OnGrid(kind, s)
	local g = {}
	for key, value in pairs(s) do
		g[key] = value
	end
	for _, key in ipairs(GRID) do
		if s[key] then
			g[key] = Px(kind, s[key])
		end
	end
	return g
end

local function OnHeaderAttribute(header, name, value)
	if type(name) == "string" and name:match("^child%d+$") and type(value) == "table" then
		ns.Button.Adopt(value, kinds[header])
	end
end

local function NewHeader(holder, kind)
	local header = CreateFrame("Frame", nil, holder, TEMPLATE)
	kinds[header] = kind
	header:HookScript("OnAttributeChanged", OnHeaderAttribute)
	header:SetAttribute("template", BUTTON_TEMPLATE)
	header:SetAttribute("templateType", "Button")
	header:SetAttribute("initialConfigFunction", CONFIG)
	return header
end

local function NewCard(parent, holder, shape, title)
	local card = CreateFrame("Frame", nil, parent)
	card:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	card:SetSize(1, 1)
	card:SetFrameLevel(parent:GetFrameLevel())
	return { frame = card, chrome = K.Widgets.Chrome(card, shape), cap = K.Widgets.RailCap(card, { title = title }) }
end

local function ClassOrder()
	if type(CLASS_SORT_ORDER) == "table" and #CLASS_SORT_ORDER > 0 then
		return table.concat(CLASS_SORT_ORDER, ",")
	end
	Style.LogOnce("noClassOrder", "CLASS_SORT_ORDER is missing; raid frames sorted by class keep group order")
	return nil
end

function Headers.Build()
	if Headers.built then
		return
	end
	local root = K.Scale.Root()
	for _, kind in ipairs({ "party", "raid" }) do
		local holder = CreateFrame("Frame", nil, root)
		holder:SetSize(1, 1)
		Headers.holders[kind] = holder
	end
	Headers.party = NewHeader(Headers.holders.party, "party")
	Headers.cards.party = NewCard(Headers.party, Headers.holders.party, { shape = "panel" }, K.L["Party"])
	for g = 1, RAID_GROUPS do
		Headers.raid[g] = NewHeader(Headers.holders.raid, "raid")
	end
	Headers.cards.raid = NewCard(Headers.raid[1], Headers.holders.raid, { shape = "window", fill = "surface" }, K.L["Raid"])
	Headers.built = true
end

local function Driver(header, values)
	if RegisterStateDriver then
		RegisterStateDriver(header, "visibility", values)
	elseif values == DRIVER_HIDE then
		header:Hide()
	else
		Style.LogOnce("noDriver", "RegisterStateDriver is missing; group headers stay shown")
		header:Show()
	end
end

local function Quiet(header)
	if UnregisterStateDriver then
		UnregisterStateDriver(header, "visibility")
	end
	header:Hide()
end

local function Children(header, fn)
	local i = 1
	local child = header:GetAttribute("child1")
	while child do
		fn(child)
		i = i + 1
		child = header:GetAttribute("child" .. i)
	end
end

local function Resize(header, width, height)
	header:SetAttribute("kstyle-width", width)
	header:SetAttribute("kstyle-height", height)
	Children(header, function(child)
		child:SetSize(width, height)
		local f = ns.Button.Content(child)
		if f then
			Style.Apply(f, width, height)
		end
	end)
end

local function Precreate(header, count)
	if header:GetAttribute("child" .. count) then
		return
	end
	local raid, party, solo = header:GetAttribute("showRaid"), header:GetAttribute("showParty"), header:GetAttribute("showSolo")
	header:SetAttribute("showRaid", false)
	header:SetAttribute("showParty", false)
	header:SetAttribute("showSolo", false)
	header:SetAttribute("startingIndex", 1 - count)
	header:Show()
	header:SetAttribute("startingIndex", 1)
	header:Hide()
	header:SetAttribute("showRaid", raid)
	header:SetAttribute("showParty", party)
	header:SetAttribute("showSolo", solo)
end

local function Sort(header, sortBy)
	header:SetAttribute("groupBy", nil)
	header:SetAttribute("groupingOrder", nil)
	header:SetAttribute("sortMethod", sortBy == "NAME" and "NAME" or "INDEX")
	if sortBy == "ROLE" then
		header:SetAttribute("groupBy", "ASSIGNEDROLE")
		header:SetAttribute("groupingOrder", ROLE_ORDER)
	elseif sortBy == "CLASS" then
		local order = ClassOrder()
		if order then
			header:SetAttribute("groupBy", "CLASS")
			header:SetAttribute("groupingOrder", order)
		end
	end
end

local function Columns(header, perColumn, maxColumns, anchor, spacing)
	header:SetAttribute("unitsPerColumn", perColumn)
	header:SetAttribute("maxColumns", maxColumns)
	header:SetAttribute("columnAnchorPoint", anchor)
	header:SetAttribute("columnSpacing", spacing)
end

local function Grow(header, geo, kind)
	header:SetAttribute("point", geo.point)
	header:SetAttribute("xOffset", Px(kind, geo.xOffset))
	header:SetAttribute("yOffset", Px(kind, geo.yOffset))
end

local function Seat(card, s, geo, kind)
	card.settings = s
	card.anchor = geo.corner
	card.frame:SetShown(s.card == true)
	if not s.card then
		return Px(kind, geo.width), Px(kind, geo.height), 0, 0
	end
	local width, height, left, top = Geometry.Card(geo, K.Widgets.SECTION_CAP_HEIGHT)
	width, height, left, top = Px(kind, width), Px(kind, height), Px(kind, left), Px(kind, top)
	local cap = card.cap
	cap.frame:ClearAllPoints()
	cap.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", left, -Px(kind, Geometry.CARD_PAD))
	cap.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -left, -Px(kind, Geometry.CARD_PAD))
	cap:Restyle()
	return width, height, left, top
end

local function Offset(geo, card, left, top, lane, kind)
	if not card.settings.card then
		local x = Px(kind, lane or 0)
		return geo.corner:find("RIGHT", 1, true) and -x or x, 0
	end
	local x, y = Geometry.CardOffset(geo.corner, left, top, lane)
	return Px(kind, x), Px(kind, y)
end

function Headers.ApplyParty(s)
	s = OnGrid("party", s)
	local geo = Geometry.Party(s)
	local holder, header = Headers.holders.party, Headers.party
	local card = Headers.cards.party
	local width, height, left, top = Seat(card, s, geo, "party")
	holder:SetSize(width, height)
	Headers.FitParty(card.members, true)
	geo.left, geo.top = left, top
	Quiet(header)
	header:SetAttribute("showRaid", false)
	header:SetAttribute("showParty", true)
	header:SetAttribute("showPlayer", s.showPlayer)
	header:SetAttribute("showSolo", s.showSolo)
	header:SetAttribute("groupFilter", nil)
	Sort(header, s.sortBy)
	Columns(header, nil, nil, nil, nil)
	Grow(header, geo, "party")
	header:ClearAllPoints()
	local lane = geo.corner:find("RIGHT", 1, true) and geo.laneSide == "RIGHT" or not geo.corner:find("RIGHT", 1, true) and geo.laneSide == "LEFT"
	local x, y = Offset(geo, card, left, top, lane and geo.lane or 0, "party")
	header:SetPoint(geo.corner, holder, geo.corner, x, y)
	Resize(header, Px("party", geo.memberWidth), s.height)
	Precreate(header, PARTY_BUTTONS)
	Driver(header, s.showSolo and DRIVER_PARTY_SOLO or DRIVER_PARTY)
	return geo
end

local function SetCardSize(frame, width, height)
	frame:SetSize(width, height)
end

local function SetCardHeight(frame, height)
	frame:SetHeight(height)
end

local function SetCardWidth(frame, width)
	frame:SetWidth(width)
end

local function Fit(card, holder, width, height, now, vertical)
	local frame = card.frame
	local corner = card.anchor or "TOPLEFT"
	if frame:GetPoint(1) ~= corner then
		frame:ClearAllPoints()
		frame:SetPoint(corner, holder, corner, 0, 0)
	end
	if card.tween then
		K.Motion.Stop(card.tween)
		card.tween = nil
	end
	local from = vertical and frame:GetHeight() or frame:GetWidth()
	local to = vertical and height or width
	if now or type(from) ~= "number" or from <= 1 or from == to then
		SetCardSize(frame, width, height)
		return
	end
	if vertical then
		frame:SetWidth(width)
	else
		frame:SetHeight(height)
	end
	card.tween = K.Motion.Tween(frame, vertical and SetCardHeight or SetCardWidth, from, to, K.Tokens.Duration("panelOpen"), K.Tokens.Easing("panelOpen"))
end

function Headers.FitParty(members, now)
	local card = Headers.cards.party
	local s = card and card.settings
	if not s then
		return
	end
	card.members = members
	local width, height = Geometry.PartyCard(s, K.Widgets.SECTION_CAP_HEIGHT, Geometry.PartyShown(s, members))
	Fit(card, Headers.holders.party, Px("party", width), Px("party", height), now, Geometry.IsVertical(s.growth))
end

function Headers.SetPartyCount(count)
	local card = Headers.cards.party
	if card then
		card.cap:SetAside(count and count > 0 and tostring(count) or nil)
		Headers.FitParty(count)
	end
end

local function RaidShown(s, members, groups)
	if s.sortBy == "GROUP" then
		return Geometry.RaidGroups(s, groups or (members and math.ceil(members / GROUP_BUTTONS)))
	end
	return Geometry.RaidFlow(s, members)
end

function Headers.FitRaid(members, groups, now)
	local card = Headers.cards.raid
	local s = card and card.settings
	if not s then
		return
	end
	card.members, card.groups = members, groups
	local width, height = Geometry.Card(RaidShown(s, members, groups), K.Widgets.SECTION_CAP_HEIGHT)
	Fit(card, Headers.holders.raid, Px("raid", width), Px("raid", height), now, Geometry.IsVertical(s.sortBy == "GROUP" and s.groupGrowth or Geometry.Perpendicular(s.growth, s.groupGrowth)))
end

function Headers.SetRaidCount(count, groups)
	local card = Headers.cards.raid
	if card then
		card.cap:SetAside(count and count > 0 and tostring(count) or nil)
		Headers.FitRaid(count, groups)
	end
end

local function RaidHeader(header, holder, s)
	Quiet(header)
	header:SetAttribute("showRaid", true)
	header:SetAttribute("showParty", false)
	header:SetAttribute("showPlayer", false)
	header:SetAttribute("showSolo", false)
	Resize(header, s.width, s.height)
	header:ClearAllPoints()
	return header, holder
end

function Headers.ApplyRaid(s)
	s = OnGrid("raid", s)
	local holder, card = Headers.holders.raid, Headers.cards.raid
	local geo = s.sortBy == "GROUP" and Geometry.RaidGroups(s) or Geometry.RaidFlow(s)
	local width, height, left, top = Seat(card, s, geo, "raid")
	holder:SetSize(width, height)
	Headers.FitRaid(card.members, card.groups, true)
	geo.left, geo.top = left, top
	local x, y = Offset(geo, card, left, top, nil, "raid")
	if s.sortBy == "GROUP" then
		for g, header in ipairs(Headers.raid) do
			RaidHeader(header, holder, s)
			header:SetAttribute("groupFilter", tostring(g))
			Sort(header, "INDEX")
			Columns(header, nil, nil, nil, nil)
			Grow(header, geo, "raid")
			local slot = geo.slots[g]
			header:SetPoint(geo.corner, holder, geo.corner, slot.x + x, slot.y + y)
			Precreate(header, GROUP_BUTTONS)
			Driver(header, DRIVER_RAID)
		end
		return geo
	end
	for g, header in ipairs(Headers.raid) do
		RaidHeader(header, holder, s)
		if g == 1 then
			header:SetAttribute("groupFilter", ALL_GROUPS)
			Sort(header, s.sortBy)
			Columns(header, geo.unitsPerColumn, geo.maxColumns, geo.columnAnchorPoint, geo.columnSpacing)
			Grow(header, geo, "raid")
			Precreate(header, RAID_BUTTONS)
			Driver(header, DRIVER_RAID)
		else
			Driver(header, DRIVER_HIDE)
		end
		header:SetPoint(geo.corner, holder, geo.corner, x, y)
	end
	return geo
end

function Headers.Stop()
	if not Headers.built then
		return
	end
	Quiet(Headers.party)
	for _, header in ipairs(Headers.raid) do
		Quiet(header)
	end
	for _, holder in pairs(Headers.holders) do
		holder:Hide()
	end
end

function Headers.Show()
	for _, holder in pairs(Headers.holders) do
		holder:Show()
	end
end

function Headers.All(fn)
	if not Headers.built then
		return
	end
	fn(Headers.party)
	for _, header in ipairs(Headers.raid) do
		fn(header)
	end
end
