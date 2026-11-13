-- DamageSkin.lua: restyles Blizzard's Damage Meter windows and their spell breakdown windows in place as the own meter's card: Blizzard's fill hushed under a flat full-height KstyleUI bar, and the header drawn as the card's section cap over Blizzard's hushed type name and timer, through the core's Skin helpers and hooks.
local _, ns = ...

local K = KstyleUI
local L, Widgets, Tokens = K.L, K.Widgets, K.Tokens
local Logic = ns.Logic

local MAX_WINDOWS = 3
local WINDOW_NAME = "DamageMeterSessionWindow"
local LEVEL_ABOVE = 1
local CAP_LEFT = 12
local CAP_MIDDLE = 14
local CAP_RIGHT = 16

local DamageSkin = { active = false, applied = false }
ns.DamageSkin = DamageSkin

local WEAK = { __mode = "k" }
local windows = setmetatable({}, WEAK)
local sources = setmetatable({}, WEAK)
local entries = setmetatable({}, WEAK)
local pills = setmetatable({}, WEAK)
local caps = setmetatable({}, WEAK)
local hushed = setmetatable({}, WEAK)
local busy = false
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
	return ns.BarColor("damage", class, reaction, nil, true)
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
	end
end

local function PlacePill(pill)
	local bar, holder = pill.bar, pill.holder
	bar.opts.height = math.max(1, Widgets.Snap(bar, Logic.Plain(holder:GetHeight()) or ns.BarList.PILL_HEIGHT))
	bar:Restyle()
	bar.keyline:Hide()
	bar.lit:Hide()
	bar.shade:Hide()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", holder, "TOPLEFT")
	bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT")
	bar:SetFrameLevel(holder:GetFrameLevel())
end

local function StylePill(pill)
	local bar = pill.bar
	bar:SetBarTexture(ns.Get("damage.texture"))
	bar:SetReverseFill(ns.Get("damage.fill") == "right")
	PlacePill(pill)
end

local function NewPill(entry, source)
	local holder = CreateFrame("Frame", nil, entry)
	holder:SetAllPoints(source)
	holder:SetFrameLevel(math.max(entry:GetFrameLevel(), source:GetFrameLevel() - LEVEL_ABOVE))
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
	local pill = { entry = entry, source = source, holder = holder, bar = bar, Restyle = PlacePill }
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

local function Revalue(entry)
	local bar = entry.StatusBar
	local text = DamageSkin.active and type(bar) == "table" and bar.Value
	local recap = entry.deathRecapID
	if not text or (not Logic.IsSecret(recap) and recap ~= nil and recap ~= 0) then
		return
	end
	local ok, perSecond = pcall(entry.ShowsValuePerSecondAsPrimary, entry)
	local main, rate = entry.value, entry.valuePerSecond
	if ok and perSecond == true and (Logic.IsSecret(rate) or rate ~= nil) then
		main = rate
	end
	if not Logic.IsSecret(main) and main == nil then
		main = 0
	end
	local shown = Logic.Abbreviate(main)
	local share = ns.Get("damage.percent") and Logic.Percent(entry.value, entry.sessionTotalValue)
	if share then
		shown = shown .. " \194\183 " .. Logic.FormatPercent(share)
	end
	text:SetText(shown)
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
		if type(entry.UpdateValue) == "function" then
			hooksecurefunc(entry, "UpdateValue", Revalue)
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
			ns.ApplyFont(bar.Value, "damage", nil, "number")
			Widgets.TextColor(bar.Value, "textEmphasis")
		end
	end
	Recolor(entry)
end

local function CapAside(text)
	if type(text) == "table" and type(text.SetFont) == "function" then
		ns.ApplyFont(text, "damage", "titleSize")
		Widgets.TextColor(text, "muted")
	end
end

local function Rehush(region)
	if busy then
		return
	end
	busy = true
	pcall(region.SetAlpha, region, 0)
	busy = false
end

local function Hush(region)
	if type(region) ~= "table" or type(region.SetAlpha) ~= "function" or hushed[region] then
		return
	end
	hushed[region] = true
	region:SetAlpha(0)
	hooksecurefunc(region, "SetAlpha", Rehush)
end

local function CapTitle(cap, text)
	if Logic.IsSecret(text) then
		cap.label:SetText(text)
		return
	end
	cap:SetText(type(text) == "string" and text or "")
end

local function CapCount(cap, text)
	if Logic.IsSecret(text) then
		cap:SetCount(" ")
		cap.count:SetText(text)
	elseif type(text) == "string" and text ~= "" then
		cap:SetCount(text)
	else
		cap:SetCount(nil)
	end
end

local function Mirror(region, paint, cap)
	if type(region) ~= "table" or type(region.SetText) ~= "function" then
		return
	end
	hooksecurefunc(region, "SetText", function(_, text)
		paint(cap, text)
	end)
	if type(region.GetText) == "function" then
		paint(cap, region:GetText())
	end
end

local function IsRegion(object)
	return type(object) == "table" and type(object.GetObjectType) == "function"
end

local function Reserve(window)
	local session = window.SessionDropdown
	if not IsRegion(session) then
		return CAP_RIGHT
	end
	local right, left = Logic.Plain(window:GetRight()), Logic.Plain(session:GetLeft())
	local own, other = Logic.Plain(window:GetEffectiveScale()), Logic.Plain(session:GetEffectiveScale())
	if not (right and left and own and other) or own <= 0 then
		return CAP_RIGHT
	end
	return math.max(CAP_RIGHT, (right * own - left * other) / own + Tokens.Size("gapMedium"))
end

local function PlaceCap(window, cap)
	local top = CAP_MIDDLE - Widgets.SECTION_CAP_HEIGHT / 2
	cap:ClearAllPoints()
	Widgets.Point(cap, "TOPLEFT", window, "TOPLEFT", CAP_LEFT, -top)
	Widgets.Point(cap, "TOPRIGHT", window, "TOPRIGHT", -Reserve(window), -top)
end

local function NewCap(window)
	local head = CreateFrame("Frame", nil, window)
	head:SetAllPoints(window)
	head:SetFrameLevel(window:GetFrameLevel() + LEVEL_ABOVE + 1)
	local cap = Widgets.SectionCap(head, {})
	caps[window] = cap
	local typeDropdown = window.DamageMeterTypeDropdown
	local typeName = type(typeDropdown) == "table" and typeDropdown.TypeName or nil
	if IsRegion(typeDropdown) then
		K.Skin.Strip(typeDropdown)
	end
	Hush(typeName)
	Hush(window.SessionTimer)
	Mirror(typeName, CapTitle, cap)
	Mirror(window.SessionTimer, CapCount, cap)
	PlaceCap(window, cap)
end

local function RestyleWindow(window)
	if not DamageSkin.active or type(window) ~= "table" then
		return
	end
	local cap = caps[window]
	if cap then
		cap:Restyle()
		PlaceCap(window, cap)
	end
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
		NewCap(window)
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
