-- SlabCrown.lua: the Medallions crest's crown of blades for a rogue, five Widgets.ClassPip daggers fanned out of the top of the rune ring, ghost steel until each combo point ignites one; on while the unit frames' Class-themed pips setting is on, which it is by default and when Unit Frames is off.
local _, ns = ...

local K = KstyleUI
local Widgets, Effects = K.Widgets, K.Effects
local cos, sin, rad = math.cos, math.sin, math.rad
local IsSecret = Widgets.IsSecret

local Crown = {}
ns.SlabCrown = Crown

local OWNER = "ActionBars.SlabCrown"
local ANGLES = { 130, 110, 90, 70, 50 }
local BASE, LENGTH, ART = 76, 44, 128 / 120

local state = { pips = {} }
Crown.state = state

local function On()
	local profile = K.Store.IsLoaded() and K.Store.Profile()
	local saved = type(profile) == "table" and profile.UnitFrames
	local resource = type(saved) == "table" and saved.resource
	return not (type(resource) == "table" and resource.classPips == false)
end

local function Hub()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and On() and UnitClass) then
		return nil
	end
	local _, class = UnitClass("player")
	return not IsSecret(class) and class == "ROGUE" and hub or nil
end

local function Set(angle)
	return {
		lit = "pipBlade" .. angle, steel = "pipBladeSteel" .. angle, shape = "pipBladeShape" .. angle, glow = "pipBladeGlow" .. angle,
		glowColor = "pipRogueGlow", coreColor = "pipRogueCore", axis = angle,
	}
end

local function Place(hub)
	local centre = BASE + LENGTH / 2
	for i, angle in ipairs(ANGLES) do
		local p = state.pips[i] or Widgets.ClassPip(hub.top, Set(angle), i, #ANGLES)
		state.pips[i] = p
		p.frame:ClearAllPoints()
		p.frame:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, centre * cos(rad(angle))), Widgets.Snap(hub, centre * sin(rad(angle))))
		p:Layout(LENGTH * ART)
		p.frame:Show()
	end
end

local function Points(event)
	if not state.shown then
		return
	end
	local points = GetComboPoints and GetComboPoints("player", "target")
	local was = state.seen and state.points or points
	state.points, state.seen = points, true
	local moving = event ~= nil and event ~= "PLAYER_TARGET_CHANGED" and Effects.Allows("flare")
	local idle = Effects.Allows("pulse") and not IsSecret(points) and type(points) == "number" and points >= #ANGLES
	for _, p in ipairs(state.pips) do
		p:Set(points, was, moving, idle)
	end
end

local function OnPower(event, _, token)
	if token == "COMBO_POINTS" then
		Points(event)
	end
end

local function Listen(on)
	if on == state.shown then
		return
	end
	state.shown = on
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	if on then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Points)
		Events.Register(OWNER, "COMBO_TARGET_CHANGED", Points)
	end
end

function Crown.Update()
	local hub = Hub()
	Listen(hub ~= nil)
	if hub then
		Place(hub)
		Points()
	else
		for _, p in ipairs(state.pips) do
			p.frame:Hide()
		end
	end
end

function Crown.SetEnabled(on)
	state.enabled = on
	local Callbacks = K.Callbacks
	if on then
		Callbacks.Register("EffectsLevelChanged", OWNER, function() Points() end)
		Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
			if module == "UnitFrames" and key == "resource.classPips" then
				Crown.Update()
			end
		end)
	else
		Callbacks.Unregister("EffectsLevelChanged", OWNER)
		Callbacks.Unregister("SettingChanged", OWNER)
	end
	Crown.Update()
end
