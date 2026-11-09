-- gallery_nameplates_clump.lua: KstyleUI_Nameplates in a twelve-mob clump, three stacks of four at the pitch the module gives the game (Stacking.lua), as a dungeon pack looks when it is pulled together. The target carries nine of the player's debuffs (five tiles and the "+4" chip the engine's own layout counts), and its cast stands down because the target sigil shows it; four casters read the player's interrupt (the warrior's Pummel is ready, so interruptible casts take the accent), one casts through a shield, and the rest are type colours, a raid marker and plain mobs.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local DEBUFFS = { { 132155, "18s", "2" }, { 132316, "9s" }, { 132363, "4s", "5" }, { 136207, "12s" }, { 132302, "7s", "3" } }
local DEBUFF_COUNT = 9
local COLUMNS = { 420, 860, 1300 }
local FLOOR = 900
local SNAP, HEX, BOLT, SCREECH, HEAL = 132200, 136071, 135808, 136124, 135915

-- Each column lists its plates from the bottom of the stack up.
local STACKS = {
	{
		{ token = "nameplate1", unit = { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true, threat = 3 }, cast = { name = "Snap", texture = SNAP } },
		{ token = "nameplate2", unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true } },
		{ token = "nameplate3", unit = { name = "Mirefin Oracle", health = 980, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600 }, cast = { name = "Mirefin Hex", texture = HEX } },
		{ token = "nameplate4", unit = { name = "Mirefin Muckdweller", health = 1100, maxHealth = 1210, level = 38, reaction = 2, canAttack = true } },
	},
	{
		{ token = "nameplate5", unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 }, cast = { name = "Terrifying Screech", texture = SCREECH, notInterruptible = true } },
		{ token = "nameplate6", unit = { name = "Mirefin Coastrunner", health = 700, maxHealth = 1210, level = 38, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600 }, cast = { name = "Frostbolt", texture = BOLT } },
		{ token = "nameplate7", unit = { name = "Kul Tiras Deserter", health = 1300, maxHealth = 1300, level = 38, reaction = 2, canAttack = true, quest = true } },
		{ token = "nameplate8", unit = { name = "Razormane Scout", health = 1180, maxHealth = 1180, level = 37, reaction = 2, canAttack = true } },
	},
	{
		{ token = "nameplate9", unit = { name = "Mirefin Tidecaller", health = 640, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600, raid = 1 }, cast = { name = "Healing Wave", texture = HEAL } },
		{ token = "nameplate10", unit = { name = "Geolord Mottle", health = 2100, maxHealth = 2600, level = 40, classification = "rare", reaction = 2, canAttack = true } },
		{ token = "nameplate11", unit = { name = "Riverglade Crocolisk", health = 1540, maxHealth = 1540, level = 38, reaction = 2, canAttack = true } },
		{ token = "nameplate12", unit = { name = "Mirefin Muckdweller", health = 1210, maxHealth = 1210, level = 38, reaction = 2, canAttack = true } },
	},
}

local function place(env, base, x, y)
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("BOTTOM", env.WorldFrame, "BOTTOMLEFT", x * k, (1080 - y) * k)
end

local function debuffs(env, ns, plate)
	local container = plate.auras
	local group = container._groups.debuffs
	local buttons = {}
	for i, entry in ipairs(DEBUFFS) do
		local button = group.frames[i]
		local aura = button._aura
		if aura.icon then
			aura.icon:SetTexture(env.Secret(entry[1]))
		end
		if aura.timer then
			aura.timer:SetText(entry[2])
		end
		if aura.count then
			aura.count:SetText(entry[3] or "")
		end
		buttons[i] = button
	end
	Hud.PlaceAuras(container, group, buttons, ns.Settings.Get("debuffs.columns"))
end

return Common.Run(function()
	local N = dofile("Tools/regression/nameplates_env.lua")
	local frames = Gallery.Frames()
	local env, K, ns = N.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Nameplates" }),
		playerClass = "WARRIOR",
		setup = function(env)
			local unitClass = env.UnitClass
			Gallery.Setup(env)
			env.UnitClass = unitClass
			env._group = { raid = false, size = 5 }
			env.IsInGroup = function()
				return true
			end
		end,
	}))
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	Hud.PlateCasts(env, K, ns, "WARRIOR")

	local _, above, height, below = ns.Stacking.Extent()
	local pitch = math.ceil(above + height + below)
	local all, casters = {}, {}
	for column, stack in ipairs(STACKS) do
		for i, spec in ipairs(stack) do
			local base = N.Add(env, spec.token, spec.unit)
			place(env, base, COLUMNS[column], FLOOR - (i - 1) * pitch)
			all[#all + 1] = spec.token
		end
	end
	N.Target(env, "nameplate1")
	for _, stack in ipairs(STACKS) do
		for _, spec in ipairs(stack) do
			if spec.cast then
				N.Cast(env, spec.token, { name = spec.cast.name, text = spec.cast.name, texture = spec.cast.texture, notInterruptible = spec.cast.notInterruptible == true })
				casters[#casters + 1] = spec.token
			end
		end
	end
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	N.Debuffs(env, "nameplate1", DEBUFF_COUNT)
	env.RunTimers()
	debuffs(env, ns, ns.Plates.Get("nameplate1"))
	for _ = 1, 10 do
		N.Tick(env, 0.05)
	end
	for i, token in ipairs(casters) do
		Hud.FillCast(ns.Plates.Get(token), 0.3 + 0.12 * i)
	end

	local list = {}
	for _, token in ipairs(all) do
		local plate = ns.Plates.Get(token)
		list[#list + 1] = plate
		list[#list + 1] = plate.level
		if token == "nameplate1" then
			list[#list + 1] = plate.auras
			list[#list + 1] = plate.auraChip.window
		end
		if plate.raid:IsShown() then
			list[#list + 1] = plate.raid
		end
	end
	frames:Add(env, ns.Plates.Get("nameplate1"), {
		name = "nameplates_clump", title = "Nameplates: a twelve-mob clump", grade = "panel", reference = "nameplate",
		rect = Gallery.Union(env, list), pad = 24,
		caption = "Twelve plates in three stacks at the pitch the module gives the game. The target (the near crocolisk) wears nine of your debuffs, five on tiles and +4 on the chip the engine's own layout counts, so the count holds in combat; its cast stands down because the target sigil shows it. Four casters with the warrior's Pummel ready take the accent, the elite's Terrifying Screech casts through a shield, and the quest mob, the rare and the marked mobs keep their colours. No plate runs into the next.",
		match = "The mockup's plate bar repeated as a dungeon pack: one track, rim and badge on every plate.",
	})
	local scene = frames:Finish(Gallery.Build(env, { time = env._time }), env, K, "gallery nameplates clump")
	scene.log[#scene.log + 1] = "gallery nameplates clump: stacked at pitch " .. pitch .. " root units; the target sigil's cast settings are stood in (Hud.PlateCasts); cast fills stand in for the engine's timer"
	return scene
end)
