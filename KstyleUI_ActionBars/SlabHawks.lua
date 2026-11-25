-- SlabHawks.lua: the Medallions hub's hawk perches for hunters who know Summon Hawk: two gilt hawk sigils on the rune ring's shoulders, one per hawk the game keeps in totem slots 2 and 3, each ringed by a timer that drains over the hawk's life, with the rune ring glowing while both are out; the engine draws them from the slot itself (alpha from haveTotem, the swipe from GetTotemDuration), so Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, max = math.cos, math.sin, math.rad, math.max
local IsSecret = Widgets.IsSecret
local Medals = ns.SlabMedals
local Known, Even, Texture, Layer = Medals.Known, Medals.Even, Medals.Texture, Medals.Layer

local Hawks = {}
ns.SlabHawks = Hawks

local OWNER = "ActionBars.SlabHawks"
local SPELLS = { 1293241, 1293525, 1293526, 1293527 }
local RADIUS, ANGLE = 78, 40
local TRACK, SOCKET, SEAT, SIGIL, GLOW, BURST, GLINT, GLINT_AT = 42, 28, 29, 23, 60, 56, 4, 8
local STEEL_ALPHA, GLOW_ALPHA, BURST_ALPHA, RING_HALO = 0.45, 0.55, 0.6, 1.6
local FLARE_RISE, FLARE_FALL, FADE, POP = 0.05, 0.4, 0.35, 1.3

local state = { perches = {} }
Hawks.state = state

local function Active()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and ns.Config("crestHawks") ~= false and UnitClass and GetTotemInfo) then
		return nil
	end
	local _, class = UnitClass("player")
	if IsSecret(class) or class ~= "HUNTER" then
		return nil
	end
	return Known(SPELLS) and hub or nil
end

local function Fade(target, from, to, duration, order)
	local group = target.fade or target:CreateAnimationGroup()
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	target.fade = group
	group:SetScript("OnFinished", function()
		target:Hide()
	end)
end

local function Lit(add, slot, frame, size, glow)
	if glow then
		add(Texture(frame, "BACKGROUND", 0, "glow", "jewelHawk", GLOW, "ADD")):SetAlpha(GLOW_ALPHA)
	end
	local sigil = add(Texture(frame, "ARTWORK", 0, "hawkSigil", "white", size, glow == false and "ADD" or nil))
	if slot == 3 then
		sigil:SetTexCoord(1, 0, 0, 1)
	end
	return sigil
end

local function Build(hub, slot)
	local holder = CreateFrame("Frame", nil, hub.top)
	holder.units = TRACK
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base)
	local p = { holder = holder, slot = slot, parts = {} }
	local add = function(t) p.parts[#p.parts + 1] = t return t end
	add(Texture(holder, "BACKGROUND", 0, "orbRing", "medSocket", TRACK))
	add(Texture(holder, "BORDER", 0, "dot", "medSocket", SOCKET))
	local steel = Lit(add, slot, holder, SIGIL)
	steel:SetVertexColor(Tokens.Color("steel"))
	steel:SetDesaturated(true)
	steel:SetAlpha(STEEL_ALPHA)
	local timer = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
	timer:SetFrameLevel(base + 1)
	timer:SetPoint("CENTER", holder, "CENTER", 0, 0)
	timer.units = TRACK
	timer:SetSwipeTexture((Tokens.Texture("orbRing")))
	timer:SetSwipeColor(Tokens.Color("jewelHawk"))
	timer:SetDrawEdge(false)
	timer:SetDrawBling(false)
	timer:SetHideCountdownNumbers(true)
	p.timer = add(timer)
	add(Medals.Ember(holder, nil, timer, "Band", base + 1, SEAT))
	local cover = Layer(holder, base + 2)
	add(Texture(cover, "ARTWORK", 0, "ring", "gilt", SEAT))
	p.lit = Layer(holder, base + 3)
	Lit(add, slot, p.lit, SIGIL, true)
	p.glint = add(Texture(p.lit, "OVERLAY", 0, "diamond", "white", GLINT, "ADD"))
	p.wasGate = Layer(holder, base + 3)
	p.was = Layer(p.wasGate, base + 3)
	Lit(add, slot, p.was, SIGIL, true)
	Fade(p.was, 1, 0, FADE)
	p.flareGate = Layer(holder, base + 4)
	p.flare = Layer(p.flareGate, base + 4)
	add(Texture(p.flare, "ARTWORK", 0, "glow", "jewelHawkCore", BURST, "ADD")):SetAlpha(BURST_ALPHA)
	Lit(add, slot, p.flare, SIGIL * POP, false)
	Fade(p.flare, 0, 1, FLARE_RISE)
	Fade(p.flare, 1, 0, FLARE_FALL, 2)
	for _, frame in ipairs({ p.was, p.flare }) do
		frame:SetAlpha(0)
		frame:Hide()
	end
	return p
end

local function BuildPair(hub)
	local pair = CreateFrame("Frame", nil, hub)
	pair:SetAllPoints(hub)
	pair.inner = CreateFrame("Frame", nil, pair)
	pair.inner:SetAllPoints(pair)
	pair.glow = CreateFrame("Frame", nil, pair.inner)
	pair.glow:SetAllPoints(pair.inner)
	pair.glyphs = Layer(pair.glow, 0)
	pair.halo = Layer(pair.glow, 0)
	local glyphs = Texture(pair.glyphs, "ARTWORK", 0, "medRuneGlyphs", "jewelHawk", ns.Slab.RING, "ADD")
	glyphs:SetAllPoints(pair.glyphs)
	pair.haloTexture = Texture(pair.halo, "BACKGROUND", 0, "glow", "jewelHawk", ns.Slab.RING * RING_HALO, "ADD")
	pair.breath = pair.glow:CreateAnimationGroup()
	pair.breath:SetLooping("BOUNCE")
	local a = pair.breath:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(ns.SlabEffects.CAP_LOW)
	a:SetDuration(ns.SlabEffects.CAP_BREATH)
	a:SetSmoothing("IN_OUT")
	state.pair = pair
	return pair
end

local function Place(hub)
	for i = 1, 2 do
		local p = state.perches[i] or Build(hub, i + 1)
		state.perches[i] = p
		local side = i == 1 and -1 or 1
		local a = rad(ANGLE)
		p.holder:ClearAllPoints()
		p.holder:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, side * RADIUS * sin(a)), Widgets.Snap(hub, RADIUS * cos(a)))
		Even(p.holder)
		for _, part in ipairs(p.parts) do
			Even(part)
		end
		local glint = Widgets.Snap(p.holder, GLINT_AT)
		p.glint:SetPoint("CENTER", p.holder, "CENTER", -glint, glint)
		p.holder:Show()
	end
	local pair = state.pair or BuildPair(hub)
	local under = max(0, hub:GetFrameLevel() - 1)
	for _, frame in ipairs({ pair, pair.inner, pair.glow, pair.halo }) do
		frame:SetFrameLevel(under)
	end
	pair.glyphs:SetFrameLevel(hub:GetFrameLevel() + 1)
	Widgets.Size(pair.haloTexture, pair.haloTexture.units, pair.haloTexture.units)
end

local function Gate(frame, value)
	frame:SetAlpha(1)
	if not IsSecret(value) then
		frame:SetShown(value == true)
	elseif frame.SetAlphaFromBoolean then
		frame:Show()
		frame:SetAlphaFromBoolean(value, 1, 0)
	else
		frame:Hide()
	end
end

local function Pair()
	local pair, first, second = state.pair, state.perches[1], state.perches[2]
	Gate(pair, first.have)
	Gate(pair.inner, second.have)
	pair:SetShown(pair:IsShown() and pair.inner:IsShown())
	if pair:IsShown() and not (IsSecret(first.have) or IsSecret(second.have)) and Effects.Allows("pulse") then
		if not pair.breath:IsPlaying() then
			pair.breath:Play()
		end
	else
		pair.breath:Stop()
	end
end

local function Paint(p, moving)
	local have, _, start, duration = GetTotemInfo(p.slot)
	Gate(p.lit, have)
	local object = GetTotemDuration and GetTotemDuration(p.slot)
	if object then
		p.timer:SetCooldownFromDurationObject(object)
	elseif not (IsSecret(have) or IsSecret(start) or IsSecret(duration)) and have == true then
		p.timer:SetCooldown(start, duration)
	else
		p.timer:Clear()
	end
	for _, frame in ipairs({ p.was, p.flare }) do
		frame.fade:Stop()
		frame:Hide()
	end
	if moving then
		Gate(p.flareGate, have)
		Gate(p.wasGate, p.have)
		for _, frame in ipairs({ p.was, p.flare }) do
			if frame:GetParent():IsShown() then
				frame:Show()
				frame.fade:Play()
			end
		end
	end
	p.have = have
end

local function OnTotem(_, slot)
	local moving = Effects.Allows("flare")
	for _, p in ipairs(state.perches) do
		if IsSecret(slot) or p.slot == slot then
			Paint(p, moving)
		end
	end
	Pair()
end

local function Stop()
	if state.listening then
		K.Events.UnregisterAll(OWNER)
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
		state.listening = false
	end
	for _, p in ipairs(state.perches) do
		p.holder:Hide()
	end
	if state.pair then
		state.pair.breath:Stop()
		state.pair:Hide()
	end
end

function Hawks.Update()
	local hub = Active()
	if not hub then
		return Stop()
	end
	if not state.listening then
		K.Events.Register(OWNER, "PLAYER_TOTEM_UPDATE", OnTotem)
		K.Callbacks.Register("EffectsLevelChanged", OWNER, Hawks.Update)
		state.listening = true
	end
	Place(hub)
	for _, p in ipairs(state.perches) do
		Paint(p, false)
	end
	Pair()
end

function Hawks.Recheck()
	if (Active() ~= nil) ~= (state.listening == true) then
		Hawks.Update()
	end
end

function Hawks.SetEnabled(on)
	state.enabled = on
	Hawks.Update()
end
