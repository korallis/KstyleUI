-- test-cooldowns-notice.lua: the Cooldown Manager tip is conditional and survives reloads, profiles and characters as account data.
local C = dofile("Tools/regression/cooldowns_env.lua")
local function Notices(env)
	local count = 0
	for _, line in ipairs(env._printed) do
		if line:find("Turn on the Cooldown Manager", 1, true) then count = count + 1 end
	end
	return count
end

local on = false
local function Setup(env)
	C.Viewers(env)
	env.C_CVar = { GetCVarBool = function() return on end }
end
local env, K = C.New({ setup = Setup })
assert(Notices(env) == 0, "the Cooldown Manager tip must stay silent while Cooldowns is off")
on = true
C.Enable(env, K)
assert(Notices(env) == 0, "the Cooldown Manager tip must stay silent while its CVar is on")
K.Modules.Disable("Cooldowns")
on = false
C.Enable(env, K)
assert(Notices(env) == 1, "the Cooldown Manager tip must show once when Cooldowns is on and its CVar is off")
K.Modules.Disable("Cooldowns")
C.Enable(env, K)
assert(Notices(env) == 1, "the Cooldown Manager tip must not repeat when Cooldowns restarts")
C.CoreEnv.Logout(env)
local again, K2 = C.New({ saved = env.KstyleUIDB, setup = function(e)
	Setup(e)
	e.UnitName = function() return "AnotherCharacter" end
end })
C.Enable(again, K2)
assert(Notices(again) == 0, "save the Cooldown Manager tip in account data so another login or character never repeats it")
K2.Store.CreateProfile("AnotherProfile")
K2.Store.SetProfile("AnotherProfile")
C.Enable(again, K2)
assert(Notices(again) == 0, "the Cooldown Manager tip must remain seen after switching profiles")
assert(#env._errors == 0 and #again._errors == 0, "conditional account notices must raise no errors")
print("cooldowns account notice ok")
