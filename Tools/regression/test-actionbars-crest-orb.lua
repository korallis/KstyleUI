-- test-actionbars-crest-orb.lua: the mage's power orb (KstyleUI_ActionBars/SlabOrb.lua) and the mage's rail (SlabRail.lua). The owner asked for the mage's crest to become a power orb tied to the spell effects, unique for each race and class, clearly showing procs and cooldowns without the Cooldown Manager; the orb plan and the owner's settings ask that the light is each tree's school colour and fills as the tree's great cooldown (Arcane Power, Combustion, Cold Snap, else Ice Block) returns, that the vessel is the player's race, that Clearcasting and Missile Barrage, and on their own trees Heating Up (a third of the rim per stack) and Fingers of Frost (a rime per charge), light inside it while Clearcasting keeps its own ring, and that the rail stands the other cooldowns and racials the owner named. The orb steps aside under Frames or when switched off, secret auras raise no error, and nothing runs OnUpdate.
local R = dofile("Tools/regression/ranged_env.lua")
local AB, Slots, New, Seated, Piece, Updating, Clean = R.AB, R.Slots, R.New, R.Seated, R.Piece, R.Updating, R.Clean
local Scene = dofile("Tools/render/scene.lua")

local ARCANE = { 168, 759, 116, 118, 12574, 12042, 12043, 12051, 1953, 122, 2136, 2139 }
local FIRE = { 168, 759, 116, 118, 11129, 11113, 12051, 1953, 122, 2136, 2139, 20572 }
local FROST = { 168, 759, 116, 118, 12472, 11426, 11958, 1953, 122, 2136, 2139, 7744 }

local function File(region)
	return (tostring(region:GetTexture()):match("([%w]+)%.png$"))
end

local function Seats(ns)
	local keys = {}
	local rail = Seated(ns, "crestRail")
	for _, list in ipairs({ rail and rail.order or {}, rail and rail.spare or {} }) do
		for _, seat in ipairs(list) do
			if seat:IsShown() then keys[#keys + 1] = seat.key end
		end
	end
	return "," .. table.concat(keys, ",") .. ","
end

local function Vessel(orb)
	for _, region in ipairs(orb._regions or {}) do
		local file = region.GetTexture and File(region)
		if file and file:find("^Vessel") then return file end
	end
end

local function Cooling(env, id, left, quiet)
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = spell == id, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function(spell) return spell == id and { start = env._now, finish = env._now + (left or 180) } or { start = 0, finish = 0 } end
	if not quiet then env.FireEvent("SPELL_UPDATE_COOLDOWN") end
end

local function Timed(orb)
	local timed = AB.W.LastCall(orb.bar, "SetTimerDuration")
	return timed and timed[1].finish, timed and timed[3]
end

-- Due(env, orb) -> when the orb's completion timer runs out, or nil while it is clear.
local function Due(env, orb)
	local _, left = Scene.CooldownFraction(env, orb.timer, env._now)
	return left and env._now + left
end

-- Elapse(env, orb, seconds) moves the clock on and, as the engine does, runs the completion timer's OnCooldownDone once the
-- duration it was bound to has run out.
local function Elapse(env, orb, seconds)
	local due = Due(env, orb)
	env._now = env._now + seconds
	if due and due <= env._now then orb.timer:GetScript("OnCooldownDone")(orb.timer) end
end

local function Tree(env, from, to)
	for _, id in ipairs(from) do env._known[id] = nil end
	R.Learn(env, unpack(to))
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
	{ known = ARCANE, race = "Human", spell = 12042, school = "Arcane", vessel = "Human", gone = "power", seats = { "presence", "evocation", "blink", "nova", "blast" } },
	{ known = FIRE, race = "Orc", spell = 11129, school = "Fire", vessel = "Orc", gone = "combustion", seats = { "blastWave", "blast", "bloodFury" } },
	{ known = FROST, race = "Scourge", spell = 12472, school = "Frost", vessel = "Scourge", gone = "snap", seats = { "block", "barrier", "forsaken" } },
	{ known = { 168, 116, 11426, 11958, 1953 }, race = "NightElf", spell = 11958, school = "Frost", vessel = "Human", gone = "block", seats = { "barrier", "blink" } },
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
	local finish, direction = Timed(orb)
	assert(finish == env._now + 180 and direction == env.Enum.StatusBarTimerDirection.ElapsedTime,
		"the light refills from the cooldown's own duration as it elapses, which the game advances")
	assert(Due(env, orb) == env._now + 180, "the completion timer counts the same cooldown (" .. tostring(Due(env, orb)) .. ")")
	Cooling(env, 12042, 60)
	assert(Timed(orb) == env._now + 60 and Due(env, orb) == env._now + 60 and orb.spent:IsShown(),
		"a cooldown cut short while spent moves the light and the completion timer onto the new timer (" .. tostring(Due(env, orb)) .. ")")
	orb.flare.play:Stop()
	Elapse(env, orb, 59)
	assert(orb.spent:IsShown() and not orb.flare.play:IsPlaying(), "a second before the shortened cooldown ends the orb is still spent")
	Elapse(env, orb, 2)
	assert(orb.ready:IsShown() and not orb.spent:IsShown() and orb.flare.play:IsPlaying(), "back: the completion timer ends with the cooldown, the orb is full again and bursts")
	env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "the cooldown event after the timer agrees the orb is full")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(not orb.fill.loop:IsPlaying() and orb.fill:GetAlpha() == 0 and orb.fill.still:GetAlpha() == 1, "Calm holds the light on a still frame")
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	assert(orb.fill.loop:IsPlaying(), "full motion plays the light again")
	env.SetTarget(false)
	env.RunTimers()
	assert(not orb.fill.loop:IsPlaying() and orb.fill.slow:IsPlaying() and orb.core.slow:IsPlaying() and orb.fill:GetAlpha() == 1,
		"at rest under full motion the light and core keep a slow idle loop")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(not orb.fill.slow:IsPlaying() and not orb.core.slow:IsPlaying() and orb.fill.still:GetAlpha() == 1, "Calm at rest holds the light still")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	assert(not orb.fill.slow:IsPlaying() and not orb.fill.loop:IsPlaying(), "motion off at rest plays nothing")
	assert(Updating(orb) == 0, "nothing in the orb runs OnUpdate")
	Clean(env, K)
end

-- A changed tree moves the light onto its own cooldown; leaving the crest and coming back reads the cooldown again.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	Cooling(env, 12042, 180)
	Cooling(env, 11129, 45, true)
	Tree(env, ARCANE, FIRE)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	assert(orb.school == "Fire" and orb.spent:IsShown() and Timed(orb) == env._now + 45 and Due(env, orb) == env._now + 45,
		"a talent swap to a cooling Combustion shows the fire orb on Combustion's own timer, light and completion (" .. tostring(Timed(orb)) .. ", " .. tostring(Due(env, orb)) .. ")")
	K.Options.Write("ActionBars", "crestOrb", false)
	env.RunTimers()
	Cooling(env, 11129, 30, true)
	K.Options.Write("ActionBars", "crestOrb", true)
	env.RunTimers()
	orb = Seated(ns, "crestOrb")
	assert(orb.spent:IsShown() and Timed(orb) == env._now + 30 and Due(env, orb) == env._now + 30,
		"coming back, the orb reads the cooldown afresh, light and completion (" .. tostring(Timed(orb)) .. ", " .. tostring(Due(env, orb)) .. ")")
	Clean(env, K)
end

-- A cooldown event that only reports the global cooldown does not empty the orb.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = true, activeCategory = 133 } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "the global cooldown alone leaves the orb full")
	-- Outside the event isOnGCD means nothing (SpellSharedDocumentation.lua), so a rebuild tells the global cooldown by its
	-- recovery category and keeps the orb full.
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = false, activeCategory = 133 } end
	K.Options.Write("ActionBars", "crestOrb", false)
	env.RunTimers()
	K.Options.Write("ActionBars", "crestOrb", true)
	env.RunTimers()
	orb = Seated(ns, "crestOrb")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "rebuilt during the global cooldown alone, the orb stays full")
	Clean(env, K)
end

-- The reviewer's finding on the shared cooldown read: an active cooldown whose global cooldown marker is secret is not a
-- confirmed spend, so it neither empties the orb nor arms a flare, while the orb keeps a spend it already confirmed; a real
-- completion flares once, whether the completion timer or the cooldown event reads it over first.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = env.Secret(true), activeCategory = env.Secret(133) } end
	env.C_Spell.GetSpellCooldownDuration = function() return { start = env._now, finish = env._now + 1.5 } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "a hidden global cooldown marker leaves the known-ready orb full")
	orb.flare.play:Stop()
	Elapse(env, orb, 2)
	assert(orb.ready:IsShown() and not orb.flare.play:IsPlaying(), "the global cooldown's timer running out plays no flare")
	env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not orb.flare.play:IsPlaying(), "the next readable event after a global cooldown alone plays no flare")
	K.Options.Write("ActionBars", "crestOrb", false)
	env.RunTimers()
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = false, activeCategory = env.Secret(133) } end
	K.Options.Write("ActionBars", "crestOrb", true)
	env.RunTimers()
	orb = Seated(ns, "crestOrb")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "rebuilt while the recovery category is secret, the orb is not emptied on a guess")
	Cooling(env, 12042, 30)
	assert(orb.spent:IsShown(), "a cooldown event that reads the global cooldown flag false confirms the spend")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = env.Secret(false) } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.spent:IsShown() and not orb.ready:IsShown(), "a hidden marker on a later event keeps the confirmed spend")
	orb.flare.play:Stop()
	env.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(orb.ready:IsShown() and not orb.spent:IsShown() and orb.flare.play:IsPlaying(), "the event that reads the cooldown over first flares the orb")
	orb.flare.play:Stop()
	Elapse(env, orb, 31)
	assert(not orb.flare.play:IsPlaying(), "and the completion timer after it does not flare a second time")
	Clean(env, K)
end

-- The reviewer's finding on the completion paths: the timer and the cooldown event settle the same ready state, so a timer-first
-- completion leaves the orb ready to take the next spend at once, and a flare armed by one spell never fires for another.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	Cooling(env, 12042, 30)
	orb.flare.play:Stop()
	Elapse(env, orb, 31)
	assert(orb.ready:IsShown() and orb.flare.play:IsPlaying(), "the completion timer ends the spend first and flares the orb")
	orb.flare.play:Stop()
	Cooling(env, 12042, 30)
	assert(orb.spent:IsShown() and not orb.ready:IsShown(), "the next confirmed spend empties the orb again with no ready event between")
	Elapse(env, orb, 31)
	assert(orb.ready:IsShown() and orb.flare.play:IsPlaying(), "and its completion flares again")
	Clean(env, K)
end

do
	local known = {}
	for _, id in ipairs(ARCANE) do if id ~= 12042 then known[#known + 1] = id end end
	local env, K, ns = New("MAGE", { known = known })
	env.SetTarget(true)
	env.RunTimers()
	Cooling(env, 12051, 480)
	local orb = Seated(ns, "crestOrb")
	assert(orb.spent:IsShown(), "without Arcane Power the orb holds a spent Evocation")
	-- The crest's rebuild stops whatever its pieces were playing, so the flare is counted where it is asked for.
	local fire, flared = ns.SlabMedals.Fire, 0
	ns.SlabMedals.Fire = function(piece)
		if piece == orb then flared = flared + 1 end
		return fire(piece)
	end
	R.Learn(env, 12042)
	env.RunTimers()
	assert(Seated(ns, "crestOrb") == orb and orb.spec.spell == 12042, "learning Arcane Power keeps the same orb on the new spell")
	assert(orb.ready:IsShown() and not orb.spent:IsShown(), "learning Arcane Power moves the orb onto its ready cooldown")
	assert(flared == 0, "the ready replacement asks for no flare that Evocation's spend armed (" .. flared .. ")")
	Cooling(env, 12042, 30)
	assert(orb.spent:IsShown(), "Arcane Power's own spend empties the orb")
	Elapse(env, orb, 31)
	assert(orb.ready:IsShown() and orb.flare.play:IsPlaying() and flared == 1, "and its own completion flares it once (" .. flared .. ")")
	ns.SlabMedals.Fire = fire
	Clean(env, K)
end

-- A spent Evocation handing the orb to an Arcane Power that is cooling too re-arms the flare for Arcane Power's own completion.
do
	local known = {}
	for _, id in ipairs(ARCANE) do if id ~= 12042 then known[#known + 1] = id end end
	local env, K, ns = New("MAGE", { known = known })
	env.SetTarget(true)
	env.RunTimers()
	Cooling(env, 12051, 480)
	local orb = Seated(ns, "crestOrb")
	env.C_Spell.GetSpellCooldown = function(spell) return { isActive = spell == 12051 or spell == 12042, isOnGCD = false } end
	env.C_Spell.GetSpellCooldownDuration = function(spell)
		return { start = env._now, finish = env._now + (spell == 12042 and 20 or spell == 12051 and 480 or 0) }
	end
	R.Learn(env, 12042)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.RunTimers()
	assert(orb.spec.spell == 12042 and orb.spent:IsShown() and Due(env, orb) == env._now + 20, "the orb takes Arcane Power's own cooldown, still spent")
	orb.flare.play:Stop()
	Elapse(env, orb, 21)
	assert(orb.ready:IsShown() and orb.flare.play:IsPlaying(), "Arcane Power's completion flares the orb")
	Clean(env, K)
end

-- The reviewer's finding on the rail settings: while the orb is due to show, the list offers no seat for the orb's cooldown,
-- and a saved pick of it waits, taking its seat again once the orb is off.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.C_Spell.GetSpellName = function(id) return "spell " .. id end
	local function Offered()
		local values = {}
		for _, option in ipairs(ns.SlabRail.Choices()) do values[#values + 1] = option.value end
		return "," .. table.concat(values, ",") .. ","
	end
	K.Options.Write("ActionBars", "crestRailSeat1", "power")
	env.SetTarget(true)
	env.RunTimers()
	assert(not Offered():find(",power,", 1, true) and Offered():find(",presence,", 1, true),
		"with the orb on, Arcane Power is not offered for a seat: " .. Offered())
	assert(not Seats(ns):find(",power,", 1, true), "the saved Arcane Power pick does not seat beside the orb: " .. Seats(ns))
	assert(K.Options.Read("ActionBars", "crestRailSeat1") == "power", "the saved pick is kept")
	K.Options.Write("ActionBars", "crestOrb", false)
	env.RunTimers()
	assert(Offered():find(",power,", 1, true), "with the orb off, Arcane Power is offered again: " .. Offered())
	local rail = Seated(ns, "crestRail")
	assert(rail.order[1].key == "power", "and the saved pick takes the first seat again (" .. tostring(rail.order[1].key) .. ")")
	Clean(env, K)
end

-- Each tree builds only its own procs, and each lights inside the orb only while its own buff is up; Heating Up fills a third
-- of the rim per stack and Fingers of Frost has a rime per charge.
local function Heat(orb, proc)
	local filled = 0
	for _, slot in ipairs(orb.lits) do
		local bar = slot.bar
		if bar and slot.container == proc.container and bar:IsShown() then
			local low, high = bar:GetMinMaxValues()
			filled = filled + math.max(0, math.min(1, (bar._count - low) / (high - low)))
		end
	end
	return filled
end

for _, case in ipairs({
	{ known = ARCANE, school = "Arcane", ids = { 12536, 400589 } },
	{ known = FIRE, school = "Fire", ids = { 12536, 400589, 400625 }, heat = 3 },
	{ known = FROST, school = "Frost", ids = { 12536, 400589, 400670 }, rime = 3 },
}) do
	local env, K, ns = New("MAGE", { known = case.known })
	env.SetTarget(true)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	local none = ("0"):rep(#case.ids)
	assert(Lit(orb) == none, case.school .. ": the orb holds the tree's " .. #case.ids .. " procs, none lit (" .. Lit(orb) .. ")")
	for i, id in ipairs(case.ids) do
		Up(env, id, 1)
		local want = none:sub(1, i - 1) .. "1" .. none:sub(i + 1)
		assert(Lit(orb) == want, case.school .. ": " .. id .. " lights its own effect alone (" .. Lit(orb) .. ", want " .. want .. ")")
	end
	Up(env, 1326083)
	assert(Lit(orb) == "01" .. none:sub(3), case.school .. ": the other Missile Barrage ID lights the bolts too (" .. Lit(orb) .. ")")
	if case.heat then
		assert(#orb.procs[case.heat].fires == 3, "Heating Up has three stacks")
		for count = 1, 3 do
			Up(env, 400625, count)
			assert(Heat(orb, orb.procs[case.heat]) == count, count .. " Heating Up stacks fill " .. count .. " thirds of the rim, not " .. Heat(orb, orb.procs[case.heat]))
		end
	end
	if case.rime then
		assert(#orb.procs[case.rime].fires == 2, "Fingers of Frost has two charges")
		for _, count in ipairs({ 1, 2, 1 }) do
			Up(env, 400670, count)
			assert(Heat(orb, orb.procs[case.rime]) == count, count .. " Fingers of Frost charges light " .. count .. " rimes, not " .. Heat(orb, orb.procs[case.rime]))
		end
	end
	Up(env, nil)
	assert(Lit(orb) == none, case.school .. ": the procs fade when their buffs drop")
	assert(Updating(orb) == 0, "nothing in the orb runs OnUpdate")
	Clean(env, K)
end

-- A talent change rebuilds the orb with the new tree's procs.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	Tree(env, ARCANE, FIRE)
	env.RunTimers()
	local orb = Seated(ns, "crestOrb")
	assert(orb.school == "Fire" and #orb.procs == 3, "Arcane to Fire: the orb is the fire orb with Heating Up (" .. tostring(orb.school) .. ", " .. #orb.procs .. ")")
	Up(env, 400625, 2)
	assert(Heat(orb, orb.procs[3]) == 2, "the new orb's Heating Up takes stacks")
	Clean(env, K)
end

-- Aura data going secret before a pull, and coming back, raises no error and keeps the orb.
do
	local env, K, ns = New("MAGE", { known = ARCANE })
	env.SetTarget(true)
	env.RunTimers()
	Up(env, 400589)
	local orb = Seated(ns, "crestOrb")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	-- The addon may not read inside the engine's aura slots while auras are secret, so the engine's own view says what shows.
	assert(Slots.Engine(env, Lit, orb) == "01", "as auras go secret the Missile Barrage already up stays lit (" .. Slots.Engine(env, Lit, orb) .. ")")
	Cooling(env, 12042)
	Up(env, 12536)
	assert(Slots.Engine(env, Lit, orb) == "10", "during the freeze the engine swaps in the Clearcasting that rose and drops the Barrage (" .. Slots.Engine(env, Lit, orb) .. ")")
	assert(Seated(ns, "crestOrb") == orb and orb.spent:IsShown(), "while auras are secret the orb stays and the cooldown still empties it")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	orb = Seated(ns, "crestOrb")
	assert(orb and orb.spent:IsShown() and Lit(orb) == "10", "after the restriction the orb shows the spent cooldown and the proc that came up during it (" .. Lit(orb) .. ")")
	Clean(env, K)
end

-- Switched off, or under the Frames form, the orb steps aside and Arcane Power returns to the rail; Clearcasting keeps its
-- own ring either way, the orb adding its flood on top.
do
	local env, K, ns = New("MAGE", { known = ARCANE, before = function(_, K) K.Options.Write("ActionBars", "crestOrb", false) end })
	assert(not Seated(ns, "crestOrb"), "switched off, no orb shows")
	assert(Seats(ns):find(",power,", 1, true), "switched off, Arcane Power stands on the rail (" .. Seats(ns) .. ")")
	assert(select(2, Piece(ns, "crestClearcasting")), "switched off, Clearcasting has its ring again")
	K.Options.Write("ActionBars", "crestOrb", true)
	env.RunTimers()
	assert(Seated(ns, "crestOrb") and not Seats(ns):find(",power,", 1, true) and select(2, Piece(ns, "crestClearcasting")),
		"switched back on, the orb takes Arcane Power and Clearcasting keeps its ring")
	Clean(env, K)
	env, K, ns = New("MAGE", { known = ARCANE, frames = true })
	assert(not Seated(ns, "crestOrb") and not ns.SlabOrb.Held(), "the Frames form has no crest, so no orb")
	assert(select(2, Piece(ns, "crestClearcasting")), "under Frames, Clearcasting keeps its own row")
	Clean(env, K)
end

-- An orb that fails to build claims nothing: Arcane Power stays on the rail.
do
	local env, K, ns = New("MAGE", { known = ARCANE, before = function(_, K) K.Medallions.Identity = function() error("no race") end end })
	assert(not Seated(ns, "crestOrb") and not ns.SlabOrb.Held(), "no orb shows, so none is held")
	assert(Seats(ns):find(",power,", 1, true), "the rail keeps Arcane Power (" .. Seats(ns) .. ")")
	Clean(env, K)
end

print("actionbars crest orb ok")
