-- Windows.lua: finds Blizzard's chat windows, now and as the game opens new ones, and hands each to the chat's parts once.
local _, ns = ...

local K = KstyleUI

local Windows = {}
ns.Windows = Windows

local WEAK = { __mode = "k" }
local watchers = {}
local hooked = false

local function Log(message)
	K.DevTest.Log(ns.NAME, message)
end

function Windows.List()
	local out = {}
	local names = CHAT_FRAMES
	if type(names) ~= "table" then
		return out
	end
	for _, name in ipairs(names) do
		local frame = type(name) == "string" and _G[name] or nil
		if type(frame) == "table" then
			out[#out + 1] = frame
		end
	end
	return out
end

function Windows.Scan()
	local frames = Windows.List()
	for _, watcher in ipairs(watchers) do
		for _, frame in ipairs(frames) do
			if not watcher.seen[frame] then
				watcher.seen[frame] = true
				K.Call(watcher.fn, frame)
			end
		end
	end
end

function Windows.Watch(fn)
	watchers[#watchers + 1] = { fn = fn, seen = setmetatable({}, WEAK) }
	if not hooked then
		hooked = true
		if type(FCF_OpenTemporaryWindow) == "function" then
			hooksecurefunc("FCF_OpenTemporaryWindow", Windows.Scan)
		else
			Log("FCF_OpenTemporaryWindow is missing; whisper windows opened later are found on UPDATE_CHAT_WINDOWS")
		end
	end
	Windows.Scan()
end

function Windows.IsCombatLog(frame)
	return type(IsCombatLog) == "function" and IsCombatLog(frame) == true
end
