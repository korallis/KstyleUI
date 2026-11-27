-- test-actionbars-crest-rail.lua: every class's five-seat crest rail (KstyleUI_ActionBars/SlabRail.lua), as the crest plan (KSTY-60, KSTY-97) asks: the tree the game names stands its own known abilities, its rotation cooldowns and then the class's other long cooldowns in any free seat, the trinket fifth, the long cooldowns beyond the seats as round medals on a second rail that rise to the crown like a seat, and the seats a player picks in the settings list; seven states driven by the game's own events at Full, Calm and Off (ready, pressed, active, about to end, ended, cooling, ready again), each ready seat burning with its animated aura; the newest running buff owns the crown; a motion change stops what is in flight; auras turning secret mid-fight raise no error; the rail holds its abilities back from the cooldown row and the trinket seat; the captain's choice moves it to its own flat row while the centred cast bars show; nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local Slots, New, Seated, Updating, Clean = R.Slots, R.New, R.Seated, R.Updating, R.Clean

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
	local env, K, ns = New("MAGE", { known = { 12042, 11958, 116 }, tree = 1 })
	local rail = Rail(ns)
	assert(Keys(rail) == "power,block" and Spares(rail) == "", "a mage with only Arcane Power and Ice Block seats both, Ice Block in the free seat")
	local row = Seated(ns, "crestCooldowns")
	for _, b in ipairs(row and row.sigils or {}) do
		assert(not (b.at and (b.family.sigil == "Arcane" or b.family.sigil == "Crystal")), "the railed cooldowns leave the cooldown row")
	end
	Clean(env, K)
end

-- Seven states on a seat whose sigil has no baked aura yet: the still sigil stands in, at Full, Calm and Off.
do
	local env, K, ns = New("MAGE", { known = { 12042, 12043, 11958 }, tree = 1 })
	Awake(env)
	local rail = Rail(ns)
	local power = rail.made.power
	assert(power.aura.loop == false and power.lit:GetAlpha() == 1 and power.breath:IsPlaying(), "ready at Full: Arcane Power's seat lights and breathes with its still sigil")
	Cast(env, 12042)
	assert(power.dip:IsPlaying() and power.bursting:IsPlaying() and power.rise:IsPlaying() and power.gate:GetAlpha() == 1, "pressed at Full: the seat dips, bursts and rises to the crown")
	Auras(env, { { 12042, 15 } })
	assert(power.crowned:IsShown() and power.burn:GetAlpha() == 1, "active: the crown shows the aura's own slot with the sigil")
	Cooling(env, 12042, true)
	assert(power.lit:GetAlpha() == 0 and power.cold:GetAlpha() == 1 and not power.breath:IsPlaying(), "cooling: the seat goes steel under its steel mark")
	Auras(env, {})
	assert(power.home:IsPlaying(), "ended at Full: the crowned medal folds home")
	assert(Cooled(env, power) and power.flare[1]:IsPlaying(), "ready again at Full: the seat relights with a flare")
	Motion(env, K, "calm")
	assert(power.lit:GetAlpha() == 1 and not power.breath:IsPlaying(), "ready at Calm: lit without breathing")
	Cast(env, 12042)
	assert(not power.rise:IsPlaying() and not power.dip:IsPlaying(), "pressed at Calm: no dip or rise")
	Motion(env, K, "off")
	Auras(env, { { 12042, 15 } })
	assert(power.gate:GetAlpha() == 0, "active at Off: no crown")
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

-- A second-rail medal whose cooldown buffs lifts to the crown when pressed, like a seat. Its straight line would cross the top
-- corner of the unit frame beside it, so it flies across above the main rail first and then down to the crown, and folds home
-- the same way back.
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
	assert(at(block.out) == dx .. "," .. dy, "the lift starts at the small medal")
	assert(at(block.back) == -dx .. ",0" and at(block.down) == "0," .. -dy, "it flies across at the medal's height, then down to the crown")
	assert(block.down:GetStartDelay() == block.back:GetDuration(), "the drop starts as the flight across ends")
	assert(at(block.away) == "0," .. dy and at(block.across) == dx .. ",0" and block.across:GetStartDelay() == block.away:GetDuration(),
		"the fold rises from the crown first, then flies across home")
	local seat = rail.order[1]
	local _, _, _, ax, ay = seat:GetPoint(1)
	assert(at(seat.back) == (cx - ax) .. "," .. (cy - ay) and at(seat.down) == "0,0" and at(seat.across) == "0,0",
		"a seat on the main rail still flies straight to the crown and back")
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
