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
		local N = dofile("Tools/regression/nameplates_env.lua")
		if os.getenv("RENDER_PARITY_ROUND") == "1" then
			-- Round 1 switched on: threat percent (at the right, beside the health text) and name colour, the health line and
			-- name marker on the target, the focus letter, a PvP badge, the spell target and a level difficulty colour.
			env.GetCreatureDifficultyColor = function(level) return level > 40 and { r = 1, g = 0.5, b = 0.25 } or { r = 1, g = 0.82, b = 0 } end
			local target, add = env._units.nameplate1, env._units.nameplate2
			target.threat, target.threatPct, target.raid = 1, 72, 8
			add.pvp, add.faction, add.spellTarget = true, "Horde", "Thaldren"
			for key, value in pairs({ ["threat.groupOnly"] = false, ["threat.name"] = true, ["threat.percent"] = true, ["threat.percentColor"] = true,
				["threat.percentPlace"] = "RIGHT", ["healthText.show"] = true,
				["target.hashLine"] = true, ["markers.nameRaid"] = true, ["focus.letter"] = "CENTER", ["markers.pvp"] = true,
				["markers.pvpPlayersOnly"] = false, ["cast.showTarget"] = true, ["cast.hideUnitName"] = false, ["level.colorMode"] = "difficulty" }) do
				K.Options.Write(module, key, value)
			end
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
		elseif os.getenv("RENDER_PARITY_ROUND") == "2" then
			-- Round 2 switched on: the target's glow, bar highlight and size, a rogue's combo points and energy on the target, an
			-- important cast with its glow and a larger spell icon on the add, and threat as the bar colour and its edge.
			local unitClass = env.UnitClass
			env.UnitClass = function(unit)
				if unit == "player" then return "Rogue", "ROGUE", 4 end
				return unitClass(unit)
			end
			env._units.player = env._units.player or {}
			env._units.player.power, env._units.player.powerMax = 70, 100
			env.GetComboPoints = function() return 3 end
			env.C_Spell.IsSpellImportant = function(id) return id ~= nil end
			env._units.nameplate2.threat = 1
			for key, value in pairs({ ["target.glow"] = true, ["target.fill"] = true, ["target.scale"] = 1.15, ["resource.show"] = true,
				["resource.energy"] = true, ["cast.important"] = true, ["cast.importantGlow"] = true, ["cast.showIcon"] = true,
				["cast.iconScale"] = 1.4, ["threat.groupOnly"] = false, ["threat.display"] = "healthEdge", ["cast.hideUnitName"] = false }) do
				K.Options.Write(module, key, value)
			end
			N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
			Hud.FillCast(ns.Plates.Get("nameplate2"), 0.4)
		end
		N.Focus(env, "nameplate2")
	end
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
