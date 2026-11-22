-- test-actionbars-medallions-storm.lua: the crest's storm orbs: a shaman who knows Lightning Shield gets three studs, three orbs and a storm halo fed by Blizzard's aura slots, nobody else gets a frame, a container, an event or a callback; each orb lights from the shield's own charge count through an application bar, secret or not, so three charges light three orbs and a spent charge drains its orb; the player's readable casts choose the flourishes: a cast ignites, a strike throws a bolt from the spent orb (one per hit, whether the aura update or the strike comes first), the last bolt leaves from where its orb was on the orbit, one charge dims the halo, the last orb flickers and the halo crackles out, an expiry too; an out-of-combat read keeps Lua's count true, strikes missed while switched off leave it unknown and an unknown count plays no flourish; learning the spell while auras are secret builds nothing until combat ends and a half-built crest stays hidden; an unchanged shield reads one rank per aura update; Calm holds the orbs on their studs, Off stops what is playing and drains at once, the engine loops wait out secret auras, nothing runs OnUpdate, the switch hides everything, and every part is an even number of pixels inside the ring at four screen sizes.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local RANK7, RANK1, STRIKE7 = 10432, 324, 26363

local function New(class, known, size)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._known = known or {}
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_UnitAuras = e.C_UnitAuras or {}
			e.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
				if e._aurasSecret then return nil end
				for _, a in ipairs(e._slotAuras.player or {}) do
					if a.id == id then return { spellId = id, applications = a.count } end
				end
			end
			Slots.Install(e)
		end,
	})
	local register, unregister = K.Callbacks.Register, K.Callbacks.Unregister
	env._callbacks = {}
	K.Callbacks.Register = function(event, owner, fn)
		if owner == "ActionBars.SlabStorm" then env._callbacks[event] = true end
		return register(event, owner, fn)
	end
	K.Callbacks.Unregister = function(event, owner)
		if owner == "ActionBars.SlabStorm" then env._callbacks[event] = nil end
		return unregister(event, owner)
	end
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

local function Cast(env, id)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-guid", id)
end

local function Shield(env, count, spell)
	local auras = env._slotAuras.player
	if count == nil then
		Slots.Set(env, "player", nil)
	elseif auras and auras[1] then
		auras[1].count = count
		Slots.Set(env, "player", auras)
	else
		Slots.Set(env, "player", { { id = spell or RANK7, count = count } })
	end
	env.FireEvent("UNIT_AURA", "player", {})
end

local function Reveal(env, v)
	return env.issecretvalue(v) and env.Reveal(v) or v
end

-- Lit(env, s) -> whether orb s draws: its slot button and bar shown and the bar filled.
local function Lit(env, s)
	local low, high = s.orb:GetMinMaxValues()
	return s.orb:GetParent():IsShown() and s.orb:IsShown() and Reveal(env, s.orb:GetValue()) >= Reveal(env, high) and Reveal(env, low) < Reveal(env, high)
end

local function Lights(env, ns)
	local n = 0
	for _, s in ipairs(ns.SlabStorm.state.seats) do
		n = n + (Lit(env, s) and 1 or 0)
	end
	return n
end

local function Fired(frame)
	return frame:IsShown() and frame.play:IsPlaying()
end

local function Finish(frame)
	frame.play:GetScript("OnFinished")(frame.play)
end

local function Playing(ns)
	local state, n = ns.SlabStorm.state, 0
	for _, s in ipairs(state.seats) do
		n = n + (s.orbit:IsPlaying() and 1 or 0) + (s.ignite.play:IsPlaying() and 1 or 0) + (s.strike.play:IsPlaying() and 1 or 0)
	end
	for _, loop in ipairs(state.loops) do
		n = n + (loop.group:IsPlaying() and 1 or 0)
	end
	return n + (state.flicker:IsPlaying() and 1 or 0) + (state.blast.play:IsPlaying() and 1 or 0) + (state.crackle.play:IsPlaying() and 1 or 0)
end

local function Registered(ns)
	local n = 0
	for _, loop in ipairs(ns.SlabStorm.state.loops) do
		for _, group in ipairs(loop.button._shownAnimations) do
			n = n + (group == loop.group and 1 or 0)
		end
	end
	return n
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do
		n = n + Updating(child)
	end
	return n
end

for _, case in ipairs({ { "WARRIOR", { [RANK7] = true } }, { "HUNTER", { [RANK7] = true } }, { "SHAMAN", {} } }) do
	local env, K, ns = New(case[1], case[2])
	local state = ns.SlabStorm.state
	assert(state.holder == nil and #state.seats == 0 and not state.listening, case[1] .. ": no orb, stud or event unless a shaman knows Lightning Shield")
	assert(#env._slotContainers == 0, case[1] .. ": no aura container either")
	assert(next(env._callbacks) == nil, case[1] .. ": no storm callback")
	Shield(env, 3)
	Cast(env, RANK7)
	assert(state.holder == nil and state.count == nil, case[1] .. ": a cast builds and counts nothing")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

do
	local env, K, ns = New("SHAMAN", { [RANK1] = true })
	local state = ns.SlabStorm.state
	local seats = state.seats
	assert(#seats == 3 and state.holder:IsShown() and state.listening, "a shaman who knows any rank gets three orbs over three studs")
	assert(#state.containers == 4 and state.fed == true, "four aura containers, one for the halo and one per orb, all feeding")
	for i, s in ipairs(seats) do
		local options = s.orb:GetParent()._applicationBar[2]
		assert(options.minApplications == i - 1 and options.maxApplications == i, "orb " .. i .. " fills from " .. (i - 1) .. " to " .. i .. " charges")
		assert(s.pin:IsShown() and s.pin:GetFrameLevel() < s.frame:GetFrameLevel(), "orb " .. i .. " sits over its stud")
	end
	assert(Lights(env, ns) == 0 and state.count == 0, "no shield: no orb lights and Lua reads zero charges")
	assert(not seats[1].orbit:IsPlaying() and not state.flicker:IsPlaying(), "no shield: nothing circles or flickers")
	assert(Registered(ns) == #state.loops, "at Full the halo's and the orbs' loops are the engine's shown animations")

	-- Cast: three orbs light from the aura's own count, the orbs ignite and start circling.
	Shield(env, 3, RANK1)
	Cast(env, RANK1)
	assert(Lights(env, ns) == 3, "three charges light three orbs")
	assert(Fired(state.blast) and Fired(seats[1].ignite) and Fired(seats[3].ignite), "a cast bursts the crest and ignites every orb")
	assert(state.count == 3 and seats[1].orbit:IsPlaying() and seats[3].orbit:IsPlaying(), "the orbs circle at Full")
	local halo = state.loops[1]
	assert(halo.button:IsShown() and halo.group:IsPlaying(), "the halo shows and crackles while the shield is up")
	Finish(state.blast)
	assert(not state.blast:IsShown(), "the burst hides once it has played")

	-- Strikes spend charges from the top: the spent orb drains under the engine's ease and throws a bolt.
	Shield(env, 2)
	Cast(env, STRIKE7)
	assert(Lights(env, ns) == 2 and not Lit(env, seats[3]), "two charges light two orbs")
	assert(seats[3].orb._ease and seats[3].orb._ease.from == 3 and seats[3].orb._ease.to == 2, "the spent orb drains under the engine's ease")
	assert(Fired(seats[3].strike) and not seats[2].strike:IsShown(), "the spent orb throws the bolt")
	local aim = seats[3].bolt:GetRotation()
	assert(type(aim) == "number" and aim ~= 0, "the bolt is turned to fly outward")
	assert(not state.flicker:IsPlaying(), "two charges do not flicker")
	Shield(env, 1)
	Cast(env, STRIKE7)
	assert(Lights(env, ns) == 1 and Fired(seats[2].strike), "one charge lights one orb; the second orb threw the bolt")
	assert(state.flicker:IsPlaying(), "the last orb flickers")
	Shield(env, nil)
	Cast(env, STRIKE7)
	assert(Lights(env, ns) == 0 and not halo.button:IsShown() and not halo.group:IsPlaying(), "the last strike ends the shield: no orb, no halo")
	assert(Fired(seats[1].strike) and Fired(state.crackle), "the last orb throws its bolt and the halo crackles out")
	assert(state.count == 0 and not seats[1].orbit:IsPlaying() and not state.flicker:IsPlaying(), "nothing circles or flickers once the shield is gone")
	Finish(state.crackle)
	assert(not state.crackle:IsShown(), "the crackle hides once it has played")
	Cast(env, STRIKE7)
	assert(state.count == 0, "a strike with no charges left changes nothing")
	Shield(env, 9)
	Cast(env, RANK7)
	env.FireEvent("UNIT_AURA", "player", {})
	Shield(env, 8)
	assert(state.count == 8 and Lights(env, ns) == 3, "more than three charges keep all three orbs lit, and a strike above three throws nothing")
	Shield(env, nil)

	-- Expiry out of combat: the read finds no shield and Lua's count follows.
	Shield(env, 3)
	Cast(env, RANK7)
	Shield(env, nil)
	assert(state.count == 0 and Lights(env, ns) == 0 and not seats[1].orbit:IsPlaying(), "an expired shield empties the count and stops the orbit")

	-- A read out of combat corrects Lua's count; a recast while two charges are left fills all three again.
	Shield(env, nil)
	Shield(env, 2)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(state.count == 0, "with no shield Lua waits for a cast rather than reading every aura update")
	Cast(env, RANK7)
	Shield(env, 2)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(state.count == 2 and Lights(env, ns) == 2, "an out-of-combat read takes the charge count")
	Shield(env, 3)
	Cast(env, RANK7)
	assert(state.count == 3 and Lights(env, ns) == 3, "a recast fills all three orbs")
	assert(Updating(state.holder) == 0, "no storm frame runs OnUpdate")

	-- Calm: the orbs hold on their studs and the loops leave the engine; the flares stay.
	K.Options.Write("Medallions", "motion", "calm")
	assert(not seats[1].orbit:IsPlaying() and Registered(ns) == 0, "Calm holds the orbs on their studs and drops the loops")
	assert(Lights(env, ns) == 3, "Calm keeps every charge lit")
	Shield(env, 2)
	Cast(env, STRIKE7)
	assert(Fired(seats[3].strike), "Calm keeps the bolt")
	Shield(env, 1)
	Cast(env, STRIKE7)
	assert(not state.flicker:IsPlaying(), "Calm does not flicker")
	K.Options.Write("Medallions", "motion", "off")
	assert(Playing(ns) == 0 and not seats[2].strike:IsShown(), "Off stops the flourishes already playing")
	Shield(env, 3)
	Cast(env, RANK7)
	Shield(env, 2)
	Cast(env, STRIKE7)
	assert(Playing(ns) == 0, "Off plays no storm animation")
	assert(not seats[3].strike:IsShown() and not seats[1].ignite:IsShown(), "Off hides the flourishes")
	assert(Lights(env, ns) == 2 and seats[3].orb._ease == nil, "Off shows the charges at once")
	K.Options.Write("Medallions", "motion", "full")
	assert(Registered(ns) == #state.loops and seats[1].orbit:IsPlaying(), "Full gives the loops back to the engine and circles again")

	-- The switch hides everything and drops every event; turning it back on reads the shield again.
	K.Options.Write("ActionBars", "crestStorm", false)
	env.RunTimers()
	assert(not state.holder:IsShown() and not state.listening and next(env._callbacks) == nil, "Lightning Shield on the crest off hides it all and stops listening")
	assert(state.fed == false and not seats[1].orbit:IsPlaying(), "and the containers stop feeding")
	K.Options.Write("ActionBars", "crestStorm", true)
	env.RunTimers()
	assert(state.holder:IsShown() and state.listening and state.fed == true and Lights(env, ns) == 2, "turning it back on lights the charges again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- In combat the aura is secret: the engine still lights the orbs from the secret count, Lua neither reads nor compares
-- it, counts from the player's own casts, plays no flourish while its count is unknown, and waits out the secret
-- auras before it touches the engine's buttons.
do
	local env, K, ns = New("SHAMAN", { [RANK7] = true })
	local state = ns.SlabStorm.state
	local seats = state.seats
	env._aurasSecret = true
	env.SetCombat(true)
	Shield(env, 3)
	assert(env.issecretvalue(seats[1].orb:GetValue()) and Lights(env, ns) == 3, "a secret count lights the orbs through the engine")
	Cast(env, env.Secret(STRIKE7))
	assert(state.count == 0, "a secret spell ID is ignored")
	env.FireEvent("UNIT_AURA", "player", {})
	assert(state.count == 0, "a secret shield leaves Lua's count alone")
	Cast(env, RANK7)
	Shield(env, 2)
	Cast(env, STRIKE7)
	assert(state.count == 2 and Fired(seats[3].strike), "in combat Lua counts the player's own casts and strikes")
	K.Options.Write("Medallions", "motion", "calm")
	assert(Registered(ns) == #state.loops, "a motion change waits while auras are secret")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(Registered(ns) == 0, "and lands when combat ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))

	local fresh, FK, fns = New("SHAMAN", { [RANK7] = true })
	fresh._aurasSecret = true
	fns.SlabStorm.state.count = nil
	Shield(fresh, 3)
	Shield(fresh, 2)
	Cast(fresh, STRIKE7)
	assert(Lights(fresh, fns) == 2 and not fns.SlabStorm.state.seats[3].strike:IsShown(), "an unknown count throws no bolt, and the engine still shows the charges")
	assert(#fresh._errors == 0 and FK.ErrorCount() == 0, AB.Errors(fresh))
end

-- Learning the spell while auras are secret builds nothing until combat ends, and a build that fails part way shows
-- nothing and raises nothing.
do
	local env, K, ns = New("SHAMAN", {})
	local state = ns.SlabStorm.state
	env._aurasSecret = true
	env.SetCombat(true)
	env._known[RANK7] = true
	ns.SlabStorm.Recheck()
	assert(state.holder == nil and not state.failed and #env._slotContainers == 0, "learning Lightning Shield while auras are secret builds nothing yet")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(state.holder:IsShown() and state.listening and state.fed == true, "and the orbs build when combat ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))

	local broken, BK, bns = New("SHAMAN", {})
	local texture = BK.Tokens.Texture
	BK.Tokens.Texture = function(name, ...)
		assert(name ~= "stormOrb", "no orb art")
		return texture(name, ...)
	end
	broken._known[RANK7] = true
	bns.SlabStorm.Recheck()
	BK.Tokens.Texture = texture
	local bstate = bns.SlabStorm.state
	assert(bstate.failed and not bstate.listening and #bstate.parts > 0, "a build that fails part way latches off")
	for n, part in ipairs(bstate.parts) do
		assert(not part:IsVisible(), "the half-built part " .. n .. " stays hidden")
	end
	assert(#broken._errors == 0, AB.Errors(broken))
end

-- One transition per hit: an aura update and the strike that caused it spend one charge between them, in either order,
-- and an expiry crackles the halo out; one charge left dims the halo.
do
	local env, K, ns = New("SHAMAN", { [RANK7] = true })
	local state, seats = ns.SlabStorm.state, ns.SlabStorm.state.seats
	local function Halo()
		return state.loops[1].group:GetParent():GetAlpha()
	end
	Shield(env, 3)
	Cast(env, RANK7)
	Shield(env, 2)
	Cast(env, STRIKE7)
	assert(Lights(env, ns) == 2 and state.count == 2, "an aura update before its strike spends one charge, not two")
	assert(Fired(seats[3].strike) and not seats[2].strike:IsShown() and not state.flicker:IsPlaying(), "and the third orb throws the bolt")
	Cast(env, STRIKE7)
	Shield(env, 1)
	assert(state.count == 1 and Fired(seats[2].strike), "a strike before its aura update spends one charge too")
	assert(Halo() < 1, "one charge left dims the halo")
	Finish(seats[2].strike)
	Shield(env, 3)
	Cast(env, RANK7)
	assert(Halo() == 1, "a recast brightens it again")
	Shield(env, nil)
	assert(Fired(state.crackle) and not seats[2].strike:IsShown(), "an expiry crackles the halo out and throws no bolt")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Strikes missed while the switch is off in combat leave the count unknown, so no flourish plays from a stale count.
do
	local env, K, ns = New("SHAMAN", { [RANK7] = true })
	local state, seats = ns.SlabStorm.state, ns.SlabStorm.state.seats
	Shield(env, 3)
	Cast(env, RANK7)
	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestStorm", false)
	env.RunTimers()
	Shield(env, 1)
	Cast(env, STRIKE7)
	Cast(env, STRIKE7)
	K.Options.Write("ActionBars", "crestStorm", true)
	env.RunTimers()
	assert(Lights(env, ns) == 1 and state.count == nil, "missed strikes leave the count unknown while the engine shows the charge")
	Shield(env, nil)
	Cast(env, STRIKE7)
	assert(not seats[3].strike:IsShown() and not seats[1].strike:IsShown(), "and the next strike throws no bolt")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(state.count == 0, "combat's end reads the count again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Off stops the flourishes already playing and drains a spent orb at once; the last bolt leaves from where its orb
-- was on the orbit, not from its stud.
do
	local env, K, ns = New("SHAMAN", { [RANK7] = true })
	local state, seats = ns.SlabStorm.state, ns.SlabStorm.state.seats
	env.GetTime = function() return env._now end
	Shield(env, 3)
	Cast(env, RANK7)
	K.Options.Write("Medallions", "motion", "off")
	assert(Playing(ns) == 0 and not state.blast:IsShown() and not seats[1].ignite:IsShown(), "Off stops the burst and the ignites")
	Shield(env, 2)
	assert(seats[3].orb:GetParent()._applicationBar[2].interpolation == 0 and seats[3].orb._ease == nil, "Off drains a spent orb at once")
	K.Options.Write("Medallions", "motion", "full")
	assert(seats[3].orb:GetParent()._applicationBar[2].interpolation == 1, "Full eases it again")
	env._aurasSecret = true
	env.SetCombat(true)
	env._now = env._now + 9 / 4
	Cast(env, STRIKE7)
	Cast(env, STRIKE7)
	local x, y = seats[1].strike:GetCenter()
	local hx, hy = ns.Slab.hub:GetCenter()
	local angle = math.deg(math.atan2(x - hx, y - hy)) % 360
	assert(Fired(seats[1].strike) and math.abs(angle - 120) < 1, "the last bolt leaves a quarter orbit on from its stud: " .. angle)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- An unchanged shield reads one rank per aura update and asks no effect policy; other casts ask nothing either.
do
	local env, K = New("SHAMAN", { [RANK1] = true })
	Shield(env, 3, RANK1)
	Cast(env, RANK1)
	env.FireEvent("UNIT_AURA", "player", {})
	local get, allows = env.C_UnitAuras.GetPlayerAuraBySpellID, K.Effects.Allows
	local reads, asks = 0, 0
	env.C_UnitAuras.GetPlayerAuraBySpellID = function(id) reads = reads + 1 return get(id) end
	K.Effects.Allows = function(kind) asks = asks + 1 return allows(kind) end
	for _ = 1, 100 do
		env.FireEvent("UNIT_AURA", "player", {})
		Cast(env, 12345)
	end
	K.Effects.Allows, env.C_UnitAuras.GetPlayerAuraBySpellID = allows, get
	assert(reads == 100 and asks == 0, "100 unrelated aura updates and casts: " .. reads .. " aura reads, " .. asks .. " policy queries")
end

for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = New("SHAMAN", { [RANK7] = true }, size)
	local k = size[2] / 768
	local function Edges(region)
		local s = region:GetEffectiveScale() * k
		return region:GetLeft() * s, region:GetRight() * s, region:GetBottom() * s, region:GetTop() * s
	end
	local function Even(value)
		local n = math.floor(value + 0.5)
		return math.abs(value - n) < 1e-3 and n % 2 == 0
	end
	local hl, hr, hb, ht = Edges(ns.Slab.hub)
	local hx, hy, ring = (hl + hr) / 2, (hb + ht) / 2, (hr - hl) / 2
	for n, part in ipairs(ns.SlabStorm.state.parts) do
		local pl, pr, pb, pt = Edges(part)
		assert(Even(pr - pl) and Even(pt - pb), at .. "part " .. n .. " is an even number of pixels: " .. (pr - pl))
	end
	for i, s in ipairs(ns.SlabStorm.state.seats) do
		local l, r, b, t = Edges(s.pin)
		local dx, dy = (l + r) / 2 - hx, (b + t) / 2 - hy
		local reach = math.sqrt(dx * dx + dy * dy) + (r - l) / 2
		assert(reach <= ring * 0.9, at .. "orb " .. i .. " stays inside the rune ring, clear of the shoulder medals: " .. reach .. " of " .. ring)
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars medallions storm ok")
