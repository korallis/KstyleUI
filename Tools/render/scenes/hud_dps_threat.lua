-- hud_dps_threat.lua: the DPS HUD with the optional compact threat card enabled alongside the damage card.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local opts = Hud.Options({ layout = "DPS" })
	opts.settings.Meters.threat.shown = true
	opts.settings.Meters.damage = { mode = "window" }
	opts.damage = { { "Valerin", "WARRIOR", 7912 }, { "Leduc", "PALADIN", 4200 }, { "Trolly", "PRIEST", 2300 } }
	opts.modules = Hud.Order()
	opts.modules[#opts.modules + 1] = "meters"
	return Hud.Build(opts)
end)
