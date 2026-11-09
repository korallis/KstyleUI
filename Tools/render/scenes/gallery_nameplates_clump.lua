-- gallery_nameplates_clump.lua: KstyleUI_Nameplates in a pack pulled onto one point: eleven mobs standing together, so the game stacks their plates in one column, each pushed up by the footprint the module gives it (Stacking.lua) times its own scale. The stub has no engine stacking, so the scene places each plate where that rule puts it, the target's base at the selected scale the module's settings hold; with "Shrink distant plates" off (the default) the plate itself keeps its size, so the target stands out by its highlight, its debuffs and a taller slot. The target carries nine of the player's debuffs (five tiles with their timers in the lane under them, and the "+4" chip the engine's own layout counts), and its cast stands down because the target sigil shows it; four casters read the player's interrupt (the warrior's Pummel is ready, so interruptible casts take the accent), one casts through a shield, and the rest are type colours, raid markers and plain mobs.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local DEBUFFS = { { 132155, "18s", "2" }, { 132316, "9s" }, { 132363, "4s", "5" }, { 136207, "12s" }, { 132302, "7s", "3" } }
local DEBUFF_COUNT = 9
local POINT_X = 960
local FLOOR = 1050
local SNAP, HEX, BOLT, SCREECH, HEAL = 132200, 136071, 135808, 136124, 135915

-- The stack from the bottom up: the plate nearest the point first, as the game's stacking pushes each next plate up.
local STACK = {
	{ token = "nameplate2", unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true } },
	{ token = "nameplate3", unit = { name = "Mirefin Oracle", health = 980, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600 }, cast = { name = "Mirefin Hex", texture = HEX } },
	{ token = "nameplate1", target = true, unit = { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true, threat = 3 }, cast = { name = "Snap", texture = SNAP } },
	{ token = "nameplate5", unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 }, cast = { name = "Terrifying Screech", texture = SCREECH, notInterruptible = true } },
	{ token = "nameplate6", unit = { name = "Mirefin Coastrunner", health = 700, maxHealth = 1210, level = 38, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600 }, cast = { name = "Frostbolt", texture = BOLT } },
	{ token = "nameplate7", unit = { name = "Kul Tiras Deserter", health = 1300, maxHealth = 1300, level = 38, reaction = 2, canAttack = true, quest = true } },
	{ token = "nameplate9", unit = { name = "Mirefin Tidecaller", health = 640, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, powerType = 0, powerMax = 1600, raid = 1 }, cast = { name = "Healing Wave", texture = HEAL } },
	{ token = "nameplate10", unit = { name = "Geolord Mottle", health = 2100, maxHealth = 2600, level = 40, classification = "rare", reaction = 2, canAttack = true } },
	{ token = "nameplate8", unit = { name = "Razormane Scout", health = 1180, maxHealth = 1180, level = 37, reaction = 2, canAttack = true } },
	{ token = "nameplate11", unit = { name = "Riverglade Crocolisk", health = 1540, maxHealth = 1540, level = 38, reaction = 2, canAttack = true } },
	{ token = "nameplate4", unit = { name = "Mirefin Muckdweller", health = 1100, maxHealth = 1210, level = 38, reaction = 2, canAttack = true } },
}

-- place(env, base, x, y) puts a base's bottom centre at screen point (x, y); a scaled base's offsets are in its own units.
local function place(env, base, x, y)
	local k = 768 / 1080 / base:GetScale()
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

	-- Every plate on one point: the game stacks them in a column, each pushed up by its footprint times its scale.
	local _, above, height, below = ns.Stacking.Extent()
	local pitch = math.ceil(above + height + below)
	local selected = ns.Settings.Get("cvars.selectedScale")
	local all, casters = {}, {}
	local y = FLOOR
	for _, spec in ipairs(STACK) do
		local scale = spec.target and selected or 1
		local base = N.Add(env, spec.token, spec.unit, { scale = scale })
		place(env, base, POINT_X, y)
		y = y - pitch * scale
		all[#all + 1] = spec.token
	end
	N.Target(env, "nameplate1")
	for _, spec in ipairs(STACK) do
		if spec.cast then
			N.Cast(env, spec.token, { name = spec.cast.name, text = spec.cast.name, texture = spec.cast.texture, notInterruptible = spec.cast.notInterruptible == true })
			casters[#casters + 1] = spec.token
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
		name = "nameplates_clump", title = "Nameplates: a pack stacked on one point", grade = "panel", reference = "nameplate",
		rect = Gallery.Union(env, list), pad = 24,
		caption = "Eleven mobs pulled onto one point, so the game stacks their plates in one column, each pushed up by the footprint the module gives it (its debuff row and timer lane included) times its scale. The target (third from the bottom; the game scales its base, so its slot is taller, while the plate keeps its size because Shrink distant plates is off) wears nine of your debuffs: five tiles with their timers in the lane under them, and +4 on the chip the engine's own layout counts; its cast stands down because the target sigil shows it. Four casters with the warrior's Pummel ready take the accent, the elite's Terrifying Screech casts through a shield, and the quest mob, the rare and the marked mobs keep their colours. No plate's bar, cast or name runs into the next. The stub has no engine stacking: each plate sits where that rule puts it.",
		match = "The mockup's plate bar repeated as a dungeon pack: one track, rim and badge on every plate.",
	})
	local scene = frames:Finish(Gallery.Build(env, { time = env._time }), env, K, "gallery nameplates clump")
	scene.log[#scene.log + 1] = "gallery nameplates clump: one column on one point, each plate up by the footprint (" .. pitch .. " root units) times its scale, the target at " .. selected .. "; the target sigil's cast settings are stood in (Hud.PlateCasts); cast fills stand in for the engine's timer"
	return scene
end)
