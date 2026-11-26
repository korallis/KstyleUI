-- test-actionbars-crest-motion.lua: the crest plan's motion rules, part 1. One end-warning flicker for every class (Core/Tokens.lua's Flicker: alpha 1 to 0.6 and back in two
-- 0.25 s steps, so two blinks a second), fades and steps eased in the token's direction everywhere on the crest, Calm keeping the ready and refresh cues as still marks, crest
-- flares sharing one place in the effects arbiter whatever starts them, and the warrior's horn calling once on its cast and once before it ends.
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

-- Every class: an alpha or scale step that appears eases out, one that leaves eases in and a looping one eases both ways (Core/Tokens.lua's Smoothing, typed here: OUT, IN,
-- IN_OUT); a hold may carry any curve, and travel and turns keep curves of their own, which part 1 of the plan leaves alone. An alpha loop that blinks twice a second or faster is
-- the one flicker.
local WANT = { enter = "OUT", exit = "IN", loop = "IN_OUT" }
local flickers, steps = {}, { enter = 0, exit = 0, loop = 0 }
for _, class in ipairs(CLASSES) do
	local env = New(class)
	flickers[class] = 0
	Groups(env, function(group)
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
assert(steps.enter > 0 and steps.exit > 0 and steps.loop > 0, "and steps of all three kinds")

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
	local slot = fed.lit.awake.lit
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
	assert(not cool.flare.play:IsPlaying() and not still:IsPlaying() and #slot._assignedAnimations == 0 and Effects.Holder("crestFlare") == nil, "Off plays no flare, shows no mark and claims nothing")
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

	Motion(env, K, "calm")
	horn.recall()
	assert(not call:IsPlaying(), "Calm plays no second call")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

print("actionbars crest motion ok")
