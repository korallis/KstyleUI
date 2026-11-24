-- test-actionbars-crest-target.lua: the crest's Kill window and Target lock (SlabTarget.lua). Kill window: a warrior or paladin who knows Execute or Hammer of Wrath gets a red arc on the foot of the inner rim whose alpha is the target's health through a 20% step curve, never a Lua comparison; crossing the line fades it in and ripples it once (hits inside the window do not), it beats at Full and holds still at Calm and Off; a friendly or dead target hides it; its switch hides it; under Frames it is a red line under the tracker row. Target lock: a new hostile target closes four gilt claws round the ring (claiming the hub at the target-change priority) and lights the top gem in its rank, only where the top seat is free; a friendly target or Off motion plays nothing; Frames gets nothing. With auras secret in combat neither raises, and nothing runs OnUpdate.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local FX = dofile("Tools/regression/effects_env.lua")

local EXECUTE, HAMMER, SHOUT = 20662, 24239, 6673

local function New(class, known, opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			FX.Install(e)
			local secrets = {}
			e.UnitHealthPercent = function(_, _, curve)
				local value = curve and curve:Evaluate(e._health) or e._health
				secrets[value] = secrets[value] or e.Secret(value)
				return secrets[value]
			end
			e._known = {}
			for _, id in ipairs(known or {}) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.IsSpellUsable = function() return false, false end
			e.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e._hostile, e._rank, e._level = true, "normal", 60
			e.UnitCanAttack = function() return e._target == true and e._hostile end
			e.UnitIsDead = function() return e._dead == true end
			e.UnitClassification = function() return e._rank end
			e.UnitLevel = function() return e._level end
			Slots.Install(e)
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
	local lock = ns.SlabTarget.lock
	if key == "crestLock" then return lock and lock:IsVisible() and lock or nil end
	local f = ns.SlabTrackers.state.forms[form or "crest"]
	for _, p in pairs(f and f.pieces or {}) do
		if p.spec.key == key and p:IsVisible() then return p end
	end
end

local function Alpha(env, region)
	local a = region:GetAlpha()
	return env.issecretvalue(a) and env.Reveal(a) or a
end

local function Health(env, value)
	env._health = value
	env.FireEvent("UNIT_HEALTH", "target")
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do n = n + Updating(child) end
	return n
end

-- Kill window: a warrior's arc lights below 20% through the curve, ripples once at the crossing and beats.
do
	local env, K, ns = New("WARRIOR", { SHOUT, EXECUTE })
	local kill = Piece(ns, "crestKill")
	assert(kill and kill.ripple and ns.SlabTrackers.Has("crestKill"), "a warrior who knows Execute gets the kill window on the crest")
	local x, y = kill:GetCenter()
	local hx, hy = ns.Slab.hub:GetCenter()
	assert(math.abs(x - hx) < 1 and math.abs(y - hy) < 1, "it is centred on the crest")
	assert(Alpha(env, kill.gate) == 0, "no target: dark")
	env._health = 0.5
	env.SetTarget(true)
	assert(Alpha(env, kill.gate) == 0, "a target at 50% leaves it dark")
	assert(env.issecretvalue(kill.gate:GetAlpha()), "the alpha is the curve's secret, never a Lua comparison")
	assert(kill.beat.play:IsPlaying(), "the beat runs with a hostile target at Full")
	Health(env, 0.15)
	assert(Alpha(env, kill.gate) == 1, "under 20% the foot burns")
	assert(kill.ripple.play:IsPlaying() and kill.fade.play:IsPlaying(), "the crossing fades it in and ripples it")
	local grow = kill.ripple.play._anims[1]
	assert(grow._type == "Scale" and grow._state.ScaleFrom[1] == 1 and grow._state.ScaleTo[1] > 1.2, "the ripple runs outward from the arc")
	assert(Alpha(env, kill.ripple) == 0, "and rests unseen")
	kill.ripple.play:Stop()
	kill.fade.play:Stop()
	Health(env, 0.1)
	assert(not kill.ripple.play:IsPlaying() and not kill.fade.play:IsPlaying(), "a hit inside the window does not ripple again")
	env._hostile = false
	env.SetTarget(true)
	assert(Alpha(env, kill.gate) == 0 and not kill.beat.play:IsPlaying(), "a target you cannot attack hides it and stops the beat")
	env._hostile, env._dead = true, true
	env.SetTarget(true)
	assert(Alpha(env, kill.gate) == 0, "a dead target hides it")
	env._dead = false
	env.SetTarget(true)
	assert(Alpha(env, kill.gate) == 1, "a living target in range lights it")
	K.Options.Write("Medallions", "motion", "calm")
	assert(Alpha(env, kill.gate) == 1 and not kill.beat.play:IsPlaying(), "Calm holds the beat still and keeps the burn")
	Health(env, 0.5)
	Health(env, 0.15)
	assert(kill.ripple.play:IsPlaying(), "Calm keeps the crossing ripple")
	kill.ripple.play:Stop()
	K.Options.Write("Medallions", "motion", "off")
	Health(env, 0.5)
	Health(env, 0.15)
	assert(Alpha(env, kill.gate) == 1 and not kill.ripple.play:IsPlaying() and not kill.fade.play:IsPlaying() and not kill.beat.play:IsPlaying(), "Off shows the end state only")
	K.Options.Write("ActionBars", "crestKill", false)
	assert(not Piece(ns, "crestKill"), "its switch hides it")
	K.Options.Write("ActionBars", "crestKill", true)
	assert(Piece(ns, "crestKill") == kill, "and brings it back")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	Clean(env, K, "warrior kill window")
end

-- A paladin with Hammer of Wrath gets it; a mage, with no execute, does not.
do
	local env, K, ns = New("PALADIN", { HAMMER })
	assert(Piece(ns, "crestKill"), "Hammer of Wrath gives a paladin the kill window")
	Clean(env, K, "paladin")
	local _, _, mage = New("MAGE", { 133 })
	assert(not mage.SlabTrackers.Has("crestKill") and not Piece(mage, "crestKill"), "a mage has no execute and no kill window")
	assert(Piece(mage, "crestLock"), "but every class has the target lock")
	local _, _, novice = New("WARRIOR", { SHOUT })
	assert(not Piece(novice, "crestKill"), "a warrior before Execute has none")
end

-- Target lock: claws on a new hostile target, the gem in its rank where the top seat is free.
do
	local env, K, ns = New("MAGE", { 133 })
	local lock = Piece(ns, "crestLock")
	assert(not lock.gem:IsShown() and Alpha(env, lock.claws) == 0, "no target: no gem, no claws")
	env._rank = "elite"
	env.SetTarget(true)
	assert(lock.claws.play:IsPlaying() and K.Effects.Holder("hub") == K.Effects.PRIORITY.target, "a new hostile target closes the claws, holding the hub at the target-change priority")
	local close = lock.claws.play._anims[1]
	assert(close._type == "Scale" and close._state.ScaleFrom[1] > 1.1 and close._state.ScaleTo[1] == 1, "the claws close inward to the ring")
	assert(Alpha(env, lock.claws) == 0, "and rest unseen when they finish")
	local gx, gy = lock.gem:GetCenter()
	local hx, hy = ns.Slab.hub:GetCenter()
	local s = lock.gem:GetEffectiveScale() / ns.Slab.hub:GetEffectiveScale()
	assert(lock.gem:IsShown() and math.abs(gx * s - hx) < 1 and math.abs(gy * s - hy - 60) < 1, "the gem sits on the top seat")
	assert(AB.Tinted(K, lock.stone, "SetVertexColor", "gilt"), "an elite's gem is gilt")
	for rank, token in pairs({ rare = "steelLit", worldboss = "plateHostile", normal = "steel" }) do
		env._rank = rank
		env.SetTarget(true)
		assert(AB.Tinted(K, lock.stone, "SetVertexColor", token), rank .. " lights the gem " .. token)
	end
	env._rank, env._level = "elite", -1
	env.SetTarget(true)
	assert(AB.Tinted(K, lock.stone, "SetVertexColor", "plateHostile"), "a skull-level boss is red")
	lock.claws.play:Stop()
	env._hostile = false
	env.SetTarget(true)
	assert(not lock.claws.play:IsPlaying() and not lock.gem:IsShown(), "a friendly target plays nothing and hides the gem")
	env._hostile = true
	K.Effects.Claim("hub", K.Effects.PRIORITY.proc, nil)
	env.SetTarget(true)
	assert(not lock.claws.play:IsPlaying(), "a proc holding the hub keeps it")
	K.Effects.Stop("hub")
	K.Options.Write("Medallions", "motion", "off")
	env.SetTarget(true)
	assert(not lock.claws.play:IsPlaying() and lock.gem:IsShown(), "Off plays no claws but keeps the gem")
	K.Options.Write("ActionBars", "crestLock", false)
	assert(not Piece(ns, "crestLock"), "its switch hides it")
	Clean(env, K, "target lock")
end

-- The top seat is taken: a warrior's threat gem keeps it, so the lock shows claws only.
do
	local env, K, ns = New("WARRIOR", { SHOUT })
	env.SetTarget(true)
	local lock = Piece(ns, "crestLock")
	assert(lock.claws.play:IsPlaying() and not lock.gem:IsShown(), "the threat gem holds the top seat")
	K.Options.Write("ActionBars", "crestThreat", false)
	env.SetTarget(true)
	assert(lock.gem:IsShown(), "with it off the rank gem takes the seat")
	Clean(env, K, "top seat")
end

-- In combat with auras secret: target changes and hits raise nothing.
do
	local env, K, ns = New("WARRIOR", { SHOUT, EXECUTE })
	env._aurasSecret = true
	env.SetCombat(true)
	env._health = 0.5
	env.SetTarget(true)
	Health(env, 0.1)
	assert(Alpha(env, Piece(ns, "crestKill").gate) == 1 and Piece(ns, "crestLock").claws.play:IsPlaying(), "both effects play in combat")
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Clean(env, K, "combat")
end

-- Frames: the kill window is a red line under the tracker row; the target lock has no Frames form.
do
	local env, K, ns = New("WARRIOR", { SHOUT, EXECUTE }, { frames = true })
	local line = Piece(ns, "crestKill", "row")
	assert(line and not line.ripple and not Piece(ns, "crestLock", "row"), "under Frames: a kill line and no target lock")
	local row = ns.SlabTrackers.state.forms.row.frame
	local _, ly = line:GetCenter()
	local _, ry = row:GetCenter()
	assert(ly < ry - 13, "the line sits under the row")
	env._health = 0.1
	env.SetTarget(true)
	assert(Alpha(env, line.gate) == 1, "and burns in range")
	Clean(env, K, "frames")
end

print("test-actionbars-crest-target: ok")
