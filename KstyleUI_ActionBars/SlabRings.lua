-- SlabRings.lua: the crest's ring-edge timing layers (docs/medallions-effects.md#ring-edge-timers): Expiring ember, an amber and a red swipe on every timer ring's own duration, each on an aura slot of its own, that stay dark until the timer's last fifth, then show amber, and red in its place in its last twelfth (a bright band just outside a medal or sigil, the ring's own line on a rim; delayed alpha animations armed from a start and length Lua could read, dark again when the timer changes under hidden values), with the token's flicker through that fifth while auras are readable out of combat and a gilt fade to steel from the game timer's own end; the melee swing ring, a fine steel line inside the rune band with a bright head and a soft white halo at each hit (a hunter's Auto Shot ring keeps its own look); the cast ring, a white-hot stroke in a gilt bloom round the crest's edge with a bright head, flashing and pulsing the crest when your own cast lands and shaking red when it is stopped; and the global cooldown spark, the same head alone round that edge.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Effects = K.Widgets, K.Tokens, K.Effects
local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
local Medals, Trackers = ns.SlabMedals, ns.SlabTrackers

local Rings = {}
ns.SlabRings = Rings

local ART = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Medallions\\Trackers\\"
local FIFTH, TWELFTH, FADE, LATE, BAND = 0.2, 1 / 12, 0.4, 0.5, 0.853
local INNER, SWING, EDGE, HALO = 112, 102, 145, 0.975 / 0.8
local TICK, FLASH, PULSE, SHAKE, FALL = 0.2, 0.25, 0.35, { 3, -5, 2 }, 0.3
local GCD_SPELL = 29515
local OWNER = "ActionBars.SlabRings"
local MELEE = { WARRIOR = true, PALADIN = true, ROGUE = true, SHAMAN = true, DRUID = { 1, 5, 8 } }
local CAST_EVENTS = {
	UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_DELAYED = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel", UNIT_SPELLCAST_CHANNEL_UPDATE = "channel",
	UNIT_SPELLCAST_SUCCEEDED = "land", UNIT_SPELLCAST_CHANNEL_STOP = "land", UNIT_SPELLCAST_INTERRUPTED = "stop", UNIT_SPELLCAST_FAILED = "stop",
	UNIT_SPELLCAST_STOP = "clear",
}
local NONE = {}
local state = { embers = {}, fed = {}, watched = {}, units = {} }
Rings.state = state

local function Pop(region, seconds)
	local group = region:CreateAnimationGroup()
	ns.Slab.Fade(group, 1, 0, seconds)
	return group
end

local function EmberOn()
	return ns.Config("crestEmber") ~= false
end

local function Head(c, scale)
	c:SetEdgeTexture(ART .. "RingBead.png", Widgets.Rgba("white", 1))
	c:SetEdgeScale(scale)
	c:SetUseCircularEdge(true)
	c:SetDrawEdge(true)
end

local function Track(piece, spec, ghost)
	local e = { piece = piece, spec = spec, unit = spec.unit or "player", ids = {}, fade = ghost and Pop(ghost, FADE), flicker = ghost and ns.Slab.Flicker(piece) }
	if ghost then ghost:SetAlpha(0) end
	for _, id in ipairs(spec.spells or NONE) do
		e.ids[id] = true
	end
	state.watched[#state.watched + 1] = e
	if not state.units[e.unit] then
		state.units[e.unit], state.listening = true, nil
		if state.enabled then Rings.Update() end
	end
	return e
end

Medals.Warn = Track

local function Delayed(frame, from, to)
	local group = frame:CreateAnimationGroup()
	group.fade = ns.Slab.Fade(group, from, to, 0)
	group:SetToFinalAlpha(true)
	return group
end

local function Late(parent, level)
	local late = Medals.Layer(parent, level)
	late:SetAlpha(0)
	late.show = Delayed(late, 0, 1)
	return late
end

local function Swipes(late, amber, red, art, level)
	red:SetAlpha(0)
	late.amber, late.red, late.leave, late.turn = amber, red, Delayed(amber, 1, 0), Delayed(red, 0, 1)
	local hot = Medals.Timer(amber, level, nil, "white", nil, ART .. "Ember" .. art .. "Amber.png")
	hot.red = Medals.Timer(red, level, nil, "white", nil, ART .. "Ember" .. art .. "Red.png")
	return hot
end

local function Arm(group, frame, wait, fade, final)
	if wait > 0 then
		group.fade:SetStartDelay(wait)
		group.fade:SetDuration(fade)
		group:Play()
	else
		frame:SetAlpha(final)
	end
end

local function Light(late, start, length)
	late.show:Stop()
	late:SetAlpha(0)
	late.start, late.length = start, length
	if start or not late.slotted then
		late.leave:Stop()
		late.turn:Stop()
	end
	if start then
		late.amber:SetAlpha(1)
		late.red:SetAlpha(0)
		local left, fade = start + length - (type(GetTime) == "function" and GetTime() or 0), Effects.Allows("flare") and Tokens.Flicker.step or 0
		Arm(late.show, late, left - length * FIFTH, fade, 1)
		Arm(late.leave, late.amber, left - length * TWELFTH, fade, 0)
		Arm(late.turn, late.red, left - length * TWELFTH, fade, 1)
	end
end

local function Known(start, length)
	return not (IsSecret(start) or IsSecret(length)) and type(start) == "number" and type(length) == "number" and length > 0
end

local function Douse(e)
	if e.late and e.lit then
		e.lit = nil
		Light(e.late)
	end
end

local function Ended(e)
	Douse(e)
	if e.fade and not e.fade:IsPlaying() and Effects.Allows("flare") and EmberOn() and e.piece:IsVisible() then
		e.fade:Play()
	end
end

local function Slots(piece, late, lit, spec, art, level, size)
	local first = Medals.Feed(Medals.Layer(late, level), spec, level)
	local second = spec.feed == "aura" and Medals.Feed(first, spec, level, first)
	lit.mirrors = lit.mirrors or {}
	lit.mirrors[#lit.mirrors + 1] = first
	local hot = Swipes(late, Medals.Layer(first, level), Medals.Layer(second or late, level), art, level + 1)
	first:SetDurationCooldown(hot)
	late.slotted = true
	if second then
		second:SetDurationCooldown(piece.add(hot.red, size))
	end
	hot.slot = first
	return hot
end

function Medals.Ember(piece, lit, timer, art, level, units)
	local band = art == "Band"
	local size = band and (units + 3) / BAND or units
	local gate, late, hot
	if lit and lit.container then
		gate = Medals.Layer(piece, level)
		late = Late(gate, level)
		hot = Slots(piece, late, lit, setmetatable({}, { __index = lit.spec }), art, level, size)
		local e = Track(piece, lit.spec, piece.add(Medals.Texture(Medals.Layer(piece, level + 1), "OVERLAY", 0, band and "medRing" or "ringLine16", "gilt", units, "ADD")))
		e.late = late
		hot:SetScript("OnCooldownDone", function() Ended(e) end)
	else
		gate = Medals.Layer(timer:GetParent(), timer:GetFrameLevel() + 1)
		late = Late(gate, gate:GetFrameLevel())
		hot = Swipes(late, Medals.Layer(late, gate:GetFrameLevel()), Medals.Layer(late, gate:GetFrameLevel()), art, gate:GetFrameLevel())
		hot:ClearAllPoints()
		hot:SetPoint("CENTER", timer, "CENTER", 0, 0)
		hot.red:SetAllPoints(hot)
		for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "Clear" }) do
			hooksecurefunc(timer, method, function(_, start, length, ...)
				hot[method](hot, start, length, ...)
				hot.red[method](hot.red, start, length, ...)
				if method == "SetCooldown" and Known(start, length) then Light(late, start, length) else Light(late) end
			end)
		end
		hot:SetScript("OnCooldownDone", function() Light(late) end)
		hot.Light = function(start, length)
			if Known(start, length) then Light(late, start, length) end
		end
		state.fed[#state.fed + 1] = late
	end
	gate:SetAlpha(EmberOn() and 1 or 0)
	state.embers[#state.embers + 1] = gate
	hot.units = size
	return hot
end

function Medals.EmberSlot(r, lit, family, size, level)
	local gate, band = r.add(Medals.Layer(r, level), size), (size + 3) / BAND
	local late = Late(gate, level)
	gate.timer = r.add(Slots(r, late, lit, setmetatable({ spells = family.spells, filter = "HELPFUL", newest = false }, { __index = lit.spec }), "Band", level, band), band)
	gate.slot = gate.timer.slot
	local e = Track(r, gate.slot.spec)
	e.late = late
	gate.timer:SetScript("OnCooldownDone", function() Ended(e) end)
	return gate
end

local function Pick(e)
	local get, best = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID, nil
	local mine = (e.spec.filter or ""):find("PLAYER", 1, true)
	for _, id in ipairs(get and e.spec.spells or NONE) do
		local a = get(e.unit, id)
		local at = type(a) == "table" and a.auraInstanceID
		if at and not (IsSecret(at) or IsSecret(a.sourceUnit)) and (not mine or a.sourceUnit == "player") and (not best or (at > best.auraInstanceID) == (e.spec.newest == true)) then
			best = a
		end
	end
	return best
end

local function Touches(e, info)
	if IsSecret(info) or type(info) ~= "table" or IsSecret(info.isFullUpdate) or info.isFullUpdate ~= false then
		return true
	end
	for _, a in ipairs(info.addedAuras or NONE) do
		if IsSecret(a.spellId) or e.ids[a.spellId] then return true end
	end
	for _, id in ipairs(info.updatedAuraInstanceIDs or NONE) do
		if IsSecret(id) or id == e.aura then return true end
	end
	for _, id in ipairs(info.removedAuraInstanceIDs or NONE) do
		if IsSecret(id) or id == e.aura then return true end
	end
	return false
end

local function Quiet(e)
	if e.flicker then e.flicker:Stop() end
	e.ends, e.due = nil, nil
end

local function Call(e, key, due, now)
	if e.called == key then
		return
	elseif due > now then
		if e.calling ~= key and C_Timer and C_Timer.After then
			e.calling = key
			C_Timer.After(due - now, function()
				if e.calling == key then
					e.calling = nil
					if not Medals.Locked() and e.piece:IsVisible() then Call(e, key, due, due) end
				end
			end)
		end
		return
	end
	e.called, e.calling = key, nil
	e.piece.recall()
end

local function Watch(e, now, pulse, ember)
	local a = Pick(e)
	local ends, length = a and a.expirationTime, a and a.duration
	e.aura = a and a.auraInstanceID
	if IsSecret(ends) or IsSecret(length) or type(ends) ~= "number" or type(length) ~= "number" or length <= 0 then
		if e.fade and ember and e.ends and now >= e.ends - LATE and Effects.Allows("flare") then
			e.fade:Stop()
			e.fade:Play()
		end
		Quiet(e)
		e.calling = nil
		Douse(e)
		return
	end
	local key = table.concat({ e.aura, ends, length, tostring(Effects.Allows("flare")) }, ":")
	if e.late and e.lit ~= (ember and key or nil) then
		e.lit = ember and key or nil
		Light(e.late, ember and ends - length or nil, length)
	end
	e.ends = ends
	local due = ends - length * FIFTH
	if e.piece.recall then
		Call(e, e.aura .. ":" .. ends, due, now)
	end
	if not (e.flicker and pulse and ember) then
		if e.flicker then e.flicker:Stop() end
		e.due = nil
	elseif e.due ~= due or due <= now and not e.flicker:IsPlaying() then
		e.flicker:Stop()
		e.due = due
		if due <= now then
			e.flicker:Play()
		elseif C_Timer and C_Timer.After then
			C_Timer.After(due - now, function()
				if e.due == due and not (Medals.Locked() or e.flicker:IsPlaying()) and Effects.Allows("pulse") and EmberOn() and e.piece:IsVisible() then
					e.flicker:Play()
				end
			end)
		end
	end
end

local function Calls()
	for _, e in ipairs(state.watched) do
		if e.piece.recall then return true end
	end
	return false
end

local function Readable(event, unit, info)
	local ember = EmberOn()
	if Medals.Locked() then
		if not state.quiet then
			state.quiet = true
			for _, e in ipairs(state.watched) do
				Quiet(e)
			end
		end
		for _, e in ipairs(state.watched) do
			if not ember or event == "UNIT_AURA" and unit == e.unit and Touches(e, info) or event == "PLAYER_TARGET_CHANGED" and e.unit == "target" then
				Douse(e)
			end
		end
		return
	end
	unit = event == "PLAYER_TARGET_CHANGED" and "target" or unit
	local full, now, pulse = state.quiet ~= false or unit == nil, type(GetTime) == "function" and GetTime() or 0, Effects.Allows("pulse")
	state.quiet = false
	for _, e in ipairs(state.watched) do
		if not (e.piece:IsVisible() and (ember or e.piece.recall)) then
			Quiet(e)
			Douse(e)
		elseif full or unit == e.unit and (event ~= "UNIT_AURA" or Touches(e, info)) then
			Watch(e, now, pulse, ember)
		end
	end
end

function Rings.Swing(parent, spec, level, form)
	local crest, melee = form == "crest", spec.melee == true
	local r = crest and Medals.Piece(parent, level, spec.size or INNER) or Medals.Medal(parent, { size = Medals.SIZE, texture = spec.texture }, level)
	r.swing = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
	r.swing:SetFrameLevel(level + 4)
	r.swing:SetAllPoints(r)
	r.swing:SetSwipeTexture(crest and melee and ART .. "SwingRing.png" or (Tokens.Texture(crest and "ringLine16" or "orbRing")))
	r.swing:SetSwipeColor(Tokens.Color(crest and melee and "white" or spec.color))
	r.swing:SetDrawEdge(false)
	r.swing:SetDrawBling(false)
	r.swing:SetHideCountdownNumbers(true)
	if crest and melee then
		Head(r.swing, 1.3)
		r.tick = r.add(Medals.Texture(r.swing, "OVERLAY", 0, "glow", "white", r.units * HALO, "ADD"))
		r.tick:SetTexture(ART .. "SwingHalo.png")
		r.tick:SetAlpha(0)
		r.tick.play = Pop(r.tick, TICK)
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
	for _, p in pairs(form and form.pieces or NONE) do
		if p.swing and p.spec.melee and p:IsVisible() then
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
	local c = p.add(Medals.Timer(p, p:GetFrameLevel() + 1, nil, "white", nil, ART .. "CastRing.png"), EDGE)
	c:SetDrawSwipe(swipe == true)
	Head(c, 1.6)
	return c
end

local function Build(hub)
	local p = Medals.Piece(hub.top, hub.top:GetFrameLevel() + 1, EDGE)
	p.cast = Ring(p, true)
	p.spark = Ring(p)
	p.flash = p.add(Medals.Texture(p, "OVERLAY", 0, "ringLine16", "white", EDGE, "ADD"))
	p.flash:SetTexture(ART .. "CastRing.png")
	p.flash:SetAlpha(0)
	p.flash.play = Pop(p.flash, FLASH)
	p.stop = p.cast:CreateAnimationGroup()
	for i, x in ipairs(SHAKE) do
		local move = p.stop:CreateAnimation("Translation")
		move:SetOffset(x, 0)
		move:SetDuration(FALL / 5)
		move:SetStartDelay((i - 1) * FALL / 5)
	end
	ns.Slab.Fade(p.stop, 1, 0, FALL)
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
	p.cast:SetSwipeColor(Tokens.Color("white"))
	p.spark:Clear()
	local start, length = Times(channel)
	if start then
		p.cast:SetCooldown(start, length)
	else
		local fn = channel and UnitChannelDuration or UnitCastingDuration
		if not pcall(function() p.cast:SetCooldownFromDurationObject(fn("player")) end) then
			p.cast:Clear()
			return
		end
	end
	state.casting = channel and "channel" or "cast"
end

local function Mine(guid, bar)
	if bar ~= nil or state.bar ~= nil then
		return bar == state.bar
	end
	return not (IsSecret(guid) or IsSecret(state.guid)) and guid == state.guid
end

local function Cast(event, _, guid, _, a, b)
	local p, kind = state.piece, CAST_EVENTS[event]
	local stopped = event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED"
	local bar, by = stopped and b or a, stopped and a or nil
	if not p:IsVisible() then
		return
	elseif kind == "cast" or kind == "channel" then
		state.guid, state.bar = guid, bar
		return Run(p, kind == "channel")
	end
	local was = state.casting
	if not was or not Mine(guid, bar) or kind == "land" and (event == "UNIT_SPELLCAST_SUCCEEDED") ~= (was == "cast") then
		return
	end
	if kind == "land" and (IsSecret(by) or by ~= nil) then
		kind = "stop"
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
	if state.casting or not (p:IsVisible() and spell and spell.GetSpellCooldown) or not (IsSecret(id) or IsSecret(recovery)) and id ~= nil and recovery == nil then
		return
	end
	local info = spell.GetSpellCooldown(GCD_SPELL)
	local duration = type(info) == "table" and info.isActive == true and spell.GetSpellCooldownDuration and spell.GetSpellCooldownDuration(GCD_SPELL)
	if duration then
		p.spark:SetCooldownFromDurationObject(duration)
	end
end

local function Listen(cast, spark)
	local ember, swing = state.enabled and (EmberOn() or Calls()) and next(state.units) ~= nil, state.enabled and MELEE_FORMS and ns.Config("crestSwing") ~= false
	local key = table.concat({ tostring(state.enabled), tostring(cast), tostring(spark), tostring(ember), tostring(swing) }, ",")
	if state.listening == key then
		return
	end
	state.listening = key
	local Events = K.Events
	Events.UnregisterAll(OWNER)
	Events.UnregisterAll(OWNER .. ".Aura")
	if not state.enabled then
		return
	end
	Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Rings.Update)
	Events.Register(OWNER, "ADDON_RESTRICTION_STATE_CHANGED", Rings.Update)
	if ember then
		local units = {}
		for unit in pairs(state.units) do
			units[#units + 1] = unit
		end
		table.sort(units)
		Events.RegisterUnit(OWNER, "UNIT_AURA", Readable, units[1], units[2])
		if units[3] then
			Events.RegisterUnit(OWNER .. ".Aura", "UNIT_AURA", Readable, units[3], units[4])
		end
		Events.Register(OWNER, "PLAYER_TARGET_CHANGED", Readable)
		Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Readable)
	end
	if swing then
		Events.Register(OWNER, "PLAYER_SWING", Swung)
	end
	for event in pairs(cast and CAST_EVENTS or NONE) do
		Events.RegisterUnit(OWNER, event, Cast, "player")
	end
	if spark then
		Events.Register(OWNER, "SPELL_UPDATE_COOLDOWN", Gcd)
	end
end

function Rings.Update()
	local hub = state.enabled and ns.Slab.hub
	local shown = hub and hub:IsShown() or false
	local cast, spark = shown and ns.Config("crestCast") ~= false, shown and ns.Config("crestGcdSpark") == true
	if (cast or spark) and not state.piece and not Medals.Locked() then
		state.piece = Build(hub)
	end
	local p = state.piece
	Listen(cast and p ~= nil, spark and p ~= nil)
	if p then
		if hub and not Medals.Locked() then
			Medals.Place(p, hub, 0, 0)
		end
		p:SetShown(cast or spark)
		p.cast:SetShown(cast)
		p.spark:SetShown(spark)
		if not cast then
			p.cast:Clear()
			p.stop:Stop()
			p.flash.play:Stop()
			state.casting = nil
		end
		if not spark then
			p.spark:Clear()
		end
	end
	Readable()
end

local function OnSetting(_, module, key)
	if module ~= "ActionBars" or type(key) ~= "string" or not key:find("^crest") then
		return
	elseif key == "crestEmber" then
		for _, gate in ipairs(state.embers) do
			gate:SetAlpha(EmberOn() and 1 or 0)
		end
	end
	Rings.Update()
end

local function OnMotion()
	for _, late in ipairs(state.fed) do
		if late.start then Light(late, late.start, late.length) end
	end
	Readable()
end

function Rings.SetEnabled(on)
	state.enabled = on
	if on and not state.hooked then
		state.hooked = true
		hooksecurefunc(ns.Slab, "Refresh", Rings.Update)
	end
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, OnSetting)
		K.Callbacks.Register("EffectsLevelChanged", OWNER, OnMotion)
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
		K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	end
	Rings.Update()
end
