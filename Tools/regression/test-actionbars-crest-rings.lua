-- test-actionbars-crest-rings.lua: the crest's ring-edge timing layers (KstyleUI_ActionBars/SlabRings.lua). Expiring ember: a medal's timer gets a white swipe of the ember band, sized just outside its rim, a rim and the cooldown ring a swipe of their own line, each fed the ring's own duration by a mirror of its slot; every cooldown sigil gets a second slot of its aura with the band; a Lua-fed timer hands its hot swipe every cooldown; under Frames too; the switch hides them. While auras are readable and out of combat a medal flickers through the last fifth of the aura its slot shows (the newest for the cooldown ring, a pet's aura on the pet), keeps its phase through unrelated aura changes, which read nothing, and fades a gilt ghost when the aura runs out; motion Off, combat, a hidden crest and secret auras stop it, and a pending start checks the motion again. The swing ring: every melee class gets a fine steel line 102 across (a druid in cat or bear form only) that each main-hand swing restarts from one duration object, with a bead head and a halo at Full, none at Calm, nothing for the off hand; a hunter's Auto Shot ring keeps its plain look; under Frames it is a medal; its switch removes it. The cast ring: your own cast fills the 145 edge from its own times (its duration object when they are secret), a channel drains; only the matching cast lands, flashing and pulsing the crest at the cast flash's priority, and an interrupted channel or stopped cast pauses red and shakes; Off clears at once; Frames clears a running cast, hears nothing and does not hold the spark; nothing is re-anchored in lockdown. The global cooldown spark is off by default; switched on, a global cooldown runs a bead edge that yields to a cast. Nothing runs OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SHOUT, RECKLESS, WALL = 6673, 1719, 871

local function New(class, known, opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			e._known = {}
			for _, id in ipairs(known or {}) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.IsSpellUsable = function() return false, false end
			e._gcdAsked = 0
			e.C_Spell.GetSpellCooldown = function(id) e._gcdAsked = e._gcdAsked + 1 return { isActive = id == 29515 and e._gcd == true, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 1.5 } end
			e.C_DurationUtil = { CreateDuration = function() e._durations = (e._durations or 0) + 1 return { SetTimeFromStart = function(d, s, l) d.start, d.length = s, l end } end }
			e.GetTime = function() return e._now or 0 end
			e._auraData, e._lookups = {}, 0
			e.C_UnitAuras = { GetUnitAuraBySpellID = function(unit, id) e._lookups = e._lookups + 1 return e._auraData[unit .. id] end }
			e.UnitCastingInfo = function() if e._cast then return "Shadow Bolt", "", 136197, e._cast[1], e._cast[2] end end
			e.UnitChannelInfo = function() if e._channel then return "Drain Life", "", 136169, e._channel[1], e._channel[2] end end
			e.UnitCastingDuration = function() return { start = 0, finish = 2.5 } end
			e.UnitChannelDuration = function() return { start = 0, finish = 5 } end
			e.Enum.PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
			e._form = opts.form
			e.GetShapeshiftFormID = function() return e._form end
		end,
	})
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

local function Piece(ns, key, form)
	local f = ns.SlabTrackers.state.forms[form or "crest"]
	for _, p in pairs(f and f.pieces or {}) do
		if p.spec and p.spec.key == key then return p end
	end
end

-- The hot swipe a lit's ember mirror drives, and the mirror's gate.
local function Hot(lit)
	for _, mirror in ipairs(lit.mirrors or {}) do
		local c = mirror._cooldown
		if c and tostring(c._state.SwipeTexture and c._state.SwipeTexture[1]):find("Ember", 1, true) then return c, mirror.container:GetParent():GetParent():GetParent() end
	end
end

local function Watched(ns, piece, unit)
	for _, e in ipairs(ns.SlabRings.state.watched) do
		if e.piece == piece and (not unit or e.unit == unit) then return e end
	end
end

local function Last(frame)
	return frame._calls[#frame._calls].method
end

local function Count(frame, method)
	local n = 0
	for _, c in ipairs(frame._calls) do
		if c.method == method then n = n + 1 end
	end
	return n
end

-- Level(frame, group, now): the alpha a delayed fade leaves its frame at, at a moment of the stub clock: the frame's own alpha until the fade's start delay has run, the
-- fade's end from then on, and a straight line between the two while it runs.
local function Level(frame, group, now)
	local fade = group.fade
	local t = group._playedAt and now - group._playedAt - fade._state.StartDelay[1]
	if not t or t < 0 then
		return frame:GetAlpha()
	end
	local from, to, length = fade._state.FromAlpha[1], fade._state.ToAlpha[1], fade._state.Duration[1]
	return t >= length and to or from + (to - from) * t / length
end

-- Colours(late, now) -> how strongly the amber and the red swipe draw at that moment.
local function Colours(late, now)
	local cap = Level(late, late.show, now)
	return cap * Level(late.amber, late.leave, now), cap * Level(late.red, late.turn, now)
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do n = n + Updating(child) end
	return n
end

-- The art SlabRings names by path ships.
for _, file in ipairs({ "EmberBandAmber.png", "EmberBandRed.png", "EmberRingLine16Amber.png", "EmberRingLine16Red.png", "CastRing.png", "SwingRing.png", "SwingHalo.png", "RingBead.png" }) do
	local handle = io.open("Media/Textures/Medallions/Trackers/" .. file, "rb")
	assert(handle, file .. " is missing; run python3 Tools/media/crest_rings.py")
	handle:close()
end

-- Expiring ember on a warrior's cooldown ring and sigils; Battle Shout's horn and Enrage's cracks warn through their last fifth on themselves (they drain as objects and along their own art, with no 112 line).
do
	local env, K, ns = New("WARRIOR", { SHOUT, 2687, RECKLESS, WALL })
	local shout, rim, cooldowns = Piece(ns, "crestShout"), Piece(ns, "crestEnrage"), Piece(ns, "crestCooldowns")
	local hot, gate = Hot(cooldowns.lit)
	assert(hot and tostring(hot._state.SwipeTexture[1]):find("EmberRingLine16Amber.png", 1, true), "the cooldown ring gets the thin ring's amber ember")
	assert(tostring(hot.red._state.SwipeTexture[1]):find("EmberRingLine16Red.png", 1, true), "and a second swipe of its red one: the two colours are separate art, never one painted over the other")
	local lits, cap = hot.slots, gate._kids[1]
	assert(lits[1]._cooldown == hot and lits[2]._cooldown == hot.red and lits[1].container ~= lits[2].container, "each swipe is the duration cooldown of a slot of its own, each in its own container")
	assert(lits[1].container:GetParent() == cap.amber and lits[2].container:GetParent() == cap.red and cap.amber:GetParent() == cap and cap.red:GetParent() == cap,
		"each container sits in a layer of the addon's own, so the addon can change either colour while it may not touch the slots")
	assert(lits[1].container._slots.lit.newest == true and lits[2].container._slots.lit.newest == true, "both slots pick the newest cooldown, as the ring's own slot does")
	assert(not Hot(rim.lit) and Watched(ns, rim), "Enrage's cracks keep no ember on the 112 line and warn on themselves")
	for _, sigil in ipairs(cooldowns.sigils) do
		assert(sigil.ember and tostring(sigil.ember.timer._state.SwipeTexture[1]):find("EmberBandAmber.png", 1, true) and tostring(sigil.ember.timer.red._state.SwipeTexture[1]):find("EmberBandRed.png", 1, true),
			"every cooldown sigil has its amber and red bands")
		local watch, slots = Watched(ns, sigil.ember.slot.spec and cooldowns), sigil.ember.slots
		assert(#slots == 2 and not slots[1].container._slots.lit.newest and not slots[2].container._slots.lit.newest and not sigil.container._slots[sigil.key].newest,
			"a sigil's ember slots sort as the sigil's own slot does, so both show the same aura")
		assert(watch, "the ring is watched")
	end
	for _, e in ipairs(ns.SlabRings.state.watched) do
		if e.piece == cooldowns and e.spec.newest == false then
			assert(e.flicker == nil and e.fade == nil and e.late, "a sigil's watch times its colours only: no flicker and no ghost of its own to schedule")
		end
	end
	Slots.Set(env, "player", { { id = RECKLESS, start = 0, duration = 120 } })
	local d = hot._state.CooldownFromDurationObject and hot._state.CooldownFromDurationObject[1]
	assert(d and d.start == 0 and d.finish == 120, "the ember swipe drains on the cooldown's own duration")
	assert(gate:GetAlpha() == 1, "on by default")
	K.Options.Write("ActionBars", "crestEmber", false)
	env.RunTimers()
	assert(gate:GetAlpha() == 0 and select(2, Hot(cooldowns.lit)):GetAlpha() == 0, "its switch hides every ember swipe")
	local sigil = cooldowns.sigils[1]
	local amber, red = sigil.ember.slots[1].container._slots.lit, sigil.ember.slots[2].container._slots.lit
	assert(amber.disabled and red.disabled, "and turns the sigil bands' slots off")
	K.Options.Write("ActionBars", "crestEmber", true)
	env.RunTimers()
	assert(gate:GetAlpha() == 1 and not amber.disabled and not red.disabled, "and brings them back")
	-- Readable: the last fifth flickers the horn, an expiry fades its gilt glow to steel.
	local watched = Watched(ns, shout)
	env._now = 100
	env._auraData["player" .. SHOUT] = { auraInstanceID = 1, expirationTime = 200, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(not watched.flicker:IsPlaying(), "100 s of 120 left: no flicker")
	env._auraData["player" .. SHOUT] = { auraInstanceID = 1, expirationTime = 110, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(watched.flicker:IsPlaying(), "10 s of 120 left: the horn flickers")
	local phase, lookups = watched.flicker._playedAt, env._lookups
	env._now = 101
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = 774, auraInstanceID = 50 } } })
	assert(watched.flicker._playedAt == phase and env._lookups == lookups, "an unrelated aura reads nothing and keeps the flicker's phase")
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 1 } })
	assert(watched.flicker._playedAt == phase and env._lookups > lookups, "an update to the watched aura re-reads it and still keeps the phase")
	K.Options.Write("Medallions", "motion", "off")
	assert(not watched.flicker:IsPlaying() and not (watched.flicker.still and watched.flicker.still:IsPlaying()), "motion Off stops the flicker and shows no mark")
	K.Options.Write("Medallions", "motion", "full")
	assert(watched.flicker:IsPlaying(), "and Full brings it back")
	env._combat = true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(not watched.flicker:IsPlaying(), "combat stops the flicker even while auras are readable")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(watched.flicker:IsPlaying(), "and leaving combat re-reads the timer")
	env._now = 110
	env._auraData["player" .. SHOUT] = nil
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 1 } })
	assert(not watched.flicker:IsPlaying() and watched.fade:IsPlaying(), "it ran out: the flicker stops and the gilt glow fades to steel")
	-- A start still pending when motion turns Off stays off.
	env._now = 120
	env._auraData["player" .. SHOUT] = { auraInstanceID = 2, expirationTime = 240, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	K.Store.Module("Medallions").motion = "off"
	env._now = 220
	env.RunTimers()
	assert(not watched.flicker:IsPlaying(), "a pending start checks the motion level again")
	K.Store.Module("Medallions").motion = "full"
	-- The cooldown ring watches the newest cooldown, as its slot shows.
	local ring = Watched(ns, cooldowns, "player")
	env._auraData["player" .. RECKLESS] = { auraInstanceID = 5, expirationTime = 221, duration = 15, sourceUnit = "player" }
	env._auraData["player" .. WALL] = { auraInstanceID = 9, expirationTime = 295, duration = 10, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(ring.ends == 295, "the newest cooldown is the one the ring warns about (" .. tostring(ring.ends) .. ")")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	-- In combat auras are secret: the flicker stops and nothing touches an aura button.
	env._combat, env._aurasSecret = true, true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	env.FireEvent("UNIT_AURA", "player")
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	K.Options.Write("ActionBars", "crestEmber", false)
	K.Options.Write("ActionBars", "crestEmber", true)
	assert(not watched.flicker:IsPlaying(), "in combat the flicker stops")
	Clean(env, K, "ember in combat")
	-- A Lua-fed timer hands its hot swipe each cooldown it gets.
	local holder = env.CreateFrame("Frame", nil, ns.Slab.hub)
	local timer = env.CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
	local lua = ns.SlabMedals.Ember(holder, nil, timer, "Band", 5, 26)
	timer:SetCooldown(50, 8)
	local start, length = lua._state.Cooldown[1], lua._state.Cooldown[2]
	assert(start == 50 and length == 8 and math.abs(lua.units - (26 + 3) / 0.853) < 1e-6, "a Lua-fed timer's cooldown reaches its ember swipe")
	timer:Clear()
	assert(Last(lua) == "Clear", "and its clear")
	-- A Lua-fed timer lights its cap late from the start and length it was given, and gets none from a duration object it cannot read.
	local late = lua:GetParent():GetParent()
	env._now = 50
	timer:SetCooldown(50, 12)
	assert(lua.red._state.Cooldown[1] == 50 and lua.red._state.Cooldown[2] == 12, "the red swipe gets the same cooldown")
	local step = K.Tokens.Flicker.step
	assert(late:GetAlpha() == 0 and late.show:IsPlaying() and math.abs(late.show.fade._state.StartDelay[1] - 9.6) < 1e-6 and math.abs(late.turn.fade._state.StartDelay[1] - 11) < 1e-6
		and math.abs(late.leave.fade._state.StartDelay[1] - (11 - step)) < 1e-6, "a fresh 12 s timer shows no cap: amber waits 9.6 s for the last fifth and has faded out by 11 s, the last twelfth, where red starts")
	-- The running timer, with nothing set again: the clock alone moves, and at no moment do both colours draw.
	for _, span in ipairs({ 12, 1.5, 0.5 }) do
		env._now = 50
		timer:SetCooldown(50, span)
		local sawAmber, sawRed
		for i = 0, 400 do
			local now = 50 + span * i / 400
			local a, r = Colours(late, now)
			local left = (50 + span - now) / span
			assert(not (a > 0 and r > 0), "a running " .. span .. " s timer never draws amber under red (" .. left .. " of it left)")
			assert(left <= 0.2 + 1e-9 or a + r == 0, "nor any warning colour before its last fifth")
			assert(left > 1 / 12 - 1e-9 or a == 0, "and no amber inside its last twelfth")
			sawAmber, sawRed = sawAmber or a > 0, sawRed or r > 0
		end
		assert(sawRed and sawAmber, "a running " .. span .. " s timer does reach its colours")
		-- Each fade takes at most a quarter of the time its colour has, so a short timer shows both at full strength too.
		local a, r = Colours(late, 50 + span * 0.85)
		assert(a == 1 and r == 0, "15 percent of " .. span .. " s left: amber alone, at full strength (" .. a .. ")")
		a, r = Colours(late, 50 + span * 0.95)
		assert(a == 0 and r == 1, "5 percent of " .. span .. " s left: red alone, at full strength (" .. r .. ")")
	end
	env._now = 50
	timer:SetCooldown(50, 12)
	timer:SetCooldownFromDurationObject({})
	assert(late:GetAlpha() == 0 and not late.show:IsPlaying() and not late.turn:IsPlaying() and not late.leave:IsPlaying(), "a timer whose length is unreadable gets no cap at all, and nothing stays armed")
	env._now = 60
	timer:SetCooldown(50, 12)
	assert(late:GetAlpha() == 1 and late.amber:GetAlpha() == 1 and late.red:GetAlpha() == 0 and not late.show:IsPlaying() and late.turn:IsPlaying() and late.leave:IsPlaying(),
		"2 s of 12 left: amber shows at once and red not yet")
	env._now = 61.5
	timer:SetCooldown(50, 12)
	assert(late:GetAlpha() == 1 and late.amber:GetAlpha() == 0 and late.red:GetAlpha() == 1, "0.5 s of 12 left: red alone, the amber swipe gone")
	lua:GetScript("OnCooldownDone")(lua)
	assert(late:GetAlpha() == 0 and not late.turn:IsPlaying(), "the timer's end darkens the cap for the next timer")
	-- A Lua-fed cap follows the motion level without waiting for its next cooldown.
	env._now = 50
	timer:SetCooldown(50, 12)
	K.Options.Write("Medallions", "motion", "off")
	assert(late.show:IsPlaying() and late.show.fade._state.Duration[1] == 0, "switching to Off re-arms a pending step as a cut")
	K.Options.Write("Medallions", "motion", "full")
	assert(late.show.fade._state.Duration[1] == K.Tokens.Flicker.step, "and Full brings its fade back")
end

-- The crest plan's late end warning: an aura's ember stays dark until the timer's last fifth, turns amber there and red in its last twelfth, darkens again on a refresh, goes dark
-- when the aura changes under hidden values, and its gilt ghost fades from the game timer's own end.
do
	local env, K, ns = New("WARRIOR", { SHOUT, 2687, RECKLESS, WALL })
	local cooldowns = Piece(ns, "crestCooldowns")
	local ring, hot = Watched(ns, cooldowns, "player"), Hot(cooldowns.lit)
	local late, done = ring.late, hot:GetScript("OnCooldownDone")
	local function Aura(now, ends, length, id)
		length = length or 120
		env._now = now
		Slots.Set(env, "player", { { id = RECKLESS, start = ends - length, duration = length } })
		env._auraData["player" .. RECKLESS] = { auraInstanceID = id or 5, expirationTime = ends, duration = length, sourceUnit = "player" }
		env.FireEvent("UNIT_AURA", "player")
	end
	local function Delay(group)
		return group.fade._state.StartDelay[1]
	end
	Aura(100, 220)
	assert(late:GetAlpha() == 0 and late.show:IsPlaying() and late.leave:IsPlaying() and late.turn:IsPlaying(), "a fresh 120 s timer shows no cap and arms every step")
	assert(math.abs(Delay(late.show) - 96) < 1e-6 and math.abs(Delay(late.turn) - 110) < 1e-6 and math.abs(Delay(late.leave) - (110 - K.Tokens.Flicker.step)) < 1e-6,
		"amber waits 96 s for the last fifth and is gone by 110 s, the last twelfth, where red starts")
	for i = 0, 480 do
		local a, r = Colours(late, 100 + i / 4)
		assert(not (a > 0 and r > 0) and (i / 4 >= 96 or a + r == 0), "the running aura timer never draws both colours, and none before its last fifth")
	end
	assert(late.show.fade._state.Duration[1] == K.Tokens.Flicker.step and late.show._state.ToFinalAlpha[1] == true, "each step fades over the flicker's step and holds its end")
	Aura(300, 320)
	assert(late:GetAlpha() == 1 and late.amber:GetAlpha() == 1 and late.red:GetAlpha() == 0 and not late.show:IsPlaying(), "20 s of 120 left: amber alone")
	assert(math.abs(Delay(late.turn) - 10) < 1e-6, "and red is 10 s away")
	Aura(300, 305)
	assert(late:GetAlpha() == 1 and late.amber:GetAlpha() == 0 and late.red:GetAlpha() == 1, "5 s of 120 left: red alone, with no amber under it")
	Aura(300, 420)
	assert(late:GetAlpha() == 0 and late.show:IsPlaying(), "a refresh darkens the cap and arms it again")
	-- The schedule follows every input it was worked out from: a replacement or a new length with the same end, and the motion level, each re-arm it.
	assert(math.abs(Delay(late.show) - 96) < 1e-6, "120 s left of 120: amber is 96 s away")
	Aura(300, 420, 60)
	assert(math.abs(Delay(late.show) - 108) < 1e-6 and math.abs(Delay(late.turn) - 115) < 1e-6, "the same end on a 60 s timer moves the steps to its own last fifth and twelfth")
	Aura(300, 420, 60, 6)
	assert(ring.aura == 6 and late.show:IsPlaying() and math.abs(Delay(late.show) - 108) < 1e-6, "a replacement that ends at the same moment is timed afresh")
	K.Options.Write("Medallions", "motion", "off")
	assert(late.show:IsPlaying() and late.show.fade._state.Duration[1] == 0, "switching to Off re-arms the pending steps as cuts, with no new aura event")
	K.Options.Write("Medallions", "motion", "calm")
	assert(late.show.fade._state.Duration[1] == K.Tokens.Flicker.step and late.show:IsPlaying(), "Calm keeps the late cap and its fade")
	K.Options.Write("Medallions", "motion", "full")
	-- An older cooldown that ends while a newer one is up: the ring keeps timing the newer one, the one its slot shows.
	env._auraData["player" .. WALL] = { auraInstanceID = 3, expirationTime = 301, duration = 10, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(ring.aura == 6 and late:GetAlpha() == 0, "an older cooldown inside its own last fifth lights nothing on the newer one's ring")
	env._auraData["player" .. WALL] = nil
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 3 } })
	assert(ring.aura == 6 and late:GetAlpha() == 0 and late.show:IsPlaying(), "and its end leaves the newer one's schedule alone")
	Aura(400, 420)
	env._combat, env._aurasSecret = true, true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(late:GetAlpha() == 1, "entering combat keeps a cap that was already timed")
	-- The steps still pending follow the motion level under hidden values too: they sit on the addon's own layers, outside the slots.
	K.Options.Write("Medallions", "motion", "off")
	assert(late:GetAlpha() == 1 and late.turn:IsPlaying() and late.turn.fade._state.Duration[1] == 0 and late.leave.fade._state.Duration[1] == 0 and math.abs(Delay(late.turn) - 10) < 1e-6,
		"switching to Off in combat re-arms the pending change to red as a cut")
	K.Options.Write("Medallions", "motion", "full")
	assert(late.turn.fade._state.Duration[1] == K.Tokens.Flicker.step, "and Full brings the fade back")
	Clean(env, K, "late ember motion in combat")
	env.FireEvent("UNIT_AURA", "player", env.Secret({ updatedAuraInstanceIDs = { 5 } }))
	assert(late:GetAlpha() == 0 and not late.show:IsPlaying(), "an aura change it cannot read darkens the cap from outside the slots, which Lua may not touch now: no cap beats a wrong one")
	assert(not ring.fade:IsPlaying(), "nothing fades before the timer ends")
	done(hot)
	assert(ring.fade:IsPlaying(), "under hidden values the game timer's end fades the gilt ghost instead of cutting")
	ring.fade:Stop()
	K.Options.Write("Medallions", "motion", "off")
	done(hot)
	assert(not ring.fade:IsPlaying(), "at Off the end fades nothing")
	Clean(env, K, "late ember")
end

-- Two cooldowns of one sigil family at once (a paladin's two ranks of Divine Shield): the sigil's own slot, both its ember slots and the warning's schedule follow the same one.
do
	local env, K, ns = New("PALADIN", { 642, 1020 })
	local cooldowns = Piece(ns, "crestCooldowns")
	local sigil
	for _, s in ipairs(cooldowns.sigils) do
		if s.family.spells[1] == 642 then sigil = s end
	end
	assert(sigil and sigil.family.spells[1] == 642 and sigil.family.spells[2] == 1020, "the Divine Shield sigil covers both ranks")
	local watch
	for _, e in ipairs(ns.SlabRings.state.watched) do
		if e.spec == sigil.ember.slot.spec then watch = e end
	end
	local late = assert(watch and watch.late, "the sigil's ember has its own watch")
	env._now = 100
	Slots.Set(env, "player", { { id = 642, start = 90, duration = 12 }, { id = 1020, start = 100, duration = 30 } })
	env._auraData["player642"] = { auraInstanceID = 3, expirationTime = 102, duration = 12, sourceUnit = "player" }
	env._auraData["player1020"] = { auraInstanceID = 8, expirationTime = 130, duration = 30, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	local shown = sigil.container._slots[sigil.key].aura
	assert(shown and shown.id == 642, "the sigil shows the older of the two, as its slot sorts")
	assert(sigil.ember.slots[1].container._slots.lit.aura == shown and sigil.ember.slots[2].container._slots.lit.aura == shown, "both ember slots drain on that same aura")
	assert(watch.aura == 3 and late.start == 90 and late.length == 12, "and the warning is timed from it, not from the newer rank")
	assert(late:GetAlpha() == 1 and late.turn:IsPlaying() and math.abs(late.turn.fade._state.StartDelay[1] - 1) < 1e-6, "2 s of its 12 left: amber shows now and red is 1 s away, on the shown aura's own clock")
	Clean(env, K, "sigil family")
end

-- Calm keeps every readable expiry warning as a still mark: the armory's horn, a rim's own art and the cooldown ring each hold at the flicker's low alpha through the last
-- fifth instead of going dark, straight away and from a start that was still pending; Off shows neither.
do
	local env, K, ns = New("WARRIOR", { SHOUT, 2687, RECKLESS, WALL })
	local cases = { { Piece(ns, "crestShout"), SHOUT, "the horn" }, { Piece(ns, "crestEnrage"), nil, "the rim" }, { Piece(ns, "crestCooldowns"), RECKLESS, "the cooldown ring" } }
	for _, case in ipairs(cases) do
		local piece, what = case[1], case[3] .. ": "
		local e = assert(Watched(ns, piece, "player"), what .. "watched")
		local id = case[2] or e.spec.spells[1]
		local flicker = assert(e.flicker, what .. "it warns on itself")
		local function Seen(now, ends)
			env._now = now
			env._auraData["player" .. id] = { auraInstanceID = 1, expirationTime = ends, duration = 120, sourceUnit = "player" }
			env.FireEvent("UNIT_AURA", "player")
		end
		K.Options.Write("Medallions", "motion", "full")
		Seen(100, 110)
		assert(flicker:IsPlaying(), what .. "Full flickers through the last fifth")
		K.Options.Write("Medallions", "motion", "calm")
		local still = assert(flicker.still, what .. "Calm makes the still mark")
		assert(still:IsPlaying() and not flicker:IsPlaying(), what .. "Calm trades the flicker for the still mark without a new aura event")
		local hold = still._anims[1]
		assert(#still._anims == 1 and hold._state.FromAlpha[1] == hold._state.ToAlpha[1] and hold._state.ToAlpha[1] == flicker._anims[1]._state.ToAlpha[1],
			what .. "the mark holds the piece at the flicker's low alpha and never moves")
		Seen(100, 220)
		assert(not still:IsPlaying(), what .. "a refresh drops the mark")
		env._now = 200
		env.RunTimers()
		assert(still:IsPlaying() and not flicker:IsPlaying(), what .. "and the pending start brings the mark, not the flicker, at Calm")
		K.Options.Write("Medallions", "motion", "off")
		assert(not still:IsPlaying() and not flicker:IsPlaying(), what .. "Off shows neither")
		env._auraData["player" .. id] = nil
		env.FireEvent("UNIT_AURA", "player")
	end
	Clean(env, K, "calm warnings")
end

-- A medal's ember is the bright band just outside its rim; under Frames the horn in the row warns as on the crest, and the hidden crest reads nothing.
do
	local env, K, ns = New("WARRIOR", { SHOUT })
	local medal = ns.SlabMedals.Medal(ns.Slab.hub, { feed = "aura", spells = { SHOUT }, color = "gilt", texture = 132333 }, 10)
	local hot = Hot(medal.lit)
	assert(hot and tostring(hot._state.SwipeTexture[1]):find("EmberBandAmber.png", 1, true) and tostring(hot.red._state.SwipeTexture[1]):find("EmberBandRed.png", 1, true), "a medal's ember is the bright band, amber and red")
	local r, g, b = unpack(hot._state.SwipeColor)
	assert(r == 1 and g == 1 and b == 1 and math.abs(hot.units - (26 + 3) / 0.853) < 1e-6, "drawn white, its band just outside the 26-unit medal's rim")
	local watched = Watched(ns, Piece(ns, "crestShout"))
	env._now = 100
	env._auraData["player" .. SHOUT] = { auraInstanceID = 1, expirationTime = 110, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(watched.flicker:IsPlaying(), "the crest's horn flickers")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(not watched.flicker:IsPlaying(), "switching to Frames stops the hidden crest's flicker")
	local row = Piece(ns, "crestShout", "row")
	assert(row and Watched(ns, row), "the horn in the Frames row warns too")
	local lookups = env._lookups
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = SHOUT, auraInstanceID = 3 } } })
	local crest = 0
	for _, e in ipairs(ns.SlabRings.state.watched) do
		if e.piece:GetParent() == ns.SlabTrackers.state.forms.crest.frame and e.ends then crest = crest + 1 end
	end
	assert(crest == 0 and env._lookups - lookups <= #Watched(ns, row).spec.spells + 1, "only the shown row horn (and the loose medal) read their spells; the hidden crest reads nothing (" .. env._lookups - lookups .. " lookups)")
	Clean(env, K, "ember under Frames")
end

-- A hunter's pet aura is watched on the pet.
do
	local env, K, ns = New("HUNTER", { 3045, 19574, 75 })
	local cooldowns = Piece(ns, "crestCooldowns")
	local pet = Watched(ns, cooldowns, "pet")
	assert(pet, "the pet's cooldown slot is watched on the pet")
	env._now = 100
	env._auraData["pet19574"] = { auraInstanceID = 4, expirationTime = 101, duration = 15, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "pet")
	assert(pet.flicker:IsPlaying(), "Bestial Wrath's last fifth flickers from the pet's own aura event")
	Clean(env, K, "pet ember")
end

-- The swing ring for every melee class.
for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE", "SHAMAN" }) do
	local env, K, ns = New(class, {})
	local ring = Piece(ns, "crestSwing")
	assert(ring and ring:IsShown() and ring.units == 102, class .. ": a swing ring 102 across sits inside the rune band, clear of a 112 rim")
	local r, g, b = unpack(ring.swing._state.SwipeColor)
	assert(r == 1 and g == 1 and b == 1 and tostring(ring.swing._state.SwipeTexture[1]):find("SwingRing.png", 1, true), class .. ": its own fine steel line in a dark channel, tinted white")
	Clean(env, K, class .. " swing")
end
do
	local env, K, ns = New("ROGUE", {})
	local ring = Piece(ns, "crestSwing")
	env._now = 10
	for _ = 1, 3 do env.FireEvent("PLAYER_SWING", env.Secret(1.8), 0) end
	local d = ring.swing._state.CooldownFromDurationObject[1]
	assert(d.start == 10 and env.issecretvalue(d.length) and env._durations == 1, "each main-hand swing restarts the ring from one duration object")
	assert(ring.tick.play:IsPlaying() and tostring(ring.tick:GetTexture()):find("SwingHalo.png", 1, true), "a soft halo at the hit")
	assert(ring.swing._state.DrawEdge[1] == true and tostring(ring.swing._state.EdgeTexture[1]):find("RingBead.png", 1, true), "and a bead head on the rim")
	ring.tick.play:Stop()
	env._now = 12
	env.FireEvent("PLAYER_SWING", 1.6, 1)
	assert(ring.swing._state.CooldownFromDurationObject[1].start == 10 and not ring.tick.play:IsPlaying(), "the off hand changes nothing")
	K.Options.Write("Medallions", "motion", "calm")
	env.FireEvent("PLAYER_SWING", 1.8, 0)
	assert(ring.swing._state.CooldownFromDurationObject[1].start == 12 and not ring.tick.play:IsPlaying(), "Calm keeps the ring and drops the halo")
	K.Options.Write("ActionBars", "crestSwing", false)
	env.RunTimers()
	assert(not ring:IsVisible(), "its switch removes the ring")
	Clean(env, K, "rogue swing")
end
do
	local env, K, ns = New("HUNTER", { 75 })
	K.Options.Write("ActionBars", "crestSwing", false)
	local ring = Piece(ns, "crestAutoShot")
	env.FireEvent("PLAYER_SWING", 2.8, 2)
	assert(ring.swing._state.DrawEdge[1] == false and not ring.tick and tostring(ring.swing._state.SwipeTexture[1]):find("RingLine16.png", 1, true),
		"a hunter's Auto Shot ring keeps its plain look: no head, no halo, its own line")
	Clean(env, K, "hunter parity")
end
do
	local env, K, ns = New("DRUID", {})
	local ring = Piece(ns, "crestSwing")
	assert(ring and not ring:IsShown(), "a druid in caster form has no swing ring")
	env._form = 1
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(ring:IsShown(), "in Cat Form it shows")
	Clean(env, K, "druid swing")
end
do
	local env, K, ns = New("WARRIOR", {}, { frames = true })
	local medal = Piece(ns, "crestSwing", "row")
	assert(medal and medal:IsShown() and medal.swing and not medal.steel:GetTexture(), "under Frames the swing ring is a medal with a sweep and no spell icon")
	env.FireEvent("PLAYER_SWING", 2.6, 0)
	assert(medal.swing._state.CooldownFromDurationObject, "which each swing restarts")
	Clean(env, K, "swing under Frames")
end

-- The cast ring and the global cooldown spark.
do
	local env, K, ns = New("MAGE", {})
	local p = ns.SlabRings.state.piece
	assert(p and p:IsShown() and p.cast:IsShown() and p.units == 145, "the cast ring sits on the crest's 145 edge")
	assert(tostring(p.cast._state.SwipeTexture[1]):find("CastRing.png", 1, true) and tostring(p.cast._state.EdgeTexture[1]):find("RingBead.png", 1, true), "a bright stroke with a bead head")
	assert(not p.spark:IsShown() and K.Store.Module("ActionBars").crestGcdSpark ~= true, "the global cooldown spark is off by default")
	env._cast = { 100000, 102500 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-A", 686, 8)
	local start, length = p.cast._state.Cooldown[1], p.cast._state.Cooldown[2]
	assert(start == 100 and length == 2.5 and p.cast._state.Reverse[1] == true, "a cast fills the edge clockwise over its own times")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-B", 1953, 9)
	env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-C", 1953, 10)
	assert(ns.SlabRings.state.casting == "cast" and Last(p.cast) == "SetCooldown" and not p.flash.play:IsPlaying(), "another spell succeeding or failing mid-cast does not end it")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-A", 686, 8)
	assert(Last(p.cast) == "Clear" and p.flash.play:IsPlaying() and K.Effects.Holder("hub") == K.Effects.PRIORITY.cast and ns.Slab.hub.crest.pulse:IsPlaying(),
		"your cast landing clears the ring, flashes it and pulses the crest at the cast flash's priority")
	env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-A", 686, 8)
	p.flash.play:Stop()
	env._cast = nil
	env._channel = { 200000, 205000 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-D", 689, 11)
	assert(p.cast._state.Reverse[1] == false and p.cast._state.Cooldown[1] == 200, "a channel drains the other way")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-D", 689, 11)
	assert(ns.SlabRings.state.casting == "channel" and not p.flash.play:IsPlaying(), "a channel's start does not land it")
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-D", 689, "Creature-0-1", 11)
	local r, g, b = K.Tokens.Color("hostile")
	assert(not p.flash.play:IsPlaying() and p.cast._state.Paused[1] == true and p.cast._state.SwipeColor[1] == r and p.cast._state.SwipeColor[2] == g and p.cast._state.SwipeColor[3] == b and p.stop:IsPlaying(),
		"an interrupted channel pauses red and shakes, with no success flash")
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-E", 689, 12)
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-E", 689, nil, 12)
	assert(p.flash.play:IsPlaying(), "a channel that runs out lands")
	p.flash.play:Stop()
	env._channel = nil
	env._cast = { env.Secret(1), env.Secret(2) }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-F", 686, 13)
	assert(p.cast._state.CooldownFromDurationObject[1].finish == 2.5 and p.cast._state.Paused[1] == false and not p.stop:IsPlaying(), "secret times run the ring on the cast's duration object")
	K.Options.Write("Medallions", "motion", "off")
	env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Cast-F", 686, 13)
	assert(Last(p.cast) == "Clear" and not p.stop:IsPlaying(), "Off shows the end state: a failed cast just clears")
	K.Options.Write("Medallions", "motion", "full")
	-- The spark: on, a global cooldown runs it; it yields to a cast.
	K.Options.Write("ActionBars", "crestGcdSpark", true)
	assert(p.spark:IsShown() and p.spark._state.DrawSwipe[1] == false and p.spark._state.DrawEdge[1] == true, "switched on, the spark is an edge with no swipe")
	env._gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(p.spark._state.CooldownFromDurationObject[1].finish == 1.5, "a global cooldown runs the spark")
	env._cast = { 300000, 302000 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-G", 686, 14)
	assert(Last(p.spark) == "Clear", "a cast takes the lane from the spark")
	p.spark._state.CooldownFromDurationObject = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(p.spark._state.CooldownFromDurationObject == nil, "and the spark waits while it runs")
	-- Frames mid-cast: the cast is dropped, nothing is heard while hidden, and the spark is free on return.
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(ns.SlabRings.state.casting == nil and Last(p.cast) == "Clear", "switching to Frames mid-cast clears the cast")
	local asked = env._gcdAsked
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-G", 686, 14)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(env._gcdAsked == asked and not p.flash.play:IsPlaying(), "hidden, the crest asks nothing and flashes nothing")
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(p.spark._state.CooldownFromDurationObject, "back on Medallions the spark runs again")
	-- Turning the cast ring off stops its flash.
	env._cast = { 400000, 401000 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-H", 686, 15)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-H", 686, 15)
	K.Options.Write("ActionBars", "crestCast", false)
	assert(not p.cast:IsShown() and not p.flash.play:IsPlaying(), "its switch hides the ring and stops its flash")
	-- In lockdown nothing is re-anchored.
	env._combat = true
	local points = Count(p, "SetPoint")
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(Count(p, "SetPoint") == points, "a restriction change in lockdown re-anchors nothing")
	env._combat = false
	Clean(env, K, "cast ring")
	K.Options.Write("ActionBars", "crestGcdSpark", false)
	assert(not p:IsShown(), "with both off nothing shows")
	assert(Updating(p) == 0, "nothing runs OnUpdate")
end
do
	local env, K, ns = New("MAGE", {}, { frames = true })
	local p = ns.SlabRings.state.piece
	assert(not (p and p:IsVisible()), "under Frames there is no cast ring")
	env._cast = { 100000, 102500 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-A", 686, 8)
	Clean(env, K, "cast under Frames")
end

print("actionbars crest rings ok")
