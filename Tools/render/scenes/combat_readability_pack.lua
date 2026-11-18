-- combat_readability_pack.lua: twenty Medallions plates in four stacks, spaced by their full stacking bounds, with five debuffs, timers, stacks, and live casts on every mob.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K, ns = N.New(Common.ScreenOpts({
		playerClass = "WARRIOR", known = { [6552] = true }, stackingBounds = true,
		saved = Gallery.Saved({ "Nameplates", HudStyle = { style = "medallions" } }), setup = Common.ForceScreen,
	}))
	if os.getenv("RENDER_PLATE_PRESET") == "Dungeon" and ns.Presets.VALUES.dungeon then
		K.Options.Write("Nameplates", "preset", "dungeon")
	end
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	local plates = {}
	local icons = { 135813, 136026, 132155, 132316, 136207 }
	for i = 1, 20 do
		local token = "nameplate" .. i
		N.Add(env, token, { name = i % 2 == 0 and "Mirefin Oracle" or "Bloodtalon Matriarch", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true })
		N.Cast(env, token, { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = i % 3 == 0 })
		N.Debuffs(env, token, 5)
		plates[i] = ns.Plates.Get(token)
	end
	N.Target(env, "nameplate1")
	N.Focus(env, "nameplate2")
	env.RunTimers()
	local maxWidth, maxHeight = 0, 0
	for _, plate in ipairs(plates) do
		local group, buttons = plate.auras._groups.debuffs, {}
		for i = 1, 5 do
			local button = group.frames[i]
			button._aura.icon:SetTexture(icons[i])
			button._aura.timer:SetText(i == 3 and "3s" or "12s")
			local color = button._aura.timerOptions.textColor
			if color then
				button._aura.timer:SetTextColor(color.curve.points[i == 3 and 1 or 2].color:GetRGBA())
			end
			button._aura.count:SetText(i == 1 and "3" or "")
			buttons[i] = button
		end
		Hud.PlaceAuras(plate.auras, group, buttons, 5)
		Hud.FillCast(plate, 0.55)
		local w, a, h, b = ns.Stacking.Extent(plate)
		maxWidth, maxHeight = math.max(maxWidth, w), math.max(maxHeight, a + h + math.max(b, ns.Stacking.BarRise() or 0))
	end
	local strideX, strideY = math.ceil(maxWidth + 24), math.ceil(maxHeight + 12)
	local width = Common.SCREEN.width / Common.SCREEN.height * 1080
	for i, plate in ipairs(plates) do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		plate.base:ClearAllPoints()
		plate.base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", (width / 2 + (col - 1.5) * strideX) * 768 / 1080, (540 + (2 - row) * strideY) * 768 / 1080)
	end
	for _ = 1, 20 do N.Tick(env, 0.05) end
	local rects = {}
	for _, plate in ipairs(plates) do
		local x, y, w, h = Common.Scene.Rect(env, plate.stackBounds)
		assert(x and x >= 0 and y >= 0 and x + w <= width and y + h <= 1080, "a stacked plate leaves the screen: " .. table.concat({ x or -1, y or -1, w or -1, h or -1, width }, ","))
		for _, r in ipairs(rects) do
			assert(x >= r[1] + r[3] or r[1] >= x + w or y >= r[2] + r[4] or r[2] >= y + h, "neighbouring plate bounds overlap: " .. table.concat({ x, y, w, h, r[1], r[2], r[3], r[4], strideX, strideY }, ","))
		end
		rects[#rects + 1] = { x, y, w, h }
	end
	assert(not Common.Errors(env, K), Common.Errors(env, K))
	return Gallery.Build(env, { time = env._time })
end)
