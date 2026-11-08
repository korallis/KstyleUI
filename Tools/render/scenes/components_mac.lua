-- components_mac.lua: the component sheet, every kit widget in the design file's sections.
local Common = dofile("Tools/render/scenes/_common.lua")
local Components = dofile("Tools/render/scenes/components.lua")

return Common.Run(function()
	return Components.Build()
end)
