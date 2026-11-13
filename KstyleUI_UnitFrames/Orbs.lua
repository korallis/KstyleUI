-- Orbs.lua: the Orbs HUD style: health and resource orbs either side of action bar 1, each a vertical status bar under a round mask that the engine eases, a pale band for health just lost, the value in the number face.
local _, ns = ...

local K = KstyleUI
local Settings, Unit, Format = ns.Settings, ns.Unit, ns.Format

local Orbs = {}
ns.Orbs = Orbs

local MODULE = Settings.MODULE
local OWNER = MODULE .. ":orbs"
local BAR_KEY = "actionbars.bar1"
local RING = K.Setup.Layouts.ORBS_RING
local HOLE = RING * 0.701
local REACH = K.Setup.Layouts.ORBS_REACH
local LIFT = K.Setup.Layouts.ORBS_LIFT
local FLOOR = 2
local SURFACE_HEIGHT = 14
local SURFACE_ALPHA = 0.8
local VALUE_SIZE = 17
local VALUE_DROP = 0.22
local VALUE_FLAGS = "OUTLINE"
local HEALTH_FORMAT, POWER_FORMAT = "currentMax", "percent"
local STRATA = "LOW"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local LEVEL_LOSS, LEVEL_FILL, LEVEL_GLASS = 1, 2, 3
local KINDS = { "health", "power" }
local NEEDED = { "SetOrientation", "SetStatusBarTexture", "GetStatusBarTexture", "SetMinMaxValues", "SetValue" }

local orbs = {}
local running, active, built, available = false, false, false, nil

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function Texture(name)
	return (K.Tokens.Texture(name))
end

local function Ease()
	if K.Motion.Level() == "off" then
		return nil
	end
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.ExponentialEaseOut
end

local function SetBarValue(bar, value, eased)
	local interpolation = eased and Ease()
	if interpolation then
		bar:SetValue(value, interpolation)
	else
		bar:SetValue(value)
	end
end

local function Supports(bar)
	for _, method in ipairs(NEEDED) do
		if type(bar[method]) ~= "function" then
			return false, method
		end
	end
	return true
end

local function NewBar(orb, level)
	local bar = CreateFrame("StatusBar", nil, orb)
	bar:SetFrameLevel(orb:GetFrameLevel() + level)
	bar:SetPoint("CENTER", orb, "CENTER", 0, 0)
	local ok, missing = Supports(bar)
	if not ok then
		return nil, missing
	end
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture(Texture("orbLiquid"))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local fill = bar:GetStatusBarTexture()
	if type(bar.CreateMaskTexture) == "function" and type(fill.AddMaskTexture) == "function" then
		bar.mask = bar:CreateMaskTexture()
		bar.mask:SetTexture(Texture("orbMask"), MASK_WRAP, MASK_WRAP)
		bar.mask:SetAllPoints(bar)
		fill:AddMaskTexture(bar.mask)
	else
		Log("mask textures are missing; the orbs fill as squares")
	end
	return bar
end

local function NewOrb(kind)
	local orb = CreateFrame("Frame", nil, K.Scale.Root())
	orb:SetFrameStrata(STRATA)
	orb:Hide()
	orb.kind = kind
	orb.back = orb:CreateTexture(nil, "BACKGROUND")
	orb.back:SetTexture(Texture("orbBack"))
	orb.back:SetPoint("CENTER", orb, "CENTER", 0, 0)
	local bar, missing = NewBar(orb, LEVEL_FILL)
	if not bar then
		return nil, missing
	end
	orb.bar = bar
	if kind == "health" then
		orb.loss, missing = NewBar(orb, LEVEL_LOSS)
		if not orb.loss then
			return nil, missing
		end
	end
	local surface = orb.bar:CreateTexture(nil, "OVERLAY")
	surface:SetTexture(Texture("orbSurface"))
	surface:SetPoint("CENTER", orb.bar:GetStatusBarTexture(), "TOP", 0, 0)
	if orb.bar.mask then
		surface:AddMaskTexture(orb.bar.mask)
	end
	orb.surface = surface
	local top = CreateFrame("Frame", nil, orb)
	top:SetAllPoints(orb)
	top:SetFrameLevel(orb:GetFrameLevel() + LEVEL_GLASS)
	orb.glass = top:CreateTexture(nil, "ARTWORK")
	orb.glass:SetTexture(Texture("orbGlass"))
	orb.glass:SetPoint("CENTER", orb, "CENTER", 0, 0)
	orb.ring = top:CreateTexture(nil, "OVERLAY", nil, 1)
	orb.ring:SetTexture(Texture("orbRing"))
	orb.ring:SetAllPoints(orb)
	orb.value = K.Widgets.FontString(top, "OVERLAY")
	orb.value:SetJustifyH("CENTER")
	orb.value:SetJustifyV("MIDDLE")
	orb.value:SetWordWrap(false)
	return orb
end

local function Build()
	built = true
	for _, kind in ipairs(KINDS) do
		local orb, missing = NewOrb(kind)
		if not orb then
			available = false
			Log("StatusBar:" .. tostring(missing) .. " is missing; the Orbs HUD style is not available and the player frame stays")
			return
		end
		orbs[kind] = orb
	end
	available = true
	Log("built the health and resource orbs")
end

local function BarRect()
	local Layout = K.Layout
	if Layout and Layout.Live and Layout.Rect and Layout.Live(BAR_KEY) then
		local left, bottom, width, height = Layout.Rect(BAR_KEY)
		if left then
			return left, bottom, width, height
		end
	end
	local Layouts = K.Setup.Layouts
	local grid = Layouts.Grid(BAR_KEY)
	local columns = math.ceil(grid.buttons / grid.rows)
	local width = columns * grid.size + (columns - 1) * grid.spacing
	local height = grid.rows * grid.size + (grid.rows - 1) * grid.spacing
	local style = K.HudStyle.Current()
	local styled = Layouts.Style(style, Layout.Setting("preset"), BAR_KEY)
	local position = styled or Layouts.Default(BAR_KEY)
	local key = styled and style .. ":" .. BAR_KEY or BAR_KEY
	local saved = K.Store.Layout()[key]
	if type(saved) == "table" and type(saved.anchor) == "string" and type(saved.x) == "number" and type(saved.y) == "number" then
		position = saved
	end
	local rootWidth, rootHeight = Layout.RootSize()
	local left, bottom = Layouts.Rect({ width = width, height = height }, position, rootWidth, rootHeight)
	return left, bottom, width, height
end

function Orbs.Centres()
	local left, bottom, width, height = BarRect()
	local rootWidth, rootHeight = K.Layout.RootSize()
	local low = RING / 2 + FLOOR
	local y = math.min(math.max(bottom + height / 2 + LIFT, low), rootHeight - low)
	return math.max(left - REACH, low), math.min(left + width + REACH, rootWidth - low), y
end

local function Place()
	local Snap = K.Widgets.Snap
	local healthX, powerX, y = Orbs.Centres()
	local centres = { health = healthX, power = powerX }
	for kind, orb in pairs(orbs) do
		orb:ClearAllPoints()
		orb:SetPoint("CENTER", K.Scale.Root(), "BOTTOMLEFT", Snap(orb, centres[kind]), Snap(orb, y))
		K.Widgets.Size(orb, RING, RING)
		K.Widgets.Size(orb.back, HOLE, HOLE)
		K.Widgets.Size(orb.glass, HOLE, HOLE)
		K.Widgets.Size(orb.bar, HOLE, HOLE)
		if orb.loss then
			K.Widgets.Size(orb.loss, HOLE, HOLE)
		end
		K.Widgets.Size(orb.surface, HOLE, SURFACE_HEIGHT)
		orb.value:ClearAllPoints()
		orb.value:SetPoint("CENTER", orb, "CENTER", 0, -Snap(orb, HOLE * VALUE_DROP))
	end
end

local function Restyle()
	local Tokens, Widgets = K.Tokens, K.Widgets
	local path = Tokens.Font("number")
	local size = VALUE_SIZE * K.Theme.FontScale()
	for _, orb in pairs(orbs) do
		if not Widgets.ApplyFont(orb.value, path, size, VALUE_FLAGS) then
			Widgets.ApplyFont(orb.value, (Tokens.Font("body")), size, VALUE_FLAGS)
		end
		orb.value:SetTextColor(Tokens.Color("textEmphasis"))
		orb.surface:SetVertexColor(Widgets.Rgba("white", SURFACE_ALPHA))
	end
	local health = orbs.health
	health.bar:SetStatusBarColor(Tokens.Color("orbHealth"))
	health.loss:SetStatusBarColor(Tokens.Color("orbLoss"))
end

local function PowerColor()
	orbs.power.bar:SetStatusBarColor(Unit.PowerTypeColor("player", true))
end

local function Health(eased)
	local orb = orbs.health
	local max, value = UnitHealthMax("player"), UnitHealth("player")
	orb.bar:SetMinMaxValues(0, max)
	orb.bar:SetValue(value)
	orb.loss:SetMinMaxValues(0, max)
	SetBarValue(orb.loss, value, eased)
	Format.Health(orb.value, "player", HEALTH_FORMAT)
end

local function Power(eased)
	local orb = orbs.power
	orb.bar:SetMinMaxValues(0, UnitPowerMax("player"))
	SetBarValue(orb.bar, UnitPower("player"), eased)
	Format.Power(orb.value, "player", POWER_FORMAT)
end

local function Refresh()
	PowerColor()
	Health(false)
	Power(false)
end

local HANDLERS = {
	UNIT_HEALTH = function()
		Health(true)
	end,
	UNIT_MAXHEALTH = function()
		Health(true)
	end,
	UNIT_POWER_UPDATE = function()
		Power(true)
	end,
	UNIT_MAXPOWER = function()
		Power(true)
	end,
	UNIT_DISPLAYPOWER = function()
		PowerColor()
		Power(false)
	end,
}

local function OnLayoutChanged(_, key)
	if active and (key == nil or key == BAR_KEY) then
		Place()
	end
end

local function OnTheme()
	if active then
		Restyle()
		Place()
	end
end

local function Listen()
	local Events, Callbacks = K.Events, K.Callbacks
	for event, handler in pairs(HANDLERS) do
		Events.RegisterUnit(OWNER, event, handler, "player")
	end
	Events.Register(OWNER, "PLAYER_ENTERING_WORLD", function()
		Place()
		Refresh()
	end)
	Callbacks.Register("LayoutChanged", OWNER, OnLayoutChanged)
	Callbacks.Register("ThemeChanged", OWNER, OnTheme)
	Callbacks.Register("ScaleChanged", OWNER, OnTheme)
end

local function Quiet()
	K.Events.UnregisterAll(OWNER)
	K.Callbacks.UnregisterAll(OWNER)
end

function Orbs.Wanted()
	return running and K.HudStyle.Current() == "orbs" and available ~= false
end

function Orbs.Apply()
	local want = Orbs.Wanted()
	if want and not built then
		Build()
		want = available == true
	end
	if want == active then
		if want then
			Place()
			Restyle()
			Refresh()
		end
		return
	end
	active = want
	if want then
		Listen()
		Place()
		Restyle()
		Refresh()
	else
		Quiet()
	end
	for _, orb in pairs(orbs) do
		orb:SetShown(want)
	end
end

function Orbs.Active()
	return active
end

function Orbs.Get(kind)
	return orbs[kind]
end

function Orbs.Enable()
	running = true
	Orbs.Apply()
end

function Orbs.Disable()
	running = false
	Orbs.Apply()
end
