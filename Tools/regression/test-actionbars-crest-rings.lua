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
		if c and tostring(c._state.SwipeTexture and c._state.SwipeTexture[1]):find("Ember", 1, true) then return c, mirror.container:GetParent() end
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

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do n = n + Updating(child) end
	return n
end

-- The art SlabRings names by path ships.
for _, file in ipairs({ "EmberBand.png", "EmberRingLine16.png", "CastRing.png", "SwingRing.png", "SwingHalo.png", "RingBead.png" }) do
	local handle = io.open("Media/Textures/Medallions/Trackers/" .. file, "rb")
	assert(handle, file .. " is missing; run python3 Tools/media/crest_rings.py")
	handle:close()
end

-- Expiring ember on a warrior's cooldown ring and sigils; Battle Shout's horn and Enrage's cracks warn through their last fifth on themselves (they drain as objects and along their own art, with no 112 line).
do
	local env, K, ns = New("WARRIOR", { SHOUT, 2687, RECKLESS, WALL })
	local shout, rim, cooldowns = Piece(ns, "crestShout"), Piece(ns, "crestEnrage"), Piece(ns, "crestCooldowns")
	local hot, gate = Hot(cooldowns.lit)
	assert(hot and tostring(hot._state.SwipeTexture[1]):find("EmberRingLine16.png", 1, true), "the cooldown ring gets the thin ring's ember")
	assert(not Hot(rim.lit) and Watched(ns, rim), "Enrage's cracks keep no ember on the 112 line and warn on themselves")
	for _, sigil in ipairs(cooldowns.sigils) do
		assert(sigil.ember and tostring(sigil.ember.timer._state.SwipeTexture[1]):find("EmberBand.png", 1, true), "every cooldown sigil has its band")
	end
	Slots.Set(env, "player", { { id = RECKLESS, start = 0, duration = 120 } })
	local d = hot._state.CooldownFromDurationObject and hot._state.CooldownFromDurationObject[1]
	assert(d and d.start == 0 and d.finish == 120, "the ember swipe drains on the cooldown's own duration")
	assert(gate:GetAlpha() == 1, "on by default")
	K.Options.Write("ActionBars", "crestEmber", false)
	env.RunTimers()
	assert(gate:GetAlpha() == 0 and select(2, Hot(cooldowns.lit)):GetAlpha() == 0, "its switch hides every ember swipe")
	local sigil = cooldowns.sigils[1]
	assert(sigil.container._slots[sigil.ember.key].disabled, "and turns the sigil bands' slots off")
	K.Options.Write("ActionBars", "crestEmber", true)
	env.RunTimers()
	assert(gate:GetAlpha() == 1 and not sigil.container._slots[sigil.ember.key].disabled, "and brings them back")
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
	assert(not watched.flicker:IsPlaying(), "motion Off stops the flicker")
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
end

-- A medal's ember is the bright band just outside its rim; under Frames the horn in the row warns as on the crest, and the hidden crest reads nothing.
do
	local env, K, ns = New("WARRIOR", { SHOUT })
	local medal = ns.SlabMedals.Medal(ns.Slab.hub, { feed = "aura", spells = { SHOUT }, color = "gilt", texture = 132333 }, 10)
	local hot = Hot(medal.lit)
	assert(hot and tostring(hot._state.SwipeTexture[1]):find("EmberBand.png", 1, true), "a medal's ember is the bright band")
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
