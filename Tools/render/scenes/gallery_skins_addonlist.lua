-- gallery_skins_addonlist.lua: one window of the skins gallery, built and skinned by _skins.lua; see Tools/render/README.md.
local Common = dofile("Tools/render/scenes/_common.lua")
local Skins = dofile("Tools/render/scenes/_skins.lua")

return Common.Run(function()
	return Skins.Scene("addonlist")
end)
