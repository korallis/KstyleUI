-- test-actionbars-crest-ranged.lua: a hunter's, mage's and warlock's crest trackers (KstyleUI_ActionBars/SlabRanged.lua) through the one tracker lifecycle: no other class registers them; every seat has a choice for each build, pet state and level band (Raptor Strike and Arcane Shot before the Aspect and the pet, a melee hunter's strike for the Mark, Arcane Intellect before the mana gem, the mage's school debuff by talent, armor for a warlock with no demon); aura pieces light through Blizzard's aura slots and Lua reads no aura; the pet and demon medals show the pet's portrait, its missing health as a bar fed the engine's values and its happiness as a rim; the gem and Healthstone are lit, cooling or empty from bag counts and item cooldowns; each spire stands alone once known and drains through duration bars; the soul wisps count Soul Shards up to five, fly in, burst, circle only at Full off rest and replace the shard jewels; cooldown rims stack the class's cooldowns, a pet's Bestial Wrath among them; moments hand the engine their flares and fires only at Full; secret auras build nothing until combat ends; each switch hides its seat alone; Frames stands the seats in the row; nothing runs OnUpdate; every crest part is an even number of pixels at four screen sizes and the spires stay under the cooldown row.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local KNOWN = {
	HUNTER = { 13165, 883, 1130, 1978, 19552, 3045, 19574, 75, 2643 },
	MAGE = { 168, 759, 11426, 12574, 116, 118, 12042, 11958, 2139, 122 },
	WARLOCK = { 172, 980, 348, 688, 6201, 1120, 18094, 18288, 706, 702, 17962, 2362, 6789 },
}

local function New(class, opts)
	opts = opts or {}
	local size = opts.size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._known = {}
			for _, id in ipairs(opts.known or KNOWN[class] or {}) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e._aurasSecret = opts.secret
			e._bags, e._cooling, e._usable = opts.bags or {}, {}, {}
			e.C_Item = e.C_Item or {}
			e.C_Item.GetItemCount = function(id) return e._bags[id] or 0 end
			e.C_Item.GetItemIconByID = function(id) return 5000000 + id end
			e.C_Item.GetItemCooldown = function(id)
				local c = e._cooling[id]
				if c then return c[1], c[2], true end
				return 0, 0, true
			end
			e.C_Spell.IsSpellUsable = function(id) return e._usable[id] == true, false end
			e.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
			e._ammo = 1000
			e.UnitUsesAmmo = function() return true end
			e.C_PaperDollInfo = { GetInventorySlotInfo = function() return 0 end }
			e.GetInventoryItemCount = function() return e._ammo end
			e.Enum.PowerType = e.Enum.PowerType or { Mana = 0 }
			e.UnitPowerPercent = function() return 0.25 end
			e.C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end, SetType = function() end } end }
			e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
			e.GetTime = e.GetTime or function() return e._now or 0 end
			e._petSpells = {}
			e.C_SpellBook.IsSpellKnown = function(id, bank) if bank == 1 then return e._petSpells[id] == true end return e._known[id] == true end
			e.Enum.SpellBookSpellBank = e.Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
			e._pet = opts.pet
			local exists = e.UnitExists
			e.UnitExists = function(unit) if unit == "pet" then return e._pet ~= nil end return exists(unit) end
			e.UnitIsDead = function(unit) return unit == "pet" and e._pet ~= nil and e._pet.dead == true end
			e.UnitHealthMax = function() return e.Secret(e._pet and e._pet.max or 0) end
			e.UnitHealthMissing = function() return e.Secret(e._pet and e._pet.missing or 0) end
			e.C_PetInfo = { GetPetHappiness = function() return e._pet and e._pet.mood end }
			e.SetPortraitTexture = function(texture, unit) texture._portrait = unit end
			e._slotGroups = true
			e.AuraContainerSortMethod = { Default = 0, AuraInstanceIDOnly = 8 }
			e.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
			Slots.Install(e)
		end,
	})
	if opts.frames then
		K.Options.Write("HudStyle", "style", "frames")
	end
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

-- Piece(ns, key, choice) -> the piece built for the switch's row and choice (1 when unset), and whether it shows.
local function Piece(ns, key, choice)
	local state = ns.SlabTrackers.state
	local form = state.form
	for i, row in ipairs(ns.SlabTrackers.CLASSES[ns.class] or {}) do
		local p = row.key == key and form and form.pieces[i .. ":" .. (choice or 1)]
		if p then return p, p:IsShown() end
	end
end

-- Seated(ns, key) -> the piece showing in the switch's seat, whichever choice it is.
local function Seated(ns, key)
	for c = 1, 3 do
		local p, shows = Piece(ns, key, c)
		if shows then return p end
	end
end

local function Shown(button, group)
	for _, g in ipairs(button._shownAnimations or {}) do
		if g == group then return true end
	end
	return false
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do
		n = n + Updating(child)
	end
	return n
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

local function Learn(env, ...)
	for _, id in ipairs({ ... }) do env._known[id] = true end
	env.FireEvent("SPELLS_CHANGED")
end

for _, class in ipairs({ "WARRIOR", "SHAMAN", "ROGUE", "PRIEST", "PALADIN", "DRUID" }) do
	local env, K, ns = New(class, { known = { 13165, 168, 172, 688 }, bags = { [6265] = 3 } })
	for _, key in ipairs({ "crestAspect", "crestManaGem", "crestTorments", "crestWisps", "crestSchool", "crestShot", "crestCurse" }) do
		assert(not ns.SlabTrackers.Has(key), class .. ": no " .. key .. " row")
	end
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 2973 } })
	local raptor, shows = Piece(ns, "crestAspect", 2)
	assert(raptor and shows and raptor.spec.feed == "cooldown", "a hunter with only Raptor Strike sees its cooldown on the left hip")
	assert(Piece(ns, "crestPet") == nil and Piece(ns, "crestPet", 2) == nil, "nothing for the right hip before Arcane Shot")
	Learn(env, 13163, 3044)
	local aspect, lit = Piece(ns, "crestAspect", 1)
	assert(aspect and lit and not select(2, Piece(ns, "crestAspect", 2)), "Aspect of the Monkey takes the hip from Raptor Strike")
	assert(select(2, Piece(ns, "crestPet", 2)), "Arcane Shot's cooldown holds the right hip until the pet")
	assert(Piece(ns, "crestShot") == nil, "no shot medal before Mongoose Bite or Multi-Shot")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER")
	local aspect, mark, sting, pet = Piece(ns, "crestAspect"), Piece(ns, "crestMark"), Piece(ns, "crestSting"), Piece(ns, "crestPet")
	assert(aspect:IsShown() and not aspect.lit:IsShown(), "no Aspect up: the medal is grey steel")
	Slots.Set(env, "player", { { id = 14318, icon = 136076, start = 0 } })
	assert(aspect.lit:IsShown() and aspect.lit.icon._state.Texture[1] == 136076, "an Aspect lights the medal with its own icon")
	Slots.Set(env, "target", { { id = 1130, icon = 132212, harmful = true, start = 0, duration = 120 }, { id = 24131, icon = 135125, harmful = true, mine = true, start = 2, duration = 12 } })
	assert(mark.lit:IsShown() and AB.W.LastCall(mark.timer, "SetCooldownFromDurationObject"), "the Mark lights its perch and drains its ring")
	assert(sting.lit:IsShown() and sting.lit.icon._state.Texture[1] == 135125, "any of your Stings, Wyvern Sting's poison too, lights the perch with its own icon")
	assert(sting.steel._state.Texture[1] == 1000000 + 1978, "the perch rests on Serpent Sting")
	Slots.Set(env, "target", { { id = 1978, icon = 132204, harmful = true, mine = false, start = 0, duration = 15 } })
	assert(not sting.lit:IsShown() and not mark.lit:IsShown(), "another hunter's Sting leaves your perch dark")
	assert(not pet.pet:IsShown(), "no pet: the pet medal is grey steel")
	env._pet = { max = 1800, missing = 600, mood = 2 }
	env.FireEvent("UNIT_PET", "player")
	assert(pet.pet:IsShown() and pet.portrait._portrait == "pet", "a pet shows its portrait")
	pet.portrait._portrait = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(pet.portrait._portrait == nil, "the pet medal repaints on its own events only, not on a cooldown update")
	env.FireEvent("UNIT_PORTRAIT_UPDATE", "pet")
	local _, high = pet.shade:GetMinMaxValues()
	assert(env.issecretvalue(high) and env.Reveal(high) == 1800 and env.Reveal(pet.shade:GetValue()) == 600, "the red shade is the engine's missing health over its maximum, never compared")
	local r, g, b = K.Tokens.Color("neutral")
	local mr, mg, mb = pet.mood:GetVertexColor()
	assert(pet.mood:IsShown() and math.abs(mr - r) + math.abs(mg - g) + math.abs(mb - b) < 1e-3, "a content pet rims the medal amber")
	env._pet.mood = env.Secret(3)
	env.FireEvent("UNIT_HAPPINESS", "pet")
	assert(not pet.mood:IsShown(), "a secret happiness hides the rim rather than guess")
	env._pet.dead = true
	env.FireEvent("UNIT_HEALTH", "pet")
	assert(not pet.pet:IsShown(), "a dead pet turns the medal back to steel")
	local mend = pet.lits[#pet.lits]
	assert(mend.container and Shown(mend, mend.loop), "Mend Pet's pulse is the engine's shown animation on a pet slot")
	local rim = Piece(ns, "crestCooldowns")
	Slots.Set(env, "pet", { { id = 19574, icon = 132127, start = 0, duration = 18 } })
	Slots.Set(env, "player", { { id = 3045, icon = 132208, start = 1, duration = 15 } })
	local seen = 0
	for _, button in ipairs(rim.stack) do seen = seen + (button:IsShown() and 1 or 0) end
	assert(seen == 2, "Rapid Fire and the pet's Bestial Wrath both stand on the cooldown rim")
	local gust = Piece(ns, "crestGust")
	assert(Shown(gust.lits[#gust.lits], gust.lits[#gust.lits].loop), "at Full the gust is the engine's shown animation")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13163, 1130, 1978, 19306, 1495, 2643, 75 } })
	local shot = Piece(ns, "crestShot")
	assert(shot and shot.spec.candidates[1] == 19306 and shot.spec.candidates[3] == 2643, "the shot medal tries Counterattack, Mongoose Bite, then Multi-Shot")
	assert(not shot.lit:IsShown(), "nothing usable: the shot medal stays steel")
	env._usable[2643] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(shot.lit:IsShown() and shot.usable == 2643, "Multi-Shot ready lights the medal")
	env._usable[19306] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(shot.usable == 19306, "Counterattack after a parry comes first")
	local ring = Piece(ns, "crestAutoShot")
	env.FireEvent("PLAYER_SWING", env.Secret(2.8), 2)
	assert(AB.W.LastCall(ring.swing, "SetCooldownFromDurationObject") or AB.W.LastCall(ring.swing, "SetCooldown"), "each Auto Shot restarts the ring, its duration secret or not")
	local r, g, b = K.Tokens.Color("steelLit")
	local sr, sg, sb = unpack(ring.swing._state.SwipeColor)
	assert(math.abs(sr - r) + math.abs(sg - g) + math.abs(sb - b) < 1e-3, "plenty of ammo: pale steel")
	env._ammo = 0
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	r, g, b = K.Tokens.Color("hostile")
	sr, sg, sb = unpack(ring.swing._state.SwipeColor)
	assert(math.abs(sr - r) + math.abs(sg - g) + math.abs(sb - b) < 1e-3, "out of ammo: the ring turns red")
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 168, 1459, 116, 118, 2136 } })
	local intellect, shows = Piece(ns, "crestManaGem", 2)
	assert(intellect and shows and intellect.spec.spells[1] == 1459, "before a gem, the right shoulder times Arcane Intellect")
	assert(select(2, Piece(ns, "crestCounterspell", 2)), "before Counterspell, the left hip sweeps Fire Blast")
	local chill, cs = Piece(ns, "crestFrozen", 2)
	assert(chill and cs, "before Frost Nova the left foot times your Frostbolt's chill")
	local poly, ps = Piece(ns, "crestYourSpell", 3)
	Slots.Set(env, "target", { { id = 116, icon = 135846, harmful = true, mine = true, start = 0, duration = 9 }, { id = 118, icon = 136071, harmful = true, mine = true, start = 0, duration = 50 } })
	assert(ps and chill.lit:IsShown() and poly.lit:IsShown(), "your Frostbolt and Polymorph light their perches")
	assert(Piece(ns, "crestSchool") == nil and Piece(ns, "crestSchool", 3) == nil, "no school medal before Frost Nova or a talent")
	Learn(env, 122, 2139)
	assert(select(2, Piece(ns, "crestFrozen", 1)) and select(2, Piece(ns, "crestCounterspell", 1)) and select(2, Piece(ns, "crestSchool", 4)), "Frost Nova and Counterspell take their seats; Frost Nova's cooldown holds the school hip")
	Learn(env, 1326079)
	assert(select(2, Piece(ns, "crestSchool", 3)), "Arcane Wrath takes the school hip at 25")
	Learn(env, 11095, 11119)
	local fire, fs = Piece(ns, "crestSchool", 1)
	assert(fs and fire.spec.pips == 5 and select(2, Piece(ns, "crestYourSpell", 1)), "Improved Scorch makes it Fire Vulnerability with five stacks; Ignite makes the spell perch your fire damage")
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE")
	local gem, ward, clear = Piece(ns, "crestManaGem"), Piece(ns, "crestWard"), Piece(ns, "crestClearcasting")
	assert(gem:IsShown() and not gem.lit:IsShown(), "no gem: an empty dark setting")
	env._bags[5514] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(gem.lit:IsShown() and gem.lit.icon._state.Texture[1] == 5005514, "a gem in the bags lights the medal")
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	assert(gem.lowMana:IsShown() and gem.lowMana:GetAlpha() == 0.25, "the low-mana glow takes its alpha from the engine's mana curve")
	env._cooling[5514] = { 100, 120 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not gem.lowMana:IsShown() and AB.W.LastCall(gem.timer, "SetCooldown"), "a used gem cools under a draining swipe and drops its low-mana glow")
	assert(AB.W.LastCall(ward.timer, "SetSwipeTexture"), "the ward drains the shared thin rim ring")
	Slots.Set(env, "player", { { id = 11426, icon = 135988, start = 0, duration = 60 } })
	assert(ward.lit:IsShown() and AB.W.LastCall(ward.timer, "SetCooldownFromDurationObject"), "Ice Barrier lights the ward ring and drains it")
	assert(clear.timer == nil and Shown(clear.lit, clear.lit.flare.play) and Shown(clear.lit, clear.lit.loop), "at Full Clearcasting gives the engine its burst and fire, with no ring")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not Shown(clear.lit, clear.lit.loop), "Calm holds the moment's fire still")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 172, 980, 348, 18265, 688, 6201, 1120, 18094, 706, 702, 17962, 2362, 6789 }, bags = { [6265] = 2 } })
	local torments, wisps = Piece(ns, "crestTorments"), Piece(ns, "crestWisps")
	assert(#torments.spires == 4 and torments.spires[4].socket:IsShown(), "Siphon Life's spire stands once the talent is known")
	local corruption = torments.spires[1]
	assert(corruption.lit:GetParent()._durationBar and corruption.glow:GetParent()._durationBar and corruption.core:GetParent()._durationBar, "each spire's three bars are duration bars the engine drains")
	Slots.Set(env, "target", { { id = 25311, icon = 136118, harmful = true, start = 0, duration = 18 } })
	assert(corruption.lit:GetParent():IsShown() and corruption.icon._state.Texture[1] == 136118, "your Corruption lights its spire and socket icon")
	assert(not torments.spires[2].lit:GetParent():IsShown(), "no Bane: its spire stays dark")
	local count = 0
	for _, s in ipairs(wisps.seats) do count = count + (s.wisp:IsShown() and 1 or 0) end
	assert(count == 2 and wisps.count == 2, "two shards: two wisps")
	assert(ns.Slab.Resting() and not wisps.seats[1].orbit:IsPlaying(), "Calm crest at rest holds the wisps still")
	env.SetTarget(true)
	assert(wisps.seats[1].orbit:IsPlaying(), "the wisps circle at Full once the crest wakes")
	env._bags[6265] = 3
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(wisps.seats[3].wisp:IsShown() and wisps.seats[3].come:IsPlaying(), "a new shard flies in")
	env._bags[6265] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(not wisps.seats[2].wisp:IsShown() and wisps.seats[2].flare.play:IsPlaying() and wisps.seats[3].flare.play:IsPlaying(), "each spent shard bursts")
	assert(not wisps.number:IsShown(), "five or fewer shards: the wisps alone")
	env._bags[6265] = 9
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(wisps.count == 1, "the wisps count only on BAG_UPDATE_DELAYED")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(wisps.count == 5 and wisps.number:IsShown() and tostring(wisps.number:GetText()) == "9", "nine shards across the bags: five wisps and the exact count")
	assert(select(2, Piece(ns, "crestDemon", 2)) and not Piece(ns, "crestDemon", 1), "no demon out: the left shoulder times Demon Armor")
	env._pet = { max = 1200, missing = 0 }
	env.FireEvent("UNIT_PET", "player")
	local demon, out = Piece(ns, "crestDemon", 1)
	assert(demon and out and demon.pet:IsShown() and not select(2, Piece(ns, "crestDemon", 2)), "a demon out takes the left shoulder")
	assert(demon.lit.container and demon.spec.spells[1] == 18789, "and lights a Demonic Sacrifice from its own aura slot")
	Slots.Set(env, "target", { { id = 1014, icon = 136139, harmful = true, start = 0, duration = 24 }, { id = 702, icon = 136138, harmful = true, start = 0, duration = 120 } })
	assert(torments.spires[2].lit:GetParent():IsShown(), "Bane of Agony rank 2 lights the Bane spire")
	assert(Piece(ns, "crestCurse").lit:IsShown(), "your Curse lights the curse perch")
	assert(select(2, Piece(ns, "crestConflagrate")) and Piece(ns, "crestConflagrate").bar, "Conflagrate refills a jewel on the lower ring")
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	local stone = Piece(ns, "crestStone")
	assert(stone.lit:IsShown() and AB.W.LastCall(stone.bar, "SetTimerDuration"), "a Spellstone on the weapon fills its jewel and drains it")
	assert(select(2, Piece(ns, "crestSpellLock", 2)), "no Felhunter: the right foot sweeps Death Coil")
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	assert(select(2, Piece(ns, "crestSpellLock", 1)), "a Felhunter's Spell Lock takes the right foot")
	K.Options.Write("ActionBars", "crestWisps", false)
	assert(not wisps:IsShown() and ns.SlabJewels.state.class == nil, "Soul wisps off hides the wisps; no jewel ever reads a soul shard power")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not wisps.seats[1].orbit:IsPlaying(), "Calm holds the wisps on their seats")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 348, 688, 687 }, pet = { max = 100, missing = 0 } })
	local skin, shows = Piece(ns, "crestHealthstone", 2)
	assert(skin and shows, "before Healthstones, with the imp on the left, the right shoulder times Demon Skin")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { secret = true, bags = { [6265] = 1 } })
	assert(ns.SlabTrackers.state.form == nil or next(ns.SlabTrackers.state.form.pieces) == nil, "secret auras build nothing")
	env._aurasSecret = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(Piece(ns, "crestTorments") and select(2, Piece(ns, "crestWisps")), "after combat the trackers build")
	Clean(env, K)
end

for class, keys in pairs({ HUNTER = { "crestShot", "crestAspect", "crestPet", "crestMark", "crestSting", "crestAutoShot", "crestGust", "crestCooldowns" },
	MAGE = { "crestArmor", "crestManaGem", "crestCounterspell", "crestFrozen", "crestYourSpell", "crestWard", "crestClearcasting", "crestCooldowns" },
	WARLOCK = { "crestTorments", "crestWisps", "crestDemon", "crestHealthstone", "crestStone", "crestConflagrate", "crestCurse", "crestSpellLock", "crestTrance", "crestCooldowns" } }) do
	local env, K, ns = New(class, { bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
	for _, key in ipairs(keys) do
		K.Options.Write("ActionBars", key, false)
		assert(not Seated(ns, key), class .. ": " .. key .. " off hides its seat")
		for _, other in ipairs(keys) do
			assert(other == key or Seated(ns, other), class .. ": " .. key .. " off leaves " .. other)
		end
		K.Options.Write("ActionBars", key, true)
	end
	local updating = 0
	for _, p in pairs(ns.SlabTrackers.state.form.pieces) do updating = updating + Updating(p) end
	assert(updating == 0, class .. ": nothing runs OnUpdate")
	Clean(env, K)
	local fenv, FK, fns = New(class, { frames = true, bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
	local seen = 0
	for _, p in pairs(fns.SlabTrackers.state.form.pieces) do seen = seen + (p:IsShown() and 1 or 0) end
	assert(fns.SlabTrackers.state.form == fns.SlabTrackers.state.forms.row and seen >= #keys, class .. ": Frames stands every seat in the row")
	local rects = {}
	for _, p in pairs(fns.SlabTrackers.state.form.pieces) do
		if p:IsShown() and not p.halo then
			local parts = p.spires and {} or p.seats or { p }
			for _, t in ipairs(p.spires or {}) do
				if t.socket:IsShown() then parts[#parts + 1], parts[#parts + 2] = t.socket, t.spire; t.spire.upright = true end
			end
			for _, f in ipairs(parts) do rects[#rects + 1] = { f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop(), f.upright } end
		end
	end
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			assert(a[5] and b[5] or a[2] <= b[1] + 0.01 or b[2] <= a[1] + 0.01 or a[4] <= b[3] + 0.01 or b[4] <= a[3] + 0.01, class .. ": Frames row pieces " .. i .. " and " .. j .. " do not overlap (side by side spires may touch, as the Spirit Poles' row)")
		end
	end
	Clean(fenv, FK)
end

for _, size in ipairs(SIZES) do
	local at = size[1] .. "x" .. size[2] .. ": "
	for _, class in ipairs({ "HUNTER", "MAGE", "WARLOCK" }) do
		local env, K, ns = New(class, { size = size, known = class == "WARLOCK" and { 172, 980, 348, 18265, 688, 6201, 1120, 18094, 706, 702, 17962, 2362, 6789 } or nil,
			bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
		local k = size[2] / 768
		local function Even(region)
			local s = region:GetEffectiveScale() * k
			local w, h = (region:GetRight() - region:GetLeft()) * s, (region:GetTop() - region:GetBottom()) * s
			local nw, nh = math.floor(w + 0.5), math.floor(h + 0.5)
			return math.abs(w - nw) < 1e-3 and nw % 2 == 0 and math.abs(h - nh) < 1e-3 and nh % 2 == 0
		end
		for key, p in pairs(ns.SlabTrackers.state.form.pieces) do
			for n, part in ipairs(p:IsShown() and p.parts or {}) do
				assert(Even(part), at .. class .. " " .. key .. " part " .. n .. " is an even number of pixels")
			end
			for i, t in ipairs(p.spires or {}) do
				for _, part in ipairs({ t.socket, t.spire, t.lit, t.glow }) do
					assert(Even(part), at .. "spire " .. i .. " parts are even pixels")
				end
			end
			for i, s in ipairs(p.seats or {}) do
				assert(Even(s) and Even(s.art), at .. "wisp " .. i .. " is an even number of pixels")
			end
		end
		if class == "WARLOCK" then
			local layouts, root = K.Setup.Layouts, K.Scale.Root():GetEffectiveScale()
			local row = layouts.Aspect(K.Scale.Aspect(), "medallions", K.Layout.Setting("preset"), "cooldowns.essential").y
			for i, t in ipairs(Piece(ns, "crestTorments").spires) do
				local _, bottom, _, height = t.spire:GetRect()
				local top = (bottom + height) * t.spire:GetEffectiveScale() / root
				assert(top < row - 2, at .. "spire " .. i .. " stays under the cooldown row (" .. top .. " against " .. row .. ")")
			end
		end
		Clean(env, K)
	end
end

print("actionbars crest ranged ok")
