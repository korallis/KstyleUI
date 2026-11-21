-- Extras.lua: three more groups made only once switched on, each a holder placed in Layout Mode and dressed in the raid's card: your group's pets, the raid's tanks again and friendly bosses.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Style, Unit, Headers, Geometry, Frames = ns.Settings, ns.Style, ns.Unit, ns.Headers, ns.Geometry, ns.Frames

local Extras = { groups = {} }
ns.Extras = Extras

local AT = {
	pets = { key = "groupframes.pets", label = L["Pet frames"], title = L["Pets"], at = { anchor = "TOP", x = 228, y = -324 }, count = 30, per = 10 },
	tanks = { key = "groupframes.tanks", label = L["Tank frames"], title = L["Tanks"], at = { anchor = "TOPRIGHT", x = -254, y = -116 }, count = 8, per = 8 },
	boss = { key = "groupframes.boss", label = L["Friendly boss frames"], title = L["Bosses"], at = { anchor = "LEFT", x = 722, y = -28 }, count = 5 },
}
local ORDER = { "pets", "tanks", "boss" }
local DRIVER = "[group] show; hide"
local CARD = { shape = "window", fill = "surface" }

ns.Button.built[#ns.Button.built + 1] = function(f)
	local button = f:GetParent()
	f.extra = button.kstyleExtra or button:GetParent().kstyleExtra
end

local function Fit(g)
	local first, last
	if g.header then
		first = g.header:GetWidth() > 1 and g.header:GetHeight() > 1 and g.header or nil
		last = first
	else
		for _, button in ipairs(g.buttons) do
			if button:IsShown() then first, last = first or button, button end
		end
		if g.reversed then first, last = last, first end
	end
	local frame = g.card.frame
	frame:SetShown(first ~= nil and Settings.current.raid.card == true)
	if first and g.left then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", first, "TOPLEFT", -g.left, g.top)
		frame:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", g.left, -g.left)
	end
end

local function Bosses(g)
	if not RegisterStateDriver then
		Style.LogOnce("extra:boss", "RegisterStateDriver is missing; friendly boss frames stay off")
		return false
	end
	g.buttons = {}
	K.Events.Register(Settings.MODULE .. ".boss", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", Extras.Engaged)
	local function Refit()
		Fit(g)
	end
	for i = 1, AT.boss.count do
		local button = CreateFrame("Button", nil, g.holder, "SecureUnitButtonTemplate")
		button.kstyleExtra = "boss"
		button:SetAttribute("*type1", "target")
		button:SetAttribute("*type2", "togglemenu")
		button:Hide()
		button:HookScript("OnShow", Refit)
		button:HookScript("OnHide", Refit)
		ns.Button.Adopt(button, "raid")
		g.buttons[i] = button
	end
	return true
end

local function Build(name)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(1, 1)
	local g = { holder = holder }
	if name == "boss" then
		g.failed = not Bosses(g)
	else
		local ok, header = pcall(Headers.New, holder, "raid", name == "pets" and "SecureGroupPetHeaderTemplate" or "SecureGroupHeaderTemplate")
		if ok then
			header.kstyleExtra = name
			g.header = header
		else
			Style.LogOnce("extra:" .. name, "the " .. name .. " header template is missing; " .. name .. " frames stay off")
		end
		g.failed = not ok
	end
	if g.failed then
		holder:Hide()
	else
		g.card = Headers.NewCard(g.header or holder, holder, CARD, AT[name].title)
		if g.header then g.header:HookScript("OnSizeChanged", function() Fit(g) end) end
		Widgets.Place(holder, AT[name].key, AT[name].at, { label = AT[name].label, module = Settings.MODULE, scalable = true })
	end
	Extras.groups[name] = g
	return g
end

local function Live(name, g, on)
	g.holder:SetShown(on)
	if K.Layout and K.Layout.SetLive then K.Layout.SetLive(AT[name].key, on) end
end

local function Size(name)
	local raid, own = Settings.current.raid, Settings.current[name]
	return math.max(40, raid.width + own.width), math.max(16, raid.height + own.height), raid.spacing
end
Extras.Size = Size

local function Seat(g, width, height, corner)
	local geo = { width = width, height = height, corner = corner }
	local w, h, left, top = Headers.Seat(g.card, Settings.current.raid, geo, "raid")
	g.holder:SetSize(w, h)
	g.left, g.top = left, top
	return Headers.Offset(geo, g.card, left, top, nil, "raid")
end

local function Others()
	if type(GetRaidRosterInfo) ~= "function" or type(GetNumGroupMembers) ~= "function" or type(IsInRaid) ~= "function" or IsInRaid() ~= true then return nil end
	local names, me = {}, UnitName("player")
	for i = 1, GetNumGroupMembers() do
		local name, _, _, _, _, _, _, _, _, raidRole, _, role = GetRaidRosterInfo(i)
		if Unit.IsSecret(name) or Unit.IsSecret(raidRole) or Unit.IsSecret(role) or Unit.IsSecret(me) then return nil end
		if type(name) == "string" and name ~= me and (raidRole == "MAINTANK" or role == "TANK") then names[#names + 1] = name end
	end
	return table.concat(names, ",")
end

local function Filter(header, name)
	local names = name == "tanks" and Settings.current.tanks.excludeSelf and Others() or nil
	local roles = name == "tanks" and not names and "MAINTANK,TANK" or nil
	if roles and header:GetAttribute("roleFilter") ~= roles then header:SetAttribute("roleFilter", roles) end
	if header:GetAttribute("nameList") ~= names then header:SetAttribute("nameList", names) end
	if not roles and header:GetAttribute("roleFilter") ~= nil then header:SetAttribute("roleFilter", nil) end
end

function Extras.Roster()
	local g = Extras.groups.tanks
	if not (g and g.on and g.header and Settings.current.tanks.excludeSelf) then return end
	if not InCombatLockdown() then return Filter(g.header, "tanks") end
	if not g.queued then
		g.queued = true
		K.Combat.Queue(function() g.queued = nil; Extras.Roster() end)
	end
end
Frames.events[#Frames.events + 1] = { event = "PLAYER_ROLES_ASSIGNED", fn = Extras.Roster }
local flush = Unit.FlushRoster
function Unit.FlushRoster()
	flush()
	Extras.Roster()
end

local function LayHeader(name, g)
	local header, s, raid = g.header, Settings.current[name], Settings.current.raid
	local width, height, spacing = Size(name)
	local growth = name == "tanks" and s.growth or raid.growth
	local wrap = Geometry.Perpendicular(growth, name == "tanks" and s.wrap or "RIGHT")
	local per = name == "tanks" and s.wrapAfter > 0 and s.wrapAfter or AT[name].per
	local columns = math.ceil(AT[name].count / per)
	Headers.Quiet(header)
	header:SetAttribute("showRaid", true)
	header:SetAttribute("showParty", name == "pets")
	header:SetAttribute("showPlayer", name == "pets")
	Filter(header, name)
	local point, x, y = Geometry.Grow(growth, spacing)
	header:SetAttribute("point", point)
	header:SetAttribute("xOffset", Widgets.Snap(g.holder, x))
	header:SetAttribute("yOffset", Widgets.Snap(g.holder, y))
	header:SetAttribute("unitsPerColumn", per)
	header:SetAttribute("maxColumns", columns)
	header:SetAttribute("columnAnchorPoint", Geometry.ColumnAnchor(wrap))
	header:SetAttribute("columnSpacing", Widgets.Snap(g.holder, spacing))
	local corner = Geometry.Corner(growth, wrap)
	local vertical = Geometry.IsVertical(growth)
	local along, across = Geometry.Line(per, vertical and height or width, spacing), Geometry.Line(columns, vertical and width or height, spacing)
	local ox, oy = Seat(g, vertical and across or along, vertical and along or across, corner)
	header:ClearAllPoints()
	header:SetPoint(corner, g.holder, corner, ox, oy)
	Headers.Resize(header, Widgets.Snap(g.holder, width), Widgets.Snap(g.holder, height))
	Headers.Precreate(header, AT[name].count)
	Headers.Driver(header, DRIVER)
	Fit(g)
end

local function Watch(g, on)
	local group = Settings.current.boss.dungeons and "group" or "group:raid"
	for i, button in ipairs(g.buttons) do
		button:SetAttribute("unit", on and "boss" .. i or nil)
		RegisterStateDriver(button, "visibility", on and ("[@boss%d,help,%s] show; hide"):format(i, group) or "hide")
	end
end

local function LayBosses(g)
	local s = Settings.current.boss
	local width, height, spacing = Size("boss")
	local growth = Settings.current.raid.growth
	local corner = Geometry.Corner(growth)
	local vertical = Geometry.IsVertical(growth)
	local dx, dy = Geometry.Offset(growth, (vertical and height or width) + spacing)
	local ox, oy = Seat(g, vertical and width or Geometry.Line(#g.buttons, width, spacing), vertical and Geometry.Line(#g.buttons, height, spacing) or height, corner)
	g.reversed = growth == "UP" or growth == "LEFT"
	for i, button in ipairs(g.buttons) do
		button:ClearAllPoints()
		button:SetPoint(corner, g.holder, corner, ox + Widgets.Snap(g.holder, dx * (i - 1)), oy + Widgets.Snap(g.holder, dy * (i - 1)))
		button:SetSize(Widgets.Snap(g.holder, width), Widgets.Snap(g.holder, height))
		local f = ns.Button.Content(button)
		if f then Style.Apply(f, button:GetWidth(), button:GetHeight()) end
	end
	Watch(g, s.display == "ALWAYS" or ns.AutoLayout.state.healer == true)
	Fit(g)
end

local function Hush(name, g)
	if g.header then
		Headers.Quiet(g.header)
		Headers.Children(g.header, function(button) button:SetAttribute("unit", nil) end)
	else
		Watch(g, false)
	end
	Live(name, g, false)
end

function Extras.Apply()
	local cfg = Settings.current
	for _, name in ipairs(ORDER) do
		local on = cfg[name].enabled or name == "boss" and cfg.boss.display ~= "NEVER"
		local g = Extras.groups[name] or on and Build(name)
		if g and not g.failed and (on or g.on) then
			if on then
				if g.header then LayHeader(name, g) else LayBosses(g) end
				Live(name, g, true)
			else
				Hush(name, g)
			end
			g.on = on
		end
	end
end

function Extras.Stop()
	for name, g in pairs(Extras.groups) do
		if g.on then Hush(name, g) end
	end
end

function Extras.Engaged()
	local g = Frames.Active() and Extras.groups.boss
	for _, button in ipairs(g and g.buttons or {}) do
		local f = ns.Button.Content(button)
		if f and f.unit and button:IsShown() then Unit.Refresh(f) end
	end
end

local colorSources = Unit.ColorSources
function Unit.ColorSources(f)
	local health, name = colorSources(f)
	if f and f.extra == "boss" and Settings.current.boss.colorSource == "reaction" then health = "reaction" end
	return health, name
end

local nameColored = Unit.NameColored
function Unit.NameColored(f, class)
	nameColored(f, class)
	local pets = Settings.current.pets
	if f.extra == "pets" and not f.status and pets.nameColor ~= "raid" then
		if pets.nameColor == "custom" then
			f.name:SetTextColor(pets.color.r, pets.color.g, pets.color.b)
		else
			f.name:SetTextColor(Tokens.Color("textEmphasis"))
		end
	end
end
