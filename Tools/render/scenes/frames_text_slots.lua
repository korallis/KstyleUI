-- frames_text_slots.lua: real default frames for base pixel comparisons, with optional extra text or unit-frame parity round 1, 2 or 3a options through Options.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local names = { UnitFrames = "unitframes", GroupFrames = "groupframes", Nameplates = "nameplates" }
	local scene, ns = Hud.Module(assert(names[module]), { layout = "DPS", party = {
		{ "Thaldren", "WARRIOR", 75, "TANK" }, { "Sylaen", "PRIEST", 80, "HEALER" },
		{ "Brakka", "SHAMAN", 50, "DAMAGER" }, { "Lunara", "MAGE", 90, "DAMAGER" },
	} })
	local env = assert(Hud.envs[scene])
	local K = env.KstyleUI
	if os.getenv("RENDER_EXTRA_TEXT") == "1" then
		local prefixes = { UnitFrames = "player.", GroupFrames = "party.", Nameplates = "" }
		local prefix = prefixes[module]
		K.Options.Get(module)
		K.Options.Write(module, prefix .. "extra1.textFormat", "[pp:abr] / [pp:max]")
		K.Options.Write(module, prefix .. "extra1.position", "BOTTOM")
		K.Options.Write(module, prefix .. "extra1.y", -8)
		K.Options.Write(module, prefix .. "extra2.textFormat", "[hp:pct]")
		K.Options.Write(module, prefix .. "extra2.position", "CENTER")
		if module == "GroupFrames" then
			K.Options.Write(module, "party.healthText", "NONE")
			K.Options.Write(module, prefix .. "extra2.position", "TOPRIGHT")
		elseif module == "Nameplates" then
			K.Options.Write(module, "extra1.textFormat", "[hp:abr] / [hp:max]")
			K.Options.Write(module, "extra1.position", "TOP")
			K.Options.Write(module, "extra1.y", 32)
		end
	end
	if os.getenv("RENDER_PARITY_R1") == "1" and module == "UnitFrames" then
		local target = env._units.target
		target.classification, target.pvp, target.faction = "elite", true, "Horde"
		dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "focus", target)
		env.FireEvent("PLAYER_FOCUS_CHANGED")
		env.C_PetInfo = { GetPetHappiness = function() return 3 end }
		env.HasPetUI = function() return true, true end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "healthDecimal", true }, { "castbarRaise", true },
			{ "target.healthAlpha", 0.75 }, { "target.healthGradient", "HORIZONTAL" }, { "target.elite", true },
			{ "target.portraitMirror", true }, { "target.portraitZoom", 0.15 }, { "target.castbarIcon", true },
			{ "target.castbarIconRight", true }, { "target.castbarAlpha", 0.75 }, { "target.auraZoom", 0.2 },
			{ "player.healthColor", "health" }, { "player.portraitMirror", true }, { "player.incomingAlpha", 0.8 },
			{ "focus.targetBorder", true }, { "focus.elite", true }, { "pet.happiness", true }, { "pet.hoverBorder", true },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		local pet = ns.Frames.Get("pet").views[1]
		if pet.button:IsShown() then dofile("Tools/regression/widget_env.lua").Enter(pet.button) end
	end
	if os.getenv("RENDER_PARITY_R2") == "1" and module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		if not env._units.pet then
			U.SetUnit(env, "pet", { name = "Wolf", level = 38, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
		end
		env._units.pet.auras = { { id = 1, icon = 136207, left = 9, harmful = true, mine = false, count = 2, dispel = "Magic" }, { id = 2, icon = 135813, left = 14, harmful = false, mine = true } }
		env._units.target.auras = { { id = 3, icon = 135813, left = 6, harmful = true, mine = true, count = 3, dispel = "Magic" }, { id = 4, icon = 136207, left = 12, harmful = true, mine = true },
			{ id = 5, icon = 136096, left = 30, harmful = false, dispel = "Magic", stealable = true }, { id = 6, icon = 135846, left = 40, harmful = false, dispel = "Magic" } }
		for i, name in ipairs({ "Magmatus", "Ignaxis" }) do
			U.SetUnit(env, "boss" .. i, { name = name, level = -1, classification = "worldboss", health = 72000 - i * 9000, healthMax = 100000, power = 0, powerMax = 100, reaction = 2 })
		end
		env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
		env.C_Spell.IsSpellImportant = function() return true end
		env.UnitShouldDisplaySpellTargetName = function() return true end
		env.UnitSpellTargetName = function() return env._units.player.name end
		K.Options.Get(module)
		for _, pair in ipairs({
			{ "pet.auras", true }, { "pet.auraFilter", "both" }, { "target.auraCountSize", 12 }, { "target.auraCountPoint", "TOPLEFT" },
			{ "target.auraFilter", "buffs" }, { "target.auraBuffDispel", true }, { "target.auraStealable", true }, { "target.auraTimerY", 1 }, { "player.powerAlpha", 0.6 }, { "player.powerGradient", "HORIZONTAL" },
			{ "target.castbarTarget", true }, { "target.castbarImportant", true }, { "player.castbarIconX", 2 }, { "boss.gap", 12 },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	if os.getenv("RENDER_PARITY_R3A") == "1" and module == "UnitFrames" then
		local U = dofile("Tools/regression/unitframes_env.lua")
		env._units.target.marker = 8
		U.SetUnit(env, "focus", env._units.target)
		U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 72000, healthMax = 100000, reaction = 2, canAttack = true })
		env.C_PetInfo = { GetPetHappiness = function() return 3 end }
		env.HasPetUI = function() return true, true end
		for _, event in ipairs({ "PLAYER_FOCUS_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "RAID_TARGET_UPDATE" }) do env.FireEvent(event) end
		for _, pair in ipairs({
			{ "target.markerSize", 28 }, { "pet.happiness", true }, { "pet.happinessPosition", "LEFT" }, { "pet.castbar", true },
			{ "pet.castbarHideIdle", false }, { "focus.auraCopy", "target" }, { "target.auraBuffZoom", 0.25 },
			{ "boss.auraSimple", "LEFT" }, { "boss.castbarHideIdle", false }, { "focus.auraFilter", "both" },
		}) do
			K.Options.Write(module, pair[1], pair[2])
		end
		local function auras(harmful, helpful)
			local list = {}
			for i, icon in ipairs({ 135813, 136026, 136207, 136197 }) do
				if i <= harmful or i > 4 - helpful then list[#list + 1] = { id = i, icon = icon, left = i * 7, harmful = i <= harmful, mine = true } end
			end
			return list
		end
		env._units.boss1.auras, env._units.target.auras = auras(3, 0), auras(2, 2)
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	if os.getenv("RENDER_PARITY_R3A") == "1" and module == "UnitFrames" then
		local W, zoomed = dofile("Tools/regression/widget_env.lua"), false
		for _, entry in ipairs(ns.Frames.Get("focus").views[1].auras.buttons) do
			zoomed = zoomed or entry.buff and entry.button:IsVisible() and W.LastCall(entry.icon, "SetTexCoord")[1] == 0.25
		end
		assert(zoomed, "the focus shows a buff at the target's buff zoom")
	end
	return Gallery.Build(env)
end)
