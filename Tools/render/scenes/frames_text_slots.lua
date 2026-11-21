-- frames_text_slots.lua: real default frames for base pixel comparisons, with optional extra text through Options, or (RENDER_AURA_BOTH=1) the target's Debuffs and buffs, with every row full and the target of target shown under RENDER_AURA_FULL=1.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local module = os.getenv("RENDER_PARITY_MODULE") or "UnitFrames"
	local names = { UnitFrames = "unitframes", GroupFrames = "groupframes", Nameplates = "nameplates" }
	local scene = Hud.Module(assert(names[module]), { layout = "DPS", party = {
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
	if os.getenv("RENDER_AURA_BOTH") == "1" and module == "UnitFrames" then
		K.Options.Write(module, "target.auraFilter", "both")
		env._units.target.auras = { { id = 1, icon = 135813, left = 9, harmful = true, mine = true }, { id = 2, icon = 136026, left = 3, harmful = true, mine = true },
			{ id = 3, icon = 136207, left = 30, harmful = false }, { id = 4, icon = 136118, left = 12, harmful = false } }
		if os.getenv("RENDER_AURA_FULL") == "1" then
			for i = 5, 32 do env._units.target.auras[i] = { id = i, icon = i % 2 == 0 and 135813 or 136207, left = 30 + i, harmful = i % 2 == 0, mine = i % 2 == 0 } end
			dofile("Tools/regression/unitframes_env.lua").SetUnit(env, "targettarget", env._units.player)
			env.FireEvent("UNIT_TARGET", "target")
		end
		dofile("Tools/regression/aura_fixture_engine.lua").Install(env)
	end
	env.RunTimers(); Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 40)
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
