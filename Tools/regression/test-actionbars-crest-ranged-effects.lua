-- test-actionbars-crest-ranged-effects.lua: a hunter's, mage's and warlock's crest pieces break out of the medal into the crest: on the crest and under Frames, at rest and with every piece lit, none is a spell or item icon or sits in a round socket frame (a medal disc, an orb or medal ring, a rune stone, a spire socket); each piece takes its feed and shows its states: your damage over time a fuse down the right band whose head rides what is left and blinks in the aura's pandemic window, the Mark's reticle closing in over the emblem, a mage's armor crystals thawing from the far end, Frost Nova's frost over the inner ring, a school's stacks as embers and a cooldown as an arc filling along the left band, a bag gem hanging from the band and charging when used, an interrupt's blade charging on the lower left, the demon's health and sigil on the left band and Demonic Sacrifice's fel flames; each sits on its break-out seat; with auras secret in combat no event or ended cooldown touches a region under an engine aura button.
local R = dofile("Tools/regression/ranged_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local Png = dofile("Tools/regression/png.lua")
-- The socketed crest on staging 3e037a6be measured 229,200 addon instructions and 1,700 widget calls for a hundred unchanged
-- mage cooldown updates, and 46,100 and 2,000 for a hundred warlock pet health ticks, with this fixture.
local BUDGET_COOLDOWN, BUDGET_HEALTH = { 229200, 1700 }, { 46100, 2000 }
local AB, Slots, New, Piece, Seated, Shown, Clean, Tint, Icons = R.AB, R.Slots, R.New, R.Piece, R.Seated, R.Shown, R.Clean, R.Tint, R.Icons

local SHARED = { crestCooldowns = true }
local LIGHT = {
	HUNTER = { player = { 14318 }, target = { 1130, 1978 }, pet = { 136 }, usable = { 2643 } },
	MAGE = { player = { 7302, 11426, 12536 }, target = { 116, 122, 22959 } },
	WARLOCK = { player = { 18789 }, target = { 172, 980, 348, 18265, 702 } },
}

-- Sockets(frame, files, found) -> found, listing every region under frame that draws a round socket frame's art.
local function Sockets(frame, files, found)
	for _, region in ipairs(frame._regions or {}) do
		local texture = region._type ~= "MaskTexture" and region._state and region._state.Texture
		if texture and files[texture[1]] then found[#found + 1] = files[texture[1]] end
	end
	for _, kid in ipairs(frame._kids or {}) do Sockets(kid, files, found) end
	return found
end

for class, light in pairs(LIGHT) do
	for _, frames in ipairs({ false, true }) do
		local env, K, ns = New(class, { frames = frames, trinket = true, bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
		local files = {}
		for _, token in ipairs({ "dot", "medRing", "medEnamel", "medSlotSocket", "medSlotChecked", "orbRing", "trackerStone" }) do files[(K.Tokens.Texture(token))] = token end
		assert(next(ns.SlabTrackers.state.form.failed) == nil, class .. ": every seat builds")
		assert(Seated(ns, "crestTrinkets") and Seated(ns, "crestShot") ~= false, class .. ": an on-use trinket in slot 13 joins the crest and the update runs to the end")
		local function Check(state)
			local found, sockets = {}, {}
			for _, p in pairs(ns.SlabTrackers.state.form.pieces) do
				Icons(p, found)
				if not SHARED[p.spec.key] then Sockets(p, files, sockets) end
			end
			local at = class .. (frames and " under Frames" or " on the crest") .. ", " .. state
			assert(#found == 0, at .. ": every piece is an effect, never a spell or item icon (" .. table.concat(found, ", ") .. ")")
			assert(#sockets == 0, at .. ": every piece breaks out of its socket, no round socket frame (" .. table.concat(sockets, ", ") .. ")")
		end
		Check("at rest")
		for unit, ids in pairs(light) do
			local auras = {}
			for _, id in ipairs(unit ~= "usable" and ids or {}) do auras[#auras + 1] = { id = id, icon = 135000 + #auras, harmful = unit == "target", start = 0, duration = 30 } end
			if unit == "usable" then
				for _, id in ipairs(ids) do env._usable[id] = true end
			else
				Slots.Set(env, unit, auras)
			end
		end
		env._petSpells[19244] = true
		env._cooling[5514], env._cooling[5512] = { 0, 120 }, { 0, 120 }
		for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" }) do env.FireEvent(event) end
		env.FireEvent("UNIT_PET", "player")
		env.FireEvent("PLAYER_SWING", 2.8, 2)
		Check("every piece lit")
		Clean(env, K)
	end
end

-- Art(region) -> the file a lit region draws, a texture's or a status bar's.
local function Art(region)
	return ((region._barTexture or region)._state.Texture or {})[1]
end

-- Drawn(frame, file, add) -> the frame's own region drawing that file, additive or solid.
local function Drawn(frame, file, add)
	for _, region in ipairs(frame._regions) do
		local state = region._state or {}
		if state.Texture and tostring(state.Texture[1]):find(file, 1, true) and ((state.BlendMode or {})[1] == "ADD") == add then return region end
	end
end

-- Same(what, { r, g, b }, er, eg, eb): the expected colour last.
local function Same(what, rgb, er, eg, eb)
	assert(math.abs(rgb[1] - er) < 1e-4 and math.abs(rgb[2] - eg) < 1e-4 and math.abs(rgb[3] - eb) < 1e-4, what .. ": " .. table.concat(rgb, ", "))
end

-- Kinds(piece, field) -> how many different arts its lights draw in that field.
local function Kinds(p, field)
	local seen, n = {}, 0
	for _, lit in ipairs(p.lits) do
		local art = lit[field or "art"] and Art(lit[field or "art"])
		if art and not seen[art] then seen[art], n = true, n + 1 end
	end
	return n
end

-- Seat(ns, piece) -> the piece's centre from the hub's, in hub units.
local function Seat(ns, p)
	local _, _, _, x, y = p:GetPoint()
	local s = p:GetEffectiveScale() / ns.Slab.hub:GetEffectiveScale()
	return x * s, y * s
end

-- At(ns, piece, x, y) -> whether the piece sits there, in hub units; Near(ns, piece, r, angle) the same in polar terms.
local function At(ns, p, ax, ay)
	local x, y = Seat(ns, p)
	return math.abs(x - ax) < 1.5 and math.abs(y - ay) < 1.5
end

local function Near(ns, p, r, angle)
	return At(ns, p, r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)))
end

-- Pandemic(env, unit, aura) feeds the aura again inside its pandemic window.
local function Pandemic(env, unit, aura)
	aura.pandemic = true
	Slots.Set(env, unit, { aura })
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 13163, 5118, 13159, 20043, 13161, 415423, 1978, 3034, 3043, 24118, 3674, 1130, 883, 2643 }, pet = { max = 100, missing = 40, mood = 3 } })
	local aspect, sting, mark, pet, shot = Piece(ns, "crestAspect"), Piece(ns, "crestSting"), Piece(ns, "crestMark"), Piece(ns, "crestPet"), Piece(ns, "crestShot")
	assert(#aspect.lits == 7 and Kinds(aspect) == 7, "each Aspect lights its own sigil: hawk, crescents, paw, pack, leaf, claws, coil")
	assert(#sting.lits == 6 and Kinds(sting, "mark") == 6, "each Sting, Lacerate and Black Arrow carries its own mark at the fuse's head")
	assert(Near(ns, aspect, 73, 228) and At(ns, mark, 0, 0) and At(ns, shot, 0, 0), "the Aspect perches on the lower left; the Mark and the shots sit over the emblem")
	assert(At(ns, sting, 64, 0) and At(ns, pet, 42, -46), "the fuse burns down the right band and the pet's light runs along the lower right band")
	local serpent = { id = 1978, harmful = true, start = 0, duration = 15 }
	Slots.Set(env, "target", { serpent })
	local lit = sting.lits[1]
	assert(lit:IsShown() and not sting.lits[3]:IsShown() and lit._durationBar[1] == lit.art and lit.art:GetOrientation() == "VERTICAL", "Serpent Sting's fuse is a duration bar burning down the band")
	assert(Shown(lit, lit.flare.play) and Shown(lit, lit.loop), "the fuse's mark ignites and its head flickers as the engine's animations")
	local r, g, b = lit.mark:GetVertexColor()
	assert(r + g + b < 2.6, "the serpent keeps its colour rather than burning white")
	local burn, seat = lit.head._kids[1], lit.head._kids[2]
	assert(#lit._regions + #lit.head._regions == 0 and #burn._regions == 1 and #burn._kids == 0, "the head's flicker holds the flame alone")
	-- A Sting's mark cannot be read at 16 units over the ring's runes, so it draws at 24 units,
	-- moved 14 units in from the fuse onto a dark shade, steady while the flame flickers; at that size the gold rule applies.
	local whole = lit.mark:GetParent()
	local body = Drawn(whole, "Serpent.png", false)
	assert(body.units == 24 and select(4, seat:GetPoint(1)) == -14 and whole:GetParent() == seat, "Serpent Sting's mark is 24 units, 14 in from the fuse's head")
	Same("its body is gold, coinGold f0c75e", { body:GetVertexColor() }, 0xf0 / 255, 0xc7 / 255, 0x5e / 255)
	Same("its halo is the Sting's colour, schoolNature 6fdc5a", { Drawn(whole, "Glow.png", true):GetVertexColor() }, 0x6f / 255, 0xdc / 255, 0x5a / 255)
	assert(#seat._regions == 2 and Drawn(seat, "Glow.png", false) and not Drawn(seat, "Glow.png", true), "it sits on a soft dark shade, never a socket")
	assert(lit.mark:GetAlpha() == 0.15 and lit.flare.play:GetParent() == whole, "the lit pass is a sheen and the ignition grows the whole mark")
	Same("Wyvern Sting's halo is schoolFire ff8a3d, apart from Black Arrow's violet", { Drawn(sting.lits[4].mark:GetParent(), "Glow.png", true):GetVertexColor() }, 0xff / 255, 0x8a / 255, 0x3d / 255)
	Same("Black Arrow's halo is schoolShadow 9d7bff", { Drawn(sting.lits[6].mark:GetParent(), "Glow.png", true):GetVertexColor() }, 0x9d / 255, 0x7b / 255, 0xff / 255)
	assert(aspect.rest:GetAlpha() == 0.85, "an unlit forged Aspect rests at 0.85 so its outline shows on the ring")
	-- The unlit mark never hides, so a lit Aspect other than the Hawk blacks it out; the backing must hold still while the figure breathes and blooms.
	local function Backing(slot)
		for _, kid in ipairs(slot._kids) do
			local t = Drawn(kid, "Hawk.png", false)
			if t and t:GetVertexColor() == 0 then return t, kid end
		end
	end
	local monkey = aspect.lits[2]
	local cover, steady = Backing(monkey)
	local figure = monkey.art:GetParent()
	assert(cover and cover.units == 35, "a lit Monkey blacks out the unlit hawk behind it at its 35 units (the 28-unit perch at the look's 1.25)")
	Same("the backing is black", { cover:GetVertexColor() }, 0, 0, 0)
	assert(select(4, cover:GetVertexColor()) == 1 and cover:GetAlpha() == 1 and steady:GetAlpha() == 1, "and opaque")
	assert(steady:GetParent() == monkey and steady ~= figure and steady ~= figure:GetParent(), "it sits on the aura slot itself, outside the breathing light and the blooming figure")
	assert(not Backing(aspect.lits[1]) and not Drawn(aspect.lits[1].art:GetParent(), "Monkey.png", false), "the lit Hawk covers the unlit hawk itself and draws no backing")
	-- The captain's answer on the plan: a lit mark is a gold body with the spell's colour as a halo behind it (24 units and above).
	Slots.Set(env, "player", { { id = 415423, start = 0 } })
	local viper = aspect.lits[7]
	local cast = viper.art:GetParent()
	Same("Aspect of the Viper's body is gold, coinGold f0c75e", { Drawn(cast, "Viper.png", false):GetVertexColor() }, 0xf0 / 255, 0xc7 / 255, 0x5e / 255)
	Same("its halo is the spell's colour, magic 5aa9ff", { Drawn(cast, "Glow.png", true):GetVertexColor() }, 0x5a / 255, 0xa9 / 255, 0xff / 255)
	assert(viper:IsShown() and viper.art:GetAlpha() == 0.15 and viper.flare.play:GetParent() == cast, "the lit pass is a sheen over the body and the landing grows the whole mark")
	Slots.Set(env, "player", nil)
	assert(lit._pandemicAnimations[1] == lit.flicker and not lit.flicker:IsPlaying(), "the ending blink waits for the pandemic window")
	Pandemic(env, "target", serpent)
	assert(lit.flicker:IsPlaying(), "inside the pandemic window the fuse blinks")
	local hunters = { id = 1130, harmful = true, start = 0, duration = 120 }
	Slots.Set(env, "target", { hunters })
	assert(mark.lit:IsShown() and not lit:IsShown() and mark.lit._pandemicAnimations[1] == mark.lit.flicker, "Hunter's Mark lights the reticle over the emblem")
	Pandemic(env, "target", hunters)
	assert(mark.lit.flicker:IsPlaying(), "the Mark blinks at its end")
	local alpha, w = Png.Alpha(Art(mark.lit.art):gsub("\\", "/"):match("Media/.+$"))
	assert(alpha(w / 2, w / 2) > 128, "the reticle has an eye at its centre")
	env.FireEvent("UNIT_PET", "player")
	assert(pet.pet:IsShown() and Tint(pet.mood, K, "friendly"), "a happy pet's ember glows green at the end of its light")
	local mend = pet.lits[#pet.lits]
	assert(mend.loops[1]:GetParent():GetAlpha() > 0, "Mend Pet's motes show with no animation running")
	for _, each in ipairs(aspect.lits) do
		assert(#each._regions == 0 and not each.awake and Shown(each, each.flare.play), "each Aspect's sigil blooms itself as it lands, with no extra glow or flare")
	end
	K.Options.Write("ActionBars", "crestSting", false)
	assert(not sting:IsShown() and mark.lit:IsShown(), "Your Sting off puts the fuse out alone")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 13163, 19306, 1495, 2643, 20900 } })
	env.SetTarget(true)
	local shot = Piece(ns, "crestShot")
	env._usable[2643] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local multi = shot.shots[shot.spec.shots[2643]]
	assert(multi:IsShown() and #multi._regions == 4 and shot.flare == multi and multi.play:IsPlaying(), "Multi-Shot ready rises three arrows up the emblem")
	env._usable[19306] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local counter = shot.shots[shot.spec.shots[19306]]
	assert(counter:IsShown() and not multi:IsShown() and Art(counter._regions[2]):find("Counter"), "Counterattack after a parry crosses two crimson blades over the emblem")
	assert(shot.flare == counter and counter.play:IsPlaying() and #AB.W.Calls(counter.play, "Play") == 1, "the parry's opening double-flashes even with Multi-Shot already up")
	local bite = shot.shots[shot.spec.shots[1495]]
	assert(Drawn(counter, "Counter.png", false).units == 36 and Drawn(bite, "Mongoose.png", false).units == 36, "the forged shots' solid bodies are 36 units, 0.45 of the 80-unit emblem, so its painting shows round them")
	local writes = #AB.W.Calls(counter, "Show") + #AB.W.Calls(counter, "Hide") + #AB.W.Calls(multi, "Show") + #AB.W.Calls(multi, "Hide")
	for _ = 1, 50 do
		env.FireEvent("SPELL_UPDATE_USABLE")
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
	end
	local after = #AB.W.Calls(counter, "Show") + #AB.W.Calls(counter, "Hide") + #AB.W.Calls(multi, "Show") + #AB.W.Calls(multi, "Hide")
	assert(after == writes, "unchanged shots repaint nothing (" .. after - writes .. " writes)")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 2973, 3044 } })
	env.SetTarget(true)
	local raptor, arcane = Piece(ns, "crestAspect", 2), Piece(ns, "crestPet", 2)
	assert(At(ns, raptor, 0, 0) and At(ns, arcane, 0, 0) and raptor.ready:GetAlpha() == 0 and not raptor.rest:IsShown(),
		"before the Aspect and the pet, Raptor Strike and Arcane Shot flash over the emblem and hold nothing there")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not raptor.ready:IsShown() and AB.W.LastCall(raptor.timer, "SetCooldownFromDurationObject") and raptor.timer._state.DrawSwipe[1] == false,
		"a strike on cooldown runs an unseen timer, no ring round the emblem")
	raptor.timer:GetScript("OnCooldownDone")(raptor.timer)
	assert(raptor.ready:IsShown() and raptor.flare.play:IsPlaying(), "and flashes the moment it is ready")
	-- The approved plan for the crest marks puts the flash under the forged rule: the flash is all a strike shows on the crest.
	Same("Raptor Strike's flash is the gold talon, coinGold f0c75e", { Drawn(raptor.flare, "Raptor.png", false):GetVertexColor() }, 0xf0 / 255, 0xc7 / 255, 0x5e / 255)
	Same("haloed in its colour, gilt d3b574", { Drawn(raptor.flare, "Glow.png", true):GetVertexColor() }, 0xd3 / 255, 0xb5 / 255, 0x74 / 255)
	assert(math.abs(Drawn(raptor.flare, "Raptor.png", false).units - 41.4) < 1e-6, "at 41.4 units (the 36-unit flash at the orb look's 1.15), so the painted emblem shows round it")
	assert(#arcane.flare._regions == 1 and arcane.flare._regions[1]._state.BlendMode[1] == "ADD", "Arcane Shot's flat orb still flashes as one additive texture")
	Same("in white, not its spell's colour", { arcane.flare._regions[1]:GetVertexColor() }, 1, 1, 1)
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 168, 6117, 759, 2139, 122, 11958, 11095 } })
	local armor, counter, frozen, fire, gem = Piece(ns, "crestArmor"), Piece(ns, "crestCounterspell"), Piece(ns, "crestFrozen"), Piece(ns, "crestSchool"), Piece(ns, "crestManaGem")
	assert(Near(ns, counter, 73, 228) and Near(ns, gem, 80, 312), "Counterspell's blade thrusts through the lower left; the mana gem hangs from the lower right")
	assert(At(ns, armor, -37, 51) and At(ns, frozen, 0, -39), "the armor grows along the upper left band; the frost lies over the inner ring")
	local ice = { id = 7302, start = 0, duration = 1800 }
	Slots.Set(env, "player", { ice })
	local frost = armor.lits[1]
	assert(frost:IsShown() and not armor.lits[2]:IsShown() and frost._durationBar[1] == frost.art and frost.art:GetReverseFill() and frost.art:GetOrientation() == "HORIZONTAL",
		"Ice Armor's crystals are a duration bar that thaws from the far end")
	assert(Shown(frost, frost.loops[1]) and Art(frost.art):find("ArmorFrost"), "the crystals grow in on apply")
	Pandemic(env, "player", ice)
	assert(frost.flicker:IsPlaying(), "the armor blinks as it runs out")
	Slots.Set(env, "player", { { id = 22782, start = 0, duration = 1800 } })
	assert(armor.lits[2]:IsShown() and not frost:IsShown() and Art(armor.lits[2].art):find("ArmorArcane"), "Mage Armor grows its own arcane runes")
	assert(counter.spec.look == "shard" and counter.bar and counter.bar:GetStatusBarTexture()._state.Desaturated ~= true, "Counterspell is a crystal blade in its own colours")
	Slots.Set(env, "target", { { id = 122, harmful = true, start = 0, duration = 8 } })
	assert(frozen.lit:IsShown() and frozen.lit._durationBar[1] == frozen.lit.art and Art(frozen.lit.art):find("Frost") and frozen.lit.art._state.FillStyle[1] == "CENTER",
		"your Frost Nova frosts the inner ring and recedes to its lowest point with its time, no hard cut along the rim")
	for _, count in ipairs({ 1, 3, 5 }) do
		Slots.Set(env, "target", { { id = 22959, harmful = true, start = 0, duration = 30, count = count } })
		local lit = 0
		for _, part in ipairs(fire.parts) do
			if part._count then
				local _, high = part:GetMinMaxValues()
				lit = lit + (env.Reveal(part:GetValue()) >= high and 1 or 0)
			end
		end
		assert(lit == count, count .. " stacks of Fire Vulnerability light " .. count .. " embers along the left band (" .. lit .. ")")
	end
	local vulnerable = { id = 22959, harmful = true, start = 0, duration = 30, count = 5 }
	Slots.Set(env, "target", { vulnerable })
	Pandemic(env, "target", vulnerable)
	local blinking = 0
	for _, each in ipairs(fire.lits) do blinking = blinking + (each.flicker and each.flicker:IsPlaying() and 1 or 0) end
	assert(blinking == 5, "the five embers blink as Fire Vulnerability runs out (" .. blinking .. ")")
	Clean(env, K)
end

-- The approved plan forges the hunter's three cooldown sigils too: under 24 units, a solid body under the lit pass at 0.6.
do
	local env, K, ns = New("HUNTER", { known = { 3045 } })
	local volley = Piece(ns, "crestCooldowns").sigils[1]
	assert(Drawn(volley, "Volley.png", false) and Drawn(volley, "Volley.png", true):GetAlpha() == 0.6, "Rapid Fire's cooldown sigil is a solid body under its lit pass")
	Clean(env, K)
end

-- The approved plan keeps the forged rule behind a per-texture flag: a class still on flat art draws as before.
do
	local env, K, ns = New("MAGE", { known = { 118, 12042 } })
	Slots.Set(env, "target", { { id = 118, harmful = true, start = 0, duration = 50 } })
	local lit = Piece(ns, "crestYourSpell", 3).lit
	local burn = lit.mark:GetParent()
	assert(lit:IsShown() and burn == lit.head._kids[1] and #burn._regions == 2 and #burn._kids == 0, "Polymorph's flat mark is one additive texture beside the flame, no body and no layer of its own")
	assert(lit.mark:GetAlpha() == 1 and lit.mark._state.BlendMode[1] == "ADD" and lit.flare.play:GetParent() == lit.mark, "it keeps its full light and its own ignition")
	local arcane = Piece(ns, "crestCooldowns").sigils[1]
	assert(Drawn(arcane, "Arcane.png", true):GetAlpha() == 1 and not Drawn(arcane, "Arcane.png", false), "a flat cooldown sigil is its one additive texture at full light, with no solid body")
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 1326079 } })
	local arc = Piece(ns, "crestSchool", 3)
	env.SetTarget(true)
	assert(At(ns, arc, -64, 0) and arc.ready:IsShown() and arc.bar:GetOrientation() == "VERTICAL", "Arcane Wrath ready: a full arc on the left band with its orb at the tip")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not arc.ready:IsShown() and AB.W.LastCall(arc.bar, "SetTimerDuration"), "cast, the arc empties and fills again over its cooldown")
	arc.timer:GetScript("OnCooldownDone")(arc.timer)
	assert(arc.ready:IsShown() and arc.flare.play:IsPlaying(), "ready, the orb flares at the tip")
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 688, 691, 6201, 18788, 702, 17962, 2362 }, pet = { max = 100, missing = 25 } })
	local demon, stone, curse = Piece(ns, "crestDemon"), Piece(ns, "crestHealthstone"), Piece(ns, "crestCurse")
	assert(At(ns, demon, -64, 0) and demon.pet:IsShown() and demon.health:GetOrientation() == "VERTICAL" and demon.health:GetReverseFill(), "the demon's health lights the left band from the top")
	assert(env.Reveal(demon.health:GetValue()) == 75 and demon.sigil:IsShown(), "its health is the engine's value, under the demon's sigil")
	env._petSpells[3110] = true
	env.FireEvent("UNIT_PET", "player")
	assert(Art(demon.glyph):find("Imp"), "an Imp out shows the Imp's sigil")
	assert(Near(ns, stone, 80, 312), "the Healthstone hangs from the lower right")
	assert(not stone.lit:IsShown() and not stone.rest:IsVisible() and stone.bail:IsVisible() and Art(stone.bail):find("Bail"), "no Healthstone: the empty bail hangs there")
	env._bags[5512] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(stone.lit:IsShown() and stone.ready:IsShown() and Tint(stone.lit.glow, K, "friendly"), "a Healthstone in the bags hangs a green gem")
	local count, cooldown = env.C_Item.GetItemCount, env.C_Item.GetItemCooldown
	local reads = 0
	env.C_Item.GetItemCount = function(...) reads = reads + 1 return count(...) end
	env.C_Item.GetItemCooldown = function(...) reads = reads + 1 return cooldown(...) end
	env._cooling[5512] = { 100, 120 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not stone.ready:IsShown() and AB.W.LastCall(stone.timer, "SetCooldown"), "a used Healthstone goes dark and its ring charges")
	assert(reads <= 14, "one bag scan per bag cooldown (" .. reads .. " reads)")
	env.C_Item.GetItemCount, env.C_Item.GetItemCooldown = count, cooldown
	K.Options.Write("Medallions", "motion", "full")
	env.SetTarget(true)
	assert(demon.bob:IsPlaying(), "awake, the demon's sigil bobs")
	K.Options.Write("Medallions", "motion", "calm")
	assert(not demon.bob:IsPlaying(), "Calm holds the sigil still")
	env._pet = nil
	env.FireEvent("UNIT_PET", "player")
	Slots.Set(env, "player", { { id = 18792, start = 0, duration = 1800 } })
	local sacrifice = demon.lit
	assert(sacrifice:IsShown() and sacrifice._durationBar[1] == sacrifice.art and Art(sacrifice.art):find("RimLeft"), "Demonic Sacrifice burns fel flames along the left band, its rim line draining")
	local fel = {}
	for _, slot in pairs(sacrifice.container._slots) do
		if slot.frame:IsShown() and slot.frame._regions[1] then fel[#fel + 1] = Art(slot.frame._regions[1]) end
	end
	assert(#fel == 1 and fel[1]:find("Fangs") and not demon.pet:IsShown(), "the sacrificed Felhunter's sigil stays on the band, turned fel")
	env._pet = { max = 100, missing = 25 }
	Slots.Set(env, "target", { { id = 702, harmful = true, start = 0, duration = 120 } })
	assert(curse.lits[1]:IsShown() and curse.lits[1]._durationBar[1] == curse.lits[1].art and At(ns, curse, 64, 0), "your Curse of Weakness burns its fuse down the right band")
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	local lock = Seated(ns, "crestSpellLock")
	assert(lock.spec.look == "blade" and lock.bar and Near(ns, lock, 73, 228), "a Felhunter's Spell Lock is a blade through the lower left that charges over its cooldown")
	Clean(env, K)
	local fenv, FK, fns = New("WARLOCK", { frames = true, trinket = true, known = { 688, 6201, 17962, 2362 }, pet = { max = 100, missing = 0 } })
	local jewel, well, trinket, fdemon = Piece(fns, "crestConflagrate"), Piece(fns, "crestFiveSecond"), Seated(fns, "crestTrinkets"), Piece(fns, "crestDemon")
	assert(jewel.bar and well.timer and trinket.bar, "under Frames Conflagrate and the trinket are jewels and the five-second rule a ring, as every class's")
	assert(fdemon.units == 26 and fdemon.health and fdemon.sigil, "under Frames the demon's light and sigil stand free in the row")
	Clean(fenv, FK)
	local tenv, TK, tns = New("WARLOCK", { known = { 172, 980, 348, 18265 } })
	local spires = Piece(tns, "crestTorments")
	local immolate = { id = 348, harmful = true, start = 0, duration = 15 }
	Slots.Set(tenv, "target", { immolate })
	Pandemic(tenv, "target", immolate)
	assert(spires.lits[3].flicker and spires.lits[3].flicker:IsPlaying() and not spires.lits[1].flicker:IsPlaying(), "Immolate's spire blinks as it runs out")
	Clean(tenv, TK)
end

-- Frames stands the crest's own objects in the row, sized to it: the same fuse with its head, reticle closing in, crystals, frost and arc.
for class, keys in pairs({ HUNTER = { crestSting = "ArcRight", crestMark = "MarkReticle" }, MAGE = { crestArmor = "ArmorFrost", crestFrozen = "Frost", crestYourSpell = "ArcRight" },
	WARLOCK = { crestCurse = "ArcRight" } }) do
	local env, K, ns = New(class, { frames = true, known = class == "MAGE" and { 168, 759, 2139, 122, 116, 118, 1326079 } or nil })
	for key, art in pairs(keys) do
		local p = Seated(ns, key)
		assert(p and p.units == 26 and Art(p.lit.art):find(art), class .. " " .. key .. " under Frames is the crest's own " .. art .. ", sized to the row")
		assert(not p.lit.mark or p.lit.head and select(2, p.lit.head:GetPoint()) == p.lit.art:GetStatusBarTexture(), class .. " " .. key .. " keeps its moving head under Frames")
	end
	if class == "HUNTER" then
		local mark = Seated(ns, "crestMark").lit
		assert(Shown(mark, mark.loops[2]), "the Frames reticle closes in")
	elseif class == "MAGE" then
		local arc = Seated(ns, "crestSchool")
		assert(arc.bar and Art(arc.bar):find("ArcLeft"), "the Frames Arcane Wrath is the charging arc, not an orb")
	end
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 759 }, bags = { [5514] = 1 } })
	local gem = Piece(ns, "crestManaGem")
	K.Options.Write("Medallions", "motion", "full")
	env.SetTarget(true)
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	assert(gem.lowMana:IsShown() and gem.pulse:IsPlaying(), "below 30% mana the ready gem pulses")
	Clean(env, K)
end

-- The two hot tracker events cost no more than the socketed crest's did: an unchanged cooldown update for a mage and a pet health tick for a warlock.
for class, case in pairs({ MAGE = { "SPELL_UPDATE_COOLDOWN", nil, BUDGET_COOLDOWN }, WARLOCK = { "UNIT_HEALTH", "pet", BUDGET_HEALTH } }) do
	local env, K = New(class, { pet = { max = 100, missing = 10 }, bags = { [5512] = 1, [5514] = 1 } })
	env.FireEvent(case[1], case[2])
	local used = Budget.Count(env, function() for _ = 1, 100 do env.FireEvent(case[1], case[2]) end end, 1)
	Budget.Check(used, case[3][1], case[3][2], class .. " " .. case[1] .. " repaints only what changed")
	print(string.format("%s %s x100: %d addon instructions, %d widget calls", class, case[1], used.instructions, used.calls))
	Clean(env, K)
end

for class in pairs(LIGHT) do
	local env, K, ns = New(class, { bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 }, known = class == "HUNTER" and { 2973, 3044, 1130, 1978, 75, 2643 } or nil })
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	env.SetTarget(true)
	env._aurasSecret = true
	env.SetCombat(true)
	for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED", "SPELLS_CHANGED" }) do env.FireEvent(event) end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	env.FireEvent("UNIT_HEALTH", "pet")
	env.FireEvent("PLAYER_SWING", 2.8, 2)
	env.FireEvent("UNIT_PET", "player")
	local ended = 0
	for _, p in pairs(ns.SlabTrackers.state.form.pieces) do
		local done = p.timer and p.lit and not p.lit.container and p.timer:GetScript("OnCooldownDone")
		if done then done(p.timer) ended = ended + 1 end
	end
	assert(ended > 0, class .. ": a cooldown ends in combat")
	K.Options.Write("Medallions", "motion", "calm")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	Clean(env, K)
end

print("actionbars crest ranged effects ok")
