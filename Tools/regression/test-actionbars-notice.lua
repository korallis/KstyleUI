-- test-actionbars-notice.lua: the bindings notice remembers each overlapping addon across logins and respects Other-addon notices.
local AB = dofile("Tools/regression/actionbars_env.lua")
local function Notices(env)
	local count = 0
	for _, text in ipairs(env._printed) do
		if text:find("action bar bindings are off", 1, true) then count = count + 1 end
	end
	return count
end
local loaded = { Bartender4 = true }
local function Setup(env)
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end
end
local env, K = AB.New({ setup = Setup })
K.Options.Write("Integrations", "notices", false)
AB.Enable(env, K)
assert(Notices(env) == 0, "Other-addon notices off must neither print nor consume a bindings notice")
K.Options.Write("Integrations", "notices", true)
env.FireEvent("UPDATE_BINDINGS")
env.RunTimers()
assert(Notices(env) == 1, "Other-addon notices on must permit the first bindings notice")
AB.CoreEnv.Logout(env)
local again, K2 = AB.New({ saved = env.KstyleUIDB, setup = Setup })
env = nil
again.RunTimers()
assert(Notices(again) == 0, "save bindings notices per account and addon so the next login does not repeat them")
loaded.Dominos = true
again.FireEvent("UPDATE_BINDINGS")
again.RunTimers()
assert(Notices(again) == 1, "a newly detected overlapping addon must get one bindings notice")
assert(again._printed[#again._printed]:find("Dominos", 1, true), "the new bindings notice must name the newly detected addon")
loaded.Bartender4 = nil
again.FireEvent("UPDATE_BINDINGS")
again.RunTimers()
assert(Notices(again) == 1, "removing an overlapping addon must not repeat a bindings notice")
K2.Options.Write("Integrations", "notices", false)
loaded.ElvUI = true
again.FireEvent("UPDATE_BINDINGS")
again.RunTimers()
assert(Notices(again) == 1, "Other-addon notices off must still suppress newly detected addons")
K2.Options.Write("Integrations", "notices", true)
again.FireEvent("UPDATE_BINDINGS")
again.RunTimers()
assert(Notices(again) == 2, "turning notices back on must permit the unseen addon's notice")
again.FireEvent("UPDATE_BINDINGS")
again.RunTimers()
assert(Notices(again) == 2 and #again._errors == 0, "bindings notices must print once per detected addon without errors")
print("actionbars account notices ok")
