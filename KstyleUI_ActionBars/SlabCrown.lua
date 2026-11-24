-- SlabCrown.lua: the Medallions crest's crown, one piece per point fanned out of the top of the rune ring, dormant until each point ignites one: Widgets.ClassPip pieces fed the combo points (a rogue's daggers, a cat-form druid's claws), or a Widgets.FedCrown the game feeds (a warrior's banners, a priest's candles, a mage's shards, a hunter's arrows, a bear's talons) whose maximum lights the rune ring in the class colour; on while the unit frames' Class resource and Class-themed pips settings are on (Combo points too for the combo pieces), which they are by default and when Unit Frames is off, and while it shows it gives the unit frames a seat just above its tips for the druid bar.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad = math.cos, math.sin, math.rad
local IsSecret = Widgets.IsSecret

local Crown = {}
ns.SlabCrown = Crown

local OWNER = "ActionBars.SlabCrown"
local FANS = { { 90 }, { 110, 70 }, { 110, 90, 70 }, { 130, 110, 70, 50 }, { 130, 110, 90, 70, 50 } }
local ARROWS = { 105, 90, 75 }
local BASE, LENGTH, ART, SEAT = 76, 44, 128 / 120, 8
local RING_HALO = 1.6
local KEYS = { ["resource.enabled"] = true, ["resource.comboPoints"] = true, ["resource.classPips"] = true }

local state = { pips = {}, built = {}, crowns = {} }
Crown.state = state

local function Saved(key)
	local profile = K.Store.IsLoaded() and K.Store.Profile()
	local saved = type(profile) == "table" and profile.UnitFrames
	local resource = type(saved) == "table" and saved.resource
	return not (type(resource) == "table" and resource[key] == false)
end

local function Class()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and Saved("enabled") and Saved("classPips") and UnitClass) then
		return nil
	end
	local _, class = UnitClass("player")
	return not IsSecret(class) and class ~= "PALADIN" and Widgets.ClassPipSet(class, 90) and class or nil
end

local function Place(hub, frame, angle)
	local centre = BASE + LENGTH / 2
	frame:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, centre * cos(rad(angle))), Widgets.Snap(hub, centre * sin(rad(angle))))
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
			Place(hub, p.frame, angle)
			p:Layout(LENGTH * ART)
			pips[i] = p
		end
		state.built[state.key] = pips
	end
	state.pips = pips
end

local function Ring(fed, hub)
	local ring = {}
	for _, part in ipairs({ { "medRuneGlyphs", 1, hub:GetFrameLevel() + 1 }, { "glow", RING_HALO, math.max(0, hub:GetFrameLevel() - 1) } }) do
		local frame = CreateFrame("Frame", nil, fed.max)
		frame:SetFrameLevel(part[3])
		frame:SetAllPoints(hub)
		local t = frame:CreateTexture(nil, "ARTWORK")
		t:SetTexture((Tokens.Texture(part[1])))
		t:SetBlendMode("ADD")
		t:SetPoint("CENTER", hub, "CENTER", 0, 0)
		Widgets.Size(t, ns.Slab.RING * part[2], ns.Slab.RING * part[2])
		ring[#ring + 1] = t
	end
	return ring
end

local function Fed(hub, kind)
	local fed = state.crowns[kind]
	if fed == nil and Widgets.CrownOpen() then
		local angles = kind == "HUNTER" and ARROWS or FANS[Widgets.CrownCount(kind)]
		fed = Widgets.FedCrown(hub.top, kind, angles, LENGTH * ART, Effects.Allows("flare")) or false
		if fed then
			for i, p in ipairs(fed.pips) do
				Place(hub, p.frame, angles[i])
			end
			fed.ring = Ring(fed, hub)
			fed:SetShown(false)
		end
		state.crowns[kind] = fed
	end
	return fed or nil
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

local function Listen(class, combo, pending)
	if class == state.class and combo == state.combo and pending == state.pending then
		return
	end
	state.class, state.combo, state.pending = class, combo, pending
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	if class and not Widgets.CrownCount(class) then
		Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Crown.Update, "player")
		Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Crown.Update, "player")
		Events.Register(OWNER, "UPDATE_SHAPESHIFT_FORM", Crown.Update)
	end
	if pending then
		Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Crown.Update)
	end
	if combo then
		Events.RegisterUnit(OWNER, "UNIT_POWER_FREQUENT", OnPower, "player")
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Points)
		Events.Register(OWNER, "COMBO_TARGET_CHANGED", Points)
	end
end

function Crown.Update(event)
	local class = Class()
	local kind = class and Widgets.CrownKind(class)
	local combo = kind and not Widgets.CrownCount(kind) and Saved("comboPoints")
	local count = combo and math.min(#FANS, ns.SlabJewels.Count("combo")) or 0
	if event == "UPDATE_SHAPESHIFT_FORM" and class == state.class and kind == state.kind and count == state.count and not state.pending then
		return
	end
	state.kind, state.count = kind, count
	local hub = ns.Slab.hub
	local want = kind and Widgets.CrownCount(kind) and kind or class == "DRUID" and "BEAR" or nil
	local built = want and Fed(hub, want)
	local fed = kind == want and built or nil
	local key, was = state.key, state.shown
	state.shown = count > 0
	if state.shown and state.key ~= class .. count then
		Build(hub, class, count)
	end
	if state.key ~= key or state.shown ~= was then
		for _, p in ipairs(state.pips) do
			p.frame:SetShown(state.shown)
		end
	end
	local moving, pending = Effects.Allows("flare"), want ~= nil and state.crowns[want] == nil
	for name, c in pairs(state.crowns) do
		if c then
			local on = c == fed
			c:SetShown(on)
			c:Listen(OWNER .. ":" .. name, on)
			pending = not c:SetMotion(moving) or pending
			if on and not Widgets.CrownOpen() then
				pending = true
			elseif on then
				local r, g, b = K.Theme.ClassColor(name == "BEAR" and "DRUID" or name)
				for _, t in ipairs(c.ring) do
					t:SetVertexColor(r, g, b)
				end
			end
		end
	end
	Listen(class, count > 0, pending)
	state.crown = fed
	local seated = state.shown or state.crown ~= nil
	if seated and not state.line then
		state.line = CreateFrame("Frame", nil, hub.top)
		state.line:SetSize(1, 1)
		state.line:SetPoint("CENTER", hub, "CENTER", 0, Widgets.Snap(hub, BASE + LENGTH + SEAT))
	end
	Widgets.SetClassCrown(seated and state.line or nil)
	if state.key ~= key or not was then
		Points()
	end
end

function Crown.SetEnabled(on)
	state.enabled = on
	local Callbacks = K.Callbacks
	if on then
		Callbacks.Register("EffectsLevelChanged", OWNER, function()
			Crown.Update()
			Points()
		end)
		Callbacks.Register("ThemeChanged", OWNER, Crown.Update)
		Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
			if module == "UnitFrames" and KEYS[key] then
				Crown.Update()
			end
		end)
	else
		Callbacks.Unregister("EffectsLevelChanged", OWNER)
		Callbacks.Unregister("ThemeChanged", OWNER)
		Callbacks.Unregister("SettingChanged", OWNER)
	end
	Crown.Update()
end
