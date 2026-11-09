-- DamageSkin.lua: restyles Blizzard's Damage Meter windows and their spell breakdown windows in place as the own meter's BarList rows: Blizzard's fill hushed, a glowing class pill at each row's foot, the header in the cap's type, through the core's Skin helpers and hooks.
local _, ns = ...

local K = KstyleUI
local L, Widgets, Tokens = K.L, K.Widgets, K.Tokens
local Logic = ns.Logic

local MAX_WINDOWS = 3
local WINDOW_NAME = "DamageMeterSessionWindow"
local PILL_GLOW_OUTSET = 3
local PILL_GLOW_ALPHA = 0.35
local LEVEL_ABOVE = 1

local DamageSkin = { active = false, applied = false }
ns.DamageSkin = DamageSkin

local WEAK = { __mode = "k" }
local windows = setmetatable({}, WEAK)
local sources = setmetatable({}, WEAK)
local entries = setmetatable({}, WEAK)
local pills = setmetatable({}, WEAK)
local generation = 1
local ownerHooked = false
local reloadAsked = false

local function Owner()
	return _G.DamageMeter
end

local function EntryColor(entry)
	local displays = Enum and Enum.DamageMeterSourceDisplayType
	local display = entry.sourceDisplayType
	local reaction = "friendly"
	if displays and not Logic.IsSecret(display) and display == displays.Enemy then
		reaction = "hostile"
	end
	local class = entry.classFilename
	if Logic.IsSecret(class) or type(class) ~= "string" or class == "" then
		class = entry.unitClassFilename
	end
	return ns.BarColor("damage", class, reaction)
end

local function Present(value)
	return Logic.IsSecret(value) or value ~= nil
end

local function Recolor(entry)
	local pill = pills[entry]
	if not DamageSkin.active or not pill then
		return
	end
	local r, g, b = EntryColor(entry)
	if pill.r ~= r or pill.g ~= g or pill.b ~= b then
		pill.r, pill.g, pill.b = r, g, b
		pill.bar:SetBarColor(r, g, b, 1)
		pill.glow:SetVertexColor(r, g, b, PILL_GLOW_ALPHA)
	end
end

local function PlacePill(pill)
	local bar, glow, source = pill.bar, pill.glow, pill.source
	local height = Widgets.Snap(bar, ns.BarList.PILL_HEIGHT)
	bar.opts.height = height
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", source, "BOTTOMLEFT")
	bar:SetPoint("BOTTOMRIGHT", source, "BOTTOMRIGHT")
	local outset = Widgets.Snap(bar, PILL_GLOW_OUTSET)
	local fill = bar:GetStatusBarTexture()
	glow:ClearAllPoints()
	glow:SetPoint("TOPLEFT", fill, "TOPLEFT", -outset, outset)
	glow:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", outset, -outset)
end

local function StylePill(pill)
	local bar = pill.bar
	bar:SetBarTexture(ns.Get("damage.texture"))
	bar:SetReverseFill(ns.Get("damage.fill") == "right")
	PlacePill(pill)
end

local function NewPill(entry, source)
	local holder = CreateFrame("Frame", nil, source)
	holder:SetAllPoints(source)
	holder:SetFrameLevel(source:GetFrameLevel() + LEVEL_ABOVE)
	local bar = Widgets.StatusBar(holder, {
		texture = ns.Get("damage.texture"),
		background = "buttonFill",
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		width = Tokens.Size("buffBarWidth"),
		height = ns.BarList.PILL_HEIGHT,
	})
	local glow = holder:CreateTexture(nil, "ARTWORK", nil, -1)
	glow:SetTexture((Tokens.Texture("pill")))
	glow:SetBlendMode("ADD")
	local pill = { entry = entry, source = source, holder = holder, bar = bar, glow = glow, Restyle = PlacePill }
	local low, high = source:GetMinMaxValues()
	if Present(low) and Present(high) then
		bar:SetBarRange(low, high)
	end
	local value = source:GetValue()
	if Present(value) then
		bar:SetBarValue(value)
	end
	hooksecurefunc(source, "SetMinMaxValues", function(_, newLow, newHigh)
		bar:SetBarRange(newLow, newHigh)
	end)
	hooksecurefunc(source, "SetValue", function(_, newValue)
		bar:SetBarValue(newValue)
	end)
	StylePill(pill)
	Widgets.Track(pill)
	return pill
end

local function StyleEntry(entry)
	if type(entry) ~= "table" or not DamageSkin.active then
		return
	end
	local bar = entry.StatusBar
	if type(bar) ~= "table" or type(bar.GetStatusBarTexture) ~= "function" then
		return
	end
	local styled = entries[entry]
	if styled == nil then
		K.Skin.Strip(bar)
		pills[entry] = NewPill(entry, bar)
		if type(entry.UpdateStatusBarColor) == "function" then
			hooksecurefunc(entry, "UpdateStatusBarColor", Recolor)
		end
	end
	if styled ~= generation then
		entries[entry] = generation
		local pill = pills[entry]
		if pill then
			pill.r, pill.g, pill.b = nil, nil, nil
			StylePill(pill)
		end
		if bar.Name then
			ns.ApplyFont(bar.Name, "damage")
			Widgets.TextColor(bar.Name, "textEmphasis")
		end
		if bar.Value then
			ns.ApplyFont(bar.Value, "damage")
			Widgets.TextColor(bar.Value, "textEmphasis")
		end
	end
	Recolor(entry)
end

local function CapTitle(text)
	if type(text) == "table" and type(text.SetFont) == "function" then
		Widgets.StyleText(text, "caption")
		Widgets.TextColor(text, "giltLit")
	end
end

local function CapAside(text)
	if type(text) == "table" and type(text.SetFont) == "function" then
		ns.ApplyFont(text, "damage", "titleSize")
		Widgets.TextColor(text, "muted")
	end
end

local function RestyleWindow(window)
	if not DamageSkin.active or type(window) ~= "table" then
		return
	end
	CapAside(window.SessionTimer)
	CapTitle(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName)
	CapAside(window.SessionDropdown and window.SessionDropdown.SessionName)
	local box = type(window.GetScrollBox) == "function" and window:GetScrollBox()
	if type(box) == "table" and type(box.ForEachFrame) == "function" then
		box:ForEachFrame(StyleEntry)
	end
	local own = type(window.GetLocalPlayerEntry) == "function" and window:GetLocalPlayerEntry()
	if own then
		StyleEntry(own)
	end
end

local function RestyleSource(source)
	if not DamageSkin.active or type(source) ~= "table" then
		return
	end
	local box = type(source.GetScrollBox) == "function" and source:GetScrollBox()
	if type(box) == "table" and type(box.ForEachFrame) == "function" then
		box:ForEachFrame(StyleEntry)
	end
end

local function SourceWindow(window)
	if type(window.GetSourceWindow) ~= "function" then
		return nil
	end
	local ok, source = pcall(window.GetSourceWindow, window)
	if ok and type(source) == "table" then
		return source
	end
	return nil
end

local function StyleSource(window)
	local source = SourceWindow(window)
	if source == nil then
		ns.LogOnce("noSourceWindow", "a Damage Meter window has no spell breakdown window on this client; only the sources are restyled")
		return
	end
	if not sources[source] then
		sources[source] = true
		K.Skin.Strip(source)
		K.Skin.Backdrop(source, { shape = "panel" })
		local scroll = type(source.GetScrollBar) == "function" and source:GetScrollBar()
		if scroll then
			K.Skin.ScrollBar(scroll)
		end
		local close = type(source.GetCloseButton) == "function" and source:GetCloseButton()
		if close then
			K.Skin.CloseButton(close)
		end
		if type(source.Refresh) == "function" then
			hooksecurefunc(source, "Refresh", RestyleSource)
		end
		local box = type(source.GetScrollBox) == "function" and source:GetScrollBox()
		if type(box) == "table" and type(box.Update) == "function" then
			hooksecurefunc(box, "Update", function()
				RestyleSource(source)
			end)
		end
	end
	RestyleSource(source)
end

local function OnInitEntry(_, entry)
	StyleEntry(entry)
end

local function StyleWindow(window)
	if type(window) ~= "table" then
		return
	end
	if not windows[window] then
		windows[window] = true
		K.Skin.Strip(window, { children = { "MinimizeContainer" } })
		K.Skin.Backdrop(window, { shape = "panel" })
		local scroll = type(window.GetScrollBar) == "function" and window:GetScrollBar()
		if scroll then
			K.Skin.ScrollBar(scroll)
		end
		if type(window.Refresh) == "function" then
			hooksecurefunc(window, "Refresh", RestyleWindow)
		end
		if type(window.InitEntry) == "function" then
			hooksecurefunc(window, "InitEntry", OnInitEntry)
		end
		StyleSource(window)
	end
	RestyleWindow(window)
end

local function Window(owner, index)
	if type(owner.GetSessionWindow) == "function" then
		local ok, window = pcall(owner.GetSessionWindow, owner, index)
		if ok and window then
			return window
		end
	end
	return _G[WINDOW_NAME .. index]
end

local function OnSetup(owner, index)
	if DamageSkin.active then
		StyleWindow(Window(owner, index))
	end
end

function DamageSkin.Restyle()
	if not DamageSkin.active then
		return
	end
	generation = generation + 1
	for window in pairs(windows) do
		RestyleWindow(window)
	end
	for source in pairs(sources) do
		RestyleSource(source)
	end
	for entry in pairs(entries) do
		StyleEntry(entry)
	end
end

function DamageSkin.Activate()
	DamageSkin.active = true
	local owner = Owner()
	if owner == nil then
		ns.LogOnce("noDamageMeter", "Blizzard's DamageMeter is missing on this client; there is nothing to restyle")
		return
	end
	if not ownerHooked and type(owner.SetupSessionWindow) == "function" then
		ownerHooked = true
		hooksecurefunc(owner, "SetupSessionWindow", OnSetup)
	end
	for i = 1, MAX_WINDOWS do
		local window = Window(owner, i)
		if window then
			StyleWindow(window)
		end
	end
	DamageSkin.applied = true
	DamageSkin.Restyle()
	ns.LogOnce("damageSkin", "Blizzard's Damage Meter is restyled in place as the own meter's rows")
end

function DamageSkin.Deactivate()
	if not DamageSkin.active then
		return
	end
	DamageSkin.active = false
	if DamageSkin.applied and not reloadAsked then
		reloadAsked = true
		K.Print(L["Blizzard's Damage Meter keeps KstyleUI's look until you reload. Type /reload to finish."])
		K.Callbacks.Fire("ReloadNeeded", ns.MODULE)
	end
end
