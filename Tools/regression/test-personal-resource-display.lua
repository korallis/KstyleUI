-- test-personal-resource-display.lua: enabling, setup and the option control Blizzard's personal resource display, while later Blizzard choices survive automatic refreshes.
local N = dofile("Tools/regression/nameplates_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

local function Writes(env)
	local n = 0
	for _, write in ipairs(env._cvarWrites) do
		if write.name == "nameplateShowSelf" then n = n + 1 end
	end
	return n
end

local env, K, ns = N.New({ enable = false })
assert(ns.Settings.defaults.personalResource == false, "Personal resource display must default off")
assert(ns.Settings.Row("personalResource").label == "Personal resource display")
assert(env._cvars.nameplateShowSelf == "1" and Writes(env) == 0, "loading the disabled module leaves Blizzard's choice alone")
K.Setup.Open(true)
K.Setup.Keep()
K.Setup.Closed(false)
assert(env._cvars.nameplateShowSelf == "1" and Writes(env) == 0, "Keep my UI leaves the personal resource display alone")
assert(K.Setup.Apply({ layout = "DPS", modules = { Nameplates = true } }))
assert(env._cvars.nameplateShowSelf == "0" and Writes(env) > 0, "setup Apply enables the module and turns the personal resource display off")
assert(ns.Settings.Get("personalResource") == false, "setup and the option agree")
K.Options.Write("Nameplates", "personalResource", true)
assert(env._cvars.nameplateShowSelf == "1", "the Nameplates option turns the display back on")
env.SetCombat(true)
K.Options.Write("Nameplates", "personalResource", false)
assert(env._cvars.nameplateShowSelf == "1", "an option change in combat waits")
env.SetCombat(false)
assert(env._cvars.nameplateShowSelf == "0", "the requested change applies out of combat")
env.C_CVar.SetCVar("nameplateShowSelf", "1")
local written = Writes(env)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" }) do env.FireEvent(event, "nameplateShowSelf") end
K.Callbacks.Fire("ProfileChanged")
K.Callbacks.Fire("ThemeChanged")
K.Options.Write("Nameplates", "name.size", 12)
K.Options.Write("Nameplates", "preset", "lumen")
env.RunTimers()
assert(env._cvars.nameplateShowSelf == "1" and Writes(env) == written, "automatic work must preserve a later Blizzard choice")
K.Modules.Disable("Nameplates")
K.Modules.Enable("Nameplates")
assert(env._cvars.nameplateShowSelf == "0", "enabling reapplies the saved personal-resource choice")
K.Modules.Disable("Nameplates")
K.Options.Write("Nameplates", "personalResource", false)
assert(env._cvars.nameplateShowSelf == "0", "the explicit option works with the skin disabled too")
env.C_CVar.SetCVar("nameplateShowSelf", "1")
K.Options.Write("Nameplates", "personalResource", true)
env.SetCombat(true)
assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
assert(ns.Settings.Get("personalResource") == false, "setup resets a previously enabled option too")
assert(env._cvars.nameplateShowSelf == "1", "setup never writes a protected CVar in combat")
env.SetCombat(false)
assert(env._cvars.nameplateShowSelf == "0", "setup's display change completes after combat even with the module off")
assert(#env._errors == 0, tostring(env._errors[1]))

local druid, DK, uf = U.New({ setup = function(e)
	e._units.player.class, e._units.player.race, e._units.player.level = "DRUID", "Tauren", 5
	e._units.player.powerType, e._units.player.powerToken = 0, "MANA"
end })
assert(not uf.Resource.state.showMana and not uf.Resource.state.showCombo and not uf.Resource.state.content:IsShown(), "a level 5 caster druid has no KstyleUI class-resource bars")
assert(#druid._errors == 0 and DK.ErrorCount() == 0)
print("personal resource display: setup, option, combat, Keep, external changes and caster druid passed")
