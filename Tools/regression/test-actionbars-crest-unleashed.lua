-- test-actionbars-crest-unleashed.lua: Unleashed (SlabUnleashed.lua): a major cooldown lights the crest's corona, hot line, blazing glyphs and outer ring from the cooldown rim's own aura slots, under the level badge and inside the crest's footprint, flares the class burst as it is assigned and lifts the emblem on the player's own cast; at Full the awake layers loop through the engine, Calm, Off and the crest at rest show the still layers, and the bindings change only out of combat; while auras are readable the corona folds and the glyphs cool when the tracked aura instance goes, whatever was cast, and an unrelated aura event queries nothing; the switch hides it all, stops its one-shots, detaches and disables its slots and stops listening, as disabling the module does; a palette change retints it; nothing is written under an aura button while auras are secret, and a cooldown that began while the crest or the switch was hidden still folds when it ends; under Frames the cooldown row wears the corona over a glow behind the row.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local function New(opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = opts.class or "WARRIOR",
		setup = function(e)
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return opts.class ~= nil or id == 1719 or id == 6673 end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_UnitAuras = e.C_UnitAuras or {}
			e._queries = 0
			e.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
				e._queries = e._queries + 1
				if e._aurasSecret then return e.Secret({}) end
				for _, a in ipairs(e._slotAuras[unit] or {}) do
					if a.id == id then return a end
				end
			end
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

-- Clearing the unit's aura has the slot fake stop the hot line's shown group, as the game does, which runs its OnStop.
local function Dark(env, unit)
	Slots.Set(env, unit or "player", nil)
end

-- Hiding an ancestor runs OnHide on every frame it takes from view, which the stub's Hide does not, so a test that hides the crest or switches it off runs each hot line layer's own OnHide.
local function Veil(action, ...)
	local sets = { ... }
	for _, set in ipairs(sets) do
		assert(set.awake:IsVisible(), "the hot line's layer is in view before it hides")
	end
	action()
	for _, set in ipairs(sets) do
		assert(not set.awake:IsVisible(), "and out of view after")
		local hide = set.awake:GetScript("OnHide")
		if hide then hide(set.awake) end
	end
end

local function Rim(ns, form)
	for _, p in pairs(ns.SlabTrackers.state.forms[form or "crest"].pieces) do
		if p.spec.families then return p end
	end
end

local function Playing(list)
	for _, g in ipairs(list or {}) do
		if not g:IsPlaying() then return false end
	end
	return list ~= nil and #list > 0
end

local function Any(list)
	for _, g in ipairs(list or {}) do
		if g:IsPlaying() then return true end
	end
	return false
end

local function Reck() return { { id = 1719, auraInstanceID = 7, count = 0, icon = 132109, start = 0, duration = 15 } } end

local function Gain(env, auras)
	Slots.Set(env, "player", auras)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = auras[1].id, auraInstanceID = auras[1].auraInstanceID } } })
end

local function Lose(env, id)
	Slots.Set(env, "player", nil)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { id } })
end

-- The crest: seat, feed, motion start, the emblem lift and the readable end.
do
	local env, K, ns = New()
	local rim, hub = Rim(ns), ns.Slab.hub
	local U = ns.SlabUnleashed
	local set = U.sets[1]
	assert(rim and set and set.crest and set.awake and set.still and set.fold, "the cooldown rim carries Unleashed's awake and still layers")
	assert(set.awake.lit.container._slots.lit.candidates.includeSpellIDs[1719], "fed by the rim's own cooldown auras")
	local awake = set.awake.lit
	local glyphs, cloud = awake.loops[3]:GetParent(), awake.loops[1]:GetParent()
	local level = glyphs:GetParent():GetFrameLevel()
	assert(level > hub:GetFrameLevel() and level < hub.top:GetFrameLevel(), "the corona, glow and glyphs draw over the ring and under the level badge")
	assert(awake._cooldown:GetFrameLevel() == level, "the thin outer ring drains with them, under the badge")
	local mask = AB.W.LastCall(cloud, "AddMaskTexture")
	assert(mask and mask[1].units == 184 and cloud:GetParent().units <= 212, "the fire is masked inside the crest's 184-unit footprint")
	local warm = 0
	for _, child in ipairs(awake._kids or {}) do
		if child:GetFrameLevel() < hub:GetFrameLevel() then warm = warm + 1 end
	end
	assert(warm == 1, "a warm burst glow burns under the ring")
	assert(not awake:IsShown() and not set.still.lit:IsShown() and set.cool:GetAlpha() == 0 and set.fold:GetAlpha() == 0, "no cooldown: nothing burns")
	env.SetCombat(true)
	Gain(env, Reck())
	assert(awake:IsVisible() and set.awake:GetAlpha() == 1 and set.still:GetAlpha() == 0, "Recklessness lights the awake corona in combat")
	assert(#awake.loops == 3 and Playing(awake.loops), "the corona's flipbook, its breath and the glyphs' turn loop through the engine")
	local burst = set.awake.burst
	assert(burst.lit.flare.play:IsPlaying(), "the class burst grows out of the ring as the cooldown is assigned")
	-- The burst is a crest flare the engine plays, which Lua may not stop under hidden values: a newer crest flare hides the burst's own layer, not the corona's.
	assert(burst:GetAlpha() == 1 and burst.lit.container ~= awake.container, "the burst's slot has a container and a layer of its own")
	local other, grow = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup()), burst.lit.flare.play
	env._aurasSecret = true
	other:Play()
	env._aurasSecret = false
	assert(other:IsPlaying() and grow:IsPlaying() and burst:GetAlpha() == 0 and set.awake:GetAlpha() == 1, "a newer crest flare hides the burst alone")
	other:Stop()
	env.RunTimers()
	assert(burst:GetAlpha() == 1, "and its layer shows again once the burst's time is over")
	-- The other order: the burst is the newer flare. It shows at once, its layer too if it was still hidden, and the older flare stops.
	Slots.Set(env, "player", nil)
	env._aurasSecret = true
	other:Play()
	Slots.Set(env, "player", Reck())
	env._aurasSecret = false
	assert(grow:IsPlaying() and burst:GetAlpha() == 1 and not other:IsPlaying(), "a burst that takes the place shows at once and stops the older flare")
	assert(AB.W.LastCall(awake._cooldown, "SetCooldownFromDurationObject"), "the outer ring drains with the aura")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
	local lift = hub.crest.lift
	assert(lift and lift:IsPlaying(), "the player's own cast lifts the emblem")
	K.Store.Module("Medallions").restingCrest = false
	env.SetCombat(false)
	Lose(env, 7)
	assert(set.fold.play:IsPlaying() and set.cool.play:IsPlaying(), "readable, the corona folds and the glyphs cool as it ends")
	assert(not Any(awake.loops), "and the loops stop with the aura")
	set.fold.play:Stop()
	Gain(env, Reck())
	Lose(env, 7)
	assert(set.fold.play:IsPlaying(), "a readable cooldown that was never cast folds too")
	set.fold.play:Stop()
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 1719)
	env._queries = 0
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = 99999, auraInstanceID = 9 } } })
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 9 } })
	assert(not set.fold.play:IsPlaying() and env._queries == 0, "a cast with no aura and unrelated aura events fold nothing and query nothing")
	Clean(env, K, "crest")
end

-- Motion and the switch: Calm, Off and the crest at rest show the still layers; bindings wait for combat to end; off stops every piece of work.
do
	local env, K, ns = New()
	local U = ns.SlabUnleashed
	local set = U.sets[1]
	local function Enabled()
		return set.awake.lit.container._enabled and set.still.lit.container._enabled
	end
	K.Options.Write("Medallions", "motion", "calm")
	Gain(env, Reck())
	assert(set.awake:GetAlpha() == 0 and set.still:GetAlpha() == 1 and set.still.lit:IsVisible() and not set.awake.lit.full, "Calm shows the still corona and glyphs and binds no loops")
	K.Options.Write("Medallions", "motion", "full")
	assert(set.awake.lit.full and Playing(set.awake.lit.loops), "Full binds the loops again")
	env.SetCombat(true)
	K.Options.Write("Medallions", "motion", "off")
	assert(set.still:GetAlpha() == 1 and set.awake.lit.full, "in combat the swap is the crest's own gate; the engine bindings wait")
	env.SetCombat(false)
	assert(not set.awake.lit.full, "and Off unbinds the loops once combat ends")
	K.Options.Write("Medallions", "motion", "full")
	K.Store.Module("Medallions").restingCrest = true
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(ns.Slab.Resting() and set.awake:GetAlpha() == 0 and set.still:GetAlpha() == 1, "the crest at rest holds it still")
	K.Store.Module("Medallions").restingCrest = false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
	Lose(env, 7)
	assert(ns.Slab.hub.crest.lift:IsPlaying() and set.fold.play:IsPlaying(), "a lift and a fold are running")
	assert(U.state.listening and Enabled(), "the switch on listens and feeds the slots")
	K.Options.Write("ActionBars", "crestUnleashed", false)
	env.RunTimers()
	for _, s in ipairs(U.sets) do
		assert(not s.awake:IsShown() and not s.still:IsShown(), "the switch off hides every Unleashed layer")
	end
	assert(not ns.Slab.hub.crest.lift:IsPlaying() and not set.fold.play:IsPlaying() and not set.cool.play:IsPlaying(), "and stops the lift, fold and cooling at once")
	assert(not U.state.listening and not Enabled() and not set.awake.lit.full, "and stops listening, disables its slots and unbinds the loops")
	Gain(env, Reck())
	assert(not Any(set.awake.lit.loops), "a cooldown while switched off starts no loop")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 1719)
	assert(not ns.Slab.hub.crest.lift:IsPlaying(), "and no lift")
	K.Options.Write("ActionBars", "crestUnleashed", true)
	env.RunTimers()
	assert(set.awake:IsShown() and U.state.listening and Enabled(), "on again it comes back")
	env.SetCombat(true)
	K.Options.Write("ActionBars", "crestUnleashed", false)
	assert(Enabled(), "switched off in combat, the slots stay as the engine has them")
	env.SetCombat(false)
	assert(not Enabled(), "until combat ends")
	K.Options.Write("ActionBars", "crestUnleashed", true)
	K.Theme.SetPalette({ WARRIOR = { r = 0.1, g = 0.3, b = 0.8 } }, 0)
	local r, g, b = set.awake.lit.loops[3]:GetParent():GetVertexColor()
	assert(math.abs(r - 0.595) < 1e-3 and math.abs(g - 0.685) < 1e-3 and math.abs(b - 0.91) < 1e-3, "a palette change retints the glyphs, mixed toward white")
	assert(set.cool:GetAlpha() == 0, "and leaves the cooling glyphs hidden")
	K.Modules.Disable("ActionBars")
	assert(not U.state.listening and not Enabled(), "disabling the module stops listening and feeding")
	Clean(env, K, "motion")
end

-- In combat with auras secret: a cooldown, a cast, a rest change and the aura going write nothing under an aura button.
do
	local env, K, ns = New()
	local set = ns.SlabUnleashed.sets[1]
	local done = set.awake.timer:GetScript("OnCooldownDone")
	env._aurasSecret = true
	env.SetCombat(true)
	Slots.Set(env, "player", Reck())
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
	K.Options.Write("Medallions", "motion", "calm")
	K.Options.Write("Medallions", "motion", "full")
	K.Theme.SetPalette({ WARRIOR = { r = 0.1, g = 0.3, b = 0.8 } }, 0)
	ns.SlabMedals.Rest()
	Dark(env)
	env.FireEvent("UNIT_AURA", "player", env.Secret({ removedAuraInstanceIDs = { 7 } }))
	assert(not set.fold.play:IsPlaying(), "secret, an aura event it cannot read folds nothing in the frame the slot hides")
	-- The crest plan: in combat the ending folds instead of cutting, the frame after the game hides the last lit slot or ends its timer.
	local function Folding()
		return set.fold.play:IsPlaying() and set.cool.play:IsPlaying()
	end
	local function Reset()
		set.fold.play:Stop()
		set.cool.play:Stop()
	end
	env.RunTimers()
	assert(Folding(), "secret, the frame after the hot line's slot hides the corona folds and the glyphs cool")
	Reset()
	-- The game timer running out is the ending: the fold plays the frame after, whether or not the game has hidden the slot yet, and the hide that follows adds nothing.
	Slots.Set(env, "player", Reck())
	done(set.awake.timer)
	env.RunTimers()
	assert(Folding(), "a hot line's timer running out folds the corona the frame after, with its slot not yet hidden")
	Reset()
	Dark(env)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "and the slot hiding afterwards folds nothing more")
	-- One cooldown running out as another takes its slot, which stays lit and so stops neither its shown group nor plays it again: the game plays the slot's assigned animations for the
	-- new aura, and that keeps the slot lit for the crest, so nothing folds until that one ends.
	Slots.Set(env, "player", Reck())
	done(set.awake.timer)
	local other
	for _, id in ipairs(set.lit.spec.spells) do
		other = other or id ~= 1719 and id
	end
	Slots.Set(env, "player", { { id = assert(other, "the rim tracks a second cooldown"), auraInstanceID = 9, count = 0, icon = 132109, start = 0, duration = 10 } })
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "a cooldown running out as another takes its lit slot folds nothing")
	done(set.awake.timer)
	env.RunTimers()
	assert(Folding(), "and that one's timer running out, the last, folds")
	Reset()
	Dark(env)
	env.RunTimers()
	done(set.awake.timer)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "and does not replay from a timer's end when nothing was lit")
	Slots.Set(env, "player", Reck())
	K.Options.Write("Medallions", "motion", "off")
	Dark(env)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "at Off the ending folds nothing")
	K.Options.Write("Medallions", "motion", "full")
	Slots.Set(env, "player", Reck())
	Veil(function() K.Options.Write("ActionBars", "crestUnleashed", false) end, set)
	Dark(env)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "switched off in combat, the slots the game still drives fold nothing")
	-- Still switched off: the game assigns a cooldown to the slots it still drives. The burst nobody sees takes no place among the crest's flares (a place it held
	-- would be taken from it by the next flare, which darkens the older one's layer), and the hidden slot counts as no lit cooldown, so its running out folds nothing
	-- when the switch comes back before the next frame.
	local showing = ns.SlabMedals.Arbitrate(ns.Slab.hub:CreateAnimationGroup())
	Slots.Set(env, "player", Reck())
	env._engine = true
	local grew = set.awake.burst.lit.flare.play:IsPlaying()
	env._engine = nil
	showing:Play()
	assert(grew and showing:IsPlaying() and set.awake.burst:GetAlpha() == 1, "switched off, the burst the game still plays unseen holds no place for the next flare to take")
	showing:Stop()
	-- The timer's own deferred check is held back here until the switch is back on and painted, the order in which a fold would show.
	local after, held = env.C_Timer.After, {}
	env.C_Timer.After = function(_, fn) held[#held + 1] = fn end
	done(set.awake.timer)
	env.C_Timer.After = after
	Slots.Set(env, "player", nil)
	local dims = {}
	env.C_Timer.After = function(_, fn) dims[#dims + 1] = fn end
	K.Options.Write("ActionBars", "crestUnleashed", true)
	env.C_Timer.After = after
	assert(set.awake.burst:IsShown() and set.awake.burst:GetAlpha() == 0, "switched back on inside the unseen burst's time, its layer stays dark: the burst took no place and may not show half played")
	for _, fn in ipairs(dims) do fn() end
	assert(set.awake.burst:GetAlpha() == 1, "and shows again once that time is over")
	env.RunTimers()
	assert(#held == 1, "the timer's end defers one check")
	held[1]()
	assert(not set.fold.play:IsPlaying(), "a cooldown assigned and run out while switched off folds nothing when the switch comes back")
	Slots.Set(env, "player", nil)
	Reset()
	K.Options.Write("ActionBars", "crestUnleashed", true)
	-- The switch hides the hot line's own layer, and its slot with it, which is no cooldown ending: off and on again with the cooldown still up folds nothing.
	Slots.Set(env, "player", Reck())
	Veil(function() K.Options.Write("ActionBars", "crestUnleashed", false) end, set)
	K.Options.Write("ActionBars", "crestUnleashed", true)
	env.RunTimers()
	assert(set.piece:IsVisible() and not set.fold.play:IsPlaying(), "switched off and on again before the next frame, the cooldown still up, nothing folds")
	Dark(env)
	env.RunTimers()
	assert(Folding(), "and that cooldown's real ending folds")
	Reset()
	-- Hiding the crest hides every slot with it, which is no cooldown ending: nothing folds then, when the crest comes back with its cooldown still up, or later from a
	-- cooldown that ended while the crest was hidden.
	Slots.Set(env, "player", Reck())
	Veil(function() set.piece:Hide() end, set)
	set.piece:Show()
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "hiding the crest and showing it again before the next frame folds nothing")
	Veil(function() set.piece:Hide() end, set)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "nor does leaving it hidden")
	Slots.Set(env, "player", nil)
	set.piece:Show()
	done(set.awake.timer)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "a cooldown that ended while the crest was hidden leaves no ending behind to fold later")
	Slots.Set(env, "player", Reck())
	Dark(env)
	env.RunTimers()
	assert(Folding(), "and the next real ending still folds")
	Reset()
	-- A timer that runs out while the crest or the switch is hidden is no ending the crest showed, even when it shows again before the deferred check runs.
	Slots.Set(env, "player", Reck())
	Veil(function() set.piece:Hide() end, set)
	done(set.awake.timer)
	set.piece:Show()
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "a timer that ran out while the crest was hidden folds nothing when it shows again in the same frame")
	Dark(env)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "nor when its slot's aura clears afterwards")
	Slots.Set(env, "player", Reck())
	Veil(function() K.Options.Write("ActionBars", "crestUnleashed", false) end, set)
	done(set.awake.timer)
	K.Options.Write("ActionBars", "crestUnleashed", true)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "a timer that ran out while switched off folds nothing when the switch comes back in the same frame")
	Dark(env)
	env.RunTimers()
	assert(not set.fold.play:IsPlaying(), "nor when its slot's aura clears afterwards, with the switch back on")
	-- A cooldown that begins while the crest or the switch is hidden lights the crest when it shows, so its ending folds.
	Veil(function() set.piece:Hide() end, set)
	Slots.Set(env, "player", Reck())
	set.piece:Show()
	Dark(env)
	env.RunTimers()
	assert(Folding(), "a cooldown that began while the crest was hidden folds as its aura clears")
	Reset()
	Veil(function() K.Options.Write("ActionBars", "crestUnleashed", false) end, set)
	Slots.Set(env, "player", Reck())
	K.Options.Write("ActionBars", "crestUnleashed", true)
	Dark(env)
	env.RunTimers()
	assert(Folding(), "a cooldown that began while switched off in combat folds as its aura clears")
	Reset()
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(not set.fold.play:IsPlaying(), "and none plays late when the restriction ends")
	Clean(env, K, "secret")
end

-- A hunter's cooldowns are fed for the player and for the pet: the fold waits for the last of them, whichever feed it is on.
do
	local env, K, ns = New({ class = "HUNTER" })
	local own, pets, fold
	for _, s in ipairs(ns.SlabUnleashed.sets) do
		if s.crest then
			fold = fold or s.fold and s
			if s.awake.lit.spec.unit == "pet" then pets = s else own = own or s end
		end
	end
	assert(own and pets and fold, "the crest has a hot line for the player's cooldowns and one for the pet's")
	local ended = own.awake.timer:GetScript("OnCooldownDone")
	local function Up(s, on)
		local spec = s.awake.lit.spec
		if on then
			Slots.Set(env, spec.unit or "player", { { id = spec.spells[1], auraInstanceID = spec.unit == "pet" and 8 or 7, start = 0, duration = 15 } })
		else
			Dark(env, spec.unit)
		end
	end
	env._aurasSecret = true
	env.SetCombat(true)
	Up(own, true)
	Up(pets, true)
	Up(own, false)
	ended(own.awake.timer)
	env.RunTimers()
	assert(not fold.fold.play:IsPlaying(), "the player's cooldown ending while the pet's is still lit folds nothing")
	Up(pets, false)
	env.RunTimers()
	assert(fold.fold.play:IsPlaying() and fold.cool.play:IsPlaying(), "the pet's ending, the last one, folds the corona")
	fold.fold.play:Stop()
	fold.cool.play:Stop()
	Up(pets, true)
	Up(pets, false)
	env.RunTimers()
	assert(fold.fold.play:IsPlaying(), "a cooldown on the pet alone folds when it ends")
	fold.fold.play:Stop()
	fold.cool.play:Stop()
	Veil(function() own.piece:Hide() end, own, pets)
	Up(pets, true)
	own.piece:Show()
	Up(pets, false)
	env.RunTimers()
	assert(fold.fold.play:IsPlaying() and fold.cool.play:IsPlaying(), "a pet cooldown that began while the crest was hidden folds when it ends")
	Clean(env, K, "pet fold")
end

-- Frames: the cooldown row wears the corona, over a breathing glow behind the row.
do
	local env, K, ns = New({ frames = true })
	local medal = Rim(ns, "row")
	local set
	for _, s in ipairs(ns.SlabUnleashed.sets) do
		if s.piece == medal then set = s end
	end
	assert(medal and set and not set.crest and not set.fold, "under Frames the cooldown row carries Unleashed")
	Gain(env, Reck())
	local loops = set.awake.lit.loops
	assert(set.awake.lit:IsVisible() and #loops == 2 and Playing(loops), "a cooldown lights its corona and breathing glow")
	assert(loops[2]:GetParent():GetFrameLevel() < medal:GetFrameLevel(), "the glow breathes behind the row")
	Clean(env, K, "frames")
end

-- KSTY-60 part 4: the blaze fires only for a family flagged major; a minor buff or a potion still drains on the cooldown rim but never sets the crest ablaze.
do
	local env, K, ns = New({ class = "WARRIOR" })
	local rim, set = Rim(ns), ns.SlabUnleashed.sets[1]
	local blaze = set.awake.lit.container._slots.lit.candidates.includeSpellIDs
	local drain = rim.lit.container._slots.lit.candidates.includeSpellIDs
	assert(blaze[1719] and blaze[20572], "Recklessness and Blood Fury, both major, feed the blaze")
	assert(drain[12292] and drain[17528], "Sweeping Strikes and a potion still drain on the cooldown rim")
	assert(not blaze[12292] and not blaze[17528], "Sweeping Strikes and a potion, not major, never feed the blaze")
	env.SetCombat(true)
	Gain(env, { { id = 12292, auraInstanceID = 9, count = 0, icon = 132306, start = 0, duration = 10 } })
	assert(rim.lit:IsVisible() and not set.awake.lit:IsShown() and not set.still.lit:IsShown(), "Sweeping Strikes lights the rim's drain and no blaze")
	Gain(env, Reck())
	assert(set.awake.lit:IsVisible(), "Recklessness still sets the crest ablaze")
	Clean(env, K, "major only")
end

print("actionbars crest unleashed ok")
