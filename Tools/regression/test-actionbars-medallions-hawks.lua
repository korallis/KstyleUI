-- test-actionbars-medallions-hawks.lua: the crest's hawk perches: a hunter who knows Summon Hawk gets two perches on the rune ring's shoulders, nobody else gets a frame, an event or a callback; each perch lights from totem slot 2 or 3 through the slot's own boolean and drains through the slot's duration object, secret or not, with no Lua compare; a summon flares, an expiry fades, a third summon refreshes the oldest perch alone, both hawks out light the rune ring, breathing only while Lua can read both slots; a flyout or spellbook update leaves a playing flare alone; the render story keeps Summon Hawk's recovery and ends empty; Calm stills the breath, Off shows end states with no animation, nothing runs OnUpdate, Hawk perches off hides everything, and every layer is an even number of pixels centred on its perch, mirrored across the crown, at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local RANK3 = 1293526

local function New(class, known, size)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._totems, e._known = {}, known or {}
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

local function Playing(ns)
	local n = 0
	for _, p in ipairs(ns.SlabHawks.state.perches) do
		n = n + (p.was.fade:IsPlaying() and 1 or 0) + (p.flare.fade:IsPlaying() and 1 or 0)
	end
	return n + (ns.SlabHawks.state.pair.breath:IsPlaying() and 1 or 0)
end

local function Updating(ns)
	local state, n = ns.SlabHawks.state, 0
	local frames = { state.pair, state.pair.inner, state.pair.glow, state.pair.glyphs, state.pair.halo }
	for _, p in ipairs(state.perches) do
		for _, key in ipairs({ "holder", "timer", "lit", "wasGate", "was", "flareGate", "flare" }) do
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
	local reads = env._reads
	env.FireEvent("SPELL_FLYOUT_UPDATE", 1)
	env.FireEvent("SPELLS_CHANGED")
	assert(left.flare.fade:IsPlaying() and env._reads == reads, "a flyout or spellbook update that changes nothing leaves the perches alone")
	assert(not state.pair:IsShown(), "one hawk leaves the ring plain")
	left.flare.fade:GetScript("OnFinished")(left.flare.fade)
	assert(not left.flare:IsShown(), "the flare hides once it has played")

	-- 1 -> 2: both perches light and the rune ring glows.
	Hawk(env, 3, 106)
	assert(Seen(env, left.lit) and Seen(env, right.lit), "two hawks light both perches")
	assert(Drawn(env, right, "flare") and not left.flare.fade:IsPlaying(), "only the new hawk's perch flares")
	assert(Seen(env, state.pair) and Seen(env, state.pair.inner) and state.pair.breath:IsPlaying(), "both hawks out light the rune ring, breathing at Full")
	assert(state.pair.glyphs:GetFrameLevel() > ns.Slab.hub:GetFrameLevel() and state.pair.halo:GetFrameLevel() < ns.Slab.hub:GetFrameLevel(), "the glyphs glow over the band and the halo sits under the hub")

	-- Expiry: the left hawk leaves, its perch fades, the ring goes plain.
	Gone(env, 2)
	assert(not Seen(env, left.lit) and Drawn(env, left, "was") and left.was.fade:IsPlaying(), "an expired hawk's perch fades out")
	assert(not Drawn(env, left, "flare"), "an expiry does not flare")
	assert(not state.pair:IsShown() and not state.pair.breath:IsPlaying(), "one hawk left: the ring goes plain")
	left.was.fade:GetScript("OnFinished")(left.was.fade)
	assert(not left.was:IsShown(), "the fade hides once it has played")

	-- Resummon fills the empty perch; a third summon refreshes the oldest perch alone.
	Hawk(env, 2, 121)
	assert(Seen(env, left.lit) and Seen(env, right.lit) and state.pair:IsShown(), "a resummon fills the empty perch")
	left.flare.fade:Stop()
	Hawk(env, 3, 123)
	assert(Timer(right).start == 123 and Timer(left).start == 121, "the replaced hawk's timer starts again; the other keeps its own")
	assert(Drawn(env, right, "flare") and Drawn(env, right, "was") and Seen(env, right.lit), "the refreshed perch flares while its old hawk fades under a lit hawk, so it never blinks")
	assert(not left.flare.fade:IsPlaying() and not left.was.fade:IsPlaying(), "the other perch does not move")
	assert(Updating(ns) == 0, "no hawk layer runs OnUpdate")

	-- Calm stills the breath; Off plays nothing and shows the end states.
	K.Options.Write("Medallions", "motion", "calm")
	assert(state.pair:IsShown() and not state.pair.breath:IsPlaying(), "Calm stills the ring's breath")
	Hawk(env, 2, 130)
	assert(left.flare.fade:IsPlaying(), "Calm keeps the flare")
	K.Options.Write("Medallions", "motion", "off")
	Gone(env, 3)
	Hawk(env, 2, 140)
	assert(Playing(ns) == 0, "Off plays no hawk animation")
	assert(not left.flare:IsShown() and not left.was:IsShown() and not right.was:IsShown(), "Off hides the flare and the fade")
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

print("actionbars medallions hawks ok")
