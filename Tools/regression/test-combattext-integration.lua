-- test-combattext-integration.lua: CombatText finds the real KstyleUI_UnitFrames, KstyleUI_GroupFrames and KstyleUI_Nameplates frames, loaded with them as the game loads them.
local CT = dofile("Tools/regression/combattext_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local G = dofile("Tools/regression/group_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Hit, On = CT.Hit, CT.On

local function Saved(...)
	local section = {}
	for i = 1, select("#", ...) do
		section[(select(i, ...))] = { enabled = true }
	end
	return { version = 2, profiles = { Default = section }, characters = {} }
end

local function noErrors(env)
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Unit frames. CombatText loads and starts first, as KstyleUI_CombatText sorts before KstyleUI_UnitFrames.

do
	local env, K = U.New({
		saved = Saved("UnitFrames", "CombatText"),
		setup = CT.Fakes,
		before = function(e)
			Load(CT.Files(), e)
		end,
	})
	local ns, uf = env._addons.KstyleUI_CombatText, env._addons.KstyleUI_UnitFrames
	assert(K.Modules.IsRunning("UnitFrames") and K.Modules.IsRunning("CombatText"), "both modules start at login")
	assert(K.Modules.List()[1] ~= "UnitFrames", "CombatText registers before UnitFrames, as in the game")

	U.SetUnit(env, "target", { name = "Wolf", level = 12, health = 50, healthMax = 200, reaction = 2 })
	env.SetTarget(true)
	local target = uf.Frames.Get("target").views[1].button
	Hit(env, "target", "WOUND", "", env.Secret(120), 1)
	assert(#On(ns, target) == 1, "numbers show on the real target frame")

	local player = uf.Frames.Get("player").views[1].button
	Hit(env, "player", "HEAL", "", env.Secret(60), 2)
	assert(#On(ns, ns.Module.field) == 1 and #On(ns, player) == 0, "your numbers use the field by default")
	K.Options.Write("CombatText", "playerPlacement", "frame")
	Hit(env, "player", "HEAL", "", env.Secret(60), 2)
	assert(#On(ns, player) == 1, "your numbers can use the real player frame")

	U.SetUnit(env, "boss2", { name = "Magmatus", level = -1, health = 72, healthMax = 100, reaction = 2 })
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	local boss2 = uf.Frames.Get("boss").views[2].button
	Hit(env, "boss2", "WOUND", "CRITICAL", env.Secret(900), 4)
	assert(#On(ns, boss2) == 1, "numbers show on the real boss2 frame")

	K.Modules.Disable("UnitFrames")
	env.RunTimers()
	Hit(env, "target", "WOUND", "", env.Secret(120), 1)
	assert(#On(ns, target) == 1, "numbers stop when UnitFrames stops")
	noErrors(env)
end

-- Group frames: the real secure headers, as the roster fills and changes.

do
	local env, K = G.New({ boot = false, saved = Saved("GroupFrames", "CombatText"), setup = CT.Fakes })
	Load(CT.Files(), env)
	G.CoreEnv.Boot(env)
	env.RunTimers()
	local ns, gf = env._addons.KstyleUI_CombatText, env._addons.KstyleUI_GroupFrames
	assert(K.Modules.IsRunning("GroupFrames") and K.Modules.IsRunning("CombatText"), "both modules start at login")

	local function button(unit)
		local header = gf.Headers.party
		local i = 1
		while header._attributes["child" .. i] do
			local child = header._attributes["child" .. i]
			if child._shown and child._attributes.unit == unit then
				return child
			end
			i = i + 1
		end
	end

	G.SetRoster(env, "party", G.Members(3))
	env.RunTimers()
	local second = assert(button("party2"), "the party header shows party2")
	Hit(env, "party2", "WOUND", "", env.Secret(55), 1)
	assert(#On(ns, second) == 1, "numbers show on the real party2 frame")

	G.SetRoster(env, "party", G.Members(4))
	env.RunTimers()
	local fourth = assert(button("party4"), "the party header shows party4 after the roster grows")
	Hit(env, "party4", "HEAL", "", env.Secret(55), 2)
	assert(#On(ns, fourth) == 1, "a member who joins gets numbers after GROUP_ROSTER_UPDATE")
	noErrors(env)
end

-- Nameplates: the base plate of a unit KstyleUI's Nameplates module dresses.

do
	local env, K = N.New({ login = false, saved = Saved("Nameplates", "CombatText"), setup = CT.Fakes })
	Load(CT.Files(), env)
	N.CoreEnv.Login(env)
	env.RunTimers()
	local ns = env._addons.KstyleUI_CombatText
	assert(K.Modules.IsRunning("Nameplates") and K.Modules.IsRunning("CombatText"), "both modules start at login")
	K.Options.Write("CombatText", "units.nameplate", true)
	local base = N.Add(env, "nameplate4", { name = "Kobold" })
	Hit(env, "nameplate4", "WOUND", "", env.Secret(33), 1)
	assert(#On(ns, base) == 1, "numbers show on the real nameplate")
	N.Remove(env, "nameplate4")
	assert(#On(ns, base) == 0, "a removed plate's numbers go")
	noErrors(env)
end

print("combat text integration ok")
