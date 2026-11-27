-- test-actionbars-crest-rail.lua: every class's five-seat crest rail (KstyleUI_ActionBars/SlabRail.lua), as the crest plan (KSTY-60, KSTY-97) asks: the tree the game names stands its own known abilities, its rotation cooldowns and then the class's other long cooldowns in any free seat, the trinket fifth, the long cooldowns beyond the seats as round medals on a second rail that rise to the crown like a seat, and the seats a player picks in the settings list; seven states driven by the game's own events at Full, Calm and Off (ready, pressed, active, about to end, ended, cooling, ready again), each ready seat burning with its animated aura; the newest running buff owns the crown; a motion change stops what is in flight; auras turning secret mid-fight raise no error; the rail holds its abilities back from the cooldown row and the trinket seat; the captain's choice moves it to its own flat row while the centred cast bars show; nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local Slots, New, Seated, Updating, Clean = R.Slots, R.New, R.Seated, R.Updating, R.Clean
local Pose = dofile("Tools/regression/anim_pose.lua")

local BM = { 13165, 883, 75, 19574, 3045, 19577, 14305 }
local MM = { 13165, 883, 75, 3045, 14305, 1310786, 20904 }
local SV = { 13165, 883, 75, 3045, 19263, 14305, 1317257 }
local ALL = { 13165, 883, 75, 19574, 3045, 19577, 14305, 1310786, 20904, 19263, 1317257 }

local function Rail(ns)
	return Seated(ns, "crestRail")
end

local function Keys(rail)
	local keys = {}
	for i, seat in ipairs(rail.order) do keys[i] = seat.key end
	return table.concat(keys, ",")
end

local function Spares(rail)
	local keys = {}
	for i, seat in ipairs(rail.spare) do keys[i] = seat.key end
	return table.concat(keys, ",")
end

local function Motion(env, K, level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
end

local function Awake(env)
	env.SetTarget(true)
	env.RunTimers()
end

local function Cooling(env, id, on)
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = on and spell == id, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
end

-- The engine ends the sweep's own timer, then the cooldown event arrives with the spell no longer cooling.
local function Cooled(env, seat)
	env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	seat.sweep:GetScript("OnCooldownDone")(seat.sweep)
	local cue = seat.relight:IsPlaying()
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	return cue
end

local function Under(region, frame)
	while region do
		if region == frame then return true end
		region = region:GetParent()
	end
	return false
end

local function Cast(env, id)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. id, id)
end

local function Burning(seat)
	return seat.aura.moving:GetAlpha() == 1 and seat.aura.still:GetAlpha() == 0 and seat.aura.loop:IsPlaying()
end

local function Still(seat)
	return seat.aura.still:GetAlpha() == 1 and seat.aura.moving:GetAlpha() == 0 and not seat.aura.loop:IsPlaying()
end

local function Hunter(row)
	local own = {}
	for _, button in ipairs(row.sigils) do
		local sigil = button.family.sigil
		if button.at and (sigil == "Volley" or sigil == "Deflect" or sigil == "Paw") then own[#own + 1] = sigil end
	end
	return table.concat(own, ",")
end

local function Auras(env, list)
	local auras = {}
	for i, each in ipairs(list) do auras[i] = { id = each[1], auraInstanceID = i, start = env._now, duration = each[2] } end
	Slots.Set(env, "player", #auras > 0 and auras or nil)
end

for _, case in ipairs({ { 1, "wrath,rapid,intimidate,trap" }, { 2, "rapid,trap,sniper,aimed" }, { 3, "rapid,deter,trap,strider" } }) do
	local env, K, ns = New("HUNTER", { known = ALL, tree = case[1], trinket = true })
	local rail = assert(Rail(ns), "a hunter who knows a rail ability sees the rail")
	assert(Keys(rail) == case[2] .. ",trinket", "the tree the game names stands its own four abilities, then the trinket: " .. Keys(rail))
	Clean(env, K)
end

for _, case in ipairs({ { BM, "wrath,rapid,intimidate,trap" }, { MM, "rapid,trap,sniper,aimed" }, { SV, "rapid,deter,trap,strider" } }) do
	local env, K, ns = New("HUNTER", { known = case[1] })
	assert(Keys(Rail(ns)) == case[2], "with no tree from the game, the tree's signature spells choose it: " .. Keys(Rail(ns)))
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = ALL })
	local most = 3
	env.C_SpecializationInfo = { GetSpecializationInfo = function(i) return i, "tree", "", 0, "DAMAGER", nil, i == most and 31 or 5 end }
	env.FireEvent("PLAYER_TALENT_UPDATE")
	assert(Keys(Rail(ns)) == "rapid,deter,trap,strider", "with no primary tree, the tree with the most points spent is chosen: " .. Keys(Rail(ns)))
	most = 2
	env.FireEvent("PLAYER_TALENT_UPDATE")
	assert(Keys(Rail(ns)) == "rapid,trap,sniper,aimed", "respending the points re-seats the rail with the same spells known: " .. Keys(Rail(ns)))
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = ALL })
	local tree = 1
	env.C_SpecializationInfo = { GetSpecialization = function() return tree end }
	env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
	Awake(env)
	local rail = Rail(ns)
	local wrath = rail.made.wrath
	assert(Keys(rail) == "wrath,rapid,intimidate,trap" and Burning(wrath), "Beast Mastery seats Bestial Wrath, burning")
	Cast(env, 19574)
	Slots.Set(env, "pet", { { id = 19574, auraInstanceID = 9, start = env._now, duration = 18 } })
	wrath.rise:Stop()
	assert(rail.owner == wrath, "Bestial Wrath owns the crown before the switch")
	local folded = false
	wrath.home:SetScript("OnPlay", function() folded = true end)
	tree = 2
	env.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
	assert(Keys(rail) == "rapid,trap,sniper,aimed", "switching trees re-seats the rail with the same spells known: " .. Keys(rail))
	assert(not wrath:IsShown() and not wrath.aura.loop:IsPlaying() and not wrath.breath:IsPlaying(), "the dropped seat stops its aura and breathing")
	assert(not folded and rail.owner ~= wrath, "the dropped seat gives up the crown without starting a fold home")
	wrath.ready = false
	wrath.sweep:GetScript("OnCooldownDone")(wrath.sweep)
	assert(not wrath.relight:IsPlaying() and not wrath.flare[1]:IsPlaying() and not wrath.glinting:IsPlaying(),
		"the dropped seat's own sweep ending claims no flare on the shown rail")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 75, 19574, 3045, 14305 } })
	assert(Keys(Rail(ns)) == "wrath,rapid,trap", "an unlearned ability and an empty trinket slot leave no seat: " .. Keys(Rail(ns)))
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	local rail = Rail(ns)
	local at = {}
	for i, seat in ipairs(rail.order) do
		local _, anchor, _, x, y = seat:GetPoint(1)
		assert(anchor == rail, "each seat stands on the rail")
		at[i] = { x, y }
	end
	assert(at[3][1] == 0 and at[1][1] == -at[5][1] and at[2][1] == -at[4][1] and at[1][2] == at[5][2], "five seats stand evenly about the crest's centre line")
	assert(at[3][2] > at[2][2] and at[2][2] > at[1][2], "the seats bow down from the middle")
	assert(at[1][2] - 14 > 75, "the lowest seat clears the crest's ring, radius 75")
	local _, _, _, cx, cy = rail.crown:GetPoint(1)
	assert(cx == 0 and cy < at[3][2] - 14 and cy > 75, "the crown sits between the ring and the middle seat")
	assert(Updating(rail) == 0, "nothing on the rail runs OnUpdate")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid = rail.made.rapid
	assert(rapid.lit:GetAlpha() == 1 and rapid.breath:IsPlaying() and Burning(rapid), "ready at Full: Rapid Fire's aura burns and the seat breathes")
	Cast(env, 3045)
	assert(rapid.dip:IsPlaying() and rapid.bursting:IsPlaying() and rapid.flash:IsPlaying(), "pressed at Full: the seat dips, bursts and flashes its ring")
	assert(rapid.rise:IsPlaying() and rapid.gate:GetAlpha() == 1 and rapid.burn:GetAlpha() == 1, "pressed at Full: the medal rises to the crown, its aura burning")
	Auras(env, { { 3045, 15 } })
	assert(rapid.crowned:IsShown() and rapid.crowned._cooldown == rapid.crowned.timer, "active: the crown's slot shows the aura and its ring drains from the aura's own duration")
	assert(rapid.crowned.aura.loop:IsPlaying() and rapid.hold:GetAlpha() == 1, "active: the crowned aura burns and the seat's own slot drains its ring")
	assert(R.AB.W.LastCall(rapid.crowned.timer, "SetEdgeTexture") and rapid.crowned.timer:GetHideCountdownNumbers() == false, "active: the crown's ring carries a bead and a countdown")
	Cooling(env, 3045, true)
	assert(rapid.lit:GetAlpha() == 0 and not rapid.breath:IsPlaying() and not rapid.aura.loop:IsPlaying(), "cooling: the seat goes steel, its aura out")
	assert(R.AB.W.LastCall(rapid.sweep, "SetCooldownFromDurationObject") and R.AB.W.LastCall(rapid.refill, "SetCooldownFromDurationObject") and rapid.refill:GetReverse(),
		"cooling: the dark sweep and the refilling steel ring take the engine's duration object")
	env._now = env._now + 12
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return unit == "player" and id == 3045 and env._ending or nil end
	env._ending = { auraInstanceID = 1, expirationTime = env._now + 3, duration = 15, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	local flickers = 0
	for _, e in ipairs(ns.SlabRings.state.watched) do
		flickers = flickers + ((e.piece == rapid.lift or e.piece == rapid) and e.flicker and e.flicker:IsPlaying() and 1 or 0)
	end
	assert(flickers > 0, "about to end: the last fifth flickers from the aura's own event")
	assert(rapid.cold:GetAlpha() == 1, "cooling: a steel sigil stays readable above the sweep")
	env._ending = nil
	Auras(env, {})
	assert(rapid.home:IsPlaying() and rapid.burn:GetAlpha() == 0, "ended at Full: the crowned medal cools to steel and folds home")
	env._now = env._now + 120
	assert(Cooled(env, rapid), "ready again: the sweep's own end relights the seat")
	assert(rapid.lit:GetAlpha() == 1 and rapid.relight:IsPlaying() and rapid.flare[1]:IsPlaying() and rapid.flare[2]:IsPlaying() and rapid.glinting:IsPlaying() and Burning(rapid),
		"ready again at Full: the cooldown event that follows keeps the relight, flare and glint, and the aura burns again")
	assert(rapid.cold:GetAlpha() == 0, "ready again: the steel mark goes")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	Motion(env, K, "calm")
	local rail = Rail(ns)
	local rapid = rail.made.rapid
	assert(rapid.lit:GetAlpha() == 1 and Still(rapid) and not rapid.breath:IsPlaying(), "ready at Calm: the aura stands still and the seat does not breathe")
	Cast(env, 3045)
	assert(not rapid.dip:IsPlaying() and not rapid.flash:IsPlaying() and not rapid.rise:IsPlaying(), "pressed at Calm: no dip, flash or rise")
	Auras(env, { { 3045, 15 } })
	assert(rapid.gate:GetAlpha() == 1 and rapid.crowned:IsShown() and Still(rapid.crowned), "active at Calm: the crown lights in place with a still aura")
	Auras(env, {})
	assert(not rapid.home:IsPlaying(), "ended at Calm: no fold")
	Cooling(env, 3045, true)
	Cooled(env, rapid)
	assert(rapid.relight:IsPlaying() and not rapid.flare[1]:IsPlaying() and not rapid.glinting:IsPlaying(), "ready again at Calm: a relight in place with no flare")
	Motion(env, K, "off")
	Cooling(env, 3045, true)
	Cooled(env, rapid)
	assert(rapid.lit:GetAlpha() == 1 and not rapid.relight:IsPlaying() and Still(rapid), "ready again at Off: lit with no motion")
	Auras(env, { { 3045, 15 } })
	assert(rapid.gate:GetAlpha() == 0 and rapid.hold:GetAlpha() == 0, "active at Off: no crown and no draining seat")
	local embers = 0
	for _, gate in ipairs(ns.SlabRings.state.embers) do
		if Under(gate, rapid) then
			embers = embers + 1
			assert(Under(gate, rapid.hold) or Under(gate, rapid.gate), "active at Off: every ember on the seat sits under its hidden drain")
		end
	end
	assert(embers > 0, "the seat's embers are measured")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, hiding = true })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	Cast(env, 3045)
	Auras(env, { { 3045, 15 } })
	Cast(env, 19574)
	assert(wrath.gate:GetAlpha() == 1 and rapid.gate:GetAlpha() == 0, "the newest press takes the crown")
	Slots.Set(env, "pet", { { id = 19574, auraInstanceID = 9, start = env._now, duration = 18 } })
	assert(wrath.gate:GetAlpha() == 1 and rapid.gate:GetAlpha() == 0 and rail.owner == wrath, "the newest running buff owns the crown")
	Slots.Set(env, "pet", nil)
	assert(rapid.gate:GetAlpha() == 1 and wrath.gate:GetAlpha() == 0 and rail.owner == rapid, "when it ends the crown goes back to the buff still running")
	assert(wrath.home:IsPlaying(), "and the ended medal folds home")
	Cast(env, 3045)
	assert(rapid.rise:IsPlaying(), "a press in flight")
	Motion(env, K, "calm")
	assert(not rapid.rise:IsPlaying() and not rapid.aura.loop:IsPlaying() and not rapid.crowned.aura.loop:IsPlaying(), "a motion change stops the rise and the burning auras at once")
	Motion(env, K, "full")
	Cast(env, 3045)
	assert(rapid.crowned.aura.loop:IsPlaying(), "the crown burns again at Full")
	K.Options.Write("ActionBars", "crestRail", false)
	assert(not rail:IsShown(), "switching the rail off hides it")
	assert(not rapid.breath:IsPlaying() and not rapid.aura.loop:IsPlaying() and not rapid.crowned.aura.loop:IsPlaying() and not rapid.rise:IsPlaying(),
		"hiding the rail stops the seat's and the crown's auras and what is in flight")
	local placed = rail.low
	K.Layout.Register(env.CreateFrame("Frame"), "unitframes.castbar.player", { anchor = "CENTER", x = 0, y = 0 })
	K.Layout.SetLive("unitframes.castbar.player", false)
	K.Layout.SetLive("unitframes.castbar.player", true)
	assert(placed == false and rail.low == placed, "the centred cast bar showing does not re-place the hidden rail")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = spell == 3045 or spell == 19574, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = spell == 19574, isOnGCD = false } end
	rapid.sweep:GetScript("OnCooldownDone")(rapid.sweep)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(rapid.flare[2]:IsPlaying() and rapid.glinting:IsPlaying() and wrath.lit:GetAlpha() == 0, "a seat ready again plays its flare while the other still cools")
	Cooled(env, wrath)
	assert(wrath.flare[1]:IsPlaying() and not rapid.flare[1]:IsPlaying() and not rapid.flare[2]:IsPlaying() and not rapid.glinting:IsPlaying(),
		"a newer ready flare stops the whole older flare: its glow, gilt ring and glint")
	Cast(env, 3045)
	Cast(env, 19574)
	assert(wrath.bursting:IsPlaying() and wrath.flash:IsPlaying() and not rapid.bursting:IsPlaying() and not rapid.flash:IsPlaying(),
		"a newer press stops the older burst and its ring flash together")
	Clean(env, K)
end

-- KSTY-103: Forever documents isOnGCD as trustworthy only while answering SPELL_UPDATE_COOLDOWN
-- (SpellSharedDocumentation.lua, docs/FOREVER_API_AUDIT.md), so a rebuild must never light a cooling seat from it.
-- Each spell's cooldown is { start, duration }, read by both cooldown calls, and its flag is what the game would answer at that
-- moment; reads.rail counts the flag reads SlabRail.lua makes, and reads.secret hides the start and duration.
local function Readings(env)
	local cds, flag, reads = {}, {}, { rail = 0, secret = false }
	env._spellCd = cds
	env.C_Spell.GetSpellCooldown = function(spell)
		local c = cds[spell]
		local start, length = c and c[1] or 0, c and c[2] or 0
		if reads.secret then start, length = env.Secret(start), env.Secret(length) end
		return setmetatable({ isActive = c ~= nil, startTime = start, duration = length, isEnabled = true }, { __index = function(_, key)
			if key ~= "isOnGCD" then return nil end
			if debug.getinfo(2, "S").source == "@KstyleUI_ActionBars/SlabRail.lua" then reads.rail = reads.rail + 1 end
			return flag[spell] or false
		end })
	end
	return cds, flag, reads
end

-- The start and finish of the newest duration object the seat's sweep took after its first `since` ones.
local function Swept(seat, since)
	local calls = R.AB.W.Calls(seat.sweep, "SetCooldownFromDurationObject")
	local d = #calls > since and calls[#calls][1]
	return d and d.start, d and d.finish
end

local function Sweeps(seat)
	return #R.AB.W.Calls(seat.sweep, "SetCooldownFromDurationObject")
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid, intimidate = rail.made.rapid, rail.made.intimidate
	local cds, flag, reads = Readings(env)
	local now = env._now
	cds[3045], cds[19577], flag[19577] = { now, 300 }, { now, 1.5 }, true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(reads.rail > 0 and rapid.lit:GetAlpha() == 0 and intimidate.lit:GetAlpha() == 1,
		"the cooldown event reads the flag: Rapid Fire's 5 minutes cool and Intimidation's 1.5 s is the global cooldown")
	flag[3045], flag[19577], reads.rail = true, false, 0
	local swept = Sweeps(rapid)
	env.FireEvent("PET_BAR_UPDATE")
	assert(reads.rail == 0, "a rebuild never reads the flag")
	local start, finish = Swept(rapid, swept)
	assert(start == now and finish == now + 300, "the rebuild feeds Rapid Fire's sweep its own 5-minute cooldown")
	assert(rapid.lit:GetAlpha() == 0 and rapid.cold:GetAlpha() == 1 and not Burning(rapid), "a rebuild while the flag reads a stale true keeps Rapid Fire's cooling seat steel")
	assert(intimidate.lit:GetAlpha() == 1 and Burning(intimidate) and not intimidate.relight:IsPlaying() and not intimidate.flare[1]:IsPlaying(),
		"a rebuild in the same global cooldown keeps Intimidation gold and burning, with no flare, whatever the flag reads then")
	Clean(env, K)
end

-- While the rail is off it misses a cooldown event. When it returns, a cooldown whose start or duration differs from the kept
-- global cooldown is one the rail never classified: a later global cooldown, or Rapid Fire's own cooldown from that same start.
for _, case in ipairs({ { "a later start", 2, 1.5, true }, { "a longer duration", 0, 300, false } }) do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid = rail.made.rapid
	local cds, flag = Readings(env)
	local now = env._now
	cds[3045], flag[3045] = { now, 1.5 }, true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(rapid.lit:GetAlpha() == 1, "Rapid Fire in the global cooldown stays ready")
	K.Options.Write("ActionBars", "crestRail", false)
	cds[3045], flag[3045] = { now + case[2], case[3] }, case[4]
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	flag[3045] = true
	K.Options.Write("ActionBars", "crestRail", true)
	assert(rail.made.rapid == rapid and rapid:IsShown(), "the rail comes back with the same Rapid Fire seat")
	assert(rapid.lit:GetAlpha() == 0 and rapid.cold:GetAlpha() == 1,
		"a cooldown with " .. case[1] .. " than the kept global cooldown, missed while the rail was off, shows steel when it returns, though the flag reads true")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local intimidate = rail.made.intimidate
	local cds, flag = Readings(env)
	K.Options.Write("ActionBars", "crestRail", false)
	cds[19577], flag[19577] = { env._now, 1.5 }, true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	K.Options.Write("ActionBars", "crestRail", true)
	assert(intimidate.lit:GetAlpha() == 0, "a rebuild in a global cooldown no event read for the rail cannot tell it from Intimidation's own, so the seat shows steel")
	flag[19577] = env.Secret(true)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(intimidate.lit:GetAlpha() == 0, "a cooldown event whose flag is secret keeps the seat as it stood")
	flag[19577] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(intimidate.lit:GetAlpha() == 1 and Burning(intimidate), "the next readable cooldown event reads only the global cooldown and lights the seat")
	assert(not intimidate.relight:IsPlaying() and not intimidate.flare[1]:IsPlaying() and not intimidate.flare[2]:IsPlaying() and not intimidate.glinting:IsPlaying(),
		"with no relight, flare or glint, as no cooldown of its own ended")
	Clean(env, K)
end

-- A cooldown the event read as Rapid Fire's own stays steel through a rebuild while its start and duration are secret, and keeps
-- its ready cue when the cooldown event that finds it ready, readable again, arrives before the sweep's own end.
do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rapid = Rail(ns).made.rapid
	local cds, flag, reads = Readings(env)
	local now = env._now
	cds[3045] = { now, 300 }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(rapid.lit:GetAlpha() == 0, "the cooldown event reads Rapid Fire's own cooldown")
	reads.secret, flag[3045] = true, true
	local swept = Sweeps(rapid)
	env.FireEvent("PET_BAR_UPDATE")
	local start, finish = Swept(rapid, swept)
	assert(start == now and finish == now + 300, "the rebuild still feeds the sweep the cooldown's duration object")
	assert(rapid.lit:GetAlpha() == 0 and rapid.cold:GetAlpha() == 1 and not Burning(rapid), "a rebuild while the cooldown's start and duration are secret keeps the seat steel")
	env._now = now + 300
	cds[3045], reads.secret = nil, false
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(rapid.lit:GetAlpha() == 1 and rapid.relight:IsPlaying() and rapid.flare[1]:IsPlaying() and rapid.flare[2]:IsPlaying() and rapid.glinting:IsPlaying() and Burning(rapid),
		"the cooldown event that finds it ready before the sweep ends relights it with its flare and glint")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	local readable = { [3045] = { start = env._now - 10, duration = 15 }, [19574] = { start = env._now - 2, duration = 18 } }
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(_, id)
		local a = readable[id]
		return a and { auraInstanceID = id, expirationTime = a.start + a.duration, duration = a.duration, sourceUnit = "player" } or nil
	end
	Slots.Set(env, "pet", { { id = 19574, auraInstanceID = 9, start = readable[19574].start, duration = 18 } })
	Auras(env, { { 3045, 15 } })
	assert(rail.owner == wrath and wrath.gate:GetAlpha() == 1 and rapid.gate:GetAlpha() == 0,
		"two buffs already running when the rail binds: the one the auras show began last owns the crown, whatever order the slots report")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	Awake(env)
	local trinket = Rail(ns).made.trinket
	assert(trinket.lit:GetAlpha() == 1, "the trinket seat starts ready")
	env.GetInventoryItemCooldown = function() return env._now, 1.5, 1, true end
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(trinket.lit:GetAlpha() == 1 and trinket.cold:GetAlpha() == 0, "the global cooldown leaves the trinket ready")
	Cast(env, 9002)
	assert(trinket.bursting:IsPlaying() and trinket.dip:IsPlaying(), "the trinket's own use plays its press cue")
	env.GetInventoryItemCooldown = function() return env._now, 120, 1, false end
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(trinket.lit:GetAlpha() == 0 and trinket.cold:GetAlpha() == 1 and R.AB.W.LastCall(trinket.sweep, "SetCooldown"), "its own cooldown turns the seat steel and sweeps")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, hiding = true })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	Cooling(env, 3045, true)
	K.Options.Write("ActionBars", "crestRail", false)
	assert(not rail:IsVisible(), "switching the rail off hides it")
	assert(not Cooled(env, rapid) and not rapid.flare[1]:IsPlaying() and not rapid.glinting:IsPlaying() and not rapid.breath:IsPlaying() and not rapid.aura.loop:IsPlaying(),
		"a cooldown ending on the hidden rail relights the seat with no flare, breath or burning aura")
	assert(rapid.lit:GetAlpha() == 1, "and the seat is ready when the rail shows again")
	wrath.signal:Play()
	wrath.signal:Stop()
	assert(not wrath.crowned.aura.loop:IsPlaying() and not wrath.home:IsPlaying(), "a crown signal arriving after the rail hides neither burns the crown nor folds home")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	local readable = { [3045] = { start = env._now - 2, duration = 15 }, [19574] = { start = env._now - 10, duration = 18 } }
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(_, id)
		assert(not env._aurasSecret, "the rail reads no aura while auras are secret")
		local a = readable[id]
		return a and { auraInstanceID = id, expirationTime = a.start + a.duration, duration = a.duration, sourceUnit = "player" } or nil
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Auras(env, { { 3045, 15 } })
	Slots.Set(env, "pet", { { id = 19574, auraInstanceID = 9, start = readable[19574].start, duration = 18 } })
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	assert(rail.owner == rapid and rapid.gate:GetAlpha() == 1 and wrath.gate:GetAlpha() == 0,
		"two buffs that opened unseen while auras were secret: once they read, the one that began last owns the crown")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	local rail = Rail(ns)
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestRail", false)
	assert(rail:IsShown() and Hunter(Seated(ns, "crestCooldowns")) == "" and not Seated(ns, "crestTrinkets"),
		"switched off in combat, the rail stays until the other trackers can take its cues back")
	assert(Seated(ns, "crestAutoShot"), "the Auto Shot ring shows before it is switched off")
	K.Options.Write("ActionBars", "crestAutoShot", false)
	assert(not Seated(ns, "crestAutoShot") and rail:IsShown(), "while the rail waits, every other tracker still updates")
	K.Options.Write("ActionBars", "crestAutoShot", true)
	env.SetCombat(false)
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and Hunter(Seated(ns, "crestCooldowns")) == "Volley,Paw", "out of combat the rail hands every cue back at once")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestRail", true)
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and Hunter(Seated(ns, "crestCooldowns")) == "Volley,Paw",
		"switched on in combat, the other trackers keep their cues while the rail cannot be placed")
	env.SetCombat(false)
	assert(Rail(ns) and not Seated(ns, "crestTrinkets") and Hunter(Seated(ns, "crestCooldowns")) == "", "out of combat the rail takes them over at once")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	assert(Rail(ns) and not Seated(ns, "crestTrinkets"), "the rail stands with the trinket")
	local claim = ns.SlabSeats.Claim
	ns.SlabSeats.Claim = function(order, specs, crest)
		local kept = {}
		for _, key in ipairs(order) do
			if specs[key].key ~= "crestRail" then kept[#kept + 1] = key end
		end
		return claim(kept, specs, crest)
	end
	ns.SlabTrackers.Update()
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and Hunter(Seated(ns, "crestCooldowns")) == "Volley,Paw",
		"a rail the update cannot seat leaves the cooldown row's sigils and the crest trinket in place")
	ns.SlabSeats.Claim = claim
	Clean(env, K)
end

do
	local function Refuse(_, _, ns)
		for _, row in ipairs(ns.SlabTrackers.CLASSES.HUNTER) do
			if row.key == "crestRail" then row.build = function() error("the rail's forge is refused") end end
		end
	end
	local env, K, ns = New("HUNTER", { known = BM, trinket = true, before = Refuse })
	local gust = Seated(ns, "crestGust")
	local rapid = false
	for _, id in ipairs(gust and gust.spec.spells or {}) do rapid = rapid or id == 3045 end
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and Hunter(Seated(ns, "crestCooldowns")) == "Volley,Paw" and rapid,
		"a rail whose build fails from the start leaves the cooldown rim's sigils, Rapid Fire's gust and the crest trinket in place")
	Clean(env, K)
end

-- The crest's own trinket sockets that show, by slot.
local function Sockets(ns)
	local form, shown = ns.SlabTrackers.state.form, {}
	for i, row in ipairs(ns.SlabTrackers.CLASSES[ns.class]) do
		local p = row.key == "crestTrinkets" and form and form.pieces[i .. ":1"]
		if p and p:IsShown() then shown[#shown + 1] = row.slot end
	end
	return table.concat(shown, ",")
end

local function Railed(rail)
	for _, at in ipairs(rail.seated) do
		if at.key == "trinket" then return at.slot end
	end
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	local worn = { [13] = 5002, [14] = 5002 }
	env.GetInventoryItemID = function(_, slot) return worn[slot] end
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 14, true)
	assert(Railed(Rail(ns)) == 13 and Sockets(ns) == "14", "with two trinkets the rail takes the first and the crest keeps the second: " .. Sockets(ns))
	worn[13] = nil
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 13, true)
	assert(Railed(Rail(ns)) == 14 and Sockets(ns) == "", "the rail moves to the trinket left, and the crest shows no second socket for it: " .. Sockets(ns))
	worn[13] = 5002
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 13, true)
	assert(Railed(Rail(ns)) == 13 and Sockets(ns) == "14", "the rail moves back to slot 13 and the crest takes slot 14 back: " .. Sockets(ns))
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true, secret = true })
	assert(not ns.SlabRail.Holds({ 3045 }) and not ns.SlabRail.Holds(nil, 13), "loading while restricted, before the rail can be built, takes no ability or trinket from the other trackers")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local rail = Rail(ns)
	assert(rail and Keys(rail) == "wrath,rapid,intimidate,trap,trinket" and ns.SlabRail.Holds({ 3045 }) and not Seated(ns, "crestTrinkets"),
		"once the rail is placed it takes them over")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	env.SetCombat(true)
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local rapid = Rail(ns).made.rapid
	Cast(env, 3045)
	Auras(env, { { 3045, 15 } })
	Motion(env, K, "calm")
	Auras(env, {})
	Motion(env, K, "full")
	assert(rapid.burn:GetAlpha() == 0, "under hidden values the crown still empties when the buff ends")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	assert(not Seated(ns, "crestTrinkets") and Rail(ns).made.trinket:IsShown(), "the trinket stands on the rail, not beside the crest")
	local held = Seated(ns, "crestCooldowns")
	assert(held and Hunter(held) == "", "the rail seats Rapid Fire and Bestial Wrath, so the cooldown row shows neither sigil: " .. Hunter(held))
	K.Options.Write("ActionBars", "crestRail", false)
	local row = Seated(ns, "crestCooldowns")
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and row and Hunter(row) == "Volley,Paw", "switched off, the cooldown row and the crest trinket come back")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 75, 19574, 3045, 19263, 14305, 1317257 }, tree = 3 })
	local rail, row = Rail(ns), Seated(ns, "crestCooldowns")
	assert(rail and Keys(rail) == "rapid,deter,trap,strider" and Spares(rail) == "wrath" and not (row and Hunter(row) ~= ""),
		"a survival rail seats Rapid Fire and Deterrence, fills its free seats with a fire trap and Strider Kick and stands Bestial Wrath on the second rail, so no cooldown row is left")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	local holder = env.CreateFrame("Frame")
	K.Layout.Register(holder, "unitframes.castbar.player", { anchor = "CENTER", x = 0, y = 0 })
	local rail = Rail(ns)
	local function Row()
		local ys = {}
		for i, seat in ipairs(rail.order) do ys[i] = select(5, seat:GetPoint(1)) end
		return ys
	end
	K.Layout.SetLive("unitframes.castbar.player", false)
	local ys = Row()
	assert(ys[3] > ys[1] and ys[1] ~= 227, "with the cast bar hidden the seats bow on the arc")
	K.Layout.SetLive("unitframes.castbar.player", true)
	ys = Row()
	assert(ys[1] == 227 and ys[3] == 227 and ys[5] == 227, "with the centred cast bar showing the seats stand in a flat row between the cooldown rows")
	local _, _, _, cx, cy = rail.crown:GetPoint(1)
	assert(cy == 227 and cx < select(4, rail.order[1]:GetPoint(1)), "and the crown leads the row")
	K.Layout.SetLive("unitframes.castbar.player", false)
	ys = Row()
	assert(ys[3] > ys[1] and ys[1] ~= 227, "with the cast bar hidden the seats bow on the arc again")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, frames = true })
	assert(not Rail(ns), "Frames builds no rail")
	Clean(env, K)
end

-- The mage's and warlock's rails, per tree from the Forever guides read for the crest plan (KSTY-97): the tree's long cooldowns,
-- its rotation cooldowns in any free seat, then the class's other long cooldowns; a long cooldown beyond the four seats stands as a
-- round medal on the second rail.
local MAGE = { 12042, 12043, 12051, 11129, 11958, 12472, 2136, 11113, 120, 11426 }
local WARLOCK = { 603, 18288, 6789, 18708, 6353, 1122, 17877 }
for _, case in ipairs({
	{ "MAGE", MAGE, 1, "power,presence,evocation,blast", "combustion,block,snap" },
	{ "MAGE", MAGE, 2, "combustion,block,evocation,cone", "power,presence,snap" },
	{ "MAGE", MAGE, 3, "block,evocation,snap,barrier", "power,presence,combustion" },
	{ "WARLOCK", WARLOCK, 1, "coil,inferno,amplify,domination", "soulfire" },
	{ "WARLOCK", WARLOCK, 2, "coil,inferno,domination,soulfire", "amplify" },
	{ "WARLOCK", WARLOCK, 3, "coil,inferno,amplify,domination", "soulfire" },
	{ "WARLOCK", { 603, 18288, 6789, 6353, 1122, 17877 }, 1, "coil,inferno,amplify,soulfire", "" },
	{ "WARLOCK", { 603, 18288, 6789, 18708, 6353, 1122, 17877, 20757, 18540 }, 2, "coil,inferno,domination,soulfire", "amplify,soulstone,ritual" },
	{ "WARLOCK", { 603, 18288, 6789, 1122, 17877, 20757, 18540 }, 1, "coil,inferno,amplify", "soulstone,ritual" },
	{ "WARLOCK", { 603, 18288, 6789, 18708, 6353, 1122, 17877, 20757, 18540 }, 3, "coil,inferno,amplify,domination", "soulfire,soulstone,ritual" },
}) do
	local env, K, ns = New(case[1], { known = case[2], tree = case[3], trinket = true })
	local rail = assert(Rail(ns), case[1] .. ": a caster who knows a rail ability sees the rail")
	local at = case[1] .. " tree " .. case[3]
	assert(Keys(rail) == case[4] .. ",trinket", at .. ": the tree's seats, then the trinket: " .. Keys(rail))
	assert(Spares(rail) == case[5], at .. ": the other long cooldowns stand on the second rail: " .. Spares(rail))
	for _, seat in ipairs(rail.spare) do
		assert(seat.small and seat.size < rail.order[1].size, at .. ": a second-rail medal is smaller than a seat")
	end
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 12042, 11958, 116 }, tree = 1, trinket = true })
	local rail = Rail(ns)
	assert(Keys(rail) == "power,block,trinket" and Spares(rail) == "", "a mage with only Arcane Power and Ice Block seats both, Ice Block in the free seat")
	local _, _, _, first = rail.order[1]:GetPoint(1)
	local _, _, _, trinket = rail.order[3]:GetPoint(1)
	assert(trinket - first == 124, "the trinket keeps the fifth place, four seats (31 units each) right of the first: " .. (trinket - first))
	local row = Seated(ns, "crestCooldowns")
	for _, b in ipairs(row and row.sigils or {}) do
		assert(not (b.at and (b.family.sigil == "Arcane" or b.family.sigil == "Crystal")), "the railed cooldowns leave the cooldown row")
	end
	Clean(env, K)
end

-- Seven states on a main seat of the mage's and the warlock's rails, at Full, Calm and Off, on seats that burn the aura their
-- sigil publishes: ready, pressed, active, about to end, ended, cooling and ready again.
local function Ending(env, ns, seat, unit, id)
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(u, spell) return u == unit and spell == id and env._ending or nil end
	env._ending = { auraInstanceID = 1, expirationTime = env._now + 3, duration = 15, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", unit)
	local flickers = 0
	for _, e in ipairs(ns.SlabRings.state.watched) do
		flickers = flickers + ((e.piece == seat.lift or e.piece == seat) and e.flicker and e.flicker:IsPlaying() and 1 or 0)
	end
	env._ending = nil
	return flickers
end

for _, case in ipairs({ { "MAGE", { 12042, 12043, 11958 }, 1, "power", 12042 }, { "WARLOCK", { 603, 18288, 6789, 1122 }, 1, "amplify", 18288 } }) do
	for _, level in ipairs({ "full", "calm", "off" }) do
		local env, K, ns = New(case[1], { known = case[2], tree = case[3] })
		Awake(env)
		if level ~= "full" then Motion(env, K, level) end
		local seat, id, full, off = Rail(ns).made[case[4]], case[5], level == "full", level == "off"
		local at = case[1] .. " " .. case[4] .. " at " .. level
		assert(seat.aura.loop and seat.lit:GetAlpha() == 1 and seat.aura.loop:IsPlaying() == full and seat.aura.still:GetAlpha() == (full and 0 or 1)
			and seat.breath:IsPlaying() == full, at .. ": ready, lit, burning its sigil's aura and breathing only at Full, its still frame at Calm and Off")
		Cast(env, id)
		assert(seat.dip:IsPlaying() == full and seat.rise:IsPlaying() == full and (not full or seat.bursting:IsPlaying() and seat.gate:GetAlpha() == 1),
			at .. ": pressed, a dip, burst and rise to the crown only at Full")
		Auras(env, { { id, 15 } })
		assert(seat.crowned:IsShown() and seat.gate:GetAlpha() == (off and 0 or 1), at .. ": active, the crown shows the buff's own slot, hidden at Off")
		Cooling(env, id, true)
		assert(seat.lit:GetAlpha() == 0 and seat.cold:GetAlpha() == 1 and not seat.breath:IsPlaying(), at .. ": cooling, the seat goes steel under its steel mark")
		env._now = env._now + 12
		local flickers = Ending(env, ns, seat, "player", id)
		assert((flickers > 0) == full, at .. ": about to end, the last fifth flickers only at Full, where flares are allowed (" .. flickers .. ")")
		Auras(env, {})
		assert(seat.home:IsPlaying() == full, at .. ": ended, the crowned medal folds home only at Full")
		env._now = env._now + 180
		Cooled(env, seat)
		assert(seat.lit:GetAlpha() == 1 and seat.cold:GetAlpha() == 0 and seat.relight:IsPlaying() == not off and seat.flare[1]:IsPlaying() == full,
			at .. ": ready again, relit, with a flare at Full and a relight in place at Calm")
		Clean(env, K)
	end
end

-- A racial whose sigil already has a published aura (Blood Fury's axe) burns that sheet on the second rail when the rail has
-- no aura of its own for it: the sheet spans 1.25 times its sigil and loops at its own 1.44 s.
do
	local env, K, ns = New("MAGE", { known = { 12042, 20572 }, tree = 1 })
	Awake(env)
	local fury = Rail(ns).spare[1]
	assert(fury and fury.key == "bloodFury", "Blood Fury stands on the second rail")
	assert(fury.aura.loop, "Blood Fury's medal has an aura to burn")
	local file = fury.aura.moving._state.Texture[1]
	assert(file:find("Auras\\Sigils\\Axe.png", 1, true) and fury.aura.loop:IsPlaying(), "ready at Full: Blood Fury burns its axe aura")
	assert(fury.aura.loop._anims[1]:GetDuration() == 1.44, "the axe sheet loops at its own 1.44 s")
	local still
	for _, region in ipairs(fury._regions) do
		local texture = region._state and region._state.Texture
		if texture and texture[1]:find("Textures\\Sigils\\Axe.png", 1, true) then still = region end
	end
	local w, mark = fury.aura.moving:GetWidth(), still:GetWidth()
	assert(math.abs(w - mark * 1.25) <= 2, "the sheet spans 1.25 times the sigil (" .. w .. " against " .. mark .. ")")
	Clean(env, K)
end

-- Soulstone's 30-minute cooldown belongs to the stone, not to Create Soulstone: its medal on the second rail counts the cooldown
-- every soulstone shares (Minor to Major), a use of the stone (20765) presses it and conjuring one (20757) does not, the global
-- cooldown alone does not turn it steel, and a cooldown the game hides keeps the medal as it stood. Ritual of Doom beside it
-- counts its own one-hour spell cooldown.
do
	local env, K, ns = New("WARLOCK", { known = { 603, 6789, 1122, 20757, 18540 }, tree = 1 })
	Awake(env)
	local rail = Rail(ns)
	local stone, ritual = rail.spare[1], rail.spare[2]
	assert(stone and stone.key == "soulstone" and stone.small and stone.lit:GetAlpha() == 1, "Soulstone stands ready on the second rail")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-20757", 20757)
	assert(not stone.dip:IsPlaying(), "conjuring a Major Soulstone does not press its medal")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-20765", 20765)
	assert(stone.dip:IsPlaying(), "using a Major Soulstone presses its medal")
	local function Stones(length)
		for _, item in ipairs({ 16896, 16895, 16893, 16892, 5232 }) do env._cooling[item] = length and { env._now, length } or nil end
		env.FireEvent("BAG_UPDATE_COOLDOWN")
	end
	Stones(1.5)
	assert(stone.lit:GetAlpha() == 1, "the global cooldown alone leaves it lit")
	Stones(1800)
	assert(stone.lit:GetAlpha() == 0 and stone.cold:GetAlpha() == 1, "the stone's 30-minute cooldown turns the medal steel")
	local get = env.C_Item.GetItemCooldown
	env.C_Item.GetItemCooldown = function(id) local start, length, enable = get(id) return env.Secret(start), env.Secret(length), enable end
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(stone.lit:GetAlpha() == 0 and stone.cold:GetAlpha() == 1 and not stone.relight:IsPlaying(), "a hidden cooldown keeps the cooling stone steel")
	env.C_Item.GetItemCooldown = get
	Stones(nil)
	assert(stone.lit:GetAlpha() == 1, "the stone ready again, readable once more, relights it")
	env.C_Item.GetItemCooldown = function(id) local start, length, enable = get(id) return env.Secret(start), env.Secret(length), enable end
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(stone.lit:GetAlpha() == 1, "and a hidden cooldown keeps the ready stone lit")
	env.C_Item.GetItemCooldown = get
	assert(ritual and ritual.key == "ritual" and ritual.lit:GetAlpha() == 1, "Ritual of Doom stands ready beside it")
	local ready, hour = env.C_Spell.GetSpellCooldownDuration, { start = env._now, finish = env._now + 3600 }
	env.C_Spell.GetSpellCooldownDuration = function(spell, ...) if spell == 18540 then return hour end return ready(spell, ...) end
	Cooling(env, 18540, true)
	assert(ritual.lit:GetAlpha() == 0 and ritual.cold:GetAlpha() == 1, "the ritual's one-hour cooldown turns its medal steel")
	for _, timer in ipairs({ ritual.sweep, ritual.refill }) do
		local fed = R.AB.W.LastCall(timer, "SetCooldownFromDurationObject")
		assert(fed and fed[1] == hour, "the ritual's dark sweep and steel ring count the one-hour duration the client reports for Ritual of Doom")
	end
	env.C_Spell.GetSpellCooldownDuration = ready
	Cooled(env, ritual)
	assert(ritual.lit:GetAlpha() == 1, "and it relights when the ritual is ready again")
	Clean(env, K)
end

-- Soulstone and Ritual of Doom keep to the second rail: the settings list does not offer them, a stale pick of one falls back,
-- and a regular pick on a sparse rail leaves them where they stood rather than pulling them into an empty seat.
do
	local env, K, ns = New("WARLOCK", { known = { 603, 6789, 1122, 20757, 18540 }, tree = 1 })
	env.C_Spell.GetSpellName = function(id) return "spell " .. id end
	local values = {}
	for _, option in ipairs(ns.SlabRail.Choices()) do values[#values + 1] = option.value end
	assert(table.concat(values, ","):find("soulstone") == nil and table.concat(values, ","):find("ritual") == nil,
		"the list offers neither: " .. table.concat(values, ","))
	K.Options.Write("ActionBars", "crestRailSeat1", "inferno")
	env.RunTimers()
	local rail = Rail(ns)
	assert(Keys(rail) == "inferno,coil" and Spares(rail) == "soulstone,ritual", "a regular pick moves only the main seats: " .. Keys(rail) .. " | " .. Spares(rail))
	K.Options.Write("ActionBars", "crestRailSeat2", "soulstone")
	env.RunTimers()
	assert(Keys(rail) == "inferno,coil" and Spares(rail) == "soulstone,ritual", "a pick of the stone falls back: " .. Keys(rail) .. " | " .. Spares(rail))
	Clean(env, K)
end

-- A cooldown the game hides mid-fight keeps the seat as it stood, with no error.
do
	local env, K, ns = New("MAGE", { known = { 12042, 11958 }, tree = 1 })
	Awake(env)
	local power = Rail(ns).made.power
	Cooling(env, 12042, true)
	env.C_Spell.GetSpellCooldown = function() return { isActive = env.Secret(true), isOnGCD = env.Secret(false) } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(power.lit:GetAlpha() == 0 and power.cold:GetAlpha() == 1, "a hidden cooldown leaves a cooling seat steel")
	Cooled(env, power)
	assert(power.lit:GetAlpha() == 1, "and the engine's own sweep end still relights it")
	Clean(env, K)
end

-- A second-rail medal whose cooldown buffs lifts to the crown when pressed, like a seat. Any straight or cornered line from it
-- crosses the main seats, the other small medals or the unit frame beside it, so it shrinks to a 4-unit spark where it stands, drops to the lane
-- 8 units above the crown (between the unit frame's top and the end seat's foot), runs along it and drops into the crown, where it
-- pops to full size once landed; the fold home runs the same three legs backwards. On the flat row the lane is 22 units under
-- the row, between the seats and the rows below them.
do
	local env, K, ns = New("MAGE", { known = { 12042, 12043, 2136, 11129, 11958 }, tree = 1 })
	Awake(env)
	local rail = Rail(ns)
	assert(Keys(rail) == "power,presence,blast,combustion" and Spares(rail) == "block", "Ice Block stands on the second rail")
	local block = rail.spare[1]
	Cast(env, 11958)
	assert(block.struck and block.dip:IsPlaying() and block.rise:IsPlaying() and block.gate:GetAlpha() == 1, "pressed: the small medal dips and its crown rises")
	local _, _, _, sx, sy = block:GetPoint(1)
	local _, _, _, cx, cy = rail.crown:GetPoint(1)
	local dx, dy = sx - cx, sy - cy
	assert(dx < -60 and dy > 20, "the medal stands left of and above the crown (" .. dx .. ", " .. dy .. ")")
	local function at(anim) local x, y = anim:GetOffset() return x .. "," .. y end
	-- Scales(group) -> each size step's order and the size the group's steps together give when it ends.
	local function Scales(group)
		local timed, out = Pose.Passes(group), {}
		for _, each in ipairs(timed) do
			if each.anim._type == "Scale" then
				local _, _, _, scale = Pose.At(timed, each.from + each.run)
				out[#out + 1] = each.anim:GetOrder() .. ":" .. string.format("%.3f", scale)
			end
		end
		return table.concat(out, " ")
	end
	assert(at(block.out) == dx .. "," .. dy, "the lift starts at the small medal")
	assert(#block.legs == 3 and at(block.legs[1]) == "0," .. (8 - dy) and at(block.legs[2]) == -dx .. ",0" and at(block.legs[3]) == "0,-8",
		"it drops to the lane under the end seat, runs along it and drops into the crown")
	assert(block.legs[1]:GetOrder() == 3 and block.legs[2]:GetOrder() == 4 and block.legs[3]:GetOrder() == 5, "one leg after another, after the shrink")
	assert(Scales(block.rise) == "1:" .. string.format("%.3f", 22 * 0.86 / 34) .. " 2:" .. string.format("%.3f", 4 / 34) .. " 6:"
		.. string.format("%.3f", 1.29 / 1.21) .. " 7:1.000", "it shrinks to a 4-unit spark where it stands and pops only once it has landed (" .. Scales(block.rise) .. ")")
	assert(at(block.trail[1]) == "0,8" and at(block.trail[2]) == dx .. ",0" and at(block.trail[3]) == "0," .. (dy - 8),
		"the fold home runs the same lane backwards")
	local seat = rail.order[1]
	local _, _, _, ax, ay = seat:GetPoint(1)
	assert(#seat.legs == 1 and at(seat.legs[1]) == (cx - ax) .. "," .. (cy - ay) and at(seat.trail[1]) == (ax - cx) .. "," .. (ay - cy),
		"a seat on the main rail still flies straight to the crown and back")
	assert(Scales(seat.rise) == "1:" .. string.format("%.3f", 28 * 0.86 / 34) .. " 2:" .. string.format("%.3f", 1.29 / 1.21) .. " 3:1.000",
		"it leaves at its dipped size, pops at the crown and settles to the crown's size (" .. Scales(seat.rise) .. ")")
	K.Layout.Register(env.CreateFrame("Frame"), "unitframes.castbar.player", { anchor = "CENTER", x = 0, y = 0 })
	K.Layout.SetLive("unitframes.castbar.player", false)
	K.Layout.SetLive("unitframes.castbar.player", true)
	assert(rail.low, "the centred cast bar moves the rail to its flat row")
	_, _, _, sx, sy = block:GetPoint(1)
	_, _, _, cx, cy = rail.crown:GetPoint(1)
	dx, dy = sx - cx, sy - cy
	assert(dx < -20, "on the flat row the first small medal stands left of the crown (" .. dx .. ")")
	assert(at(block.legs[1]) == "0," .. (-22 - dy) and at(block.legs[2]) == -dx .. ",0" and at(block.legs[3]) == "0,22"
		and at(block.trail[1]) == "0,-22" and at(block.trail[3]) == "0," .. (dy + 22), "and runs the lane 22 units under the row both ways")
	assert(Scales(block.rise) == "1:" .. string.format("%.3f", 22 * 0.86 / 34) .. " 2:" .. string.format("%.3f", 4 / 34) .. " 6:1.000 7:1.000",
		"and lands at the crown's size with no pop (" .. Scales(block.rise) .. ")")
	Auras(env, { { 27619, 10 } })
	assert(block.crowned:IsShown() and rail.owner == block, "active: its buff, by the aura's own id, owns the crown")
	Clean(env, K)
end

-- A spell with no drawn sigil yet shows its own round icon, greyed while it cools.
do
	local env, K, ns = New("MAGE", { known = { 12472, 11958, 12051 }, tree = 3 })
	local rail = Rail(ns)
	local snap = rail.made.snap
	local function Icon(frame)
		for _, region in ipairs(frame._regions) do
			local texture = region._state and region._state.Texture
			if texture and texture[1] == 1000000 + 12472 then return region end
		end
	end
	local face, mark = Icon(snap), Icon(snap.cold)
	local function Grey(region) return (region._state.Desaturated or {})[1] == true end
	assert(face and not Grey(face), "Cold Snap's seat draws the spell's own icon in colour")
	assert(mark and Grey(mark), "and greys it for the steel mark over the cooldown")
	Clean(env, K)
end

-- The settings list: a known ability the player picks takes its seat, a displaced long cooldown moves to the second rail, and an
-- unknown or unlearned pick falls back to the tree's choice.
do
	local env, K, ns = New("MAGE", { known = MAGE, tree = 1, trinket = true })
	env.C_Spell.GetSpellName = function(id) return "spell " .. id end
	local values = {}
	for _, option in ipairs(ns.SlabRail.Choices()) do values[#values + 1] = option.value end
	assert(table.concat(values, ",") == ",power,presence,evocation,combustion,block,snap,blast,cone,barrier",
		"the list offers the tree's choice, then every known ability of the class's lists: " .. table.concat(values, ","))
	K.Options.Write("ActionBars", "crestRailSeat1", "evocation")
	env.RunTimers()
	local rail = Rail(ns)
	assert(Keys(rail) == "evocation,power,presence,blast,trinket" and Spares(rail) == "combustion,block,snap",
		"a picked seat takes its place and the rest move along: " .. Keys(rail) .. " | " .. Spares(rail))
	K.Options.Write("ActionBars", "crestRailSeat3", "cone")
	env.RunTimers()
	assert(Keys(rail) == "evocation,power,cone,presence,trinket" and Spares(rail) == "combustion,block,snap",
		"a picked rotation cooldown takes its seat and the seat it displaced moves along: " .. Keys(rail) .. " | " .. Spares(rail))
	K.Options.Write("ActionBars", "crestRailSeat1", "nothing")
	K.Options.Write("ActionBars", "crestRailSeat3", "")
	env.RunTimers()
	assert(Keys(rail) == "power,presence,evocation,blast,trinket", "an unknown pick falls back to the tree's choice: " .. Keys(rail))
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 12042, 11958 }, tree = 1 })
	K.Options.Write("ActionBars", "crestRailSeat2", "evocation")
	env.RunTimers()
	assert(Keys(Rail(ns)) == "power,block", "an unlearned pick falls back to the tree's choice")
	Clean(env, K)
end

-- A pick for a late seat keeps its number when the seats before it have nothing to hold: Rail seat 4 stands fourth, not second.
do
	local env, K, ns = New("MAGE", { known = { 12042, 12051 }, tree = 1 })
	K.Options.Write("ActionBars", "crestRailSeat4", "evocation")
	env.RunTimers()
	local rail = Rail(ns)
	assert(Keys(rail) == "power,evocation", "the two known abilities stand: " .. Keys(rail))
	local _, _, _, first = rail.order[1]:GetPoint(1)
	local _, _, _, fourth = rail.order[2]:GetPoint(1)
	assert(fourth - first == 93, "Evocation stands three seats (31 units each) right of the first seat, in seat 4: " .. (fourth - first))
	Clean(env, K)
end

-- The second rail stands clear of the main rail and the crown on the arc and on the low row.
do
	local env, K, ns = New("MAGE", { known = MAGE, tree = 3, trinket = true })
	local holder = env.CreateFrame("Frame")
	K.Layout.Register(holder, "unitframes.castbar.player", { anchor = "CENTER", x = 0, y = 0 })
	local rail = Rail(ns)
	for _, low in ipairs({ false, true }) do
		K.Layout.SetLive("unitframes.castbar.player", low)
		local placed = {}
		for _, list in ipairs({ rail.order, rail.spare, { rail.crown } }) do
			for _, f in ipairs(list) do
				local _, _, _, x, y = f:GetPoint(1)
				placed[#placed + 1] = { x, y, (f.size or f.units) / 2 }
			end
		end
		for i = 1, #placed do
			for j = i + 1, #placed do
				local a, b = placed[i], placed[j]
				local gap = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) - a[3] - b[3]
				assert(gap >= 0, (low and "low row" or "arc") .. ": no two medals overlap (" .. i .. ", " .. j .. ")")
			end
		end
	end
	assert(Updating(rail) == 0, "nothing on either rail runs OnUpdate")
	Clean(env, K)
end

print("actionbars crest rail ok")
