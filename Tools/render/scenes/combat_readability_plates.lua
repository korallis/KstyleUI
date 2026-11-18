-- combat_readability_plates.lua: target, uninterruptible focus, and other plates in the selected preset, in ready, waiting and unknown-readiness rows.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local function Build(readiness, row)
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K, ns = N.New(Common.ScreenOpts({
		playerClass = os.getenv("RENDER_NO_INTERRUPT") == "1" and "HUNTER" or "WARRIOR", known = { [6552] = true },
		saved = Gallery.Saved({ "Nameplates", HudStyle = { style = (os.getenv("RENDER_HUD_STYLE") or "Medallions"):lower() } }),
		setup = Common.ForceScreen,
	}))
	if os.getenv("RENDER_PLATE_PRESET") == "Dungeon" and ns.Presets.VALUES.dungeon then
		K.Options.Write("Nameplates", "preset", "dungeon")
	end
	if readiness ~= "ready" then
		env._cooldowns[6552] = { isActive = readiness == "secret" and env.Secret(true) or true, isOnGCD = false }
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
	end
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	local width = Common.SCREEN.width / Common.SCREEN.height * 1080
	local names = { "Mirefin Oracle", "Bloodtalon Matriarch", "Riverglade Snapper" }
	for i, name in ipairs(names) do
		local base = N.Add(env, "nameplate" .. i, { name = name, health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true })
		base:ClearAllPoints()
		base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", (width / 2 + (i - 2) * 280) * 768 / 1080, (800 - (row - 1) * 200) * 768 / 1080)
		local spell = i == 2 and "Terrifying Screech" or "Shadow Bolt"
		N.Cast(env, "nameplate" .. i, { name = spell, text = spell, texture = 136197, notInterruptible = i == 2 })
		Hud.FillCast(ns.Plates.Get("nameplate" .. i), 0.55)
	end
	N.Target(env, "nameplate1")
	N.Focus(env, "nameplate2")
	N.Debuffs(env, "nameplate1", 2)
	env.RunTimers()
	local plate = ns.Plates.Get("nameplate1")
	local group = plate.auras._groups.debuffs
	local buttons = {}
	for i = 1, 2 do
		local button = group.frames[i]
		button._aura.icon:SetTexture(i == 1 and 135813 or 136026)
		button._aura.timer:SetText(i == 1 and "12s" or "3s")
		button._aura.count:SetText(i == 1 and "3" or "")
		local color = button._aura.timerOptions.textColor
		if color then
			button._aura.timer:SetTextColor(color.curve.points[i == 1 and 2 or 1].color:GetRGBA())
		end
		buttons[i] = button
	end
	Hud.PlaceAuras(plate.auras, group, buttons, ns.Settings.Get("debuffs.columns"))
	for _ = 1, 20 do N.Tick(env, 0.05) end
	local scene = Common.Scene.Build(env, { time = env._time, iconDirs = Common.IconDirs() })
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return scene
end
return Common.Run(function()
	local scenes = {}
	for row, readiness in ipairs({ "ready", "wait", "secret" }) do scenes[#scenes + 1] = Build(readiness, row) end
	return Common.Scene.Merge(scenes)
end)
