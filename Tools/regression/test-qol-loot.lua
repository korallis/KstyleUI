-- test-qol-loot.lua: faster auto loot takes every unlocked slot at once when the game auto loots, and never when it does not.
local Q = dofile("Tools/regression/qol_env.lua")

local function Looted(env)
	local out = {}
	for _, call in ipairs(Q.Calls(env, "LootSlot")) do
		out[#out + 1] = call[1]
	end
	return table.concat(out, ",")
end

local function Ready(env, autoloot, ...)
	env.SetTime(env.GetTime() + 1)
	env.FireEvent("LOOT_READY", autoloot, ...)
	env.RunTimers()
end

-- Off while the module is off.
do
	local env = Q.New()
	env._loot = { {}, {}, {} }
	Ready(env, true)
	assert(Looted(env) == "", "nothing loots while the module is off")
end

-- With the game auto looting, every slot is taken at once, last first, and a locked slot is left alone.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._loot = { {}, { locked = true }, {}, {} }
	Ready(env, true)
	assert(Looted(env) == "4,3,1", "every unlocked slot loots, last first, got " .. Looted(env))
end

-- The game says no auto loot (the setting is off, or the modifier key flipped it): the window stays for the player.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._loot = { {}, {} }
	Ready(env, false)
	assert(Looted(env) == "", "manual loot is left to the player")
end

-- No payload: the game's auto-loot setting and the auto-loot key decide, as Blizzard's own buttons read them.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._loot = { {} }
	env._cvars.autoLootDefault = "1"
	Ready(env, nil)
	assert(Looted(env) == "1", "auto loot on and no key held loots")
	Q.Reset(env)
	env._modified.AUTOLOOTTOGGLE = true
	Ready(env, nil)
	assert(Looted(env) == "", "the auto-loot key held flips it off")
	Q.Reset(env)
	env._cvars.autoLootDefault = "0"
	Ready(env, nil)
	assert(Looted(env) == "1", "auto loot off with the key held loots")
	Q.Reset(env)
	env._modified.AUTOLOOTTOGGLE = false
	Ready(env, nil)
	assert(Looted(env) == "", "auto loot off and no key held leaves the window")
end

-- A secret payload is never tested; the setting and key decide instead.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._loot = { {} }
	env._cvars.autoLootDefault = "0"
	Ready(env, env.Secret(true))
	assert(Looted(env) == "", "a secret payload falls back to the setting")
	assert(K.ErrorCount() == 0, "and raises nothing")
end

-- LOOT_READY can fire twice for one corpse; the second, at the same moment, does not loot again.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	env._loot = { {}, {} }
	Ready(env, true)
	env.FireEvent("LOOT_READY", true)
	assert(Looted(env) == "2,1", "one pass per loot window, got " .. Looted(env))
	Ready(env, true)
	assert(Looted(env) == "2,1,2,1", "a later window loots again, got " .. Looted(env))
end

-- The setting turns it off.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	Q.Write(env, K, "fastLoot", false)
	env._loot = { {} }
	Ready(env, true)
	assert(Looted(env) == "", "faster loot off leaves looting to the game")
end

print("qol loot ok")
