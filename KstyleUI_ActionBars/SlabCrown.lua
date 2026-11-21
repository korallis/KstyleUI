-- SlabCrown.lua: the Medallions crest's crown, one Widgets.ClassPip piece per combo point fanned out of the top of the rune ring (a rogue's daggers, a cat-form druid's claws), dormant until each point ignites one; on while the unit frames' Class resource, Combo points and Class-themed pips settings are on, which they are by default and when Unit Frames is off, and it tells the unit frames whether it shows.
local _, ns = ...

local K = KstyleUI
local Widgets, Effects = K.Widgets, K.Effects
local cos, sin, rad = math.cos, math.sin, math.rad
local IsSecret = Widgets.IsSecret

local Crown = {}
ns.SlabCrown = Crown

local OWNER = "ActionBars.SlabCrown"
local FANS = { { 90 }, { 110, 70 }, { 110, 90, 70 }, { 130, 110, 70, 50 }, { 130, 110, 90, 70, 50 } }
local BASE, LENGTH, ART = 76, 44, 128 / 120
local KEYS = { ["resource.enabled"] = true, ["resource.comboPoints"] = true, ["resource.classPips"] = true }

local state = { pips = {}, built = {} }
Crown.state = state

local function Saved(key)
	local profile = K.Store.IsLoaded() and K.Store.Profile()
	local saved = type(profile) == "table" and profile.UnitFrames
	local resource = type(saved) == "table" and saved.resource
	return not (type(resource) == "table" and resource[key] == false)
end

local function Class()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and Saved("enabled") and Saved("comboPoints") and Saved("classPips") and UnitClass) then
		return nil
	end
	local _, class = UnitClass("player")
	return not IsSecret(class) and Widgets.ClassPipSet(class, 90) and class or nil
end

local function Build(hub, class, count)
	for _, p in ipairs(state.pips) do
		p.frame:Hide()
	end
	state.key = class .. count
	local pips = state.built[state.key]
	if not pips then
		pips = {}
		for i, angle in ipairs(FANS[count]) do
			local p = Widgets.ClassPip(hub.top, Widgets.ClassPipSet(class, angle), i, count)
			local centre = BASE + LENGTH / 2
			p.frame:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, centre * cos(rad(angle))), Widgets.Snap(hub, centre * sin(rad(angle))))
			p:Layout(LENGTH * ART)
			pips[i] = p
		end
		state.built[state.key] = pips
	end
	state.pips = pips
end

local function Points(event)
	if not state.shown then
		return
	end
	local points = GetComboPoints and GetComboPoints("player", "target")
	local was = points
	if state.seen then
		was = state.points
		if event and not IsSecret(points) and not IsSecret(was) and points == was then
			return
		end
	end
	state.points, state.seen = points, true
	local moving = event ~= nil and event ~= "PLAYER_TARGET_CHANGED" and Effects.Allows("flare")
	local idle = Effects.Allows("pulse") and not IsSecret(points) and type(points) == "number" and points >= #state.pips
	for _, p in ipairs(state.pips) do
		p:Set(points, was, moving, idle)
	end
end

local function OnPower(event, _, token)
	if token == "COMBO_POINTS" then
		Points(event)
	end
end

local function Listen(class, kind)
	if class == state.class and kind == state.kind then
		return
	end
	state.class, state.kind = class, kind
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	if class then
		Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Crown.Update, "player")
		Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Crown.Update, "player")
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Crown.Update)
	end
	if kind then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Points)
		Events.Register(OWNER, "COMBO_TARGET_CHANGED", Points)
	end
end

function Crown.Update()
	local class = Class()
	local kind = class and ns.SlabJewels.Kind(class)
	local count = kind and math.min(#FANS, ns.SlabJewels.Count(kind)) or 0
	Listen(class, kind)
	state.shown = count > 0
	if state.shown and state.key ~= class .. count then
		Build(ns.Slab.hub, class, count)
	end
	for _, p in ipairs(state.pips) do
		p.frame:SetShown(state.shown)
	end
	Widgets.SetClassCrown(state.shown)
	Points()
end

function Crown.SetEnabled(on)
	state.enabled = on
	local Callbacks = K.Callbacks
	if on then
		Callbacks.Register("EffectsLevelChanged", OWNER, function() Points() end)
		Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
			if module == "UnitFrames" and KEYS[key] then
				Crown.Update()
			end
		end)
	else
		Callbacks.Unregister("EffectsLevelChanged", OWNER)
		Callbacks.Unregister("SettingChanged", OWNER)
	end
	Crown.Update()
end
