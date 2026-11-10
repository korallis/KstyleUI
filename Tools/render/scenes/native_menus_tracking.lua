-- native_menus_tracking.lua: KstyleUI's tracking menu through the native menu fixture, in the material RENDER_MATERIAL names; see _native_menus.lua.
local Common = dofile("Tools/render/scenes/_common.lua")
local Native = dofile("Tools/render/scenes/_native_menus.lua")

return Common.Run(function()
	return Native.Scene("tracking")
end)
