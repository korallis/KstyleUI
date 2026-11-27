-- test-actionbars-crest-popoffs.lua: the crest's signature pop-offs (KstyleUI_ActionBars/SlabPopoffs.lua, the crest plan's Part 5 with the KSTY-97 amendment): every class has one or two, each a known spell of Tools/data/abilities.json and none of the four the ledger could not confirm; each claims its own seat on the crest's shoulders; its aura lights it from the engine's own slot, which at Full plays the rising flare, at Calm the still flare and at Off no flare; the aura's end folds it at Full only; the switch hides them; while auras are secret nothing touches the slot and the fold still plays.
local F = dofile("Tools/regression/crest_armory_fixture.lua")
local AB, Slots, New, Clean = F.AB, F.Slots, F.New, F.Clean

local function Load(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

-- The spell ids Tools/data/abilities.json lists, each with its owning class.
local OWNERS = {}
for id, owner in Load("Tools/data/abilities.json"):gmatch('"id": (%d+),%s*"name": "[^"]*",%s*"subtext": "[^"]*",%s*"category": "[^"]*",%s*"owner": "(%u+)"') do
	OWNERS[tonumber(id)] = owner
end
assert(OWNERS[11958] == "MAGE" and OWNERS[19574] == "HUNTER", "abilities.json reads as the build's spell list")

-- The four plan candidates the crest needs ledger found no Forever source for: Avenging Wrath, Readiness, Shadowfiend, Metamorphosis.
local UNCONFIRMED = { [407788] = "Avenging Wrath", [23989] = "Readiness", [401977] = "Shadowfiend", [403789] = "Metamorphosis" }
local ORDER = { "MAGE", "HUNTER", "PALADIN", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "WARRIOR", "ROGUE" }

local function Pops(ns)
	local list = {}
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if p.spec.key == "crestPopoffs" then list[#list + 1] = p end
	end
	table.sort(list, function(a, b) return a.spec.art < b.spec.art end)
	return list
end

local function Pop(ns, art)
	for _, p in ipairs(Pops(ns)) do
		if p.spec.art == art then return p end
	end
end

-- The game runs a slot's shown groups' OnStop when it hides the slot; the stub does not, so the tests run it, then the frame after.
local function Gone(env, p, unit)
	Slots.Set(env, unit or "player", nil)
	p.watch._scripts.OnStop(p.watch)
	env.RunTimers()
end

local function Motion(env, K, level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
end

-- Each class's rows, in the goal's order: the mage first, then the hunter, then the rest.
do
	local _, _, ns = New("MAGE", {})
	local classes = ns.SlabPopoffs.CLASSES
	assert(#classes == 9, "all nine classes have pop-offs")
	for i, entry in ipairs(classes) do
		local class, rows = entry[1], entry[2]
		assert(class == ORDER[i], "pop-offs are listed mage first, then hunter, then the rest")
		assert(#rows == 1 or #rows == 2, class .. " has one or two pop-offs")
		local seats = {}
		for _, row in ipairs(rows) do
			assert(row.crestOnly and row.feed == "aura" and row.key == "crestPopoffs", class .. ": a pop-off is a crest-only aura row behind its switch")
			local seat = ns.SlabSeats.Name(row.seat)
			assert(seat and seat:find("^pop") and not seats[seat], class .. ": each pop-off has a pop seat of its own")
			seats[seat] = true
			for _, id in ipairs(row.known or row.spells) do
				assert(OWNERS[id] == class, class .. ": pop-off spell " .. id .. " is the class's own spell in abilities.json")
			end
			for _, id in ipairs(row.spells) do
				assert(not UNCONFIRMED[id], class .. " uses " .. tostring(UNCONFIRMED[id]) .. ", which no Forever source confirms")
			end
		end
	end
end

-- A mage: nothing known, no pop-offs; Ice Block and Evocation known, both seated over the crest, unlit until their auras.
local env, K, ns = New("MAGE", {})
env.SetTarget(true)
env.RunTimers()
assert(#Pops(ns) == 0, "an unknown spell's pop-off is never built")
env._known[11958], env._known[12051] = true, true
env.FireEvent("SPELLS_CHANGED")
env.RunTimers()
local block, evocation = Pop(ns, "Crystal"), Pop(ns, "Vortex")
assert(block and evocation and #Pops(ns) == 2, "Ice Block and Evocation each build a pop-off once known")
local form = ns.SlabTrackers.state.forms.crest
local claimed = {}
for seat, key in pairs(form.claims) do
	if key == "crestPopoffs" then claimed[#claimed + 1] = seat end
end
table.sort(claimed)
assert(#claimed == 2 and claimed[1] == "popLeft" and claimed[2] == "popRight" and #form.refused == 0, "they claim the pop seats beside each other, and no piece is refused")
local lit = block.lits[1]
assert(not lit:IsShown(), "with no aura the pop-off shows nothing")

-- Full: the aura lights it, the rising flare plays from below the seat, the ring drains, and the end folds it.
local full = lit.flareGate.lit
local rise = full.flare.play
local moves = {}
for _, a in ipairs(rise._anims) do
	if a._type == "Translation" then moves[#moves + 1] = select(2, a:GetOffset()) end
end
assert(#moves == 2 and moves[1] == -moves[2] and moves[2] > 0, "the Full flare drops below the seat and rises back into it")
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
assert(lit:IsShown() and rise:IsPlaying(), "at Full the aura lights the pop-off and its flare rises off the crest")
assert(AB.W.LastCall(lit._cooldown, "SetCooldownFromDurationObject"), "its ring drains with the aura")
assert(block.up and not block.fold.play:IsPlaying(), "it is up and not folding")
Gone(env, block)
assert(not lit:IsShown() and block.fold.play:IsPlaying(), "at Full the aura's end folds it")
Clean(env, K, "full")

-- Calm: the still flare and no rise or fold.
Motion(env, K, "calm")
block.fold.play:Stop()
assert(full.full == "calm", "at Calm the flare's first slot holds its still")
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
assert(full.flare.still and full.flare.still:IsPlaying() and not rise:IsPlaying(), "at Calm the pop-off shows the still flare, no rise")
assert(lit:IsShown(), "and lights")
Gone(env, block)
assert(not block.fold.play:IsPlaying(), "at Calm the end does not fold")
Clean(env, K, "calm")

-- Off: the end state only.
Motion(env, K, "off")
full.flare.still:Stop()
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
-- The engine keeps both flare slots bound at every level, so a level change in combat needs no Lua; at Off their layers are dark.
assert(lit:IsShown() and lit.flareGate:GetAlpha() == 0 and lit.flareGate.other:GetAlpha() == 0, "at Off the pop-off lights and both flare layers stay dark")
Gone(env, block)
assert(not block.fold.play:IsPlaying(), "at Off the end does not fold")
Clean(env, K, "off")

-- Secret auras: a boss pull turns auras secret before combat; the engine still lights the slot, Lua touches nothing under it, and the fold still plays.
Motion(env, K, "full")
env._aurasSecret = true
env.SetCombat(true)
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
K.Options.Write("Medallions", "motion", "calm")
K.Options.Write("Medallions", "motion", "full")
ns.SlabMedals.Rest()
assert(Slots.Engine(env, function() return lit:IsShown() end), "secret, the engine lights the pop-off")
Gone(env, block)
assert(block.fold.play:IsPlaying(), "secret, the aura's end still folds the pop-off's own frame")
Clean(env, K, "secret")
env._aurasSecret = false
env.SetCombat(false)
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
env.RunTimers()
block.fold.play:Stop()
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
assert(lit:IsShown() and rise:IsPlaying(), "when the restriction ends the pop-off rises again")
Gone(env, block)
Clean(env, K, "after the restriction")

-- The switch hides every pop-off.
K.Options.Write("ActionBars", "crestPopoffs", false)
env.RunTimers()
assert(not block:IsShown() and not evocation:IsShown(), "the switch hides the pop-offs")
block.fold.play:Stop()
Slots.Set(env, "player", { { id = 11958, start = 0, duration = 10 } })
Gone(env, block)
assert(not block.fold.play:IsPlaying(), "a hidden pop-off never folds")
K.Options.Write("ActionBars", "crestPopoffs", true)
env.RunTimers()
assert(block:IsShown() and evocation:IsShown(), "and turning it back on shows them again")
Clean(env, K, "switch")

-- The hunter's Bestial Wrath burns on the pet.
do
	local henv, hK, hns = New("HUNTER", { 19574, 19263 })
	henv.SetTarget(true)
	henv.RunTimers()
	local wrath = Pop(hns, "Paw")
	assert(wrath and Pop(hns, "Deflect"), "Bestial Wrath and Deterrence build once known")
	Slots.Set(henv, "player", { { id = 19574, start = 0, duration = 18 } })
	assert(not wrath.lits[1]:IsShown(), "Bestial Wrath on the hunter lights nothing")
	Slots.Set(henv, "pet", { { id = 19574, start = 0, duration = 18 } })
	assert(wrath.lits[1]:IsShown(), "Bestial Wrath lights from the pet")
	Clean(henv, hK, "hunter")
end

-- Every class with every pop-off known: each is built, seated without a refusal, and lights from its own aura.
for _, entry in ipairs(ns.SlabPopoffs.CLASSES) do
	local class, rows = entry[1], entry[2]
	local known = {}
	for _, row in ipairs(rows) do
		for _, id in ipairs(row.known or row.spells) do known[#known + 1] = id end
	end
	local cenv, cK, cns = New(class, known)
	cenv.SetTarget(true)
	cenv.RunTimers()
	local pops = Pops(cns)
	assert(#pops == #rows, class .. ": every known pop-off is built")
	for _, line in ipairs(cns.SlabTrackers.state.forms.crest.refused) do
		assert(not line:find("crestPopoffs", 1, true) and not line:find(" pop", 1, true), class .. ": " .. line)
	end
	for _, row in ipairs(rows) do
		local p = Pop(cns, row.art)
		Slots.Set(cenv, row.unit or "player", { { id = row.spells[1], start = 0, duration = 10 } })
		assert(p:IsVisible() and p.lits[1]:IsShown(), class .. ": " .. row.art .. " lights from its aura")
		Slots.Set(cenv, row.unit or "player", nil)
	end
	Clean(cenv, cK, class)
end

print("test-actionbars-crest-popoffs: ok")
