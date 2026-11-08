-- auras_tracker.lua: the screen's top right at a buff count: the minimap, the aura rows beside it with RENDER_BUFFS
-- buffs (10 when unset) and three debuffs, and the objective tracker where Forever's Edit Mode preset puts it, so a
-- render shows the rows never reach the tracker whatever the count.
--
--   RENDER_BUFFS=16 Tools/render/shoot.sh auras_tracker --backdrop
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local DEFAULT_BUFFS, DEBUFFS = 10, 3

return Common.Run(function()
	local count = tonumber(os.getenv("RENDER_BUFFS")) or DEFAULT_BUFFS
	return Hud.Build({ layout = "DPS", modules = { "minimap", "auras", "tracker" }, buffs = count, debuffs = DEBUFFS })
end)
