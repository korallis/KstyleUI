-- frames_parity.lua: the real scoped module frames with optional parity controls, selected with RENDER_PARITY_MODULE.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local names = { UnitFrames = "unitframes", GroupFrames = "groupframes", Nameplates = "nameplates" }
	local scene, ns = Hud.Module(assert(names[module]), { layout = "DPS", boss = {
		name = "Magmatus", level = 40, health = 72000, healthMax = 100000, reaction = 2, canAttack = true,
		cast = { name = "Whirlwind", texture = 132369, start = 8500, finish = 12000, spellID = 1680, notInterruptible = true },
	}, party = {
		{ "Thaldren", "WARRIOR", 75, "TANK" }, { "Sylaen", "PRIEST", 80, "HEALER" },
		{ "Brakka", "SHAMAN", 50, "DAMAGER" }, { "Lunara", "MAGE", 90, "DAMAGER" },
	} })
	local env = assert(Hud.envs[scene])
	local K = env.KstyleUI
	if module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 2500, healthMax = 4000, reaction = 2, canAttack = true,
			cast = { name = "Frostbolt", texture = 135846, start = 8500, finish = 12000, spellID = 116 } })
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		env.GetNetStats = function() return 0, 0, 30, 180 end
		K.Options.Write(module, "player.castbarLatency", true)
	elseif module == "GroupFrames" then
		env.UnitHasIncomingResurrection = function(unit) return unit == "party1" end
		env.C_IncomingSummon = { HasIncomingSummon = function(unit) return unit == "party2" end }
		env.UnitIsAFK = function(unit) return unit == "party3" end
		ns.Unit.ForEach(ns.Indicators.Status)
	else
		K.Options.Write(module, "target.dimOthers", 0.4)
		K.Options.Write(module, "cast.spark", true)
		K.Options.Write(module, "cast.hideUnitName", true)
		K.Options.Write(module, "cast.fullOpacity", true)
		K.Options.Write(module, "focus.fullOpacity", true)
		dofile("Tools/regression/nameplates_env.lua").Focus(env, "nameplate2")
	end
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
