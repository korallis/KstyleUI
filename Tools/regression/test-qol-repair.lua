-- test-qol-repair.lua: auto repair at a repair merchant pays from guild funds first when asked, then from the player's money, and prints the cost.
local Q = dofile("Tools/regression/qol_env.lua")
local CoreEnv = Q.CoreEnv

local function Repairs(env)
	local out = {}
	for _, call in ipairs(Q.Calls(env, "RepairAllItems")) do
		out[#out + 1] = call[1] == true and "guild" or "own"
	end
	return table.concat(out, ",")
end

local function Visit(env)
	env.FireEvent("MERCHANT_SHOW")
	env.RunTimers()
end

local function New(repair)
	local env, K = Q.New()
	for key, value in pairs(repair or {}) do
		env._repair[key] = value
	end
	Q.Enable(env, K)
	return env, K
end

-- The player pays, and the chat line names the cost.
do
	local env = New({ cost = 1234, money = 5000 })
	Visit(env)
	assert(Repairs(env) == "own", "repairs with the player's money, got " .. Repairs(env))
	assert(CoreEnv.Printed(env, "<1234c>"), "prints the cost")
end

-- Nothing to repair, or a merchant who cannot repair: no call and no chat line.
do
	local env = New({ cost = 0, money = 5000 })
	Visit(env)
	assert(Repairs(env) == "", "nothing broken, nothing repaired")
	env._repair.cost, env._repair.can = 500, false
	Visit(env)
	assert(Repairs(env) == "", "a merchant who cannot repair is left alone")
	assert(#env._printed == 0, "and nothing prints")
end

-- Not enough money: no repair, and the chat line says why.
do
	local env = New({ cost = 9000, money = 100 })
	Visit(env)
	assert(Repairs(env) == "", "never repairs on money the player lacks")
	assert(CoreEnv.Printed(env, "<9000c>"), "says what the repair would cost")
end

-- Guild funds: only when the setting asks, the rank allows it and the guild can cover the whole bill.
do
	local env = New({ cost = 2000, money = 5000, inGuild = true, guild = true, withdraw = 10000, bank = 50000 })
	Visit(env)
	assert(Repairs(env) == "own", "guild funds wait for the setting, got " .. Repairs(env))
end

do
	local env, K = New({ cost = 2000, money = 5000, inGuild = true, guild = true, withdraw = 10000, bank = 50000 })
	Q.Write(env, K, "guildRepair", true)
	Visit(env)
	assert(Repairs(env) == "guild", "the guild pays first, got " .. Repairs(env))
	assert(CoreEnv.Printed(env, "<2000c>"), "prints the cost")

	Q.Reset(env)
	env._repair.withdraw = 1000
	Visit(env)
	assert(Repairs(env) == "own", "a withdraw limit below the bill falls back to the player, got " .. Repairs(env))

	Q.Reset(env)
	env._repair.withdraw, env._repair.bank = -1, 1500
	Visit(env)
	assert(Repairs(env) == "own", "an unlimited rank still needs the guild bank to cover it, got " .. Repairs(env))

	Q.Reset(env)
	env._repair.bank = 3000
	Visit(env)
	assert(Repairs(env) == "guild", "an unlimited rank with enough in the bank pays, got " .. Repairs(env))

	Q.Reset(env)
	env._repair.guild = false
	Visit(env)
	assert(Repairs(env) == "own", "a rank without repair rights pays from the player, got " .. Repairs(env))
end

-- Secret amounts are never compared.
do
	local env, K = New({ money = 5000 })
	env.GetRepairAllCost = function()
		return env.Secret(1000), env.Secret(true)
	end
	Visit(env)
	assert(Repairs(env) == "", "a secret cost repairs nothing")
	assert(K.ErrorCount() == 0, "and raises nothing")
end

-- The setting turns it off.
do
	local env, K = New({ cost = 100, money = 5000 })
	Q.Write(env, K, "autoRepair", false)
	Visit(env)
	assert(Repairs(env) == "", "auto repair off repairs nothing")
end

print("qol repair ok")
