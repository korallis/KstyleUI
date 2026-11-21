-- Extras.lua: three more groups made only once switched on, each a holder placed in Layout Mode: your group's pets, the raid's tanks again and friendly bosses.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Style, Unit, Headers, Geometry, Frames = ns.Settings, ns.Style, ns.Unit, ns.Headers, ns.Geometry, ns.Frames

local Extras = { groups = {} }
ns.Extras = Extras

local AT = {
	pets = { key = "groupframes.pets", label = L["Pet frames"], at = { anchor = "LEFT", x = 360, y = -160 }, count = 10 },
	tanks = { key = "groupframes.tanks", label = L["Tank frames"], at = { anchor = "LEFT", x = 360, y = 160 }, count = 8 },
	boss = { key = "groupframes.boss", label = L["Friendly boss frames"], at = { anchor = "RIGHT", x = -360, y = 160 }, count = 5 },
}
local ORDER = { "pets", "tanks", "boss" }
local DRIVER = "[group] show; hide"
local FRIENDLY = [[
	if name == "state-unitexists" or name == "state-kstylegroup" or name == "kstyle-on" then
		if self:GetAttribute("kstyle-on") and self:GetAttribute("state-kstylegroup") == 1 and self:GetAttribute("state-unitexists") and PlayerCanAssist(self:GetAttribute("unit")) then
			self:Show()
		else
			self:Hide()
		end
	end
]]
local which = setmetatable({}, { __mode = "k" })

ns.Button.built[#ns.Button.built + 1] = function(f)
	local button = f:GetParent()
	f.extra = which[button] or which[button:GetParent()]
end

local function Wanted(name)
	local cfg = Settings.current
	if name == "boss" then return cfg.boss.display ~= "NEVER" end
	return cfg[name].enabled
end

local function Header(holder, name, template)
	local ok, header = pcall(Headers.New, holder, "raid", template)
	if not ok then
		Style.LogOnce("extra:" .. name, "the " .. template .. " template is missing; " .. name .. " frames stay off")
		return nil
	end
	which[header] = name
	return header
end

local function Bosses(g)
	if not (RegisterUnitWatch and SecureHandlerWrapScript and RegisterStateDriver) then
		Style.LogOnce("extra:boss", "the unit watch or secure handlers are missing; friendly boss frames stay off")
		return false
	end
	g.buttons = {}
	K.Events.Register(Settings.MODULE .. ".boss", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", Extras.Engaged)
	for i = 1, AT.boss.count do
		local button = CreateFrame("Button", nil, g.holder, "SecureUnitButtonTemplate")
		which[button] = "boss"
		button:SetAttribute("unit", "boss" .. i)
		button:SetAttribute("*type1", "target")
		button:SetAttribute("*type2", "togglemenu")
		button:Hide()
		SecureHandlerWrapScript(button, "OnAttributeChanged", button, FRIENDLY)
		RegisterUnitWatch(button, true)
		ns.Button.Adopt(button, "raid")
		g.buttons[i] = button
	end
	return true
end

local function Build(name)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(1, 1)
	Widgets.Place(holder, AT[name].key, AT[name].at, { label = AT[name].label, module = Settings.MODULE, scalable = true })
	local g = { holder = holder }
	if name == "boss" then
		if not Bosses(g) then g.failed = true end
	else
		g.header = Header(holder, name, name == "pets" and "SecureGroupPetHeaderTemplate" or "SecureGroupHeaderTemplate")
		g.failed = g.header == nil
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

local function LayHeader(name, g, on)
	local header, s = g.header, Settings.current[name]
	local width, height, spacing = Size(name)
	local growth = name == "tanks" and s.growth or Settings.current.raid.growth
	local wrap = name == "tanks" and Geometry.Perpendicular(growth, s.wrap) or "RIGHT"
	local per = name == "tanks" and s.wrapAfter > 0 and s.wrapAfter or AT[name].count
	local columns = math.ceil(AT[name].count / per)
	Headers.Quiet(header)
	header:SetAttribute("showRaid", true)
	header:SetAttribute("showParty", name == "pets")
	header:SetAttribute("showPlayer", name == "pets")
	header:SetAttribute("roleFilter", name == "tanks" and "MAINTANK,TANK" or nil)
	local point, x, y = Geometry.Grow(growth, spacing)
	header:SetAttribute("point", point)
	header:SetAttribute("xOffset", Widgets.Snap(g.holder, x))
	header:SetAttribute("yOffset", Widgets.Snap(g.holder, y))
	header:SetAttribute("unitsPerColumn", per)
	header:SetAttribute("maxColumns", columns)
	header:SetAttribute("columnAnchorPoint", Geometry.ColumnAnchor(wrap))
	header:SetAttribute("columnSpacing", Widgets.Snap(g.holder, spacing))
	local corner = Geometry.Corner(growth, wrap)
	header:ClearAllPoints()
	header:SetPoint(corner, g.holder, corner, 0, 0)
	local vertical = Geometry.IsVertical(growth)
	local along, across = Geometry.Line(per, vertical and height or width, spacing), Geometry.Line(columns, vertical and width or height, spacing)
	g.holder:SetSize(vertical and across or along, vertical and along or across)
	Headers.Resize(header, Widgets.Snap(g.holder, width), Widgets.Snap(g.holder, height))
	Headers.Precreate(header, AT[name].count)
	Headers.Driver(header, on and DRIVER or "hide")
end

local function LayBosses(g, on)
	local s, healer = Settings.current.boss, ns.AutoLayout.state.healer
	local width, height, spacing = Size("boss")
	local growth = Settings.current.raid.growth
	local point = Geometry.Grow(growth, spacing)
	local vertical = Geometry.IsVertical(growth)
	local step = (vertical and height or width) + spacing
	local dx, dy = Geometry.Offset(growth, step)
	g.holder:SetSize(vertical and width or Geometry.Line(#g.buttons, width, spacing), vertical and Geometry.Line(#g.buttons, height, spacing) or height)
	for i, button in ipairs(g.buttons) do
		button:ClearAllPoints()
		button:SetPoint(point, g.holder, point, Widgets.Snap(g.holder, dx * (i - 1)), Widgets.Snap(g.holder, dy * (i - 1)))
		button:SetSize(Widgets.Snap(g.holder, width), Widgets.Snap(g.holder, height))
		local f = ns.Button.Content(button)
		if f then Style.Apply(f, button:GetWidth(), button:GetHeight()) end
		RegisterStateDriver(button, "kstylegroup", s.dungeons and "[group] 1; 0" or "[group:raid] 1; 0")
		button:SetAttribute("kstyle-on", on and (s.display == "ALWAYS" or healer == true) or false)
	end
end

function Extras.Apply()
	for _, name in ipairs(ORDER) do
		local on = Wanted(name)
		local g = Extras.groups[name] or on and Build(name)
		if g and not g.failed then
			if g.header then LayHeader(name, g, on) else LayBosses(g, on) end
			Live(name, g, on)
		end
	end
end

function Extras.Stop()
	for name, g in pairs(Extras.groups) do
		if not g.failed then
			if g.header then
				Headers.Quiet(g.header)
			else
				for _, button in ipairs(g.buttons) do button:SetAttribute("kstyle-on", false) end
			end
			Live(name, g, false)
		end
	end
end

function Extras.Engaged()
	local g = Frames.Active() and Extras.groups.boss
	for _, button in ipairs(g and g.buttons or {}) do
		local f = ns.Button.Content(button)
		if f and f.unit and button:IsShown() then Unit.Refresh(f) end
	end
end

local applyRaid, stop = Headers.ApplyRaid, Headers.Stop
function Headers.ApplyRaid(...)
	local geo = applyRaid(...)
	Extras.Apply()
	return geo
end
function Headers.Stop()
	stop()
	Extras.Stop()
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
