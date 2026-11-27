-- test-actionbars-crest-pieces.lua: each of the warrior's, paladin's and rogue's crest pieces (SlabArmory.lua), one row each: its look on the crest (a rim by its ring) and under Frames, steel at rest, lit by its own feed (an aura drains it, a cooldown or item charges it, a usable strike or enchant lights it), hidden and shown again by its switch, changed in combat with auras secret only through its own frames and replayed when the restriction ends, and under Frames the same object with no round socket frame; then the review of 6fc9d08a: an aura's piece warns through its last fifth, Slice and Dice's fuse keeps off the level number and its spark orbits, the trinket's ember burns on its own ring, a strike taking over flashes, the band flashes and the horn's wave, the Holy flasks clear of the Seal's ring, the paladin builds only the school layers it can use, and a shared container is re-armed once.
local F = dofile("Tools/regression/crest_armory_fixture.lua")
local AB, Slots, New, Clean, Auras, Walk, Round, Find, Lit = F.AB, F.Slots, F.New, F.Clean, F.Auras, F.Walk, F.Round, F.Find, F.Lit

-- Each piece, one row: its look on the crest (nil: a rim) and under Frames; its feed lights it (an aura drains it, a cooldown or item charges it, a usable strike or enchant lights it); its switch hides it; in combat with auras secret it changes nothing it may not.
local PIECES = {
	{ "WARRIOR", { 6673 }, 0, "crestShout", "horn", "horn", player = { 6673 } },
	{ "WARRIOR", { 11585 }, 0, "crestOpening", "sword", "sword", usable = 11585 },
	{ "WARRIOR", { 2687 }, 0, "crestEnrage", nil, "flame", player = { 29131 }, ring = "Cracks.png" },
	{ "WARRIOR", { 21553 }, 0, "crestHipLeft", "grooveLL", "grooveLL", cooling = 21553 },
	{ "WARRIOR", { 11581 }, 18, "crestHipLeft", "grooveLL", "grooveLL", target = { 11581 } },
	{ "WARRIOR", { 12319 }, 0, "crestHipRight", "grooveLR", "grooveLR", player = { 12966 } },
	{ "WARRIOR", { 2565 }, 18, "crestHipRight", "ward", "ward", player = { 2565 } },
	{ "WARRIOR", { 72 }, 0, "crestFootLeft", "grooveBL", "grooveBL", cooling = 72 },
	{ "WARRIOR", { 100 }, 0, "crestFootRight", "grooveBR", "grooveBR", cooling = 100 },
	{ "WARRIOR", { 355 }, 18, "crestFootRight", "grooveBR", "grooveBR", cooling = 355, target = { 355 } },
	{ "PALADIN", { 20154 }, 0, "crestSeal", "seal", "seal", player = { 20154 } },
	{ "PALADIN", { 20271 }, 0, "crestJudgement", "hammer", "hammer", cooling = 20271 },
	{ "PALADIN", { 20271, 20165 }, 0, "crestJudged", "brand", "brand", target = { 20185 } },
	{ "PALADIN", { 10333 }, 0, "crestHipLeft", "grooveLL", "grooveLL", cooling = 10333 },
	{ "PALADIN", { 20925, 25780 }, 0, "crestHipRight", "flames", "flames", player = { 25780 } },
	{ "PALADIN", { 20473, 1328548 }, 0, "crestHipRight", "oath", "oath", friend = { 1328548 } },
	{ "PALADIN", { 24239 }, 0, "crestHipRight", "grooveLR", "grooveLR", usable = 24239 },
	{ "PALADIN", { 10314 }, 0, "crestHipRight", "grooveLR", "grooveLR", cooling = 10314 },
	{ "PALADIN", { 20473, 20271 }, 0, "crestFootLeft", "vial", "vial", item = true },
	{ "PALADIN", { 853 }, 0, "crestFootLeft", "grooveBL", "grooveBL", cooling = 853 },
	{ "PALADIN", { 20473, 20271 }, 0, "crestFootRight", "vial", "vial", item = true },
	{ "PALADIN", { 20925 }, 0, "crestRing", "ward", "ward", player = { 20925 } },
	{ "PALADIN", { 20049 }, 0, "crestRing", nil, "flame", player = { 20050 } },
	{ "ROGUE", { 8676 }, 30, "crestSlice", "dagger", "dagger", usable = 8676 },
	{ "ROGUE", { 5171 }, 0, "crestSlice", nil, "dagger", player = { 6774 }, ring = "Fuse.png" },
	{ "ROGUE", { 1856 }, 30, "crestRupture", "stain", "stain", cooling = 1856 },
	{ "ROGUE", { 1943 }, 0, "crestRupture", "stain", "stain", target = { 11275 } },
	{ "ROGUE", { 2842 }, 0, "crestPoisons", "vial", "vial", enchant = 1, slot = "MainHand" },
	{ "ROGUE", { 2842 }, 0, "crestPoisons", "vial", "vial", enchant = 2, slot = "OffHand" },
	{ "ROGUE", { 1766 }, 0, "crestFootLeft", "grooveBL", "grooveBL", cooling = 1766 },
	{ "ROGUE", { 14177, 2842 }, 0, "crestFootRight", "grooveBR", "grooveBR", target = { 2818 } },
	{ "ROGUE", { 14251 }, 0, "crestFootRight", "grooveBR", "grooveBR", usable = 14251 },
	{ "ROGUE", { 16511 }, 0, "crestFootRight", "drop", "drop", target = { 16511 } },
	{ "ROGUE", { 1316709 }, 0, "crestFootRight", "brand", "brand", target = { 1316709 } },
	{ "ROGUE", { 1329549 }, 0, "crestFootRight", "grooveBR", "grooveBR", cooling = 1329549 },
}

local function Feed(env, row)
	if row.player then Slots.Set(env, "player", Auras(env, row.player)) end
	if row.target then Slots.Set(env, "target", Auras(env, row.target, true)) end
	if row.friend then Slots.Set(env, "target", Auras(env, row.friend)) end
	if row.enchant then Slots.Enchant(env, row.enchant, { start = 0, duration = 1800 }) end
	if row.usable then env._usable[row.usable] = true end
	if row.cooling then env._cooling[row.cooling] = true end
	for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED" }) do env.FireEvent(event) end
end

for _, row in ipairs(PIECES) do
	local class, known, form, key, crest, frames = row[1], row[2], row[3], row[4], row[5], row[6]
	local where = class .. " " .. key .. " " .. tostring(crest or frames) .. (row.slot and " " .. row.slot or "")
	local env, K, ns = New(class, known)
	env._form = form
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	local p = Find(ns, key, nil, row.slot)
	assert(p and p.spec.look == frames, where .. ": shows on the crest")
	if crest then
		assert(p.lit and p.lit.mask, where .. ": the crest draws it as its own " .. crest)
	else
		assert(p.timer and AB.W.LastCall(p.timer, "SetSwipeTexture")[1]:find(row.ring or "RingLine16.png", 1, true), where .. ": runs round the crest's ring")
	end
	if not (row.cooling or row.item) then
		assert(not Lit(p), where .. ": steel with nothing up")
	end
	Feed(env, row)
	assert(Lit(p), where .. ": lit by its feed")
	if row.cooling or row.item then
		assert(AB.W.LastCall(p.bar, "SetTimerDuration"), where .. ": charges over its cooldown")
	elseif crest and not row.usable then
		assert(AB.W.LastCall(p.lit.bar, "SetTimerDuration") or AB.W.LastCall(p.lit.timer, "SetCooldownFromDurationObject"), where .. ": drains with its aura")
	end
	K.Options.Write("ActionBars", key, false)
	assert(not Find(ns, key, nil, row.slot), where .. ": its switch hides it")
	K.Options.Write("ActionBars", key, true)
	p = Find(ns, key, nil, row.slot)
	assert(p, where .. ": and shows it again")
	env._aurasSecret = true
	env.SetCombat(true)
	if row.usable then env._usable[row.usable] = false end
	if row.cooling then env._cooling[row.cooling] = false end
	for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED" }) do env.FireEvent(event) end
	if row.usable then assert(not Lit(p), where .. ": in combat a strike gone unusable dims it") end
	if row.cooling then assert(AB.W.LastCall(p.bar, "SetValue")[1] == 1, where .. ": in combat a finished cooldown fills it") end
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	env.SetCombat(false)
	assert(Find(ns, key, nil, row.slot) == p, where .. ": the restriction ending replays onto the same piece")
	Clean(env, K, where .. " in combat")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	local round, f = Round(K), Find(ns, key, "row", row.slot)
	assert(f and f.spec.look == frames and ns.SlabArmory.LOOKS[frames], where .. ": under Frames the same " .. frames .. " stands free")
	Walk(f, function(region) assert(not round(region), where .. ": under Frames it sits in a round socket (" .. tostring(round(region)) .. ")") end)
	Feed(env, row)
	assert(Lit(f), where .. ": lit by its feed under Frames")
	Clean(env, K, where .. " Frames")
end

local function Watched(ns, piece)
	for _, e in ipairs(ns.SlabRings.state.watched) do
		if e.piece == piece then return e end
	end
end

local function Anim(group, kind)
	for _, a in ipairs(group._anims or {}) do
		if a._type == kind then return a end
	end
end

-- An aura's piece flickers through its last fifth and fades a gilt glow when the aura ends, as a medal's ember did; a rim with its own ring art warns on that ring, not on the 112 inner line (review of 6fc9d08a #2, #4).
for _, case in ipairs({ { "WARRIOR", { 6673 }, "crestShout", 6673 }, { "PALADIN", { 20271, 20166 }, "crestJudged", 20186 }, { "ROGUE", { 1943 }, "crestRupture", 11275 },
	{ "WARRIOR", { 2687 }, "crestEnrage", 29131 }, { "ROGUE", { 5171 }, "crestSlice", 6774 } }) do
	local env, K, ns = New(case[1], case[2])
	local p = Find(ns, case[3])
	local e = Watched(ns, p)
	assert(e and e.flicker and e.fade and e.ids[case[4]], case[3] .. ": its last fifth flickers the piece and its end fades a gilt glow")
	for _, region in ipairs(p.parts) do
		local swipe = region._state and region._state.SwipeTexture
		assert(not (swipe and tostring(swipe[1]):find("Ember", 1, true)), case[3] .. ": no ember band or 112 line round a piece that is no ring")
	end
	Clean(env, K, case[3] .. " warning")
end

-- Slice and Dice: a fine fuse with a gap over the level number, and a spark orbiting the band once every 1.6 s, hidden while it passes the number (review of 6fc9d08a #3).
do
	local env, K, ns = New("ROGUE", { 5171 })
	local p = Find(ns, "crestSlice")
	assert(AB.W.LastCall(p.timer, "SetSwipeTexture")[1]:find("Fuse.png", 1, true) and p.timer.units == 150, "Slice and Dice burns the fine fuse")
	local orbit = p.lit.awake and p.lit.awake.lit.loop
	local turn = orbit and Anim(orbit, "Rotation")
	assert(turn and AB.W.LastCall(turn, "SetDegrees")[1] == -360 and AB.W.LastCall(turn, "SetDuration")[1] == 1.6 and orbit:GetLooping() == "REPEAT",
		"its spark orbits clockwise, one lap in 1.6 s")
	local hide = {}
	for _, a in ipairs(orbit._anims) do
		if a._type == "Alpha" then hide[#hide + 1] = AB.W.LastCall(a, "SetStartDelay")[1] end
	end
	assert(hide[1] == 0.72 and hide[2] == 0.96, "and it fades out over the level number (258 to 282 degrees) and back")
	Clean(env, K, "fuse")
end

-- The trinket's ember burns on the central ring it qualifies, not round the moved jewel (review of 6fc9d08a #1). The crest's rail carries the trinket while it
-- shows, so the socket is read with the rail switched off.
do
	local env, K, ns = New("ROGUE", { 5171, 13877 })
	K.Options.Write("ActionBars", "crestRail", false)
	env._resolveRects = true
	local jewel = Find(ns, "crestTrinkets")
	local hot
	for _, part in ipairs(jewel.parts) do
		local swipe = part._state and part._state.SwipeTexture
		if swipe and tostring(swipe[1]):find("EmberRingLine16", 1, true) then hot = part end
	end
	local hx, hy = hot:GetCenter()
	local rx, ry = jewel.timer:GetCenter()
	assert(math.abs(hx - rx) < 0.01 and math.abs(hy - ry) < 0.01, "the trinket's ember is centred on its cooldown ring, " .. hx - rx .. ", " .. hy - ry .. " off")
	Clean(env, K, "trinket ember")
end

-- A strike taking over from another flashes as it slides out, and half the band flashes in its colour; the hammer flashes the left half, the brand the right (review of 6fc9d08a #4).
do
	local env, K, ns = New("WARRIOR", { 20662, 11585 })
	ns.Slab.Resting = function() return false end
	local opening = Find(ns, "crestOpening")
	env._usable[11585] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	opening.flare.play:Stop()
	env._usable[20662] = true
	env.FireEvent("SPELL_UPDATE_USABLE")
	assert(opening.flare.play:IsPlaying(), "Execute taking over from Overpower flashes too")
	Clean(env, K, "swap flash")
	for _, case in ipairs({ { "WARRIOR", { 11585 }, "crestOpening", 0 }, { "PALADIN", { 20271 }, "crestJudgement", 1 }, { "PALADIN", { 20271, 20165 }, "crestJudged", 0 } }) do
		env, K, ns = New(case[1], case[2])
		local p, band = Find(ns, case[3]), nil
		Walk(p, function(region)
			local texture = region._state and region._state.Texture
			if texture and tostring(texture[1]):find("BandFlash.png", 1, true) then band = region end
		end)
		local point = band and { band:GetPoint(1) }
		assert(band and point[2] == ns.SlabTrackers.state.forms.crest.frame and band.units == 150 and AB.W.LastCall(band, "SetTexCoord")[1] == case[4], case[3] .. ": its flare flashes its half of the band")
		Clean(env, K, case[3] .. " band")
	end
end

-- The horn calls a wave round the band from its bell; Thunder Clap crackles along its groove (review of 6fc9d08a #4).
do
	local env, K, ns = New("WARRIOR", { 6673 })
	local loops = Find(ns, "crestShout").lit.awake.lit.loops
	local turn = loops[2] and Anim(loops[2], "Rotation")
	assert(turn and loops[2]:GetParent():GetTexture():find("Wave.png", 1, true) and AB.W.LastCall(turn, "SetDuration")[1] == 0.8, "the horn's call travels round the band in 0.8 s")
	Clean(env, K, "horn wave")
	env, K, ns = New("WARRIOR", { 11581 })
	env._form = 18
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	loops = Find(ns, "crestHipLeft").lit.awake.lit.loops
	assert(loops and loops[1] and loops[1]:GetParent():GetTexture():find("GrooveLLGlow.png", 1, true), "Thunder Clap crackles along the lower-left groove")
	Clean(env, K, "crackle")
end

-- A Holy paladin's flasks hang on the band beside the level badge, under no ring: the Seal's flood ring runs behind every perched piece (review of 6fc9d08a #4).
do
	local env, K, ns = New("PALADIN", { 20154, 20473, 20271 })
	local seal, stone = Find(ns, "crestSeal"), Find(ns, "crestFootLeft")
	local x, y = stone:GetCenter()
	local hx, hy = ns.Slab.hub:GetCenter()
	local r = math.sqrt((x - hx) ^ 2 + (y - hy) ^ 2) / (ns.Slab.hub:GetEffectiveScale() / stone:GetEffectiveScale())
	assert(stone.spec.look == "vial" and stone.spec.size == 16 and r > 60, "the healthstone flask hangs on the band, clear inside the Seal's ring, " .. r)
	assert(seal.lit.timer:GetFrameLevel() < stone:GetFrameLevel(), "and the Seal's flood ring runs behind it")
	Clean(env, K, "flasks")
end

-- A paladin builds only the school layers it can use, so knowing one Seal costs one layer; learning another adds its own (review of 6fc9d08a #7).
do
	local env, K, ns = New("PALADIN", { 20154, 20271 })
	local seal, judged = Find(ns, "crestSeal"), Find(ns, "crestJudged")
	assert(#seal.lits == 1 and #judged.lits == 1, "Righteousness alone: one seal layer and one judged layer, got " .. #seal.lits .. " and " .. #judged.lits)
	env._known[20166] = true
	env.FireEvent("SPELLS_CHANGED")
	env.RunTimers()
	seal = Find(ns, "crestSeal")
	Slots.Set(env, "player", Auras(env, { 20166 }))
	assert(#seal.lits == 2 and seal.lits[2]:IsShown(), "learning Seal of Wisdom builds its blue layer")
	Clean(env, K, "lazy schools")
end

-- A shared container is re-armed once when the motion level changes, however many slots it holds (review of 6fc9d08a #5).
do
	local env, K, ns = New("PALADIN", { 20154, 20375, 20162, 20165, 20166, 20164, 20163, 20271 })
	local seal = Find(ns, "crestSeal")
	local unique, flips = {}, 0
	for _, lit in ipairs(seal.lits) do
		unique[lit.container] = true
		for _, m in ipairs(lit.mirrors or {}) do unique[m.container] = true end
	end
	local containers = 0
	for c in pairs(unique) do
		containers = containers + 1
		local set = c.SetEnabled
		c.SetEnabled = function(self, v)
			if v ~= self._enabled then flips = flips + 1 end
			return set(self, v)
		end
	end
	ns.SlabMedals.Engine({ seal }, true, false)
	ns.SlabMedals.Engine({ seal }, true, true)
	assert(#seal.lits == 7 and flips <= 4 * containers, "seven seals' slots re-arm each of their " .. containers .. " containers once per change, got " .. flips .. " flips")
	Clean(env, K, "re-arm")
end

print("actionbars crest pieces ok")
