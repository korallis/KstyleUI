-- test-actionbars-crest-unleashed.lua: Unleashed (SlabUnleashed.lua): a major cooldown lights the crest's corona, blazing glyphs and outer ring from the cooldown rim's own aura slots, flares the class burst as it is assigned and lifts the emblem on the player's own cast; at Full the awake layers loop through the engine, Calm, Off and the crest at rest show the still layers instead, and while auras are readable the corona folds and the glyphs cool as it ends; the switch hides it all and stops listening; nothing is written under an aura button while auras are secret; under Frames the cooldown medal wears the corona and glow.
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
			e.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
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

local RECK = { { id = 1719, count = 0, icon = 132109, start = 0, duration = 15 } }

-- The crest: feed, motion start, the emblem lift and the readable end.
do
	local env, K, ns = New()
	local rim = Rim(ns)
	local U = ns.SlabUnleashed
	local set = U.sets[1]
	assert(rim and set and set.crest and set.awake and set.still and set.fold, "the cooldown rim carries Unleashed's awake and still layers")
	assert(set.awake.lit.container._slots.lit.candidates.includeSpellIDs[1719], "fed by the rim's own cooldown auras")
	assert(not set.awake.lit:IsShown() and not set.still.lit:IsShown(), "no cooldown: nothing burns")
	env.SetCombat(true)
	Slots.Set(env, "player", RECK)
	local awake = set.awake.lit
	assert(awake:IsVisible() and set.awake:GetAlpha() == 1 and set.still:GetAlpha() == 0, "Recklessness lights the awake corona in combat")
	assert(#awake.loops == 4 and Playing(awake.loops), "the corona's two flipbooks, its breath and the glyphs' turn loop through the engine")
	assert(awake.flare.play:IsPlaying(), "the class burst grows out of the ring as the cooldown is assigned")
	assert(AB.W.LastCall(awake._cooldown, "SetCooldownFromDurationObject"), "the outer ring drains with the aura")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
	local lift = ns.Slab.hub.crest.lift
	assert(lift and lift:IsPlaying(), "the player's own cast lifts the emblem")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 6673)
	K.Store.Module("Medallions").restingCrest = false
	env.SetCombat(false)
	Slots.Set(env, "player", nil)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(set.fold.play:IsPlaying() and set.cool.play:IsPlaying(), "readable, the corona folds and the glyphs cool as it ends")
	assert(not Playing(awake.loops), "and the loops stop with the aura")
	Clean(env, K, "crest")
end

-- Motion: Calm, Off and the crest at rest show the still layers; the switch hides everything and stops listening.
do
	local env, K, ns = New()
	local U = ns.SlabUnleashed
	local set = U.sets[1]
	Slots.Set(env, "player", RECK)
	env.SetCombat(true)
	assert(set.awake:GetAlpha() == 1, "awake at Full in combat")
	K.Options.Write("Medallions", "motion", "calm")
	assert(set.awake:GetAlpha() == 0 and set.still:GetAlpha() == 1 and set.still.lit:IsVisible(), "Calm drops the loops for the still corona and glyphs")
	K.Options.Write("Medallions", "motion", "off")
	assert(set.still:GetAlpha() == 1 and not set.awake.lit.full, "Off shows the end state and gives the engine no loops")
	K.Options.Write("Medallions", "motion", "full")
	env.SetCombat(false)
	K.Store.Module("Medallions").restingCrest = true
	env.FireEvent("PLAYER_TARGET_CHANGED")
	assert(ns.Slab.Resting() and set.awake:GetAlpha() == 0 and set.still:GetAlpha() == 1, "the crest at rest holds it still")
	assert(U.state.listening, "the switch on listens for the player's casts")
	K.Options.Write("ActionBars", "crestUnleashed", false)
	env.RunTimers()
	for _, s in ipairs(U.sets) do
		assert(not s.awake:IsShown() and not s.still:IsShown(), "the switch off hides every Unleashed layer")
	end
	assert(not U.state.listening and not U.state.watching, "and stops listening")
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 1719)
	assert(not (ns.Slab.hub.crest.lift and ns.Slab.hub.crest.lift:IsPlaying()), "no lift with the switch off")
	K.Options.Write("ActionBars", "crestUnleashed", true)
	env.RunTimers()
	assert(set.awake:IsShown() and U.state.listening, "on again it comes back")
	Clean(env, K, "motion")
end

-- In combat with auras secret: a cooldown, a cast, a rest change and the aura going write nothing under an aura button.
do
	local env, K, ns = New()
	local set = ns.SlabUnleashed.sets[1]
	env._aurasSecret = true
	env.SetCombat(true)
	Slots.Set(env, "player", RECK)
	env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1719)
	K.Options.Write("Medallions", "motion", "calm")
	K.Options.Write("Medallions", "motion", "full")
	ns.SlabMedals.Rest()
	Slots.Set(env, "player", nil)
	env.FireEvent("UNIT_AURA", "player", {})
	assert(not set.fold.play:IsPlaying(), "secret, the end shows no fold: the corona ends with the ring")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(not set.fold.play:IsPlaying(), "and none plays late when the restriction ends")
	Clean(env, K, "secret")
end

-- Frames: the cooldown medal wears the corona and a breathing glow.
do
	local env, K, ns = New({ frames = true })
	local medal = Rim(ns, "row")
	local set
	for _, s in ipairs(ns.SlabUnleashed.sets) do
		if s.piece == medal then set = s end
	end
	assert(medal and set and not set.crest and not set.fold, "under Frames the cooldown medal carries Unleashed")
	Slots.Set(env, "player", RECK)
	assert(set.awake.lit:IsVisible() and #set.awake.lit.loops == 3 and Playing(set.awake.lit.loops), "a cooldown lights its corona and breathing glow")
	Clean(env, K, "frames")
end

print("actionbars crest unleashed ok")
