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

function ns.SetLive(key, live)
	local Layout = K.Layout
	if Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(key, live and true or false)
	end
end

function ns.Place(frame, key, limits)
	local layouts = K.Setup and K.Setup.Layouts
	if not (K.Layout and K.Layout.Register and layouts) then
		ns.LogOnce("noLayout:" .. key, key .. " stays where it was built: the Layout service is missing")
		return
	end
	local width, _, label = ns.Footprint(key)
	local saved = K.Store.Layout()[key]
	if key == "meters.damage" and saved and saved.width == 269 and saved.height == 158 and not (saved.anchor or saved.x or saved.y) then
		saved.width = width
	end
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
