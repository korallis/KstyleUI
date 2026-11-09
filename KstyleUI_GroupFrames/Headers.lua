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

local CONFIG = [[
	local header = self:GetParent()
	self:SetWidth(header:GetAttribute("kstyle-width"))
	self:SetHeight(header:GetAttribute("kstyle-height"))
	self:SetAttribute("*type1", "target")
	self:SetAttribute("*type2", "togglemenu")
]]

local kinds = setmetatable({}, { __mode = "k" })

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
	local party = Headers.holders.party
	local card = CreateFrame("Frame", nil, Headers.party)
	card:SetPoint("TOPLEFT", party, "TOPLEFT", 0, 0)
	card:SetSize(1, 1)
	card:SetFrameLevel(Headers.party:GetFrameLevel())
	Headers.cards.party = {
		frame = card,
		chrome = K.Widgets.Chrome(card, { shape = "panel" }),
		cap = K.Widgets.RailCap(card, { title = K.L["Party"] }),
	}
	for g = 1, RAID_GROUPS do
		Headers.raid[g] = NewHeader(Headers.holders.raid, "raid")
	end
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

local function Grow(header, geo)
	header:SetAttribute("point", geo.point)
	header:SetAttribute("xOffset", geo.xOffset)
	header:SetAttribute("yOffset", geo.yOffset)
end

function Headers.ApplyParty(s)
	local geo = Geometry.Party(s)
	local holder, header = Headers.holders.party, Headers.party
	local card = Headers.cards.party
	local width, height, left, top = Geometry.Card(geo, K.Widgets.SECTION_CAP_HEIGHT)
	holder:SetSize(width, height)
	local cap = card.cap
	cap.frame:ClearAllPoints()
	cap.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", left, -Geometry.CARD_PAD)
	cap.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -left, -Geometry.CARD_PAD)
	cap:Restyle()
	card.settings = s
	card.anchor = geo.corner
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
	Grow(header, geo)
	header:ClearAllPoints()
	local x, y = left + (geo.laneSide == "LEFT" and geo.lane or 0), -top
	if geo.corner:find("RIGHT", 1, true) then
		x = -(left + (geo.laneSide == "RIGHT" and geo.lane or 0))
	end
	if geo.corner:find("BOTTOM", 1, true) then
		y = Geometry.CARD_PAD
	end
	header:SetPoint(geo.corner, holder, geo.corner, x, y)
	Resize(header, geo.memberWidth, s.height)
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

function Headers.FitParty(members, now)
	local card = Headers.cards.party
	local s = card and card.settings
	if not s then
		return
	end
	card.members = members
	local frame, holder = card.frame, Headers.holders.party
	local width, height = Geometry.PartyCard(s, K.Widgets.SECTION_CAP_HEIGHT, Geometry.PartyShown(s, members))
	local corner = card.anchor or "TOPLEFT"
	if frame:GetPoint(1) ~= corner then
		frame:ClearAllPoints()
		frame:SetPoint(corner, holder, corner, 0, 0)
	end
	if card.tween then
		K.Motion.Stop(card.tween)
		card.tween = nil
	end
	local vertical = Geometry.IsVertical(s.growth)
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

function Headers.SetPartyCount(count)
	local card = Headers.cards.party
	if card then
		card.cap:SetAside(count and count > 0 and tostring(count) or nil)
		Headers.FitParty(count)
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
	local holder = Headers.holders.raid
	if s.sortBy == "GROUP" then
		local geo = Geometry.RaidGroups(s)
		holder:SetSize(geo.width, geo.height)
		for g, header in ipairs(Headers.raid) do
			RaidHeader(header, holder, s)
			header:SetAttribute("groupFilter", tostring(g))
			Sort(header, "INDEX")
			Columns(header, nil, nil, nil, nil)
			Grow(header, geo)
			local slot = geo.slots[g]
			header:SetPoint(geo.corner, holder, geo.corner, slot.x, slot.y)
			Precreate(header, GROUP_BUTTONS)
			Driver(header, DRIVER_RAID)
		end
		return geo
	end
	local geo = Geometry.RaidFlow(s)
	holder:SetSize(geo.width, geo.height)
	for g, header in ipairs(Headers.raid) do
		RaidHeader(header, holder, s)
		if g == 1 then
			header:SetAttribute("groupFilter", ALL_GROUPS)
			Sort(header, s.sortBy)
			Columns(header, geo.unitsPerColumn, geo.maxColumns, geo.columnAnchorPoint, geo.columnSpacing)
			Grow(header, geo)
			header:SetPoint(geo.corner, holder, geo.corner, 0, 0)
			Precreate(header, RAID_BUTTONS)
			Driver(header, DRIVER_RAID)
		else
			header:SetPoint(geo.corner, holder, geo.corner, 0, 0)
			Driver(header, DRIVER_HIDE)
		end
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
