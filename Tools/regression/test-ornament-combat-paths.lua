-- test-ornament-combat-paths.lua: at Full, a burst of the unit frames' per-event combat updates (health, power, prediction, auras, threat, cast progress and every running OnUpdate) restyles no ornament and places no piece.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "target", { name = "Wolf", level = 12, health = 50, healthMax = 200, power = 10, powerMax = 100, powerType = 1, powerToken = "RAGE", reaction = 2, canAttack = true, classification = "elite" })
env.SetTarget(true)
local CAST = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env._units.player.cast, env._units.target.cast = CAST, CAST
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-2", 116)
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
env.SetCombat(true)
env.RunTimers()

local view = ns.Frames.Get("target").views[1]
local Handle = getmetatable(view.health.ornament)
assert(view.portraitOrnament.used > 0, "the target draws its portrait band before the burst")
local counts = { Restyle = 0, Place = 0, Piece = 0, Follow = 0 }
for name in pairs(counts) do
	local original = Handle[name]
	Handle[name] = function(...)
		counts[name] = counts[name] + 1
		return original(...)
	end
end

local units = { "player", "target" }
local updates = {}
for _, frame in ipairs(env._frames) do
	local script = frame._scripts and frame._scripts.OnUpdate
	if script then updates[#updates + 1] = { frame, script } end
end
for i = 1, 40 do
	for _, unit in ipairs(units) do
		local u = env._units[unit]
		u.health = 20 + (i * 7) % 150
		u.power = (i * 3) % 100
		u.threatOn = i % 4
		for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_SPELLCAST_DELAYED" }) do
			env.FireEvent(event, unit)
		end
	end
	for _, entry in ipairs(updates) do
		local frame, script = entry[1], entry[2]
		if frame._scripts.OnUpdate == script then script(frame, 0.05) end
	end
	env.RunTimers()
end
assert(#updates > 0, "the burst drives the running OnUpdate scripts")
assert(counts.Restyle == 0 and counts.Place == 0 and counts.Piece == 0 and counts.Follow == 0, string.format("per-event combat updates touch no ornament: %d restyles, %d placements, %d anchored pieces, %d follows", counts.Restyle, counts.Place, counts.Piece, counts.Follow))
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok per-event combat updates touch no ornament")
