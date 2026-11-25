-- _rings.lua: RENDER_RINGS puts the crest's ring-edge timers (KstyleUI_ActionBars/SlabRings.lua) in a state with RENDER_RINGS_LEFT of the timer left (0.5 when unset): ember re-times every aura the scene gave (use it with RENDER_TRACKERS=lit), cast and channel run a 2.5 s cast or a 5 s channel, landed and stopped end a cast RENDER_RINGS_T seconds ago (0.05 when unset), swing a 1.8 s main-hand swing, gcd a 1.5 s global cooldown with the spark switched on.
local Slots = dofile("Tools/regression/aura_slots.lua")

local Rings = {}

local CAST, CHANNEL, SWING, GCD = 2.5, 5, 1.8, 1.5

function Rings.Story()
	local story = os.getenv("RENDER_RINGS")
	return story ~= nil and story ~= "" and story or nil
end

local function Ago(group, env, t)
	if group and group._playedAt then group._playedAt = env._time - t end
end

function Rings.Play(env, K, ns, notes)
	local story = Rings.Story()
	local left = tonumber(os.getenv("RENDER_RINGS_LEFT") or "") or 0.5
	local t = tonumber(os.getenv("RENDER_RINGS_T") or "") or 0.05
	local clock, time = env._now, env.GetTime
	env._now = env._time
	env.GetTime = function() return env._now end
	if story == "ember" then
		for unit, auras in pairs(env._slotAuras or {}) do
			for _, a in ipairs(auras) do
				if a.duration then a.start = env._time - a.duration * (1 - left) end
			end
			Slots.Set(env, unit, auras)
		end
	elseif story == "cast" or story == "landed" or story == "stopped" then
		local start = env._time - CAST * (1 - left)
		env.UnitCastingInfo = function() return "Shadow Bolt", "", 136197, start * 1000, (start + CAST) * 1000 end
		env.FireEvent("UNIT_SPELLCAST_START", "player")
		if story ~= "cast" then
			env._now = env._time - t
			env.FireEvent(story == "landed" and "UNIT_SPELLCAST_SUCCEEDED" or "UNIT_SPELLCAST_INTERRUPTED", "player")
			local p = ns.SlabRings.state.piece
			Ago(p.flash.play, env, t)
			Ago(p.stop, env, t)
			Ago(ns.Slab.hub.crest.pulse, env, t)
			Ago(ns.Slab.hub.glyphs.flash, env, t)
		end
	elseif story == "channel" then
		local start = env._time - CHANNEL * (1 - left)
		env.UnitChannelInfo = function() return "Drain Life", "", 136169, start * 1000, (start + CHANNEL) * 1000 end
		env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	elseif story == "swing" then
		env._now = env._time - SWING * (1 - left)
		env.FireEvent("PLAYER_SWING", SWING, 0)
	elseif story == "gcd" then
		K.Options.Write("ActionBars", "crestGcdSpark", true)
		local start = env._time - GCD * (1 - left)
		env.C_Spell.GetSpellCooldown = function() return { isActive = true, isOnGCD = true } end
		env.C_Spell.GetSpellCooldownDuration = function() return { start = start, finish = start + GCD } end
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
	end
	env._now, env.GetTime = clock, time
	notes[#notes + 1] = string.format("rings: %s, %.2f left", story, left)
end

return Rings
