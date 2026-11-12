-- nameplate_bible.lua: KstyleUI_Nameplates in the KSTY-44 mock-up's state, cropped as one frame each: the target
-- (Galestrider, level 6, 71 percent, one of the player's effects with nine stacks over the bar's right end) with
-- its brackets, the same mob not targeted, an elite casting an interruptible spell, a rare, a world boss and a
-- friendly player. The fake AuraContainer engine lays out no buttons, so the scene fills the effect tiles and places
-- them as the engine's flow layout would (Hud.PlaceAuras). Every base sits at scale 1, so the crops read in root
-- units. RENDER_COMBAT=1 puts the player in combat with a group, so threat shows on the plates that carry it.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local EMBER, SNAP = 135813, 132200
local PLATES = {
	{ token = "nameplate1", x = 320, y = 200, unit = { name = "Galestrider", health = 1206, maxHealth = 1698, level = 6, reaction = 2, canAttack = true, threat = 3 } },
	{ token = "nameplate2", x = 320, y = 330, unit = { name = "Galestrider", health = 1698, maxHealth = 1698, level = 6, reaction = 2, canAttack = true, threat = 0 } },
	{ token = "nameplate3", x = 320, y = 460, unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 } },
	{ token = "nameplate4", x = 760, y = 200, unit = { name = "Gorefang", health = 2400, maxHealth = 5200, level = 39, classification = "rare", reaction = 2, canAttack = true } },
	{ token = "nameplate5", x = 760, y = 330, unit = { name = "Azuregos", health = 610000, maxHealth = 850000, level = -1, classification = "worldboss", reaction = 2, canAttack = true } },
	{ token = "nameplate6", x = 760, y = 460, unit = { name = "Leduc", health = 3100, maxHealth = 3400, level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "PALADIN" } },
}

local function place(env, base, x, y)
	local k = 768 / 1080
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", x * k, (1080 - y) * k)
end

local function effect(env, ns, plate)
	local container = plate.auras
	if not container then
		return "the target plate has no aura container"
	end
	local group = container._groups.debuffs
	local button = group.frames[1]
	local aura = button._aura
	if aura.icon then
		aura.icon:SetTexture(env.Secret(EMBER))
	end
	if aura.count then
		aura.count:SetText("9")
	end
	Hud.PlaceAuras(container, group, { button }, ns.Settings.Get("debuffs.columns"))
	return nil
end

local function cast(env, token, spec)
	local unit = env._units[token]
	unit.cast = spec
	unit.castDuration = { start = env._time - 0.9, finish = env._time + 1.1, GetRemainingDuration = function() return 1.1 end }
	env.FireEvent("UNIT_SPELLCAST_START", token)
end

return Common.Run(function()
	local N = dofile("Tools/regression/nameplates_env.lua")
	local frames = Gallery.Frames()
	local combat = os.getenv("RENDER_COMBAT") == "1"
	local env, K, ns = N.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "Nameplates" }),
		setup = function(env)
			local unitClass = env.UnitClass
			Gallery.Setup(env)
			env.UnitClass = unitClass
			env.RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
			env._group = { raid = false, size = combat and 4 or 1 }
			env.IsInGroup = function()
				return combat
			end
			env.InCombatLockdown = function()
				return combat
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
	cast(env, "nameplate3", { name = "Snap", text = "Snap", texture = SNAP, notInterruptible = false })
	N.Debuffs(env, "nameplate1", 1)
	env.RunTimers()
	local problem = effect(env, ns, ns.Plates.Get("nameplate1"))
	for _ = 1, 10 do
		N.Tick(env, 0.05)
	end
	local function crop(token, name, title, caption)
		local plate = ns.Plates.Get(token)
		local list = { plate, plate.level, plate.marker, plate.brackets, plate.name }
		if plate.auras and plate.auras:IsShown() then
			list[#list + 1] = plate.auras
		end
		if plate.raid:IsShown() then
			list[#list + 1] = plate.raid
		end
		frames:Add(env, plate, {
			name = name, title = title, caption = caption, grade = "panel", reference = "nameplate", pad = 24,
			rect = Gallery.Union(env, list),
			match = "detail-nameplate-and-damage-numbers.jpg in renders/KSTY-44: the clean bar, the gilt brackets, the level diamond and the effect over the bar's right end.",
		})
	end
	crop("nameplate1", "plate_target", "Nameplate: the target", "The mock-up's plate: a clean bar, gilt brackets at both ends, the level diamond at the left and the player's effect over the bar's right end with its stack count.")
	crop("nameplate2", "plate_other", "Nameplate: the same mob, not the target", "No brackets; the level diamond stays, so nothing moves when the target changes.")
	crop("nameplate3", "plate_elite", "Nameplate: an elite casting", "The elite's diamond takes a two-pixel gold rim; the cast bar runs under the plate.")
	crop("nameplate4", "plate_rare", "Nameplate: a rare", "The rare's diamond takes a two-pixel rim in the rare colour.")
	crop("nameplate5", "plate_boss", "Nameplate: a world boss", "The boss's diamond reads ?? in red, inside a two-pixel red rim.")
	crop("nameplate6", "plate_friendly", "Nameplate: a friendly player", "A friendly player's plate in the class colour.")
	local scene = frames:Finish(Gallery.Build(env, { time = env._time }), env, K, "nameplate bible")
	if problem then
		scene.log[#scene.log + 1] = "nameplate bible: error: " .. problem
	end
	return scene
end)
