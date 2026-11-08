-- buttons_toned.lua: the same scene as buttons_mac with the micro menu and bag bar rims toned to half strength.
local Common = dofile("Tools/render/scenes/_common.lua")
local Buttons = dofile("Tools/render/scenes/buttons.lua")

return Common.Run(function()
	return Buttons.Build({ rim = 0.5 })
end)
