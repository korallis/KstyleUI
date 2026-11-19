-- test-compat-same-job.lua: overlapping bars keep their keys and menus, Details owns damage, and a player's explicit action-bar choice survives reload.
local AB = dofile("Tools/regression/actionbars_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/meters_env.lua")

local function Loaded(addon)
	return function(env)
		env.C_AddOns = env.C_AddOns or {}
		env.C_AddOns.IsAddOnLoaded = function(name) return name == addon end
	end
end

local function NoticeCount(env)
	local count = 0
	for _, text in ipairs(env._printed or {}) do
		if text:find("action bar bindings", 1, true) then count = count + 1 end
	end
	return count
end

for _, screen in ipairs({ {1920, 1080}, {2560, 1440}, {5120, 1440}, {3840, 2160} }) do
	for _, addon in ipairs({ "Bartender4", "Dominos" }) do
		local env, K, ns = AB.New({ width = screen[1], height = screen[2], setup = function(e)
			Loaded(addon)(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end })
		AB.Enable(env, K)
		assert(next(env._game.overrides) == nil, "ActionBars must leave override bindings off beside " .. addon .. " until the player enables it themselves")
		env.FireEvent("UPDATE_BINDINGS")
		assert(NoticeCount(env) == 1, "post one action bar bindings notice, even after UPDATE_BINDINGS")
		K.Options.Write("ActionBars", "enabled", false)
		K.Options.Write("ActionBars", "enabled", true)
		env.RunTimers()
		assert(AB.PressKey(env, "1"), "the player's explicit action-bar choice permits bindings")
		local reloaded, reloadK = AB.New({ saved = env.KstyleUIDB, setup = function(e)
			Loaded(addon)(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end })
		assert(AB.PressKey(reloaded, "1"), "the player's explicit choice survives reload")
		reloadK.Modules.Disable("ActionBars")
		assert(next(reloaded._game.overrides) == nil, "Disable still clears the bindings")
		assert(#env._blocked == 0 and #env._errors == 0 and #reloaded._errors == 0, "overlap binding changes raise no errors")

		local dEnv, dK, d = D.New({ width = screen[1], height = screen[2], setup = function(e)
			Loaded(addon)(e)
			D.Menus(e)
		end })
		dEnv.RunTimers()
		for _, id in ipairs({ "micro", "bags" }) do
			assert(d.Menus.Content(id) == nil, "DataBars must not build " .. id .. " beside " .. addon)
			assert(not dK.Safe.IsHidden(dEnv[d.Menus.GROUPS[id].hide]), "leave the other addon's menu container alone")
		end
		assert(dK.Modules.IsRunning("DataBars") and d.Bars.views.xp, "XP and the rest of DataBars keep running")
		dK.Options.Write("DataBars", "micro.enabled", true)
		dEnv.FireEvent("PLAYER_ENTERING_WORLD")
		dEnv.RunTimers()
		assert(d.Menus.Content("micro") == nil and #dEnv._errors == 0, "settings and world events cannot reclaim the menus")
	end
	for _, mode in ipairs({ "window", "skin" }) do
		local env, K, ns = M.New({ width = screen[1], height = screen[2], setup = Loaded("Details") })
		K.Options.Write("Meters", "damage.mode", mode)
		M.Enable(env, K)
		assert(not ns.Damage.holder:IsShown() and not ns.DamageSkin.active, "Details keeps the damage window in " .. mode .. " mode")
		assert(not K.Safe.IsHidden(env.DamageMeter) and not K.Layout.Live("meters.damage"), "do not take Blizzard's meter or leave a damage mover")
		K.Options.Write("Meters", "followRole", true)
		K.Options.Write("Meters", "roles.DAMAGER", "both")
		assert(not ns.Damage.holder:IsShown() and not K.Safe.IsHidden(env.DamageMeter), "role-following cannot reclaim damage beside Details")
		assert(ns.Threat.holder:IsShown() and K.Layout.Live("meters.threat"), "Details leaves threat active")
		K.Options.Write("Meters", "swing.attached", false)
		env.FireEvent("PLAYER_SWING", 2, M.SWING.MainHand)
		assert(ns.Swing.content:IsShown(), "Details leaves the swing timer active")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end

print("same-job compatibility ok (1920x1080, 2560x1440, 5120x1440, 3840x2160)")
