-- _effects.lua: RENDER_FX starts a Medallions effect through the addon and samples its own animations at RENDER_FX_T, or the first rising alpha's peak; 3D models are not drawn.
local FX = dofile("Tools/regression/effects_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local Effects = {}

local STATES = { ready = true, cap = true, levelup = true, cast = true, stopped = true, vignette = true, burst = true, rest = true, jewels = true, hawks = true, storm = true }

-- The hawk story RENDER_FX=hawks plays, as totem updates in order: Summon Hawk at 1, 9, 20.5 and 26.5 s, at least
-- its 6 s category recovery apart, fills a free slot (2, then 3) or the oldest hawk's, and each hawk leaves
-- HAWK_LIFE seconds later.
local HAWK_LIFE = 18
local HAWKS = {
	{ at = 1, slot = 2, summon = true },
	{ at = 9, slot = 3, summon = true },
	{ at = 19, slot = 2 },
	{ at = 20.5, slot = 2, summon = true },
	{ at = 26.5, slot = 3, summon = true },
	{ at = 38.5, slot = 2 },
	{ at = 44.5, slot = 3 },
}

-- The Lightning Shield story RENDER_FX=storm plays, as the shield's charges and the player's casts in order: a cast at
-- 1 s, then three strikes at least the shield's 3.5 s proc recovery apart, the last ending the shield.
local STORM = {
	{ at = 1, spell = 10432, charges = 3 },
	{ at = 4.5, spell = 26363, charges = 2 },
	{ at = 8, spell = 26363, charges = 1 },
	{ at = 11.5, spell = 26363 },
}

local MANA = { MAGE = true, PRIEST = true, WARLOCK = true, PALADIN = true, SHAMAN = true, DRUID = true }

function Effects.State()
	local state = rawget(_G, "RENDER_FX") or os.getenv("RENDER_FX")
	if not state or state == "" then
		return nil
	end
	assert(STATES[state], "RENDER_FX must be one of ready, cap, levelup, cast, stopped, vignette, burst, rest, jewels, hawks or storm")
	local t = tonumber(rawget(_G, "RENDER_FX_T") or os.getenv("RENDER_FX_T") or "")
	return state, t
end

local function Sample(env, group, t, other)
	t = t or Scene.AnimationPeak(group)
	for _, each in ipairs({ group, other }) do
		if each._playedAt then
			each._playedAt = env._time - t
		end
	end
	return t
end

local function Fixtures(env)
	local powerType = env.UnitPowerType
	FX.Install(env)
	if powerType then
		env.UnitPowerType = powerType
	end
end

-- Jewels() -> the two counts of RENDER_JEWELS=from,to, the crest jewels' change; the unit frame's combo pips show the second.
local function Jewels()
	local from, to = (os.getenv("RENDER_JEWELS") or "4,5"):match("^(%d+),(%d+)$")
	assert(from, "RENDER_JEWELS must be from,to, such as 4,5")
	return from, to
end


-- Apply(env, module, ns, notes) runs the RENDER_FX state in this module's environment, with the effect started
-- RENDER_FX_T seconds before the scene's clock (env._time); it appends what it did to notes.
function Effects.Apply(env, module, ns, notes)
	local state, t = Effects.State()
	local K = env.KstyleUI
	if not state or not K then
		return
	end
	local E = K.Effects
	local now = env._now
	env._now = env._time - (t or 0)
	if module == "actionbars" then
		if state == "ready" then
			local b = ns.actionButtons[4]
			b.realCooldown = true
			b:FlashReady()
			t = Sample(env, b.medReady.anim, t)
			notes[#notes + 1] = "fx: slot 4's ready flash " .. t .. " s after its cooldown ended"
		elseif state == "cap" then
			Fixtures(env)
			local _, class = env.UnitClass("player")
			if MANA[class] then
				env._powerType, env._powerToken = 0, "MANA"
			end
			env._power = 1
			ns.SlabEffects.UpdateCap()
			notes[#notes + 1] = "fx: the hub ring at a capped resource (power type " .. tostring(env._askedPower) .. "), its alpha the curve's answer"
		elseif state == "jewels" then
			-- RENDER_JEWELS=from,to: the crest jewels went from one count to the other RENDER_FX_T seconds ago;
			-- RENDER_JEWELS_BREATH is how far the ring's breath has run; RENDER_JEWELS_MOTION sets Medallions motion.
			local from, to = Jewels()
			local motion = os.getenv("RENDER_JEWELS_MOTION")
			if motion and motion ~= "" then
				K.Options.Write("Medallions", "motion", motion)
			end
			local points = tonumber(from)
			env.GetComboPoints = function() return points end
			env.UnitPower = function() return points end
			ns.SlabJewels.Update()
			points = tonumber(to)
			ns.SlabJewels.Update()
			local ring = ns.SlabJewels.state.ring
			if ring and ring.breath._playedAt then
				ring.breath._playedAt = env._time - (tonumber(os.getenv("RENDER_JEWELS_BREATH") or "") or 0)
			end
			notes[#notes + 1] = "fx: the crest jewels " .. from .. " to " .. to .. ", " .. (t or 0) .. " s in"
		elseif state == "hawks" then
			-- A hunter who knows Summon Hawk, RENDER_FX_T seconds into the HAWKS story (10 when unset): every totem
			-- update so far goes through the addon's own handler, and each perch's flare or fade is sampled from its last.
			local at = t or 10
			local totems, last = {}, {}
			env.C_SpellBook = env.C_SpellBook or {}
			env.C_SpellBook.IsSpellKnown = function(id) return id == 1293241 end
			env.GetTotemInfo = function(slot)
				local hawk = totems[slot]
				if not hawk then return false, "", 0, 0, 0, 1, 0 end
				return true, "Hawk", hawk.start, HAWK_LIFE, 132158, 1, hawk.spell
			end
			env.GetTotemDuration = function(slot)
				local hawk = totems[slot]
				return { start = hawk and hawk.start or 0, finish = hawk and hawk.start + HAWK_LIFE or 0 }
			end
			if os.getenv("RENDER_HAWK_PERCHES") == "off" then
				K.Options.Write("ActionBars", "crestHawks", false)
			end
			ns.SlabHawks.Update()
			for _, e in ipairs(HAWKS) do
				if e.at <= at then
					totems[e.slot] = e.summon and { start = env._time - (at - e.at), spell = e.slot == 2 and 1293248 or 1312637 } or nil
					env.FireEvent("PLAYER_TOTEM_UPDATE", e.slot)
					last[e.slot] = e.at
				end
			end
			for _, p in ipairs(ns.SlabHawks.state.perches) do
				for _, group in ipairs({ p.flare.fade, p.was.fade }) do
					if group._playedAt and last[p.slot] then
						group._playedAt = env._time - (at - last[p.slot])
					end
				end
			end
			notes[#notes + 1] = "fx: the hawk perches " .. at .. " s into the story"
		elseif state == "storm" then
			-- A shaman who knows Lightning Shield, RENDER_FX_T seconds into the STORM story (2.5 when unset): the aura
			-- slots take each charge count and the addon's own handler each cast, at its own time on the clock.
			-- RENDER_STORM=off turns the setting off and plays nothing, for a pixel diff against a build without it.
			local at = t or 2.5
			env.C_SpellBook = env.C_SpellBook or {}
			local known = env.C_SpellBook.IsSpellKnown
			env.C_SpellBook.IsSpellKnown = function(id) return id == 10432 or (known ~= nil and known(id)) end
			if os.getenv("RENDER_STORM") == "off" then
				K.Options.Write("ActionBars", "crestStorm", false)
				ns.SlabStorm.Update()
				env._now = now
				notes[#notes + 1] = "fx: Lightning Shield on the crest off"
				return
			end
			local Slots = dofile("Tools/regression/aura_slots.lua")
			Slots.Install(env)
			local aura
			env.C_UnitAuras = env.C_UnitAuras or {}
			env.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
				return aura and id == aura.id and { spellId = id, applications = aura.count } or nil
			end
			ns.SlabStorm.Update()
			local clock = env.GetTime
			env.GetTime = function() return env._now end
			for _, e in ipairs(STORM) do
				if e.at <= at then
					env._now = env._time - (at - e.at)
					aura = e.charges and (aura or { id = 10432 }) or nil
					if aura then
						aura.count = e.charges
					end
					Slots.Set(env, "player", aura and { aura } or nil)
					env.FireEvent("UNIT_AURA", "player", {})
					env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-storm", e.spell)
				end
			end
			env.GetTime = clock
			notes[#notes + 1] = "fx: the storm orbs " .. at .. " s into the story"
		elseif state == "levelup" then
			K.Options.Write("Medallions", "motion", "calm")
			env.FireEvent("PLAYER_LEVEL_UP", 12)
			local burst = ns.Slab.hub.burst
			t = Sample(env, burst.anim, t)
			notes[#notes + 1] = "fx: the hub's 2D level-up burst " .. t .. " s in (the 3D rays at Full are not drawn)"
		end
	elseif module == "unitframes" then
		if state == "jewels" then
			local _, to = Jewels()
			env._comboPoints = tonumber(to)
			env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
			notes[#notes + 1] = "fx: the player's combo pips at " .. to .. ", as the crest jewels"
		elseif state == "vignette" then
			Fixtures(env)
			env._health = 0.08
			for _, kind in ipairs({ "player", "target" }) do
				local uf = ns.Frames.Get(kind)
				if uf then ns.Slab.Health(uf.views[1], kind) end
			end
			E.Vignette.Update()
			if E.Vignette.frame then
				E.Vignette.frame.breath:Stop()
			end
			notes[#notes + 1] = "fx: the low-health vignette at 8% health"
		elseif state == "burst" then
			local m = E.playerMedallion
			K.Options.Write("Medallions", "motion", "calm")
			local _, class = env.UnitClass("player")
			if m and m:Burst(class) then
				t = Sample(env, m.burst.anim, t)
				notes[#notes + 1] = "fx: the class burst behind the player's medallion " .. t .. " s in"
			else
				notes[#notes + 1] = "fx: no player medallion to burst behind"
			end
		elseif state == "cast" or state == "stopped" then
			env.C_DurationUtil = env.C_DurationUtil or {}
			env.C_DurationUtil.CreateDuration = env.C_DurationUtil.CreateDuration or function()
				return { SetTimeSpan = function(duration, start, finish)
					duration.start, duration.finish = start, math.max(start, finish)
				end }
			end
			local player = env._units.player
			if not player.cast then
				player.cast = { name = "Lightning Bolt", texture = 136048, start = (env._time - 1) * 1000, finish = (env._time + 1) * 1000, spellID = 403 }
				env.FireEvent("UNIT_SPELLCAST_START", "player")
			end
			local cb
			for _, kind in ipairs({ "player", "target" }) do
				for _, list in ipairs({ ns.CastBars.Inline(kind) or {}, ns.CastBars.Get(kind) or {} }) do
					for _, each in ipairs(list) do
						if not cb and each.frame:IsShown() then
							cb = each
						end
					end
				end
			end
			if cb then
				local unit = cb.unit
				env._units[unit].cast, env._units[unit].channel = nil, nil
				if state == "cast" then
					env.FireEvent("UNIT_SPELLCAST_STOP", unit, "Cast-1", cb.spellID, cb.castBarID)
				else
					env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", unit, "Cast-1", cb.spellID, nil, cb.castBarID)
				end
				local streak = cb.medStreak
				t = Sample(env, cb.flash.group, t, streak and streak.anim)
				notes[#notes + 1] = "fx: the " .. cb.kind .. " cast bar's " .. state .. " flash " .. t .. " s in"
			else
				notes[#notes + 1] = "fx: no cast bar is showing"
			end
		elseif state == "rest" then
			env.SetCombat(true)
			env.SetCombat(false)
			env.RunTimers()
			for _ = 1, 40 do
				K.Layout.RefreshAlpha("unitframes.focus", 0)
			end
			for _, key in ipairs(K.Layout.Rest.KEYS) do
				K.Layout.RefreshAlpha(key, 0)
			end
			notes[#notes + 1] = "fx: the secondary frames resting after combat"
		end
	end
	env._now = now
end

return Effects
