-- Scale.lua: the KstyleUI_Root canvas and the whole-physical-pixel maths.
local _, ns = ...

local Scale = {}
ns.Scale = Scale

local floor, max, min = math.floor, math.max, math.min

local REFERENCE_HEIGHT = 1080
local UI_HEIGHT = 768
local REFERENCE_SCALE = UI_HEIGHT / REFERENCE_HEIGHT
local MIN_USER_SCALE, MAX_USER_SCALE = 0.75, 1.5
Scale.MIN_USER_SCALE, Scale.MAX_USER_SCALE = MIN_USER_SCALE, MAX_USER_SCALE

local state = {
	user = 1,
	pixel = 1,
	borderPixels = 1,
	applied = {},
	waiting = false,
}

local function Fire(event, ...)
	local callbacks = ns.Callbacks
	if callbacks and callbacks.Fire then
		callbacks.Fire(event, ...)
	end
end

local function Log(message)
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, "Scale", message)
	end
end

local function IsPositive(v)
	if issecretvalue and issecretvalue(v) then
		return false
	end
	return type(v) == "number" and v == v and v > 0
end

local root = CreateFrame("Frame", "KstyleUI_Root", UIParent)
root:SetAllPoints(UIParent)

local function PhysicalHeight()
	local _, height = GetPhysicalScreenSize()
	if IsPositive(height) then
		return height
	end
	Log("GetPhysicalScreenSize gave no usable height; using " .. REFERENCE_HEIGHT)
	return REFERENCE_HEIGHT
end

local function ParentScale()
	local s = UIParent:GetEffectiveScale()
	if IsPositive(s) then
		return s
	end
	return 1
end

local function Apply()
	local height, parent, user = PhysicalHeight(), ParentScale(), state.user
	local last = state.applied
	if last[1] == height and last[2] == parent and last[3] == user then
		return
	end
	root:SetScale(REFERENCE_SCALE / parent * user)
	last[1], last[2], last[3] = height, parent, user
	local effective = root:GetEffectiveScale()
	if not IsPositive(effective) then
		effective = REFERENCE_SCALE * user
	end
	state.pixel = UI_HEIGHT / (height * effective)
	state.borderPixels = max(1, floor(1 / state.pixel + 0.5))
	Fire("ScaleChanged")
end

local events = CreateFrame("Frame")

local function ApplyWaiting()
	state.waiting = false
	events:UnregisterEvent("PLAYER_REGEN_ENABLED")
	Apply()
end

local function Request(reason)
	if not InCombatLockdown() then
		Apply()
		return
	end
	if state.waiting then
		return
	end
	state.waiting = true
	Log("rescale for " .. reason .. " waits for combat to end")
	local combat = ns.Combat
	if combat and combat.Queue then
		combat.Queue(ApplyWaiting)
	else
		events:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
end

local function Recheck()
	Request("a late display change")
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		Apply()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ApplyWaiting()
	else
		Request(event)
		C_Timer.After(0, Recheck)
	end
end)

function Scale.Root()
	return root
end

function Scale.Pixel(n)
	return (n or 1) * state.pixel
end

function Scale.Border()
	return state.borderPixels * state.pixel
end

function Scale.Snap(units)
	return floor(units / state.pixel + 0.5) * state.pixel
end

function Scale.UserScale()
	return state.user
end

function Scale.SetUserScale(size)
	if not IsPositive(size) then
		return false
	end
	size = min(MAX_USER_SCALE, max(MIN_USER_SCALE, size))
	if size ~= state.user then
		state.user = size
		Request("the size setting")
	end
	return true
end

Apply()
