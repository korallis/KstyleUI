-- Viewers.lua: Blizzard's Cooldown Manager viewers, faded to alpha 0 while KstyleUI mirrors them and never moved or hidden.
local _, ns = ...

local K = KstyleUI

local Viewers = {}
ns.Viewers = Viewers

local NAMES = {
	essential = "EssentialCooldownViewer",
	utility = "UtilityCooldownViewer",
	buffs = "BuffIconCooldownViewer",
	bars = "BuffBarCooldownViewer",
}
Viewers.NAMES = NAMES

function Viewers.Frame(group)
	local name = NAMES[group]
	local frame = name and _G[name]
	if type(frame) == "table" and type(frame.GetObjectType) == "function" then
		return frame
	end
	return nil
end

local function State(frame)
	local side = K.Safe.Side(frame)
	local state = side.cooldowns
	if not state then
		state = {}
		side.cooldowns = state
	end
	return state
end

local function IsItem(child)
	return type(child) == "table" and type(child.GetCooldownID) == "function" and type(child.SetMouseMotionEnabled) == "function"
end

local function SetItemsMouse(frame, enabled)
	for _, child in ipairs({ frame:GetChildren() }) do
		if IsItem(child) then
			child:SetMouseMotionEnabled(enabled)
		end
	end
end

local function TooltipsShown(frame)
	return frame.tooltipsShown ~= false
end

local function SetOwnAlpha(frame, state, alpha)
	state.busy = true
	frame:SetAlpha(alpha)
	state.busy = false
end

local function Refade(frame, alpha)
	local state = State(frame)
	if state.busy then
		return
	end
	if type(alpha) == "number" and not ns.IsSecret(alpha) then
		state.wanted = alpha
	end
	if state.faded then
		SetOwnAlpha(frame, state, 0)
	end
end

local function OnAcquire(frame, item)
	if State(frame).faded and IsItem(item) then
		item:SetMouseMotionEnabled(false)
	end
end

local function OnTooltips(frame)
	if State(frame).faded then
		SetItemsMouse(frame, false)
	end
end

local function Hook(frame, state)
	if state.hooked then
		return
	end
	state.hooked = true
	hooksecurefunc(frame, "SetAlpha", Refade)
	if type(frame.OnAcquireItemFrame) == "function" then
		hooksecurefunc(frame, "OnAcquireItemFrame", OnAcquire)
	end
	if type(frame.SetTooltipsShown) == "function" then
		hooksecurefunc(frame, "SetTooltipsShown", OnTooltips)
	end
end

function Viewers.Fade(group)
	local frame = Viewers.Frame(group)
	if not frame then
		ns.LogOnce("viewer-missing-" .. group, NAMES[group] .. " is missing; nothing to fade")
		return false
	end
	local state = State(frame)
	if state.faded then
		return true
	end
	Hook(frame, state)
	if not state.wanted then
		local alpha = frame:GetAlpha()
		state.wanted = (type(alpha) == "number" and not ns.IsSecret(alpha)) and alpha or 1
	end
	state.faded = true
	SetOwnAlpha(frame, state, 0)
	SetItemsMouse(frame, false)
	ns.Log("faded " .. NAMES[group] .. " while KstyleUI shows the " .. group .. " group")
	return true
end

function Viewers.Unfade(group)
	local frame = Viewers.Frame(group)
	if not frame then
		return false
	end
	local state = State(frame)
	if not state.faded then
		return true
	end
	state.faded = false
	SetOwnAlpha(frame, state, state.wanted or 1)
	SetItemsMouse(frame, TooltipsShown(frame))
	ns.Log("restored " .. NAMES[group])
	return true
end

function Viewers.IsFaded(group)
	local frame = Viewers.Frame(group)
	return frame ~= nil and State(frame).faded == true
end
