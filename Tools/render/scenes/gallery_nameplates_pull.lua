-- gallery_nameplates_pull.lua: KstyleUI_Nameplates in a seven-mob pull, cropped as one frame of the gallery. The
-- game stacks plates by the size the module gives it (Stacking.lua: the plate's own footprint), so this scene
-- stacks two columns of bases at that footprint's pitch, as the game's stacking would, and the crop proves that
-- stacked plates clear each other and still read: the target mid-cast with the player's debuffs, a caster in the
-- caster colour casting an interruptible spell, a quest mob in the quest colour, a rare in the rare colour, an
-- elite under a skull casting an uninterruptible spell, and two plain mobs. The warrior's Pummel is ready, so
-- interruptible casts take the accent. The target carries eight of the player's debuffs: the engine assigns five
-- tiles (A.Assign stands in for its frame refresh) and the plate's "+3" chip counts the rest. The fake engine lays
-- out no buttons, so the scene fills the five tiles and places them as the flow layout would (Hud.PlaceAuras).
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local DEBUFFS = { { 132155, "18s", "2" }, { 132316, "9s" }, { 132363, "4s", "5" }, { 136207, "12s" }, { 132302, "7s", "3" } }
local DEBUFF_COUNT = 8
local SNAP, SCREECH, HEX = 132200, 136124, 136071
local PUMMEL = 6552
local COLUMNS = { 560, 1120 }
local FLOOR = 760

-- Each column lists its plates from the bottom of the stack up, as the game stacks plates over the mob nearest
-- the camera.
local STACKS = {
	{
		{ token = "nameplate1", unit = { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true, threat = 3 } },
		{ token = "nameplate2", unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true, threat = 0 } },
		{ token = "nameplate3", unit = { name = "Mirefin Oracle", health = 980, maxHealth = 1210, level = 39, reaction = 2, canAttack = true, threat = 0, powerType = 0, powerMax = 1600 } },
	},
	{
		{ token = "nameplate4", unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 } },
		{ token = "nameplate5", unit = { name = "Kul Tiras Deserter", health = 1300, maxHealth = 1300, level = 38, reaction = 2, canAttack = true, quest = true } },
		{ token = "nameplate6", unit = { name = "Geolord Mottle", health = 2100, maxHealth = 2600, level = 40, classification = "rare", reaction = 2, canAttack = true } },
		{ token = "nameplate7", unit = { name = "Razormane Scout", health = 1180, maxHealth = 1180, level = 37, reaction = 2, canAttack = true } },
	},
}

local function place(env, base, x, y)
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("BOTTOM", env.WorldFrame, "BOTTOMLEFT", x * k, (1080 - y) * k)
end

local function debuffs(env, ns, plate)
	local container = plate.auras
	if not container then
		return "the target plate has no aura container"
	end
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
	return nil
end

return Common.Run(function()
	local N = dofile("Tools/regression/nameplates_env.lua")
	local frames = Gallery.Frames()
	local env, K, ns = N.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Nameplates" }),
		playerClass = "WARRIOR",
		known = { [PUMMEL] = true },
		setup = function(env)
			local unitClass = env.UnitClass
			Gallery.Setup(env)
			env.UnitClass = unitClass
			env._group = { raid = false, size = 4 }
			env.IsInGroup = function()
				return true
			end
		end,
	}))
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10

	-- The game's stacking pitch is the footprint the module gave it: the plate's extent with one row of debuffs,
	-- in the base's units. Every base sits at scale 1 here, so that pitch is in root units.
	local _, above, height, below = ns.Stacking.Extent()
	local pitch = math.ceil(above + height + below)
	local all = {}
	for column, stack in ipairs(STACKS) do
		for i, spec in ipairs(stack) do
			local base = N.Add(env, spec.token, spec.unit)
			place(env, base, COLUMNS[column], FLOOR - (i - 1) * pitch)
			all[#all + 1] = spec.token
		end
	end
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = SNAP, notInterruptible = false })
	N.Cast(env, "nameplate3", { name = "Mirefin Hex", text = "Mirefin Hex", texture = HEX, notInterruptible = false })
	N.Cast(env, "nameplate4", { name = "Terrifying Screech", text = "Terrifying Screech", texture = SCREECH, notInterruptible = true })
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	N.Debuffs(env, "nameplate1", DEBUFF_COUNT)
	env.RunTimers()
	local problem = debuffs(env, ns, ns.Plates.Get("nameplate1"))
	for _ = 1, 10 do
		N.Tick(env, 0.05)
	end

	local list = {}
	for _, token in ipairs(all) do
		local plate = ns.Plates.Get(token)
		list[#list + 1] = plate
		list[#list + 1] = plate.level
		if plate.auras and token == "nameplate1" then
			list[#list + 1] = plate.auras
			list[#list + 1] = plate.auraChip
		end
		if plate.raid:IsShown() then
			list[#list + 1] = plate.raid
		end
	end
	frames:Add(env, ns.Plates.Get("nameplate1"), {
		name = "nameplates_pull", title = "Nameplates: a seven-mob pull, stacked", grade = "panel", reference = "nameplate",
		rect = Gallery.Union(env, list), pad = 24,
		caption = "Seven plates stacked at the pitch the module gives the game (the plate's own footprint, Stacking.lua): the target mid-cast with eight of the player's debuffs, five on tiles and a +3 chip for the rest, a caster in the caster colour casting an interruptible spell in the accent (the warrior's Pummel is ready), a quest mob in the quest colour, a rare in the rare colour, an elite under a skull casting an uninterruptible spell in the shield colour, and two plain mobs. No plate runs into the next.",
		match = "The mockup's plate bar repeated as a pull: the same track, rim and badge on every plate, the type colours and the interrupt colours the kit's tokens (quest, rare, epic, textDisabled).",
	})
	local scene = frames:Finish(Gallery.Build(env, { time = env._time }), env, K, "gallery nameplates pull")
	if problem then
		scene.log[#scene.log + 1] = "gallery nameplates pull: error: " .. problem
	end
	scene.log[#scene.log + 1] = "gallery nameplates pull: stacked at pitch " .. pitch .. " root units, the footprint Stacking.lua gives the game"
	return scene
end)
