-- Scale.lua: the KstyleUI_Root canvas (the whole screen, or under the Centred arrangement a centred band on a screen wider than the HUD width setting allows), its layout class (16:9, 21:9 or 32:9), the inset of that band under Spread, where group and boss frames stay, the automatic pixel-perfect size and the whole-physical-pixel maths.
local _, ns = ...

local Scale = {}
ns.Scale = Scale

local abs, ceil, floor, max, min = math.abs, math.ceil, math.floor, math.max, math.min

local REFERENCE_HEIGHT = 1080
local UI_HEIGHT = 768
local REFERENCE_SCALE = UI_HEIGHT / REFERENCE_HEIGHT
local MIN_USER_SCALE, MAX_USER_SCALE = 0.6, 1.5
local DEFAULT_USER_SCALE = 16 / 19
local STEPS_PER_PIXEL = 16
local WHOLE_BAND = 0.125
local CANVAS = { ["21:9"] = 12 / 5, ["16:9"] = 16 / 9, full = false }
local DEFAULT_CANVAS = "21:9"
local ARRANGEMENT = { centred = true, spread = true }
local DEFAULT_ARRANGEMENT = "centred"
local ASPECTS = { "16:9", "21:9", "32:9" }
local ASPECT_FROM = { ["21:9"] = 2.05, ["32:9"] = 2.9 }
Scale.MIN_USER_SCALE, Scale.MAX_USER_SCALE = MIN_USER_SCALE, MAX_USER_SCALE
Scale.DEFAULT_USER_SCALE = DEFAULT_USER_SCALE
Scale.STEPS_PER_PIXEL, Scale.WHOLE_BAND = STEPS_PER_PIXEL, WHOLE_BAND
Scale.CANVAS, Scale.DEFAULT_CANVAS = CANVAS, DEFAULT_CANVAS
Scale.ARRANGEMENT, Scale.DEFAULT_ARRANGEMENT = ARRANGEMENT, DEFAULT_ARRANGEMENT
Scale.ASPECTS, Scale.ASPECT_FROM = ASPECTS, ASPECT_FROM

local state = {
	user = DEFAULT_USER_SCALE,
	auto = true,
	maximum = MAX_USER_SCALE,
	effectiveUser = DEFAULT_USER_SCALE,
	height = REFERENCE_HEIGHT,
	pixel = 1,
	canvas = 0,
	origin = 0,
	band = 0,
	aspect = ASPECTS[1],
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

local function ArrangementSetting()
	local store = ns.Store
	local value = store and store.IsLoaded() and store.Module("Layout").arrangement
	if ARRANGEMENT[value] then
		return value
	end
	return DEFAULT_ARRANGEMENT
end

local function BandWidth(width, height)
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

local function CanvasWidth(width, height)
	if ArrangementSetting() == "spread" then
		return width
	end
	return BandWidth(width, height)
end

Scale.CanvasWidth = CanvasWidth

local function AspectClass(width, height)
	local class = ASPECTS[1]
	if IsPositive(width) and IsPositive(height) then
		for i = 2, #ASPECTS do
			if width / height >= ASPECT_FROM[ASPECTS[i]] then
				class = ASPECTS[i]
			end
		end
	end
	return class
end

Scale.AspectClass = AspectClass

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

local function Step(height)
	return REFERENCE_HEIGHT / (STEPS_PER_PIXEL * height)
end

local function Within(k, height, maximum)
	local step = Step(height)
	return max(ceil(MIN_USER_SCALE / step - 1e-9), min(k, floor(maximum / step + 1e-9)))
end

local function Nearest(size, height, maximum)
	local step = Step(height)
	return Within(floor(size / step + 0.5), height, maximum) * step
end

local function Auto(height, maximum)
	local today = height * DEFAULT_USER_SCALE / REFERENCE_HEIGHT
	local whole = max(1, floor(today + 0.5))
	local size = whole * REFERENCE_HEIGHT / height
	if abs(whole - today) <= WHOLE_BAND * today and size >= MIN_USER_SCALE - 1e-9 and size <= maximum + 1e-9 then
		return size
	end
	return Nearest(DEFAULT_USER_SCALE, height, maximum)
end

Scale.Nearest, Scale.Auto = Nearest, Auto

local function Apply()
	local screen, height = PhysicalSize()
	local width = CanvasWidth(screen, height)
	local parent, user, auto = ParentScale(), state.user, state.auto
	local maximum, enabled = Limit(width, height)
	local effectiveUser = auto and Scale.Auto(height, maximum) or Scale.Nearest(user, height, maximum)
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
	if last[1] == height and last[2] == parent and last[3] == user and last[4] == width and last[5] == maximum and last[6] == screen and last[7] == auto then
		return
	end
	local previous = state.effectiveUser
	root:SetScale(REFERENCE_SCALE / parent * effectiveUser)
	state.maximum, state.effectiveUser = maximum, effectiveUser
	last[1], last[2], last[3], last[4], last[5], last[6], last[7] = height, parent, user, width, maximum, screen, auto
	state.height = height
	local effective = root:GetEffectiveScale()
	if not IsPositive(effective) then
		effective = REFERENCE_SCALE * effectiveUser
	end
	state.pixel = UI_HEIGHT / (height * effective)
	state.canvas = width
	state.aspect = AspectClass(width, height)
	state.origin = (screen - width) / 2 * state.pixel
	state.band = (width - BandWidth(screen, height)) / 2 * state.pixel
	root:ClearAllPoints()
	if width < screen then
		root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", state.origin, 0)
		root:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -state.origin, 0)
		Log(string.format("the HUD spreads over a centred %d px of the %d px screen (HUD width %s, %s layout)", width, screen, CanvasSetting(), state.aspect))
	else
		root:SetAllPoints(UIParent)
	end
	Fire("ScaleChanged")
	if added and not auto and user > maximum and effectiveUser < previous - 1e-9 then
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

local UI_SCALE_CVARS = { uiscale = true, useuiscale = true }

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		Apply()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ApplyWaiting()
	elseif event ~= "CVAR_UPDATE" or type(name) == "string" and UI_SCALE_CVARS[name:lower()] then
		Request(event)
		C_Timer.After(0, Recheck)
	end
end)
root:SetScript("OnSizeChanged", function()
	Request("the window size")
end)

function Scale.Root()
	return root
end

function Scale.Origin()
	return state.origin
end

function Scale.Band()
	return state.band
end

function Scale.Aspect()
	return state.aspect
end

function Scale.Arrangement()
	return ArrangementSetting()
end

function Scale.Pixel(n)
	return (n or 1) * state.pixel
end

function Scale.Border()
	return state.pixel
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

function Scale.IsAuto()
	return state.auto
end

function Scale.SetAuto(on)
	if type(on) ~= "boolean" then
		return false
	end
	if on ~= state.auto then
		state.auto = on
		Request("the automatic size")
	end
	return true
end

function Scale.Step()
	return Step(state.height)
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
	elseif module == "Layout" and key == "arrangement" then
		Request("the arrangement")
	elseif ns.Features.modules[module] ~= nil then
		Request("an element setting")
	end
end)
ns.Callbacks.Register("ModuleChanged", "Scale", function()
	Request("a module switch")
end)
ns.Callbacks.Register("ProfileChanged", "Scale", function()
	if ns.Appearance then
		Scale.SetAuto(ns.Appearance.Get("uiScaleAuto"))
		Scale.SetUserScale(ns.Appearance.Get("uiScale"))
	end
	Request("the profile")
end)

Apply()
