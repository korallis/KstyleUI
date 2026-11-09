-- Plates.lua: attaches a plate to each nameplate, fades Blizzard's plate with alpha, and routes events to the plates.
local _, ns = ...

local K = KstyleUI
local Settings, Logic, Plate = ns.Settings, ns.Logic, ns.Plate
local IsSecret = Logic.IsSecret
local MODULE = Settings.MODULE

local Plates = { running = false }
ns.Plates = Plates

ns.state = {
	width = Plate.DEFAULT_WIDTH,
	height = Plate.DEFAULT_HEIGHT,
	isTank = false,
	inGroup = false,
	hasTarget = false,
}

local MAX_PLATES = 40
local TOKENS = {}
for i = 1, MAX_PLATES do
	TOKENS[i] = "nameplate" .. i
end

local byUnit = {}
local byBase = setmetatable({}, { __mode = "k" })
local built = {}
local samples = {}
local faded = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local refading = false
local plateFor = { target = nil, focus = nil }
local plateForWorks = { target = true, focus = true }

local LogOnce = ns.LogOnce

function Plates.Get(unit)
	return byUnit[unit]
end

function Plates.AddSample(plate)
	samples[#samples + 1] = plate
end

function Plates.Each(fn, ...)
	for i = 1, #built do
		fn(built[i], ...)
	end
	for i = 1, #samples do
		fn(samples[i], ...)
	end
end

local IGNORES_PARENT_ALPHA = { "selectionHighlight" }
local KEEPS_ALPHA = { "SoftTargetFrame" }
local childAlpha = setmetatable({}, { __mode = "k" })
local childIgnored = setmetatable({}, { __mode = "k" })

local function OnBlizzardAlpha(frame)
	if refading or not Plates.running or not faded[frame] then
		return
	end
	refading = true
	frame:SetAlpha(0)
	refading = false
end

local function Hook(frame)
	if hooked[frame] then
		return
	end
	hooked[frame] = true
	if type(hooksecurefunc) ~= "function" then
		LogOnce("hook", "hooksecurefunc is missing; Blizzard's plates may show again when the game resets their alpha")
		return
	end
	local ok, err = pcall(hooksecurefunc, frame, "SetAlpha", OnBlizzardAlpha)
	if not ok then
		LogOnce("hook-failed", "hooking a Blizzard UnitFrame's SetAlpha failed: " .. tostring(err))
	end
end

local function Fade(frame)
	if not frame then
		return
	end
	faded[frame] = true
	Hook(frame)
	refading = true
	frame:SetAlpha(0)
	refading = false
	for _, key in ipairs(IGNORES_PARENT_ALPHA) do
		local child = frame[key]
		if type(child) == "table" and type(child.SetAlpha) == "function" then
			if childAlpha[child] == nil then
				local alpha = child:GetAlpha()
				childAlpha[child] = not IsSecret(alpha) and type(alpha) == "number" and alpha or 1
			end
			child:SetAlpha(0)
		end
	end
	for _, key in ipairs(KEEPS_ALPHA) do
		local child = frame[key]
		if type(child) == "table" and type(child.SetIgnoreParentAlpha) == "function" then
			if childIgnored[child] == nil then
				local ignored = type(child.IsIgnoringParentAlpha) == "function" and child:IsIgnoringParentAlpha()
				childIgnored[child] = not IsSecret(ignored) and ignored == true
			end
			child:SetIgnoreParentAlpha(true)
			LogOnce("keep-" .. key, "Blizzard's " .. key .. " ignores the faded UnitFrame's alpha, so its icon stays visible")
		else
			LogOnce("keep-missing-" .. key, "Blizzard's UnitFrame has no " .. key .. "; nothing to keep visible")
		end
	end
end

local function Unfade(frame)
	if not (frame and faded[frame]) then
		return
	end
	faded[frame] = nil
	frame:SetAlpha(1)
	for _, key in ipairs(IGNORES_PARENT_ALPHA) do
		local child = frame[key]
		local alpha = type(child) == "table" and childAlpha[child]
		if alpha then
			child:SetAlpha(alpha)
			childAlpha[child] = nil
		end
	end
	for _, key in ipairs(KEEPS_ALPHA) do
		local child = frame[key]
		if type(child) == "table" and childIgnored[child] ~= nil then
			child:SetIgnoreParentAlpha(childIgnored[child])
			childIgnored[child] = nil
		end
	end
end

local function PlateForToken(which)
	if not plateForWorks[which] then
		return nil
	end
	local api = C_NamePlate
	if not (api and api.GetNamePlateForUnit) then
		plateForWorks[which] = false
		LogOnce("plate-for", "C_NamePlate.GetNamePlateForUnit is missing; highlights use UnitIsUnit")
		return nil
	end
	local ok, base = pcall(api.GetNamePlateForUnit, which)
	if not ok then
		plateForWorks[which] = false
		LogOnce("plate-for-" .. which, "GetNamePlateForUnit refused " .. which .. "; highlights use UnitIsUnit")
		return nil
	end
	return base
end

local tokenExists = { target = false, focus = false }

local function Exists(which)
	local exists = UnitExists and UnitExists(which)
	return not IsSecret(exists) and exists == true
end

local function UpdateTokens()
	plateFor.target = PlateForToken("target")
	plateFor.focus = PlateForToken("focus")
	tokenExists.target = Exists("target")
	tokenExists.focus = Exists("focus")
	ns.state.hasTarget = tokenExists.target
end

function Plates.IsUnit(plate, which)
	local base = plateFor[which]
	if base then
		return plate.base == base
	end
	if not (tokenExists[which] and plate.unit and UnitIsUnit) then
		return false
	end
	local same = UnitIsUnit(plate.unit, which)
	if IsSecret(same) then
		LogOnce("unit-compare", "UnitIsUnit returned a secret; that plate shows no highlight")
		return false
	end
	return same == true
end

local function UpdateRole()
	local state = ns.state
	local role = Settings.Get("threat.role")
	if role == "tank" then
		state.isTank = true
	elseif role == "other" then
		state.isTank = false
	else
		local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
		state.isTank = not IsSecret(assigned) and assigned == "TANK"
	end
	local grouped = IsInGroup and IsInGroup()
	state.inGroup = not IsSecret(grouped) and grouped == true
end

local function IsPlayerPlate(base)
	local api = C_NamePlate
	if not (api and api.GetNamePlateForUnit) then
		return false
	end
	local ok, own = pcall(api.GetNamePlateForUnit, "player")
	return ok and own ~= nil and own == base
end

local function WidgetsOnly(unit)
	if not UnitNameplateShowsWidgetsOnly then
		return false
	end
	local only = UnitNameplateShowsWidgetsOnly(unit)
	return not IsSecret(only) and only == true
end

local function Detach(unit)
	local plate = byUnit[unit]
	if not plate then
		return
	end
	byUnit[unit] = nil
	Unfade(plate.unitFrame)
	plate.unitFrame = nil
	plate:ClearUnit()
end

local function FadeLater(plate, base, unit)
	LogOnce("late", "Blizzard's UnitFrame was not ready at NAME_PLATE_UNIT_ADDED; the fade waits a frame")
	C_Timer.After(0, function()
		if Plates.running and byUnit[unit] == plate and base.UnitFrame then
			plate.unitFrame = base.UnitFrame
			Fade(base.UnitFrame)
		end
	end)
end

local function Attach(unit)
	local api = C_NamePlate
	local base = api and api.GetNamePlateForUnit and api.GetNamePlateForUnit(unit)
	if not base then
		return
	end
	if IsPlayerPlate(base) or WidgetsOnly(unit) then
		Unfade(base.UnitFrame)
		return
	end
	local plate = byBase[base]
	if not plate then
		plate = ns.NewPlate(base)
		byBase[base] = plate
		built[#built + 1] = plate
	end
	if plate.unit and plate.unit ~= unit and byUnit[plate.unit] == plate then
		Detach(plate.unit)
	end
	byUnit[unit] = plate
	plate:SetUnit(unit)
	local unitFrame = base.UnitFrame
	if unitFrame then
		plate.unitFrame = unitFrame
		Fade(unitFrame)
	else
		FadeLater(plate, base, unit)
	end
end

local unitHandlers = {}

local function AddUnitHandler(event, fn)
	local list = unitHandlers[event]
	if not list then
		list = {}
		unitHandlers[event] = list
	end
	list[#list + 1] = fn
end

local function Dispatch(event, unit, ...)
	local plate = byUnit[unit]
	if plate then
		local list = unitHandlers[event]
		for i = 1, #list do
			list[i](plate, event, ...)
		end
	end
end

local function Method(name)
	return function(plate)
		plate[name](plate)
	end
end

local function ForAll(method)
	return function()
		for _, plate in pairs(byUnit) do
			plate[method](plate)
		end
	end
end

local UNIT_EVENTS = {
	UNIT_HEALTH = Method("UpdateHealth"),
	UNIT_MAXHEALTH = Method("UpdateHealth"),
	UNIT_NAME_UPDATE = Method("UpdateName"),
	UNIT_LEVEL = Method("UpdateLevel"),
	UNIT_CLASSIFICATION_CHANGED = function(plate)
		plate:UpdateMarker()
		plate:RefreshType()
	end,
	UNIT_FACTION = Method("RefreshFlags"),
	UNIT_FLAGS = Method("RefreshFlags"),
	UNIT_DISPLAYPOWER = Method("RefreshType"),
	UNIT_THREAT_SITUATION_UPDATE = Method("UpdateThreat"),
	UNIT_THREAT_LIST_UPDATE = Method("UpdateThreat"),
}
for event, fn in pairs(UNIT_EVENTS) do
	AddUnitHandler(event, fn)
end

local componentsAdded = 0

local function AddComponentEvents()
	local components = ns.Components
	for i = componentsAdded + 1, #components do
		for event, fn in pairs(components[i].events or {}) do
			AddUnitHandler(event, fn)
		end
	end
	componentsAdded = #components
end

local function OnHighlight()
	UpdateTokens()
	for _, plate in pairs(byUnit) do
		plate:UpdateHighlight()
	end
end

local function OnRole()
	UpdateRole()
	for _, plate in pairs(byUnit) do
		plate:UpdateThreat()
	end
end

local GLOBAL_EVENTS = {
	NAME_PLATE_UNIT_ADDED = function(_, unit)
		UpdateTokens()
		Attach(unit)
	end,
	NAME_PLATE_UNIT_REMOVED = function(_, unit)
		Detach(unit)
		UpdateTokens()
	end,
	RAID_TARGET_UPDATE = ForAll("UpdateRaid"),
	QUEST_LOG_UPDATE = ForAll("RefreshType"),
	UNIT_QUEST_LOG_CHANGED = ForAll("RefreshType"),
	PLAYER_TARGET_CHANGED = OnHighlight,
	PLAYER_FOCUS_CHANGED = OnHighlight,
	PLAYER_ROLES_ASSIGNED = OnRole,
	GROUP_ROSTER_UPDATE = OnRole,
}
Plates.UNIT_EVENTS, Plates.GLOBAL_EVENTS = UNIT_EVENTS, GLOBAL_EVENTS

Plates.LAYOUT_KEY = "nameplates.plate"

function Plates.ReadSize()
	local state = ns.state
	local w, h = Plate.DEFAULT_WIDTH, Plate.DEFAULT_HEIGHT
	local Layout = K.Layout
	local settings = Layout and Layout.Get and Layout.Get(Plates.LAYOUT_KEY)
	if type(settings) == "table" then
		if type(settings.width) == "number" and settings.width > 0 then
			w = settings.width
		end
		if type(settings.height) == "number" and settings.height > 0 then
			h = settings.height
		end
	end
	state.width, state.height = w, h
end

function Plates.RestyleAll()
	Plates.Each(function(plate)
		plate:Restyle()
	end)
end

function Plates.Start()
	Plates.running = true
	Settings.Invalidate()
	UpdateRole()
	UpdateTokens()
	Plates.ReadSize()
	AddComponentEvents()
	for event in pairs(unitHandlers) do
		K.Events.Register(MODULE, event, Dispatch)
	end
	for event, fn in pairs(GLOBAL_EVENTS) do
		K.Events.Register(MODULE, event, fn)
	end
	ns.Interrupt.Start()
	for i = 1, MAX_PLATES do
		local unit = TOKENS[i]
		local exists = UnitExists and UnitExists(unit)
		if not IsSecret(exists) and exists then
			Attach(unit)
		end
	end
	OnHighlight()
end

function Plates.Stop()
	Plates.running = false
	ns.Interrupt.Stop()
	for unit in pairs(byUnit) do
		Detach(unit)
	end
	for frame in pairs(faded) do
		Unfade(frame)
	end
end

function Plates.Count()
	local n = 0
	for _ in pairs(byUnit) do
		n = n + 1
	end
	return n
end
