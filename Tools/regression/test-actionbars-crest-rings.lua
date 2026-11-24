-- test-actionbars-crest-rings.lua: the crest's ring-edge timing layers (KstyleUI_ActionBars/SlabRings.lua). Expiring ember: every aura timer ring (medal, inner rim, cooldown ring) gets a second white swipe of the ember art fed the same duration by a mirror of its slot, a Lua-fed timer hands its hot swipe every cooldown, under Frames too; the switch hides them; while auras are readable the medal flickers through the last fifth and an expired ring's ghost fades, and in combat nothing touches an aura button. The swing ring: every melee class gets a steel ring 108 across (a druid in cat or bear form only) that each main-hand swing restarts from one duration object with a tick at Full, none at Calm, nothing for the off hand; under Frames it is a medal; its switch removes it. The cast ring: a cast fills the 145 edge clockwise from the cast's own times (a duration object when they are secret), a channel drains; a landed cast clears it, flashes it and pulses the crest at the cast flash's priority; a stopped one pauses it red and shakes it; Off clears it at once; it is gone under Frames and with its switch. The global cooldown spark is off by default; switched on, a global cooldown runs an edge-only swipe that yields to a cast. Nothing runs OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SHOUT, RECKLESS = 6673, 1719

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
			e.C_Spell.GetSpellCooldown = function(id) return { isActive = id == 29515 and e._gcd == true, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 1.5 } end
			e.C_DurationUtil = { CreateDuration = function() e._durations = (e._durations or 0) + 1 return { SetTimeFromStart = function(d, s, l) d.start, d.length = s, l end } end }
			e.GetTime = function() return e._now or 0 end
			e._auraData = {}
			e.C_UnitAuras = { GetUnitAuraBySpellID = function(unit, id) return e._auraData[unit .. id] end }
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

-- The hot swipe a lit's ember mirror drives.
local function Hot(lit)
	for _, mirror in ipairs(lit.mirrors or {}) do
		local c = mirror._cooldown
		if c and tostring(c._state.SwipeTexture and c._state.SwipeTexture[1]):find("Ember", 1, true) then return c, mirror.container:GetParent() end
	end
end

local function Last(frame)
	return frame._calls[#frame._calls].method
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do n = n + Updating(child) end
	return n
end

-- The art SlabRings names by path ships.
for _, file in ipairs({ "EmberOrbRing.png", "EmberRingLine16.png", "CastRing.png" }) do
	local handle = io.open("Media/Textures/Medallions/Trackers/" .. file, "rb")
	assert(handle, file .. " is missing; run python3 Tools/media/crest_rings.py")
	handle:close()
end

-- Expiring ember on a warrior's medal, inner rim and cooldown ring.
do
	local env, K, ns = New("WARRIOR", { SHOUT, 2687, RECKLESS })
	local shout, rim, cooldowns = Piece(ns, "crestShout"), Piece(ns, "crestEnrage"), Piece(ns, "crestCooldowns")
	local hot, gate = Hot(shout.lit)
	assert(hot and tostring(hot._state.SwipeTexture[1]):find("EmberOrbRing.png", 1, true), "the shout medal's timer ring has an ember swipe of the medal ring's art")
	local r, g, b = unpack(hot._state.SwipeColor)
	assert(r == 1 and g == 1 and b == 1 and hot.units == shout.lit.timer.units, "drawn white, at its timer ring's size, so the art's amber and red show")
	assert(Hot(rim.lit) and tostring(Hot(rim.lit)._state.SwipeTexture[1]):find("EmberRingLine16.png", 1, true) and Hot(cooldowns.lit), "the inner rim and the cooldown ring get the thin ring's ember")
	Slots.Set(env, "player", { { id = SHOUT, start = 0, duration = 120 } })
	local d = hot._state.CooldownFromDurationObject and hot._state.CooldownFromDurationObject[1]
	assert(d and d.start == 0 and d.finish == 120, "the ember swipe drains on the shout's own duration")
	assert(gate:GetAlpha() == 1, "on by default")
	K.Options.Write("ActionBars", "crestEmber", false)
	assert(gate:GetAlpha() == 0 and select(2, Hot(rim.lit)):GetAlpha() == 0, "its switch hides every ember swipe")
	K.Options.Write("ActionBars", "crestEmber", true)
	assert(gate:GetAlpha() == 1, "and brings them back")
	-- Readable: the last fifth flickers the medal, an expiry fades the ring to steel.
	local watched
	for _, e in ipairs(ns.SlabRings.state.watched) do if e.piece == shout then watched = e end end
	env._now = 100
	env._auraData["player" .. SHOUT] = { expirationTime = 200, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(not watched.flicker:IsPlaying(), "100 s of 120 left: no flicker")
	env._auraData["player" .. SHOUT] = { expirationTime = 110, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(watched.flicker:IsPlaying(), "10 s of 120 left: the medal flickers")
	env._now = 110
	env._auraData["player" .. SHOUT] = nil
	env.FireEvent("UNIT_AURA", "player")
	assert(not watched.flicker:IsPlaying() and watched.fade:IsPlaying(), "it ran out: the flicker stops and the gilt ring fades to steel")
	env._now = 120
	env._auraData["player" .. SHOUT] = { expirationTime = 125, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(watched.flicker:IsPlaying(), "a new last fifth flickers again")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	-- In combat auras are secret: the flicker stops and nothing touches an aura button.
	env._combat, env._aurasSecret = true, true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	env.FireEvent("UNIT_AURA", "player")
	K.Options.Write("ActionBars", "crestEmber", false)
	K.Options.Write("ActionBars", "crestEmber", true)
	assert(not watched.flicker:IsPlaying(), "in combat the flicker stops")
	Clean(env, K, "ember in combat")
	-- A Lua-fed timer hands its hot swipe each cooldown it gets.
	local holder = env.CreateFrame("Frame", nil, ns.Slab.hub)
	local timer = env.CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
	timer.units = 30
	local lua = ns.SlabMedals.Ember(holder, nil, timer, "OrbRing.png", 5)
	timer:SetCooldown(50, 8)
	local start, length = lua._state.Cooldown[1], lua._state.Cooldown[2]
	assert(start == 50 and length == 8 and lua.units == 30, "a Lua-fed timer's cooldown reaches its ember swipe")
	timer:Clear()
	assert(Last(lua) == "Clear", "and its clear")
end

-- Under Frames the row's medals carry the same ember.
do
	local env, K, ns = New("WARRIOR", { SHOUT }, { frames = true })
	local shout = Piece(ns, "crestShout", "row")
	assert(shout and Hot(shout.lit), "the shout medal in the Frames row has its ember swipe")
	Clean(env, K, "ember under Frames")
end

-- The swing ring for every melee class.
for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE", "SHAMAN" }) do
	local env, K, ns = New(class, {})
	local ring = Piece(ns, "crestSwing")
	local r, g, b = K.Tokens.Color("steelLit")
	assert(ring and ring:IsShown() and ring.units == 108, class .. ": a swing ring 108 across sits inside the rune band")
	assert(ring.swing._state.SwipeColor[1] == r and ring.swing._state.SwipeColor[2] == g and ring.swing._state.SwipeColor[3] == b, class .. ": in pale steel")
	Clean(env, K, class .. " swing")
end
do
	local env, K, ns = New("ROGUE", {})
	local ring = Piece(ns, "crestSwing")
	env._now = 10
	for _ = 1, 3 do env.FireEvent("PLAYER_SWING", env.Secret(1.8), 0) end
	local d = ring.swing._state.CooldownFromDurationObject[1]
	assert(d.start == 10 and env.issecretvalue(d.length) and env._durations == 1, "each main-hand swing restarts the ring from one duration object")
	assert(ring.tick.play:IsPlaying() and ring.swing._state.DrawEdge[1] == true and ring.swing._state.UseCircularEdge[1] == true, "a tick at the hit and a bright head on the rim at Full")
	ring.tick.play:Stop()
	env._now = 12
	env.FireEvent("PLAYER_SWING", 1.6, 1)
	assert(ring.swing._state.CooldownFromDurationObject[1].start == 10 and not ring.tick.play:IsPlaying(), "the off hand changes nothing")
	K.Options.Write("Medallions", "motion", "calm")
	env.FireEvent("PLAYER_SWING", 1.8, 0)
	assert(ring.swing._state.CooldownFromDurationObject[1].start == 12 and not ring.tick.play:IsPlaying(), "Calm keeps the ring and drops the tick")
	K.Options.Write("ActionBars", "crestSwing", false)
	env.RunTimers()
	assert(not ring:IsVisible(), "its switch removes the ring")
	Clean(env, K, "rogue swing")
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
	assert(not p.spark:IsShown() and K.Store.Module("ActionBars").crestGcdSpark ~= true, "the global cooldown spark is off by default")
	env._cast = { 100000, 102500 }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	local start, length = p.cast._state.Cooldown[1], p.cast._state.Cooldown[2]
	assert(start == 100 and length == 2.5 and p.cast._state.Reverse[1] == true, "a cast fills the edge clockwise over its own times")
	local r, g, b = K.Tokens.Color("gilt")
	assert(p.cast._state.SwipeColor[1] == r and p.cast._state.SwipeColor[2] == g and p.cast._state.SwipeColor[3] == b, "in gilt")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	assert(Last(p.cast) == "Clear" and p.flash.play:IsPlaying() and K.Effects.Holder("hub") == K.Effects.PRIORITY.cast and ns.Slab.hub.crest.pulse:IsPlaying(),
		"a landed cast clears the ring, flashes it and pulses the crest at the cast flash's priority")
	env.FireEvent("UNIT_SPELLCAST_STOP", "player")
	p.flash.play:Stop()
	env._cast = nil
	env._channel = { 200000, 205000 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	assert(p.cast._state.Reverse[1] == false and p.cast._state.Cooldown[1] == 200, "a channel drains the other way")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	assert(ns.SlabRings.state.casting == "channel" and not p.flash.play:IsPlaying(), "a channel's start does not land it")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	r, g, b = K.Tokens.Color("hostile")
	assert(p.cast._state.Paused[1] == true and p.cast._state.SwipeColor[1] == r and p.cast._state.SwipeColor[2] == g and p.cast._state.SwipeColor[3] == b and p.stop:IsPlaying(), "a stopped cast pauses red and shakes")
	env._channel = nil
	env._cast = { env.Secret(1), env.Secret(2) }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	assert(p.cast._state.CooldownFromDurationObject[1].finish == 2.5 and p.cast._state.Paused[1] == false and not p.stop:IsPlaying(), "secret times run the ring on the cast's duration object")
	K.Options.Write("Medallions", "motion", "off")
	env.FireEvent("UNIT_SPELLCAST_FAILED", "player")
	assert(Last(p.cast) == "Clear" and not p.stop:IsPlaying(), "Off shows the end state: a failed cast just clears")
	K.Options.Write("Medallions", "motion", "full")
	-- The spark: on, a global cooldown runs it; it yields to a cast.
	K.Options.Write("ActionBars", "crestGcdSpark", true)
	assert(p.spark:IsShown() and p.spark._state.DrawSwipe[1] == false and p.spark._state.DrawEdge[1] == true, "switched on, the spark is an edge with no swipe")
	env._gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(p.spark._state.CooldownFromDurationObject[1].finish == 1.5, "a global cooldown runs the spark")
	env._cast = { 300000, 302000 }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	assert(Last(p.spark) == "Clear", "a cast takes the lane from the spark")
	p.spark._state.CooldownFromDurationObject = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(p.spark._state.CooldownFromDurationObject == nil, "and the spark waits while it runs")
	-- In combat the ring keeps working with no error.
	env._combat, env._aurasSecret = true, true
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	Clean(env, K, "cast ring in combat")
	K.Options.Write("ActionBars", "crestCast", false)
	assert(not p.cast:IsShown(), "its switch hides the ring")
	K.Options.Write("ActionBars", "crestGcdSpark", false)
	assert(not p:IsShown(), "with both off nothing shows")
	assert(Updating(p) == 0, "nothing runs OnUpdate")
end
do
	local env, K, ns = New("MAGE", {}, { frames = true })
	local p = ns.SlabRings.state.piece
	assert(not (p and p:IsVisible()), "under Frames there is no cast ring")
	env._cast = { 100000, 102500 }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	Clean(env, K, "cast under Frames")
end

print("actionbars crest rings ok")
