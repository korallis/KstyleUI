-- auras_tracker.lua: the Lumen rails at a buff count: the lens card, the Blessings under it with RENDER_BUFFS buffs
-- (10 when unset) and three debuffs, and the objective tracker where the setup asks the player to move it, the left
-- rail's story slot, so a render shows the rows and the tracker apart whatever the count.
--
--   RENDER_BUFFS=16 Tools/render/shoot.sh auras_tracker --backdrop
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

local DEFAULT_BUFFS, DEBUFFS = 10, 3

return Common.Run(function()
	local count = tonumber(os.getenv("RENDER_BUFFS")) or DEFAULT_BUFFS
	local _, slot = Lumen.Preset("DPS")
	return Hud.Build({ layout = "DPS", modules = { "minimap", "auras", "tracker" }, buffs = count, debuffs = DEBUFFS, trackerAt = { slot.left + 36, slot.top } })
end)
