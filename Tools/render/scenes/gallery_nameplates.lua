-- gallery_nameplates.lua: KstyleUI_Nameplates in a pull, each plate cropped as one frame of the gallery: the
-- target's plate mid-cast with three of the player's debuffs over it, a second crocolisk beside it (not the
-- target, so dimmed), an elite casting an uninterruptible spell under a skull raid marker with the player on
-- its threat table, and a friendly paladin's plate. The fake AuraContainer engine lays out no buttons, so this
-- scene fills the debuff tiles and places them as the engine's flow layout would (Hud.PlaceAuras). Every base
-- plate sits at scale 1 here, so the crops read in root units; scenes/nameplate.lua proves the 0.58 case.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local DEBUFFS = { { 132155, "18s", "2" }, { 132316, "9s" }, { 132363, "4s", "5" } }
local SNAP, SCREECH, HOLY_LIGHT = 132200, 136124, 135981
local PLATES = {
	{ token = "nameplate1", x = 300, y = 220, unit = { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true, threat = 3 } },
	{ token = "nameplate2", x = 300, y = 400, unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true, threat = 0 } },
	{ token = "nameplate3", x = 760, y = 220, unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 } },
	{ token = "nameplate4", x = 760, y = 400, unit = { name = "Leduc", health = 3100, maxHealth = 3400, level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "PALADIN" } },
}

local function place(env, base, x, y)
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", x * k, (1080 - y) * k)
end

-- debuffs(env, ns, plate) binds three of the player's debuffs to the target plate's tiles, as the engine would,
-- and lays them out above the health bar as the container's flow layout does.
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
		setup = function(env)
			local unitClass = env.UnitClass
			Gallery.Setup(env)
			-- The stub's UnitClass reads each unit's class (the paladin's plate); the gallery's reads the warrior's.
			env.UnitClass = unitClass
			env.RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
			env._group = { raid = false, size = 4 }
			env.IsInGroup = function()
				return true
			end
		end,
	}))
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	for _, spec in ipairs(PLATES) do
		local base = N.Add(env, spec.token, spec.unit)
		place(env, base, spec.x, spec.y)
	end
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = SNAP, notInterruptible = false })
	N.Cast(env, "nameplate3", { name = "Terrifying Screech", text = "Terrifying Screech", texture = SCREECH, notInterruptible = true })
	N.Cast(env, "nameplate4", { name = "Holy Light", text = "Holy Light", texture = HOLY_LIGHT, notInterruptible = false })
	for _ = 1, 20 do
		N.Tick(env, 0.05)
	end
	local problem = debuffs(env, ns, ns.Plates.Get("nameplate1"))
	for _ = 1, 10 do
		N.Tick(env, 0.05)
	end
	local function crop(token, spec)
		local plate = ns.Plates.Get(token)
		local list = { plate }
		if token == "nameplate1" and plate.auras then
			list[#list + 1] = plate.auras
		end
		spec.rect = Gallery.Union(env, list)
		spec.pad = 24
		frames:Add(env, plate, spec)
	end
	crop("nameplate1", {
		name = "nameplates_target", title = "Nameplate: the target, casting, with your debuffs", grade = "panel", reference = "nameplate",
		caption = "The target's plate: the health bar in the reaction colour with the level badge at its left end, the name above, the cast bar under it with the spell's icon, name and time left, three of the player's debuffs (chamfered tiles, timers and stack counts) above the name, and the target highlight round the bar.",
		match = "The bar is the mockup's plate bar over the crocolisk: the buttonFill track, the 1 px rim, the chamfered level badge; the cast bar and debuff tiles take the kit's bar and tile grades.",
	})
	crop("nameplate2", {
		name = "nameplates_other", title = "Nameplate: a second enemy, not the target", grade = "panel", reference = "nameplate",
		caption = "A plate that is not the target, at full health and with no threat: the same bar and badge, dimmed by the target setting's dim-others, so the target's plate leads the eye in a pull.",
		match = "The mockup's plate bar at rest: track, rim and badge, without the cast bar.",
	})
	crop("nameplate3", {
		name = "nameplates_elite", title = "Nameplate: an elite casting an uninterruptible spell", grade = "panel", reference = "nameplate",
		caption = "An elite's plate: the gold diamond above the bar's right end, the skull raid marker, the threat glow in the warning colour (the player is second on its table), and a cast bar in the uninterruptible colour with its icon dimmed.",
		match = "The mockup's plate bar with the kit's classification diamond and threat glow; the uninterruptible cast takes the textDisabled token.",
	})
	crop("nameplate4", {
		name = "nameplates_friendly", title = "Nameplate: a friendly player", grade = "panel", reference = "nameplate",
		caption = "A friendly paladin's plate in the class colour, the name in the class colour too, casting Holy Light.",
		match = "The mockup's plate bar in a class colour, as the party rows colour their bars.",
	})
	local scene = frames:Finish(Gallery.Build(env, { time = env._time }), env, K, "gallery nameplates")
	if problem then
		scene.log[#scene.log + 1] = "gallery nameplates: error: " .. problem
	end
	scene.log[#scene.log + 1] = "gallery nameplates: the debuffs are laid out by the scene as the AuraContainer engine would; the game binds each icon and timer itself"
	return scene
end)
