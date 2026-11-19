-- test-compat-review.lua: explicit choices beat overlap defaults, notices obey their switch, and only overlapping parts yield.
local AB = dofile("Tools/regression/actionbars_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/meters_env.lua")

local function Loaded(addon)
	return function(env)
		env.C_AddOns = env.C_AddOns or {}
		env.C_AddOns.IsAddOnLoaded = function(name) return name == addon end
	end
end

local function Notices(env)
	local count = 0
	for _, text in ipairs(env._printed or {}) do
		if text:find("action bar bindings", 1, true) then count = count + 1 end
	end
	return count
end

local tests = {}
function tests.choice(screen)
	local env, K = AB.New({ width = screen[1], height = screen[2], setup = function(e)
		Loaded("Bartender4")(e)
		e._game.bindings.ACTIONBUTTON1 = { "1" }
	end })
	K.Options.Write("ActionBars", "enabled", true)
	env.RunTimers()
	assert(AB.PressKey(env, "1"), "the player's own ActionBars choice must keep bindings on")
	assert(Notices(env) == 0, "explicitly enabling ActionBars must not claim bindings are off; finish SettingChanged before printing")
	assert(#env._errors == 0 and #env._blocked == 0, "explicit enable must raise no errors")
end

function tests.notices(screen)
	local env, K = AB.New({ width = screen[1], height = screen[2], setup = Loaded("Bartender4") })
	K.Options.Write("Integrations", "notices", false)
	AB.Enable(env, K)
	env.FireEvent("UPDATE_BINDINGS")
	env.RunTimers()
	assert(Notices(env) == 0, "ActionBars must respect Other-addon notices before printing")
	K.Options.Write("Integrations", "notices", true)
	env.FireEvent("UPDATE_BINDINGS")
	env.RunTimers()
	assert(Notices(env) == 1, "re-enabling notices permits one notice while bindings still yield")
	assert(#env._errors == 0, "notice changes must raise no errors")
end

function tests.databars(screen)
	for _, addon in ipairs({ "Bartender4", "Dominos" }) do
		local setup = function(e) Loaded(addon)(e); D.Menus(e) end
		local env, K, ns = D.New({ width = screen[1], height = screen[2], setup = setup })
		assert(K.Setup.NewChoice().modules.DataBars, "setup must keep DataBars on beside " .. addon .. "; only its micro menu and bag bar yield")
		env.RunTimers()
		assert(ns.Bars.views.xp.content:IsShown() and ns.Strip.view.content:IsShown(), "XP and the data strip stay on")
		for _, id in ipairs({ "micro", "bags" }) do
			assert(not K.Options.Read("DataBars", id .. ".enabled"), "the yielded " .. id .. " switch must show Off")
			assert(not K.Safe.IsHidden(env[ns.Menus.GROUPS[id].hide]), "leave the overlapping Blizzard container alone")
			K.Options.Write("DataBars", id .. ".enabled", true)
			env.RunTimers()
			assert(ns.Menus.Visible(id) and K.Safe.IsHidden(env[ns.Menus.GROUPS[id].hide]), "the player can turn " .. id .. " back on beside " .. addon)
		end
		local reloaded, reloadK, reloadNs = D.New({ saved = env.KstyleUIDB, setup = setup })
		reloaded.RunTimers()
		assert(reloadNs.Menus.Visible("micro") and reloadNs.Menus.Visible("bags"), "both menu overrides survive reload")
		assert(reloadK.Store.Module("DataBars").micro.enabled, "reload preserves the chosen micro switch")
		assert(#env._errors == 0 and #reloaded._errors == 0, "menu overrides raise no errors")
	end
end

function tests.meters(screen)
	for _, mode in ipairs({ "window", "skin" }) do
		local env, K, ns = M.New({ width = screen[1], height = screen[2], setup = Loaded("Details") })
		assert(K.Setup.NewChoice().modules.Meters, "setup must keep Meters on beside Details; only damage yields")
		K.Options.Write("Meters", "damage.mode", mode)
		K.Options.Write("Meters", "followRole", true)
		K.Options.Write("Meters", "roles.DAMAGER", "both")
		M.Enable(env, K)
		assert(not K.Options.Read("Meters", "damage.shown") and not ns.Damage.holder:IsShown() and not ns.DamageSkin.active, "only damage starts off beside Details")
		assert(ns.Threat.holder:IsShown(), "threat stays on beside Details")
		K.Options.Write("Meters", "swing.attached", false)
		env.FireEvent("PLAYER_SWING", 2, M.SWING.MainHand)
		assert(ns.Swing.content:IsShown(), "swing stays on beside Details")
		K.Options.Write("Meters", "damage.shown", true)
		env.RunTimers()
		assert(mode == "skin" and ns.DamageSkin.active or mode == "window" and ns.Damage.holder:IsShown(), "the player can turn damage back on beside Details in " .. mode .. " mode")
		local reloaded, reloadK, reloadNs = M.New({ saved = env.KstyleUIDB, setup = Loaded("Details"), followRole = true })
		M.Enable(reloaded, reloadK)
		assert(reloadNs.MeterShown("damage"), "the damage override survives reload")
		assert(#env._errors == 0 and #reloaded._errors == 0, "damage overrides raise no errors")
	end
end

for _, screen in ipairs({ {1920, 1080}, {2560, 1440}, {5120, 1440}, {3840, 2160} }) do
	for _, name in ipairs({ "choice", "notices", "databars", "meters" }) do
		if not arg[1] or arg[1] == name then tests[name](screen) end
	end
end
print("compat review " .. (arg[1] or "all") .. " ok (1080p, 1440p, ultrawide, 4K)")
