-- Frames.lua: the secure unit buttons for each frame, their Layout elements, unit watches and events.
local _, ns = ...

local K = KstyleUI
local Settings, Geometry, Style, Unit = ns.Settings, ns.Geometry, ns.Style, ns.Unit

local Frames = {}
ns.Frames = Frames

local MODULE = Settings.MODULE
local BOSS_COUNT = 5
local BOSS_GAP = 10
local POLL_INTERVAL = 0.2

local FULL_LIMITS = { minWidth = 120, minHeight = 24, maxWidth = 640, maxHeight = 160 }
local SMALL_LIMITS = { minWidth = 60, minHeight = 14, maxWidth = 400, maxHeight = 120 }
local BOSS_LIMITS = { minWidth = 120, minHeight = 100, maxWidth = 640, maxHeight = 800 }

local POLLED = { targettarget = true, focustarget = true }

local UNIT_EVENTS = {
	UNIT_HEALTH = "Health",
	UNIT_MAXHEALTH = "Health",
	UNIT_HEAL_PREDICTION = "Prediction",
	UNIT_ABSORB_AMOUNT_CHANGED = "Prediction",
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "Prediction",
	UNIT_POWER_UPDATE = "Power",
	UNIT_MAXPOWER = "Power",
	UNIT_DISPLAYPOWER = "PowerType",
	UNIT_NAME_UPDATE = "Name",
	UNIT_LEVEL = "Level",
	UNIT_CLASSIFICATION_CHANGED = "Level",
	UNIT_PORTRAIT_UPDATE = "Portrait",
	UNIT_MODEL_CHANGED = "Portrait",
	UNIT_FACTION = "Colors",
	UNIT_FLAGS = "Colors",
	UNIT_CONNECTION = "Colors",
}

local frames, order = {}, {}
local running = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function Owner(unit)
	return MODULE .. ":" .. unit
end

local HANDLERS = {
	Health = function(view, unit)
		Unit.Health(view, unit)
	end,
	Prediction = function(view, unit)
		Unit.Prediction(view, unit)
	end,
	Power = function(view, unit)
		Unit.Power(view, unit)
	end,
	PowerType = function(view, unit)
		Unit.PowerColor(view, unit)
		Unit.Power(view, unit, true)
	end,
	Name = function(view, unit)
		Unit.Name(view, unit)
	end,
	Level = function(view, unit)
		Unit.Level(view, unit)
	end,
	Portrait = function(view, unit)
		Unit.Portrait(view, unit)
	end,
	Colors = function(view, unit)
		Unit.HealthColor(view, unit)
		Unit.Health(view, unit)
	end,
}

local function Active(view)
	return running and view.uf.active
end

local function Refresh(view, instant)
	if Active(view) then
		Unit.All(view, view.unit, instant)
	end
end

local function RefreshKind(kind, instant)
	local uf = frames[kind]
	if uf then
		for _, view in ipairs(uf.views) do
			Refresh(view, instant)
		end
	end
end

local function OnEnter(button)
	if UnitFrame_OnEnter then
		UnitFrame_OnEnter(button)
	end
end

local function OnLeave(button)
	if UnitFrame_OnLeave then
		UnitFrame_OnLeave(button)
	end
end

local function Poll(holder, elapsed)
	local uf = holder.uf
	uf.elapsed = uf.elapsed + elapsed
	if uf.elapsed < POLL_INTERVAL then
		return
	end
	uf.elapsed = 0
	local view = uf.views[1]
	if Active(view) and UnitExists(view.unit) then
		Unit.Health(view, view.unit)
		Unit.Power(view, view.unit)
	end
end

local function StartPolling(uf)
	if POLLED[uf.kind] and not uf.polling then
		uf.polling = true
		uf.elapsed = 0
		uf.holder:SetScript("OnUpdate", Poll)
	end
end

local function StopPolling(uf)
	if uf.polling then
		uf.polling = false
		uf.holder:SetScript("OnUpdate", nil)
	end
end

local function Visible(frame)
	local shown = frame:IsVisible()
	return (issecretvalue and issecretvalue(shown)) or shown == true
end

local function OnButtonShow(button)
	local view = button.view
	if Active(view) then
		StartPolling(view.uf)
		Unit.All(view, view.unit, true)
	end
end

local function OnButtonHide(button)
	StopPolling(button.view.uf)
end

local function NewView(uf, unit)
	local button = CreateFrame("Button", nil, uf.holder, "SecureUnitButtonTemplate")
	button:SetAttribute("unit", unit)
	button:SetAttribute("type1", "target")
	button:SetAttribute("type2", "togglemenu")
	button:RegisterForClicks("AnyUp")
	button.unit = unit
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	local view = Style.New(button, uf.kind)
	view.button, view.unit, view.uf = button, unit, uf
	button.view = view
	button:HookScript("OnShow", OnButtonShow)
	button:HookScript("OnHide", OnButtonHide)
	return view
end

local function Limits(kind)
	if kind == "boss" then
		return BOSS_LIMITS
	end
	return K.Setup.Layouts.Element(Settings.ELEMENTS[kind]).height < Geometry.FULL_MIN_HEIGHT and SMALL_LIMITS or FULL_LIMITS
end

local function Register(uf)
	local key = Settings.ELEMENTS[uf.kind]
	local element = K.Setup.Layouts.Element(key)
	local position = K.Setup.Layouts.Default(key)
	local holder = uf.holder
	holder:SetSize(element.width, element.height)
	holder:ClearAllPoints()
	holder:SetPoint(position.anchor, K.Scale.Root(), position.anchor, position.x, position.y)
	local Layout = K.Layout
	if not (Layout and Layout.Register) then
		Log("Layout.Register is missing; " .. key .. " keeps its default position")
		return
	end
	local limits = Limits(uf.kind)
	Layout.Register(holder, key, position, {
		label = element.label,
		module = MODULE,
		resizable = true,
		minWidth = limits.minWidth,
		minHeight = limits.minHeight,
		maxWidth = limits.maxWidth,
		maxHeight = limits.maxHeight,
	})
end

local function Build(kind)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	local uf = { kind = kind, holder = holder, views = {}, elapsed = 0, active = false }
	holder.uf = uf
	local count = kind == "boss" and BOSS_COUNT or 1
	for i = 1, count do
		local unit = kind == "boss" and ("boss" .. i) or kind
		uf.views[i] = NewView(uf, unit)
	end
	holder:HookScript("OnSizeChanged", function()
		Frames.Relayout(uf)
	end)
	frames[kind] = uf
	order[#order + 1] = kind
	Register(uf)
	return uf
end

local function Size(frame)
	local w, h = frame:GetSize()
	if (issecretvalue and (issecretvalue(w) or issecretvalue(h))) or type(w) ~= "number" or type(h) ~= "number" then
		return nil
	end
	return w, h
end

local function Protected()
	return InCombatLockdown()
end

local function Queue(uf, field, fn)
	if uf[field] then
		return
	end
	uf[field] = true
	K.Combat.Queue(function()
		uf[field] = false
		fn(uf)
	end)
end

local function Slots(uf, w, h)
	if uf.kind == "boss" then
		return Geometry.Slots(BOSS_COUNT, BOSS_GAP, w, h)
	end
	return { { x = 0, y = 0, w = w, h = h } }
end

function Frames.Relayout(uf)
	if Protected() then
		Queue(uf, "layoutQueued", Frames.Relayout)
		return
	end
	local w, h = Size(uf.holder)
	if not (w and uf.s) then
		return
	end
	local slots = Slots(uf, w, h)
	for i, view in ipairs(uf.views) do
		local slot = slots[i]
		local button = view.button
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", uf.holder, "TOPLEFT", slot.x, -slot.y)
		button:SetSize(slot.w, slot.h)
		Style.Layout(view, uf.s, slot.w, slot.h)
	end
end

function Frames.Restyle(uf)
	uf.s = Settings.Snapshot(uf.kind)
	for _, view in ipairs(uf.views) do
		view.s = uf.s
		Style.Restyle(view, uf.kind)
	end
	Frames.Relayout(uf)
	for _, view in ipairs(uf.views) do
		Refresh(view, true)
	end
end

local function RegisterUnitEvents(view)
	if POLLED[view.uf.kind] then
		return
	end
	local owner = Owner(view.unit)
	local handler = view.handler
	if not handler then
		handler = function(event)
			local name = UNIT_EVENTS[event]
			if name and Active(view) then
				HANDLERS[name](view, view.unit)
			end
		end
		view.handler = handler
	end
	for event in pairs(UNIT_EVENTS) do
		K.Events.RegisterUnit(owner, event, handler, view.unit)
	end
end

function Frames.Apply(uf)
	local want = running and Settings.Value(uf.kind, "enabled")
	if Protected() then
		Queue(uf, "applyQueued", Frames.Apply)
		return
	end
	uf.active = want and true or false
	if want then
		uf.holder:Show()
		Frames.Restyle(uf)
	end
	for _, view in ipairs(uf.views) do
		local button = view.button
		if want then
			RegisterUnitEvents(view)
			RegisterUnitWatch(button)
		else
			UnregisterUnitWatch(button)
			button:Hide()
			K.Events.UnregisterAll(Owner(view.unit))
		end
	end
	if want and Visible(uf.views[1].button) then
		StartPolling(uf)
	elseif not want then
		StopPolling(uf)
	end
end

local function ForEach(fn)
	for _, kind in ipairs(order) do
		fn(frames[kind])
	end
end

local function OnSettingChanged(_, module, key)
	if module ~= MODULE then
		return
	end
	local kind, rest = key:match("^(%w+)%.(.+)$")
	local uf = kind and frames[kind]
	if uf then
		if rest == "enabled" then
			Frames.Apply(uf)
			ns.Blizzard.Apply(running)
		elseif uf.active then
			Frames.Restyle(uf)
		end
		return
	end
	if key == "hideBlizzard" then
		ns.Blizzard.Apply(running)
	elseif key == "accent" or key == "accentColor" then
		ForEach(function(each)
			for _, view in ipairs(each.views) do
				Style.Accent(view)
			end
		end)
	end
end

local function RestyleAll()
	ForEach(function(uf)
		if uf.active then
			Frames.Restyle(uf)
		end
	end)
end

local function OnProfileChanged()
	ForEach(Frames.Apply)
	ns.Blizzard.Apply(running)
end

local function OnLayoutChanged(_, key)
	ForEach(function(uf)
		if Settings.ELEMENTS[uf.kind] == key and uf.active then
			Frames.Relayout(uf)
		end
	end)
end

local function RegisterEvents()
	local Events = K.Events
	Events.Register(MODULE, "PLAYER_TARGET_CHANGED", function()
		RefreshKind("target", true)
		RefreshKind("targettarget", true)
	end)
	Events.Register(MODULE, "PLAYER_FOCUS_CHANGED", function()
		RefreshKind("focus", true)
		RefreshKind("focustarget", true)
	end)
	Events.RegisterUnit(MODULE, "UNIT_TARGET", function(_, unit)
		RefreshKind(unit == "focus" and "focustarget" or "targettarget", true)
	end, "target", "focus")
	Events.RegisterUnit(MODULE, "UNIT_PET", function()
		RefreshKind("pet", true)
	end, "player")
	Events.Register(MODULE, "INSTANCE_ENCOUNTER_ENGAGE_UNIT", function()
		RefreshKind("boss", true)
	end)
	Events.Register(MODULE, "UNIT_TARGETABLE_CHANGED", function()
		RefreshKind("boss", true)
	end)
	Events.Register(MODULE, "PLAYER_ENTERING_WORLD", function()
		ForEach(function(uf)
			RefreshKind(uf.kind, true)
		end)
	end)
	local Callbacks = K.Callbacks
	Callbacks.Register("SettingChanged", MODULE, OnSettingChanged)
	Callbacks.Register("ThemeChanged", MODULE, RestyleAll)
	Callbacks.Register("ScaleChanged", MODULE, RestyleAll)
	Callbacks.Register("ProfileChanged", MODULE, OnProfileChanged)
	Callbacks.Register("LayoutChanged", MODULE, OnLayoutChanged)
end

function Frames.Enable()
	running = true
	if #order == 0 then
		for _, kind in ipairs(Settings.KINDS) do
			Build(kind)
		end
		Log("built " .. #order .. " unit frames")
	end
	RegisterEvents()
	ForEach(Frames.Apply)
	ns.Blizzard.Apply(true)
end

function Frames.Disable()
	running = false
	ForEach(function(uf)
		Frames.Apply(uf)
		if not Protected() then
			uf.holder:Hide()
		end
	end)
	ns.Blizzard.Apply(false)
end

function Frames.Get(kind)
	return frames[kind]
end

function Frames.IsRunning()
	return running
end
