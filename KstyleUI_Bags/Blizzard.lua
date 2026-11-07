-- Blizzard.lua: follows Blizzard's bag functions through secure hooks, keeps Blizzard's bag frames under a hidden parent, and stands down for the gamepad style.
local _, ns = ...

local K = KstyleUI

local Blizzard = {}
ns.Blizzard = Blizzard

local HOOKS = {
	{ "ToggleAllBags", "toggle" },
	{ "ToggleBackpack", "toggle" },
	{ "ToggleBag", "toggle" },
	{ "OpenAllBags", "open" },
	{ "OpenBackpack", "open" },
	{ "OpenBag", "open" },
	{ "CloseAllBags", "close" },
	{ "CloseBackpack", "close" },
	{ "CloseBag", "close" },
}
local FALLBACK_CONTAINER_FRAMES = 13

local installed = false
local active = false
local pending
local scheduled = false
local handlers = {}

local function IsTrue(value)
	return not ns.Data.IsSecret(value) and value == true
end

function Blizzard.GamepadStyle()
	local input = InputUtil
	if type(input) ~= "table" or type(input.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, enabled = pcall(input.IsGamepadUIEnabled)
	return ok and IsTrue(enabled)
end

local function ContainerFrames()
	local count = ns.Data.Plain(NUM_CONTAINER_FRAMES, "number") or FALLBACK_CONTAINER_FRAMES
	return count
end

function Blizzard.AnyOpen()
	local combined = ContainerFrameCombinedBags
	if combined and IsTrue(combined:IsShown()) then
		return true
	end
	for i = 1, ContainerFrames() do
		local frame = _G["ContainerFrame" .. i]
		if frame and IsTrue(frame:IsShown()) then
			return true
		end
	end
	return false
end

function Blizzard.MayOpen()
	local allowed = ContainerFrame_AllowedToOpenBags
	if type(allowed) ~= "function" then
		return true
	end
	local ok, result = pcall(allowed)
	if not ok or ns.Data.IsSecret(result) then
		return true
	end
	return result == true
end

local function Stale(frame)
	return frame ~= nil and IsTrue(frame:IsShown()) and not IsTrue(frame:IsVisible())
end

function Blizzard.Release()
	local combined = ContainerFrameCombinedBags
	if Stale(combined) then
		combined:Hide()
	end
	for i = 1, ContainerFrames() do
		local frame = _G["ContainerFrame" .. i]
		if Stale(frame) then
			frame:Hide()
		end
	end
end

local function Flush()
	scheduled = false
	local action = pending
	pending = nil
	if not active or not action then
		return
	end
	local handler = handlers[action]
	if handler then
		K.Call(handler, Blizzard.AnyOpen())
	end
end

local function Request(action)
	if not active then
		return
	end
	pending = action
	if scheduled then
		return
	end
	scheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Flush)
	else
		Flush()
	end
end

local function Install()
	if installed then
		return
	end
	installed = true
	for _, hook in ipairs(HOOKS) do
		local name, action = hook[1], hook[2]
		if type(_G[name]) == "function" then
			hooksecurefunc(name, function()
				Request(action)
			end)
		else
			ns.Log(name .. " is missing; the bag window does not follow it")
		end
	end
end

function Blizzard.OnAction(action, fn)
	handlers[action] = fn
end

function Blizzard.Start()
	if active then
		return true
	end
	if Blizzard.GamepadStyle() then
		ns.Log("the gamepad interface style is on; Blizzard's bags stay, because its D-pad navigates them")
		return false
	end
	Install()
	active = true
	K.Safe.HideBlizzard(ContainerFrameCombinedBags)
	K.Safe.HideBlizzard(ContainerFrameContainer)
	return true
end

function Blizzard.Stop()
	pending = nil
	if not active then
		return
	end
	active = false
	Blizzard.Release()
	K.Safe.RestoreBlizzard(ContainerFrameCombinedBags)
	K.Safe.RestoreBlizzard(ContainerFrameContainer)
end

function Blizzard.IsActive()
	return active
end
