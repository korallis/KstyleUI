-- Blizzard.lua: hides and restores Blizzard's keyboard action bars through Safe, and tells when the gamepad interface is active.
local _, ns = ...

local K = KstyleUI

function ns.IsGamepad()
	local style = C_InputInterfaceStyle
	local types = Enum and Enum.InputDeviceInterfaceType
	if not (style and type(style.GetCurrentStyle) == "function" and types and types.Gamepad ~= nil) then
		return false
	end
	local current = style.GetCurrentStyle()
	if ns.IsSecret(current) then
		return false
	end
	return current == types.Gamepad
end

function ns.HideBlizzard()
	for _, name in ipairs(ns.BLIZZARD_BARS) do
		K.Safe.HideBlizzard(_G[name])
	end
end

function ns.RestoreBlizzard()
	for _, name in ipairs(ns.BLIZZARD_BARS) do
		K.Safe.RestoreBlizzard(_G[name])
	end
end
