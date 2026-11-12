-- hud_reference.lua: staging's code in the state of the owner's reference picture of 2026-11-09, on his 3456 by 2234 screen (_reference.lua).
local Common = dofile("Tools/render/scenes/_common.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

return Common.Run(function()
	return Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS", meterSecret = os.getenv("RENDER_METER_SECRET") == "1" })
end)
