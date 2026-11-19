-- short_numbers.lua: the five number surfaces on the same 12,400 and 41,800 fixtures, using their real formatters.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local settings = Hud.PresetSettings("Tank")
	settings.UnitFrames.player = { healthText = "currentMax" }
	settings.UnitFrames.target = { healthText = "currentMax" }
	settings.GroupFrames.party = { healthText = "CURRENT_MAX" }
	settings.GroupFrames.raid = { healthText = "CURRENT_MAX" }
	settings.GroupFrames.icons = { role = false, leader = false }
	settings.Nameplates = { healthText = { show = true, format = "value" } }
	settings.DataBars.xp = { text = "short", textHover = false, instrumentText = false }
	return Hud.Build({
		layout = "Tank", settings = settings,
		modules = { "nameplates", "groupframes", "meters", "unitframes", "databars" },
		player = { health = 12400, healthMax = 41800 },
		target = { name = "Shadowgale Poacher", level = 38, health = 12400, healthMax = 41800, reaction = 2, canAttack = true },
		party = { { "Leduc", "PALADIN", 12400, "HEALER", 41800 }, { "Trolly", "PRIEST", 1240000, "DAMAGER", 2500000 } },
		raid = os.getenv("RENDER_SHORT_RAID") == "1",
		plates = { { unit = { name = "Shadowgale Poacher", level = 38, health = 12400, maxHealth = 41800, reaction = 2, canAttack = true }, x = 900, y = 380 } },
		damage = { { "Thaldren", "WARRIOR", 12400 }, { "Leduc", "PALADIN", 1240 } },
		meterHover = false, meterSolo = false,
		game = { xp = 12400, xpMax = 41800, faction = false }, menus = false,
	})
end)
