-- test-actionbars-crest-ranged.lua: a hunter's, mage's and warlock's crest trackers (KstyleUI_ActionBars/SlabRanged.lua) through the one tracker lifecycle: no other class registers them; every seat has a choice for each build, pet state and level band (Raptor Strike and Arcane Shot before the Aspect and the pet, a melee hunter's strike for the Mark, Arcane Intellect before the mana gem, the mage's school debuff by talent, armor for a warlock with no demon); aura pieces light through Blizzard's aura slots and Lua reads no aura; the pet's light along the band is its health as a bar fed the engine's values, with a forged haunch only below Happy (amber light and halo at Content, red at Unhappy, gilt and no haunch at Happy, none for a secret value), moved by UNIT_HAPPINESS alone, landing, breathing, blinking for 3 s and fading green by the motion level, gone with the pet, and Mend Pet's motes; the pet's focus fed unchanged and repainted alone; the paw on the pet's perch while no pet is out, red and breathing at Full while it lies dead and never while hidden, none for a secret death; Trueshot Aura's sigil lit gilt while up and steel while down; Improved Tracking's mark gold when the tracked type is a hostile target's, steel when not, gone with no target or a friendly one, listening only while switched on and blind to a secret type or reaction; the range ring off while Auto Shot reaches, gilt only when melee surely reaches, red only when both surely fall short, none for an unknown or secret reading or a friendly target, from the game's range events, never polled, the crest's own range checks released when no ring needs them and a shared one left alone; the pet's family ability cooling by the pet's cooldown event through a dismissal and a pet swap, its debuff ring and Furious Howl from your pet alone; Growl's orders by autocast, group, the pet's target and a secret; your own Immolation Trap's burn and the potion pendant through its recharge; Tranquilizing Shot on the lower left foot; the fuse's head rides its fill and the Mark's reticle closes in; the gem and Healthstone are lit, cooling or empty from bag counts and item cooldowns; each spire stands alone once known and drains through duration bars; the soul wisps count Soul Shards up to five with a faint rim at five or more, fly in, burst and circle only at Full off rest, the first one too, and replace the shard jewels; Rapid Fire alone gusts; only your own school debuff lights its embers; cooldown rims stack the class's cooldowns, a pet's Bestial Wrath among them; moments hand the engine their flares and fires only at Full; secret auras build nothing until combat ends; each switch hides its seat alone; Frames stands the seats in the row; a mana update asks the bags nothing and every shot reuses one duration object; nothing loads for any other class; nothing runs OnUpdate; every crest part is an even number of pixels at four screen sizes and the spires stay under the cooldown row.
local R = dofile("Tools/regression/ranged_env.lua")
local AB, Slots, SIZES, New, Piece, Seated, Shown, Updating, Clean, Tint, Learn, Listening = R.AB, R.Slots, R.SIZES, R.New, R.Piece, R.Seated, R.Shown, R.Updating, R.Clean, R.Tint, R.Learn, R.Listening

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
	assert(mark.lit:IsShown() and Shown(mark.lit, mark.lit.loops[2]) and Shown(mark.lit, mark.lit.loops[1]), "the Mark's reticle closes in on the left band and gleams")
	assert(sting.lits[4]:IsShown() and sting.lits[4]._durationBar[1] == sting.lits[4].art, "any of your Stings, Wyvern Sting's poison too, burns its own mark down with its time")
	local _, fill, at = sting.lits[4].head:GetPoint()
	assert(fill == sting.lits[4].art:GetStatusBarTexture() and at == "TOP" and sting.lits[4].mark:GetTexture():find("Wyvern"), "the fuse's head, Wyvern Sting's own mark in a flame, rides the top of what is left")
	Slots.Set(env, "target", { { id = 1978, icon = 132204, harmful = true, mine = false, start = 0, duration = 15 } })
	assert(not sting.lits[1]:IsShown() and not mark.lit:IsShown(), "another hunter's Sting leaves your fuse dark")
	assert(not pet.pet:IsShown() and not pet.feed, "no pet: the band's health and focus lights are dark and no haunch is made")
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
	K.Options.Write("ActionBars", "crestRail", false)
	local rim = Piece(ns, "crestCooldowns")
	Slots.Set(env, "pet", { { id = 19574, icon = 132127, start = 0, duration = 18 } })
	Slots.Set(env, "player", { { id = 3045, icon = 132208, start = 1, duration = 15 } })
	local seen = 0
	for _, button in ipairs(rim.sigils) do seen = seen + (button:IsShown() and 1 or 0) end
	assert(seen == 2, "Rapid Fire and the pet's Bestial Wrath both stand on the cooldown rim")
	local gust = Piece(ns, "crestGust")
	local copy = gust.lits[#gust.lits].lights.flame
	assert(Shown(copy, copy.loop) and gust.gust:GetParent():GetParent() == copy, "at Full the gust is the engine's shown animation on its feed's gated fire copy")
	assert(gust.gust:GetParent():GetAlpha() > 0, "the gust's streaks stay visible if its tween never runs")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes): the pet's perch shows a missing pet as a steel hound and a dead one in red.
	local env, K, ns = New("HUNTER", { hiding = true })
	local pet = Piece(ns, "crestPet")
	local lost = pet.lost
	assert(lost.seat:IsShown() and not lost.halo:IsShown() and lost.hound:GetTexture() == (K.Tokens.Texture("glyphHound")) and Tint(lost.hound, K, "steel"), "no pet out: a steel hound waits on the pet's perch")
	env._pet = { max = 1800, missing = 0, mood = 3 }
	env.FireEvent("UNIT_PET", "player")
	assert(not lost.seat:IsShown() and pet.pet:IsShown(), "a pet out takes the hound away")
	env._pet.missing, env._pet.dead = 1800, true
	env.FireEvent("UNIT_HEALTH", "pet")
	assert(lost.seat:IsShown() and lost.halo:IsShown() and Tint(lost.hound, K, "hostile", 0.2) and not pet.pet:IsShown(), "a dead pet: the hound turns red with a red halo and the light goes out")
	assert(not lost.breath:IsPlaying(), "the crest at rest holds the red halo still")
	env.SetTarget(true)
	assert(lost.breath:IsPlaying(), "awake at Full, the red halo breathes")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not lost.breath:IsPlaying() and lost.halo:IsShown() and Tint(lost.hound, K, "hostile", 0.2), "Calm holds the red halo still and keeps the state")
	K.Options.Write("Medallions", "motion", "off")
	assert(not lost.breath:IsPlaying() and lost.seat:IsShown() and lost.halo:IsShown(), "Off still shows the dead hound, unmoving")
	K.Options.Write("Medallions", "motion", "full")
	env._pet.dead = env.Secret(true)
	env.FireEvent("UNIT_HEALTH", "pet")
	assert(not lost.seat:IsShown() and not lost.breath:IsPlaying(), "a secret death shows no hound rather than guess")
	env._pet.dead, env._pet.missing = false, 0
	env.FireEvent("UNIT_HEALTH", "pet")
	assert(not lost.seat:IsShown() and pet.pet:IsShown(), "a revived pet clears the hound")
	env._pet = nil
	env.FireEvent("UNIT_PET", "player")
	assert(lost.seat:IsShown() and not lost.halo:IsShown() and Tint(lost.hound, K, "steel"), "a dismissed pet leaves the steel hound")
	env._pet = { max = 1800, missing = 1800, mood = 3, dead = true }
	env.FireEvent("UNIT_PET", "player")
	assert(lost.halo:IsShown() and lost.breath:IsPlaying(), "dead again at Full: the red halo breathes")
	K.Options.Write("ActionBars", "crestPet", false)
	assert(not lost.seat:IsVisible() and not lost.breath:IsPlaying(), "Pet light off hides the hound with the band and stops the red halo")
	K.Options.Write("Medallions", "motion", "calm")
	K.Options.Write("Medallions", "motion", "full")
	assert(not lost.breath:IsPlaying(), "a motion change while the hound is hidden never restarts its halo")
	K.Options.Write("ActionBars", "crestPet", true)
	assert(lost.seat:IsVisible() and lost.breath:IsPlaying(), "shown again, the dead hound's halo breathes")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 1130, 1978, 75 } })
	assert(not Seated(ns, "crestTrueshot") and not Seated(ns, "crestTracking"), "without Trueshot Aura or Improved Tracking neither seat shows")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes): Trueshot Aura steel while down and gilt while up.
	local env, K, ns = New("HUNTER", { tracking = 1494 })
	local aura = Piece(ns, "crestTrueshot")
	assert(aura:IsShown() and aura.rest:IsShown() and not aura.lit:IsShown(), "Trueshot Aura down: a steel mark on the upper left")
	assert(aura.rest:GetRegions():GetTexture() == (K.Tokens.Texture("glyphTrueshot")), "the steel mark is the face the Trueshot token names")
	Slots.Set(env, "player", { { id = 20906, icon = 132329, start = 0 } })
	assert(aura.lit:IsShown() and Tint(aura.lit.art, K, "gilt", 0.1), "Trueshot Aura up lights the mark gilt")
	Slots.Set(env, "player", {})
	assert(not aura.lit:IsShown(), "the aura gone puts the light out")
	K.Options.Write("ActionBars", "crestTrueshot", false)
	assert(not aura:IsShown() and Piece(ns, "crestTracking"):IsShown(), "Trueshot Aura sigil off hides only its seat")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes): Improved Tracking's compass gold when the tracked creature type is a hostile target's.
	local env, K, ns = New("HUNTER", { tracking = 1494 })
	local compass = Piece(ns, "crestTracking")
	assert(compass:IsShown() and not compass.rest:IsShown() and not compass.match:IsShown(), "no target: the compass shows nothing")
	env._creature = 1
	env.SetTarget(true)
	assert(compass.match:IsShown() and not compass.rest:IsShown(), "Track Beasts on a hostile beast lights the compass gold")
	env._attackable = false
	env.FireEvent("UNIT_FACTION", "target")
	assert(not compass.match:IsShown() and not compass.rest:IsShown(), "a friendly beast never lights the compass, repainted as the target's reaction changes")
	env._attackable = env.Secret(true)
	env.FireEvent("UNIT_FACTION", "target")
	assert(not compass.match:IsShown() and not compass.rest:IsShown(), "a secret reaction shows nothing rather than guess")
	env._attackable = true
	env._creature = 7
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(compass.rest:IsShown() and not compass.match:IsShown(), "a humanoid while tracking beasts: steel")
	env._tracking = 19883
	env.FireEvent("MINIMAP_UPDATE_TRACKING")
	assert(compass.match:IsShown(), "switching to Track Humanoids lights it")
	local writes = #AB.W.Calls(compass.match, "SetShown")
	env._tracking = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(#AB.W.Calls(compass.match, "SetShown") == writes and compass.match:IsShown(), "the compass repaints on its own events only")
	env.FireEvent("MINIMAP_UPDATE_TRACKING")
	assert(compass.rest:IsShown() and not compass.match:IsShown(), "no creature tracking: steel")
	env._herbs, env._tracking = true, 19883
	env.FireEvent("MINIMAP_UPDATE_TRACKING")
	assert(compass.match:IsShown(), "Find Herbs beside Track Humanoids still matches the humanoid")
	local asked, check = {}, env.issecretvalue
	env.issecretvalue = function(v) if v ~= nil then asked[v] = true end return check(v) end
	env._creature = env.Secret(7)
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.issecretvalue = check
	assert(asked[env._creature] and compass.rest:IsShown() and not compass.match:IsShown(), "a secret creature type is asked about before use and never lights the compass: steel")
	env.SetTarget(false)
	assert(not compass.rest:IsShown() and not compass.match:IsShown(), "the target gone hides the compass")
	assert(Listening(env, "MINIMAP_UPDATE_TRACKING") and Listening(env, "UNIT_FACTION"), "the compass listens for tracking and reaction changes while it is on")
	K.Options.Write("ActionBars", "crestTracking", false)
	K.Options.Write("ActionBars", "crestRange", false)
	assert(not compass:IsShown() and not Listening(env, "MINIMAP_UPDATE_TRACKING") and not Listening(env, "UNIT_FACTION"), "switched off, the compass's own events are unregistered")
	assert(Listening(env, "PLAYER_TARGET_CHANGED"), "the target event stays for the trackers that still need it")
	K.Options.Write("ActionBars", "crestTracking", true)
	assert(Listening(env, "MINIMAP_UPDATE_TRACKING") and compass.match:IsShown() == false, "switched back on, the compass listens again")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes, row 43): range and the dead zone read from the engine's range checks, never polled.
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 1130, 1978, 75, 2973, 14260, 2974 }, hiding = true })
	local reach = Piece(ns, "crestRange")
	assert(reach and reach:IsShown() and not reach.ring:IsShown(), "no target: no range ring")
	env._range[75] = true
	env.SetTarget(true)
	assert(env._rangeChecks[75] == true and env._rangeChecks[14260] == true and env._rangeChecks[2974] == nil, "a target turns on the engine's range checks for Auto Shot and the best Raptor Strike")
	assert(not reach.ring:IsShown(), "in shot range: no ring")
	env._range[75], env._range[14260] = false, false
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 75, false, true)
	assert(reach.ring:IsShown() and Tint(reach.ring, K, "hostile"), "neither the shot nor the strike reaches (the dead zone or too far): a red ring")
	env._range[14260] = true
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 14260, true, true)
	assert(reach.ring:IsShown() and Tint(reach.ring, K, "giltLit"), "only Raptor Strike reaches: a gilt ring")
	env._range[14260] = env.Secret(true)
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 14260, true, true)
	assert(not reach.ring:IsShown(), "a secret melee reading with Auto Shot out of range is unknown: no ring, never red or gilt")
	env._range[14260] = nil
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 14260, false, false)
	assert(not reach.ring:IsShown(), "a melee range the engine cannot check is unknown: no ring")
	env._range[75], env._range[14260] = env.Secret(false), false
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 75, false, true)
	assert(not reach.ring:IsShown(), "a secret shot reading with melee out of range is unknown: no ring")
	env._range[75], env._range[14260] = true, true
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 75, true, true)
	assert(not reach.ring:IsShown(), "whenever Auto Shot reaches, no ring")
	env._range[75], env._range[14260] = false, false
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 75, false, true)
	env._attackable = false
	env.FireEvent("UNIT_FACTION", "target")
	assert(not reach.ring:IsShown(), "a friendly target shows no range ring")
	assert(Updating(reach) == 0 and Listening(env, "SPELL_RANGE_CHECK_UPDATE"), "the ring follows the range event and runs no OnUpdate")
	env._attackable = true
	env._known[14260], env._known[14261] = nil, true
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(env._rangeChecks[14260] == false and env._rangeChecks[14261] == true and env._rangeChecks[75] == true, "a new Raptor Strike rank releases the old rank's range check and turns on the new one's")
	K.Options.Write("ActionBars", "crestRange", false)
	assert(not Listening(env, "SPELL_RANGE_CHECK_UPDATE"), "Range ring off unregisters the range event")
	assert(env._rangeChecks[75] == false and env._rangeChecks[14261] == false, "Range ring off releases the range checks the crest turned on")
	K.Options.Write("ActionBars", "crestRange", true)
	assert(env._rangeChecks[75] == true and env._rangeChecks[14261] == true, "Range ring on turns them on again")
	Clean(env, K)
end

do
	-- Review finding range-engine-stays-enabled: a range check something else already runs is shared, never released by the crest.
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 1130, 1978, 75, 2973 }, hiding = true })
	local reach = Piece(ns, "crestRange")
	env.FireEvent("SPELL_RANGE_CHECK_UPDATE", 2973, true, true)
	env._range[75] = true
	env.SetTarget(true)
	assert(env._rangeChecks[75] == true and env._rangeChecks[2973] == nil, "a range check another owner already runs is read but never turned on by the crest")
	K.Options.Write("HudStyle", "style", "frames")
	local row = Piece(ns, "crestRange")
	assert(not reach:IsVisible() and row ~= reach and row:IsVisible() and env._rangeChecks[75] == true, "a style change hands the range check from the crest's ring to the row's")
	K.Options.Write("ActionBars", "crestRange", false)
	assert(env._rangeChecks[75] == false and env._rangeChecks[2973] == nil, "with no ring left the crest releases its own range check and leaves the shared one alone")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes, rows 19 to 22): the pet's focus, its family ability with what it leaves, and its orders.
	local env, K, ns = New("HUNTER", { petSpells = { 24580, 24579, 2649, 14916 } })
	local pet, family, orders = Piece(ns, "crestPet"), Piece(ns, "crestPetAbility"), Piece(ns, "crestOrders")
	assert(family and family.spec.spell == 24579 and orders.spec.spell == 14916, "the pet's best known family ability and Growl take their perches")
	env._pet = { max = 1800, missing = 0, mood = 3, focus = 40 }
	env.FireEvent("UNIT_PET", "player")
	local _, high = pet.focus:GetMinMaxValues()
	assert(env.issecretvalue(high) and env.Reveal(high) == 100 and env.Reveal(pet.focus:GetValue()) == 40, "the pet's focus is a second light inside its band, the engine's values never compared")
	env._pet.focus = 70
	local health = #AB.W.Calls(pet.health, "SetValue")
	env.FireEvent("UNIT_POWER_UPDATE", "pet")
	assert(env.Reveal(pet.focus:GetValue()) == 70 and #AB.W.Calls(pet.health, "SetValue") == health, "a focus tick repaints the focus alone")
	assert(family.ready:IsShown(), "Demoralizing Screech ready: the perch is lit")
	env._spellCd[24579] = { 0, 10 }
	env.FireEvent("PET_BAR_UPDATE_COOLDOWN")
	assert(not family.ready:IsShown(), "the pet's cooldown event alone starts the perch cooling")
	env._spellCd[24579] = nil
	env.FireEvent("PET_BAR_UPDATE_COOLDOWN")
	assert(family.ready:IsShown(), "the pet's cooldown event alone brings it ready again")
	env._spellCd[24579] = { 0, 10 }
	env.FireEvent("PET_BAR_UPDATE_COOLDOWN")
	env._pet, env._spellCd[24579] = nil, nil
	env.FireEvent("UNIT_PET", "player")
	env._pet = { max = 1800, missing = 0, mood = 3, focus = 70 }
	env.FireEvent("UNIT_PET", "player")
	assert(family.ready:IsShown(), "a pet dismissed while cooling and called back after its cooldown ended shows ready")
	local screech = family.lits[2]
	Slots.Set(env, "target", { { id = 24579, icon = 132182, harmful = true, mine = false, start = 0, duration = 30 } })
	assert(not screech:IsShown(), "another hunter's pet's Demoralizing Screech never lights your perch's ring")
	Slots.Set(env, "target", { { id = 24579, icon = 132182, harmful = true, mine = true, start = 0, duration = 30 } })
	assert(screech:IsShown() and screech._cooldown == screech.timer, "your pet's Demoralizing Screech on the target lights the perch with a timer arc on its ring")
	Slots.Set(env, "player", { { id = 24604, icon = 132203, mine = false, start = 0, duration = 10 } })
	assert(not family.lits[3]:IsShown(), "another hunter's Furious Howl on you leaves the perch's gilt ring off")
	Slots.Set(env, "player", { { id = 24604, icon = 132203, mine = true, start = 0, duration = 10 } })
	assert(family.lits[3]:IsShown(), "your pet's Furious Howl on you lights the perch gilt")
	assert(orders.rest:IsShown() and not orders.match:IsShown(), "solo with Growl on autocast: the orders rest in steel")
	env._autocast[14916] = false
	env.FireEvent("PET_BAR_UPDATE")
	assert(orders.match:IsShown(), "solo with Growl off autocast: the orders light red")
	env._autocast[14916], env._grouped = true, true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(orders.match:IsShown(), "grouped with Growl on autocast: red")
	env._autocast[14916] = env.Secret(false)
	env.FireEvent("PET_BAR_UPDATE")
	assert(orders.rest:IsShown() and not orders.match:IsShown(), "a secret autocast state shows steel rather than guess")
	env._grouped = false
	env._autocast[14916] = true
	env.SetTarget(true)
	env._petTarget = "other"
	env.FireEvent("UNIT_TARGET", "pet")
	assert(orders.match:IsShown(), "the pet on another target than your hostile one: red")
	env._petTarget = "yours"
	env.FireEvent("UNIT_TARGET", "pet")
	assert(orders.rest:IsShown() and not orders.match:IsShown(), "the pet on your target: steel")
	env._pet = nil
	env.FireEvent("UNIT_PET", "player")
	assert(not orders.rest:IsShown() and not orders.match:IsShown(), "no pet: no orders")
	env._petSpells[24579], env._petSpells[24640] = nil, true
	env._spellCd[24640] = { 0, 10 }
	env.FireEvent("PET_BAR_UPDATE")
	family = Piece(ns, "crestPetAbility")
	assert(family.spec.spell == 24640 and not family.ready:IsShown(), "a scorpid swapped in takes the perch with its Scorpid Poison's own cooldown")
	K.Options.Write("ActionBars", "crestPet", false)
	K.Options.Write("ActionBars", "crestOrders", false)
	assert(not Listening(env, "UNIT_POWER_UPDATE") and not Listening(env, "UNIT_TARGET"), "the pet light and orders off unregister the pet's power and target events")
	assert(Listening(env, "PET_BAR_UPDATE_COOLDOWN"), "the pet ability perch listens for the pet's cooldown event")
	K.Options.Write("ActionBars", "crestPetAbility", false)
	assert(not Listening(env, "PET_BAR_UPDATE_COOLDOWN"), "Pet ability perch off unregisters the pet's cooldown event")
	Clean(env, K)
end

do
	-- First mate's correction on row 49 (docs/crest-coverage.md, Hunter homes): Tranquilizing Shot gets a home on the crest's lower left foot.
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 1130, 75 } })
	assert(not Seated(ns, "crestTranq"), "no Tranquilizing Shot learned: no seat")
	env._known[19801] = true
	env.FireEvent("PLAYER_TALENT_UPDATE")
	local tranq = Piece(ns, "crestTranq")
	assert(tranq and tranq.spec.spell == 19801 and ns.SlabSeats.Name(tranq.spec.seat) == "footLeft", "Tranquilizing Shot learned: its glyph sits on the crest's lower left foot")
	assert(tranq.ready:IsShown(), "ready: lit")
	env._spellCd[19801] = { 0, 20 }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not tranq.ready:IsShown() and #R.Icons(tranq, {}) == 0, "shot: it cools under its ring, with no spell icon")
	env._spellCd[19801] = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(tranq.ready:IsShown(), "cooled: lit again")
	K.Options.Write("ActionBars", "crestTranq", false)
	assert(not Seated(ns, "crestTranq"), "Tranquilizing Shot off hides its seat")
	Clean(env, K)
end

do
	-- The crest homes plan (docs/crest-coverage.md, Hunter homes, rows 29 and 61): Immolation Trap's burn on the fuse and the potion pendant.
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 1130, 13795, 75 }, bags = { [929] = 2 } })
	local sting, potion = Piece(ns, "crestSting"), Piece(ns, "crestPotion")
	local burn = sting.lits[#sting.lits]
	Slots.Set(env, "target", { { id = 14298, icon = 135813, harmful = true, mine = false, start = 0, duration = 15 } })
	assert(not burn:IsShown(), "another hunter's Immolation Trap burning your target leaves the fuse dark")
	Slots.Set(env, "target", { { id = 14298, icon = 135813, harmful = true, mine = true, start = 0, duration = 15 } })
	assert(burn:IsShown() and burn.mark:GetTexture() == (K.Tokens.Texture("sigilFireTrap")), "your own Immolation Trap's burn burns down the fuse under the fire trap's mark")
	Slots.Set(env, "target", {})
	assert(not burn:IsShown(), "the burn ended: the fuse goes dark")
	assert(potion.lit:IsShown() and potion.ready:IsShown(), "a Healing Potion in the bags hangs ready on the pendant")
	env._cooling[929] = { 0, 120 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not potion.ready:IsShown(), "a potion drunk: the pendant cools")
	env._cooling[929] = nil
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(potion.ready:IsShown(), "the potions recharged: the pendant hangs ready again")
	env._bags[929] = 0
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(not potion.lit:IsShown(), "no potion left: the pendant is empty")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 883, 3045, 75 } })
	assert(not Seated(ns, "crestGust"), "the crest plan moves Rapid Fire to the cooldown rail: alone it brings no gust while the rail shows")
	K.Options.Write("ActionBars", "crestRail", false)
	local gust = Piece(ns, "crestGust")
	assert(gust, "with the rail off, Rapid Fire alone brings the gust, without Deadly Aspects")
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
	assert(corruption.lit:GetParent():IsShown() and corruption.rune.loop and corruption.rune:GetParent():GetParent() == corruption.lit:GetParent().lights.flame and corruption.neck:GetParent() == corruption.lit:GetParent(), "your Corruption lights its spire, the glyph's aura at its foot and the neck between")
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

for class, keys in pairs({ HUNTER = { "crestShot", "crestAspect", "crestPet", "crestMark", "crestSting", "crestAutoShot", "crestGust", "crestCooldowns", "crestRail", "crestTrueshot",
	"crestTracking", "crestRange", "crestPetAbility", "crestOrders", "crestPotion" },
	MAGE = { "crestArmor", "crestManaGem", "crestCounterspell", "crestSchool", "crestFrozen", "crestYourSpell", "crestWard", "crestClearcasting", "crestCooldowns" },
	WARLOCK = { "crestTorments", "crestWisps", "crestDemon", "crestHealthstone", "crestStone", "crestConflagrate", "crestCurse", "crestSpellLock", "crestTrance", "crestCooldowns" } }) do
	local deterrence = class == "HUNTER" and { 13165, 883, 1130, 1978, 19552, 3045, 19574, 75, 2643, 19263, 19506, 24293 } or nil
	local env, K, ns = New(class, { known = deterrence, tree = deterrence and 1, bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 },
		petSpells = { 24579, 14916 } })
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
	local fenv, FK, fns = New(class, { frames = true, bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 }, petSpells = { 24579, 14916 } })
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
