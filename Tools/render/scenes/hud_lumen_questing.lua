-- hud_lumen_questing.lua: the Lumen Rails HUD out of combat, as the mockup's questing board: three quests and the RestedXP guide in the story slot, a party of three, the last fight's damage, every card lit.
local Common = dofile("Tools/render/scenes/_common.lua")
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

return Common.Run(function()
	return Lumen.Build("questing")
end)
