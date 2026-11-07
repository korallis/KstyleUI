-- World.lua: the game's own damage numbers: DAMAGE_TEXT_FONT, which the game reads at login, set to the chosen KstyleUI font.
local _, ns = ...

local K = KstyleUI

local World = {}
ns.World = World

local original

local function Log(message)
	K.DevTest.Log("CombatText", message)
end

function World.Capture()
	if original == nil then
		local current = DAMAGE_TEXT_FONT
		original = type(current) == "string" and current or false
	end
end

function World.Restore()
	if original and DAMAGE_TEXT_FONT ~= original then
		DAMAGE_TEXT_FONT = original
		Log("DAMAGE_TEXT_FONT is back to " .. original .. " from the next login")
		return true
	end
	return false
end

function World.Apply(cfg)
	if not cfg.worldFont then
		return World.Restore()
	end
	local path = cfg.worldFace
	if DAMAGE_TEXT_FONT == path then
		return false
	end
	DAMAGE_TEXT_FONT = path
	Log("DAMAGE_TEXT_FONT is " .. path .. "; the game reads it at the next login")
	return true
end

function World.Current()
	return DAMAGE_TEXT_FONT
end
