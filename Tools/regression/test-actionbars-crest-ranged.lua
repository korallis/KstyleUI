-- test-actionbars-crest-ranged.lua: a hunter's, mage's and warlock's crest trackers (KstyleUI_ActionBars/SlabRanged.lua) through the one tracker lifecycle: no other class registers them; every seat has a choice for each build, pet state and level band (Raptor Strike and Arcane Shot before the Aspect and the pet, a melee hunter's strike for the Mark, Arcane Intellect before the mana gem, the mage's school debuff by talent, armor for a warlock with no demon); aura pieces light through Blizzard's aura slots and Lua reads no aura; the pet's light along the band is its health as a bar fed the engine's values, with a forged haunch only below Happy (amber light and halo at Content, red at Unhappy, gilt and no haunch at Happy, none for a secret value), moved by UNIT_HAPPINESS alone, landing, breathing, blinking for 3 s and fading green by the motion level, gone with the pet, and Mend Pet's motes; the fuse's head rides its fill and the Mark's reticle closes in; the gem and Healthstone are lit, cooling or empty from bag counts and item cooldowns; each spire stands alone once known and drains through duration bars; the soul wisps count Soul Shards up to five with a faint rim at five or more, fly in, burst and circle only at Full off rest, the first one too, and replace the shard jewels; Rapid Fire alone gusts; only your own school debuff lights its embers; cooldown rims stack the class's cooldowns, a pet's Bestial Wrath among them; moments hand the engine their flares and fires only at Full; secret auras build nothing until combat ends; each switch hides its seat alone; Frames stands the seats in the row; a mana update asks the bags nothing and every shot reuses one duration object; nothing loads for any other class; nothing runs OnUpdate; every crest part is an even number of pixels at four screen sizes and the spires stay under the cooldown row.
local R = dofile("Tools/regression/ranged_env.lua")
local AB, Slots, SIZES, New, Piece, Seated, Shown, Updating, Clean, Tint, Learn = R.AB, R.Slots, R.SIZES, R.New, R.Piece, R.Seated, R.Shown, R.Updating, R.Clean, R.Tint, R.Learn

for _, class in ipairs({ "WARRIOR", "SHAMAN", "ROGUE", "PRIEST", "PALADIN", "DRUID" }) do
	local env, K, ns = New(class, { known = { 13165, 168, 172, 688 }, bags = { [6265] = 3 } })
	for _, key in ipairs({ "crestAspect", "crestManaGem", "crestTorments", "crestWisps", "crestSchool", "crestShot", "crestCurse" }) do
		assert(not ns.SlabTrackers.Has(key), class .. ": no " .. key .. " row")
	end
	local rows = ns.SlabTrackers.CLASSES
	assert(not (rows.HUNTER or rows.MAGE or rows.WARLOCK), class .. ": no ranged row is even loaded")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 2973 } })
	local raptor, shows = Piece(ns, "crestAspect", 2)
	assert(raptor and shows and raptor.spec.feed == "cooldown", "a hunter with only Raptor Strike sees its cooldown flash over the emblem")
	assert(Piece(ns, "crestPet") == nil and Piece(ns, "crestPet", 2) == nil, "nothing for the pet's band before Arcane Shot")
	Learn(env, 13163, 3044)
	local aspect, lit = Piece(ns, "crestAspect", 1)
	assert(aspect and lit and not select(2, Piece(ns, "crestAspect", 2)), "Aspect of the Monkey perches on the ring in place of Raptor Strike")
	assert(select(2, Piece(ns, "crestPet", 2)), "Arcane Shot's cooldown flashes over the emblem until the pet")
	assert(Piece(ns, "crestShot") == nil, "no shot over the emblem before Mongoose Bite or Multi-Shot")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER")
	local aspect, mark, sting, pet = Piece(ns, "crestAspect"), Piece(ns, "crestMark"), Piece(ns, "crestSting"), Piece(ns, "crestPet")
	assert(aspect:IsShown() and aspect.rest:IsShown() and not aspect.lit:IsShown(), "no Aspect up: a dark steel hawk perched on the ring")
	Slots.Set(env, "player", { { id = 14318, icon = 136076, start = 0 } })
	assert(aspect.lits[1]:IsShown() and not aspect.lits[7]:IsShown() and Tint(aspect.lits[1].art, K, "gilt", 0.1), "Aspect of the Hawk lights the perched hawk gilt")
	Slots.Set(env, "player", { { id = 415423, icon = 132160, start = 0 } })
	assert(aspect.lits[7]:IsShown() and not aspect.lits[1]:IsShown() and Tint(aspect.lits[7].art, K, "magic", 0.1), "Aspect of the Viper lights its coil mana blue")
	assert(Shown(aspect.lits[7], aspect.lits[7].loop), "at Full the glyph breathes as the engine's shown animation")
	Slots.Set(env, "target", { { id = 1130, icon = 132212, harmful = true, start = 0, duration = 120 }, { id = 24131, icon = 135125, harmful = true, mine = true, start = 2, duration = 12 } })
	assert(mark.lit:IsShown() and Shown(mark.lit, mark.lit.loops[2]) and Shown(mark.lit, mark.lit.loops[1]), "the Mark's reticle closes in over the emblem and gleams")
	assert(sting.lits[4]:IsShown() and sting.lits[4]._durationBar[1] == sting.lits[4].art, "any of your Stings, Wyvern Sting's poison too, burns its own mark down with its time")
	local _, fill, at = sting.lits[4].head:GetPoint()
	assert(fill == sting.lits[4].art:GetStatusBarTexture() and at == "TOP" and sting.lits[4].mark:GetTexture():find("Wyvern"), "the fuse's head, Wyvern Sting's own mark in a flame, rides the top of what is left")
	Slots.Set(env, "target", { { id = 1978, icon = 132204, harmful = true, mine = false, start = 0, duration = 15 } })
	assert(not sting.lits[1]:IsShown() and not mark.lit:IsShown(), "another hunter's Sting leaves your fuse dark")
	assert(not pet.pet:IsShown() and not pet.feed, "no pet: only the dark groove on the band, and no haunch is made")
	assert(not (ns.SlabTrackers.CLASSES.MAGE or ns.SlabTrackers.CLASSES.WARLOCK), "a hunter loads only the hunter's rows")
	env._pet = { max = 1800, missing = 600, mood = 3 }
	env.FireEvent("UNIT_PET", "player")
	assert(pet.pet:IsShown() and pet.health:GetOrientation() == "HORIZONTAL" and pet.health:GetReverseFill(), "a pet lights its band from the right")
	local writes = #AB.W.Calls(pet.health, "SetValue")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(#AB.W.Calls(pet.health, "SetValue") == writes, "the pet's light repaints on its own events only, not on a cooldown update")
	env.FireEvent("UNIT_HEALTH", "pet")
	local _, high = pet.health:GetMinMaxValues()
	assert(env.issecretvalue(high) and env.Reveal(high) == 1800 and env.Reveal(pet.health:GetValue()) == 1200, "the light is the engine's health over its maximum, never compared")
	-- the pet mood plan's part 1 (docs/medallions-effects.md, Pet mood haunch): a haunch on the hunter crest below Happy, amber at Content, red at Unhappy, gone at Happy
	local function Light(token)
		local r, g, b = K.Tokens.Color(token)
		local lr, lg, lb = pet.health:GetStatusBarColor()
		return math.abs(lr - (0.3 + 0.7 * r)) + math.abs(lg - (0.3 + 0.7 * g)) + math.abs(lb - (0.3 + 0.7 * b)) < 1e-3
	end
	assert(not pet.feed and Light("giltLit"), "a happy pet: no haunch is made and its light stays gilt")
	env._pet.mood = 2
	env.FireEvent("UNIT_HAPPINESS", "pet")
	local feed = pet.feed
	assert(feed and feed.seat:IsShown() and feed.gold and Tint(feed.tint, K, "neutral") and Light("neutral"), "Content: the haunch lands, its halo and the pet's light amber")
	local body = feed.seat._regions[2]
	assert(body:GetTexture():find("Haunch", 1, true) and Tint(body, K, "coinGold"), "the haunch's body is the forged gold Haunch")
	local sheen = table.concat({ feed.sheen:GetVertexColor() }, ",")
	assert(feed.land:IsPlaying() and not feed.breath:IsPlaying() and not feed.blink:IsPlaying(), "at Full the drop lands with one flare; the crest at rest holds Content's halo still")
	env.SetTarget(true)
	assert(feed.breath:IsPlaying(), "awake, Content's halo breathes")
	env._pet.mood = 1
	env.FireEvent("UNIT_HAPPINESS", "pet")
	assert(feed.seat:IsShown() and Tint(feed.tint, K, "hostile") and Light("hostile"), "Unhappy: the haunch and the pet's light turn red")
	assert(Tint(body, K, "coinGold") and table.concat({ feed.sheen:GetVertexColor() }, ",") == sheen, "the mood colours only the halo: the haunch itself stays gold")
	assert(feed.blink:IsPlaying() and not feed.breath:IsPlaying(), "reaching Unhappy blinks the halo and stops the breath")
	local steps = 0
	for _, a in ipairs(feed.blink._anims) do steps = steps + a._state.Duration[1] end
	assert(feed.blink:GetLooping() ~= "REPEAT" and math.abs(steps - 3) < 1e-6, "the blink runs at the crest's warning rate for 3 s and ends, held, rather than loop")
	env._pet.mood = 3
	env.FireEvent("UNIT_HAPPINESS", "pet")
	assert(Tint(feed.tint, K, "friendly") and feed.flash:IsPlaying() and feed.leave:IsPlaying() and Light("giltLit"), "fed to Happy: the halo flashes green and the haunch fades as the light turns gilt")
	feed.leave:GetScript("OnFinished")(feed.leave)
	assert(not feed.seat:IsShown(), "the faded haunch is gone")
	env._pet.mood = 2
	env.FireEvent("UNIT_HAPPINESS", "pet")
	assert(feed.seat:IsShown() and pet.feed == feed, "a second drop shows the same haunch again")
	env._pet = nil
	env.FireEvent("UNIT_PET", "player")
	assert(not pet.pet:IsVisible() and not feed.seat:IsVisible(), "a dismissed pet takes its haunch with it")
	env._pet = { max = 1800, missing = 600, mood = 2 }
	env.FireEvent("UNIT_PET", "player")
	assert(feed.seat:IsVisible() and not feed.land:IsPlaying(), "a pet called back at Content shows the haunch with no landing")
	env._pet.mood = env.Secret(1)
	env.FireEvent("UNIT_HAPPINESS", "pet")
	assert(not feed.seat:IsShown() and Light("giltLit"), "a secret happiness hides the haunch rather than guess")
	env._pet.dead = true
	env.FireEvent("UNIT_HEALTH", "pet")
	assert(not pet.pet:IsShown(), "a dead pet puts its light out")
	local mend = pet.lits[#pet.lits]
	assert(mend.container and #mend.loops == 4 and Shown(mend, mend.loops[1]) and Shown(mend, mend.loops[4]), "Mend Pet's motes run along the light as the engine's shown animations on a pet slot")
	local rim = Piece(ns, "crestCooldowns")
	Slots.Set(env, "pet", { { id = 19574, icon = 132127, start = 0, duration = 18 } })
	Slots.Set(env, "player", { { id = 3045, icon = 132208, start = 1, duration = 15 } })
	local seen = 0
	for _, button in ipairs(rim.sigils) do seen = seen + (button:IsShown() and 1 or 0) end
	assert(seen == 2, "Rapid Fire and the pet's Bestial Wrath both stand on the cooldown rim")
	local gust = Piece(ns, "crestGust")
	assert(Shown(gust.lits[#gust.lits], gust.lits[#gust.lits].loop), "at Full the gust is the engine's shown animation")
	assert(gust.gust:GetParent():GetAlpha() > 0, "the gust's streaks stay visible if its tween never runs")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 3045, 75 } })
	local gust = Piece(ns, "crestGust")
	assert(gust, "Rapid Fire alone brings the gust, without Deadly Aspects")
	Slots.Set(env, "player", { { id = 3045, icon = 132208, start = 0, duration = 15 } })
	assert(gust.lit:IsShown() and gust.lits[#gust.lits]:IsShown(), "Rapid Fire up gusts across the crest with no Quick Shots")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13163, 1130, 1978, 19306, 1495, 2643, 75 } })
	local shot = Piece(ns, "crestShot")
	assert(shot and shot.spec.candidates[1] == 19306 and shot.spec.candidates[3] == 2643, "the shot tries Counterattack, Mongoose Bite, then Multi-Shot")
	assert(not shot.lit:IsShown(), "nothing usable: the emblem shows no shot")
	env.SetTarget(true)
	env._usable[2643] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local multi = shot.shots[shot.spec.shots[2643]]
	assert(shot.lit:IsShown() and shot.usable == 2643 and multi:IsShown() and shot.flare.play:IsPlaying(), "Multi-Shot ready fires three arrows up the emblem")
	env._usable[19306] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(shot.usable == 19306 and shot.shots[shot.spec.shots[19306]]:IsShown() and not multi:IsShown(), "Counterattack after a parry comes first, its crimson blades in place of the arrows")
	local ring = Piece(ns, "crestAutoShot")
	local made, create = 0, env.C_DurationUtil.CreateDuration
	env.C_DurationUtil.CreateDuration = function() made = made + 1 return create() end
	for _ = 1, 10 do env.FireEvent("PLAYER_SWING", env.Secret(2.8), 2) end
	assert(made == 1, "ten shots reuse one duration object, as the swing timer does (" .. made .. " made)")
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
	assert(intellect and shows and intellect.spec.spells[1] == 1459, "before a gem, Arcane Intellect perches on the lower right")
	assert(select(2, Piece(ns, "crestCounterspell", 2)), "before Counterspell, Fire Blast's orb charges on the lower left")
	local chill, cs = Piece(ns, "crestFrozen", 2)
	assert(chill and cs, "before Frost Nova your Frostbolt's chill frosts the inner ring")
	local poly, ps = Piece(ns, "crestYourSpell", 3)
	Slots.Set(env, "target", { { id = 116, icon = 135846, harmful = true, mine = true, start = 0, duration = 9 }, { id = 118, icon = 136071, harmful = true, mine = true, start = 0, duration = 50 } })
	assert(ps and chill.lit:IsShown() and poly.lit:IsShown(), "your Frostbolt and Polymorph light the frost and the fuse")
	assert(Piece(ns, "crestSchool") == nil and Piece(ns, "crestSchool", 3) == nil, "nothing on the left band before Frost Nova or a talent")
	Learn(env, 122, 2139)
	assert(select(2, Piece(ns, "crestFrozen", 1)) and select(2, Piece(ns, "crestCounterspell", 1)) and select(2, Piece(ns, "crestSchool", 4)), "Frost Nova and Counterspell take their seats; Frost Nova's cooldown charges along the left band")
	Learn(env, 1326079)
	assert(select(2, Piece(ns, "crestSchool", 3)), "Arcane Wrath charges along the left band at 25")
	Learn(env, 11095, 11119)
	local fire, fs = Piece(ns, "crestSchool", 1)
	assert(fs and fire.spec.stacks == 5 and select(2, Piece(ns, "crestYourSpell", 1)),
		"Improved Scorch makes the left band five embers, one per stack of Fire Vulnerability; Ignite makes the fuse your fire damage")
	Slots.Set(env, "target", { { id = 22959, icon = 135818, harmful = true, mine = false, start = 0, duration = 30, count = 5 } })
	assert(not fire.lit:IsShown(), "another mage's Fire Vulnerability leaves your embers dark")
	Slots.Set(env, "target", { { id = 22959, icon = 135818, harmful = true, mine = true, start = 0, duration = 30, count = 5 } })
	assert(fire.lit:IsShown(), "your own Fire Vulnerability fills it")
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE")
	local gem, ward, clear = Piece(ns, "crestManaGem"), Piece(ns, "crestWard"), Piece(ns, "crestClearcasting")
	assert(gem:IsShown() and not gem.lit:IsShown(), "no gem: nothing hangs from the band")
	env._bags[5514] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(gem.lit:IsShown() and gem.ready:IsShown(), "a gem in the bags hangs lit from the band")
	local asked, count, cooldown = 0, env.C_Item.GetItemCount, env.C_Item.GetItemCooldown
	env.C_Item.GetItemCount = function(...) asked = asked + 1 return count(...) end
	env.C_Item.GetItemCooldown = function(...) asked = asked + 1 return cooldown(...) end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	assert(gem.lowMana:IsShown() and gem.lowMana:GetAlpha() == 0.25, "the low-mana glow takes its alpha from the engine's mana curve")
	assert(asked == 0, "a mana update asks the bags nothing (" .. asked .. " queries)")
	env.C_Item.GetItemCount, env.C_Item.GetItemCooldown = count, cooldown
	env._cooling[5514] = { 100, 120 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not gem.lowMana:IsVisible() and AB.W.LastCall(gem.timer, "SetCooldown") and not gem.ready:IsShown(),
		"a used gem goes dark and charges again over its cooldown, without its low-mana glow")
	assert(AB.W.LastCall(ward.timer, "SetSwipeTexture"), "the ward drains the shared thin rim ring")
	Slots.Set(env, "player", { { id = 11426, icon = 135988, start = 0, duration = 60 } })
	assert(ward.lit:IsShown() and AB.W.LastCall(ward.timer, "SetCooldownFromDurationObject"), "Ice Barrier lights the ward ring and drains it")
	local gate = clear.lit.flareGate
	local ping = gate.lit.flare._regions[1]
	assert(clear.timer == nil and Shown(gate.lit, gate.lit.flare.play) and ping:GetTexture():find("RingLine16", 1, true) and Tint(ping, K, "schoolArcane", 0),
		"Clearcasting, a proc, pings a thin ring round the crest in its own arcane colour when it lights, with no drain ring")
	local aura = clear.fire and clear.fire.lit._regions[1]
	assert(aura and aura:GetTexture() == K.Tokens.Texture("procAura") and Tint(aura, K, "schoolArcane", 0) and clear.fire.lit.loop,
		"while it is up its Blender-made aura of running arcs loops round the crest in arcane colour, never an icon (captain's direction: procs are animated spell effects)")
	assert(not ping:GetTexture():find("Burst", 1, true), "and never the class burst: that is the blaze's")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 172, 980, 348, 18265, 688, 691, 6201, 1120, 18094, 706, 702, 17962, 2362, 6789 }, bags = { [6265] = 2 } })
	local torments, wisps = Piece(ns, "crestTorments"), Piece(ns, "crestWisps")
	assert(#torments.spires == 4 and torments.spires[4].base:IsShown() and torments.spires[4].dim:GetTexture():find("Siphon"), "Siphon Life's spire stands once the talent is known")
	local corruption = torments.spires[1]
	assert(corruption.lit:GetParent()._durationBar and corruption.glow:GetParent()._durationBar and corruption.core:GetParent()._durationBar, "each spire's three bars are duration bars the engine drains")
	Slots.Set(env, "target", { { id = 25311, icon = 136118, harmful = true, start = 0, duration = 18 } })
	assert(corruption.lit:GetParent():IsShown() and corruption.rune:GetParent() == corruption.lit:GetParent() and corruption.neck:GetParent() == corruption.lit:GetParent(), "your Corruption lights its spire, the glyph at its foot and the neck between")
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
	-- The bursts of one spend are one crest flare: they hold the crest's flare place together, another crest flare stops them all, and the next spend stops that one.
	assert(K.Effects.Holder("crestFlare") == K.Effects.PRIORITY.ready, "the spend's bursts hold the crest's flare place")
	local other = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	other:Play()
	assert(other:IsPlaying() and not wisps.seats[2].flare.play:IsPlaying() and not wisps.seats[3].flare.play:IsPlaying(), "a crest flare from elsewhere stops both bursts")
	env._bags[6265] = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(wisps.seats[1].flare.play:IsPlaying() and not other:IsPlaying(), "and the next spend stops that one in turn")
	env._bags[6265] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(not wisps.number:IsShown() and not wisps.full:IsShown(), "five or fewer shards: the wisps alone")
	env._bags[6265] = 9
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(wisps.count == 1, "the wisps count only on BAG_UPDATE_DELAYED")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(wisps.count == 5 and wisps.number:IsShown() and tostring(wisps.number:GetText()) == "9", "nine shards across the bags: five wisps and the exact count")
	assert(wisps.full:IsShown(), "five or more shards: the rim keeps a faint violet light")
	assert(select(2, Piece(ns, "crestDemon", 2)) and not select(2, Piece(ns, "crestDemon", 1)), "no demon out: the Demon Armor sigil holds the left band, the demon's light ready behind it")
	env._pet = { max = 1200, missing = 0 }
	env.FireEvent("UNIT_PET", "player")
	local demon, out = Piece(ns, "crestDemon", 1)
	assert(demon and out and demon.pet:IsShown() and not select(2, Piece(ns, "crestDemon", 2)), "a demon out takes the left band")
	assert(demon.lit.container and demon.spec.spells[1] == 18789, "and lights a Demonic Sacrifice from its own aura slot")
	Slots.Set(env, "target", { { id = 1014, icon = 136139, harmful = true, start = 0, duration = 24 }, { id = 702, icon = 136138, harmful = true, start = 0, duration = 120 } })
	assert(torments.spires[2].lit:GetParent():IsShown(), "Bane of Agony rank 2 lights the Bane spire")
	assert(Piece(ns, "crestCurse").lit:IsShown(), "your Curse lights its fuse")
	assert(select(2, Piece(ns, "crestConflagrate")) and Piece(ns, "crestConflagrate").bar, "Conflagrate refills a jewel on the lower ring")
	Slots.Enchant(env, 1, { start = 0, duration = 1800 })
	local stone = Piece(ns, "crestStone")
	assert(stone.lit:IsShown() and AB.W.LastCall(stone.bar, "SetTimerDuration"), "a Spellstone on the weapon fills its jewel and drains it")
	assert(select(2, Piece(ns, "crestSpellLock", 2)), "no Felhunter: Death Coil's orb charges on the lower left")
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	assert(select(2, Piece(ns, "crestSpellLock", 1)), "a Felhunter's Spell Lock blade takes the lower left")
	K.Options.Write("ActionBars", "crestWisps", false)
	assert(not wisps:IsShown() and ns.SlabJewels.state.class == nil, "Soul wisps off hides the wisps; no jewel ever reads a soul shard power")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not wisps.seats[1].orbit:IsPlaying(), "Calm holds the wisps on their seats")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK")
	local wisps = Piece(ns, "crestWisps")
	env._bags[6265] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(ns.Slab.Resting() and wisps.seats[1].wisp:IsShown() and not wisps.seats[1].come:IsPlaying(), "Calm crest at rest: a gained shard settles without flying in")
	env._bags[6265] = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(not wisps.seats[1].flare.play:IsPlaying(), "Calm crest at rest: a spent shard goes without a burst")
	env.SetTarget(true)
	env._bags[6265] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(wisps.seats[1].come:IsPlaying() and wisps.seats[1].orbit:IsPlaying(), "the first shard gained with the crest awake flies in and circles at once")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 172, 688, 691, 706, 6201, 6789 } })
	assert(select(2, Piece(ns, "crestDemon", 2)) and select(2, Piece(ns, "crestSpellLock", 2)), "no demon: the armor sigil on the left band, Death Coil on the lower left")
	env.SetCombat(true)
	env._pet = { max = 1200, missing = 300 }
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	local demon, out = Piece(ns, "crestDemon", 1)
	assert(demon and out and demon.pet:IsShown() and env.Reveal(demon.health:GetValue()) == 900, "a Felhunter summoned in combat shows its sigil and health at once")
	assert(select(2, Piece(ns, "crestSpellLock", 1)), "and its Spell Lock takes the lower left in combat")
	env._pet = nil
	env.FireEvent("UNIT_PET", "player")
	assert(select(2, Piece(ns, "crestDemon", 2)) and select(2, Piece(ns, "crestSpellLock", 2)), "the demon gone in combat: armor and Death Coil return")
	env.SetCombat(false)
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 348, 688, 687 }, pet = { max = 100, missing = 0 } })
	local skin, shows = Piece(ns, "crestHealthstone", 2)
	assert(skin and shows, "before Healthstones, with the imp on the left band, Demon Skin perches on the lower right")
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
	MAGE = { "crestArmor", "crestManaGem", "crestCounterspell", "crestSchool", "crestFrozen", "crestYourSpell", "crestWard", "crestClearcasting", "crestCooldowns" },
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
				if t.base:IsShown() then parts[#parts + 1], parts[#parts + 2] = t.base, t.spire; t.spire.upright = true end
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
			bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0, mood = 1 } })
		local k = size[2] / 768
		local function Even(region)
			local s = region:GetEffectiveScale() * k
			local function Plain(v) return env.issecretvalue(v) and env.Reveal(v) or v end
			local w, h = Plain(region:GetWidth()) * s, Plain(region:GetHeight()) * s
			local nw, nh = math.floor(w + 0.5), math.floor(h + 0.5)
			return math.abs(w - nw) < 1e-3 and nw % 2 == 0 and math.abs(h - nh) < 1e-3 and nh % 2 == 0
		end
		for key, p in pairs(ns.SlabTrackers.state.form.pieces) do
			for n, part in ipairs(p:IsShown() and p.parts or {}) do
				assert(Even(part), at .. class .. " " .. key .. " part " .. n .. " is an even number of pixels")
			end
			for i, t in ipairs(p.spires or {}) do
				for _, part in ipairs({ t.base, t.spire, t.lit, t.glow }) do
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
