-- test-actionbars-crest-target.lua: the crest's Kill window and Target lock (SlabTarget.lua). Kill window: a warrior or paladin who knows Execute or Hammer of Wrath gets a burning band on the foot of the inner rim (a white-orange core, feathered tips) whose alpha is the target's health through a step curve that lights under 20%, never a Lua comparison; crossing the line fades it in and sends one separate wave outward (hits inside the window do not), it beats at Full and holds still at Calm and Off; a friendly or dead target hides it; its switch hides it, and switched off neither effect asks about the target on a hit; under Frames it is a red line as wide as the tracker row. Target lock: a new hostile target closes four forged claws inward round the ring (claiming the hub at the target-change priority) and lights the top gem in its rank only while the top seat is free, rechecked when a form or switch changes the seat; a friendly or dead target, or switching it off, stops the claws and frees only its own claim; it is not built in combat. With auras secret in combat neither raises, and nothing runs OnUpdate.
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
	if opts.lockOff then K.Options.Write("ActionBars", "crestLock", false) end
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

local function Claws(lock)
	return lock.claws[1].play:IsPlaying()
end

local function Counting(env, names)
	local n = {}
	for _, name in ipairs(names) do
		local real = env[name]
		n[name] = 0
		env[name] = function(...) n[name] = n[name] + 1 return real(...) end
	end
	return n
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

-- Kill window: a warrior's band lights under 20% through the curve, waves once at the crossing and beats.
do
	local env, K, ns = New("WARRIOR", { SHOUT, EXECUTE })
	local kill = Piece(ns, "crestKill")
	assert(kill and kill.ripple and ns.SlabTrackers.Has("crestKill"), "a warrior who knows Execute gets the kill window on the crest")
	local x, y = kill:GetCenter()
	local hx, hy = ns.Slab.hub:GetCenter()
	assert(math.abs(x - hx) < 1 and math.abs(y - hy) < 1, "it is centred on the crest")
	assert(AB.Tinted(K, kill.core, "SetVertexColor", "jewelComboCore") and kill.core:GetBlendMode() == "ADD", "the foot has a hot white-orange core")
	assert(AB.W.LastCall(kill.band, "SetGradient") and AB.W.LastCall(kill.edge, "SetGradient"), "the band and its edge feather towards their tips")
	assert(Alpha(env, kill) == 0, "no target: dark")
	env._health = 0.5
	env.SetTarget(true)
	assert(Alpha(env, kill) == 0, "a target at 50% leaves it dark")
	assert(env.issecretvalue(kill:GetAlpha()), "the alpha is the curve's secret, never a Lua comparison")
	assert(kill.beat.play:IsPlaying() and kill.beat.play._state.Looping[1] == "REPEAT", "the beat runs with a hostile target at Full")
	Health(env, 0.2)
	assert(Alpha(env, kill) == 0, "at exactly 20% it stays dark: the band lights under the line")
	Health(env, 0.15)
	assert(Alpha(env, kill) == 1, "under 20% the foot burns")
	assert(kill.ripple.play:IsPlaying() and kill.ripple.grow:IsPlaying() and kill.fade.play:IsPlaying(), "the crossing fades it in and sends the wave")
	local moved, grown
	for _, a in ipairs(kill.ripple.play._anims) do
		if a._type == "Translation" then moved = a._state.Offset end
	end
	for _, a in ipairs(kill.ripple.grow._anims) do
		if a._type == "Scale" then grown = a._state.ScaleTo end
	end
	assert(moved and moved[1] == 0 and moved[2] < -8 and grown and grown[1] > 1.15, "the wave is its own edge, travelling outward from the foot")
	assert(Alpha(env, kill.ripple) == 0, "and rests unseen")
	kill.ripple.play:Stop()
	kill.fade.play:Stop()
	Health(env, 0.1)
	assert(not kill.ripple.play:IsPlaying() and not kill.fade.play:IsPlaying(), "a hit inside the window does not wave again (the client compares the bar's values)")
	env._hostile = false
	env.SetTarget(true)
	assert(Alpha(env, kill) == 0 and not kill.beat.play:IsPlaying(), "a target you cannot attack hides it and stops the beat")
	env._hostile, env._dead = true, true
	env.SetTarget(true)
	assert(Alpha(env, kill) == 0, "a dead target hides it")
	env._dead = false
	env.SetTarget(true)
	assert(Alpha(env, kill) == 1, "a living target in range lights it")
	K.Options.Write("Medallions", "motion", "calm")
	assert(Alpha(env, kill) == 1 and not kill.beat.play:IsPlaying(), "Calm holds the beat still and keeps the burn")
	Health(env, 0.5)
	Health(env, 0.15)
	assert(kill.ripple.play:IsPlaying(), "Calm keeps the crossing wave")
	kill.ripple.play:Stop()
	K.Options.Write("Medallions", "motion", "off")
	Health(env, 0.5)
	Health(env, 0.15)
	assert(Alpha(env, kill) == 1 and not kill.ripple.play:IsPlaying() and not kill.fade.play:IsPlaying() and not kill.beat.play:IsPlaying(), "Off shows the end state only")
	K.Options.Write("ActionBars", "crestKill", false)
	assert(not Piece(ns, "crestKill"), "its switch hides it")
	K.Options.Write("ActionBars", "crestKill", true)
	assert(Piece(ns, "crestKill") == kill, "and brings it back")
	assert(Updating(ns.SlabTrackers.state.forms.crest.frame) == 0, "nothing runs OnUpdate")
	Clean(env, K, "warrior kill window")
end

-- Health events: switched off, neither effect asks about the target; on, a hit never re-reads the target's rank.
do
	local env, K = New("WARRIOR", { SHOUT, EXECUTE })
	env.SetTarget(true)
	local n = Counting(env, { "UnitCanAttack", "UnitIsDead", "UnitLevel", "UnitClassification", "UnitHealthPercent" })
	for _ = 1, 10 do Health(env, 0.6) end
	assert(n.UnitLevel == 0 and n.UnitClassification == 0 and n.UnitHealthPercent == 10, "a hit repaints the kill band and never re-reads the target's rank")
	K.Options.Write("ActionBars", "crestKill", false)
	K.Options.Write("ActionBars", "crestLock", false)
	n = Counting(env, { "UnitCanAttack", "UnitIsDead", "UnitLevel", "UnitClassification", "UnitHealthPercent" })
	for _ = 1, 10 do Health(env, 0.6) end
	assert(n.UnitCanAttack + n.UnitIsDead + n.UnitLevel + n.UnitClassification + n.UnitHealthPercent == 0, "both switched off: a hit asks nothing")
	Clean(env, K, "health events")
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

-- Target lock: forged claws close on a new hostile target, the gem in its rank where the top seat is free.
do
	local env, K, ns = New("MAGE", { 133 })
	local lock = Piece(ns, "crestLock")
	assert(not lock.gem:IsShown() and #lock.claws == 4 and Alpha(env, lock.claws[1]) == 0, "no target: no gem, four claws unseen")
	for _, c in ipairs(lock.claws) do
		assert(c.art:GetTexture():find("PipClaw130", 1, true) and c.glow:GetTexture():find("PipClawGlow130", 1, true), "each claw is the forged claw with its glow")
	end
	env._rank = "elite"
	env.SetTarget(true)
	assert(Claws(lock) and K.Effects.Holder("hub") == K.Effects.PRIORITY.target, "a new hostile target closes the claws, holding the hub at the target-change priority")
	local px, py = lock:GetCenter()
	for _, c in ipairs(lock.claws) do
		local cx, cy = c:GetCenter()
		local close = c.play._anims[1]
		local dx, dy = close._state.Offset[1], close._state.Offset[2]
		assert(close._type == "Translation" and math.abs(math.sqrt(dx * dx + dy * dy) - 12) < 0.5 and dx * (cx - px) < 0 and dy * (cy - py) < 0, "each claw travels 12 units inward")
	end
	assert(Alpha(env, lock.claws[1]) == 0, "and rests unseen when they finish")
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
	env._hostile = false
	env.SetTarget(true)
	assert(not Claws(lock) and K.Effects.Holder("hub") == nil and not lock.gem:IsShown(), "a friendly target mid-close stops the claws, frees the hub and hides the gem")
	env._hostile = true
	env.SetTarget(true)
	K.Options.Write("ActionBars", "crestLock", false)
	assert(not Claws(lock) and K.Effects.Holder("hub") == nil, "switching it off mid-close stops the claws and frees the hub")
	K.Options.Write("ActionBars", "crestLock", true)
	env.SetTarget(true)
	K.Effects.Claim("hub", K.Effects.PRIORITY.proc, nil)
	env._hostile = false
	env.SetTarget(true)
	assert(K.Effects.Holder("hub") == K.Effects.PRIORITY.proc, "a newer owner of the hub keeps it")
	env._hostile = true
	env.SetTarget(true)
	assert(not Claws(lock), "a proc holding the hub keeps it from the claws")
	K.Effects.Stop("hub")
	env._dead = true
	Health(env, 0)
	assert(not lock.gem:IsShown(), "the target dying hides its gem")
	env._dead = false
	K.Options.Write("Medallions", "motion", "off")
	env.SetTarget(true)
	assert(not Claws(lock) and lock.gem:IsShown(), "Off plays no claws but keeps the gem")
	K.Options.Write("ActionBars", "crestLock", false)
	assert(not Piece(ns, "crestLock"), "its switch hides it")
	Clean(env, K, "target lock")
end

-- The top seat is taken: a warrior's threat gem, or a cat-form druid's jewels, keep it; the gem follows the seat.
do
	local env, K, ns = New("WARRIOR", { SHOUT })
	env.SetTarget(true)
	local lock = Piece(ns, "crestLock")
	assert(Claws(lock) and not lock.gem:IsShown(), "the threat gem holds the top seat")
	K.Options.Write("ActionBars", "crestThreat", false)
	assert(lock.gem:IsShown(), "with it off the rank gem takes the seat")
	Clean(env, K, "top seat")
	local denv, DK, dns = New("DRUID", {})
	local dlock = dns.SlabTarget.lock
	denv.UnitPowerMax = function() return 5 end
	denv.SetTarget(true)
	assert(dns.SlabJewels.state.count == 0 and dlock.gem:IsShown(), "a caster druid's top seat is free")
	denv._powerType, denv._powerToken = 3, "ENERGY"
	denv.FireEvent("UNIT_DISPLAYPOWER", "player")
	denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(dns.SlabJewels.state.count == 5 and not dlock.gem:IsShown(), "Cat Form's jewels take the seat from the gem on the same target")
	denv._powerType, denv._powerToken = 0, "MANA"
	denv.FireEvent("UNIT_DISPLAYPOWER", "player")
	denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(dns.SlabJewels.state.count == 0 and dlock.gem:IsShown(), "back in caster form the gem returns")
	Clean(denv, DK, "druid seat")
end

-- In combat the lock is not built; it is built once the restriction ends. Target changes and hits raise nothing.
do
	local env, K, ns = New("MAGE", { 133 }, { lockOff = true })
	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestLock", true)
	assert(ns.SlabTarget.lock == nil, "switched on in combat with auras secret, the lock waits")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(Piece(ns, "crestLock") and ns.SlabTarget.lock.gem:GetNumPoints() == 1, "combat over: built and seated")
	Clean(env, K, "combat build")
	local wenv, WK, wns = New("WARRIOR", { SHOUT, EXECUTE })
	wenv._aurasSecret = true
	wenv.SetCombat(true)
	wenv._health = 0.5
	wenv.SetTarget(true)
	Health(wenv, 0.1)
	assert(Alpha(wenv, Piece(wns, "crestKill")) == 1 and Claws(Piece(wns, "crestLock")), "both effects play in combat")
	wenv.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Clean(wenv, WK, "combat")
end

-- Frames: the kill window is a red line as wide as the tracker row above it; the target lock has no Frames form.
do
	local env, K, ns = New("WARRIOR", { SHOUT, EXECUTE }, { frames = true })
	local line = Piece(ns, "crestKill", "row")
	assert(line and not line.ripple and not Piece(ns, "crestLock", "row"), "under Frames: a kill line and no target lock")
	local row = ns.SlabTrackers.state.forms.row
	local left, right = math.huge, -math.huge
	for _, p in pairs(row.pieces) do
		if p:IsVisible() and p ~= line then
			left, right = math.min(left, p:GetLeft()), math.max(right, p:GetRight())
		end
	end
	assert(math.abs(line.line:GetLeft() - left) < 1 and math.abs(line.line:GetRight() - right) < 1, "the line spans the row's medals and no further")
	assert(line.line:GetTop() < row.frame:GetBottom(), "and sits under the row")
	env._health = 0.1
	env.SetTarget(true)
	assert(Alpha(env, line) == 1, "and burns in range")
	Clean(env, K, "frames")
end

print("test-actionbars-crest-target: ok")
