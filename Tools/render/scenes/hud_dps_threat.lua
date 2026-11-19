-- hud_dps_threat.lua: the DPS HUD with the optional compact threat card enabled alongside the damage card.
local Common = dofile("Tools/render/scenes/_common.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

return Common.Run(function()
	return Reference.Build({ layout = os.getenv("RENDER_LAYOUT") or "DPS", meterChoice = "both", meterGroup = "party", meterSecret = true })
end)
