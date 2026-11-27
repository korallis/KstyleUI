-- test-actionbars-crest-rail.lua: the hunter's five-seat crest rail (KstyleUI_ActionBars/SlabRail.lua), as the crest plan asks: each talent tree stands its own abilities on the rail, known ones only, with the on-use trinket as the fifth seat; the seats bow on an arc above the ring; a ready medal lights and breathes at Full, a press dips and bursts it and a buffed major rises to the crown under the rail's own gate, the aura's slots show the crowned medal and drain the seat, the crown's timer ending folds it home; a cooldown darkens the seat and refills a reversed steel ring, and the end of the cooldown relights it with a flare at Full, a relight alone at Calm and no motion at Off; Off shows no crown; the rail lifts the rim's sigils, Rapid Fire's gust and the crest trinket while it shows and gives them back when switched off; Frames builds no rail; nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local Slots, New, Seated, Updating, Clean = R.Slots, R.New, R.Seated, R.Updating, R.Clean

local BM = { 13165, 883, 75, 19574, 3045, 19577, 14305 }
local MM = { 13165, 883, 75, 3045, 14305, 1310786, 20904 }
local SV = { 13165, 883, 75, 3045, 19263, 14305, 1317257 }

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

for _, case in ipairs({ { BM, "wrath,rapid,intimidate,trap" }, { MM, "rapid,trap,sniper,aimed" }, { SV, "rapid,deter,trap,strider" } }) do
	local env, K, ns = New("HUNTER", { known = case[1], trinket = true })
	local rail = assert(Rail(ns), "a hunter who knows a rail ability sees the rail")
	assert(Keys(rail) == case[2] .. ",trinket", "each tree stands its own four abilities, then the trinket: " .. Keys(rail))
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 75, 19574, 3045, 14305 } })
	local rail = Rail(ns)
	assert(Keys(rail) == "wrath,rapid,trap", "an unlearned ability and an empty trinket slot leave no seat: " .. Keys(rail))
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
	assert(rapid.lit:GetAlpha() == 1 and rapid.breath:IsPlaying(), "ready: Rapid Fire lights gold and breathes at Full")
	Cooling(env, 3045, true)
	assert(rapid.lit:GetAlpha() == 0 and not rapid.breath:IsPlaying(), "cooling: the medal goes steel and stops breathing")
	assert(env.Reveal and R.AB.W.LastCall(rapid.sweep, "SetCooldownFromDurationObject") and R.AB.W.LastCall(rapid.refill, "SetCooldownFromDurationObject"),
		"cooling: the dark sweep and the steel ring take the engine's duration object")
	assert(rapid.refill:GetReverse(), "the steel ring refills rather than drains")
	Cooling(env, 3045, false)
	rapid.ready = false
	rapid.lit:SetAlpha(0)
	rapid.sweep:GetScript("OnCooldownDone")(rapid.sweep)
	assert(rapid.lit:GetAlpha() == 1 and rapid.relight:IsPlaying() and rapid.flare[1]:IsPlaying() and rapid.flare[2]:IsPlaying(), "ready again at Full: it relights with a flare")
	Motion(env, K, "calm")
	rapid.ready = false
	rapid.sweep:GetScript("OnCooldownDone")(rapid.sweep)
	assert(rapid.relight:IsPlaying() and not rapid.breath:IsPlaying(), "ready again at Calm: it relights in place and does not breathe")
	Motion(env, K, "off")
	rapid.ready = false
	rapid.relight:Stop()
	rapid.flare[1]:Stop()
	rapid.sweep:GetScript("OnCooldownDone")(rapid.sweep)
	assert(rapid.lit:GetAlpha() == 1 and not rapid.relight:IsPlaying() and not rapid.flare[1]:IsPlaying(), "ready again at Off: lit with no motion")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM })
	Awake(env)
	local rail = Rail(ns)
	local rapid, wrath = rail.made.rapid, rail.made.wrath
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 3045)
	assert(rapid.dip:IsPlaying() and rapid.bursting:IsPlaying(), "pressed at Full: the seat dips and bursts")
	assert(rapid.rise:IsPlaying() and rapid.gate:GetAlpha() == 1 and wrath.gate:GetAlpha() == 0, "pressed at Full: Rapid Fire rises to the crown and owns it")
	Slots.Set(env, "player", { { id = 3045, icon = 132208, auraInstanceID = 4, start = 0, duration = 15 } })
	assert(rapid.crowned:IsShown(), "active: the crown's slot shows the lifted medal from the aura itself")
	assert(rapid.crowned._cooldown == rapid.crowned.timer, "active: the crown's ring drains from the aura's own duration")
	assert(rapid.hold:GetAlpha() == 1, "active: the seat's slot darkens it and drains its ring")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 19574)
	assert(wrath.gate:GetAlpha() == 1 and rapid.gate:GetAlpha() == 0, "the newest major takes the crown; the other drains on its seat")
	wrath.crowned.timer:GetScript("OnCooldownDone")(wrath.crowned.timer)
	assert(wrath.home:IsPlaying(), "ended at Full: the crowned medal cools and folds home")
	Motion(env, K, "calm")
	rapid.rise:Stop()
	rapid.dip:Stop()
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 3045)
	assert(rapid.gate:GetAlpha() == 1 and not rapid.rise:IsPlaying() and not rapid.dip:IsPlaying(), "pressed at Calm: the crown lights in place with no lift or dip")
	Motion(env, K, "off")
	assert(rapid.gate:GetAlpha() == 0 and rapid.hold:GetAlpha() == 0, "Off: no crown and no active seat; the seat shows only lit, cooling or ready")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, trinket = true })
	assert(not Seated(ns, "crestTrinkets") and Rail(ns).made.trinket:IsShown(), "the trinket stands on the rail, not beside the crest")
	assert(#Seated(ns, "crestCooldowns").sigils == 0, "the rail's majors leave the rim's small sigils")
	K.Options.Write("ActionBars", "crestRail", false)
	assert(not Rail(ns) and Seated(ns, "crestTrinkets") and #Seated(ns, "crestCooldowns").sigils > 0, "switched off, the rim's sigils and the crest trinket come back")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = BM, frames = true })
	assert(not Rail(ns), "Frames builds no rail")
	Clean(env, K)
end

print("actionbars crest rail ok")
