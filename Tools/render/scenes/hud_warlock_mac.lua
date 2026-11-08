-- hud_warlock_mac.lua: the whole HUD in the DPS layout on the owner's Mac for a warlock (Warlock in _classes.lua), every module in its mockup state.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	return Hud.Build({ layout = "DPS", class = "WARLOCK" })
end)
