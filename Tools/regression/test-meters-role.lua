-- test-meters-role.lua: role choices override manual switches, settle after combat and restore manual behaviour when off.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New({ followRole = true, setup = function(e)
	e._role = "TANK"
	e.UnitGroupRolesAssigned = function() return e._role end
	e._group.size = 5
end })
local function Fit(damage, threat)
	local enabled = K.Setup.Layouts.Enabled("DPS", K.Store.Profile())
	assert(enabled["meters.damage"] == damage and enabled["meters.threat"] == threat, "automatic sizing must reserve exactly the role/manual meter choice")
end
local settings = K.Store.Module("Meters")
assert(settings.followRole == true, "role meters default on")
settings.threat.shown = false
M.Enable(env, K)
assert(ns.Threat.holder:IsShown() and ns.Threat.list.panel:IsShown(), "tanks see threat even when the manual switch is off")
Fit(false, true)
assert(not ns.Damage.holder:IsShown() and not K.Layout.Live("meters.damage"), "tanks hide damage and its mover")
assert(not env.DamageMeter:IsVisible(), "tanks also hide Blizzard's damage window")
local fitCalls = 0
local limit = K.Setup.Layouts.ScaleLimit
K.Setup.Layouts.ScaleLimit = function(...)
	fitCalls = fitCalls + 1
	return limit(...)
end
local previewParent = env.CreateFrame("Frame", nil, K.Scale.Root())
previewParent:SetSize(600, 400)
local preview = ns.Preview.Build(previewParent)
assert(preview.threat.holder:IsShown() and not preview.damage.holder:IsShown(), "the Options preview follows the tank's role")
env.SetCombat(true)
env._role = "DAMAGER"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
env.FireEvent("GROUP_ROSTER_UPDATE")
assert(ns.Threat.holder:IsShown() and not ns.Damage.holder:IsShown(), "combat retains the tank meter")
Fit(false, true)
env.SetCombat(false)
env.RunTimers()
assert(ns.Damage.holder:IsShown() and not ns.Threat.holder:IsShown(), "combat end shows damage for DPS")
Fit(true, false)
assert(fitCalls > 0, "a settled role change must recalculate the HUD fit without a profile switch")
M.Write(env, K, "roles.DAMAGER", "both")
assert(ns.Damage.holder:IsShown() and ns.Threat.holder:IsShown(), "each role can show both")
Fit(true, true)
M.Write(env, K, "roles.DAMAGER", "threat")
assert(not ns.Damage.holder:IsShown() and ns.Threat.holder:IsShown(), "DPS can choose threat")
Fit(false, true)
env._role = "HEALER"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(ns.Damage.holder:IsShown() and not ns.Threat.holder:IsShown(), "healers default to damage")
Fit(true, false)
M.Write(env, K, "followRole", false)
assert(ns.Damage.holder:IsShown() and not ns.Threat.holder:IsShown(), "off restores saved manual switches")
Fit(true, false)
M.Write(env, K, "threat.shown", true)
assert(ns.Damage.holder:IsShown() and ns.Threat.holder:IsShown(), "off permits both manual meters")
Fit(true, true)
assert(settings.threat.shown == true and settings.damage.shown == true, "role changes do not overwrite manual choices")
assert(K.ErrorCount() == 0)
print("role meters ok")
