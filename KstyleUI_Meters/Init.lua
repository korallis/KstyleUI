-- Init.lua: the KstyleUI_Meters addon table, which the module's files share, and the helper that places a meter with Layout.
local addonName, ns = ...

ns.addonName = addonName

local K = KstyleUI

function ns.Footprint(key)
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element(key)
	if element then
		return element.width, element.height, element.label
	end
	return nil
end

function ns.Place(frame, key, limits)
	local layouts = K.Setup and K.Setup.Layouts
	if not (K.Layout and K.Layout.Register and layouts) then
		ns.LogOnce("noLayout:" .. key, key .. " stays where it was built: the Layout service is missing")
		return
	end
	local _, _, label = ns.Footprint(key)
	K.Layout.Register(frame, key, layouts.Default(key), {
		label = label or key,
		module = ns.MODULE,
		resizable = true,
		minWidth = limits.minWidth,
		maxWidth = limits.maxWidth,
		minHeight = limits.minHeight,
		maxHeight = limits.maxHeight,
	})
end
