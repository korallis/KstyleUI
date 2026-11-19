-- test-nameplates-text-cost.lua: default plate events keep base 59d4c5a5's widget cost and zero work for unused tag fields.
local N = dofile("Tools/regression/nameplates_env.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local env, K = N.New()
for i = 1, 40 do N.Add(env, "nameplate" .. i) end

for _, event in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_TARGET" }) do
	local cost = Budget.Count(env, function()
		for _ = 1, 100 do env.FireEvent(event, "nameplate1") end
	end)
	Budget.Check(cost, 0, 0, "unused " .. event .. ": register tag events only for formats that need them, filtered by unit")
end

for event, calls in pairs({ UNIT_HEALTH = 1618, UNIT_NAME_UPDATE = 300 }) do
	local cost = Budget.Count(env, function()
		for _ = 1, 100 do env.FireEvent(event, "nameplate1") end
	end)
	assert(cost.calls <= calls, event .. ": default text must not add widget calls above base 59d4c5a5")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, "event cost must measure successful paths")
print("nameplate text cost ok: zero instructions/calls for unused tag events; health/name widget calls at base 59d4c5a5")
