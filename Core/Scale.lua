-- Scale.lua: the KstyleUI_Root canvas (the whole screen, or under the Centred arrangement a centred band on a screen wider than the HUD width setting allows), its layout class (16:9, 21:9 or 32:9), the inset of that band under Spread, where group and boss frames stay, the automatic pixel-perfect size and the whole-physical-pixel maths.
local _, ns = ...

local Scale = {}
ns.Scale = Scale

local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local REFERENCE_HEIGHT = 1080
local UI_HEIGHT = 768
local REFERENCE_SCALE = UI_HEIGHT / REFERENCE_HEIGHT
local MIN_USER_SCALE, MAX_USER_SCALE = 0.6, 1.5
local DEFAULT_USER_SCALE = 16 / 19
local STEPS_PER_PIXEL = 16
local MOCKUP_SIZE = 1
local TEXT_FLOOR = 11
local CACHE_KEYS = 6
local RESIZE_DELAY = 0.12
local DEVELOPMENT_VERSION = "@" .. "project-version@"
local CANVAS = { ["21:9"] = 12 / 5, ["16:9"] = 16 / 9, full = false }
local DEFAULT_CANVAS = "21:9"
local ARRANGEMENT = { centred = true, spread = true }
local DEFAULT_ARRANGEMENT = "centred"
local ASPECTS = { "16:9", "21:9", "32:9" }
local ASPECT_FROM = { ["21:9"] = 2.05, ["32:9"] = 2.9 }
Scale.MIN_USER_SCALE, Scale.MAX_USER_SCALE = MIN_USER_SCALE, MAX_USER_SCALE
Scale.DEFAULT_USER_SCALE = DEFAULT_USER_SCALE
Scale.STEPS_PER_PIXEL, Scale.MOCKUP_SIZE, Scale.TEXT_FLOOR = STEPS_PER_PIXEL, MOCKUP_SIZE, TEXT_FLOOR
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
	dirty = true,
	textFloor = true,
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

local function Invalidate()
	state.effective = nil
	if ns.Widgets and ns.Widgets.InvalidateScale then ns.Widgets.InvalidateScale() end
end

local root = CreateFrame("Frame", "KstyleUI_Root", UIParent)
root:SetAllPoints(UIParent)
for _, method in ipairs({ "SetScale", "SetParent", "SetIgnoreParentScale" }) do
	hooksecurefunc(root, method, Invalidate)
end

hooksecurefunc(UIParent, "SetScale", Invalidate)

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

local function Limit(width, height, screen, user, auto)
	local layouts = ns.Setup and ns.Setup.Layouts
	if not (layouts and layouts.ScaleLimit) then
		return MAX_USER_SCALE, nil, auto and Scale.Auto(height, MAX_USER_SCALE) or Scale.Nearest(user, height, MAX_USER_SCALE)
	end
	local store = ns.Store
	local preset = store and store.IsLoaded() and store.Module("Layout").preset or "DPS"
	local enabled = layouts.Enabled(preset, store and store.IsLoaded() and store.Profile() or nil)
	local style = ns.HudStyle and ns.HudStyle.Current and ns.HudStyle.Current() or nil
	local cache, key, entry
	if store and store.IsLoaded() and ns.VERSION ~= DEVELOPMENT_VERSION then
		cache = KstyleUIDB.scaleCache
		if type(cache) ~= "table" or cache.version ~= ns.VERSION or type(cache.entries) ~= "table" then
			cache = { version = ns.VERSION, entries = {} }
			KstyleUIDB.scaleCache = cache
		end
		local flags = {}
		for i, element in ipairs(layouts.ELEMENTS) do
			flags[i] = enabled[element.key] and "1" or "0"
		end
		key = table.concat({ preset, screen, height, style or "frames", ArrangementSetting(), CanvasSetting(), table.concat(flags), ns.Appearance and not ns.Appearance.Readability("textFloor") and "legacy-text" or "scaled-text" }, ":")
		local requested = string.format("%.17g", user)
		for i, saved in ipairs(cache.entries) do
			local maximum = type(saved) == "table" and type(saved.maximum) == "string" and tonumber(saved.maximum)
			if type(saved) == "table" and saved.key == key and IsPositive(maximum) and maximum <= MAX_USER_SCALE then
				entry = saved
				local answer
				if auto then
					answer = saved.auto
				elseif saved.user == requested then
					answer = saved.nearest
				elseif saved.previousUser == requested then
					answer = saved.previousNearest
				end
				answer = type(answer) == "string" and tonumber(answer)
				if IsPositive(answer) and answer >= MIN_USER_SCALE and answer <= maximum then
					table.remove(cache.entries, i)
					table.insert(cache.entries, 1, saved)
					return maximum, enabled, answer
				end
				break
			end
		end
	end
	local maximum, fits = layouts.ScaleLimit(width, height, preset, enabled, style)
	local effective = auto and Scale.Auto(height, maximum, fits) or Scale.Nearest(user, height, maximum, fits)
	if cache then
		if not entry then
			entry = { key = key }
			table.insert(cache.entries, 1, entry)
			while #cache.entries > CACHE_KEYS do
				cache.entries[#cache.entries] = nil
			end
		end
		entry.maximum = string.format("%.17g", maximum)
		if auto then
			entry.auto = string.format("%.17g", effective)
		else
			local requested = string.format("%.17g", user)
			if entry.user ~= requested then
				entry.previousUser, entry.previousNearest = entry.user, entry.nearest
			end
			entry.user, entry.nearest = requested, string.format("%.17g", effective)
		end
	end
	return maximum, enabled, effective
end

local function Step(height)
	return REFERENCE_HEIGHT / (STEPS_PER_PIXEL * height)
end

local function Within(k, height, maximum, fits)
	local step = Step(height)
	local low, top = ceil(MIN_USER_SCALE / step - 1e-9), floor(maximum / step + 1e-9)
	if top * step > maximum then
		top = top - 1
	end
	k = max(low, min(k, top))
	while fits and k > low and not fits(k * step) do
		k = k - 1
	end
	return k
end

local function Nearest(size, height, maximum, fits)
	local step = Step(height)
	return Within(floor(size / step + 0.5), height, maximum, fits) * step
end

local function Auto(height, maximum, fits)
	return Nearest(MOCKUP_SIZE, height, maximum, fits)
end

Scale.Nearest, Scale.Auto = Nearest, Auto

local function Apply()
	local screen, height = PhysicalSize()
	local width, band = CanvasWidth(screen, height), BandWidth(screen, height)
	local parent, user, auto = ParentScale(), state.user, state.auto
	local last = state.applied
	if not state.dirty and last[1] == height and last[2] == parent and last[3] == user and last[4] == width and last[6] == screen and last[7] == auto and last[8] == band then
		return
	end
	state.dirty = false
	local maximum, enabled, effectiveUser = Limit(width, height, screen, user, auto)
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
	if last[1] == height and last[2] == parent and last[3] == user and last[4] == width and last[5] == maximum and last[6] == screen and last[7] == auto and last[8] == band and state.effectiveUser == effectiveUser then
		return
	end
	local previous = state.effectiveUser
	root:SetScale(REFERENCE_SCALE / parent * effectiveUser)
	state.maximum, state.effectiveUser = maximum, effectiveUser
	last[1], last[2], last[3], last[4], last[5], last[6], last[7], last[8] = height, parent, user, width, maximum, screen, auto, band
	state.height = height
	local effective = root:GetEffectiveScale()
	if not IsPositive(effective) then
		effective = REFERENCE_SCALE * effectiveUser
	end
	state.pixel = UI_HEIGHT / (height * effective)
	state.effective = effective
	state.canvas = width
	state.aspect = AspectClass(width, height)
	state.origin = (screen - width) / 2 * state.pixel
	state.band = (width - band) / 2 * state.pixel
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
	if (reason == "DISPLAY_SIZE_CHANGED" or reason == "the window size") and ns.Widgets and ns.Widgets.Setting("resizeDebounce") and not InCombatLockdown() then
		state.resizeToken = (state.resizeToken or 0) + 1
		local token = state.resizeToken
		C_Timer.After(RESIZE_DELAY, function()
			if token == state.resizeToken then
				Request("the resize settled")
			end
		end)
		return
	end
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
	Invalidate()
	Request("a late display change")
end

local function RecheckDisplay()
	Invalidate()
	Request("DISPLAY_SIZE_CHANGED")
end

local UI_SCALE_CVARS = { uiscale = true, useuiscale = true }

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		Invalidate()
		state.dirty = true
		Apply()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ApplyWaiting()
	elseif event ~= "CVAR_UPDATE" or type(name) == "string" and UI_SCALE_CVARS[name:lower()] then
		Invalidate()
		Request(event)
		C_Timer.After(0, event == "DISPLAY_SIZE_CHANGED" and RecheckDisplay or Recheck)
	end
end)
root:SetScript("OnSizeChanged", function()
	Invalidate()
	Request("the window size")
end)

function Scale.Root()
	return root
end

function Scale.Effective()
	return state.effective or root:GetEffectiveScale()
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

function Scale.TextFloor()
	if not ns.Appearance or ns.Appearance.Readability("textFloor") then
		return max(1, floor(TEXT_FLOOR / state.pixel + 0.5))
	end
	if state.height < REFERENCE_HEIGHT then
		return 1
	end
	return floor(TEXT_FLOOR * state.height / REFERENCE_HEIGHT + 0.5)
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
	if module == "Layout" or ns.Features.modules[module] ~= nil then
		state.dirty = true
	end
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
ns.Callbacks.Register("HudStyleChanged", "Scale", function()
	state.dirty = true
	Request("the HUD style")
end)
ns.Callbacks.Register("ReadabilityChanged", "Scale", function()
	local textFloor = ns.Appearance.Readability("textFloor")
	if state.textFloor ~= textFloor then
		state.textFloor, state.dirty = textFloor, true
		Request("the text minimum")
	end
end)
ns.Callbacks.Register("ModuleChanged", "Scale", function()
	state.dirty = true
	Request("a module switch")
end)
ns.Callbacks.Register("ProfileChanged", "Scale", function()
	state.dirty = true
	if ns.Appearance then
		Scale.SetAuto(ns.Appearance.Get("uiScaleAuto"))
		Scale.SetUserScale(ns.Appearance.Get("uiScale"))
	end
	Request("the profile")
end)

Apply()
