-- Blizzard.lua: hides Blizzard's party frames, compact raid frames and raid manager through KstyleUI.Safe while the module runs, gives them back, and tells when the gamepad interface is on.
local _, ns = ...

local K = KstyleUI

local Blizzard = {}
ns.Blizzard = Blizzard

local FRAMES = {
	{ setting = "party", label = "PartyFrame", get = function()
		return PartyFrame
	end },
	{ setting = "raid", label = "CompactRaidFrameContainer", get = function()
		return CompactRaidFrameContainer
	end },
	{ setting = "manager", label = "CompactRaidFrameManager", get = function()
		return CompactRaidFrameManager
	end },
}

local missing = {}
local hidden = {}
local logged = {}

local issecretvalue = issecretvalue or function()
	return false
end

local function Log(message)
	K.DevTest.Log(ns.Settings.MODULE, message)
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function FromInputUtil()
	local input = InputUtil
	if type(input) ~= "table" or type(input.IsGamepadUIEnabled) ~= "function" then
		return nil
	end
	local ok, enabled = pcall(input.IsGamepadUIEnabled)
	if ok and not issecretvalue(enabled) and type(enabled) == "boolean" then
		return enabled
	end
	LogOnce("styleInputUtil", "InputUtil.IsGamepadUIEnabled gave no plain answer")
	return nil
end

local function FromStyle()
	local style = C_InputInterfaceStyle
	local types = Enum and Enum.InputDeviceInterfaceType
	if type(style) ~= "table" or type(style.GetCurrentStyle) ~= "function" or type(types) ~= "table" or types.Gamepad == nil then
		return nil
	end
	local ok, current = pcall(style.GetCurrentStyle)
	if ok and not issecretvalue(current) and current ~= nil then
		return current == types.Gamepad
	end
	LogOnce("styleCurrent", "C_InputInterfaceStyle.GetCurrentStyle gave no plain answer")
	return nil
end

function Blizzard.GamepadStyle()
	local gamepad = FromInputUtil()
	if gamepad ~= nil then
		LogOnce("styleFromInputUtil", "the interface style comes from InputUtil.IsGamepadUIEnabled")
		return gamepad
	end
	gamepad = FromStyle()
	if gamepad ~= nil then
		LogOnce("styleFromStyle", "the interface style comes from C_InputInterfaceStyle.GetCurrentStyle")
		return gamepad
	end
	LogOnce("styleNone", "the interface style is unknown; group frames assume keyboard and mouse")
	return false
end

function Blizzard.Apply(active)
	local wanted = ns.Settings.current.blizzard
	for _, item in ipairs(FRAMES) do
		local frame = item.get()
		if frame == nil then
			if not missing[item.label] then
				missing[item.label] = true
				Log(item.label .. " is not loaded yet; it is hidden when it loads")
			end
		elseif active and wanted[item.setting] then
			if not hidden[item.label] then
				hidden[item.label] = true
				K.Safe.HideBlizzard(frame)
				Log("hid " .. item.label .. " through Safe.HideBlizzard")
			end
		elseif hidden[item.label] then
			hidden[item.label] = nil
			K.Safe.RestoreBlizzard(frame)
			Log("gave " .. item.label .. " back through Safe.RestoreBlizzard")
		end
	end
end
