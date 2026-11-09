-- hud_lumen_combat.lua: the Lumen Rails HUD in combat, as the mockup's combat board: a party of five, the boss card, the boss as the target with its cast on the sigil, and the slow cards calmed to 30%.
local Common = dofile("Tools/render/scenes/_common.lua")
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

return Common.Run(function()
	return Lumen.Build("combat")
end)
