-- Blizzard.lua: hides and restores Blizzard's keyboard action bars through Safe, and tells when the gamepad interface is active.
local _, ns = ...

local K = KstyleUI

function ns.StylePossess()
	local frame = PossessActionBar
	if not (frame and frame.actionButtons) then return end
	K.Combat.Queue(function()
		if not ns.running then return end
		if not K.Layout.Element("actionbars.possess") then
			K.Layout.Register(frame, "actionbars.possess", K.Setup.Layouts.Default("actionbars.possess"), { label = K.L["Possess"], module = "ActionBars", fields = { "anchor", "x", "y" } })
		end
		for _, button in ipairs(frame.actionButtons) do
			if button.icon then
				local keep = { [button.icon] = true }
				if button.cooldown then keep[button.cooldown] = true end
				K.Skin.Strip(button, { keep = keep })
				K.Skin.Backdrop(button, { icon = true })
			end
		end
	end)
end

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
