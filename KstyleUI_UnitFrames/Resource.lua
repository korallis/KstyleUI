-- Resource.lua: the class resource element under the player frame: combo points as one-point status bars, and the druid's mana bar.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings, Style = ns.Settings, ns.Style

local Resource = {}
ns.Resource = Resource

local KEY = "unitframes.resource"
local OWNER = "UnitFrames:resource"
local PIPS = 5
local MANA_SHARE = 0.35
local MANA_MIN, MANA_MAX = 3, 6
local GAP = 2
local LIMITS = { minWidth = 40, minHeight = 4, maxWidth = 400, maxHeight = 48 }
local POWER_MANA, POWER_ENERGY, POWER_COMBO = 0, 3, 4

local state = { built = false, running = false, showCombo = false, showMana = false }
Resource.state = state
Resource.KEY = KEY

local function PowerTypes()
	local types = Enum and Enum.PowerType
	if types then
		return types.Mana or POWER_MANA, types.Energy or POWER_ENERGY, types.ComboPoints or POWER_COMBO
	end
	return POWER_MANA, POWER_ENERGY, POWER_COMBO
end

local function PlayerClass()
	local _, file = UnitClass("player")
	if issecretvalue and issecretvalue(file) then
		return nil
	end
	return file
end

local function Build()
	local element = K.Setup.Layouts.Element(KEY)
	local position = K.Setup.Layouts.Default(KEY)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(element.width, element.height)
	holder:SetPoint(position.anchor, K.Scale.Root(), position.anchor, position.x, position.y)
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	local dot = Tokens.Texture("dot")
	local pips = {}
	for i = 1, PIPS do
		local pip = Widgets.StatusBar(content, { texture = dot })
		pip:SetBarRange(i - 1, i)
		pip:SetBarValue(0)
		pips[i] = pip
	end
	local mana = Widgets.StatusBar(content, { smooth = true })
	state.holder, state.content, state.pips, state.mana = holder, content, pips, mana
	holder:HookScript("OnSizeChanged", function()
		Resource.Layout()
	end)
	state.built = true
	if K.Layout and K.Layout.Register then
		K.Layout.Register(holder, KEY, position, {
			label = element.label,
			module = Settings.MODULE,
			resizable = true,
			minWidth = LIMITS.minWidth,
			minHeight = LIMITS.minHeight,
			maxWidth = LIMITS.maxWidth,
			maxHeight = LIMITS.maxHeight,
		})
	end
end

local function Size()
	local w, h = state.holder:GetSize()
	if (issecretvalue and (issecretvalue(w) or issecretvalue(h))) or type(w) ~= "number" or type(h) ~= "number" then
		return nil
	end
	return w, h
end

local function Snap(units)
	return Widgets.Snap(state.holder, units)
end

local function Place(bar, x, y, w, h)
	bar.opts.width, bar.opts.height = w, h
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", state.content, "TOPLEFT", Snap(x), -Snap(y))
	bar:Restyle()
end

function Resource.Layout()
	if not state.built then
		return
	end
	local w, h = Size()
	if not w then
		return
	end
	local max, min = math.max, math.min
	local manaH = 0
	if state.showMana and state.showCombo then
		manaH = min(max(MANA_MIN, min(MANA_MAX, h * MANA_SHARE)), max(0, (h - GAP) / 2))
	elseif state.showMana then
		manaH = min(h, MANA_MAX)
	end
	local pipRow = state.showCombo and (state.showMana and max(0, h - manaH - GAP) or h) or 0
	if state.showCombo then
		local spacing = min(Settings.Resource("spacing"), max(0, (w - PIPS) / (PIPS - 1)))
		local size = max(0, min(pipRow, (w - spacing * (PIPS - 1)) / PIPS))
		local span = size * PIPS + spacing * (PIPS - 1)
		local x = (w - span) / 2
		for i, pip in ipairs(state.pips) do
			Place(pip, x + (i - 1) * (size + spacing), (pipRow - size) / 2, size, size)
			pip:Show()
		end
	else
		for _, pip in ipairs(state.pips) do
			pip:Hide()
		end
	end
	if state.showMana then
		Place(state.mana, 0, state.showCombo and pipRow + GAP or (h - manaH) / 2, w, manaH)
		state.mana:Show()
	else
		state.mana:Hide()
	end
end

local function ComboColor()
	if Settings.Resource("comboColor") == "custom" then
		local c = Settings.Resource("comboCustom")
		return c.r, c.g, c.b
	end
	return Theme.Accent()
end

local function ManaColor()
	local source = Settings.Resource("manaColor")
	if source == "custom" then
		local c = Settings.Resource("manaCustom")
		return c.r, c.g, c.b
	elseif source == "class" then
		return Theme.Accent()
	end
	local c = PowerBarColor and PowerBarColor.MANA
	if type(c) == "table" and type(c.r) == "number" then
		return Theme.Brighten(c.r, c.g, c.b)
	end
	return Tokens.Color("rare")
end

function Resource.Restyle()
	if not state.built then
		return
	end
	local r, g, b = ComboColor()
	local texture = Tokens.Texture("dot")
	for _, pip in ipairs(state.pips) do
		pip:SetBarTexture(texture)
		pip:SetBarColor(r, g, b)
	end
	state.mana:SetBarTexture(Settings.Resource("manaTexture"))
	state.mana:SetBarColor(ManaColor())
	local o = Style.ORIENTATION[Settings.Resource("manaOrientation")] or Style.ORIENTATION.RIGHT
	state.mana:SetOrientation(o[1])
	state.mana:SetReverseFill(o[2])
	Resource.Visibility()
end

function Resource.Points()
	if not state.showCombo then
		return
	end
	local _, _, combo = PowerTypes()
	local points
	if GetComboPoints then
		points = GetComboPoints("player", "target")
	else
		points = UnitPower("player", combo)
	end
	for _, pip in ipairs(state.pips) do
		pip:SetBarValue(points)
	end
end

function Resource.Mana()
	if not state.showMana then
		return
	end
	local mana = PowerTypes()
	state.mana:SetBarRange(0, UnitPowerMax("player", mana))
	state.mana:SetBarValue(UnitPower("player", mana))
end

function Resource.Visibility()
	local class = PlayerClass()
	local mana, energy = PowerTypes()
	local current = UnitPowerType("player")
	if issecretvalue and issecretvalue(current) then
		current = nil
	end
	local on = state.running and Settings.Resource("enabled")
	state.showCombo = on and Settings.Resource("comboPoints") and (class == "ROGUE" or class == "DRUID" and current == energy) or false
	state.showMana = on and Settings.Resource("druidMana") and class == "DRUID" and current ~= nil and current ~= mana or false
	state.content:SetShown(state.showCombo or state.showMana)
	Resource.ListenToPower(state.running and (state.showCombo or state.showMana))
	Resource.Layout()
	Resource.Points()
	Resource.Mana()
end

local function OnPower(_, _, token)
	if token == "COMBO_POINTS" then
		Resource.Points()
	elseif token == "MANA" then
		Resource.Mana()
	end
end

function Resource.ListenToPower(on)
	on = on and true or false
	if on == state.listening then
		return
	end
	state.listening = on
	local Events = K.Events
	if on then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
		Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", OnPower, "player")
	else
		Events.Unregister(OWNER, "UNIT_POWER_FREQUENT")
		Events.Unregister(OWNER, "UNIT_MAXPOWER")
	end
end

function Resource.Enable()
	if not state.built then
		Build()
	end
	state.running = true
	if state.hiddenByModule then
		state.hiddenByModule = false
		state.holder:Show()
	end
	local Events = K.Events
	Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Resource.Visibility, "player")
	Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Resource.Visibility)
	Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Resource.Points)
	Events.Register(OWNER, "COMBO_TARGET_CHANGED", Resource.Points)
	Resource.Restyle()
end

function Resource.Disable()
	state.running = false
	state.listening = false
	K.Events.UnregisterAll(OWNER)
	if state.built then
		state.content:Hide()
		state.holder:Hide()
		state.hiddenByModule = true
	end
end
