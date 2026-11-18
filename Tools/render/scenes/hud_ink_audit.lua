-- hud_ink_audit.lua: the reference HUD with a long cast label and a low-health figure for the ink audit.
local Common = dofile("Tools/render/scenes/_common.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
Reference.STATE.spec.cast[1] = "Terrifying Screech"
Reference.STATE.target.cast.name = "Terrifying Screech"
Reference.STATE.player.health = 70
return Common.Run(function()
	return Reference.Build({ layout = "DPS" })
end)
