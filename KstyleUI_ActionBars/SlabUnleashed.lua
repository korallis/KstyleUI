-- SlabUnleashed.lua: Unleashed (docs/medallions-effects.md#unleashed), the crest taking fire while a major cooldown burns: each cooldown rim container gets two more slots of its own newest aura, one awake and one still, so the crest swaps motion by its own gate alpha in combat; they hold the class's ambient fire as a corona just outside the ring, the rune glyphs blazing in the class colour and turning at one and a half times combat speed, a thin outer ring draining with the aura and, awake, the class burst growing out of the ring as a cooldown is assigned. The player's own cast of a cooldown lifts the emblem, and while auras are readable the corona folds and the glyphs cool as the last one ends. Under Frames the newest-cooldown medal wears the corona and a breathing glow.
local _, ns = ...

local K = KstyleUI
local Tokens, Effects, Widgets = K.Tokens, K.Effects, K.Widgets
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals

local Unleashed = {}
ns.SlabUnleashed = Unleashed

local OWNER = "ActionBars.SlabUnleashed"
local RIM, CORONA, OUTER, ROW_CORONA, ROW_GLOW, EMBERS = 150, 224, 160, 1.9, 3, 8
local FLIP, BREATH, BREATH_LOW, TURN = 0.96, 0.7, 0.85, 90 / (2.25 * 1.5)
local BURST = { 0.7, 1.45, 0.5 }
local LIFT = { { 1, 1.06, 0.12, "OUT" }, { 1.06, 1.03, 0.25, "IN_OUT" }, { 1.03, 1.03, 0.6 }, { 1.03, 1, 0.6, "IN_OUT" } }
local FOLD, FOLD_RUN, COOL_RUN = 1.12, 0.4, 0.6
local sets, state = {}, { ids = {} }
Unleashed.sets, Unleashed.state = sets, state

local function Scale(group, from, to, duration, order, smoothing)
	local a = group:CreateAnimation("Scale")
	a:SetScaleFrom(from, from)
	a:SetScaleTo(to, to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	a:SetSmoothing(smoothing or "NONE")
	return a
end

local function Fade(group, from, to, duration, smoothing)
	ns.Slab.Fade(group, from, to, duration):SetSmoothing(smoothing or "NONE")
	return group
end

local function Sized(piece, parent, level, units)
	local f = CreateFrame("Frame", nil, parent)
	f:SetPoint("CENTER", piece, "CENTER", 0, 0)
	f:SetFrameLevel(level)
	return piece.add(f, units)
end

local function Glyphs(piece, parent, r, g, b)
	local t = piece.add(Medals.Texture(parent, "OVERLAY", 0, "medRuneGlyphs", "white", RIM, "ADD"))
	t:SetVertexColor(r, g, b)
	return t
end

local function Class(spec)
	return (spec.burst or "medBurstWarrior"):gsub("^medBurst", "medAmbient"), K.Theme.ClassColor(ns.class)
end

local function Lights(piece, lit, spec, crest, awake)
	local ambient, r, g, b = Class(spec)
	local level = lit:GetFrameLevel() + 2
	local gate = Medals.Mirror(piece, lit, level)
	local slot = gate.lit
	local fire = Sized(piece, slot, crest and math.max(0, ns.Slab.hub:GetFrameLevel() - 1) or level, crest and CORONA or piece.units * ROW_CORONA)
	local cloud = Medals.Cloud(fire, ambient, 0)
	local embers = Medals.Cloud(fire, ambient, EMBERS)
	local glyphs
	if crest then
		glyphs = Glyphs(piece, slot, r, g, b)
		slot:SetDurationCooldown(piece.add(Medals.Timer(slot, level + 1, "ringLine16", spec.color), OUTER))
	else
		piece.add(Medals.Texture(fire, "BACKGROUND", 0, "glow", "white", piece.units * ROW_GLOW, "ADD")):SetVertexColor(r, g, b, 0.35)
	end
	if awake then
		local breath = fire:CreateAnimationGroup()
		breath:SetLooping("BOUNCE")
		local stretch = FLIP / select(4, Tokens.Flipbook(ambient))
		slot.loops = { Medals.Flip(cloud, ambient, stretch), Medals.Flip(embers, ambient, stretch * 1.5), Fade(breath, 1, BREATH_LOW, BREATH, "IN_OUT") }
		if glyphs then
			local spin = glyphs:CreateAnimationGroup()
			spin:SetLooping("REPEAT")
			local turn = spin:CreateAnimation("Rotation")
			turn:SetDegrees(-360)
			turn:SetDuration(TURN)
			slot.loops[4] = spin
			local flare = piece.add(Medals.Texture(slot, "OVERLAY", 1, spec.burst or "glow", "white", RIM, "ADD"))
			flare:SetAlpha(0)
			flare.play = flare:CreateAnimationGroup()
			Scale(flare.play, BURST[1], BURST[2], BURST[3], 1, "OUT")
			Fade(flare.play, 1, 0, BURST[3], "OUT")
			slot.flare = flare
		end
	end
	return gate
end

local function Fold(piece, spec)
	local ambient, r, g, b = Class(spec)
	local fold = Medals.Cloud(Sized(piece, piece, math.max(0, ns.Slab.hub:GetFrameLevel() - 1), CORONA), ambient, 0)
	fold:SetAlpha(0)
	fold.play = fold:CreateAnimationGroup()
	Scale(fold.play, FOLD, 1, FOLD_RUN, 1, "IN")
	Fade(fold.play, 1, 0, FOLD_RUN, "IN")
	local cool = Glyphs(piece, piece, r, g, b)
	cool:SetAlpha(0)
	cool.play = Fade(cool:CreateAnimationGroup(), 1, 0, COOL_RUN, "IN_OUT")
	return fold, cool
end

function Unleashed.Dress(piece, spec, form)
	local crest = form == "crest"
	for i, lit in ipairs(piece.lits) do
		local set = { piece = piece, crest = crest, awake = Lights(piece, lit, spec, crest, true), still = Lights(piece, lit, spec, crest, false) }
		if crest and i == 1 then
			set.fold, set.cool = Fold(piece, spec)
		end
		sets[#sets + 1] = set
	end
	for _, family in ipairs(spec.families) do
		for _, list in ipairs({ family.spells, family.known or {} }) do
			for _, id in ipairs(list) do
				state.ids[id] = family.unit or "player"
			end
		end
	end
end

local function Readable()
	local get = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	if type(get) ~= "function" or Medals.Restricted() then
		return nil
	end
	for id, unit in pairs(state.ids) do
		local aura = get(unit, id)
		if IsSecret(aura) then
			return nil
		end
		if aura then
			return true
		end
	end
	return false
end

local function Moving(set)
	return Effects.Allows("pulse") and not (set.crest and ns.Slab.Resting())
end

local function Play(region)
	region.play:Stop()
	region.play:Play()
end

local Watch

local function OnEvent(event, _, _, spell)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if IsSecret(spell) or not state.ids[spell] then
			return
		end
		local hub = ns.Slab.hub
		if hub and hub:IsVisible() and Effects.Allows("flare") then
			if not hub.crest.lift then
				hub.crest.lift = hub.crest:CreateAnimationGroup()
				for i, s in ipairs(LIFT) do
					Scale(hub.crest.lift, s[1], s[2], s[3], i, s[4])
				end
			end
			hub.crest.lift:Stop()
			hub.crest.lift:Play()
		end
		state.up = true
		return Watch(true)
	end
	local up = Readable()
	if up == nil then
		return
	end
	if event == "UNIT_AURA" and state.up and not up then
		for _, set in ipairs(sets) do
			if set.fold and set.piece:IsVisible() and Moving(set) then
				Play(set.fold)
				Play(set.cool)
			end
		end
	end
	state.up = up
	Watch(up)
end

function Watch(up)
	if state.watching == up then
		return
	end
	state.watching = up
	local Events = K.Events
	if up then
		Events.RegisterUnit(OWNER, "UNIT_AURA", OnEvent, "player", "pet")
		Events.Register(OWNER, "PLAYER_REGEN_ENABLED", OnEvent)
		Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", OnEvent)
	else
		for _, event in ipairs({ "UNIT_AURA", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
			Events.Unregister(OWNER, event)
		end
	end
end

function Unleashed.Paint()
	local on, crest = ns.Config("crestUnleashed") ~= false, false
	for _, set in ipairs(sets) do
		local moving = Moving(set)
		set.awake:SetShown(on)
		set.still:SetShown(on)
		set.awake:SetAlpha(moving and 1 or 0)
		set.still:SetAlpha(moving and 0 or 1)
		crest = crest or on and set.crest and set.piece:IsVisible()
	end
	if crest ~= state.listening then
		state.listening = crest
		if crest then
			K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_SUCCEEDED", OnEvent, "player")
		else
			K.Events.UnregisterAll(OWNER)
			state.up, state.watching = nil, nil
		end
	end
end

Medals.OnRest(Unleashed.Paint)
