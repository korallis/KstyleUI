-- buttons_mac.lua: every square icon button on the owner's Mac, with the micro menu and bag bar at the full rim.
local Common = dofile("Tools/render/scenes/_common.lua")
local Buttons = dofile("Tools/render/scenes/buttons.lua")

return Common.Run(function()
	return Buttons.Build({ rim = 1 })
end)
