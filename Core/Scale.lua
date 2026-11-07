-- Scale.lua: the KstyleUI_Root canvas and the whole-physical-pixel maths.
local _, ns = ...

local Scale = {}
ns.Scale = Scale

local floor, max, min = math.floor, math.max, math.min

local REFERENCE_HEIGHT = 1080 -- the root is this many units tall at a size of 1
local UI_HEIGHT = 768 -- the screen is this many units tall at an effective scale of 1
local REFERENCE_SCALE = UI_HEIGHT / REFERENCE_HEIGHT
local MIN_USER_SCALE, MAX_USER_SCALE = 0.75, 1.5
Scale.MIN_USER_SCALE, Scale.MAX_USER_SCALE = MIN_USER_SCALE, MAX_USER_SCALE

local state = {
	user = 1, -- the size slider
	pixel = 1, -- root units per physical pixel, as applied
	borderPixels = 1,
	applied = {}, -- the physical height, UIParent scale and size last applied
	waiting = false, -- a rescale waits for combat to end
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

-- Sets the root's scale so it is REFERENCE_HEIGHT / size units tall, then recomputes the pixel size.
-- Fires ScaleChanged when the screen, the UI scale or the size changed since the last call.
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

-- Applies now, or once combat ends: secure frames on the root make SetScale protected in combat.
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
		-- Login is the one time protected setup may run in combat, after a reload.
		Apply()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ApplyWaiting()
	else
		Request(event)
		-- The engine may settle the new size a frame later.
		C_Timer.After(0, Recheck)
	end
end)

-- Root() -> KstyleUI_Root, the canvas every KstyleUI frame sits on.
function Scale.Root()
	return root
end

-- Pixel(n) -> the root units of n whole physical pixels.
function Scale.Pixel(n)
	return (n or 1) * state.pixel
end

-- Border() -> the thickness of every border line: about one unit, in whole physical pixels.
function Scale.Border()
	return state.borderPixels * state.pixel
end

-- Snap(units) -> units rounded to the nearest whole physical pixel.
function Scale.Snap(units)
	return floor(units / state.pixel + 0.5) * state.pixel
end

function Scale.UserScale()
	return state.user
end

-- SetUserScale(size) -> ok. The size is clamped to 0.75 .. 1.5.
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
