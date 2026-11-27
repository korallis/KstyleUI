-- test-actionbars-crest-rail.lua: the hunter's five-seat crest rail (KstyleUI_ActionBars/SlabRail.lua), as the crest plan (KSTY-60, KSTY-97) asks: the tree the game names stands its own known abilities, the trinket fifth; seven states driven by the game's own events at Full, Calm and Off (ready, pressed, active, about to end, ended, cooling, ready again), each ready seat burning with its animated aura; the newest running buff owns the crown; a motion change stops what is in flight; auras turning secret mid-fight raise no error; the rail holds its abilities back from the cooldown row and the trinket seat; the captain's choice moves it to its own flat row while the centred cast bars show; nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local Slots, New, Seated, Updating, Clean, Learn = R.Slots, R.New, R.Seated, R.Updating, R.Clean, R.Learn

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

local function Cooled(env, seat, id)
	Cooling(env, id, false)
	seat.sweep:GetScript("OnCooldownDone")(seat.sweep)
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
	for _, family in ipairs(row.spec.families) do
		if family.sigil == "Volley" or family.sigil == "Deflect" or family.sigil == "Paw" then own[#own + 1] = family.sigil end
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
	env.C_SpecializationInfo = { GetSpecializationInfo = function(i) return i, "tree", "", 0, "DAMAGER", nil, i == 3 and 31 or 5 end }
	Learn(env, 3044)
	assert(Keys(Rail(ns)) == "rapid,deter,trap,strider", "with no primary tree, the tree with the most points spent is chosen: " .. Keys(Rail(ns)))
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
	env._ending = nil
	Auras(env, {})
	assert(rapid.home:IsPlaying() and rapid.burn:GetAlpha() == 0, "ended at Full: the crowned medal cools to steel and folds home")
	env._now = env._now + 120
	Cooled(env, rapid, 3045)
	assert(rapid.lit:GetAlpha() == 1 and rapid.relight:IsPlaying() and rapid.flare[1]:IsPlaying() and rapid.glinting:IsPlaying() and Burning(rapid),
		"ready again at Full: the seat relights with a flare and a glint and its aura burns again")
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
	Cooled(env, rapid, 3045)
	assert(rapid.relight:IsPlaying() and not rapid.flare[1]:IsPlaying() and not rapid.glinting:IsPlaying(), "ready again at Calm: a relight in place with no flare")
	Motion(env, K, "off")
	Cooling(env, 3045, true)
	Cooled(env, rapid, 3045)
	assert(rapid.lit:GetAlpha() == 1 and not rapid.relight:IsPlaying() and Still(rapid), "ready again at Off: lit with no motion")
	Auras(env, { { 3045, 15 } })
	assert(rapid.gate:GetAlpha() == 0 and rapid.hold:GetAlpha() == 0, "active at Off: no crown and no draining seat")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
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
	rail:Hide()
	rail:GetScript("OnHide")(rail)
	assert(not rapid.breath:IsPlaying() and not rapid.aura.loop:IsPlaying(), "hiding the rail stops what is in flight")
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
	assert(not Seated(ns, "crestCooldowns"), "the rail holds Rapid Fire and Bestial Wrath, so the cooldown row has nothing left")
	K.Options.Write("ActionBars", "crestRail", false)
	local row = Seated(ns, "crestCooldowns")
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and row and Hunter(row) == "Volley,Deflect,Paw", "switched off, the cooldown row and the crest trinket come back")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 75, 19574, 3045, 19263, 14305, 1317257 }, tree = 3 })
	local row = Seated(ns, "crestCooldowns")
	assert(row and Hunter(row) == "Paw", "a survival rail leaves Bestial Wrath on the cooldown row")
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

print("actionbars crest rail ok")
