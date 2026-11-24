-- test-actionbars-crest-ranged-effects.lua: a hunter's, mage's and warlock's crest seats are effects, never spell or item icons, on the crest and under Frames, at rest and with every piece lit; each effect takes its feed and shows its states: an orb charges over a cooldown and glows and flares when ready, a shield or stone lights in its buff's colour and drains its ring, a flame burns down over your debuff, an ice glint and a fel wisp drain their rings, a gem is empty, lit or charging from the bags, a blade charges for an interrupt, and the five-second rule under Frames is the level badge's ring; with auras secret in combat no event or ended cooldown touches a region under an engine aura button.
local R = dofile("Tools/regression/ranged_env.lua")
local AB, Slots, New, Piece, Seated, Shown, Clean, Tint, Icons = R.AB, R.Slots, R.New, R.Piece, R.Seated, R.Shown, R.Clean, R.Tint, R.Icons

local LIGHT = {
	HUNTER = { player = { 14318 }, target = { 1130, 1978 }, pet = { 136 }, usable = { 2643 } },
	MAGE = { player = { 7302, 11426, 12536 }, target = { 116, 122, 22959 } },
	WARLOCK = { player = { 18789 }, target = { 172, 980, 348, 18265, 702 } },
}
for class, light in pairs(LIGHT) do
	for _, frames in ipairs({ false, true }) do
		local env, K, ns = New(class, { frames = frames, trinket = true, bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
		assert(next(ns.SlabTrackers.state.form.failed) == nil, class .. ": every seat builds")
		assert(Seated(ns, "crestTrinkets") and Seated(ns, "crestShot") ~= false, class .. ": an on-use trinket in slot 13 joins the crest and the update runs to the end")
		local function Check(state)
			local found = {}
			for _, p in pairs(ns.SlabTrackers.state.form.pieces) do
				Icons(p, found)
			end
			assert(#found == 0, class .. (frames and " under Frames" or " on the crest") .. ", " .. state .. ": every piece is an effect, never a spell or item icon (" .. table.concat(found, ", ") .. ")")
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

-- Kinds(piece) -> how many different arts its lights draw.
local function Kinds(p)
	local seen, n = {}, 0
	for _, lit in ipairs(p.lits) do
		local art = lit.art and Art(lit.art)
		if art and not seen[art] then seen[art], n = true, n + 1 end
	end
	return n
end

do
	local env, K, ns = New("HUNTER", { known = { 13165, 13163, 5118, 13159, 20043, 13161, 415423, 1978, 3034, 3043, 24118, 3674 } })
	local aspect, sting = Piece(ns, "crestAspect"), Piece(ns, "crestSting")
	assert(#aspect.lits == 7 and Kinds(aspect) == 7, "each Aspect lights its own glyph: hawk, crescents, paw, pack, leaf, claws, coil")
	assert(#sting.lits == 6 and Kinds(sting) == 6, "each Sting, Lacerate and Black Arrow burns its own mark")
	Slots.Set(env, "target", { { id = 3043, harmful = true, start = 0, duration = 20 } })
	assert(sting.lits[3]:IsShown() and not sting.lits[1]:IsShown() and sting.lits[3]._durationBar[1] == sting.lits[3].art, "Scorpid Sting burns its hook down, not the serpent")
	Clean(env, K)
	local wenv, WK, wns = New("WARLOCK")
	assert(Kinds(Piece(wns, "crestCurse")) == 5, "each Curse burns its own mark")
	local spires = Piece(wns, "crestTorments").spires
	assert(Art(spires[1].rune) ~= Art(spires[3].rune), "each torment socket has its own glyph")
	Clean(wenv, WK)
end

do
	local env, K, ns = New("HUNTER", { known = { 13163, 19306, 1495, 2643, 20900 } })
	env.SetTarget(true)
	local shot = Piece(ns, "crestShot")
	env._usable[2643] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(shot.lit:IsShown() and Art(shot.lit.art):find("Multi") and shot.flare.play:IsPlaying(), "Multi-Shot ready lights three arrowheads under a flare")
	env._usable[19306] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(Art(shot.lit.art):find("Counter") and Tint(shot.lit.glow, K, "hostile"), "Counterattack after a parry crosses two crimson blades")
	local writes = #AB.W.Calls(shot.lit.art, "SetTexture") + #AB.W.Calls(shot.lit.art, "SetVertexColor") + #AB.W.Calls(shot.lit.glow, "SetVertexColor")
	for _ = 1, 50 do
		env.FireEvent("SPELL_UPDATE_USABLE")
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
	end
	local after = #AB.W.Calls(shot.lit.art, "SetTexture") + #AB.W.Calls(shot.lit.art, "SetVertexColor") + #AB.W.Calls(shot.lit.glow, "SetVertexColor")
	assert(after == writes, "unchanged shots repaint nothing (" .. after - writes .. " writes)")
	Clean(env, K)
end

do
	local env, K, ns = New("HUNTER", { known = { 2973, 3044 } })
	env.SetTarget(true)
	local raptor, arcane = Piece(ns, "crestAspect", 2), Piece(ns, "crestPet", 2)
	assert(raptor.spec.look == "orb" and arcane.spec.look == "orb" and raptor.ready:IsShown(), "before the Aspect and the pet, Raptor Strike and Arcane Shot are orbs, alight while ready")
	env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = false } end
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not raptor.ready:IsShown() and AB.W.LastCall(raptor.timer, "SetCooldownFromDurationObject") and raptor.timer._state.Reverse[1] == true,
		"a strike on cooldown leaves a steel orb whose ring charges round it")
	raptor.timer:GetScript("OnCooldownDone")(raptor.timer)
	assert(raptor.ready:IsShown() and raptor.flare.play:IsPlaying(), "and it ignites under a flare the moment it is ready")
	Clean(env, K)
end

do
	local env, K, ns = New("MAGE", { known = { 168, 6117, 759, 2139, 122, 11958, 11095 } })
	local armor, counter, frozen, fire = Piece(ns, "crestArmor"), Piece(ns, "crestCounterspell"), Piece(ns, "crestFrozen"), Piece(ns, "crestSchool")
	Slots.Set(env, "player", { { id = 7302, start = 0, duration = 1800 } })
	assert(armor.lits[1]:IsShown() and not armor.lits[2]:IsShown() and Tint(armor.lits[1].glow, K, "schoolFrost") and armor.lits[1]._cooldown == armor.lits[1].timer,
		"Ice Armor lights the frost shield and drains its ring")
	Slots.Set(env, "player", { { id = 22782, start = 0, duration = 1800 } })
	assert(armor.lits[2]:IsShown() and not armor.lits[1]:IsShown() and Art(armor.lits[2].art) ~= Art(armor.lits[1].art), "Mage Armor lights the arcane shield")
	assert(counter.spec.look == "shard" and counter.bar and counter.bar:GetStatusBarTexture()._state.Desaturated ~= true, "Counterspell is a crystal blade in its own colours")
	Slots.Set(env, "target", { { id = 122, harmful = true, start = 0, duration = 8 } })
	assert(frozen.lit:IsShown() and frozen.lit._cooldown == frozen.timer, "your Frost Nova on the target lights the ice crystal and drains its ring")
	for _, count in ipairs({ 1, 3, 5 }) do
		Slots.Set(env, "target", { { id = 22959, harmful = true, start = 0, duration = 30, count = count } })
		local lit = 0
		for _, part in ipairs(fire.parts) do
			if part._count then
				local _, high = part:GetMinMaxValues()
				lit = lit + (env.Reveal(part:GetValue()) >= high and 1 or 0)
			end
		end
		assert(lit == count, count .. " stacks of Fire Vulnerability light " .. count .. " embers round the orb (" .. lit .. ")")
	end
	Clean(env, K)
end

do
	local env, K, ns = New("WARLOCK", { known = { 688, 691, 6201, 18788, 702, 17962, 2362 }, pet = { max = 100, missing = 0 } })
	local demon, stone, curse = Piece(ns, "crestDemon"), Piece(ns, "crestHealthstone"), Piece(ns, "crestCurse")
	assert(not stone.lit:IsShown() and not stone.rest:IsVisible(), "no Healthstone: an empty setting")
	env._bags[5512] = 1
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(stone.lit:IsShown() and stone.ready:IsShown() and Tint(stone.lit.glow, K, "friendly"), "a Healthstone in the bags lights a green gem")
	local count, cooldown = env.C_Item.GetItemCount, env.C_Item.GetItemCooldown
	local reads = 0
	env.C_Item.GetItemCount = function(...) reads = reads + 1 return count(...) end
	env.C_Item.GetItemCooldown = function(...) reads = reads + 1 return cooldown(...) end
	env._cooling[5512] = { 100, 120 }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not stone.ready:IsShown() and AB.W.LastCall(stone.timer, "SetCooldown"), "a used Healthstone goes dark and its ring charges")
	assert(reads <= 14, "one bag scan per bag cooldown (" .. reads .. " reads)")
	env.C_Item.GetItemCount, env.C_Item.GetItemCooldown = count, cooldown
	Slots.Set(env, "player", { { id = 18789, start = 0, duration = 1800 } })
	assert(demon.lit:IsShown() and demon.lit._cooldown == demon.timer and Shown(demon.lit, demon.lit.loop), "Demonic Sacrifice burns a fel wisp in the demon medal, its ring draining")
	Slots.Set(env, "target", { { id = 702, harmful = true, start = 0, duration = 120 } })
	assert(curse.lits[1]:IsShown() and curse.lits[1]._durationBar[1] == curse.lits[1].art, "your Curse of Weakness burns its mark down over its time")
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	local lock = Seated(ns, "crestSpellLock")
	assert(lock.spec.look == "blade" and lock.bar, "a Felhunter's Spell Lock is a blade that charges over its cooldown")
	Clean(env, K)
	local fenv, FK, fns = New("WARLOCK", { frames = true, trinket = true, known = { 688, 6201, 17962, 2362 } })
	local jewel, well, trinket = Piece(fns, "crestConflagrate"), Piece(fns, "crestFiveSecond"), Seated(fns, "crestTrinkets")
	assert(jewel.spec.look == "orb" and jewel.ready and Art(jewel.lit.art):find("Coal"), "under Frames Conflagrate is a coal that charges")
	assert(well.timer and not well.steel and trinket.ready, "under Frames the five-second rule is a mana well and the trinket a gem")
	Clean(fenv, FK)
end

for class in pairs(LIGHT) do
	local env, K, ns = New(class, { bags = { [6265] = 2, [5512] = 1, [5514] = 1 }, pet = { max = 100, missing = 0 } })
	env._petSpells[19244] = true
	env.FireEvent("UNIT_PET", "player")
	env.SetTarget(true)
	env._aurasSecret = true
	env.SetCombat(true)
	for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED", "SPELLS_CHANGED" }) do env.FireEvent(event) end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
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
