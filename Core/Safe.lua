-- Safe.lua: taint-safe helpers: hide Blizzard frames by reparenting, and weak-keyed per-frame side tables.
local _, ns = ...

local Safe = {}
ns.Safe = Safe

local WEAK = { __mode = "k" }
local wanted = setmetatable({}, WEAK)
local hidden = setmetatable({}, WEAK)
local originals = setmetatable({}, WEAK)
local waiting = setmetatable({}, WEAK)
local side = setmetatable({}, WEAK)
local hiddenParent
local listening = false
local schedule

local function log(message)
	ns.DevTest.Log("Safe", message)
end

local function caller()
	if debugstack then
		local line = debugstack(3, 1, 0)
		if type(line) == "string" then
			return " (" .. line:gsub("%s+$", "") .. ")"
		end
	end
	return ""
end

local function onEditModeExit()
	if EventRegistry and EventRegistry.UnregisterCallback then
		EventRegistry:UnregisterCallback("EditMode.Exit", Safe)
	end
	listening = false
	for frame in pairs(waiting) do
		waiting[frame] = nil
		schedule(frame)
	end
end

local function waitForEditMode(frame)
	waiting[frame] = true
	if listening then
		return
	end
	if EventRegistry and EventRegistry.RegisterCallback then
		listening = true
		EventRegistry:RegisterCallback("EditMode.Exit", onEditModeExit, Safe)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(1, onEditModeExit)
		log("EventRegistry missing; polling for the end of Edit Mode")
	end
end

local function editModeOpen()
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
		return true
	end
	return EditModeManagerFrame ~= nil and EditModeManagerFrame.IsEditModeActive ~= nil and EditModeManagerFrame:IsEditModeActive() == true
end

local function apply(frame)
	local want = wanted[frame]
	if not want then
		return
	end
	if InCombatLockdown() then
		ns.Combat.Queue(function()
			apply(frame)
		end)
		return
	end
	if editModeOpen() then
		waitForEditMode(frame)
		return
	end
	wanted[frame] = nil
	if want == "hide" and not hidden[frame] then
		originals[frame] = frame:GetParent()
		frame:SetParent(hiddenParent)
		hidden[frame] = true
	elseif want == "restore" and hidden[frame] then
		frame:SetParent(originals[frame])
		hidden[frame], originals[frame] = nil, nil
	end
end

function schedule(frame)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			apply(frame)
		end)
	else
		apply(frame)
	end
end

local function isFrame(frame)
	return type(frame) == "table" and type(frame.SetParent) == "function" and type(frame.GetParent) == "function"
end

function Safe.HideBlizzard(frame)
	if frame == nil then
		log("HideBlizzard: frame missing on this client; skipped" .. caller())
		return
	end
	if not isFrame(frame) then
		error("KstyleUI.Safe.HideBlizzard: expected a frame, got " .. type(frame), 2)
	end
	if hidden[frame] and wanted[frame] == nil then
		return
	end
	if not hiddenParent then
		hiddenParent = CreateFrame("Frame")
		hiddenParent:Hide()
	end
	wanted[frame] = "hide"
	schedule(frame)
end

function Safe.RestoreBlizzard(frame)
	if frame == nil then
		return
	end
	if not isFrame(frame) then
		error("KstyleUI.Safe.RestoreBlizzard: expected a frame, got " .. type(frame), 2)
	end
	if not hidden[frame] and wanted[frame] == nil then
		return
	end
	wanted[frame] = "restore"
	schedule(frame)
end

function Safe.IsHidden(frame)
	return hidden[frame] == true
end

function Safe.Side(frame)
	if type(frame) ~= "table" then
		error("KstyleUI.Safe.Side: expected a frame, got " .. type(frame), 2)
	end
	local state = side[frame]
	if not state then
		state = {}
		side[frame] = state
	end
	return state
end
