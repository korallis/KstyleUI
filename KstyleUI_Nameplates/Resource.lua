-- Resource.lua: the player's combo points, and optionally energy, on the target's plate, drawn as the unit frames' resource pips.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret

local Resource = {}
ns.Resource = Resource

local OWNER = "Nameplates:resource"
local PIPS, PIP, GAP = 5, 6, 2
local TRACK = "buttonFill"
local SAMPLE_POINTS, SAMPLE_ENERGY = 3, 0.6
local state = { classOK = false, listening = false }

local function PowerType(name, fallback)
	local types = Enum and Enum.PowerType
	return types and types[name] or fallback
end

local function Applies(plate)
	return Settings.Get("resource.show") and (plate.sample ~= nil or state.classOK)
end

local function Height(plate)
	local h = Widgets.Snap(plate, PIP * Settings.Get("resource.scale"))
	if Settings.Get("resource.energy") then
		h = h + GAP + Widgets.Snap(plate, Settings.Get("resource.energyHeight"))
	end
	return h
end

function Resource.Room(plate, side)
	return plate.resource and plate.resource:IsShown() and Settings.Get("resource.place") == side and Height(plate) + GAP or 0
end

local function FillColor()
	if Settings.Get("resource.colorSource") == "custom" then
		local c = Settings.Get("resource.color")
		return c.r, c.g, c.b
	end
	return Theme.Accent()
end

local function EnergyColor()
	local c = PowerBarColor and PowerBarColor.ENERGY
	if type(c) == "table" and type(c.r) == "number" then
		return Theme.Brighten(c.r, c.g, c.b)
	end
	return Tokens.Color("neutral")
end

local function Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()
	frame.pips = {}
	local dot = Tokens.Texture("dot")
	for i = 1, PIPS do
		frame.pips[i] = Widgets.StatusBar(frame, { texture = dot, background = TRACK, min = i - 1, max = i, value = 0 })
	end
	frame.energy = Widgets.UnitBar(frame, { loss = false, spark = false })
	return frame
end

local function Layout(frame, plate)
	local size = Widgets.Snap(plate, PIP * Settings.Get("resource.scale"))
	local spacing = Widgets.Snap(plate, Settings.Get("resource.spacing"))
	local span = PIPS * size + (PIPS - 1) * spacing
	local energy = Settings.Get("resource.energy")
	local eh = energy and Widgets.Snap(plate, Settings.Get("resource.energyHeight")) or 0
	local ew = Widgets.Snap(plate, span * Settings.Get("resource.energyWidth"))
	local above = energy and Settings.Get("resource.energyPlace") == "ABOVE"
	local r, g, b = FillColor()
	for i, pip in ipairs(frame.pips) do
		pip.opts.width, pip.opts.height = size, size
		pip:ClearAllPoints()
		pip:SetPoint("TOP", frame, "TOP", (i - (PIPS + 1) / 2) * (size + spacing), above and -(eh + GAP) or 0)
		pip:Restyle()
		pip:SetBarColor(r, g, b)
	end
	local bar = frame.energy
	bar:SetShown(energy)
	frame.full = nil
	if energy then
		bar.opts.width, bar.opts.height = ew, eh
		bar:ClearAllPoints()
		bar:SetPoint("TOP", frame, "TOP", 0, above and 0 or -(size + GAP))
		bar:Restyle()
		bar:SetBarColor(EnergyColor())
	end
	Widgets.Size(frame, math.max(span, ew), Height(plate))
	frame:ClearAllPoints()
	if Settings.Get("resource.place") == "TOP" then
		local name = Settings.Get("name.show") and not plate.nameOnly and ns.Plate.NAME_GAP + (plate.subtitleRoom or 0) + (plate.whoSize or Settings.Get("name.size")) + ns.Plate.QuestRise(plate) + GAP or GAP
		frame:SetPoint("BOTTOM", plate.health, "TOP", 0, Widgets.Snap(plate, name))
	else
		frame:SetPoint("TOP", plate.health, "BOTTOM", 0, -Widgets.Snap(plate, ns.Cast.Room(plate) + GAP))
	end
end

local function PlayerClass()
	local class = type(UnitClass) == "function" and select(2, UnitClass("player"))
	return not IsSecret(class) and class
end

function Resource.Active()
	local class = PlayerClass()
	if class == "ROGUE" then return true end
	local current = class == "DRUID" and type(UnitPowerType) == "function" and UnitPowerType("player")
	return not IsSecret(current) and current == PowerType("Energy", 3)
end

function Resource.Update(_, _, token)
	local plate = state.plate
	local frame = plate and plate.resource
	if not frame then return end
	if token == nil or token == "COMBO_POINTS" then
		local points
		if type(GetComboPoints) == "function" then
			points = GetComboPoints("player", "target")
		elseif type(UnitPower) == "function" then
			points = UnitPower("player", PowerType("ComboPoints", 4))
		end
		if type(points) ~= "nil" then
			for _, pip in ipairs(frame.pips) do pip:SetBarValue(points) end
		end
	end
	if not ((token == nil or token == "ENERGY") and Settings.Get("resource.energy") and type(UnitPower) == "function" and type(UnitPowerMax) == "function") then return end
	local kind = PowerType("Energy", 3)
	local value, max = UnitPower("player", kind), UnitPowerMax("player", kind)
	local secrets = type(issecretvalue) == "function"
	local full = Settings.Get("resource.energyHideFull") and not ns.state.inCombat and secrets and not issecretvalue(value) and not issecretvalue(max)
		and type(value) == "number" and type(max) == "number" and value >= max
	if full ~= frame.full then
		frame.full = full
		frame.energy:SetShown(not full)
	end
	if not secrets or issecretvalue(max) or max ~= frame.max then
		frame.max = max
		frame.energy:SetBarRange(0, max)
	end
	frame.energy:SetBarValue(value)
end

function Resource.Place(plate, isTarget)
	local on = isTarget and Applies(plate) and not plate.nameOnly and (plate.sample ~= nil or Resource.Active()) or false
	local frame = plate.resource
	if on then
		frame = frame or Build(plate)
		if plate.resource ~= frame or plate.resourceStale or not frame:IsShown() then
			plate.resource, plate.resourceStale = frame, false
			Layout(frame, plate)
		end
		if plate.sample then
			for _, pip in ipairs(frame.pips) do pip:SetBarValue(SAMPLE_POINTS) end
			frame.energy:SetBarRange(0, 1)
			frame.energy:SetBarValue(SAMPLE_ENERGY)
		else
			state.plate = plate
			Resource.Update()
		end
	elseif state.plate == plate then
		state.plate = nil
	end
	if frame and on ~= frame:IsShown() then
		frame:SetShown(on)
		if not plate.sample then ns.Stacking.Bound(plate, plate.rise or 0) end
		ns.Auras.Reanchor(plate)
	end
end

ns.Components[#ns.Components + 1] = { Room = function(plate, anchor) return not anchor and Resource.Room(plate, "BOTTOM") or 0 end, Clear = Resource.Place }

local function Refresh()
	local plate = ns.Plates.highlighted.target
	if state.plate and state.plate ~= plate then Resource.Place(state.plate, false) end
	if plate then Resource.Place(plate, true) end
end

function Resource.Sync()
	local class = PlayerClass()
	state.classOK = class == "ROGUE" or class == "DRUID"
	local listen = ns.Plates.running and Settings.Get("resource.show") and state.classOK or false
	if listen ~= state.listening then
		state.listening = listen
		local Events = K.Events
		if listen then
			Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", Resource.Update, "player")
			Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Resource.Update, "player")
			Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Refresh, "player")
			Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Refresh)
			Events.Register(OWNER, "COMBO_TARGET_CHANGED", Resource.Update)
		else
			Events.UnregisterAll(OWNER)
		end
	end
	if not listen and state.plate then Resource.Place(state.plate, false) end
end
