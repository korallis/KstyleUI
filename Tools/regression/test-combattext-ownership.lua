-- test-combattext-ownership.lua: default combat text ownership, explicit Keep, queued CVar restoration and the world role before login.
local CT = dofile("Tools/regression/combattext_env.lua")

do
	local env, K, ns = CT.New({ saved = CT.Saved({ enabled = true }), login = false })
	assert(env.DAMAGE_TEXT_FONT == (K.Tokens.Font("world")), "the world combat role is assigned in the main chunk before PLAYER_LOGIN")
	assert(not K.Modules.IsRunning("CombatText") and #env._cvarWrites == 0, "early font assignment starts no scrolling text or CVar writes")
	CT.CoreEnv.Login(env)
	env.RunTimers()
	assert(K.Modules.IsRunning("CombatText"), "the saved switch starts scrolling text at login")
	for _, name in ipairs({ CT.SELF, CT.TARGETS[1], CT.TARGETS[2] }) do
		assert(env._cvars[name] == "0", "the default hides Blizzard's duplicate numbers: " .. name)
	end
	CT.Hit(env, "player", "WOUND", "", 123, 1)
	assert(#CT.Shown(ns) == 1, "our scrolling number still displays with Blizzard's numbers hidden")
	env.SetCombat(true)
	local writes = #env._cvarWrites
	K.Modules.Disable("CombatText")
	env.RunTimers()
	assert(#env._cvarWrites == writes, "disabling in combat never writes a CVar")
	env.SetCombat(false)
	env.RunTimers()
	for _, name in ipairs({ CT.SELF, CT.TARGETS[1], CT.TARGETS[2] }) do
		assert(env._cvars[name] == "1", "disable restores the player's value after combat: " .. name)
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CT.New({ saved = CT.Saved({ enabled = true, blizzardSelf = "keep", blizzardTargets = "keep" }) })
	assert(K.Modules.IsRunning("CombatText"), "the module runs with explicit Keep")
	assert(#env._cvarWrites == 0, "explicit Keep survives the changed default without CVar writes")
	for _, name in ipairs(CT.TARGETS) do
		assert(env._cvars[name] == "1", "explicit Keep preserves the player's world numbers")
	end
	CT.CoreEnv.Logout(env)
	assert(env.KstyleUIDB.profiles.Default.CombatText.blizzardTargets == "keep", "explicit Keep is saved against the new Hide default")
	local again, K2 = CT.New({ saved = env.KstyleUIDB })
	assert(K2.Modules.IsRunning("CombatText") and #again._cvarWrites == 0, "explicit Keep still wins after a full relog")
end

do
	local env, K = CT.New({ saved = CT.Saved({ enabled = true }), login = false })
	K.Store.Defaults("CombatText").blizzardTargets = "keep"
	K.Store.Module("CombatText").blizzardTargets = "keep"
	CT.CoreEnv.Logout(env)
	assert(env.KstyleUIDB.profiles.Default.CombatText.blizzardTargets == nil, "Store strips the materialized v0.2.1 Keep default at logout")
	local again, K2 = CT.New({ saved = env.KstyleUIDB })
	assert(K2.Options.Read("CombatText", "blizzardTargets") == "hide", "the normally saved v0.2.1 profile inherits the new Hide default")
	assert(again._cvars[CT.TARGETS[1]] == "0" and again._cvars[CT.TARGETS[2]] == "0", "the upgraded profile hides native world damage and healing")
end

do
	local env, K = CT.New({ saved = CT.Saved({ enabled = true }), login = false })
	env.SetCombat(true)
	CT.CoreEnv.Login(env)
	env.RunTimers()
	assert(K.Modules.IsRunning("CombatText") and #env._cvarWrites == 0, "login in combat defers the initial hide")
	env.SetCombat(false)
	env.RunTimers()
	assert(env._cvars[CT.TARGETS[1]] == "0" and env._cvars[CT.TARGETS[2]] == "0", "world damage and healing hide after combat")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local saved = CT.Saved({ enabled = true })
	saved.profiles.Default.Appearance = { roleFontWorld = "SourceSans3Regular", roleFontNumber = "PTSerifBold" }
	local env, K = CT.New({ saved = saved, login = false })
	assert(K.Tokens.Font("world") == K.Tokens.FontPath("SourceSans3Regular"), "the saved world role is loaded before this addon")
	assert(K.Tokens.Font("world") ~= K.Tokens.Font("number"), "the fixture distinguishes world and interface numbers")
	assert(env.DAMAGE_TEXT_FONT == (K.Tokens.Font("world")), "the saved world role wins before PLAYER_LOGIN")
end

print("combat text ownership ok")
