-- test-actionbars-crest-armory.lua: the warrior's, paladin's and rogue's crest effects (SlabArmory.lua): no piece of theirs, on the crest or in the Frames row, in any stance, form or spec, an on-use trinket's among them, shows a spell's or item's icon; the Seal and the judged target glow in their school's colour; the opening draws the usable strike's own weapon and slides it out when it becomes usable, awake only; an aura drains its object, a cooldown charges its gem and an item fills its vial and refills it as it cools; each look's motion loops only at Full; perched objects stay inside the ring at four screen sizes; and in combat with auras secret the Lua-fed effects change only the crest's own frames. Each piece's own feed, rest, switch, combat and Frames object: test-actionbars-crest-pieces.
local F = dofile("Tools/regression/crest_armory_fixture.lua")
local AB, Slots, New, Clean, Auras, Walk, Round, Find = F.AB, F.Slots, F.New, F.Clean, F.Auras, F.Walk, F.Round, F.Find

local CASES = {
	{ "WARRIOR", { 25289, 20662, 11585, 25288, 2565, 23925, 23894, 1680, 402927, 11574, 2687, 18499, 12317, 1719, 12328, 871, 12975, 12292, 20230,
		11581, 21553, 11605, 12319, 1329555, 6554, 1672, 355, 20617, 11578 }, { 0, 17, 18, 19 } },
	{ "PALADIN", { 20154, 20271, 642, 498, 20216, 1022, 1044, 1311015, 1310897, 10333, 10314, 10308, 24239, 20473, 20929, 1328548 }, { 0 } },
	{ "PALADIN", { 20154, 20271, 642, 10333, 407632, 20925, 25780, 10308 }, { 0 } },
	{ "PALADIN", { 20154, 20271, 642, 10333, 20049, 24239, 10314, 10308 }, { 0 } },
	{ "ROGUE", { 5171, 1943, 2842, 8676, 1833, 703, 1856, 13877, 13750, 5277, 2983, 14177, 1766, 14144, 1329328 }, { 0, 30 } },
	{ "ROGUE", { 5171, 1943, 2842, 14251, 1766, 14148, 1329549 }, { 0, 30 } },
	{ "ROGUE", { 5171, 1943, 2842, 16511, 1766, 1316709 }, { 0 } },
}
local AURAS = {
	player = { 25289, 12880, 29131, 12966, 12292, 1329555, 2565, 1719, 20154, 20166, 20050, 25780, 20925, 642, 6774, 13877, 14143, 1310703 },
	target = { 772, 11581, 355, 20185, 20186, 1328548, 1310909, 11275, 703, 2818, 16511, 1316709 },
}

-- The seats every case must show, in every form, on the crest and in the row: a piece that fails to build is missing, not passing.
local SEATS = {
	WARRIOR = { "crestShout", "crestOpening", "crestHipLeft", "crestHipRight", "crestFootLeft", "crestFootRight", "crestTrinkets" },
	PALADIN = { "crestFiveSecond", "crestSeal", "crestJudgement", "crestJudged", "crestHipLeft", "crestHipRight", "crestFootLeft",
		"crestTrinkets" },
	ROGUE = { "crestSlice", "crestRupture", "crestPoisons", "crestFootLeft", "crestFootRight", "crestTrinkets" },
}

for _, case in ipairs(CASES) do
	for _, frames in ipairs({ false, true }) do
		local env, K, ns = New(case[1], case[2], frames)
		local round = Round(K)
		for _, id in ipairs(case[2]) do env._usable[id] = true end
		env._cooling[20271] = true
		Slots.Set(env, "player", Auras(env, AURAS.player))
		Slots.Set(env, "target", Auras(env, AURAS.target, true))
		Slots.Enchant(env, 1, { start = 0, duration = 1800 })
		Slots.Enchant(env, 2, { start = 0, duration = 1800 })
		for _, form in ipairs(case[3]) do
			env._form = form
			env.FireEvent("UPDATE_SHAPESHIFT_FORM")
			env.FireEvent("SPELL_UPDATE_USABLE")
			env.FireEvent("SPELL_UPDATE_COOLDOWN")
			env.FireEvent("BAG_UPDATE_DELAYED")
			local where = case[1] .. " " .. table.concat(case[2], ","):sub(1, 30) .. " form " .. form .. (frames and " Frames" or " crest")
			local f = ns.SlabTrackers.state.forms[frames and "row" or "crest"]
			local shown = {}
			for key, piece in pairs(f.pieces) do
				shown[piece.spec.key] = shown[piece.spec.key] or piece:IsVisible()
				Walk(piece, function(region)
					local texture = region._state and region._state.Texture
					assert(not (texture and type(texture[1]) == "number"), where .. ": " .. key .. " (" .. tostring(piece.spec.key) .. ") shows an icon, file " .. tostring(texture and texture[1]) .. "; give its row a look (SlabArmory.lua) or its family a sigil instead of a spell's icon")
					assert(region._icon == nil, where .. ": " .. key .. " (" .. tostring(piece.spec.key) .. ") hands the engine a region for the aura's icon")
					assert(not (piece.spec.look or piece.spec.key == "crestFiveSecond") or not round(region), where .. ": " .. key .. " (" .. tostring(piece.spec.key) .. ") sits in a round socket ("
						.. tostring(round(region)) .. "); perch it, cut it into the band or lay it over the emblem (SlabArmory.lua) instead")
				end)
			end
			assert(next(f.failed) == nil, where .. ": piece " .. tostring(next(f.failed)) .. " failed to build")
			for _, key in ipairs(SEATS[case[1]]) do
				assert(shown[key], where .. ": " .. key .. " shows")
			end
		end
		Clean(env, K, case[1])
	end
end

-- The Seal glows its own seal's colour and the judged brand its judgement's.
do
	local env, K, ns = New("PALADIN", { 20154, 20166, 20271 })
	local seal, judged
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.key == "crestSeal" then seal = piece end
		if piece.spec.key == "crestJudged" then judged = piece end
	end
	local function Colour(region) return table.concat({ region:GetStatusBarColor() }, ",", 1, 3) end
	local function Token(name) return table.concat({ K.Tokens.Color(name) }, ",", 1, 3) end
	Slots.Set(env, "player", Auras(env, { 20166 }))
	local lit = {}
	for i, l in ipairs(seal.lits) do if l:IsShown() then lit[#lit + 1] = i end end
	assert(#lit == 1 and Colour(seal.lits[lit[1]].bar) == Token("schoolFrost"), "the Seal of Wisdom lights its one seal in blue")
	Slots.Set(env, "target", Auras(env, { 20186 }, true))
	lit = {}
	for i, l in ipairs(judged.lits) do if l:IsShown() then lit[#lit + 1] = i end end
	assert(#lit == 1 and Colour(judged.lits[lit[1]].bar) == Token("schoolFrost"), "your Judgement of Wisdom brands the target in the same blue")
	assert(AB.W.LastCall(judged.lits[lit[1]].bar, "SetTimerDuration"), "and the brand drains with it")
	Clean(env, K, "schools")
end

-- The opening draws the strike's own weapon, and slides it out when it becomes usable, only awake at Full.
do
	local env, K, ns = New("WARRIOR", { 6673, 20662, 11585 })
	local opening
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.key == "crestOpening" and piece:IsVisible() then opening = piece end
	end
	ns.Slab.Resting = function() return false end
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	local texture = AB.W.LastCall(opening.lit.mask, "SetTexture")[1]
	assert(texture:find("Axe.png", 1, true) and opening.slide:IsPlaying(), "Execute draws its axe and slides it out")
	assert(table.concat({ opening.lit.bar:GetStatusBarColor() }, ",", 1, 3) == table.concat({ K.Tokens.Color("plateHostile") }, ",", 1, 3), "in red")
	opening.slide:Stop()
	env._usable[20662] = false
	env.FireEvent("SPELL_UPDATE_USABLE")
	ns.Slab.Resting = function() return true end
	env._usable[11585] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(opening.lit:IsShown() and not opening.slide:IsPlaying(), "at rest Overpower lights without the slide")
	Clean(env, K, "opening")
end

-- Each look's motion loops only at Full: the horn's call, the drop's drip, the vial's bubble, the flame's flicker, the seal's halo.
do
	local env, K, ns = New("WARRIOR", { 25289, 11574, 2687 }, true)
	local loops = {}
	for _, piece in pairs(ns.SlabTrackers.state.forms.row.pieces) do
		local mirror = piece.lit and piece.lit.awake and piece.lit.awake.lit
		if mirror and mirror.loops then loops[piece.spec.look] = mirror end
	end
	assert(loops.horn and loops.sword and loops.flame, "the horn, Rend's dripping sword and the flame each loop under Frames too")
	for _, mirror in pairs(loops) do assert(mirror.full == true and mirror.loops[1]:GetParent():GetAlpha() == 0, "at Full the engine plays the loop over a hidden part") end
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	for _, mirror in pairs(loops) do assert(mirror.full == false, "at Calm the engine drops it") end
	Clean(env, K, "loops")
end

-- A cooldown charges its gem and flares when ready; an item fills its vial and dims it while it cools.
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20473, 10308 })
	local hip, stone
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.key == "crestHipLeft" and piece:IsVisible() then hip = piece end
		if piece.spec.key == "crestFootLeft" and piece:IsVisible() then stone = piece end
	end
	env._cooling[hip.spec.spell] = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(hip.spec.look == "grooveLL" and AB.W.LastCall(hip.bar, "SetTimerDuration"), "the hip's groove charges over its cooldown")
	ns.Slab.Resting = function() return false end
	hip.flare.play:Stop()
	hip.timer:GetScript("OnCooldownDone")(hip.timer)
	assert(hip.flare.play:IsPlaying(), "and flares when ready")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(stone.spec.look == "vial" and stone.lit:IsShown() and AB.W.LastCall(stone.bar, "SetTimerDuration"), "a cooling healthstone's vial refills")
	Clean(env, K, "charges")
end

-- In combat with auras secret a usable strike, a cooldown and an item change only the crest's own frames.
do
	local env, K = New("PALADIN", { 20154, 20271, 20473, 10308, 24239 })
	env._aurasSecret = true
	env.SetCombat(true)
	env._usable[24239] = true
	env._cooling[20271] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	env._aurasSecret = false
	env.SetCombat(false)
	Clean(env, K, "secret combat")
end

-- A target change refreshes the paladin's judged brand once and its burst once, as one Judgement medal did: the schools share a container (review of 568555f1 #6).
do
	local env, K = New("PALADIN", { 20154, 20271 })
	local calls = 0
	for _, c in ipairs(env._slotContainers) do
		local update = c.UpdateAllAuras
		c.UpdateAllAuras = function(self) calls = calls + 1 return update(self) end
	end
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(calls <= 2, "a target change refreshes 2 containers, got " .. calls .. "; give the schools one container's slots")
	Clean(env, K, "target refresh")
end

-- The rogue's crest fire keeps its ambient-only rim (review of 568555f1 #5).
do
	local env, K, ns = New("ROGUE", { 14144, 5171, 2842 })
	assert(Find(ns, "crestFire").timer == nil, "the rogue's crest fire has no timer ring")
	Clean(env, K, "rogue fire")
end

-- A rejected enchant leaves the vial still: no liquid and no bubble, in either form (review of 568555f1 #3).
for _, frames in ipairs({ false, true }) do
	local env, K, ns = New("ROGUE", { 14144, 5171, 2842 }, frames)
	ns.Slab.Resting = function() return false end
	ns.SlabMedals.Rest()
	local vial = Find(ns, "crestPoisons", frames and "row" or "crest")
	local id = next(vial.spec.reject)
	env.C_PaperDollInfo = env.C_PaperDollInfo or {}
	env.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function() return { enchantID = id } end
	Slots.Enchant(env, vial.spec.slot == "MainHand" and 1 or 2, { start = 0, duration = 3600 })
	env.FireEvent("UNIT_INVENTORY_CHANGED", "player")
	for _, mirror in ipairs(vial.lit.mirrors) do
		assert(mirror.gate:GetAlpha() == 0, "a sharpening stone gates the vial's burst and bubble too")
	end
	Clean(env, K, "rejected enchant")
end

-- An empty consumable vial is an empty flask: the glass, no liquid (review of 568555f1 #10).
do
	local env, K, ns = New("PALADIN", { 20154, 20271, 20473, 10308 })
	local stone = Find(ns, "crestFootLeft")
	env.C_Item.GetItemCount = function() return 0 end
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(not stone.lit:IsShown() and AB.W.LastCall(stone.ghost, "SetTexture")[1]:find("VialGlass.png", 1, true), "no healthstone: no liquid shows, only the glass")
	Clean(env, K, "empty vial")
end

-- A strike taking over from another draws its own weapon out again (review of 568555f1 #4).
do
	local env, K, ns = New("WARRIOR", { 6673, 20662, 11585 })
	local opening = Find(ns, "crestOpening")
	ns.Slab.Resting = function() return false end
	env._usable[11585] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	opening.slide:Stop()
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(opening.slide:IsPlaying(), "Execute taking over from Overpower slides its axe out")
	Clean(env, K, "weapon swap")
end

-- A partial fill never redraws the object: the lit layer is a plain fill cut by the whole object's own outline (review of 568555f1 #2).
do
	local env, K, ns = New("WARRIOR", { 25289 })
	local horn = Find(ns, "crestShout")
	local fill, masks = horn.lit.bar:GetStatusBarTexture(), horn.lit.bar:GetStatusBarTexture()._masks or {}
	assert(fill._state.Texture[1] == (K.Tokens.Texture("barFlat")) and masks[1], "the horn's fill is plain, cut by a mask")
	assert(masks[1]:GetParent() ~= fill and AB.W.LastCall(masks[1], "SetTexture")[1]:find("Horn.png", 1, true), "by the whole horn's outline")
	Clean(env, K, "fill")
end

-- Every perched object stays inside the crest's ring and clear of the unit slab strip (34 to 49 units above the centre) at four screen sizes; the Seal sits above the ring; Frames pieces keep apart (review of 568555f1 #1, #9).
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE" }) do
		local env, K, ns = AB.New({ class = class, width = size[1], height = size[2], setup = function(e)
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function() return true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return false end }
			e.GetInventoryItemID = function(_, slot) return (slot == 16 or slot == 17) and 2092 or nil end
			e._slotGroups = true
			Slots.Install(e)
		end })
		AB.Enable(env, K)
		env.RunTimers()
		env._resolveRects = true
		local hub = ns.Slab.hub
		local hx, hy = hub:GetCenter()
		local k = hub:GetEffectiveScale()
		for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			local look = ns.SlabArmory.LOOKS[p.spec.look or ""]
			if p:IsVisible() and p.ghost and look and not look.groove and p.spec.key ~= "crestSeal" then
				local l, b, w, h = p.ghost:GetRect()
				local s = p.ghost:GetEffectiveScale() / k
				local x0, y0, x1, y1 = l * s - hx, b * s - hy, (l + w) * s - hx, (b + h) * s - hy
				for _, corner in ipairs({ { x0, y0 }, { x1, y0 }, { x0, y1 }, { x1, y1 } }) do
					assert(math.sqrt(corner[1] ^ 2 + corner[2] ^ 2) <= 75, class .. " " .. p.spec.key .. ": the object stays inside the crest's ring")
				end
				assert(y1 <= 34, class .. " " .. p.spec.key .. ": the object stays below the unit slab strip, top at " .. y1)
			end
		end
		Clean(env, K, class .. " seats")
	end
end
for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE" }) do
	local env, K, ns = New(class, { 6673, 20662, 5171, 1943, 2842, 14251, 1766, 20154, 20271, 1672, 11578 }, true)
	env._resolveRects = true
	local boxes = {}
	for _, p in pairs(ns.SlabTrackers.state.forms.row.pieces) do
		if p:IsVisible() and p.ghost then
			local l, b, w, h = p.ghost:GetRect()
			for _, o in ipairs(boxes) do
				assert(l >= o[1] + o[3] or o[1] >= l + w or b >= o[2] + o[4] or o[2] >= b + h, class .. ": Frames objects keep apart")
			end
			boxes[#boxes + 1] = { l, b, w, h }
		end
	end
	Clean(env, K, class .. " row")
end

print("actionbars crest armory ok")
