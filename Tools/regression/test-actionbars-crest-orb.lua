-- test-actionbars-crest-orb.lua: the mage's power orb (KstyleUI_ActionBars/SlabOrb.lua) and the mage's rail (SlabRail.lua). The owner asked for the mage's crest to become a power orb tied to the spell effects, unique for each race and class, clearly showing procs and cooldowns without the Cooldown Manager; the orb plan and the owner's settings ask that the light is each tree's school colour and fills as the tree's great cooldown (Arcane Power, Combustion, Cold Snap, else Ice Block) returns, that the vessel is the player's race, that Clearcasting, Missile Barrage, Heating Up (a third of the rim per stack) and Fingers of Frost (a rime per charge) light inside it, and that the rail stands the other cooldowns and racials the owner named. The orb steps aside under Frames or when switched off, secret auras raise no error, and nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local AB, Slots, New, Seated, Piece, Updating, Clean = R.AB, R.Slots, R.New, R.Seated, R.Piece, R.Updating, R.Clean

local ARCANE = { 168, 759, 116, 118, 12574, 12042, 12043, 12051, 1953, 122, 2136, 2139 }
local FIRE = { 168, 759, 116, 118, 11129, 11113, 12051, 1953, 122, 2136, 2139, 20572 }
local FROST = { 168, 759, 116, 118, 12472, 11426, 11958, 1953, 122, 2136, 2139, 7744 }

local function File(region)
	return (tostring(region:GetTexture()):match("([%w]+)%.png$"))
end

local function Seats(ns)
	local keys = {}
	for i, at in ipairs(Seated(ns, "crestRail") and ns.SlabRail.picked or {}) do keys[i] = at.key end
	return "," .. table.concat(keys, ",") .. ","
end

local function Vessel(orb)
	for _, region in ipairs(orb._regions or {}) do
		local file = region.GetTexture and File(region)
		if file and file:find("^Vessel") then return file end
	end
end

local function Cooling(env, id)
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = spell == id, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function(spell) return spell == id and { start = env._now, finish = env._now + 180 } or { start = 0, finish = 0 } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
end

local function Up(env, id, count)
	Slots.Set(env, "player", id and { { id = id, auraInstanceID = id, start = env._now, duration = 15, count = count } } or nil)
end

-- Lit(orb) -> one digit per proc, 1 where its first effect shows.
local function Lit(orb)
	local on = {}
	for i, lit in ipairs(orb.procs) do on[i] = lit.fires[1]:IsVisible() and "1" or "0" end
	return table.concat(on)
end

-- Each tree's orb holds its own great cooldown in its school's light; the vessel is the player's race; the rail stands the rest.
for _, case in ipairs({
	{ known = ARCANE, race = "Human", spell = 12042, school = "Arcane", vessel = "Human", gone = "ap", seats = { "pom", "evocation", "blink", "nova", "fireBlast" } },
	{ known = FIRE, race = "Orc", spell = 11129, school = "Fire", vessel = "Orc", gone = "combustion", seats = { "blastWave", "fireBlast", "bloodFury" } },
	{ known = FROST, race = "Scourge", spell = 12472, school = "Frost", vessel = "Scourge", gone = "coldSnap", seats = { "iceBlock", "barrier", "forsaken" } },
	{ known = { 168, 116, 11426, 11958, 1953 }, race = "NightElf", spell = 11958, school = "Frost", vessel = "Human", gone = "iceBlock", seats = { "barrier", "blink" } },
}) do
	local env, K, ns = New("MAGE", { known = case.known, before = function(e) e.UnitRace = function() return case.race, case.race, 1 end; e.UnitSex = function() return 2 end end })
	local orb = assert(Seated(ns, "crestOrb"), case.school .. ": a mage's crest shows the power orb")
	assert(orb.spec.spell == case.spell, case.school .. ": the orb holds the tree's great cooldown, not " .. tostring(orb.spec.spell))
	assert(File(orb.fill) == "Light" .. case.school and File(orb.core) == "Core" .. case.school and File(orb.meniscus) == "Meniscus" .. case.school,
		case.school .. ": the light, core and meniscus are the school's own (" .. tostring(File(orb.fill)) .. ")")
	assert(R.Tint(orb.glow, K, "school" .. case.school), case.school .. ": the ready glow is the school's colour")
	assert(Vessel(orb) == "Vessel" .. case.vessel, case.race .. ": the vessel is " .. case.vessel .. "'s, not " .. tostring(Vessel(orb)))
	local seats = Seats(ns)
	assert(not seats:find("," .. case.gone .. ",", 1, true), case.school .. ": the rail leaves the orb's cooldown to the orb (" .. seats .. ")")
	for _, key in ipairs(case.seats) do
		assert(seats:find("," .. key .. ",", 1, true), case.school .. ": the rail stands " .. key .. " (" .. seats .. ")")
	end
	Clean(env, K)
end

-- The light empties when the great cooldown is spent, fills from the game's own timer and flares when it returns.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "Arcane Power ready: the orb is full, its core burning")
	assert(orb.fill.loop:IsPlaying() and orb.core.loop:IsPlaying(), "at full motion the light and the core loop their flip-books")
	Cooling(env, 12042)
	assert(not orb.ready:IsShown() and orb.spent:IsShown(), "spent: the core goes out and the meniscus rides the light's surface")
	local timed = AB.W.LastCall(orb.bar, "SetTimerDuration")
	assert(timed and timed[1].finish == env._now + 180, "the light refills from the cooldown's own duration, which the game advances")
	env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
	orb.flare.play:Stop()
	orb.timer:GetScript("OnCooldownDone")(orb.timer)
	assert(orb.ready:IsShown() and not orb.spent:IsShown() and orb.flare.play:IsPlaying(), "back: the orb is full again and bursts")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "the cooldown event after the timer agrees the orb is full")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(not orb.fill.loop:IsPlaying() and orb.fill:GetAlpha() == 0 and orb.fill.still:GetAlpha() == 1, "Calm holds the light on a still frame")
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	assert(orb.fill.loop:IsPlaying(), "full motion plays the light again")
	assert(Updating(orb) == 0, "nothing in the orb runs OnUpdate")
	Clean(env, K)
end

-- Each proc lights inside the orb only while its own buff is up; Heating Up fills a third of the rim per stack.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	assert(Lit(orb) == "0000", "no proc: nothing lights in the orb (" .. Lit(orb) .. ")")
	for i, id in ipairs({ 12536, 400589, 400625, 400670 }) do
		Up(env, id, 1)
		local want = ("000"):sub(1, i - 1) .. "1" .. ("000"):sub(i)
		assert(Lit(orb) == want, id .. " lights its own effect alone (" .. Lit(orb) .. ", want " .. want .. ")")
	end
	Up(env, 1326083)
	assert(Lit(orb) == "0100", "the other Missile Barrage ID lights the bolts too (" .. Lit(orb) .. ")")
	assert(#orb.procs[3].fires == 3 and #orb.procs[4].fires == 2, "Heating Up has three stacks, Fingers of Frost two charges")
	for count = 1, 3 do
		Up(env, 400625, count)
		local filled = 0
		for _, slot in ipairs(orb.lits) do
			local bar = slot.bar
			if bar and slot.container == orb.procs[3].container and bar:IsShown() then
				local low, high = bar:GetMinMaxValues()
				filled = filled + math.max(0, math.min(1, (bar._count - low) / (high - low)))
			end
		end
		assert(filled == count, count .. " Heating Up stacks fill " .. count .. " thirds of the rim, not " .. filled)
	end
	Up(env, nil)
	assert(Lit(orb) == "0000", "the procs fade when their buffs drop")
	assert(Updating(orb) == 0, "nothing in the orb runs OnUpdate")
	Clean(env, K)
end

-- Aura data going secret before a pull, and coming back, raises no error and keeps the orb.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	Up(env, 400589)
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Cooling(env, 12042)
	Up(env, 12536)
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	assert(orb and orb.spent:IsShown(), "the orb stays and shows the spent cooldown through the restriction")
	Clean(env, K)
end

-- Switched off, or under the Frames form, the orb steps aside: Arcane Power returns to the rail and Clearcasting to its ring.
do
	local env, K, ns = New("MAGE", { known = ARCANE, before = function(_, K) K.Options.Write("ActionBars", "crestOrb", false) end })
	assert(not Seated(ns, "crestOrb"), "switched off, no orb shows")
	assert(Seats(ns):find(",ap,", 1, true), "switched off, Arcane Power stands on the rail (" .. Seats(ns) .. ")")
	assert(select(2, Piece(ns, "crestClearcasting")), "switched off, Clearcasting has its ring again")
	K.Options.Write("ActionBars", "crestOrb", true)
	env.RunTimers()
	assert(Seated(ns, "crestOrb") and not Seats(ns):find(",ap,", 1, true) and not select(2, Piece(ns, "crestClearcasting")),
		"switched back on, the orb takes Arcane Power and Clearcasting again")
	Clean(env, K)
	env, K, ns = New("MAGE", { known = ARCANE, frames = true })
	assert(not Seated(ns, "crestOrb") and not ns.SlabOrb.Held(), "the Frames form has no crest, so no orb")
	assert(select(2, Piece(ns, "crestClearcasting")), "under Frames, Clearcasting keeps its own row")
	Clean(env, K)
end

print("actionbars crest orb ok")
