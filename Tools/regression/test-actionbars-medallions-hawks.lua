-- test-actionbars-medallions-hawks.lua: the crest's hawk perches: a hunter who knows Summon Hawk gets two perches on the rune ring's shoulders, nobody else gets a frame, an event or a callback; each perch lights from totem slot 2 or 3 through the slot's own boolean and drains through the slot's duration object, secret or not, with no Lua compare; a summon flares, an expiry fades, a third summon refreshes the oldest perch alone, both hawks out light the rune ring, breathing only while Lua can read both slots; a flyout or spellbook update leaves a playing flare alone; the render story keeps Summon Hawk's recovery and ends empty; at Full a summon lifts its gilt hawk 13 units outward and swells it from 0.55 to 1.35 times in 0.12 s, settling over 0.30 s with a ripple of 0.35 s while the timer stays seated, the empty steel hawk shows only on an empty slot, two hawks fade the ring's glow in over 0.30 s without a blink on a refresh, an expiry sinks the old hawk 3 units over 0.35 s, a proc or level-up holding the hub keeps the lift still and stops one already playing, a cast holding the hub or a proc on a spell with no button does not, a reload, style switch, spellbook change or combat entry with hawks out shows them at once without a lift, Calm keeps fades without travel and stills the breath, Off shows end states with no animation, ending a glow fade already playing, nothing runs OnUpdate, Hawk perches off hides everything, and every layer is an even number of pixels centred on its perch, mirrored across the crown, at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")
local FX = dofile("Tools/regression/effects_env.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local RANK3 = 1293526

-- New(class, known, size, setup): setup(e), when given, fills the fixture before login, such as hawks already out.
local function New(class, known, size, setup)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._totems, e._known = {}, known or {}
			e.UnitCastingInfo = function() if e._cast then return "Summon Hawk", "", 132158, e._cast[1], e._cast[2] end end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e._reads = 0
			e.GetTotemInfo = function(slot)
				e._reads = e._reads + 1
				local t = e._totems[slot]
				if not t then return false, "", 0, 0, 0, 1, 0 end
				return t.have, "Hawk", t.start, t.duration, 132158, 1, t.spell
			end
			e.GetTotemDuration = function(slot)
				local t = e._totems[slot]
				return { start = t and t.start or 0, finish = t and t.finish or 0 }
			end
			if setup then setup(e) end
		end,
	})
	-- env._callbacks: the callbacks the hawks hold now, by event.
	local register, unregister = K.Callbacks.Register, K.Callbacks.Unregister
	env._callbacks = {}
	K.Callbacks.Register = function(event, owner, fn)
		if owner == "ActionBars.SlabHawks" then env._callbacks[event] = true end
		return register(event, owner, fn)
	end
	K.Callbacks.Unregister = function(event, owner)
		if owner == "ActionBars.SlabHawks" then env._callbacks[event] = nil end
		return unregister(event, owner)
	end
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

local function Hawk(env, slot, start, secret)
	local t = { have = true, start = start, duration = 18, finish = start + 18, spell = slot == 2 and 1293248 or 1312637 }
	if secret then
		t.have, t.start, t.duration = env.Secret(true), env.Secret(start), env.Secret(18)
	end
	env._totems[slot] = t
	env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
end

local function Gone(env, slot, secret)
	env._totems[slot] = secret and { have = env.Secret(false), start = env.Secret(0), duration = env.Secret(0), finish = 0 } or nil
	env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
end

-- Seen(env, frame) -> whether a gated frame draws: shown, and its alpha (revealed when secret) above zero.
local function Seen(env, frame)
	local alpha = frame:GetAlpha()
	if env.issecretvalue(alpha) then
		alpha = env.Reveal(alpha)
	end
	return frame:IsShown() and alpha > 0
end

local function Drawn(env, p, key)
	return Seen(env, p[key .. "Gate"]) and p[key]:IsShown()
end

local function Timer(p)
	local object = p.timer._state.CooldownFromDurationObject
	return object and object[1]
end

local function Lifting(p)
	return p.lift:IsPlaying() and p.pops[1]:IsPlaying() and p.pops[2]:IsPlaying() and p.ripple.wave:IsPlaying()
end

local function Still(p)
	local n = 0
	for _, group in ipairs({ p.lift, p.pops[1], p.pops[2], p.ripple.wave, p.sink }) do
		n = n + (group:IsPlaying() and 1 or 0)
	end
	return n == 0
end

local function Playing(ns)
	local n = 0
	local pair = ns.SlabHawks.state.pair
	for _, p in ipairs(ns.SlabHawks.state.perches) do
		n = n + (p.was.fade:IsPlaying() and 1 or 0) + (p.flare.fade:IsPlaying() and 1 or 0) + (Still(p) and 0 or 1)
	end
	return n + (pair.breath:IsPlaying() and 1 or 0) + (pair.dawn[1]:IsPlaying() and 1 or 0) + (pair.dawn[2]:IsPlaying() and 1 or 0)
end

-- Steps(group, kind) -> that kind's animations of the group by order: { order = { field = values } }.
local function Steps(group, kind)
	local steps = {}
	for _, anim in ipairs(group._anims) do
		if anim._type == kind then
			local st = anim._state
			steps[#steps + 1] = { order = st.Order and st.Order[1] or 1, duration = st.Duration[1], offset = st.Offset, from = st.ScaleFrom, to = st.ScaleTo, alpha = st.ToAlpha and st.ToAlpha[1] }
		end
	end
	table.sort(steps, function(a, b) return a.order < b.order end)
	return steps
end

-- Settle(p): the stub plays a group until it is stopped; this ends a perch's motion as its time running out would.
local function Settle(p)
	for _, group in ipairs({ p.lift, p.pops[1], p.pops[2], p.ripple.wave, p.sink }) do
		group:Stop()
	end
end

local function Near(a, b)
	return math.abs(a - b) < 1e-6
end

local function Updating(ns)
	local state, n = ns.SlabHawks.state, 0
	local frames = { state.pair, state.pair.inner, state.pair.glow, state.pair.glyphs, state.pair.halo }
	for _, p in ipairs(state.perches) do
		for _, key in ipairs({ "holder", "timer", "pop", "lit", "wasGate", "was", "rippleGate", "flareGate", "flare" }) do
			frames[#frames + 1] = p[key]
		end
	end
	for _, frame in ipairs(frames) do
		n = n + (frame:GetScript("OnUpdate") and 1 or 0)
	end
	return n
end

for _, case in ipairs({ { "WARRIOR", { [RANK3] = true } }, { "ROGUE", {} }, { "HUNTER", {} } }) do
	local env, K, ns = New(case[1], case[2])
	local state = ns.SlabHawks.state
	assert(#state.perches == 0 and state.pair == nil and not state.listening, case[1] .. ": no perch, ring or event unless a hunter knows Summon Hawk")
	assert(next(env._callbacks) == nil, case[1] .. ": no hawk callback either; register EffectsLevelChanged with the totem event")
	Hawk(env, 2, 10)
	assert(#state.perches == 0, case[1] .. ": a totem update builds nothing")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("HUNTER", { [RANK3] = true })
	local state = ns.SlabHawks.state
	local left, right = state.perches[1], state.perches[2]
	assert(left and right and left.slot == 2 and right.slot == 3 and state.listening, "a hunter who knows any rank gets a perch for slot 2 and one for slot 3")
	assert(left.holder:IsShown() and right.holder:IsShown(), "both perches show their empty steel hawks")
	assert(not Seen(env, left.lit) and not Seen(env, right.lit) and not state.pair:IsShown(), "no hawks: nothing is lit and the ring is plain")
	assert(not left.lit:IsShown() and not state.pair:IsShown(), "a readable empty slot hides its lit layers rather than drawing them at alpha 0")
	local hr, hg, hb = K.Tokens.Color("jewelHawk")
	local sr, sg, sb = unpack(left.timer._state.SwipeColor)
	assert(math.abs(sr - hr) + math.abs(sg - hg) + math.abs(sb - hb) < 1e-3, "the timer drains in the hawk jewel's green")

	-- 0 -> 1: the left perch lights and flares.
	Hawk(env, 2, 100)
	assert(Seen(env, left.lit) and not Seen(env, right.lit), "one hawk lights one perch")
	assert(Timer(left) and Timer(left).start == 100 and Timer(left).finish == 118, "the timer is the slot's own duration object")
	assert(Drawn(env, left, "flare") and left.flare.fade:IsPlaying(), "a summon flares")
	assert(not Drawn(env, left, "was"), "nothing was there to fade")
	assert(Lifting(left) and Still(right), "at Full the summoned hawk lifts and swells with a ripple; the other perch is still")
	assert(not left.steel:IsShown() and right.steel:IsShown(), "the empty steel hawk hides under the gilt one and stays on the empty perch")
	assert(left.timer:GetParent() == left.holder and left.ripple:GetParent() ~= left.pop, "the timer ring and ripple stay on the seat; only the hawk travels")
	local move = Steps(left.lift, "Translation")
	local out = move[1].offset
	assert(#move == 2 and Near(math.sqrt(out[1] ^ 2 + out[2] ^ 2), 13) and out[1] < 0 and out[2] > 0, "the left hawk lifts 13 units up and out from the crest")
	assert(Near(move[1].duration, 0.12) and Near(move[2].duration, 0.3) and Near(move[2].offset[1], -out[1]) and Near(move[2].offset[2], -out[2]), "it rises in 0.12 s and comes home over 0.30 s")
	local swell = Steps(left.pops[1], "Scale")
	assert(Near(swell[1].from[1], 0.55) and Near(swell[1].to[1], 1.35) and Near(swell[1].duration, 0.12), "the hawk swells from 0.55 to 1.35 times in 0.12 s")
	assert(Near(swell[1].to[1] * swell[2].to[1], 1) and Near(swell[2].duration, 0.3), "and settles to its own size over 0.30 s")
	local ripple = Steps(left.ripple.wave, "Scale")[1]
	assert(ripple.duration <= 0.35 and Steps(left.ripple.wave, "Alpha")[1].alpha == 0, "the ripple is gone within 0.35 s")
	local rout = Steps(right.lift, "Translation")[1].offset
	assert(Near(rout[1], -out[1]) and Near(rout[2], out[2]), "the right hawk lifts the mirror way")
	local reads = env._reads
	env.FireEvent("SPELL_FLYOUT_UPDATE", 1)
	env.FireEvent("SPELLS_CHANGED")
	assert(left.flare.fade:IsPlaying() and env._reads == reads, "a flyout or spellbook update that changes nothing leaves the perches alone")
	assert(not state.pair:IsShown(), "one hawk leaves the ring plain")
	left.flare.fade:GetScript("OnFinished")(left.flare.fade)
	assert(not left.flare:IsShown(), "the flare hides once it has played")
	Settle(left)

	-- 1 -> 2: both perches light and the rune ring glows.
	Hawk(env, 3, 106)
	assert(Seen(env, left.lit) and Seen(env, right.lit), "two hawks light both perches")
	assert(Drawn(env, right, "flare") and not left.flare.fade:IsPlaying(), "only the new hawk's perch flares")
	assert(Lifting(right) and Still(left), "only the new hawk lifts")
	local dawn = Steps(state.pair.dawn[1], "Alpha")[1]
	assert(state.pair.dawn[1]:IsPlaying() and state.pair.dawn[2]:IsPlaying() and Near(dawn.duration, 0.3) and dawn.alpha == 1, "the ring's glow fades in over 0.30 s")
	assert(Seen(env, state.pair) and Seen(env, state.pair.inner) and state.pair.breath:IsPlaying(), "both hawks out light the rune ring, breathing at Full")
	assert(state.pair.glyphs:GetFrameLevel() > ns.Slab.hub:GetFrameLevel() and state.pair.halo:GetFrameLevel() < ns.Slab.hub:GetFrameLevel(), "the glyphs glow over the band and the halo sits under the hub")

	-- Expiry: the left hawk leaves, its perch fades, the ring goes plain.
	Gone(env, 2)
	assert(not Seen(env, left.lit) and Drawn(env, left, "was") and left.was.fade:IsPlaying(), "an expired hawk's perch fades out")
	assert(not Drawn(env, left, "flare"), "an expiry does not flare")
	local sink = Steps(left.sink, "Translation")[1]
	assert(left.sink:IsPlaying() and not left.lift:IsPlaying() and left.steel:IsShown(), "the expired hawk sinks while the steel hawk returns, and nothing lifts")
	assert(Near(math.sqrt(sink.offset[1] ^ 2 + sink.offset[2] ^ 2), 3) and sink.offset[2] < 0 and sink.offset[1] > 0 and Near(sink.duration, 0.35), "it sinks 3 units in towards the crest over 0.35 s")
	assert(not state.pair:IsShown() and not state.pair.breath:IsPlaying(), "one hawk left: the ring goes plain")
	left.was.fade:GetScript("OnFinished")(left.was.fade)
	assert(not left.was:IsShown(), "the fade hides once it has played")

	-- Resummon fills the empty perch; a third summon refreshes the oldest perch alone.
	Hawk(env, 2, 121)
	assert(Seen(env, left.lit) and Seen(env, right.lit) and state.pair:IsShown(), "a resummon fills the empty perch")
	left.flare.fade:Stop()
	Settle(left)
	Settle(right)
	assert(state.pair.dawn[1]:IsPlaying(), "a resummon to two hawks fades the glow in again")
	for _, group in ipairs(state.pair.dawn) do
		group:Stop()
	end
	Hawk(env, 3, 123)
	assert(Timer(right).start == 123 and Timer(left).start == 121, "the replaced hawk's timer starts again; the other keeps its own")
	assert(Drawn(env, right, "flare") and Drawn(env, right, "was") and Seen(env, right.lit), "the refreshed perch flares while its old hawk fades under a lit hawk, so it never blinks")
	assert(not left.flare.fade:IsPlaying() and not left.was.fade:IsPlaying() and Still(left), "the other perch does not move")
	assert(Lifting(right) and right.sink:IsPlaying(), "the refreshed perch lifts its new hawk while the old one sinks")
	assert(state.pair:IsShown() and not state.pair.dawn[1]:IsPlaying() and not state.pair.dawn[2]:IsPlaying(), "a refresh keeps the ring's glow lit with no fade, so it never blinks")

	-- A proc or level-up holding the hub keeps the motion; the hawk still lights, flares and drains.
	local token = K.Effects.Claim("hub", K.Effects.PRIORITY.proc, function() end)
	Hawk(env, 2, 124)
	assert(Seen(env, left.lit) and left.flare.fade:IsPlaying() and Still(left), "with a proc holding the hub the hawk lights and flares without lifting")
	assert(Timer(left).start == 124, "and its timer still drains")
	K.Effects.Release("hub", token)
	Hawk(env, 2, 125)
	assert(Lifting(left), "the lift is back once the hub is free")
	assert(ns.SlabEffects.Proc(ns.Slab.hub), "a proc claims the hub")
	assert(Still(left) and left.flare.fade:IsPlaying() and Timer(left).start == 125, "a proc arriving mid-lift stops the travel, swell and ripple, keeping the flare and the timer")
	K.Effects.Stop("hub")
	assert(Updating(ns) == 0, "no hawk layer runs OnUpdate")

	-- Calm stills the breath; Off plays nothing and shows the end states.
	Settle(right)
	K.Options.Write("Medallions", "motion", "calm")
	assert(state.pair:IsShown() and not state.pair.breath:IsPlaying(), "Calm stills the ring's breath")
	Hawk(env, 2, 130)
	assert(left.flare.fade:IsPlaying() and Still(left) and Still(right), "Calm keeps the flare without travel, swell or ripple")
	Gone(env, 2)
	assert(left.was.fade:IsPlaying() and Still(left), "Calm fades an expired hawk without sinking it")
	Hawk(env, 2, 131)
	K.Options.Write("Medallions", "motion", "full")
	K.Options.Write("Appearance", "motion", "reduced")
	Hawk(env, 2, 132)
	assert(left.flare.fade:IsPlaying() and Still(left), "reduced motion in Appearance caps the hawks at Calm")
	K.Options.Write("Appearance", "motion", "full")
	Gone(env, 2)
	Hawk(env, 2, 133)
	assert(state.pair.dawn[1]:IsPlaying() and state.pair.dawn[2]:IsPlaying(), "a second hawk fades the ring's glow in")
	K.Options.Write("Medallions", "motion", "off")
	assert(not state.pair.dawn[1]:IsPlaying() and not state.pair.dawn[2]:IsPlaying() and state.pair:IsShown(), "switching to Off mid-fade shows the lit ring at once")
	Gone(env, 3)
	Hawk(env, 2, 140)
	assert(Playing(ns) == 0, "Off plays no hawk animation")
	assert(not left.flare:IsShown() and not left.was:IsShown() and not right.was:IsShown(), "Off hides the flare and the fade")
	assert(not left.steel:IsShown() and right.steel:IsShown() and Timer(left).start == 140, "Off keeps the count and the timer")
	assert(Seen(env, left.lit) and not Seen(env, right.lit) and not state.pair:IsShown(), "Off shows the end state at once")
	assert(Updating(ns) == 0, "no hawk layer runs OnUpdate at Off")
	K.Options.Write("Medallions", "motion", "full")

	K.Options.Write("ActionBars", "crestHawks", false)
	env.RunTimers()
	assert(not left.holder:IsShown() and not right.holder:IsShown() and not state.pair:IsShown() and not state.listening, "Hawk perches off hides both perches and the ring and stops listening")
	assert(next(env._callbacks) == nil, "Hawk perches off drops the hawks' callback too")
	K.Options.Write("ActionBars", "crestHawks", true)
	env.RunTimers()
	assert(left.holder:IsShown() and Seen(env, left.lit) and state.listening, "turning it back on reads the slots again")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	assert(not left.holder:IsShown() and not state.listening, "only the Medallions crest has perches")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Hub contention through the player's own events: Summon Hawk's cast landing pulses the hub at the cast flash's
-- priority and leaves the lift; a proc on a spell with no action button, low health and another slot's cooldown ending
-- claim nothing on the hub, so the lift goes on with every timer drawn; a proc on a bar button and a level-up each claim
-- the hub and stop a lift already playing, keeping the flare, the lit hawk and the timer.
do
	local env, K, ns = New("HUNTER", { [RANK3] = true }, nil, function(e)
		FX.Install(e)
		e._health = 0.1
	end)
	local state = ns.SlabHawks.state
	local left, right = state.perches[1], state.perches[2]
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env._cast = { 99000, 100000 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-H", 1293241, 1)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-H", 1293241, 1)
	env._cast = nil
	assert(K.Effects.Holder("hub") == K.Effects.PRIORITY.cast, "Summon Hawk landing pulses the hub at the cast flash's priority")
	Hawk(env, 2, 100)
	assert(Lifting(left), "the cast flash leaves the lift")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 999)
	assert(Lifting(left) and K.Effects.Holder("hub") == K.Effects.PRIORITY.cast, "a proc on a spell with no button claims nothing and the lift goes on")
	env._health = 0.05
	env.FireEvent("UNIT_HEALTH", "player")
	local vignette = K.Effects.Vignette.frame
	assert(vignette and vignette:IsShown() and env.Reveal(vignette._lastAlpha.args[1]) == 1, "low health shows the vignette in full")
	assert(Lifting(left) and Timer(left).start == 100, "low health claims nothing on the hub: the lift goes on and the timer draws")
	AB.Slot(env, 2, { texture = 2, type = "spell", id = 200 })
	local ready = AB.Button(ns, "bar1", 2)
	ready.realCooldown = true
	ready.cooldown:GetScript("OnCooldownDone")(ready.cooldown)
	assert(ready.medReady and ready.medReady.anim:IsPlaying(), "another slot's cooldown ending plays its ready flash")
	assert(Lifting(left) and Timer(left).start == 100, "the ready flash stays on its slot: the lift goes on and the timer draws")
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(K.Effects.Holder("hub") == K.Effects.PRIORITY.proc, "a proc on a button claims the hub")
	assert(Still(left) and left.flare.fade:IsPlaying() and Seen(env, left.lit) and Timer(left).start == 100, "it stops the lift and keeps the flare, the lit hawk and the timer")
	Hawk(env, 3, 101)
	assert(Seen(env, right.lit) and right.flare.fade:IsPlaying() and Still(right) and Timer(right).start == 101, "a hawk summoned under the proc lights and flares without lifting")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	K.Effects.Stop("hub")
	Hawk(env, 3, 102)
	assert(Lifting(right), "with the hub free a refresh lifts")
	env.FireEvent("PLAYER_LEVEL_UP", 12)
	assert(K.Effects.Holder("hub") ~= nil and K.Effects.Holder("hub") <= K.Effects.PRIORITY.proc, "a level-up claims the hub")
	assert(Still(right) and right.flare.fade:IsPlaying() and Seen(env, right.lit) and Timer(right).start == 102, "a level-up mid-lift stops it and keeps the flare, the lit hawk and the timer")
	assert(Seen(env, left.lit) and Timer(left).start == 100 and state.pair:IsShown(), "the other hawk and the ring stay lit throughout")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Hawks already out across a reload, a HUD style switch, a spellbook change and combat entry: each repaint shows the
-- hawks and their timers at once, with no lift; once combat makes the slots secret the ring holds still and a refresh
-- lifts only its own perch.
do
	local env, K, ns = New("HUNTER", { [RANK3] = true }, nil, function(e)
		e._totems[2] = { have = true, start = 50, duration = 18, finish = 68, spell = 1293248 }
		e._totems[3] = { have = true, start = 52, duration = 18, finish = 70, spell = 1312637 }
	end)
	local state = ns.SlabHawks.state
	local left, right = state.perches[1], state.perches[2]
	assert(Seen(env, left.lit) and Seen(env, right.lit) and state.pair:IsShown(), "a reload with two hawks out lights both perches and the ring")
	assert(Still(left) and Still(right) and not left.flare.fade:IsPlaying() and not state.pair.dawn[1]:IsPlaying(), "a reload plays no lift, flare or glow fade")
	assert(Timer(left).start == 50 and Timer(right).start == 52 and not left.steel:IsShown(), "and keeps each hawk's timer, steel hidden")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(Seen(env, left.lit) and Still(left) and Timer(left).start == 50 and state.pair:IsShown(), "a style switch back to Medallions shows the hawks and timers at once")
	env.FireEvent("SPELLS_CHANGED")
	assert(Seen(env, right.lit) and Still(right) and Timer(right).start == 52, "a spellbook change that keeps Summon Hawk leaves the hawks still")
	env._known = {}
	env.FireEvent("SPELLS_CHANGED")
	assert(not left.holder:IsShown() and not state.listening, "a talent change that drops Summon Hawk takes the perches")
	env._known = { [RANK3] = true }
	env.FireEvent("SPELLS_CHANGED")
	assert(Seen(env, left.lit) and Still(left) and Timer(left).start == 50, "learning it again shows the hawk already out, still")
	assert(state.pair.breath:IsPlaying(), "two readable hawks breathe at Full")
	env.SetCombat(true)
	assert(Seen(env, left.lit) and Still(left) and state.pair.breath:IsPlaying(), "entering combat alone changes nothing")
	env._totems[2] = { have = env.Secret(true), start = env.Secret(50), duration = env.Secret(18), finish = 68, spell = 1293248 }
	Hawk(env, 3, 60, true)
	assert(not state.pair.breath:IsPlaying() and Seen(env, state.pair), "once the slots are secret the ring holds still and stays lit")
	assert(Lifting(right) and Still(left) and Timer(left).start == 50, "a refresh in combat lifts only its own perch; the other keeps its timer")
	env.SetCombat(false)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("HUNTER", { [1293527] = true })
	local state = ns.SlabHawks.state
	local left, right = state.perches[1], state.perches[2]
	Hawk(env, 2, 10, true)
	Hawk(env, 3, 12, true)
	assert(env.issecretvalue(left.lit._state.AlphaFromBoolean[1]), "a secret slot lights its perch through the engine's boolean")
	assert(Seen(env, left.lit) and Seen(env, right.lit) and Seen(env, state.pair) and Seen(env, state.pair.inner), "two secret hawks light both perches and the ring")
	assert(env.issecretvalue(state.pair._state.AlphaFromBoolean[1]) and env.issecretvalue(state.pair.inner._state.AlphaFromBoolean[1]), "the ring is gated by both secret booleans, one per frame")
	assert(not state.pair.breath:IsPlaying(), "a ring Lua cannot see does not breathe, so it never loops at alpha 0")
	assert(env.issecretvalue(left.steel._state.AlphaFromBoolean[1]) and not Seen(env, left.steel), "a secret hawk hides the steel hawk through the engine's boolean")
	assert(Lifting(right) and env.issecretvalue(right.rippleGate._state.AlphaFromBoolean[1]), "a secret summon lifts under its own gate")
	assert(not state.pair.dawn[1]:IsPlaying(), "a secret pair switches its glow, since Lua cannot tell a refresh")
	Gone(env, 2, true)
	assert(not Seen(env, left.lit) and Drawn(env, left, "was") and not Drawn(env, left, "flare"), "a secret expiry fades the perch and never flares")
	assert(not Seen(env, state.pair), "and the ring goes dark through the boolean")
	Gone(env, 3, true)
	assert(not state.pair.breath:IsPlaying(), "two secret empty slots: the ring's breath stays stopped")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The render story (RENDER_FX=hawks) is one a hunter can play: summons at least Summon Hawk's 6 s category recovery
-- apart, and every hawk gone by the end.
do
	local env, K, ns = New("HUNTER", { [RANK3] = true })
	local state = ns.SlabHawks.state
	local fire, summons = env.FireEvent, {}
	env.FireEvent = function(event, slot, ...)
		fire(event, slot, ...)
		if event == "PLAYER_TOTEM_UPDATE" and env.GetTotemInfo(slot) then
			summons[#summons + 1] = select(3, env.GetTotemInfo(slot))
		end
	end
	rawset(_G, "RENDER_FX", "hawks")
	rawset(_G, "RENDER_FX_T", "60")
	env._time = env._now or 0
	dofile("Tools/render/scenes/_effects.lua").Apply(env, "actionbars", ns, {})
	rawset(_G, "RENDER_FX", nil)
	rawset(_G, "RENDER_FX_T", nil)
	assert(#summons >= 3, "the story summons a third hawk")
	for i = 2, #summons do
		assert(summons[i] - summons[i - 1] >= 6, "story summons " .. (i - 1) .. " and " .. i .. " are " .. (summons[i] - summons[i - 1]) .. " s apart; keep Summon Hawk's 6 s recovery")
	end
	assert(not Seen(env, state.perches[1].lit) and not Seen(env, state.perches[2].lit), "the story ends with both hawks gone; add their expiries")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = New("HUNTER", { [RANK3] = true }, size)
	local k = size[2] / 768
	local function Edges(region)
		local s = region:GetEffectiveScale() * k
		return region:GetLeft() * s, region:GetRight() * s, region:GetBottom() * s, region:GetTop() * s
	end
	local function Even(value)
		local n = math.floor(value + 0.5)
		return math.abs(value - n) < 1e-3 and n % 2 == 0
	end
	local centres = {}
	for i, p in ipairs(ns.SlabHawks.state.perches) do
		local l, r, b, t = Edges(p.holder)
		local cx, cy = (l + r) / 2, (b + t) / 2
		centres[i] = { cx, cy }
		for n, part in ipairs(p.parts) do
			local pl, pr, pb, pt = Edges(part)
			assert(Even(pr - pl) and Even(pt - pb), at .. "perch " .. i .. " layer " .. n .. " is an even number of pixels: " .. (pr - pl))
			if part ~= p.glint then
				assert(math.abs((pl + pr) / 2 - cx) < 1e-3 and math.abs((pb + pt) / 2 - cy) < 1e-3, at .. "perch " .. i .. " layer " .. n .. " centres on its perch")
			end
		end
	end
	local hl, hr, _, ht = Edges(ns.Slab.hub)
	local hx = (hl + hr) / 2
	assert(math.abs((centres[1][1] - hx) + (centres[2][1] - hx)) < 1e-3 and math.abs(centres[1][2] - centres[2][2]) < 1e-3, at .. "the perches mirror across the crown")
	assert(centres[1][2] < ht, at .. "the perches sit on the ring's shoulders, below its top")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The crest plan's flare rule (the review of part 1): hawks summoned together flare as one ensemble in the crest's one flare place; a flare from elsewhere stops both, and
-- the next summon takes the place back.
do
	local env, K, ns = New("HUNTER", { [RANK3] = true })
	local Effects, left, right = K.Effects, ns.SlabHawks.state.perches[1], ns.SlabHawks.state.perches[2]
	Hawk(env, 2, 100)
	Hawk(env, 3, 100)
	assert(left.flare.fade:IsPlaying() and right.flare.fade:IsPlaying(), "two hawks summoned together both flare: one ensemble, not split")
	assert(Effects.Holder("crestFlare") == Effects.PRIORITY.ready, "the ensemble holds the crest's flare place")
	local other = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	other:Play()
	assert(other:IsPlaying() and not left.flare.fade:IsPlaying() and not right.flare.fade:IsPlaying() and not right.flare:IsShown(), "a crest flare from elsewhere stops both")
	Hawk(env, 2, 130)
	assert(left.flare.fade:IsPlaying() and not other:IsPlaying(), "and the next summon stops that one in turn")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars medallions hawks ok")
