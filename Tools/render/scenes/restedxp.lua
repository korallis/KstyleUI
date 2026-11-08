-- restedxp.lua: the RestedXP windows the skin tests' fake builds, skinned by KstyleUI_Skins and laid out as
-- RestedXP lays them out in the game (scenes/_restedxp.lua): the active steps over the guide window (header,
-- step list, footer) at the screen's left edge, with the v2 guide window, the active item frame and the guide
-- configurator beside them.
local Common = dofile("Tools/render/scenes/_common.lua")
local RestedXP = dofile("Tools/render/scenes/_restedxp.lua")

return Common.Run(function()
	local R = RestedXP.Build()
	local scene = Common.Scene.Build(R.env)
	local err = Common.Errors(R.env, R.K)
	if err then
		scene.log[#scene.log + 1] = "restedxp error: " .. err
	end
	for _, line in ipairs(R.log) do
		scene.log[#scene.log + 1] = line
	end
	return scene
end)
