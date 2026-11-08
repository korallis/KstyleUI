-- hud_dps_mac.lua: the whole HUD in the DPS layout on the owner's Mac, every module in its mockup state, for the class RENDER_CLASS names (shoot.sh --class; the mockup's warrior when unset).
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	return Hud.Build({ layout = "DPS" })
end)
