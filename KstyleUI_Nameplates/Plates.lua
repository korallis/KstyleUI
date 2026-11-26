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
local highlighted = {}
Plates.highlighted = highlighted

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

local function OnBlizzardAlpha(frame, alpha)
	if refading or not Plates.running or not faded[frame] or not IsSecret(alpha) and alpha == 0 then
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

local hovered

local function Detach(unit)
	local plate = byUnit[unit]
	if not plate then
		return
	end
	byUnit[unit] = nil
	if hovered == plate then hovered = nil end
	for which, selected in pairs(highlighted) do
		if selected == plate then highlighted[which] = nil end
	end
	Unfade(plate.unitFrame)
	plate.unitFrame, plate.boundsTried = nil, nil
	if plate.fadeTicker then plate.fadeTicker:Cancel(); plate.fadeTicker = nil end
	plate:ClearUnit()
end

local function FadeLater(plate, base, unit)
	LogOnce("late", "Blizzard's UnitFrame was not ready at NAME_PLATE_UNIT_ADDED; the fade waits a frame")
	C_Timer.After(0, function()
		if not Plates.running or byUnit[unit] ~= plate or plate.unitFrame or plate.fadeTicker then return end
		if base.UnitFrame then
			plate.unitFrame = base.UnitFrame
			Fade(base.UnitFrame)
		elseif type(C_Timer.NewTicker) == "function" then
			local attempts = 0
			plate.fadeTicker = C_Timer.NewTicker(0.05, function(ticker)
				attempts = attempts + 1
				if Plates.running and byUnit[unit] == plate and base.UnitFrame then
					plate.unitFrame = base.UnitFrame
					Fade(base.UnitFrame)
				elseif attempts < 20 then return end
				ticker:Cancel()
				plate.fadeTicker = nil
			end)
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
	for which in pairs(plateForWorks) do
		if Plates.IsUnit(plate, which) then highlighted[which] = plate end
	end
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
	if IsSecret(unit) or type(unit) ~= "string" then
		return
	end
	if unit == "player" and event == "UNIT_FACTION" then
		for _, each in pairs(byUnit) do each:UpdatePvp() end
	end
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
	UNIT_MAXHEALTH = function(plate) plate:UpdateHealth(); if plate.absorb then plate:UpdateAbsorb() end end,
	UNIT_NAME_UPDATE = Method("UpdateName"),
	PLAYER_GUILD_UPDATE = function(plate) if plate.subtitled or plate.subtitle then plate:UpdateSubtitle() end end,
	UNIT_LEVEL = function(plate) plate:UpdateLevel(); plate:RefreshType(); plate:UpdateTags("Level") end,
	PLAYER_FLAGS_CHANGED = function(plate) if plate.statusTags then plate:UpdateName() end end,
	UNIT_CLASSIFICATION_CHANGED = function(plate)
		plate:UpdateMarker()
		plate:RefreshType()
	end,
	UNIT_FACTION = Method("RefreshFlags"),
	UNIT_FLAGS = Method("RefreshFlags"),
	UNIT_DISPLAYPOWER = function(plate) plate:RefreshType(); plate:UpdateTags("Power") end,
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

local distanceTicker, ranges, Poll

local function Plain(value)
	return not IsSecret(value) and type(value) == "number" and value or nil
end
Plates.Plain = Plain

local function Ranges()
	local book, spell, bank = C_SpellBook, C_Spell, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
	local list, seen = {}, {}
	if not (book and spell and bank and type(book.GetNumSpellBookSkillLines) == "function" and type(book.GetSpellBookSkillLineInfo) == "function"
		and type(book.GetSpellBookItemInfo) == "function" and type(spell.GetSpellInfo) == "function") then
		LogOnce("distance", "the spellbook API or C_Spell.GetSpellInfo is missing; plates show no distance")
		return list
	end
	for line = 1, book.GetNumSpellBookSkillLines() do
		local info = book.GetSpellBookSkillLineInfo(line)
		for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
			local item = book.GetSpellBookItemInfo(slot, bank)
			local data = item and not item.isPassive and Plain(item.spellID) and spell.GetSpellInfo(item.spellID)
			local range = data and Plain(data.minRange) == 0 and Plain(data.maxRange)
			if range and range > 0 then
				if not seen[range] then
					seen[range] = { range }
					list[#list + 1] = seen[range]
				end
				table.insert(seen[range], item.spellID)
			end
		end
	end
	table.sort(list, function(a, b) return a[1] < b[1] end)
	return list
end

local function CheckDistance()
	local plate = highlighted.target
	local api = C_Spell and C_Spell.IsSpellInRange
	if not (plate and plate.distanceText and type(api) == "function") then return end
	if not ranges then
		local ok, list = pcall(Ranges)
		ranges = ok and list or {}
		if not ok then LogOnce("distance-book", "reading the spellbook failed: " .. tostring(list)) end
	end
	local text, beyond = "", 0
	for _, entry in ipairs(ranges) do
		local inRange
		for i = 2, #entry do
			local ok, answer = pcall(api, entry[i], "target")
			if ok and not IsSecret(answer) and answer ~= nil then
				inRange = answer
				break
			end
		end
		if inRange == true then
			text = string.format("%d-%d", beyond, entry[1])
			break
		elseif inRange == false then
			beyond = entry[1]
		end
	end
	if text == "" and beyond > 0 then text = string.format("%d+", beyond) end
	if text ~= plate.distanceValue then
		plate.distanceValue = text
		plate.distanceText:SetText(text)
	end
end

local function OnSpells()
	ranges = nil
end

local function FindHighlight(which)
	local base = plateFor[which]
	if base then return byBase[base] end
	for _, plate in pairs(byUnit) do
		if Plates.IsUnit(plate, which) then return plate end
	end
end

local function OnHighlight(event)
	local hadTarget = ns.state.hasTarget
	UpdateTokens()
	local target, focus = FindHighlight("target"), FindHighlight("focus")
	local sigilCasts = ns.Cast.SigilCasts()
	if not event or hadTarget ~= ns.state.hasTarget and Settings.Get("target.dimOthers") < 1 then
		for _, plate in pairs(byUnit) do plate:UpdateHighlight(sigilCasts) end
	else
		local which = event == "PLAYER_FOCUS_CHANGED" and "focus" or "target"
		local before, after = highlighted[which], target
		if which == "focus" then after = focus end
		if before ~= after then
			if before and before.unit then before:UpdateHighlight(sigilCasts) end
			if after then after:UpdateHighlight(sigilCasts) end
		end
	end
	highlighted.target, highlighted.focus = target, focus
	Poll()
	if distanceTicker then CheckDistance() end
end

local function OnRole()
	local tank = ns.state.isTank
	UpdateRole()
	local flipped = tank ~= ns.state.isTank
	for _, plate in pairs(byUnit) do
		plate:UpdateThreat()
		if flipped then plate:UpdateColor() end
		plate:UpdateTags("Group")
	end
end

local function OnCombat(event)
	ns.state.inCombat = event == "PLAYER_REGEN_DISABLED"
	ns.Resource.Update()
	if not ns.state.inCombat and Settings.Get("markers.questText") then
		for _, plate in pairs(byUnit) do plate:UpdateQuest() end
	end
end

local function OnWorld()
	local inside = IsInInstance and IsInInstance()
	inside = not IsSecret(inside) and inside == true
	if inside == ns.state.inInstance then return end
	ns.state.inInstance = inside
	for _, plate in pairs(byUnit) do
		plate:UpdateLevel()
		plate:RefreshType()
		plate:UpdateQuest()
	end
end

local function OnHover()
	local get, plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit, nil
	local ok, base = false, nil
	if get then ok, base = pcall(get, "mouseover") end
	if ok then
		plate = base and byBase[base]
	elseif not ns.state.inCombat then
		for _, each in pairs(byUnit) do
			local same = UnitIsUnit and UnitIsUnit(each.unit, "mouseover")
			if not IsSecret(same) and same == true then plate = each end
		end
	end
	if plate and not plate.unit then plate = nil end
	if plate == hovered then return end
	if hovered then hovered.hovered = nil; hovered:UpdateFill() end
	hovered = plate
	if plate then plate.hovered = true; plate:UpdateFill() end
end

local RANGE_STEP = 0.25
local rangeTicker, rangeSpell, hoverOn, worldOn, distanceOn, rangeOn

local function CheckRange()
	local spell = rangeSpell or ns.Interrupt.spell
	local api = C_Spell and C_Spell.IsSpellInRange
	if not (spell and type(api) == "function") then
		LogOnce("range", "no range spell or C_Spell.IsSpellInRange; plates keep their opacity")
	end
	for _, plate in pairs(byUnit) do
		local out = false
		if spell and type(api) == "function" and plate.kind == "enemy" then
			local ok, inRange = pcall(api, spell, plate.unit)
			out = ok and not IsSecret(inRange) and inRange == false
		end
		if out ~= (plate.outOfRange == true) then
			plate.outOfRange = out
			plate:UpdateAlpha()
		end
	end
end

function Poll()
	local timer = C_Timer and type(C_Timer.NewTicker) == "function"
	local distance = distanceOn and highlighted.target ~= nil and timer
	if distance and not distanceTicker then
		distanceTicker = C_Timer.NewTicker(RANGE_STEP, CheckDistance)
	elseif not distance and distanceTicker then
		distanceTicker:Cancel()
		distanceTicker = nil
	end
	local range = rangeOn and next(byUnit) ~= nil and timer
	if range and not rangeTicker then
		rangeTicker = C_Timer.NewTicker(RANGE_STEP, CheckRange)
	elseif not range and rangeTicker then
		rangeTicker:Cancel()
		rangeTicker = nil
	end
end

function Plates.SyncOptions()
	local distance = Plates.running and Settings.Get("target.distance") or false
	if distance and not distanceOn then
		ranges = nil
		K.Events.Register("NameplatesDistance", "SPELLS_CHANGED", OnSpells)
	elseif not distance and distanceOn then
		K.Events.Unregister("NameplatesDistance", "SPELLS_CHANGED")
	end
	distanceOn = distance
	local world = Plates.running and not Settings.Get("markers.instances") or false
	if world ~= (worldOn == true) then
		worldOn = world
		if world then
			K.Events.Register(MODULE, "PLAYER_ENTERING_WORLD", OnWorld)
		else
			K.Events.Unregister(MODULE, "PLAYER_ENTERING_WORLD")
			ns.state.inInstance = nil
		end
	end
	if world then OnWorld() end
	local hover = Plates.running and Settings.Get("target.hover") or false
	if hover ~= (hoverOn == true) then
		hoverOn = hover
		if hover then
			K.Events.Register(MODULE, "UPDATE_MOUSEOVER_UNIT", OnHover)
			OnHover()
		else
			K.Events.Unregister(MODULE, "UPDATE_MOUSEOVER_UNIT")
			if hovered then hovered.hovered = nil; hovered:UpdateFill(); hovered = nil end
		end
	end
	local range = Plates.running and Settings.Get("range.fade") or false
	local named = range and Settings.Get("range.spell") or ""
	rangeSpell = named ~= "" and ns.Interrupt.NamedSpell(named) or nil
	if not range and rangeOn then
		for _, plate in pairs(byUnit) do
			if plate.outOfRange then plate.outOfRange = nil; plate:UpdateAlpha() end
		end
	end
	rangeOn = range
	Poll()
end

local function QuestChanged()
	Plate.QuestChanged()
	for _, plate in pairs(byUnit) do
		plate:RefreshType()
		plate:UpdateQuest()
	end
end

local GLOBAL_EVENTS = {
	NAME_PLATE_UNIT_ADDED = function(_, unit)
		UpdateTokens()
		Attach(unit)
		Poll()
	end,
	NAME_PLATE_UNIT_REMOVED = function(_, unit)
		Detach(unit)
		UpdateTokens()
		Poll()
	end,
	RAID_TARGET_UPDATE = ForAll("UpdateRaid"),
	QUEST_LOG_UPDATE = QuestChanged,
	UNIT_QUEST_LOG_CHANGED = QuestChanged,
	PLAYER_LEVEL_UP = function()
		for _, plate in pairs(byUnit) do
			plate:UpdateLevel()
			plate:RefreshType()
		end
	end,
	PLAYER_TARGET_CHANGED = OnHighlight,
	PLAYER_FOCUS_CHANGED = OnHighlight,
	PLAYER_ROLES_ASSIGNED = OnRole,
	GROUP_ROSTER_UPDATE = OnRole,
	PLAYER_REGEN_DISABLED = OnCombat,
	PLAYER_REGEN_ENABLED = OnCombat,
}
Plates.UNIT_EVENTS, Plates.GLOBAL_EVENTS = UNIT_EVENTS, GLOBAL_EVENTS

Plates.LAYOUT_KEY = "nameplates.plate"

function Plates.ReadSize()
	local state = ns.state
	local w, h = Settings.Get("health.width"), Settings.Get("health.height")
	local Layout = K.Layout
	local settings = Layout and Layout.Get and Layout.Get(Plates.LAYOUT_KEY)
	if type(settings) == "table" then
		if type(settings.width) == "number" and settings.width > 0 and settings.width ~= Plate.DEFAULT_WIDTH then
			w = settings.width
		end
		if type(settings.height) == "number" and settings.height > 0 and settings.height ~= Plate.DEFAULT_HEIGHT then
			h = settings.height
		end
	end
	state.width, state.height = w, h
end

function Plates.RestyleAll()
	ns.Resource.Sync()
	Plates.SyncOptions()
	Plates.Each(function(plate)
		plate:Restyle()
	end)
end

function Plates.Start()
	Plates.running = true
	local fighting = InCombatLockdown()
	ns.state.inCombat = not IsSecret(fighting) and fighting == true
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
	ns.Cast.WatchInterrupt()
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
	Plates.SyncOptions()
	K.Interrupt.Unwatch(MODULE)
	ns.Resource.Sync()
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
