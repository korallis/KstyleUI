-- test-actionbars-crest-popoffs.lua: the crest's signature pop-offs (KstyleUI_ActionBars/SlabPopoffs.lua, the crest plan's Part 5 with the KSTY-97 amendment and its review): every class but the hunter has one or two, the mage's listed first, and the hunter none (its crest rail, SlabRail.lua, crowns Bestial Wrath and Deterrence while they run), each a known spell of Tools/data/abilities.json and none of the four the ledger could not confirm; each class's pop-offs take seats of their own or the overlay seat they were chosen for; each lights from its own aura on its own unit and no other, and goes when the aura goes; at Full the flare rises, at Calm it is still and at Off it is dark; the aura's end folds it at Full only, and Calm, Off, the crest coming to rest or the piece hiding stop a fold already running or waiting for its frame; Ice Block covers the emblem, Evocation's ticks loop into the mana gem at Full only, Divine Shield's fold shrinks into the Forbearance ring that lights from the debuff, Power Infusion also lights when the priest casts it on a target, focus or, in a party or raid, a member they have not selected, with the same flare, ring, late warning and shared fold, keeps lighting through target and focus changes, draws once for one ally reached through two names, keeps a missing member's slot hidden and listens only while it shows, arms its late warning from the aura events of the player, the target and every party or raid member, a late joiner included, hears no member after the group is gone, and, joined in combat or turned into a raid while auras are secret, keeps the variant built before, builds nothing protected and lights the new member once when the restriction lifts, and either rank of Nightfall builds Shadow Trance; the switch hides them; while auras are secret, from before combat until the restriction lifts, nothing touches the slots and an aura's end still folds.
local F = dofile("Tools/regression/crest_armory_fixture.lua")
local W = dofile("Tools/regression/widget_env.lua")
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

-- Each class's signature moments as the plan and its amendment name them, typed from Wowhead Forever: the spell a character knows,
-- the aura that lights the pop-off and the unit that carries it.
local SIGNATURES = {
	MAGE = { { art = "Crystal", known = 11958, aura = 11958 }, { art = "Vortex", known = 12051, aura = 12051 } },
	PALADIN = { { art = "Bubble", known = 642, aura = 642 }, { art = "Sun", known = 20216, aura = 20216 } },
	PRIEST = { { art = "Infusion", known = 10060, aura = 10060 }, { art = "Focus", known = 14751, aura = 14751 } },
	WARLOCK = { { art = "Void", known = 18094, aura = 17941 }, { art = "Curse", known = 18288, aura = 18288 } },
	DRUID = { { art = "Innervate", known = 29166, aura = 29166 }, { art = "Swift", known = 17116, aura = 17116 } },
	SHAMAN = { { art = "Bolt", known = 16164, aura = 16246 }, { art = "Swift", known = 16188, aura = 16188 } },
	WARRIOR = { { art = "Sweep", known = 12292, aura = 12292 } },
	ROGUE = { { art = "Veil", known = 1784, aura = 1784 } },
}

local function Pops(ns)
	local list = {}
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if p.spec.key == "crestPopoffs" then list[#list + 1] = p end
	end
	return list
end

local function Pop(ns, art)
	for _, p in ipairs(Pops(ns)) do
		if p.spec.art == art then return p end
	end
end

-- The lit of a piece whose aura container reads this unit.
local function On(p, unit, n)
	for _, lit in ipairs(p.lits) do
		if lit.container._unit == unit then
			n = (n or 1) - 1
			if n == 0 then return lit end
		end
	end
end

local function Motion(env, K, level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
end

local function Gain(env, unit, id, fields)
	local aura = { id = id, start = env._now, duration = 10 }
	for k, v in pairs(fields or {}) do aura[k] = v end
	Slots.Set(env, unit, { aura })
end

-- An aura's end: the engine hides its slot and stops the shown groups on it, and the fold waits a frame.
local function Gone(env, unit)
	Slots.Set(env, unit or "player", nil)
	env.RunTimers()
end

local function Finish(env)
	while W.FinishGroups(env) do end
end

-- The rows: the mage first, one or two each, none for the hunter (its crest rail owns its two moments), known spells of their own class, seats of their own.
do
	local _, _, ns = New("MAGE", {})
	local classes = ns.SlabPopoffs.CLASSES
	assert(#classes == 8 and classes[1][1] == "MAGE", "every class but the hunter has pop-offs, the mage's first")
	local seen = {}
	for _, entry in ipairs(classes) do
		local class, rows = entry[1], entry[2]
		assert(SIGNATURES[class] and not seen[class], class .. " is listed once")
		seen[class] = true
		assert(#rows == #SIGNATURES[class] and (#rows == 1 or #rows == 2), class .. " has one or two pop-offs")
		local seats = {}
		for i, row in ipairs(rows) do
			assert(row.crestOnly and row.feed == "aura" and row.key == "crestPopoffs", class .. ": a pop-off is a crest-only aura row behind its switch")
			assert(row.art == SIGNATURES[class][i].art, class .. ": pop-off " .. i .. " is " .. SIGNATURES[class][i].art)
			local seat = ns.SlabSeats.Name(row.seat)
			assert(seat and not seats[seat], class .. ": each pop-off has a named seat of its own")
			seats[seat] = true
			local owned = false
			for _, id in ipairs(row.known or row.spells) do
				owned = owned or OWNERS[id] == class
			end
			assert(owned, class .. ": " .. row.art .. " is known from a spell abilities.json gives the class")
			for _, id in ipairs(row.spells) do
				assert(not UNCONFIRMED[id], class .. " uses " .. tostring(UNCONFIRMED[id]) .. ", which no Forever source confirms")
			end
		end
	end
	assert(ns.SlabSeats.Name(classes[1][2][1].seat) == "emblem" and ns.SlabSeats.Name(classes[1][2][2].seat) == "perchRight", "Ice Block's shell sits over the emblem and Evocation over the mana gem's seat")
end

-- The hunter's two moments belong to its cooldown rail (SlabRail.lua), which crowns Bestial Wrath from the pet and Deterrence from the hunter
-- while they run: a hunter who knows both, with both auras up, builds no pop-off of its own.
do
	local henv, hK, hns = New("HUNTER", { 19574, 19263 })
	henv.SetTarget(true)
	henv.RunTimers()
	assert(hns.SlabRail.ABILITIES.wrath.spells[1] == 19574 and hns.SlabRail.ABILITIES.deter.spells[1] == 19263, "the rail carries Bestial Wrath and Deterrence")
	Gain(henv, "pet", 19574)
	Gain(henv, "player", 19263)
	assert(#Pops(hns) == 0, "the hunter builds no pop-off; the rail shows its moments")
	Clean(henv, hK, "hunter")
end

-- Every class: each pop-off lights from its own aura on its own unit and goes when it goes; another unit, another class's aura or another
-- pop-off's aura lights nothing.
for class, signatures in pairs(SIGNATURES) do
	local known = {}
	for _, s in ipairs(signatures) do known[#known + 1] = s.known end
	local cenv, cK, cns = New(class, known)
	cenv.SetTarget(true)
	cenv.RunTimers()
	assert(#Pops(cns) == #signatures, class .. ": every known pop-off is built")
	for _, line in ipairs(cns.SlabTrackers.state.forms.crest.refused) do
		assert(not line:find("crestPopoffs", 1, true), class .. ": " .. line)
	end
	for i, s in ipairs(signatures) do
		local p = assert(Pop(cns, s.art), class .. ": " .. s.art .. " is built")
		local unit, wrong = s.unit or "player", s.unit and "player" or "pet"
		Gain(cenv, wrong, s.aura)
		assert(not p.lits[1]:IsShown(), class .. ": " .. s.art .. "'s aura on the " .. wrong .. " lights nothing")
		Gone(cenv, wrong)
		Gain(cenv, unit, class == "ROGUE" and 11958 or 1784)
		assert(not p.lits[1]:IsShown(), class .. ": another class's aura lights nothing")
		local other = signatures[3 - i]
		if other then
			Gain(cenv, other.unit or "player", other.aura)
			assert(not p.lits[1]:IsShown(), class .. ": " .. other.art .. "'s aura does not light " .. s.art)
			Gone(cenv, other.unit or "player")
		end
		Gain(cenv, unit, s.aura)
		assert(p:IsVisible() and p.lits[1]:IsShown(), class .. ": " .. s.art .. " lights from its aura on the " .. unit)
		Gone(cenv, unit)
		assert(not p.lits[1]:IsShown(), class .. ": " .. s.art .. " goes when its aura goes")
		Finish(cenv)
	end
	Clean(cenv, cK, class)
end

-- A mage: nothing known, no pop-offs; Ice Block and Evocation known, both overlays, unlit until their auras.
local env, K, ns = New("MAGE", {})
env.SetTarget(true)
env.RunTimers()
assert(#Pops(ns) == 0, "an unknown spell's pop-off is never built")
env._known[11958], env._known[12051] = true, true
env.FireEvent("SPELLS_CHANGED")
env.RunTimers()
local block, evocation = Pop(ns, "Crystal"), Pop(ns, "Vortex")
assert(block and evocation and #Pops(ns) == 2, "Ice Block and Evocation each build a pop-off once known")
assert(#ns.SlabTrackers.state.forms.crest.refused == 0, "the overlays claim no seat, so no piece is refused")
local lit = block.lits[1]
assert(not lit:IsShown() and not block.fold:IsShown(), "with no aura the pop-off and its fold draw nothing")
local w = block:GetWidth()
assert(w >= 2 * evocation:GetWidth(), "the Ice Block shell is drawn round the emblem, wider than a seated pop-off")
local _, shellAt, _, sx, sy = block:GetPoint(1)
local _, gemAt, _, gx, gy = evocation:GetPoint(1)
assert(shellAt == gemAt and sx == 0 and sy == 0 and (gx ~= 0 or gy ~= 0), "the shell is centred on the emblem, where Evocation sits off it on the gem")

-- Full: the aura lights it, the flare plays in place over the emblem, the ring drains, and the end folds it.
local full = lit.flareGate.lit
local rise = full.flare.play
for _, a in ipairs(rise._anims) do
	assert(a._type ~= "Translation", "the Ice Block flare grows in place over the emblem, it does not travel")
end
Gain(env, "player", 11958)
assert(lit:IsShown() and rise:IsPlaying(), "at Full the aura lights the pop-off and its flare plays")
assert(AB.W.LastCall(lit._cooldown, "SetCooldownFromDurationObject"), "its ring drains with the aura")
local sheet = lit.auraLoops and lit.auraLoops[1]
assert(sheet and sheet:IsPlaying() and sheet:GetParent():GetTexture():find("Auras\\Popoffs\\Crystal.png", 1, true), "at Full its Blender sheet loops in the lit slot")
assert(next(block.ups) and not block.fold.play:IsPlaying(), "it is up and not folding")
Gone(env)
assert(not lit:IsShown() and block.fold:IsShown() and block.fold.play:IsPlaying(), "at Full the aura's end folds it")
Finish(env)
assert(not block.fold:IsShown(), "the fold hides its layer once it ends")
Clean(env, K, "full")

-- A fold already running stops when the player picks Calm or Off, and when the crest comes to rest.
for _, level in ipairs({ "calm", "off" }) do
	Gain(env, "player", 11958)
	Gone(env)
	assert(block.fold.play:IsPlaying(), level .. ": the fold runs at Full")
	Motion(env, K, level)
	assert(not block.fold.play:IsPlaying() and not block.fold:IsShown(), "picking " .. level .. " stops the running fold")
	Motion(env, K, "full")
	Finish(env)
end
Gain(env, "player", 11958)
Gone(env)
assert(block.fold.play:IsPlaying(), "the fold runs while the crest is awake")
env.SetTarget(false)
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(ns.Slab.Resting() and not block.fold.play:IsPlaying(), "the crest coming to rest stops the running fold")
Gain(env, "player", 11958)
Gone(env)
assert(not block.fold.play:IsPlaying(), "a resting crest does not fold")
env.SetTarget(true)
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
Finish(env)
Clean(env, K, "fold stops")

-- Evocation's ticks run into the mana gem from the crest at Full only.
local vlit = evocation.lits[1]
local ticks
for _, loop in ipairs(vlit.loops or {}) do
	ticks = loop:GetLooping() == "REPEAT" and loop or ticks
end
assert(ticks, "Evocation has a repeating tick")
local into = {}
for _, a in ipairs(ticks._anims) do
	if a._type == "Translation" then into[#into + 1] = { a:GetOffset() } end
end
local seat = evocation.spec.seat
assert(#into == 2 and into[1][1] == -into[2][1] and into[2][1] * seat[1] > 0 and into[2][2] * seat[2] > 0, "each tick starts toward the crest's middle and runs out into the gem's seat")
Gain(env, "player", 12051)
assert(vlit:IsShown() and Slots.Engine(env, function() return F.Lit(evocation) end), "Evocation lights")
assert(ticks:IsPlaying(), "at Full the ticks loop")
-- One tick every 2 s, as the plan's Evocation treatment says: the group's orders run one after another.
local ends = {}
for _, a in ipairs(ticks._anims) do
	local order = a:GetOrder()
	ends[order] = math.max(ends[order] or 0, a:GetDuration())
end
local period = 0
for _, d in pairs(ends) do period = period + d end
assert(math.abs(period - 2) < 0.001, "a tick runs every 2 s (" .. period .. ")")
Gone(env)
assert(not vlit:IsShown() and not ticks:IsPlaying(), "the channel's end stops the ticks")
Finish(env)
for _, level in ipairs({ "calm", "off" }) do
	Motion(env, K, level)
	Gain(env, "player", 12051)
	-- Calm and Off show the twin faces whose hold layer the engine lights; the Full face keeps its loop but stays dark.
	local looping = false
	for _, face in ipairs({ evocation, unpack(evocation.twins or {}) }) do
		local loop, alpha, node = face.lits[1].loops and face.lits[1].loops[#face.lits[1].loops], 1, face.lits[1].hold
		while node do
			alpha, node = alpha * node:GetAlpha(), node:GetParent()
		end
		looping = looping or loop ~= nil and loop:IsPlaying() and alpha > 0
	end
	assert(not looping and vlit:IsShown(), "at " .. level .. " Evocation lights and no shown face loops its ticks")
	Gone(env)
	Motion(env, K, "full")
	Finish(env)
end
Clean(env, K, "evocation")

-- Calm: the still flare and no fold.
Motion(env, K, "calm")
Gain(env, "player", 11958)
assert(full.full == "calm" and full.flare.still and full.flare.still:IsPlaying() and not rise:IsPlaying(), "at Calm the pop-off shows the still flare")
assert(lit:IsShown() and not sheet:IsPlaying(), "and lights, its Blender sheet held on its first frame")
Gone(env)
assert(not block.fold.play:IsPlaying(), "at Calm the end does not fold")
Clean(env, K, "calm")

-- Off: the end state only.
Motion(env, K, "off")
full.flare.still:Stop()
Gain(env, "player", 11958)
assert(lit:IsShown() and lit.flareGate:GetAlpha() == 0 and lit.flareGate.other:GetAlpha() == 0, "at Off the pop-off lights and both flare layers stay dark")
Gone(env)
assert(not block.fold.play:IsPlaying(), "at Off the end does not fold")
Motion(env, K, "full")
Finish(env)
Clean(env, K, "off")

-- Secret auras: a boss pull turns auras secret before combat starts. An aura gained before stays lit by the engine, its end while still
-- secret folds the pop-off's own frame without touching the slot, and once combat ends and the restriction lifts it rises again.
Gain(env, "player", 11958)
assert(lit:IsShown() and rise:IsPlaying(), "lit before the restriction")
env._aurasSecret = true
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
env.RunTimers()
assert(Slots.Engine(env, function() return lit:IsShown() end), "secret before combat, the engine keeps the pop-off lit")
env.SetCombat(true)
K.Options.Write("Medallions", "motion", "calm")
K.Options.Write("Medallions", "motion", "full")
ns.SlabMedals.Rest()
Gone(env)
assert(Slots.Engine(env, function() return not lit:IsShown() end), "secret, the engine hides the pop-off when its aura ends")
assert(block.fold.play:IsPlaying(), "secret, the aura's end still folds the pop-off's own frame")
Finish(env)
Clean(env, K, "secret")
env.SetCombat(false)
env._aurasSecret = false
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
env.RunTimers()
Gain(env, "player", 11958)
assert(lit:IsShown() and rise:IsPlaying(), "when the restriction ends the pop-off rises again")
Gone(env)
Finish(env)
Clean(env, K, "after the restriction")

-- The switch hides every pop-off, and a hidden one never folds.
K.Options.Write("ActionBars", "crestPopoffs", false)
env.RunTimers()
assert(not block:IsShown() and not evocation:IsShown(), "the switch hides the pop-offs")
Gain(env, "player", 11958)
Gone(env)
assert(not block.fold.play:IsPlaying(), "a hidden pop-off never folds")
K.Options.Write("ActionBars", "crestPopoffs", true)
env.RunTimers()
assert(block:IsShown() and evocation:IsShown(), "and turning it back on shows them again")
Finish(env)

-- Hiding a pop-off, by its switch or by a style that has no crest, stops a running fold and a fold that waits for the next frame,
-- so neither plays when the pop-off shows again. The stub does not run OnHide when a frame stops being visible; the game does.
local function Hid(frame)
	assert(not frame:IsVisible(), "the pop-off is hidden")
	local fn = frame:GetScript("OnHide")
	if fn then fn(frame) end
end
local function Show(write)
	write(true)
	env.RunTimers()
	assert(block:IsVisible(), "the pop-off shows again")
	Finish(env)
end
for what, write in pairs({
	switch = function(on) K.Options.Write("ActionBars", "crestPopoffs", on) end,
	style = function(on) K.Options.Write("HudStyle", "style", on and "medallions" or "frames") end,
}) do
	Gain(env, "player", 11958)
	Gone(env)
	assert(block.fold.play:IsPlaying(), what .. ": the fold runs")
	write(false)
	env.RunTimers()
	Hid(block)
	assert(not block.fold.play:IsPlaying() and not block.fold:IsShown(), what .. ": hiding the pop-off stops its running fold")
	Show(write)
	Gain(env, "player", 11958)
	Slots.Set(env, "player", nil)
	write(false)
	Hid(block)
	write(true)
	env.RunTimers()
	assert(not block.fold.play:IsPlaying() and not block.fold:IsShown(), what .. ": a fold that waited for the next frame does not play once the pop-off was hidden")
	Finish(env)
end
-- In the game the switch hides the pop-off before its slots are disabled, so the slot's watch stops after the pop-off's OnHide; the stub
-- disables the slots first, so the test hides the piece and then stops the watch the way the disabled slot does. It schedules nothing,
-- and no fold plays when the pop-off shows again before the next frame.
Gain(env, "player", 11958)
block:Hide()
Hid(block)
lit.watch:Stop()
assert(not block.settling, "an aura that ends on a hidden pop-off schedules no fold")
block:Show()
env.RunTimers()
assert(not block.fold.play:IsPlaying() and not block.fold:IsShown(), "and none plays when it shows again before the next frame")
Gone(env)
Finish(env)
-- Calm, then Full again, before the fold's frame: the waiting fold is dropped.
for _, level in ipairs({ "calm", "off" }) do
	Gain(env, "player", 11958)
	Slots.Set(env, "player", nil)
	assert(block.settling, level .. ": the aura's end waits a frame to fold")
	K.Options.Write("Medallions", "motion", level)
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	assert(not block.fold.play:IsPlaying() and not block.fold:IsShown(), level .. ": a fold waiting for its frame is dropped when the motion level drops, even if Full returns first")
	Finish(env)
end
Clean(env, K, "switch")

-- The paladin's Divine Shield folds into the Forbearance ring, which lights from the debuff on the paladin and not on the target.
do
	local penv, pK, pns = New("PALADIN", { 642 })
	penv.SetTarget(true)
	penv.RunTimers()
	local shield = assert(Pop(pns, "Bubble"), "Divine Shield builds once known")
	local forbearance = assert(On(shield, "player", 2), "Divine Shield carries a second slot on the paladin")
	local grow
	for _, a in ipairs(shield.fold.play._anims) do
		if a._type == "Scale" then grow = select(1, a:GetScaleTo()) end
	end
	assert(grow and grow < 1, "the shield's fold shrinks")
	Gain(penv, "target", 25771, { harmful = true })
	assert(not forbearance:IsShown(), "Forbearance on the target lights nothing")
	Slots.Set(penv, "target", nil)
	Slots.Set(penv, "player", { { id = 642, start = penv._now, duration = 12 }, { id = 25771, start = penv._now, duration = 60, harmful = true } })
	assert(shield.lits[1]:IsShown() and forbearance:IsShown(), "the shield and the Forbearance ring light together")
	Slots.Set(penv, "player", { { id = 25771, start = penv._now, duration = 60, harmful = true } })
	penv.RunTimers()
	assert(not shield.lits[1]:IsShown() and forbearance:IsShown() and shield.fold.play:IsPlaying(), "the shield folds into the ring, which stays while Forbearance lasts")
	assert(AB.W.LastCall(forbearance._cooldown, "SetCooldownFromDurationObject"), "the ring drains with Forbearance")
	Gone(penv)
	assert(not forbearance:IsShown(), "and goes when Forbearance does")
	Clean(penv, pK, "paladin")
end

-- The priest's Power Infusion on the target or focus, only from the priest's own cast, gets the display it gets on the priest: its
-- flare rises, its ring and late warning drain with it, and its end folds the one pop-off; a recipient two units name draws once.
local function Seen(region, root)
	local alpha = 1
	while region and region ~= root do
		alpha = alpha * region:GetAlpha()
		region = region:GetParent()
	end
	return alpha
end

local function Drains(slot)
	local n = 0
	for _, m in ipairs(slot.mirrors or {}) do
		if m:IsShown() and m._cooldown and AB.W.LastCall(m._cooldown, "SetCooldownFromDurationObject") then n = n + 1 end
	end
	return n
end

do
	local renv, rK, rns = New("PRIEST", { 10060 })
	local same = {}
	renv.UnitIsUnit = function(a, b) return a == b or same[a .. "=" .. b] or same[b .. "=" .. a] or false end
	renv.SetTarget(true)
	renv.FireEvent("PLAYER_FOCUS_CHANGED")
	renv.RunTimers()
	local infusion = assert(Pop(rns, "Infusion"), "Power Infusion builds once known")
	local self = infusion.lits[1]
	Gain(renv, "player", 10060)
	local warned = Drains(self)
	assert(self:IsShown() and self.flareGate.lit.flare.play:IsPlaying() and warned > 0, "on the priest the flare rises and the late warning drains")
	Gone(renv)
	Finish(renv)
	for _, unit in ipairs({ "target", "focus" }) do
		local ally = assert(On(infusion, unit), "Power Infusion has a slot on the " .. unit)
		Gain(renv, unit, 10060, { mine = false })
		assert(not ally:IsShown(), "another priest's Power Infusion on the " .. unit .. " lights nothing")
		Gain(renv, unit, 10060, { mine = true })
		assert(ally:IsShown() and not self:IsShown(), "the priest's own Power Infusion on the " .. unit .. " lights its slot")
		assert(ally:IsVisible() and Seen(ally, infusion) == 1, "a " .. unit .. " who is someone else draws")
		assert(ally.flareGate and ally.flareGate.lit.flare.play:IsPlaying(), "on the " .. unit .. " the flare rises as it does on the priest")
		assert(AB.W.LastCall(ally._cooldown, "SetCooldownFromDurationObject") and Drains(ally) == warned, "on the " .. unit .. " the ring and the late warning drain with it")
		assert(next(infusion.ups) and not infusion.fold.play:IsPlaying(), "it is up and not folding")
		Slots.Set(renv, unit, nil)
		renv.RunTimers()
		assert(not ally:IsShown() and infusion.fold.play:IsPlaying(), "its end on the " .. unit .. " folds the pop-off")
		Finish(renv)
	end
	-- The priest targeting themself: the target's slot lights beside the priest's own, and only one draws.
	local target, focus = On(infusion, "target"), On(infusion, "focus")
	same["target=player"] = true
	renv.FireEvent("PLAYER_TARGET_CHANGED")
	Gain(renv, "player", 10060)
	Gain(renv, "target", 10060, { mine = true })
	assert(self:IsVisible() and target:IsShown() and not target:IsVisible(), "a target who is the priest draws once")
	-- The focus who is also the target, with the comparison secret: the engine applies the secret answer, and the focus slot draws nothing.
	same["target=player"] = nil
	local secret = renv.Secret(true)
	same["focus=target"] = secret
	renv.FireEvent("PLAYER_TARGET_CHANGED")
	Gain(renv, "focus", 10060, { mine = true })
	local gated
	for frame in function(_, f) return f ~= infusion and f:GetParent() or nil end, nil, focus do
		local call = frame._state.AlphaFromBoolean
		gated = gated or call and call[1] == secret and call[2] == 0 and call[3] == 1
	end
	assert(target:IsVisible() and Seen(target, infusion) == 1 and focus:IsVisible() and gated, "a focus who is the target draws once")
	same["focus=target"] = nil
	renv.FireEvent("PLAYER_FOCUS_CHANGED")
	assert(focus:IsVisible() and Seen(focus, infusion) == 1, "a new focus draws again")
	Clean(renv, rK, "priest")
end

-- Power Infusion's chosen reach (the crest plan's review): a party or raid member the priest has not selected, such as one healed by a click-cast,
-- lights the same pop-off; it stays through target and focus changes; a member who is also the target, the focus or the priest
-- draws once; a member who is not there watches nothing; and the pop-off listens for identity and roster changes only while shown.
local function Shown(from, art)
	for _, p in ipairs(Pops(from)) do
		if p.spec.art == art and p:IsShown() then return p end
	end
end

local function Listeners(at, event)
	local n = 0
	for _, f in ipairs(at._frames) do
		if f._events[event] then n = n + 1 end
	end
	return n
end

-- An aura gain as the client delivers it: the slots update and UNIT_AURA fires for that unit only, read back through
-- C_UnitAuras (Slots.Readings).
local function Aura(at, unit, id, fields)
	local aura = { id = id, start = at._now, duration = 10 }
	for k, v in pairs(fields or {}) do aura[k] = v end
	Slots.Deliver(at, unit, { aura })
end

-- Whether some frame hears UNIT_AURA for this unit.
local function Hears(at, unit)
	for _, f in ipairs(at._frames) do
		local units = f._events.UNIT_AURA
		for _, each in ipairs(type(units) == "table" and units or {}) do
			if each == unit then return true end
		end
	end
	return false
end

-- Whether the late warning of this pop-off's slot for unit is armed on the aura that started now.
local function Warned(at, own, variant, unit)
	for _, e in ipairs(own.SlabRings.state.watched) do
		if e.unit == unit and (e.piece.top or e.piece) == variant and e.late then
			return e.late.start == at._now and e.late.show:IsPlaying()
		end
	end
	return false
end

do
	local genv, gK, gns = New("PRIEST", { 10060 })
	local same, members, raid = {}, {}, false
	genv.UnitIsUnit = function(a, b) return a == b or same[a .. "=" .. b] or same[b .. "=" .. a] or false end
	genv.IsInGroup = function() return next(members) ~= nil end
	genv.IsInRaid = function() return raid end
	local exists = genv.UnitExists
	genv.UnitExists = function(unit) return members[unit] == true or exists(unit) end
	Slots.Readings(genv)
	genv.SetTarget(true)
	genv.RunTimers()
	local solo = assert(Shown(gns, "Infusion"), "Power Infusion builds once known")
	assert(not On(solo, "party1") and not On(solo, "raid1"), "a priest on their own watches no party or raid member")
	Aura(genv, "player", 10060)
	Aura(genv, "target", 10060, { mine = true })
	assert(Warned(genv, gns, solo, "player") and Warned(genv, gns, solo, "target"), "on their own the priest's and the target's Power Infusion arm their late warnings")
	members.party1, members.party2 = true, true
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	genv.RunTimers()
	local party = assert(Shown(gns, "Infusion"), "in a party the pop-off shows")
	assert(party ~= solo and not solo:IsShown() and On(party, "party4") and not On(party, "raid1"), "in a party the pop-off watches the four party members")
	local p2, p3 = On(party, "party2"), On(party, "party3")
	local host = p3:GetParent()
	while host and not (host.unit == "party3" and host.other == nil) do host = host:GetParent() end
	assert(host and not host:IsShown() and not p3:IsVisible(), "a party member who is not there keeps their slot hidden, so it reads no auras")
	members.party3 = true
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	assert(host:IsShown(), "and joining shows it")
	members.party3 = nil
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	assert(not host:IsShown(), "and leaving hides it again")
	members.party4 = true
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	Aura(genv, "party4", 10060, { mine = true })
	assert(On(party, "party4"):IsVisible() and Warned(genv, gns, party, "party4"), "the last party member, joining after the party formed, lights and arms its late warning")
	Aura(genv, "player", 10060)
	Aura(genv, "target", 10060, { mine = true })
	assert(Warned(genv, gns, party, "player") and Warned(genv, gns, party, "target"), "in a party the priest's and the target's late warnings still arm")
	-- Selecting a buffed member moves their buff to the target's slot and back with no aura event, so the slot that shows takes over
	-- the late warning from the one the selection hid.
	members.party2 = true
	Aura(genv, "party2", 10060, { mine = true })
	assert(Warned(genv, gns, party, "party2"), "the priest's Power Infusion on a party member arms its late warning")
	same["target=party2"] = true
	Slots.Set(genv, "target", genv._slotAuras.party2)
	genv.SetTarget(true)
	assert(On(party, "target"):IsVisible() and not On(party, "party2"):IsVisible() and Warned(genv, gns, party, "target"), "targeting that member hands the warning to the target's slot")
	same["target=party2"] = nil
	Slots.Set(genv, "target", nil)
	genv.SetTarget(true)
	assert(On(party, "party2"):IsVisible() and Warned(genv, gns, party, "party2"), "targeting someone else hands it back to the member's own slot")
	same["focus=party2"] = true
	Slots.Set(genv, "focus", genv._slotAuras.party2)
	genv.FireEvent("PLAYER_FOCUS_CHANGED")
	assert(On(party, "focus"):IsVisible() and not On(party, "party2"):IsVisible() and Warned(genv, gns, party, "focus"), "focusing that member hands the warning to the focus's slot")
	same["focus=party2"] = nil
	Slots.Set(genv, "focus", nil)
	genv.FireEvent("PLAYER_FOCUS_CHANGED")
	assert(On(party, "party2"):IsVisible() and Warned(genv, gns, party, "party2"), "and clearing the focus hands it back")
	Slots.Set(genv, "party2", nil)
	members.party4 = nil
	Slots.Set(genv, "party4", nil)
	Slots.Set(genv, "player", nil)
	Slots.Set(genv, "target", nil)
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	genv.RunTimers()
	Finish(genv)
	Gain(genv, "party2", 10060, { mine = false })
	assert(not p2:IsShown(), "another priest's Power Infusion on a party member lights nothing")
	Gain(genv, "party2", 10060, { mine = true })
	assert(p2:IsVisible() and Seen(p2, party) == 1 and p2.flareGate.lit.flare.play:IsPlaying(), "the priest's Power Infusion on a party member they have not selected lights and rises")
	assert(Drains(p2) > 0, "and its ring and late warning drain")
	genv.SetTarget(false)
	genv.FireEvent("PLAYER_FOCUS_CHANGED")
	assert(p2:IsVisible() and Seen(p2, party) == 1, "it stays lit through target and focus changes")
	same["target=party2"] = true
	genv.SetTarget(true)
	Gain(genv, "target", 10060, { mine = true })
	local target = On(party, "target")
	assert(target:IsVisible() and p2:IsShown() and not p2:IsVisible(), "a party member who is the target draws once")
	same["target=party2"] = nil
	genv.SetTarget(true)
	Slots.Set(genv, "target", nil)
	genv.RunTimers()
	assert(p2:IsVisible() and not party.fold.play:IsPlaying(), "a new target leaves the party member's pop-off drawn and unfolded")
	Slots.Set(genv, "party2", nil)
	genv.RunTimers()
	assert(party.fold.play:IsPlaying(), "its end on the party member folds the pop-off")
	Finish(genv)
	raid, members.raid1, members.raid5 = true, true, true
	same["raid1=player"] = true
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	genv.RunTimers()
	local band = assert(Shown(gns, "Infusion"), "in a raid the pop-off shows")
	assert(band ~= party and On(band, "raid40") and not On(band, "party1"), "in a raid it watches the forty raid members")
	local r1, r5 = On(band, "raid1"), On(band, "raid5")
	Aura(genv, "raid5", 10060, { mine = true })
	assert(r5:IsVisible() and Seen(r5, band) == 1, "the priest's Power Infusion on a raid member lights")
	Aura(genv, "player", 10060)
	Gain(genv, "raid1", 10060, { mine = true })
	assert(band.lits[1]:IsVisible() and r1:IsShown() and not r1:IsVisible(), "the raid member who is the priest draws once")
	assert(Warned(genv, gns, band, "player") and Warned(genv, gns, band, "raid5"), "in a raid the priest's and a raid member's late warnings arm")
	members.raid37 = true
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	Aura(genv, "raid37", 10060, { mine = true })
	assert(On(band, "raid37"):IsVisible() and Warned(genv, gns, band, "raid37"), "a raid member late in the raid's order, joining after it formed, lights and arms its late warning")
	Aura(genv, "target", 10060, { mine = true })
	assert(Warned(genv, gns, band, "target"), "and the target's late warning still arms")
	local on = Listeners(genv, "GROUP_ROSTER_UPDATE")
	assert(on > 0 and Listeners(genv, "PLAYER_FOCUS_CHANGED") > 0, "a shown Power Infusion pop-off listens for roster and identity changes")
	gK.Options.Write("ActionBars", "crestPopoffs", false)
	genv.RunTimers()
	Hid(band)
	assert(Listeners(genv, "GROUP_ROSTER_UPDATE") == on - 1, "switched off it stops listening")
	same["raid1=player"] = nil
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	local mine = r1
	while mine and mine.other ~= "player" do mine = mine:GetParent() end
	assert(mine and not mine:IsShown(), "a hidden pop-off does not notice a changed raid")
	gK.Options.Write("ActionBars", "crestPopoffs", true)
	genv.RunTimers()
	assert(Listeners(genv, "GROUP_ROSTER_UPDATE") == on and r1:IsVisible(), "shown again it listens and reads the raid afresh")
	raid, members = false, {}
	for _, unit in ipairs({ "player", "target", "raid1", "raid5", "raid37" }) do Slots.Set(genv, unit, nil) end
	genv.FireEvent("GROUP_ROSTER_UPDATE")
	genv.RunTimers()
	Finish(genv)
	assert(Shown(gns, "Infusion") == solo, "leaving the raid brings back the priest's own pop-off")
	Aura(genv, "player", 10060)
	Aura(genv, "target", 10060, { mine = true })
	assert(Warned(genv, gns, solo, "player") and Warned(genv, gns, solo, "target"), "after leaving the priest's and the target's late warnings arm again")
	assert(not Hears(genv, "raid37") and not Hears(genv, "party4"), "and no raid or party member's auras are heard while the priest's own pop-off shows")
	Clean(genv, gK, "group priest")
end

-- Joining a group in combat, or turning a party into a raid while auras are secret, builds nothing then: the pop-off already built
-- keeps watching who it watched (on their own the priest, the target and the focus; in a party the party), each ally draws once, and
-- once the lock lifts the group's own pop-off builds and an unselected member lights with its late warning.
do
	local lenv, lK, lns = New("PRIEST", { 10060 })
	local members, raid = {}, false
	lenv.UnitIsUnit = function(a, b) return a == b end
	lenv.IsInGroup = function() return next(members) ~= nil end
	lenv.IsInRaid = function() return raid end
	local exists = lenv.UnitExists
	lenv.UnitExists = function(unit) return members[unit] == true or exists(unit) end
	Slots.Readings(lenv)
	lenv.SetTarget(true)
	lenv.RunTimers()
	local solo = assert(Shown(lns, "Infusion"), "Power Infusion builds once known")
	local built = #Pops(lns)
	lenv.SetCombat(true)
	members.party1 = true
	lenv.FireEvent("GROUP_ROSTER_UPDATE")
	lenv.RunTimers()
	assert(#Pops(lns) == built and Shown(lns, "Infusion") == solo, "joining a party in combat builds nothing and keeps the priest's own pop-off")
	Aura(lenv, "target", 10060, { mine = true })
	assert(On(solo, "target"):IsVisible() and Seen(On(solo, "target"), solo) == 1, "meanwhile the target's Power Infusion draws once")
	Slots.Set(lenv, "target", nil)
	lenv.SetCombat(false)
	lenv.RunTimers()
	Finish(lenv)
	local party = assert(Shown(lns, "Infusion"), "out of combat the pop-off shows")
	assert(party ~= solo and On(party, "party1"), "and the party's own pop-off builds")
	Aura(lenv, "party1", 10060, { mine = true })
	assert(On(party, "party1"):IsVisible() and Seen(On(party, "party1"), party) == 1 and Warned(lenv, lns, party, "party1"), "a party member not selected lights once with its warning")
	Slots.Set(lenv, "party1", nil)
	lenv.RunTimers()
	Finish(lenv)
	built = #Pops(lns)
	lenv._aurasSecret = true
	lenv.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	raid, members.raid12 = true, true
	lenv.FireEvent("GROUP_ROSTER_UPDATE")
	lenv.RunTimers()
	assert(#Pops(lns) == built and Shown(lns, "Infusion") == party, "turning into a raid while auras are secret builds nothing and keeps the party's pop-off")
	lenv._aurasSecret = false
	lenv.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	lenv.RunTimers()
	local band = assert(Shown(lns, "Infusion"), "once the restriction lifts the pop-off shows")
	assert(band ~= party and On(band, "raid40"), "and the raid's own pop-off builds")
	Aura(lenv, "raid12", 10060, { mine = true })
	assert(On(band, "raid12"):IsVisible() and Seen(On(band, "raid12"), band) == 1 and Warned(lenv, lns, band, "raid12"), "a raid member not selected lights once with its warning")
	Clean(lenv, lK, "locked roster")
end

-- A warlock who knows only the second rank of Nightfall still builds Shadow Trance's pop-off.
do
	local lenv, lK, lns = New("WARLOCK", { 18095 })
	lenv.SetTarget(true)
	lenv.RunTimers()
	local void = assert(Pop(lns, "Void"), "Nightfall rank 2 alone builds Shadow Trance's pop-off")
	Gain(lenv, "player", 17941)
	assert(void.lits[1]:IsShown(), "Shadow Trance lights it")
	Clean(lenv, lK, "warlock")
end

print("test-actionbars-crest-popoffs: ok")
