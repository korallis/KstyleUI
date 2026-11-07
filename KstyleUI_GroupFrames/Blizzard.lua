-- Blizzard.lua: hides Blizzard's party frames, compact raid frames and raid manager through KstyleUI.Safe while the module runs, and gives them back.
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

local function Log(message)
	K.DevTest.Log(ns.Settings.MODULE, message)
end

function Blizzard.Apply(running)
	local wanted = ns.Settings.current.blizzard
	for _, item in ipairs(FRAMES) do
		local frame = item.get()
		if frame == nil then
			if not missing[item.label] then
				missing[item.label] = true
				Log(item.label .. " is not loaded yet; it is hidden when it loads")
			end
		elseif running and wanted[item.setting] then
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
