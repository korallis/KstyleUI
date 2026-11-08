-- tooltip_design.lua: the design file's item tooltip on the Tooltips glass, at the sheet's position, so a crop at
-- 2 px per unit lands on the design file's own crop.
local Common = dofile("Tools/render/scenes/_common.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")

return Common.Run(function()
	return Tooltip.Build()
end)
