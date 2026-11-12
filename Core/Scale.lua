-- Scale.lua: the KstyleUI_Root canvas (the whole screen, or a centred band on a screen wider than the HUD width setting allows) and the whole-physical-pixel maths.
local _, ns = ...

local Scale = {}
ns.Scale = Scale

local floor, max, min = math.floor, math.max, math.min

local REFERENCE_HEIGHT = 1080
local UI_HEIGHT = 768
local REFERENCE_SCALE = UI_HEIGHT / REFERENCE_HEIGHT
local MIN_USER_SCALE, MAX_USER_SCALE = 0.6, 1.5
local DEFAULT_USER_SCALE = 16 / 19
local CANVAS = { ["21:9"] = 12 / 5, ["16:9"] = 16 / 9, full = false }
local DEFAULT_CANVAS = "21:9"
Scale.MIN_USER_SCALE, Scale.MAX_USER_SCALE = MIN_USER_SCALE, MAX_USER_SCALE
Scale.DEFAULT_USER_SCALE = DEFAULT_USER_SCALE
Scale.CANVAS, Scale.DEFAULT_CANVAS = CANVAS, DEFAULT_CANVAS

local state = {
	user = DEFAULT_USER_SCALE,
	maximum = MAX_USER_SCALE,
	effectiveUser = DEFAULT_USER_SCALE,
	pixel = 1,
	canvas = 0,
	origin = 0,
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
	return type(v) == "number" and v == v and v > 0 and v < math.huge
end

local root = CreateFrame("Frame", "KstyleUI_Root", UIParent)
root:SetAllPoints(UIParent)

local function PhysicalSize()
	local width, height
	if type(GetPhysicalScreenSize) == "function" then
		width, height = GetPhysicalScreenSize()
	end
	if IsPositive(height) then
		return IsPositive(width) and width or 0, height
	end
	Log("GetPhysicalScreenSize gave no usable height; using " .. REFERENCE_HEIGHT)
	return 0, REFERENCE_HEIGHT
end

local function ParentScale()
	local s = UIParent:GetEffectiveScale()
	if IsPositive(s) then
		return s
	end
	return 1
end

local function CanvasSetting()
	local store = ns.Store
	local value = store and store.IsLoaded() and store.Module("Layout").canvas
	if CANVAS[value] ~= nil then
		return value
	end
	return DEFAULT_CANVAS
end

-- CanvasWidth(width, height) -> the physical width the HUD spreads over: the screen's, or on a screen wider than the
-- HUD width setting allows a centred band that wide, an even number of pixels narrower so it starts on a whole pixel.
local function CanvasWidth(width, height)
	local aspect = CANVAS[CanvasSetting()]
	if not aspect or not IsPositive(width) or width <= height * aspect then
		return width
	end
	local canvas = floor(height * aspect + 0.5)
	if (width - canvas) % 2 == 1 then
		canvas = canvas + 1
	end
	return canvas
end

Scale.CanvasWidth = CanvasWidth

local function Limit(width, height)
	local layouts = ns.Setup and ns.Setup.Layouts
	if not (layouts and layouts.ScaleLimit) then
		return MAX_USER_SCALE
	end
	local store = ns.Store
	local preset = store and store.IsLoaded() and store.Module("Layout").preset or "DPS"
	local enabled = layouts.Enabled(preset, store and store.IsLoaded() and store.Profile() or nil)
	return layouts.ScaleLimit(width, height, preset, enabled), enabled
end

local function Apply()
	local screen, height = PhysicalSize()
	local width = CanvasWidth(screen, height)
	local parent, user = ParentScale(), state.user
	local maximum, enabled = Limit(width, height)
	local effectiveUser = min(user, maximum)
	local added = false
	if state.enabled and enabled then
		for _, element in ipairs(ns.Setup.Layouts.ELEMENTS) do
			if enabled[element.key] and not state.enabled[element.key] then
				added = true
				break
			end
		end
	end
	state.enabled = enabled
	local last = state.applied
	if last[1] == height and last[2] == parent and last[3] == user and last[4] == width and last[5] == maximum and last[6] == screen then
		return
	end
	local previous = state.effectiveUser
	root:SetScale(REFERENCE_SCALE / parent * effectiveUser)
	state.maximum, state.effectiveUser = maximum, effectiveUser
	last[1], last[2], last[3], last[4], last[5], last[6] = height, parent, user, width, maximum, screen
	local effective = root:GetEffectiveScale()
	if not IsPositive(effective) then
		effective = REFERENCE_SCALE * effectiveUser
	end
	state.pixel = UI_HEIGHT / (height * effective)
	state.borderPixels = max(1, floor(1 / state.pixel + 0.5))
	state.canvas = width
	state.origin = (screen - width) / 2 * state.pixel
	root:ClearAllPoints()
	if width < screen then
		root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", state.origin, 0)
		root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -state.origin, 0)
		Log(string.format("the HUD spreads over a centred %d px of the %d px screen (HUD width %s)", width, screen, CanvasSetting()))
	else
		root:SetAllPoints(UIParent)
	end
	Fire("ScaleChanged")
	if added and user > maximum and effectiveUser < previous - 1e-9 then
		ns.Print(string.format(ns.L["HUD resized to %.1f%% to keep enabled elements on screen and apart."], effectiveUser * 100))
	end
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

function Scale.Origin()
	return state.origin
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

function Scale.AppliedUserScale()
	return state.effectiveUser
end

function Scale.MaxUserScale()
	return state.maximum
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

ns.Callbacks.Register("SettingChanged", "Scale", function(_, module, key)
	if module == "Layout" and key == "preset" then
		Request("the layout preset")
	elseif module == "Layout" and key == "canvas" then
		Request("the HUD width")
	elseif ns.Features.modules[module] ~= nil then
		Request("an element setting")
	end
end)
ns.Callbacks.Register("ModuleChanged", "Scale", function()
	Request("a module switch")
end)
ns.Callbacks.Register("ProfileChanged", "Scale", function()
	if ns.Appearance then
		Scale.SetUserScale(ns.Appearance.Get("uiScale"))
	end
	Request("the profile")
end)

Apply()
