-- SlabHawks.lua: the Medallions hub's hawk perches for hunters who know Summon Hawk: two gilt hawk sigils on the rune ring's shoulders, one per hawk the game keeps in totem slots 2 and 3, each ringed by a timer that drains over the hawk's life, with the rune ring glowing while both are out; the engine draws them from the slot itself (alpha from haveTotem, the swipe from GetTotemDuration), so Lua never reads or compares a secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local cos, sin, rad, floor, max = math.cos, math.sin, math.rad, math.floor, math.max
local IsSecret = Widgets.IsSecret

local Hawks = {}
ns.SlabHawks = Hawks

local OWNER = "ActionBars.SlabHawks"
local SPELLS = { 1293241, 1293525, 1293526, 1293527 }
local SLOTS = { 2, 3 }
local RADIUS, ANGLE = 78, 40
local TRACK, SOCKET, SEAT, SIGIL, GLOW, BURST, GLINT, GLINT_AT = 42, 28, 29, 23, 60, 56, 4, 8
local STEEL_ALPHA, GLOW_ALPHA, BURST_ALPHA, RING_HALO = 0.45, 0.55, 0.6, 1.6
local FLARE_RISE, FLARE_FALL, FADE, POP = 0.05, 0.4, 0.35, 1.3

local state = { perches = {} }
Hawks.state = state

local function Known()
	local book = C_SpellBook
	if not (book and type(book.IsSpellKnown) == "function") then
		return false
	end
	for _, id in ipairs(SPELLS) do
		local known = book.IsSpellKnown(id)
		if not IsSecret(known) and known == true then
			return true
		end
	end
	return false
end

local function Active()
	local hub = ns.Slab and ns.Slab.hub
	if not (state.enabled and hub and hub:IsShown() and ns.Config("crestHawks") ~= false and UnitClass and GetTotemInfo) then
		return nil
	end
	local _, class = UnitClass("player")
	if IsSecret(class) or class ~= "HUNTER" then
		return nil
	end
	return Known() and hub or nil
end

local function Even(region)
	local px = Widgets.Border(region)
	local side = max(2, 2 * floor(region.units / px / 2 + 0.5)) * px
	region:SetSize(side, side)
end

local function Texture(parent, layer, sublevel, texture, color, size, blend)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture((Tokens.Texture(texture)))
	t:SetVertexColor(Tokens.Color(color))
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	if blend then
		t:SetBlendMode(blend)
	end
	t.units = size
	return t
end

local function Layer(holder, level)
	local frame = CreateFrame("Frame", nil, holder)
	frame:SetAllPoints(holder)
	frame:SetFrameLevel(level)
	return frame
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
	return group
end

local function Lit(p, frame, size, glow)
	local add = function(t) p.parts[#p.parts + 1] = t return t end
	if glow then
		add(Texture(frame, "BACKGROUND", 0, "glow", "jewelHawk", GLOW, "ADD")):SetAlpha(GLOW_ALPHA)
	end
	local sigil = add(Texture(frame, "ARTWORK", 0, "hawkSigil", "white", size, glow == false and "ADD" or nil))
	p.sigils[#p.sigils + 1] = sigil
	return sigil
end

local function Build(hub, slot)
	local holder = CreateFrame("Frame", nil, hub.top)
	holder.units = TRACK
	local base = hub.top:GetFrameLevel() + 1
	holder:SetFrameLevel(base)
	local p = { holder = holder, slot = slot, parts = {}, sigils = {} }
	local add = function(t) p.parts[#p.parts + 1] = t return t end
	add(Texture(holder, "BACKGROUND", 0, "orbRing", "medSocket", TRACK))
	add(Texture(holder, "BORDER", 0, "dot", "medSocket", SOCKET))
	local steel = Lit(p, holder, SIGIL)
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
	local cover = Layer(holder, base + 2)
	add(Texture(cover, "ARTWORK", 0, "ring", "gilt", SEAT))
	p.lit = Layer(holder, base + 3)
	Lit(p, p.lit, SIGIL, true)
	p.glint = add(Texture(p.lit, "OVERLAY", 0, "diamond", "white", GLINT, "ADD"))
	p.wasGate = Layer(holder, base + 3)
	p.was = Layer(p.wasGate, base + 3)
	Lit(p, p.was, SIGIL, true)
	Fade(p.was, 1, 0, FADE)
	p.flareGate = Layer(holder, base + 4)
	p.flare = Layer(p.flareGate, base + 4)
	add(Texture(p.flare, "ARTWORK", 0, "glow", "jewelHawkCore", BURST, "ADD")):SetAlpha(BURST_ALPHA)
	Lit(p, p.flare, SIGIL * POP, false)
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
	local halo = Texture(pair.halo, "BACKGROUND", 0, "glow", "jewelHawk", ns.Slab.RING * RING_HALO, "ADD")
	pair.haloTexture = halo
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
	for i, slot in ipairs(SLOTS) do
		local p = state.perches[i] or Build(hub, slot)
		state.perches[i] = p
		local side = i == 1 and -1 or 1
		local a = rad(ANGLE)
		p.holder:ClearAllPoints()
		p.holder:SetPoint("CENTER", hub, "CENTER", Widgets.Snap(hub, side * RADIUS * sin(a)), Widgets.Snap(hub, RADIUS * cos(a)))
		Even(p.holder)
		for _, part in ipairs(p.parts) do
			Even(part)
		end
		for _, sigil in ipairs(p.sigils) do
			if side > 0 then
				sigil:SetTexCoord(1, 0, 0, 1)
			end
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
	local pair = state.pair
	local first, second = state.perches[1], state.perches[2]
	if not (pair and first and second) then
		return
	end
	Gate(pair, first.have)
	Gate(pair.inner, second.have)
	pair:SetShown(pair:IsShown() and pair.inner:IsShown())
	if pair:IsShown() and Effects.Allows("pulse") then
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
	if moving and p.seen then
		Gate(p.flareGate, have)
		Gate(p.wasGate, p.have)
		for _, frame in ipairs({ p.was, p.flare }) do
			if frame:GetParent():IsShown() then
				frame:Show()
				frame.fade:Play()
			end
		end
	end
	p.have, p.seen = have, true
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
		state.listening = false
	end
	for _, p in ipairs(state.perches) do
		p.holder:Hide()
		p.seen = nil
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
		state.listening = true
	end
	Place(hub)
	for _, p in ipairs(state.perches) do
		Paint(p, false)
	end
	Pair()
end

function Hawks.SetEnabled(on)
	state.enabled = on
	if on then
		K.Callbacks.Register("EffectsLevelChanged", OWNER, Hawks.Update)
	else
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	end
	Hawks.Update()
end
