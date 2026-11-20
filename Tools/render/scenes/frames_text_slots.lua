-- frames_text_slots.lua: real default frames for base pixel comparisons, with optional extra text or unit-frame parity round 1 options through Options.
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
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
