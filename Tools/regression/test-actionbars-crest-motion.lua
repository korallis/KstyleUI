-- test-actionbars-crest-motion.lua: the crest plan's motion rules, part 1. One end-warning flicker for every class (Core/Tokens.lua's Flicker: alpha 1 to 0.6 and back in two
-- 0.25 s steps, so two blinks a second), fades and steps eased in the token's direction everywhere on the crest, Calm keeping the ready and refresh cues as still marks, crest
-- flares sharing one place in the effects arbiter whatever starts them, and the warrior's horn calling once on its cast and once before it ends. Each crest size chain
-- runs as one path with no jump, its steps composed by Tools/regression/anim_pose.lua's rule.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local Pose = dofile("Tools/regression/anim_pose.lua")

local SHOUT = 25289
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function New(class, unknown, before)
	local env, K, ns = AB.New({ class = class, setup = function(e)
		e._trackOrigin = true
		e.C_SpellBook = e.C_SpellBook or {}
		e.C_SpellBook.IsSpellKnown = function(id) return not (unknown and unknown[id]) end
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		e.GetTime = function() return e._now or 0 end
		e._auraData = {}
		e.C_UnitAuras = { GetUnitAuraBySpellID = function(unit, id) return e._auraData[unit .. id] end }
		e._slotGroups = true
		e._totems = {}
		e.GetTotemInfo = function(slot)
			local t = e._totems[slot]
			if not t then return false, "", 0, 0, 0, 1, 0 end
			return true, "Hawk", t.start, 18, 132158, 1, t.spell
		end
		e.GetTotemDuration = function(slot)
			local t = e._totems[slot]
			return { start = t and t.start or 0, finish = t and t.start + 18 or 0 }
		end
		-- A shaman has totems to drop, so the Spirit Poles and their spires build.
		e.C_ActionBar.GetMultiCastBarIndex = function() return 12 end
		e.GetMultiCastTotemSpells = function(slot) return slot == 1 and 3599 or nil end
		e.SetMultiCastSpell = function() end
		e.CreateFrame("Frame", "MultiCastActionBarFrame", e.UIParent)
		Slots.Install(e)
		e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
	end })
	if before then before(env, K) end
	AB.Enable(env, K)
	env.RunTimers()
	assert(#env._errors == 0 and K.ErrorCount() == 0, class .. ": " .. AB.Errors(env))
	return env, K, ns
end

local function Set(anim, key)
	local s = anim._state[key]
	return s and s[1]
end

-- Every animation group the action bars made, on frames and on their regions.
local function Groups(env, each)
	local function walk(owner)
		for _, group in ipairs(owner._groups or {}) do
			local first = group._anims and group._anims[1]
			if first and tostring(first._origin):find("KstyleUI_ActionBars", 1, true) then
				each(group)
			end
		end
	end
	for _, frame in ipairs(env._frames) do
		walk(frame)
		for _, region in ipairs(frame._regions or {}) do
			walk(region)
		end
	end
end

-- The token is the plan's rate, typed here from the plan: 1 to 0.6 and back, 0.25 s a step.
do
	local _, K, ns = New("WARRIOR")
	local f, s = K.Tokens.Flicker, K.Tokens.Smoothing
	assert(f.low == 0.6 and f.step == 0.25, "the end-warning flicker dips to 0.6 in 0.25 s steps: two blinks a second")
	local holder = ns.Slab.hub
	local blink = ns.Slab.Flicker(ns.Slab.hub:CreateTexture(), 0.8)
	local down, up = blink._anims[1], blink._anims[2]
	assert(Set(blink, "Looping") == "REPEAT" and #blink._anims == 2, "the flicker is one repeating pair of steps")
	assert(Set(down, "FromAlpha") == 0.8 and math.abs(Set(down, "ToAlpha") - 0.48) < 1e-9 and Set(up, "ToAlpha") == 0.8, "a dimmer part flickers between its own alpha and 0.6 of it")
	assert(Set(down, "Duration") == 0.25 and Set(up, "Duration") == 0.25 and Set(down, "Smoothing") == "IN_OUT" and Set(up, "Smoothing") == "IN_OUT", "each step takes 0.25 s and eases both ways")
	local group = holder:CreateAnimationGroup()
	assert(Set(ns.Slab.Fade(group, 0, 1, 0.2), "Smoothing") == s.enter and s.enter == "OUT", "a fade that appears eases out")
	assert(Set(ns.Slab.Fade(group, 1, 0, 0.2), "Smoothing") == s.exit and s.exit == "IN", "a fade that leaves eases in")
	local loop = holder:CreateAnimationGroup()
	loop:SetLooping("BOUNCE")
	assert(Set(ns.Slab.Fade(loop, 0, 1, 0.2), "Smoothing") == s.loop and s.loop == "IN_OUT", "a looping fade eases both ways")
end

-- Every class: an alpha or scale step that appears eases out, one that leaves eases in and a looping one eases both ways (Core/Tokens.lua's Smoothing, typed here: OUT, IN,
-- IN_OUT); a hold may carry any curve, and travel and turns keep curves of their own, which part 1 of the plan leaves alone. An alpha loop that blinks twice a second or faster is
-- the one flicker.
local WANT = { enter = "OUT", exit = "IN", loop = "IN_OUT" }

-- The one flicker, typed from the plan: a repeating pair of alpha steps of 0.25 s each with no pause, down to 0.6 of the part's own alpha and back up to it.
local function Flicker(group, what)
	local down, up = group._anims[1], group._anims[2]
	assert(Set(group, "Looping") == "REPEAT" and #group._anims == 2 and down._type == "Alpha" and up._type == "Alpha", what .. ": the warning is one repeating pair of alpha steps")
	local high, low = Set(down, "FromAlpha"), Set(down, "ToAlpha")
	assert(high > 0 and high <= 1 and math.abs(low - high * 0.6) < 1e-9 and Set(up, "FromAlpha") == low and Set(up, "ToAlpha") == high,
		what .. ": it dips from the part's alpha to 0.6 of it and comes back to it")
	for _, step in ipairs({ down, up }) do
		assert(Set(step, "Duration") == 0.25 and (Set(step, "StartDelay") or 0) == 0 and (Set(step, "EndDelay") or 0) == 0, what .. ": each step takes 0.25 s with no pause, two blinks a second")
	end
end

-- The warnings by the callers that play them, whatever rate a wrong one would have: every ember watch (a medal, the horn), every slot's refresh cue, the last Lightning
-- Shield orb, a rune stone's gutter and the last Inner Fire flame.
local met, checked = {}, {}
local function Warnings(ns, class)
	local n = 0
	local function check(group, what)
		if group then
			Flicker(group, class .. " " .. what)
			n = n + 1
			met[what], checked[group] = true, true
		end
	end
	for _, e in ipairs(ns.SlabRings.state.watched) do
		check(e.flicker, "ember watch")
	end
	check(ns.SlabStorm and ns.SlabStorm.state.flicker, "storm orb")
	-- The storm's loops are the halo's clouds, all on the halo's one slot, and then a spark on each orb's own slot, whatever builds its loop.
	local storm = ns.SlabStorm and ns.SlabStorm.state.loops or {}
	for _, loop in ipairs(storm) do
		if loop.button ~= storm[1].button then check(loop.group, "storm spark") end
	end
	for _, socket in ipairs(ns.Totems and ns.Totems.state.sockets or {}) do
		check(socket.spire and socket.spire.flicker.anim, "totem spire")
	end
	local crest = ns.SlabTrackers.state.forms.crest
	local function walk(piece, key)
		for _, lit in ipairs(piece.lits or { piece.lit }) do
			check(lit.flicker, key .. " refresh cue")
			-- A caster mark's fire burns on its slot's gated copy, which carries the refresh cue of the part it burns on.
			for _, copy in ipairs(lit.mirrors or {}) do
				check(copy.flicker, key .. " fire copy")
			end
			-- The looks that burn with the one flicker while their aura shows: a fuse's head, and a flame or a crackle on a warrior's or paladin's hip.
			if lit.loop and rawget(lit.loop, "low") then check(lit.loop, key .. " burn") end
			for _, group in ipairs(lit.awake and lit.awake.lit.loops or {}) do
				if rawget(group, "low") then check(group, key .. " flame") end
			end
		end
	end
	for _, piece in pairs(crest and crest.pieces or {}) do
		local key = tostring(piece.spec and piece.spec.key)
		check(piece.gutter, "rune stone")
		check(piece.ring and piece.flicker, "Inner Fire")
		walk(piece, key)
		-- A piece with cues on its own art is built three times, once for each motion level, and each copy carries the same callers.
		for _, twin in ipairs(piece.twins or {}) do
			walk(twin, key)
		end
	end
	return n
end

-- What only builds or plays once the game drives it: a hunter's hawks and the pair's glow, and the crest's lift on a tracked cooldown's cast.
local function Travel(group)
	local curves = {}
	for _, anim in ipairs(group._anims) do
		if anim._type == "Translation" then curves[#curves + 1] = Set(anim, "Smoothing") end
	end
	return table.concat(curves, ",")
end

local function Drive(env, ns, class)
	if class == "HUNTER" then
		for slot, spell in pairs({ [2] = 1293248, [3] = 1312637 }) do
			env._totems[slot] = { start = 0, spell = spell }
			env.FireEvent("PLAYER_TOTEM_UPDATE", slot)
		end
		local p, pair = assert(ns.SlabHawks.state.perches[1], "a summon builds the hawk's perch"), assert(ns.SlabHawks.state.pair, "and two hawks the pair's glow")
		assert(p.lift:IsPlaying() and p.pops[1]:IsPlaying() and pair.dawn[1]:IsPlaying(), "the summon lifts and swells the hawk and both fade the ring's glow in")
		local up, down = p.pops[1]._anims[1], p.pops[1]._anims[2]
		assert(Set(up, "Smoothing") == "OUT" and Set(down, "ScaleTo") < Set(down, "ScaleFrom") and Set(down, "Smoothing") == "IN", "the hawk swells easing out and shrinks back easing in")
		assert(Set(pair.dawn[1]._anims[1], "Smoothing") == "OUT" and Set(pair.breath._anims[1], "Smoothing") == "IN_OUT", "the pair's glow fades in easing out and breathes easing both ways")
		-- Travel is not part 1's: the lift's way out and back and the old hawk's sinking keep the curves they had.
		assert(Travel(p.lift) == "OUT,IN_OUT" and Travel(p.sink) == "IN", "the hawk's travel keeps its own curves (" .. Travel(p.lift) .. "; " .. Travel(p.sink) .. ")")
	elseif class == "WARRIOR" then
		env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
		local lift = assert(ns.Slab.hub.crest.lift, "a tracked cooldown's cast builds the crest's lift")
		assert(lift:IsPlaying() and #lift._anims == 4, "and plays its four steps")
	end
end

-- A piece with cues on its own art has two more copies, one for each other motion level. A copy is the slots alone: it sits exactly on the piece, each slot under a layer
-- of its own, and with those layers dark nothing of a copy reaches the screen, so the piece's chrome is drawn once.
local function Copies(env, ns, class)
	local n = 0
	local function Rect(region)
		local x, y, w, h = region:GetRect()
		return string.format("%.2f,%.2f,%.2f,%.2f", x, y, w, h)
	end
	local function Seen(frame, what)
		for _, region in ipairs({ frame:GetRegions() }) do
			assert(not (region:IsVisible() and region:GetEffectiveAlpha() > 0), what .. " draws a part of its own (" .. tostring(region._origin) .. ")")
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			Seen(child, what)
		end
	end
	env._resolveRects = true
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		for i, twin in ipairs(piece.twins or {}) do
			local what = class .. " " .. piece.spec.key .. " copy " .. i
			assert(#twin.lits == #piece.lits and twin:IsShown() == piece:IsShown(), what .. " has the piece's slots and shows with it")
			for k, lit in ipairs(piece.lits) do
				local copy = twin.lits[k]
				if not lit.container then
					-- A cooldown feed beside aura slots (the hunter's pet ability) has no slot to copy: the copy leaves it dark.
					assert(not copy:IsVisible(), what .. ": slot " .. k .. " is a cooldown, which the copy leaves dark")
				else
					assert(lit.hold and copy.hold and lit.hold ~= copy.hold and lit.hold:GetAlpha() == 1 and copy.hold:GetAlpha() == 0, what .. ": the piece's own slot shows and the copy's is dark")
					assert(copy.container ~= lit.container, what .. " has an aura feed of its own")
					if piece:IsShown() then
						assert(Rect(copy) == Rect(lit), what .. ": slot " .. k .. " sits at " .. Rect(copy) .. ", not on the piece's at " .. Rect(lit))
					end
				end
			end
			env._engine = true
			Seen(twin, what)
			env._engine = nil
			n = n + 1
		end
	end
	env._resolveRects = nil
	return n
end

-- A group moves unless every step holds its alpha or its size: a still mark is a group that does not move.
local function Moves(group)
	for _, anim in ipairs(group._anims or {}) do
		local from, to = Set(anim, "FromAlpha"), Set(anim, "ToAlpha")
		if anim._type == "Scale" then from, to = Set(anim, "ScaleFrom"), Set(anim, "ScaleTo") end
		if (anim._type ~= "Alpha" and anim._type ~= "Scale") or from ~= to then return true end
	end
	return false
end

-- The moving cues the engine holds for slots that can reach the screen: bound to a slot, on a visible parent, under no dark layer.
local function Moving(env)
	local seen = {}
	env._engine = true
	for _, frame in ipairs(env._frames) do
		for _, field in ipairs({ "_shownAnimations", "_assignedAnimations", "_pandemicAnimations" }) do
			for _, group in ipairs(rawget(frame, field) or {}) do
				if Moves(group) and frame:GetParent():IsVisible() and frame:GetEffectiveAlpha() > 0 then
					seen[#seen + 1] = tostring(group._anims[1]._origin)
				end
			end
		end
	end
	env._engine = nil
	return seen
end

-- The owner's choice (review of 5fd726b9): a motion level changed in combat applies at once, to every cue. Under hidden values the engine keeps each slot's cues, so
-- no slot that still holds a moving cue may reach the screen at Calm or Off: its layer is dark and a copy bound for the level in use shows instead.
local function Quieted(env, K, class)
	env.SetCombat(true)
	local full = #Moving(env)
	assert(full > 0, class .. ": at Full the engine holds moving cues for the crest")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	for _, level in ipairs({ "calm", "off" }) do
		K.Options.Write("Medallions", "motion", level)
		env.RunTimers()
		local seen = Moving(env)
		assert(#seen == 0, class .. ": at " .. level .. ", chosen under hidden values, a slot that can show still holds a moving cue from " .. tostring(seen[1])
			.. "; put the slot under a layer that is dark at this level (Medals.Twins, or a moving and a still copy)")
	end
	K.Options.Write("Medallions", "motion", "full")
	env.RunTimers()
	assert(#Moving(env) == full, class .. ": Full, chosen under hidden values, shows every moving cue again")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
end

-- A group's size steps make one path, composed by the rule anim_pose.lua names: it never jumps where a later step starts, and a group that does not loop
-- ends at its region's own size or faded out, since the region takes its own size back when the group ends. Chain(group, what) -> 1 for a group of two or more
-- size steps, after checking its path, otherwise 0.
local function Chain(group, what)
	local timed, _, length = Pose.Passes(group)
	local scales, last, fade = 0, nil, nil
	for _, each in ipairs(timed) do
		if each.anim._type == "Scale" then scales = scales + 1 end
	end
	if scales < 2 then return 0 end
	local origin = tostring(group._anims[1]._origin)
	for _, each in ipairs(timed) do
		if each.anim._type == "Scale" and each.from > 0 then
			local _, _, _, before = Pose.At(timed, each.from - 1e-4)
			local _, _, _, after = Pose.At(timed, each.from + 1e-4)
			assert(math.abs(after - before) < 0.01, string.format("%s: the size chain from %s jumps from %.3f to %.3f where its step %d starts at %.3f s; write the step from 1 to the next size over the last",
				what, origin, before, after, each.anim:GetOrder(), each.from))
		end
	end
	for _, anim in ipairs(group._anims) do
		if anim._type == "Alpha" and (not last or (Set(anim, "Order") or 1) >= last) then last, fade = Set(anim, "Order") or 1, Set(anim, "ToAlpha") end
	end
	local _, _, _, ends = Pose.At(timed, length)
	local looping = Set(group, "Looping") == "REPEAT" or Set(group, "Looping") == "BOUNCE"
	assert(looping or math.abs(ends - 1) < 0.01 or fade == 0, string.format("%s: the size chain from %s ends at %.3f and still shows, so it snaps back to 1 as the group ends", what, origin, ends))
	return 1
end

local flickers, steps, named, copies, chains = {}, { enter = 0, exit = 0, loop = 0 }, {}, {}, {}
for _, class in ipairs(CLASSES) do
	local env, K, ns = New(class)
	Quieted(env, K, class)
	copies[class] = Copies(env, ns, class)
	Drive(env, ns, class)
	named[class] = Warnings(ns, class)
	flickers[class], chains[class] = 0, 0
	Groups(env, function(group)
		chains[class] = chains[class] + Chain(group, class)
		local alphaOnly, cycle = true, 0
		local looping = Set(group, "Looping") == "REPEAT" or Set(group, "Looping") == "BOUNCE"
		for _, anim in ipairs(group._anims) do
			local smoothing, from, to = Set(anim, "Smoothing")
			if anim._type == "Alpha" then
				from, to = Set(anim, "FromAlpha"), Set(anim, "ToAlpha")
			elseif anim._type == "Scale" then
				from, to = Set(anim, "ScaleFrom"), Set(anim, "ScaleTo")
			end
			if from and to and from ~= to then
				local kind = looping and "loop" or to < from and "exit" or "enter"
				assert(smoothing == WANT[kind], class .. ": a " .. anim._type .. " from " .. from .. " to " .. to .. " (" .. tostring(anim._origin) .. ") eases " .. tostring(smoothing)
					.. ", not " .. WANT[kind] .. "; build it with ns.Slab.Fade or Grow and no curve of its own")
				steps[kind] = steps[kind] + 1
			elseif anim._type == "Alpha" or anim._type == "Scale" then
				assert(from == to or smoothing == "IN" or smoothing == "OUT" or smoothing == "IN_OUT", class .. ": a linear " .. anim._type .. " from " .. tostring(anim._origin))
			end
			alphaOnly = alphaOnly and anim._type == "Alpha"
			cycle = cycle + (Set(anim, "Duration") or 0) + (Set(anim, "StartDelay") or 0) + (Set(anim, "EndDelay") or 0)
		end
		-- Every flicker the action bars build with ns.Slab.Flicker is one of the callers named above, so a new caller is named there too.
		assert(rawget(group, "low") == nil or checked[group], class .. ": a flicker from " .. tostring(group._anims[1]._origin) .. " that the walk by caller does not name; add its caller to Warnings")
		if alphaOnly and Set(group, "Looping") == "REPEAT" and cycle <= 0.5 then
			Flicker(group, class .. ": a second end-warning rate (" .. cycle .. " s a cycle) from " .. tostring(group._anims[1]._origin) .. "; use ns.Slab.Flicker")
			flickers[class] = flickers[class] + 1
		end
	end)
end
for _, class in ipairs(CLASSES) do
	assert(named[class] > 0, class .. ": the walk by caller meets a warning")
end
for _, what in ipairs({ "ember watch", "storm orb", "storm spark", "totem spire", "rune stone", "Inner Fire", "crestMark refresh cue", "crestCurse refresh cue", "crestFlameShock refresh cue",
	"crestSting burn", "crestYourSpell burn", "crestCurse burn", "crestDemon burn", "crestHipLeft flame", "crestHipRight flame" }) do
	assert(met[what], "the walk by caller meets the " .. what)
end
assert(flickers.WARRIOR > 0 and flickers.HUNTER > 0 and flickers.SHAMAN > 0 and flickers.WARLOCK > 0, "the walk meets the flicker on warriors, hunters, shamans and warlocks")
assert(steps.enter > 0 and steps.exit > 0 and steps.loop > 0, "and steps of all three kinds")
assert(chains.WARRIOR > 0 and chains.HUNTER > 0 and chains.MAGE > 0 and chains.WARLOCK > 0, "the walk meets size chains on the crest's pulse and lift and on the rail's medals")
for _, class in ipairs({ "HUNTER", "WARLOCK", "MAGE", "PRIEST", "SHAMAN", "DRUID" }) do
	assert(copies[class] > 0, class .. ": a ranged crest has pieces with copies for the other motion levels")
end

local function Has(list, item)
	for _, each in ipairs(list) do
		if each == item then return true end
	end
	return false
end

local function Motion(env, K, level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
end

local function Piece(ns, key)
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.key == key and piece:IsShown() then return piece end
	end
end

-- Calm keeps the refresh cue as a still mark on every slot that flickers at Full: the engine holds the same part at the flicker's low alpha through the refresh window, on
-- the ranged kit's mark, stacks, band and spire paths as on a figure. Off keeps neither.
for _, case in ipairs({ { "HUNTER", "crestMark" }, { "HUNTER", "crestSting" }, { "WARLOCK", "crestCurse" }, { "WARLOCK", "crestDemon" }, { "SHAMAN", "crestFlameShock" } }) do
	local env, K, ns = New(case[1])
	local what = case[1] .. " " .. case[2] .. ": "
	local piece = assert(Piece(ns, case[2]), what .. "the piece is on the crest")
	local lit = (piece.lits or { piece.lit })[1]
	local flicker = assert(lit.flicker, what .. "its slot flickers in the refresh window")
	local function Feed(pandemic)
		local harmful = (lit.spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
		Slots.Set(env, lit.spec.unit or "player", { { id = lit.spec.spells[1], start = 0, duration = 30, harmful = harmful, mine = true, pandemic = pandemic } })
		assert(lit:IsShown(), what .. "the slot takes the aura")
	end
	assert(Has(lit._pandemicAnimations, flicker) and #lit._pandemicAnimations == 1, what .. "at Full the refresh cue is the flicker")
	Feed(true)
	assert(flicker:IsPlaying(), what .. "and it plays inside the refresh window")
	Motion(env, K, "calm")
	local still = flicker.still
	assert(still and Has(lit._pandemicAnimations, still) and #lit._pandemicAnimations == 1 and not flicker:IsPlaying(), what .. "at Calm the engine gets a still mark instead of the flicker")
	local hold = still._anims[1]
	assert(#still._anims == 1 and Set(hold, "FromAlpha") == Set(hold, "ToAlpha") and Set(hold, "ToAlpha") == Set(flicker._anims[1], "ToAlpha"),
		what .. "the mark holds the part at the flicker's low alpha and never moves")
	Feed(false)
	assert(not still:IsPlaying(), what .. "outside the refresh window the mark is off")
	Feed(true)
	assert(still:IsPlaying() and not flicker:IsPlaying(), what .. "inside it the mark shows, still")
	assert(#lit._shownAnimations == 0, what .. "Calm drops the loops")
	Motion(env, K, "off")
	assert(#lit._pandemicAnimations == 0 and not still:IsPlaying() and not flicker:IsPlaying(), what .. "at Off there is neither mark nor flicker")
	Motion(env, K, "full")
	assert(Has(lit._pandemicAnimations, flicker) and #lit._pandemicAnimations == 1, what .. "Full brings the flicker back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A ranged piece that blooms itself as it lands (a hunter's Aspect) keeps a still ready mark at Calm too: the Aspect burns as an aura, so its bloom plays on the
-- burning copy and Calm's still mark on the copy bound for Calm, holding the sigil at its bloom's size for one short pass on each new aura, in place of the growth.
do
	local env, K, ns = New("HUNTER")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local aspect = assert(Piece(ns, "crestAspect"), "the Aspect perch")
	local lit = aspect.lits[1]
	local burning = lit.art:GetParent():GetParent()
	local bloom = assert(burning.flare and burning.flare.play, "an Aspect blooms on its burning copy")
	-- The seven Aspects share one cue layer, each with its own slot on it, so the Hawk's slot is the mirror of its own light bound for Calm.
	local cue
	for _, mirror in ipairs(lit.mirrors) do
		cue = mirror.burns == "calm" and mirror or cue
	end
	local still = assert(lit.cues and cue and cue.flare, "and has a still mark on a copy bound for Calm").still
	local hold, grow = still._anims[1], bloom._anims[1]
	assert(hold._type == "Scale" and Set(hold, "ScaleFrom") == Set(hold, "ScaleTo") and Set(hold, "ScaleTo") == Set(grow, "ScaleFrom") and Set(still, "Looping") == nil,
		"the mark holds the sigil at the size its bloom starts from, for one pass, and never moves")
	Motion(env, K, "calm")
	Slots.Set(env, "player", { { id = lit.spec.spells[1], start = 0, duration = 600 } })
	assert(cue:IsShown() and still:IsPlaying() and lit.cues:GetAlpha() == 1, "a new Aspect at Calm shows the still mark")
	assert(K.Effects.Holder("crestFlare") == K.Effects.PRIORITY.ready, "and it takes the crest's flare place as any ready cue does")
	env.RunTimers()
	Slots.Set(env, "player", {})
	Motion(env, K, "off")
	Slots.Set(env, "player", { { id = lit.spec.spells[1], start = 0, duration = 600 } })
	assert(lit.cues:GetAlpha() == 0 and K.Effects.Holder("crestFlare") == nil, "Off shows no still mark and claims nothing")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Under hidden values the engine keeps the animations it was given, and Lua may not touch them. A medal's flare therefore has two slots, each under a layer the addon
-- owns: one holds Full's flare and one Calm's still mark, whatever the level in use. A level changed in combat shows at once, because the layer bound for it lights
-- and the other goes dark; Off darkens both. The slots are bound again when the restriction ends.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local fed = assert(Piece(ns, "crestEnrage"), "an aura medal")
	local gate = fed.lit.flareGate
	local other = assert(gate.other, "the flare has a second slot")
	local slot, alt = gate.lit, other.lit
	assert(gate ~= other and slot.container ~= alt.container and other:GetParent() == fed, "under a layer and an aura feed of its own")
	local function Bound()
		return Has(slot._assignedAnimations, slot.flare.play) and #slot._assignedAnimations == 1 and Has(alt._assignedAnimations, alt.flare.still) and #alt._assignedAnimations == 1
	end
	assert(Bound() and gate:GetAlpha() == 1 and other:GetAlpha() == 0, "at Full the first slot has the flare and shows; the second has the still mark and is dark")
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	local function Gain()
		Slots.Set(env, "player", nil)
		Slots.Set(env, "player", { { id = fed.lit.spec.spells[1], start = 0, duration = 12 } })
	end
	local showing = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")

	Motion(env, K, "calm")
	assert(Bound(), "calm under hidden values: the engine keeps what it was given")
	assert(gate:GetAlpha() == 0 and other:GetAlpha() == 1, "calm under hidden values: the flare's layer is dark and the still mark's shows")
	showing:Play()
	Gain()
	assert(Engine(function() return slot.flare.play:IsPlaying() and slot.flare:GetEffectiveAlpha() == 0 end), "calm under hidden values: a new aura's flare plays unseen")
	assert(Engine(function() return alt.flare.still:IsPlaying() end) and not showing:IsPlaying(), "and its still mark shows at once, taking the crest's flare place as it does out of combat")

	Motion(env, K, "off")
	assert(Bound() and gate:GetAlpha() == 0 and other:GetAlpha() == 0, "off under hidden values: both layers are dark")
	showing:Play()
	Gain()
	assert(Engine(function() return slot.flare:GetEffectiveAlpha() == 0 and alt.flare:GetEffectiveAlpha() == 0 end), "off under hidden values: nothing of a new aura's cue reaches the screen")
	assert(showing:IsPlaying(), "and a cue nobody sees takes no place: a flare that is showing plays on")
	showing:Stop()

	Motion(env, K, "full")
	assert(gate:GetAlpha() == 1 and other:GetAlpha() == 0, "full under hidden values: the flare's layer shows again")
	Motion(env, K, "off")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	assert(Bound() and gate:GetAlpha() == 0 and other:GetAlpha() == 0, "at Off out of combat the slots keep both cues under dark layers, ready for a level changed in the next fight")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Motion(env, K, "full")
	assert(gate:GetAlpha() == 1 and other:GetAlpha() == 0, "so Off to Full in combat shows the flare")
	Motion(env, K, "calm")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	assert(Has(slot._assignedAnimations, slot.flare.still) and #slot._assignedAnimations == 1 and gate:GetAlpha() == 1, "when the restriction ends at Calm the first slot gets the still mark and shows")
	assert(Has(alt._assignedAnimations, alt.flare.play) and #alt._assignedAnimations == 1 and other:GetAlpha() == 0, "and the second gets the flare, dark")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A cue on a ranged piece's own art (a refresh flicker, a bloom, a loop) cannot sit under a layer apart from the art. Such a piece has two copies of its slots, so each
-- motion level has a slot bound for it: the level in use shows its slot's layer and the other two are dark. A level changed in combat swaps the layers at once.
do
	local env, K, ns = New("HUNTER")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local sting = assert(Piece(ns, "crestSting"), "the hunter's sting")
	assert(sting.twins and #sting.twins == 2, "has two copies")
	local full, calm, off = sting.lits[1], sting.twins[1].lits[1], sting.twins[2].lits[1]
	local function Alphas()
		return full.hold:GetAlpha() .. "," .. calm.hold:GetAlpha() .. "," .. off.hold:GetAlpha()
	end
	local function Bound()
		return Has(full._pandemicAnimations, full.flicker) and #full._pandemicAnimations == 1 and #full._shownAnimations > 0
			and Has(calm._pandemicAnimations, calm.flicker.still) and #calm._pandemicAnimations == 1 and #calm._shownAnimations == 0
			and #off._pandemicAnimations == 0 and #off._shownAnimations == 0 and #off._assignedAnimations == 0
	end
	assert(Bound(), "the piece's slot has Full's flicker and loops, one copy Calm's still mark and no loop, the other nothing")
	assert(Alphas() == "1,0,0", "at Full the piece's own slot shows (" .. Alphas() .. ")")
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local harmful = (full.spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
	Slots.Set(env, full.spec.unit or "player", { { id = full.spec.spells[1], start = 0, duration = 30, harmful = harmful, mine = true, pandemic = true } })
	assert(Engine(function() return full.flicker:IsPlaying() and calm.flicker.still:IsPlaying() and off:IsShown() end), "one aura lights all three slots, each with its own cue")
	Motion(env, K, "calm")
	assert(Bound() and Alphas() == "0,1,0", "calm under hidden values: the still mark's slot shows and the flickering one is dark (" .. Alphas() .. ")")
	assert(Engine(function() return full.flicker:GetParent():GetEffectiveAlpha() == 0 end), "so the flicker the engine still plays does not reach the screen")
	Motion(env, K, "off")
	assert(Bound() and Alphas() == "0,0,1", "off under hidden values: the slot with no cue shows (" .. Alphas() .. ")")
	Motion(env, K, "full")
	assert(Bound() and Alphas() == "1,0,0", "full under hidden values: the flickering slot shows again (" .. Alphas() .. ")")
	Motion(env, K, "calm")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	assert(Has(full._pandemicAnimations, full.flicker.still) and #full._shownAnimations == 0 and Alphas() == "1,0,0", "when the restriction ends the piece's own slot is bound for Calm and shows (" .. Alphas() .. ")")
	assert(Has(calm._pandemicAnimations, calm.flicker) and #off._pandemicAnimations == 0, "and the copies take the other two levels")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The same holds for a cue on a slot the piece adds beside its first one: a mage's stack embers (Scorch, Winter's Chill) and a warlock's torment spires. A live
-- warning is followed through the three levels under hidden values.
for _, case in ipairs({ { "MAGE", "crestSchool" }, { "WARLOCK", "crestTorments" } }) do
	local env, K, ns = New(case[1])
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local what = case[1] .. " " .. case[2] .. ": "
	local piece = assert(Piece(ns, case[2]), what .. "the piece is on the crest")
	assert(piece.twins and #piece.twins == 2, what .. "has a copy of its slots for each other level")
	local k
	for n, lit in ipairs(piece.lits) do
		if (n > 1 or case[2] == "crestTorments") and (lit.flicker or lit.loop) then k = k or n end
	end
	local full, calm, off = assert(piece.lits[k], what .. "a slot beside the first has a cue"), piece.twins[1].lits[k], piece.twins[2].lits[k]
	local spec = full.spec or piece.lits[1].spec
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	local function Seen()
		return Engine(function() return (full:GetEffectiveAlpha() > 0 and "full" or "") .. (calm:GetEffectiveAlpha() > 0 and "calm" or "") .. (off:GetEffectiveAlpha() > 0 and "off" or "") end)
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local harmful = (spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
	Slots.Set(env, spec.unit or "player", { { id = spec.spells[1], count = 5, start = 0, duration = 30, harmful = harmful, mine = true, pandemic = true } })
	local cue = full.flicker or full.loop
	assert(Engine(function() return full:IsShown() and calm:IsShown() and off:IsShown() and cue:IsPlaying() end), what .. "one aura lights the slot and both copies, and the cue plays")
	assert(Seen() == "full", what .. "at Full the moving slot shows (" .. Seen() .. ")")
	Motion(env, K, "calm")
	assert(Seen() == "calm" and Engine(function() return cue:IsPlaying() end), what .. "calm under hidden values: the cue the engine still plays is dark and the calm copy shows (" .. Seen() .. ")")
	if full.flicker then
		assert(Engine(function() return calm.flicker.still:IsPlaying() and not calm.flicker:IsPlaying() end), what .. "with the still mark in place of the flicker")
	else
		assert(#calm._shownAnimations == 0, what .. "with no loop")
	end
	Motion(env, K, "off")
	assert(Seen() == "off" and #off._pandemicAnimations == 0 and #off._shownAnimations == 0, what .. "off under hidden values: the copy with no cue shows (" .. Seen() .. ")")
	Motion(env, K, "full")
	assert(Seen() == "full", what .. "full under hidden values: the moving slot shows again (" .. Seen() .. ")")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- An aura mark a slot feeds burns its fire and its still on two gated copies of that slot (the aura kit's motion rule, KSTY-51 plan): the caster's perches,
-- fuse heads, stack embers, spire feet and sacrificed demons, the cooldown sigils and the hunter's gust. Under hidden values the engine keeps every binding, so the
-- fire's loop stays bound at each level and only the layers choose: a level chosen during the pull shows at once, from a restriction begun at Calm, Off or rest,
-- and the loop stops when its aura clears or its piece is switched off.
local function Unknown(...)
	local set = {}
	for _, list in ipairs({ ... }) do
		for _, id in ipairs(list) do set[id] = true end
	end
	return set
end
-- Each build seats one choice per seat: a mage who conjures no gem wears the Intellect perch, one without the Scorch talents stacks Winter's Chill embers, and a
-- warlock who makes no healthstone wears the armor perch. The counts are the fires each fed seat shows: one head or perch, a fire per curse (five), per Torment
-- foot (four) and per stack ember (five, the spec's stacks); one sacrificed demon, the Imp's buff fed alone; one gust; and a sigil per cooldown-row family with
-- an aura sheet that the crest rail does not hold. The rail takes the class's long cooldowns and the player's own racial, so the row keeps the potions and the
-- other races' racials the fixture's spellbook knows (Perception and Will of the Forsaken where a mage or warlock race has them), and the warlock's Shadow Ward
-- and sacrificed-demon sigils. A mage's second rail fills with its other cooldowns first (Blink, Frost Nova, Fire Blast and the rest) but keeps its first
-- racial, so the other major racials it would take fall back to the row, two more fires there.
for _, build in ipairs({
	{ "MAGE", { crestYourSpell = 1, crestCooldowns = 9 } },
	{ "MAGE", { crestSchool = 5, crestManaGem = 1 }, Unknown({ 10054, 10053, 3552, 759 }, { 11095, 12872, 12873 }) },
	{ "WARLOCK", { crestTorments = 4, crestCurse = 5, crestDemon = 1, crestCooldowns = 9 } },
	{ "WARLOCK", { crestHealthstone = 1 }, Unknown({ 11730, 11729, 5699, 6202, 6201 }) },
	{ "HUNTER", { crestGust = 1, crestCooldowns = 5 } },
}) do
	local class, want = build[1], build[2]
	local env, K, ns = New(class, build[3])
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local lits, auras = {}, {}
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		for _, lit in ipairs(piece.lits) do
			if want[piece.spec.key] and lit.lights and lit:GetParent():IsVisible() then
				local spec = lit.spec
				local unit, harmful = spec.unit or "player", (spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
				auras[unit] = auras[unit] or {}
				for _, family in ipairs(spec.families or { spec }) do
					table.insert(auras[unit], { id = family.spells[1], count = 3, start = 0, duration = 30, harmful = harmful, mine = true })
				end
				lits[#lits + 1] = { lit = lit, key = piece.spec.key, what = class .. " " .. piece.spec.key .. " " .. spec.spells[1] }
			end
		end
	end
	local function Feed(on)
		for unit, list in pairs(auras) do
			Slots.Set(env, unit, on and list or {})
		end
	end
	Feed(true)
	local fires, seen, burning = {}, {}, {}
	local function Find(frame, each)
		for _, region in ipairs(frame._regions or {}) do
			if region.loop and region.still and not seen[region] then
				seen[region] = true
				fires[#fires + 1] = { fire = region, what = each.what }
				burning[each.key] = (burning[each.key] or 0) + 1
			end
		end
		for _, kid in ipairs(frame._kids or {}) do
			Find(kid, each)
		end
	end
	for _, each in ipairs(lits) do
		for _, copy in ipairs(each.lit.mirrors) do
			if copy.burns and copy:IsShown() then
				Find(copy, each)
				for _, slot in pairs(copy.container and copy.container._slots or {}) do
					if slot.frame ~= copy and slot.frame:IsShown() then Find(slot.frame, each) end
				end
			end
		end
	end
	for key, count in pairs(want) do
		assert(burning[key] == count, class .. ": " .. key .. " burns " .. count .. " fires on its flame copies (" .. tostring(burning[key]) .. ")")
	end
	-- Under hidden values the addon writes nothing to these slots' containers: a level is chosen by the layers alone, so a container switched off and on again
	-- inside the pull, which would end in the same picture, is caught here.
	local writes, watched = {}, {}
	local function Watch(container)
		if not container or watched[container] then return end
		watched[container] = true
		for _, name in ipairs({ "SetEnabled", "SetAuraSlotEnabled", "SetUnit", "AddAuraSlot", "UpdateAllAuras" }) do
			local write = container[name]
			container[name] = function(...)
				if env._aurasSecret then writes[#writes + 1] = name end
				return write(...)
			end
		end
	end
	for _, each in ipairs(lits) do
		Watch(each.lit.container)
		for _, copy in ipairs(each.lit.mirrors) do
			Watch(copy.container)
		end
	end
	local function Shows(region)
		return region:IsVisible() and region:GetEffectiveAlpha() > 0
	end
	local function Check(level, moving)
		env._engine = true
		for _, f in ipairs(fires) do
			assert(f.fire.loop:IsPlaying(), f.what .. ": at " .. level .. " the fire's loop stays bound and playing")
			assert(Shows(f.fire) == moving and Shows(f.fire.still) == not moving, f.what .. ": at " .. level .. " under hidden values the " .. (moving and "fire" or "still") .. " shows alone")
		end
		env._engine = nil
	end
	local function Restrict(on)
		env._aurasSecret = on
		env.SetCombat(on)
		env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
		env.RunTimers()
	end
	for _, start in ipairs({ "calm", "off", "rest" }) do
		if start == "rest" then
			K.Options.Write("Medallions", "restingCrest", true)
			env.SetTarget(false)
			env.RunTimers()
		else
			Motion(env, K, start)
		end
		Check("the " .. start .. " start", false)
		-- The pull begins: auras go secret and combat wakes a resting crest; Full is then chosen while they stay secret.
		Restrict(true)
		Motion(env, K, "full")
		Check("full from " .. start, true)
		for _, step in ipairs({ { "calm", false }, { "off", false }, { "full", true } }) do
			Motion(env, K, step[1])
			Check(step[1] .. " from " .. start, step[2])
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
		if start == "rest" then
			-- Every aura clears in the pull: each loop stops with its slot.
			Feed(false)
			env._engine = true
			for _, f in ipairs(fires) do
				assert(not f.fire.loop:IsPlaying() and not Shows(f.fire), f.what .. ": its aura cleared under hidden values, the fire's loop stops")
			end
			env._engine = nil
			Feed(true)
		end
		assert(#writes == 0, class .. ": from the " .. start .. " start the pull wrote to a fed slot's container (" .. table.concat(writes, ", ") .. ")")
		Restrict(false)
		if start == "rest" then
			K.Options.Write("Medallions", "restingCrest", false)
			env.SetTarget(true)
			env.RunTimers()
		end
	end
	-- Each piece switched off after the pull takes its loops with it.
	for key in pairs(want) do
		K.Options.Write("ActionBars", key, false)
	end
	env.RunTimers()
	for _, f in ipairs(fires) do
		assert(not f.fire.loop:IsPlaying() and not Shows(f.fire), f.what .. ": its piece switched off, the fire's loop stops")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A cue that began while its layer was dark took no flare place, so a level change may not bring it on screen half played beside the flare that holds the place: its
-- layer stays dark for the rest of the cue's time and shows again after it.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local cool, fed = assert(Piece(ns, "crestFootLeft"), "a cooldown medal"), assert(Piece(ns, "crestEnrage"), "an aura medal")
	local ready = assert(cool.timer:GetScript("OnCooldownDone"), "the cooldown medal flares from its own timer's end")
	local gate, other = fed.lit.flareGate, fed.lit.flareGate.other
	Motion(env, K, "off")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env._now = 100
	Slots.Set(env, "player", { { id = fed.lit.spec.spells[1], start = 0, duration = 12 } })
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	K.Options.Write("Medallions", "motion", "calm")
	assert(other.base == 1 and other:GetAlpha() == 0, "Off to Calm inside the cue's time: the still mark that began unseen stays dark")
	ready(cool.timer)
	assert(cool.flare.still:IsPlaying(), "a ready cue that starts now takes the place and shows")
	K.Options.Write("Medallions", "motion", "full")
	assert(gate.base == 1 and gate:GetAlpha() == 0, "Calm to Full inside the cue's time: the flare that began unseen stays dark too")
	for _, fn in ipairs(armed) do fn() end
	assert(gate:GetAlpha() == 1, "and its layer shows once the cue's time is over")
	K.Options.Write("Medallions", "motion", "off")
	Slots.Set(env, "player", nil)
	Slots.Set(env, "player", { { id = fed.lit.spec.spells[1], start = 0, duration = 12 } })
	env._now = 101
	K.Options.Write("Medallions", "motion", "full")
	assert(gate:GetAlpha() == 1, "a cue whose time is already over hides nothing")
	env.C_Timer.After = after
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A warning Lua plays itself follows the same rule through ns.Slab.Warn: the flicker at Full, the still mark at Calm, nothing at Off.
do
	local env, K, ns = New("WARRIOR")
	local blink = ns.Slab.Flicker(ns.Slab.hub:CreateTexture())
	ns.Slab.Warn(blink, true)
	assert(blink:IsPlaying() and not blink.still, "Full flickers")
	Motion(env, K, "calm")
	ns.Slab.Warn(blink, true)
	assert(not blink:IsPlaying() and blink.still:IsPlaying(), "Calm holds the still mark")
	ns.Slab.Warn(blink, false)
	assert(not blink.still:IsPlaying(), "and drops it when the warning ends")
	Motion(env, K, "off")
	ns.Slab.Warn(blink, true)
	assert(not blink:IsPlaying() and not blink.still:IsPlaying(), "Off shows neither")
end

-- Crest flares share one place in the effects arbiter whatever starts them: a cooldown's own timer ending (Lua) and a new aura in a slot (the engine) stop each other, so
-- two never overlap. Calm keeps each as a still mark; Off plays none.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local Effects = K.Effects
	local cool, fed = assert(Piece(ns, "crestFootLeft"), "a cooldown medal"), assert(Piece(ns, "crestEnrage"), "an aura medal")
	local ready = assert(cool.timer:GetScript("OnCooldownDone"), "the cooldown medal flares from its own timer's end")
	local slot = fed.lit.flareGate.lit
	local function Gain(on)
		Slots.Set(env, "player", on and { { id = fed.lit.spec.spells[1], start = env._now or 0, duration = 12 } } or nil)
	end
	assert(Has(slot._assignedAnimations, slot.flare.play), "at Full the engine plays the aura medal's flare on each new aura")
	ready(cool.timer)
	assert(cool.flare.play:IsPlaying() and cool.flare:GetParent():GetAlpha() == 1, "a cooldown coming ready flares")
	assert(Effects.Holder("crestFlare") == Effects.PRIORITY.ready, "and holds the crest's flare place")
	Gain(true)
	assert(slot.flare.play:IsPlaying() and not cool.flare.play:IsPlaying(), "an aura's flare, started by the engine, stops the cooldown's: two never overlap")
	ready(cool.timer)
	assert(cool.flare.play:IsPlaying() and not slot.flare.play:IsPlaying(), "and the cooldown's flare stops the aura's")
	env.RunTimers()
	assert(Effects.Holder("crestFlare") == nil, "the place frees itself when the flare is over")
	cool.flare.play:Stop()
	Gain(false)

	Motion(env, K, "calm")
	ready(cool.timer)
	assert(not cool.flare.play:IsPlaying(), "Calm plays no flare animation")
	local still = assert(cool.flare.still, "Calm keeps the ready cue as a still mark")
	local hold = still._anims[1]
	assert(still:IsPlaying() and #still._anims == 1 and Set(hold, "FromAlpha") == 1 and Set(hold, "ToAlpha") == 1 and Set(still, "Looping") == nil,
		"the mark stands at full alpha for one short pass and never moves")
	assert(cool.flare:GetParent():GetAlpha() == 1, "and its layer shows")
	assert(Has(slot._assignedAnimations, slot.flare.still) and not Has(slot._assignedAnimations, slot.flare.play), "the engine gets the aura medal's still mark instead of its flare")
	Gain(true)
	assert(slot.flare.still:IsPlaying() and not slot.flare.play:IsPlaying() and not still:IsPlaying(), "a new aura shows its still mark and takes the place from the cooldown's")
	env.RunTimers()
	Gain(false)

	Motion(env, K, "off")
	ready(cool.timer)
	Gain(true)
	assert(not cool.flare.play:IsPlaying() and not still:IsPlaying() and Effects.Holder("crestFlare") == nil, "Off plays no flare, shows no mark and claims nothing")
	assert(fed.lit.flareGate:GetAlpha() == 0 and fed.lit.flareGate.other:GetAlpha() == 0, "the aura medal's two cue layers are dark")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A caster's fed mark blooms on its flame copy through the same flare place: Polymorph's fuse head and Counterspell's ready cue stop each other, and a bloom
-- begun while its copy was dark keeps that copy dark after a switch to Full for the rest of its time, while the still copy keeps the steady aura on screen. The
-- mage knows neither Ignite nor Winter's Chill, so the fuse seats its Polymorph choice.
do
	local env, K, ns = New("MAGE", Unknown({ 11119, 11120, 12846, 12847, 12848 }, { 11180, 28592, 28593, 28594, 28595 }))
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local Effects = K.Effects
	local cool, fuse = assert(Piece(ns, "crestCounterspell"), "a cooldown medal"), assert(Piece(ns, "crestYourSpell"), "Polymorph's fuse")
	local ready = assert(cool.timer:GetScript("OnCooldownDone"), "the cooldown medal flares from its own timer's end")
	local lit = fuse.lit
	local flames, stills = lit.flames, lit.stills
	local copy = lit.mark:GetParent():GetParent()
	local bloom = assert(copy.flare, "the head blooms on its flame copy").play
	assert(not lit.flare, "the fuse's own slot carries no second bloom for the same aura")
	local function Cast(id)
		Slots.Set(env, "target", { { id = id, harmful = true, start = env._now or 0, duration = 50, mine = true } })
	end
	env.SetTarget(true)
	env.RunTimers()
	Cast(118)
	assert(bloom:IsPlaying() and Effects.Holder("crestFlare") ~= nil, "a new Polymorph blooms the head and holds the crest's flare place")
	ready(cool.timer)
	assert(cool.flare.play:IsPlaying() and not bloom:IsPlaying(), "a cooldown coming ready stops the head's bloom: two never overlap")
	Cast(12826)
	assert(bloom:IsPlaying() and not cool.flare.play:IsPlaying(), "and a fresh Polymorph's bloom stops the cooldown's")
	env.RunTimers()
	bloom:Stop()
	Slots.Set(env, "target", {})

	-- Calm keeps one still arrival cue, on a copy bound for Calm whose layer only Calm lights, which takes the flare place like any flare while the unseen bloom
	-- claims nothing; Off has no cue.
	local still = assert(lit.cues and lit.cues.lit.flare, "the head has a cue copy bound for Calm").still
	Motion(env, K, "calm")
	Cast(118)
	assert(still:IsPlaying() and Effects.Holder("crestFlare") ~= nil, "at Calm a new Polymorph holds the head still for one pass in the flare place")
	assert(flames:GetAlpha() == 0 and flames.late, "the moving bloom plays only on the dark flame copy and takes no place")
	ready(cool.timer)
	assert(cool.flare.still:IsPlaying() and not still:IsPlaying(), "a cooldown's still mark stops it: one cue at a time")
	env.RunTimers()
	Slots.Set(env, "target", {})
	Motion(env, K, "off")
	Cast(118)
	assert(lit.cues:GetAlpha() == 0 and Effects.Holder("crestFlare") == nil and flames:GetAlpha() == 0, "Off shows no arrival cue and claims nothing")
	Slots.Set(env, "target", {})

	-- In a pull the copies keep the bindings made before it, so the level chosen there decides at once whether a fresh aura's cue shows: from Calm, Off shows
	-- the steady mark with no cue; from Off, Calm shows the cue. Nothing is bound while auras are secret (the slots refuse it).
	local function Pull(on)
		env._aurasSecret = on or nil
		env.SetCombat(on)
		env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
		env.RunTimers()
	end
	for _, path in ipairs({ { "calm", "off" }, { "off", "calm" } }) do
		Motion(env, K, path[1])
		Pull(true)
		Motion(env, K, path[2])
		env._now = (env._now or 0) + 10
		Cast(path[2] == "off" and 118 or 12826)
		local what = path[1] .. " to " .. path[2] .. " in the pull: "
		env._engine = true
		if path[2] == "off" then
			assert(lit.cues:GetAlpha() == 0 and Effects.Holder("crestFlare") == nil and stills:GetAlpha() == 1, what .. "a fresh aura shows its steady mark with no cue")
		else
			assert(still:IsPlaying() and lit.cues:GetAlpha() == 1 and Effects.Holder("crestFlare") ~= nil, what .. "a fresh aura's still cue shows at once in the flare place")
		end
		env._engine = nil
		env.RunTimers()
		Slots.Set(env, "target", {})
		Pull(false)
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))

	Motion(env, K, "calm")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env._now = 100
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	Cast(118)
	assert(stills:GetAlpha() == 1 and flames:GetAlpha() == 0, "at Calm the still copy shows the aura")
	K.Options.Write("Medallions", "motion", "full")
	assert(flames.base == 1 and flames:GetAlpha() == 0, "Calm to Full inside the bloom's time: the flame copy whose bloom began unseen stays dark")
	assert(stills:GetAlpha() == 1, "and the still copy keeps the steady aura on screen meanwhile")
	for _, fn in ipairs(armed) do fn() end
	assert(flames:GetAlpha() == 1 and stills:GetAlpha() == 0, "once the bloom's time is over the flame copy shows alone")
	env.C_Timer.After = after
	env._aurasSecret = nil
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A fuse built at Calm with Polymorph already on the target binds its copies with the aura present: its flame copy is dark from the start, so the bloom the
-- engine plays there claims nothing.
do
	local env, K, ns = New("MAGE", Unknown({ 11119, 11120, 12846, 12847, 12848 }, { 11180, 28592, 28593, 28594, 28595 }), function(e, K)
		K.Options.Write("Medallions", "restingCrest", false)
		K.Options.Write("Medallions", "motion", "calm")
		Slots.Set(e, "target", { { id = 118, harmful = true, start = 0, duration = 50, mine = true } })
	end)
	local lit = assert(Piece(ns, "crestYourSpell"), "Polymorph's fuse").lit
	assert(lit:IsShown() and lit.flames.base == 0 and lit.flames.late, "the first binding's bloom began on a dark flame copy and claims nothing")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Under hidden values Lua may not stop a flare the engine is playing inside an aura slot. The newer flare shows at once all the same, and the older one is hidden: its
-- slot sits under a layer of its own, which the addon owns and turns dark for the rest of the flare's time. The slot's next flare shows it again at once.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local cool, fed = assert(Piece(ns, "crestFootLeft"), "a cooldown medal"), assert(Piece(ns, "crestEnrage"), "an aura medal")
	local ready = assert(cool.timer:GetScript("OnCooldownDone"), "the cooldown medal flares from its own timer's end")
	local gate, slot = fed.lit.flareGate, fed.lit.flareGate.lit
	local function Gain(on)
		Slots.Set(env, "player", on and { { id = fed.lit.spec.spells[1], start = 0, duration = 12 } } or nil)
	end
	assert(gate:GetParent() == fed and slot.container ~= fed.lit.container, "the flare's slot has a container of its own under a layer of the medal's")
	local flare = slot.flare.play
	-- The test reads the slot's flare as the engine would; the addon's own code may not, and the stub raises if it tries.
	local function Plays()
		env._engine = true
		local playing = flare:IsPlaying()
		env._engine = nil
		return playing
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	Gain(true)
	assert(Plays() and gate:GetAlpha() == 1, "hidden values: the engine plays the aura medal's flare")
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	ready(cool.timer)
	assert(cool.flare.play:IsPlaying(), "the newer flare shows at once")
	assert(Plays() and gate:GetAlpha() == 0, "the older one, which Lua may not stop, is hidden by its own layer")
	assert(fed:IsShown() and fed:GetAlpha() == 1, "and nothing else of the medal is")
	for _, fn in ipairs(armed) do fn() end
	assert(gate:GetAlpha() == 1, "the layer shows again once the hidden flare's time is over")
	Gain(false)
	Gain(true)
	armed = {}
	ready(cool.timer)
	assert(gate:GetAlpha() == 0, "hidden again by the next cooldown's flare")
	Gain(false)
	Gain(true)
	assert(Plays() and gate:GetAlpha() == 1 and not cool.flare.play:IsPlaying(), "the slot's own next flare shows its layer at once and stops the cooldown's")
	env.C_Timer.After = after
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A melee seat's schools share one container for their art, and each school's flare has slots and a layer of its own: the second school's flare, landing while the
-- first still plays, shows at once and hides the first one's layer.
for _, side in ipairs({ "player", "target" }) do
	local env, K, ns = New("PALADIN")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local seat
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		local a, b = piece.lits and piece.lits[1], piece.lits and piece.lits[2]
		if a and b and a.flareGate and b.flareGate and a.container == b.container and (a.spec.unit or "player") == side then seat = piece end
	end
	assert(seat, "a paladin's crest has a seat on the " .. side .. " (Seals on the player, Judgements on the target) whose schools share a container")
	local gates, slots = { seat.lits[1].flareGate, seat.lits[2].flareGate }, {}
	assert(gates[1] ~= gates[2], "each school's flare has a layer of its own")
	for i = 1, 2 do
		slots[i] = gates[i].lit
		assert(slots[i].flare.gate == gates[i] and slots[i].container ~= slots[3 - i] and gates[i]:GetParent() == seat, "and a slot of its own under it")
	end
	assert(slots[1].container ~= slots[2].container, "on aura feeds of their own")
	local unit = seat.lits[1].spec.unit or "player"
	local harmful = (slots[1].spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
	local first = { id = slots[1].spec.spells[1], auraInstanceID = 31, start = 0, duration = 12, harmful = harmful, mine = true }
	local second = { id = slots[2].spec.spells[1], auraInstanceID = 32, start = 0, duration = 12, harmful = harmful, mine = true }
	local function Plays(i)
		env._engine = true
		local playing = slots[i].flare.play:IsPlaying()
		env._engine = nil
		return playing
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	Slots.Set(env, unit, { first })
	assert(Plays(1) and gates[1]:GetAlpha() == 1, "hidden values: the first school's flare plays")
	Slots.Set(env, unit, { first, second })
	assert(Plays(2) and gates[2]:GetAlpha() == 1, "the second school's flare shows at once")
	assert(Plays(1) and gates[1]:GetAlpha() == 0, "and the first one's, which Lua may not stop, is hidden by its own layer")
	assert(seat:IsShown() and seat:GetAlpha() == 1, "nothing else of the seat is")
	for _, fn in ipairs(armed) do fn() end
	env.C_Timer.After = after
	assert(gates[1]:GetAlpha() == 1, "the layer shows again once the hidden flare's time is over")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A ranged piece's bloom is a crest flare the engine plays too, on the flame copy its aura burns on. Newer, it shows at once and hides the older flare's layer.
-- Older, it is hidden when a newer flare shows: its flame copy goes dark for the rest of the bloom's time and the still copy keeps the steady aura on screen.
do
	local env, K, ns = New("HUNTER")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local aspect = assert(Piece(ns, "crestAspect"), "the Aspect perch")
	local lit, older = aspect.lits[1], nil
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		local gate = piece ~= aspect and piece:IsShown() and piece.lit and piece.lit.flareGate
		if gate and gate.lit and gate.lit.spec.unit == nil and not older then older = piece end
	end
	assert(older, "a hunter's crest has an aura medal with a flare")
	local gate, slot = older.lit.flareGate, older.lit.flareGate.lit
	local burning = lit.art:GetParent():GetParent()
	local bloom = assert(burning.flare, "the Aspect blooms on its flame copy").play
	assert(burning.flare.gate == lit.flames, "and that bloom is gated by the flame copies")
	local function Alphas()
		return lit.flames:GetAlpha() .. "," .. lit.stills:GetAlpha()
	end
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	-- One table an aura, as the game keeps one aura instance: a slot's flare plays again only for a new one.
	local medal, sigil = { id = slot.spec.spells[1], auraInstanceID = 21, start = 0, duration = 30 }, { id = lit.spec.spells[1], auraInstanceID = 22, start = 0, duration = 600 }
	local function Auras(first, second)
		Slots.Set(env, "player", { first and medal or sigil, second and sigil or nil })
	end
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) armed[#armed + 1] = fn end
	Auras(true, false)
	assert(Engine(function() return slot.flare.play:IsPlaying() end) and gate:GetAlpha() == 1, "hidden values: the medal's flare plays")
	Auras(true, true)
	assert(Engine(function() return bloom:IsPlaying() end) and gate:GetAlpha() == 0, "the Aspect's bloom shows at once and the older flare's layer hides")
	assert(Alphas() == "1,0", "the bloom plays on the flame copy, which shows alone (" .. Alphas() .. ")")
	armed = {}
	local other = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	other:Play()
	assert(other:IsPlaying() and Engine(function() return bloom:IsPlaying() end), "a newer flare shows at once, and Lua may not stop the bloom")
	assert(Alphas() == "0,1", "so the flame copy is hidden and the still copy shows the aura in its place (" .. Alphas() .. ")")
	assert(#armed > 0, "a timer waits out the bloom")
	for _, fn in ipairs(armed) do fn() end
	env.C_Timer.After = after
	assert(Alphas() == "1,0", "the flame copy shows again once the bloom's time is over (" .. Alphas() .. ")")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A bloom already growing its socket when aura values turn secret: a newer flare hides the flame copy, and the socket that grows sits on it,
-- so the still copy shows over a socket that never moved.
do
	local env, K, ns = New("HUNTER")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local lit = assert(Piece(ns, "crestAspect"), "the Aspect perch").lits[1]
	local burning = lit.art:GetParent():GetParent()
	local flare = burning.flare
	assert(flare.socket ~= nil, "the Aspect's bloom carries a socket of its own")
	local function Engine(fn)
		env._engine = true
		local value = fn()
		env._engine = nil
		return value
	end
	Slots.Set(env, "player", { { id = lit.spec.spells[1], auraInstanceID = 31, start = 0, duration = 600 } })
	flare.play:Stop()
	flare.play:Play()
	assert(flare.play:IsPlaying() and lit.flames:GetAlpha() == 1, "auras readable: the Aspect's bloom grows its socket on the flame copy")
	env._aurasSecret = true
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
	local after = env.C_Timer.After
	env.C_Timer.After = function() end
	local other = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	other:Play()
	env.C_Timer.After = after
	assert(Engine(function() return flare.play:IsPlaying() end), "hidden values: Lua may not stop the growing bloom")
	assert(lit.flames:GetAlpha() == 0 and lit.stills:GetAlpha() == 1, "so a newer flare hides the flame copy and the still copy shows")
	assert(Engine(function() return flare.socket:GetEffectiveAlpha() == 0 end), "and the growing socket is hidden with the bloom's light")
	local still = lit.stills
	local function Socket(frame)
		for _, region in ipairs(frame._regions or {}) do
			if region ~= flare.socket and tostring((region._state.Texture or {})[1]):find("Socket.png", 1, true) then return region end
		end
		for _, kid in ipairs(frame._kids or {}) do
			local found = kid ~= burning and Socket(kid)
			if found then return found end
		end
	end
	local shared = Socket(lit)
	assert(shared and #(shared._parent._groups or {}) == 0 and shared._parent ~= flare.socket._parent and still:GetAlpha() == 1, "while the shared socket under the still holds its size")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The warrior's horn calls once when Battle Shout lands and once as its last fifth begins, instead of every three seconds. The late call is its own one-shot for each
-- application: it does not need the expiring ember, and a shout first seen inside its last fifth still gets it, once.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local horn = Piece(ns, "crestShout")
	local call = horn.lit.awake.lit.loops[1]
	local function Seen(id, ends)
		env._auraData["player" .. SHOUT] = { auraInstanceID = id, expirationTime = ends, duration = 120, sourceUnit = "player" }
		env.FireEvent("UNIT_AURA", "player")
	end
	assert(Set(call, "Looping") == nil and type(horn.recall) == "function", "the horn's call is one pass, not a loop")
	env._now = 100
	Slots.Set(env, "player", { { id = SHOUT, start = 100, duration = 120 } })
	assert(call:IsPlaying(), "the call plays when the shout lands")
	call:Stop()
	Seen(1, 220)
	assert(not call:IsPlaying(), "nothing calls while the shout is fresh")
	env._now = 196
	env.RunTimers()
	assert(call:IsPlaying(), "the horn calls again as the last fifth begins")
	call:Stop()
	Seen(1, 220)
	env.RunTimers()
	assert(not call:IsPlaying(), "and only once for that shout")

	K.Options.Write("ActionBars", "crestEmber", false)
	env.RunTimers()
	env._now = 300
	Seen(2, 420)
	assert(not call:IsPlaying(), "with the expiring ember off a fresh shout still waits")
	env._now = 396
	env.RunTimers()
	assert(call:IsPlaying(), "and still gets its late call")
	call:Stop()
	K.Options.Write("ActionBars", "crestEmber", true)
	env.RunTimers()
	assert(not call:IsPlaying(), "switching the ember back does not repeat it")

	env._now = 610
	Seen(3, 620)
	assert(call:IsPlaying(), "a shout first seen inside its last fifth calls at once")
	call:Stop()
	Seen(3, 620)
	env.RunTimers()
	assert(not call:IsPlaying(), "once")

	-- The late call follows the timer the horn shows: a new length with the same end moves it, and it checks the shout is still there before it calls.
	-- The stub runs every timer whatever the clock says, so this part keeps the timers itself and runs each at the moment it was set for.
	local after, armed = env.C_Timer.After, {}
	env.C_Timer.After = function(delay, fn) armed[#armed + 1] = { at = env._now + delay, fn = fn } end
	local function Reach(now)
		env._now = now
		local due = {}
		for i = #armed, 1, -1 do
			if armed[i].at <= now then table.insert(due, 1, table.remove(armed, i)) end
		end
		for _, t in ipairs(due) do t.fn() end
	end
	env._now = 700
	Seen(4, 820)
	env._auraData["player" .. SHOUT] = { auraInstanceID = 4, expirationTime = 820, duration = 60, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	Reach(796)
	assert(not call:IsPlaying(), "the same shout given a shorter length no longer calls at the old last fifth")
	Reach(808)
	assert(call:IsPlaying(), "it calls at the new one")
	call:Stop()
	env._now = 900
	Seen(5, 1020)
	env._auraData["player" .. SHOUT] = nil
	Reach(996)
	assert(not call:IsPlaying(), "a shout that went away without a readable event gets no late call")
	env.C_Timer.After = after

	Motion(env, K, "calm")
	horn.recall()
	assert(not call:IsPlaying(), "Calm plays no second call")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars crest motion ok")
