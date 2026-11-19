-- crest_travel.lua: the open Medallions travel menu; RENDER_TRAVEL selects mage, simple, before-mage or before-simple.
local Common = dofile("Tools/render/scenes/_common.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

return Common.Run(function()
	local mode = os.getenv("RENDER_TRAVEL") or "simple"
	rawset(_G, "RENDER_TRAVEL", mode)
	rawset(_G, "RENDER_HUD_STYLE", "Medallions")
	local scene = Reference.Build({ class = mode:find("mage", 1, true) and "MAGE" or "WARRIOR" })
	rawset(_G, "RENDER_TRAVEL", nil)
	return scene
end)
