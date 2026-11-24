-- SlabRings.lua: the crest's ring-edge timing layers (docs/medallions-effects.md#ring-edge-timers): Expiring ember, a second swipe on every timer ring's own duration that paints its last fifth amber and last twelfth red, flickers that fifth and fades an expired ring to steel while auras are readable; the swing ring, drained inside the rune band over each main-hand swing (and a hunter's Auto Shot) with a white tick at the hit; the cast ring, your cast drawn round the crest's outer edge that flashes and pulses the crest when it lands and shakes red when it is stopped; and the global cooldown spark, one spark round that edge per global cooldown.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local IsSecret = Widgets.IsSecret
local Medals, Trackers = ns.SlabMedals, ns.SlabTrackers

local Rings = {}
ns.SlabRings = Rings

local ART = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Trackers\\"
local FIFTH, FLICKER, FADE, LATE = 0.2, 0.12, 0.4, 0.5
local INNER, SWING, EDGE = 112, 108, 145
local TICK, FLASH, PULSE, SHAKE, FALL = 0.2, 0.25, 0.35, { 3, -5, 2 }, 0.3
local GCD_SPELL = 29515
local OWNER = "ActionBars.SlabRings"
local MELEE = { WARRIOR = true, PALADIN = true, ROGUE = true, SHAMAN = true, DRUID = { 1, 5, 8 } }
local CAST_EVENTS = {
	UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_DELAYED = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel", UNIT_SPELLCAST_CHANNEL_UPDATE = "channel",
	UNIT_SPELLCAST_SUCCEEDED = "land", UNIT_SPELLCAST_CHANNEL_STOP = "land", UNIT_SPELLCAST_INTERRUPTED = "stop", UNIT_SPELLCAST_FAILED = "stop",
	UNIT_SPELLCAST_STOP = "clear",
}
local state = { embers = {}, watched = {} }
Rings.state = state

local function Pop(region, seconds, smoothing)
	local group = region:CreateAnimationGroup()
	ns.Slab.Fade(group, 1, 0, seconds):SetSmoothing(smoothing)
	return group
end

local function EmberOn()
	return ns.Config("crestEmber") ~= false
end

local function Hot(parent, level, art)
	local t = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	t:SetFrameLevel(level)
	t:SetPoint("CENTER", parent, "CENTER", 0, 0)
	t:SetSwipeTexture(ART .. "Ember" .. art)
	t:SetSwipeColor(Tokens.Color("white"))
	t:SetDrawEdge(false)
	t:SetDrawBling(false)
	t:SetHideCountdownNumbers(true)
	return t
end

function Medals.Ember(piece, lit, timer, art, level, color)
	local gate, hot
	if lit and lit.container then
		gate = Medals.Mirror(piece, lit, level)
		hot = Hot(gate.lit, level, art)
		gate.lit:SetDurationCooldown(hot)
		local ghost = Medals.Texture(Medals.Layer(piece, level + 1), "OVERLAY", 0, art == "OrbRing.png" and "orbRing" or "ringLine16", color or "gilt", timer.units)
		ghost:SetAlpha(0)
		piece.add(ghost)
		state.watched[#state.watched + 1] = { piece = piece, spec = lit.spec, fade = Pop(ghost, FADE, "IN_OUT"),
			flicker = Medals.Steps(piece, { { 1, 0.5, FLICKER }, { 0.5, 1, FLICKER } }, true) }
	else
		gate = Medals.Layer(timer:GetParent(), timer:GetFrameLevel() + 1)
		hot = Hot(gate, gate:GetFrameLevel(), art)
		for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "Clear" }) do
			hooksecurefunc(timer, method, function(_, ...) hot[method](hot, ...) end)
		end
	end
	gate:SetAlpha(EmberOn() and 1 or 0)
	state.embers[#state.embers + 1] = gate
	hot.units = timer.units
	return hot
end

local function Aura(spec)
	local get = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
	local mine = (spec.filter or ""):find("PLAYER", 1, true)
	for _, id in ipairs(get and spec.spells or {}) do
		local a = get(spec.unit or "player", id)
		if type(a) == "table" and not IsSecret(a.sourceUnit) and (not mine or a.sourceUnit == "player") then
			return a
		end
	end
end

local function Watch(e, now)
	local a = Aura(e.spec)
	local ends, length = a and a.expirationTime, a and a.duration
	if IsSecret(ends) or IsSecret(length) or type(ends) ~= "number" or type(length) ~= "number" or length <= 0 then
		if e.ends and now >= e.ends - LATE and Effects.Allows("flare") then
			e.fade:Stop()
			e.fade:Play()
		end
		e.ends, e.due = nil, nil
		e.flicker:Stop()
		return
	end
	e.ends = ends
	local due = ends - length * FIFTH
	if not Effects.Allows("pulse") or due > now and e.due == due then
		return
	end
	e.flicker:Stop()
	e.due = due
	if due <= now then
		e.flicker:Play()
	elseif C_Timer and C_Timer.After then
		C_Timer.After(due - now, function()
			if e.due == due and not Medals.Restricted() and e.piece:IsShown() then e.flicker:Play() end
		end)
	end
end

local function Readable(_, unit)
	local restricted, now = Medals.Restricted(), type(GetTime) == "function" and GetTime() or 0
	for _, e in ipairs(state.watched) do
		if restricted or not EmberOn() then
			e.flicker:Stop()
			e.ends, e.due = nil, nil
		elseif e.piece:IsShown() and (unit == nil or unit == (e.spec.unit or "player")) then
			Watch(e, now)
		end
	end
end

function Rings.Swing(parent, spec, level, form)
	local crest = form == "crest"
	local r = crest and Medals.Piece(parent, level, spec.size or INNER) or Medals.Medal(parent, { size = Medals.SIZE, texture = spec.texture }, level)
	r.swing = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
	r.swing:SetFrameLevel(level + 4)
	r.swing:SetAllPoints(r)
	r.swing:SetSwipeTexture((Tokens.Texture(crest and "ringLine16" or "orbRing")))
	r.swing:SetSwipeColor(Tokens.Color(spec.color))
	r.swing:SetDrawEdge(crest)
	r.swing:SetUseCircularEdge(true)
	r.swing:SetDrawBling(false)
	r.swing:SetHideCountdownNumbers(true)
	if crest then
		r.tick = r.add(Medals.Texture(r.swing, "OVERLAY", 0, "ringLine16", "white", r.units, "ADD"))
		r.tick:SetAlpha(0)
		r.tick.play = Pop(r.tick, TICK, "OUT")
	end
	r.color, r.spec = spec.color, spec
	return r
end

function Rings.Start(r, duration, kind, melee)
	local types = Enum and Enum.PlayerSwingType or {}
	if type(GetTime) ~= "function" or IsSecret(kind) or kind ~= (types.MainHand or 0) and (melee or kind ~= (types.Ranged or 2)) then
		return
	end
	local util = C_DurationUtil
	r.duration = r.duration or util and type(util.CreateDuration) == "function" and util.CreateDuration()
	if r.duration and pcall(r.duration.SetTimeFromStart, r.duration, GetTime(), duration) then
		r.swing:SetCooldownFromDurationObject(r.duration)
	elseif not IsSecret(duration) and type(duration) == "number" then
		r.swing:SetCooldown(GetTime(), duration)
	end
	if r.tick and Effects.Allows("pulse") then
		r.tick.play:Stop()
		r.tick.play:Play()
	end
end

local function Swung(_, duration, kind)
	local form = Trackers.state.form
	for _, p in pairs(form and form.pieces or {}) do
		if p.swing and p.spec.melee and p:IsShown() then
			Rings.Start(p, duration, kind, true)
		end
	end
end

local CLASS = UnitClass and select(2, UnitClass("player"))
local MELEE_FORMS = not IsSecret(CLASS) and MELEE[CLASS]
if MELEE_FORMS then
	Trackers.Register(CLASS, { { key = "crestSwing", seat = "rim", build = Rings.Swing, color = "steelLit", size = SWING, melee = true,
		known = function() return true end, choices = MELEE_FORMS ~= true and { { forms = MELEE_FORMS } } or nil } })
end

local function Ring(p, swipe)
	local c = p.add(CreateFrame("Cooldown", nil, p, "CooldownFrameTemplate"), EDGE)
	c:SetPoint("CENTER", p, "CENTER", 0, 0)
	c:SetSwipeTexture(ART .. "CastRing.png")
	c:SetDrawEdge(true)
	c:SetUseCircularEdge(true)
	c:SetDrawBling(false)
	c:SetHideCountdownNumbers(true)
	c:SetDrawSwipe(swipe == true)
	return c
end

local function Build(hub)
	local p = Medals.Piece(hub.top, hub.top:GetFrameLevel() + 1, EDGE)
	p.cast = Ring(p, true)
	p.spark = Ring(p)
	p.flash = p.add(Medals.Texture(p, "OVERLAY", 0, "ringLine16", "gilt", EDGE, "ADD"))
	p.flash:SetTexture(ART .. "CastRing.png")
	p.flash:SetAlpha(0)
	p.flash.play = Pop(p.flash, FLASH, "OUT")
	p.stop = p.cast:CreateAnimationGroup()
	for i, x in ipairs(SHAKE) do
		local move = p.stop:CreateAnimation("Translation")
		move:SetOffset(x, 0)
		move:SetDuration(FALL / 5)
		move:SetStartDelay((i - 1) * FALL / 5)
	end
	ns.Slab.Fade(p.stop, 1, 0, FALL):SetSmoothing("IN")
	p.stop:SetScript("OnFinished", function()
		p.cast:Clear()
		p.cast:SetPaused(false)
	end)
	return p
end

local function Times(channel)
	local info = channel and UnitChannelInfo or UnitCastingInfo
	if type(info) ~= "function" then
		return nil
	end
	local _, _, _, start, finish = info("player")
	if not (IsSecret(start) or IsSecret(finish)) and type(start) == "number" and type(finish) == "number" and finish > start then
		return start / 1000, (finish - start) / 1000
	end
end

local function Run(p, channel)
	p.stop:Stop()
	p.cast:SetPaused(false)
	p.cast:SetReverse(not channel)
	p.cast:SetSwipeColor(Tokens.Color("gilt"))
	p.spark:Clear()
	local start, length = Times(channel)
	if start then
		p.cast:SetCooldown(start, length)
	else
		local fn = channel and UnitChannelDuration or UnitCastingDuration
		local ok, duration = pcall(fn, "player")
		if not (fn and ok and duration ~= nil and pcall(p.cast.SetCooldownFromDurationObject, p.cast, duration, true)) then
			p.cast:Clear()
			return
		end
	end
	state.casting = channel and "channel" or "cast"
end

local function Cast(event)
	local p, kind = state.piece, CAST_EVENTS[event]
	if not (p and ns.Slab.hub:IsShown()) then
		return
	elseif kind == "cast" or kind == "channel" then
		return Run(p, kind == "channel")
	end
	local was = state.casting
	if not was or kind == "land" and (event == "UNIT_SPELLCAST_SUCCEEDED") ~= (was == "cast") then
		return
	end
	state.casting = nil
	if kind == "stop" and Effects.Allows("flare") then
		p.cast:SetPaused(true)
		p.cast:SetSwipeColor(Tokens.Color("hostile"))
		p.stop:Play()
		return
	end
	p.cast:Clear()
	if kind == "land" and Effects.Allows("flare") then
		p.flash.play:Stop()
		p.flash.play:Play()
		if Effects.ClaimFor("hub", Effects.PRIORITY.cast, PULSE) then
			ns.Slab.Pulse()
		end
	end
end

local function Gcd(_, id, _, _, recovery)
	local p, spell = state.piece, C_Spell
	if state.casting or not (p and spell and spell.GetSpellCooldown) or not (IsSecret(id) or IsSecret(recovery)) and id ~= nil and recovery == nil then
		return
	end
	local info = spell.GetSpellCooldown(GCD_SPELL)
	local duration = type(info) == "table" and info.isActive == true and spell.GetSpellCooldownDuration and spell.GetSpellCooldownDuration(GCD_SPELL)
	if duration then
		p.spark:SetCooldownFromDurationObject(duration)
	end
end

local function Listen(cast, spark)
	local ember, swing = state.enabled and EmberOn(), state.enabled and MELEE_FORMS and ns.Config("crestSwing") ~= false
	local key = table.concat({ tostring(state.enabled), tostring(cast), tostring(spark), tostring(ember), tostring(swing) }, ",")
	if state.listening == key then
		return
	end
	state.listening = key
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	Events.UnregisterAll(OWNER .. ".Cast")
	if not state.enabled then
		return
	end
	Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Rings.Update)
	Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", Rings.Update)
	if ember then
		Events.RegisterUnit(OWNER, "UNIT_AURA", Readable, "player", "target")
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Readable)
		Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Readable)
	end
	if swing then
		Events.Register(OWNER, "PLAYER_SWING", Swung)
	end
	for event in pairs(cast and CAST_EVENTS or {}) do
		Events.RegisterUnit(OWNER .. ".Cast", event, Cast, "player")
	end
	if spark then
		Events.Register(OWNER, "SPELL_UPDATE_COOLDOWN", Gcd)
	end
end

function Rings.Update()
	local hub = state.enabled and ns.Slab.hub
	local cast, spark = hub and ns.Config("crestCast") ~= false or false, hub and ns.Config("crestGcdSpark") == true or false
	if (cast or spark) and not state.piece and not Medals.Locked() then
		state.piece = Build(hub)
	end
	local p = state.piece
	Listen(cast and p ~= nil, spark and p ~= nil)
	if not p then
		return
	end
	Medals.Place(p, hub, 0, 0)
	p:SetShown(cast or spark)
	p.cast:SetShown(cast)
	p.spark:SetShown(spark)
	if not cast then
		p.cast:Clear()
		state.casting = nil
	end
end

local function OnSetting(_, module, key)
	if module ~= "ActionBars" or type(key) ~= "string" or not key:find("^crest") then
		return
	elseif key == "crestEmber" then
		for _, gate in ipairs(state.embers) do
			gate:SetAlpha(EmberOn() and 1 or 0)
		end
		Readable()
	end
	Rings.Update()
end

function Rings.SetEnabled(on)
	state.enabled = on
	if on and not state.hooked then
		state.hooked = true
		hooksecurefunc(ns.Slab, "Refresh", Rings.Update)
	end
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, OnSetting)
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
	end
	Rings.Update()
end
