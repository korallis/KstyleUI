-- test-actionbars-crest-motion.lua: the crest plan's motion rules, part 1. One end-warning flicker for every class (Core/Tokens.lua's Flicker: alpha 1 to 0.6 and back in two
-- 0.25 s steps, so two blinks a second), eased fades and steps everywhere on the crest, Calm keeping the ready flare and a still refresh mark, crest flares sharing one place in
-- the effects arbiter, and the warrior's horn calling once on its cast and once before it ends.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SHOUT = 25289
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function New(class)
	local env, K, ns = AB.New({ class = class, setup = function(e)
		e._trackOrigin = true
		e.C_SpellBook = e.C_SpellBook or {}
		e.C_SpellBook.IsSpellKnown = function() return true end
		e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
		e.GetTime = function() return e._now or 0 end
		e._auraData = {}
		e.C_UnitAuras = { GetUnitAuraBySpellID = function(unit, id) return e._auraData[unit .. id] end }
		e._slotGroups = true
		Slots.Install(e)
		e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
	end })
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

-- Every class: no fade or step on the crest is linear, and an alpha loop that blinks twice a second or faster is the one flicker.
local flickers = {}
for _, class in ipairs(CLASSES) do
	local env = New(class)
	flickers[class] = 0
	Groups(env, function(group)
		local alphaOnly, cycle = true, 0
		for _, anim in ipairs(group._anims) do
			local smoothing = Set(anim, "Smoothing")
			if anim._type == "Alpha" or anim._type == "Scale" then
				assert(smoothing == "IN" or smoothing == "OUT" or smoothing == "IN_OUT", class .. ": a linear " .. anim._type .. " from " .. tostring(anim._origin) .. "; build it with ns.Slab.Fade or Grow")
			end
			alphaOnly = alphaOnly and anim._type == "Alpha"
			cycle = cycle + (Set(anim, "Duration") or 0) + (Set(anim, "StartDelay") or 0) + (Set(anim, "EndDelay") or 0)
		end
		if alphaOnly and Set(group, "Looping") == "REPEAT" and cycle <= 0.5 then
			local down, up = group._anims[1], group._anims[2]
			local high = Set(down, "FromAlpha")
			assert(#group._anims == 2 and cycle == 0.5 and math.abs(Set(down, "ToAlpha") - high * 0.6) < 1e-9 and Set(up, "ToAlpha") == high,
				class .. ": a second end-warning rate (" .. cycle .. " s a cycle) from " .. tostring(down._origin) .. "; use ns.Slab.Flicker")
			flickers[class] = flickers[class] + 1
		end
	end)
end
assert(flickers.WARRIOR > 0 and flickers.HUNTER > 0 and flickers.SHAMAN > 0 and flickers.WARLOCK > 0, "the walk meets the flicker on warriors, hunters, shamans and warlocks")

-- Calm keeps the cues and drops the loops: the engine keeps the ready flare, trades the refresh flicker for a still mark it shows through the refresh window, and Off keeps neither.
do
	local found
	for _, class in ipairs(CLASSES) do
		local env, K, ns = New(class)
		for _, piece in pairs(ns.SlabTrackers.state.forms.crest and ns.SlabTrackers.state.forms.crest.pieces or {}) do
			for _, lit in ipairs(piece.lits or { piece.lit }) do
				if not found and lit.cue and lit.flicker and piece:IsShown() then
					found = { env = env, K = K, ns = ns, lit = lit, piece = piece }
				end
			end
		end
		if found then break end
	end
	assert(found, "some class has a figure with a refresh cue")
	local env, K, lit = found.env, found.K, found.lit
	local function Has(list, item)
		for _, each in ipairs(list) do
			if each == item then return true end
		end
		return false
	end
	local function Feed(pandemic)
		local harmful = (lit.spec.filter or "HELPFUL"):find("HARMFUL", 1, true) ~= nil
		Slots.Set(env, lit.spec.unit or "player", { { id = lit.spec.spells[1], start = 0, duration = 30, harmful = harmful, mine = true, pandemic = pandemic } })
		assert(lit:IsShown(), "the figure's slot takes the aura")
	end
	assert(Has(lit._pandemicAnimations, lit.flicker) and not Has(lit._pandemicRegions, lit.cue), "at Full the refresh cue is the flicker")
	Feed(true)
	assert(not lit.cue:IsShown(), "and the still mark stays hidden")
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	assert(not Has(lit._pandemicAnimations, lit.flicker) and not lit.flicker:IsPlaying(), "at Calm the flicker goes")
	assert(Has(lit._pandemicRegions, lit.cue), "and the engine gets the still mark instead")
	Feed(false)
	assert(not lit.cue:IsShown(), "outside the refresh window the mark is hidden")
	Feed(true)
	assert(lit.cue:IsShown(), "inside it the mark shows, still")
	assert(#lit._shownAnimations == 0, "Calm drops the loops")
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	assert(not Has(lit._pandemicRegions, lit.cue) and not lit.cue:IsShown() and not Has(lit._pandemicAnimations, lit.flicker), "at Off there is neither mark nor flicker")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The ready flare plays at Full and Calm, not at Off, and two crest flares never overlap: the newer one takes the arbiter's place and stops the older.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local Medals, Effects = ns.SlabMedals, K.Effects
	local flared = {}
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.flare and #flared < 2 then flared[#flared + 1] = piece end
	end
	local a, b = flared[1], flared[2]
	assert(a and b and a.flare ~= b.flare, "two crest pieces carry a ready flare")
	Medals.Fire(a)
	assert(a.flare.play:IsPlaying() and Effects.Holder("crestFlare") == Effects.PRIORITY.ready, "a ready flare plays and holds the crest's flare place")
	Medals.Fire(b)
	assert(b.flare.play:IsPlaying() and not a.flare.play:IsPlaying(), "a second flare stops the first: two never overlap")
	env.RunTimers()
	assert(Effects.Holder("crestFlare") == nil, "the place frees itself when the flare is over")
	b.flare.play:Stop()
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	Medals.Fire(a)
	assert(a.flare.play:IsPlaying() and a.flare:GetParent():GetAlpha() == 1, "Calm keeps the ready flare, and its layer shows")
	a.flare.play:Stop()
	env.RunTimers()
	K.Options.Write("Medallions", "motion", "off")
	env.RunTimers()
	Medals.Fire(a)
	assert(not a.flare.play:IsPlaying() and Effects.Holder("crestFlare") == nil, "Off plays no flare and claims nothing")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The warrior's horn calls once when Battle Shout lands and once as its last fifth begins, instead of every three seconds.
do
	local env, K, ns = New("WARRIOR")
	K.Options.Write("Medallions", "restingCrest", false)
	env.RunTimers()
	local horn
	for _, piece in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if piece.spec.key == "crestShout" then horn = piece end
	end
	local call = horn.lit.awake.lit.loops[1]
	assert(Set(call, "Looping") == nil and type(horn.recall) == "function", "the horn's call is one pass, not a loop")
	env._now = 100
	Slots.Set(env, "player", { { id = SHOUT, start = 100, duration = 120 } })
	assert(call:IsPlaying(), "the call plays when the shout lands")
	call:Stop()
	env._auraData["player" .. SHOUT] = { auraInstanceID = 1, expirationTime = 220, duration = 120, sourceUnit = "player" }
	env.FireEvent("UNIT_AURA", "player")
	assert(not call:IsPlaying(), "nothing calls while the shout is fresh")
	env._now = 196
	env.RunTimers()
	assert(call:IsPlaying(), "the horn calls again as the last fifth begins")
	call:Stop()
	K.Options.Write("Medallions", "motion", "calm")
	env.RunTimers()
	horn.recall()
	assert(not call:IsPlaying(), "Calm plays no second call")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars crest motion ok")
