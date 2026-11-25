-- test-actionbars-crest-unleashed.lua: Unleashed (SlabUnleashed.lua): a major cooldown lights the crest's corona, hot line, blazing glyphs and outer ring from the cooldown rim's own aura slots, under the level badge and inside the crest's footprint, flares the class burst as it is assigned and lifts the emblem on the player's own cast; at Full the awake layers loop through the engine, Calm, Off and the crest at rest show the still layers, and the bindings change only out of combat; while auras are readable the corona folds and the glyphs cool when the tracked aura instance goes, whatever was cast, and an unrelated aura event queries nothing; the switch hides it all, stops its one-shots, detaches and disables its slots and stops listening, as disabling the module does; a palette change retints it; nothing is written under an aura button while auras are secret; under Frames the cooldown row wears the corona over a glow behind the row.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local function New(opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = "WARRIOR",
		setup = function(e)
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return id == 1719 or id == 6673 end
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
	assert(awake.flare.play:IsPlaying(), "the class burst grows out of the ring as the cooldown is assigned")
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
	Slots.Set(env, "player", nil)
	env.FireEvent("UNIT_AURA", "player", env.Secret({ removedAuraInstanceIDs = { 7 } }))
	assert(not set.fold.play:IsPlaying(), "secret, an aura event it cannot read folds nothing")
	-- The crest plan: in combat the ending folds from the game timer's own end instead of cutting.
	done(set.awake.timer)
	assert(set.fold.play:IsPlaying() and set.cool.play:IsPlaying(), "secret, the game timer's end folds the corona and cools the glyphs")
	set.fold.play:Stop()
	set.cool.play:Stop()
	K.Options.Write("Medallions", "motion", "off")
	done(set.awake.timer)
	assert(not set.fold.play:IsPlaying(), "at Off the timer's end folds nothing")
	K.Options.Write("Medallions", "motion", "full")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(not set.fold.play:IsPlaying(), "and none plays late when the restriction ends")
	Clean(env, K, "secret")
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

print("actionbars crest unleashed ok")
