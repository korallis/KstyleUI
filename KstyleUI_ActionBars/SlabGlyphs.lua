-- SlabGlyphs.lua: the Medallions crest's rune glyph band (docs/medallions-effects.md#glyph-tide-and-stance-mantle): the glyph tide, two vertical status bars fed the player's power, one eased and one immediate, whose fills mask the lit glyphs, a paler core and a fringe, so the band lights from the foot upward in the resource's colour, a gain eases and a spend drops at once while the engine compares the values; and the stance mantle, which tints the band and a thin inner rim by GetShapeshiftFormID, turns every glyph layer one notch together and cross-fades the old ink into the new on a change, and under Frames tints the active stance button's rim. Both are built out of combat only and replay held-back work when combat or the restriction ends.
local _, ns = ...

local K = KstyleUI
local Effects, Tokens, Widgets = K.Effects, K.Tokens, K.Widgets
local IsSecret = Widgets.IsSecret
local TWO_PI = 2 * math.pi

local Glyphs = {}
ns.SlabGlyphs = Glyphs

local TIDE_OWNER, MANTLE_OWNER, REPLAY_OWNER = "ActionBars.SlabGlyphs.Tide", "ActionBars.SlabGlyphs.Mantle", "ActionBars.SlabGlyphs.Replay"
local INSET, SETTLE, CORE, CORE_ALPHA, FRINGE, FRINGE_ALPHA = 6, 0.6, 0.55, 0.6, 140, 0.25
local HALO, RIPPLE, RIPPLE_RUN = 122, 142 / 122, 0.35
local FADE, NOTCH, TURN, STEALTH, DIM, RUNES = 0.25, 30, 0.3, 30, 0.55, 0.7
local MANTLE = {
	[17] = "gilt", [18] = "magic", [19] = "schoolFire", [5] = "pipDruidGlow", [8] = "pipDruidGlow", [1] = "coinGold", [3] = "mantleTravel",
	[30] = "schoolShadow", [28] = "schoolShadow", [16] = "totemSpirit",
}
Glyphs.CLASSES = { WARRIOR = true, DRUID = true, ROGUE = true, PRIEST = true, SHAMAN = true, PALADIN = true }
Glyphs.NOTCH = NOTCH

local tide, mantle, band, state = {}, { angle = 0 }, {}, {}
local REPLAY = { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
Glyphs.tide, Glyphs.mantle, Glyphs.band = tide, mantle, band

local function Anim(group, kind, duration, smoothing, target)
	local a = group:CreateAnimation(kind)
	a:SetDuration(duration)
	a:SetSmoothing(smoothing)
	if target then
		a:SetTarget(target)
	end
	return a
end

local function Fader(region, duration)
	local group = region:CreateAnimationGroup()
	group.alpha = Anim(group, "Alpha", duration, "IN_OUT")
	return group
end

local function Near(a, b)
	return math.abs(a - b) < 0.002
end

local function FadeTo(region, group, to, moving)
	local from = region:GetAlpha()
	if Near(from, to) then
		return
	end
	group:Stop()
	region:SetAlpha(to)
	if moving then
		group.alpha:SetFromAlpha(from)
		group.alpha:SetToAlpha(to)
		group:Play()
	end
end

local function Tint(region, r, g, b)
	local cr, cg, cb, a = region:GetVertexColor()
	if not (Near(cr, r) and Near(cg, g) and Near(cb, b)) then
		region:SetVertexColor(r, g, b, a)
	end
end

local function Interpolation(moving)
	local modes = Enum and Enum.StatusBarInterpolation or {}
	return moving and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0)
end

local function PowerRGB(token)
	local c = token and (K.Theme.Palette(token) or type(PowerBarColor) == "table" and PowerBarColor[token])
	if type(c) == "table" and type(c.r) == "number" then
		return K.Theme.Brighten(c.r, c.g, c.b)
	end
	return Tokens.Color("rare")
end

local function Art(parent, layer, sublevel, token, units)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture((Effects.Texture(token, "ring")))
	t:SetBlendMode("ADD")
	if units then
		Widgets.Size(t, units, units)
		Widgets.Point(t, "CENTER", parent, "CENTER", 0, 0)
	else
		Widgets.Fill(t, parent)
	end
	return t
end

local function Bar(parent, hub)
	local bar = CreateFrame("StatusBar", nil, parent)
	Widgets.Fill(bar, hub, 0, INSET, 0, INSET)
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture((Effects.Texture("barFlat")))
	bar:GetStatusBarTexture():SetAlpha(0)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture((Effects.Texture("barFlat")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(bar:GetStatusBarTexture())
	return bar, mask
end

local function Hold(on)
	state.pending = on
	for _, event in ipairs(REPLAY) do
		if on then
			K.Events.Register(REPLAY_OWNER, event, ns.SlabEffects.UpdateCap)
		else
			K.Events.Unregister(REPLAY_OWNER, event)
		end
	end
end

local function Turn(angle)
	for _, t in ipairs(band) do
		t:SetRotation(angle)
	end
end

local function Build(hub)
	local runes = hub.runes
	local frame = ns.SlabMedals.Layer(hub, hub:GetFrameLevel() + 1)
	tide.eased, tide.easedMask = Bar(frame, hub)
	tide.now, tide.nowMask = Bar(frame, hub)
	tide.fringe = Art(frame, "ARTWORK", 0, "ring", FRINGE)
	tide.lit = Art(frame, "ARTWORK", 1, "medRuneGlyphs")
	tide.core = Art(frame, "ARTWORK", 2, "medRuneGlyphs")
	tide.core:SetAlpha(CORE_ALPHA)
	tide.fringe:SetAlpha(FRINGE_ALPHA)
	for _, t in ipairs({ tide.fringe, tide.lit, tide.core }) do
		t:AddMaskTexture(tide.easedMask)
		t:AddMaskTexture(tide.nowMask)
	end
	tide.above = hub:CreateMaskTexture()
	tide.above:SetTexture((Effects.Texture("barFlat")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	tide.above:SetPoint("BOTTOMLEFT", tide.now:GetStatusBarTexture(), "TOPLEFT", 0, 0)
	tide.above:SetPoint("TOPRIGHT", hub, "TOPRIGHT", 0, 0)
	frame.settle = Fader(frame, SETTLE)
	frame.settle.alpha:SetFromAlpha(1)
	frame.settle.alpha:SetToAlpha(0)
	frame.settle:SetScript("OnFinished", function()
		frame:Hide()
	end)
	frame:Hide()
	tide.frame = frame

	local ink = Art(hub, "ARTWORK", 5, "medRuneGlyphs")
	ink:Hide()
	ink.fade = Fader(ink, FADE)
	ink.fade.alpha:SetToAlpha(0)
	ink.fade:SetScript("OnFinished", function()
		ink:Hide()
	end)
	local layer = ns.SlabMedals.Layer(hub, hub:GetFrameLevel() + 1)
	local halo, ripple = Art(layer, "ARTWORK", 0, "ringLine32", HALO), Art(layer, "ARTWORK", 1, "ringLine32", HALO)
	halo.fade = Fader(halo, FADE)
	ripple:Hide()
	ripple.anim = ripple:CreateAnimationGroup()
	local grow = Anim(ripple.anim, "Scale", RIPPLE_RUN, "OUT")
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(RIPPLE, RIPPLE)
	local fade = Anim(ripple.anim, "Alpha", RIPPLE_RUN, "OUT")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	ripple.anim:SetScript("OnFinished", function()
		ripple:Hide()
	end)
	layer:Hide()

	band[1], band[2], band[3], band[4] = runes, ink, tide.lit, tide.core
	local notch = runes:CreateAnimationGroup()
	local playing = runes.turn:IsPlaying()
	for _, t in ipairs(band) do
		Anim(notch, "Rotation", TURN, "OUT", t ~= runes and t or nil):SetDegrees(-NOTCH)
		if t ~= runes then
			local spin = Anim(runes.turn, "Rotation", ns.Slab.RUNE_TURN, "NONE", t)
			spin:SetDegrees(-360)
		end
	end
	runes.turn:Stop()
	if playing then
		runes.turn:Play()
	end
	notch:SetScript("OnFinished", function()
		Turn(mantle.angle)
	end)
	hub.crest.dim, runes.lift, mantle.rest = Fader(hub.crest, FADE), Fader(runes, FADE), runes:GetAlpha()
	mantle.frame, mantle.halo, mantle.ripple, mantle.turn, mantle.ink = layer, halo, ripple, notch, ink
end

local function Still(hub)
	local turn = mantle.turn
	if not turn then
		return
	end
	if turn:IsPlaying() then
		turn:Stop()
		Turn(mantle.angle)
	end
	for _, group in ipairs({ mantle.ripple.anim, mantle.ink.fade, mantle.halo.fade, hub.runes.lift, hub.crest.dim }) do
		group:Stop()
	end
	mantle.ripple:Hide()
	mantle.ink:Hide()
	if tide.frame.settle:IsPlaying() then
		tide.frame.settle:Stop()
		tide.frame:Hide()
	end
end

local function Feed(event, _, token)
	local kind = tide.kind
	if not (kind and tide.frame:IsShown()) or event == "UNIT_POWER_FREQUENT" and tide.token and not IsSecret(token) and token ~= tide.token then
		return
	end
	local most, power = UnitPowerMax("player", kind), UnitPower("player", kind)
	for _, bar in ipairs({ tide.eased, tide.now }) do
		if event ~= "UNIT_POWER_FREQUENT" then
			bar:SetMinMaxValues(0, most)
		end
		bar:SetValue(power, bar == tide.eased and event and tide.ease or Interpolation(false))
	end
end

local function Cover(on)
	if on ~= (tide.covering == true) then
		tide.covering = on
		for i = 1, 2 do
			if on then
				band[i]:AddMaskTexture(tide.above)
			else
				band[i]:RemoveMaskTexture(tide.above)
			end
		end
	end
end

local function Settle(shown)
	local frame = tide.frame
	tide.shown = shown
	frame.settle:Stop()
	frame:SetAlpha(1)
	Cover(shown)
	if shown then
		frame:Show()
	elseif frame:IsShown() and tide.moving then
		frame.settle:Play()
	else
		frame:Hide()
	end
end

local function OnCombat(event)
	tide.combat = event == "PLAYER_REGEN_DISABLED"
	ns.SlabEffects.UpdateCap()
end

local function ListenTide(on)
	if on == tide.listening then
		return
	end
	tide.listening = on
	local Events = K.Events
	if not on then
		Events.UnregisterAll(TIDE_OWNER)
		tide.combat = nil
		return
	end
	Events.RegisterUnit(TIDE_OWNER, "UNIT_POWER_FREQUENT", Feed, "player")
	Events.RegisterUnit(TIDE_OWNER, "UNIT_MAXPOWER", Feed, "player")
	Events.RegisterUnit(TIDE_OWNER, "UNIT_DISPLAYPOWER", ns.SlabEffects.UpdateCap, "player")
	Events.Register(TIDE_OWNER, "PLAYER_REGEN_DISABLED", OnCombat)
	Events.Register(TIDE_OWNER, "PLAYER_REGEN_ENABLED", OnCombat)
end

local function UpdateTide(on)
	local kind, token
	if on and UnitPowerType and UnitPower and UnitPowerMax then
		kind, token = UnitPowerType("player")
		if IsSecret(kind) or IsSecret(token) then
			Hold(true)
			kind, token = tide.kind, tide.token
		end
	end
	if type(kind) ~= "number" or not tide.frame then
		if tide.frame then
			Cover(false)
			tide.frame.settle:Stop()
			tide.frame:Hide()
		end
		tide.kind, tide.token, tide.shown = nil, nil, false
		ListenTide(false)
		return
	end
	tide.kind, tide.token, tide.moving = kind, token, Effects.Allows("flare")
	tide.ease = Interpolation(tide.moving)
	if tide.combat == nil then
		tide.combat = ns.Slab.InCombat()
	end
	local r, g, b = PowerRGB(token)
	Tint(tide.lit, r, g, b)
	Tint(tide.fringe, r, g, b)
	Tint(tide.core, r + (1 - r) * CORE, g + (1 - g) * CORE, b + (1 - b) * CORE)
	ListenTide(true)
	Settle(token ~= "MANA" or tide.combat)
	Feed()
end

function Glyphs.Drives()
	return tide.shown and tide.kind or nil
end

function Glyphs.TideColor(power)
	if tide.shown and tide.kind == power then
		return tide.lit:GetVertexColor()
	end
end

local function Notch(moving)
	if mantle.turn:IsPlaying() then
		mantle.turn:Stop()
		Turn(mantle.angle)
	end
	mantle.angle = (mantle.angle - math.rad(NOTCH)) % TWO_PI
	if moving then
		mantle.turn:Play()
	else
		Turn(mantle.angle)
	end
end

local function Wear(hub, form, token)
	local changed = mantle.worn and form ~= mantle.wornForm
	local moving = changed and Effects.Allows("flare")
	local r, g, b = hub.r, hub.g, hub.b
	if token ~= "class" and token then
		r, g, b = Tokens.Color(token)
	end
	local runes, ink, halo, ripple = hub.runes, mantle.ink, mantle.halo, mantle.ripple
	if moving then
		local cr, cg, cb, ca = runes:GetVertexColor()
		ink:SetVertexColor(cr, cg, cb, ca)
		ink.fade:Stop()
		ink.fade.alpha:SetFromAlpha(ca)
		ink:Show()
		ink.fade:Play()
		runes:SetAlpha(0)
		ripple:SetVertexColor(halo:GetVertexColor())
		if not halo:IsShown() then
			ripple:SetVertexColor(r, g, b, 1)
		end
		ripple:Show()
		ripple.anim:Stop()
		ripple.anim:Play()
	end
	Tint(runes, r, g, b)
	FadeTo(runes, runes.lift, token and RUNES or mantle.rest, moving)
	FadeTo(hub.crest, hub.crest.dim, form == STEALTH and DIM or 1, moving)
	Tint(halo, r, g, b)
	if token then
		if changed or not halo:IsShown() then
			halo.fade:Stop()
			halo:SetAlpha(moving and 0 or 1)
			halo:Show()
		end
		FadeTo(halo, halo.fade, 1, moving)
	else
		halo:Hide()
	end
	if changed then
		Notch(moving)
	end
	mantle.frame:Show()
	mantle.worn, mantle.wornForm = true, form
end

local function Undress(hub)
	if not mantle.worn then
		return
	end
	Still(hub)
	mantle.worn, mantle.wornForm, mantle.angle = false, nil, 0
	Turn(0)
	mantle.frame:Hide()
	hub.runes:SetVertexColor(hub.r, hub.g, hub.b, mantle.rest)
	hub.crest:SetAlpha(1)
end

local function Rims(token, frames)
	local r, g, b
	if token == "class" then
		r, g, b = K.Theme.ClassColor((select(2, UnitClass("player"))))
	elseif token then
		r, g, b = Tokens.Color(token)
	end
	for _, button in ipairs(ns.stanceButtons or {}) do
		local active = false
		if frames and r and type(GetShapeshiftFormInfo) == "function" then
			local _, on = GetShapeshiftFormInfo(button.index)
			active = not IsSecret(on) and on == true
		end
		if active or button.mantle then
			button.mantle = active and { r, g, b } or nil
			ns.Button.SetAccent(button, ns.AccentRGB())
		end
	end
end

local function Form()
	local id = type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID()
	if IsSecret(id) then
		Hold(true)
		return mantle.form or 0
	end
	return id or 0
end

function Glyphs.Wear(event)
	local form = Form()
	if event and form == mantle.form then
		return
	end
	mantle.form = form
	local token = mantle.on and form ~= 0 and (MANTLE[form] or "class") or nil
	Rims(token, mantle.frames)
	local hub = ns.Slab.hub
	if mantle.crest and mantle.turn then
		Wear(hub, form, token)
	elseif hub and mantle.turn then
		Undress(hub)
	end
end

function Glyphs.Update()
	local hub = ns.Slab and ns.Slab.hub
	local crest = ns.running == true and hub ~= nil and hub:IsShown() and Effects.Active()
	local _, class = UnitClass("player")
	local on = ns.running == true and ns.Config("crestMantle") ~= false and not IsSecret(class) and Glyphs.CLASSES[class] == true
	local flow = crest and ns.Config("crestTide") ~= false
	state.pending = false
	if (flow or on and crest) and not mantle.turn then
		if ns.SlabMedals.Locked() then
			Hold(true)
		else
			Build(hub)
		end
	end
	if mantle.turn and not Effects.Allows("flare") then
		Still(hub)
	end
	UpdateTide(flow)
	mantle.on, mantle.crest, mantle.frames = on, on and crest, on and K.HudStyle.Current() == "frames"
	if on then
		K.Events.Register(MANTLE_OWNER, "UPDATE_SHAPESHIFT_FORM", Glyphs.Wear)
	else
		K.Events.Unregister(MANTLE_OWNER, "UPDATE_SHAPESHIFT_FORM")
	end
	Glyphs.Wear()
	if not state.pending then
		Hold(false)
	end
end
