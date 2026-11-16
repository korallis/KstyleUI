local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	return Hud.Build({ layout = "DPS", class = "WARLOCK", vehicle = true })
end)
