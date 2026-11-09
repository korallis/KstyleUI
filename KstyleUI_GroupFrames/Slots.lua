-- Slots.lua: the player's indicator slots: up to six aura slots per group frame, each a category the game's own aura filters define, placed where the player chooses, found and drawn by the AuraContainer engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Button, Auras = ns.Settings, ns.Style, ns.Unit, ns.Button, ns.Auras

local Slots = {}
ns.Slots = Slots

local COUNT = Settings.INDICATOR_SLOTS
local OFF = "OFF"
local PLAYER = "PLAYER"
local SLOT_LEVEL = 8
Slots.CATEGORIES = {
	EXTERNAL = { filter = "HELPFUL|EXTERNAL_DEFENSIVE", icon = 135936 },
	BIG_DEFENSIVE = { filter = "HELPFUL|BIG_DEFENSIVE", icon = 135919 },
	HOTS = { filter = "HELPFUL|PLAYER|RAID_IN_COMBAT", icon = 135953 },
	IMPORTANT = { filter = "HELPFUL|IMPORTANT", icon = 135932 },
	CROWD_CONTROL = { filter = "HARMFUL|CROWD_CONTROL", icon = 136071 },
	BOSS = { filter = "HARMFUL", candidates = { isBossAura = true }, icon = 136207 },
	DISPEL = { filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", icon = 135894 },
	SPELLS = { filter = "HELPFUL", spells = true, icon = 136081 },
}
local CATEGORIES = Slots.CATEGORIES
local NEUTRAL_FILTER = "HELPFUL"

local available = true
local waiting = setmetatable({}, { __mode = "k" })

local function Key(i)
	return "indicator" .. i
end

function Slots.Spells(text)
	local set, any = {}, false
	if type(text) ~= "string" then
		return nil
	end
	for digits in text:gmatch("%d+") do
		local id = tonumber(digits)
		if id and id > 0 then
			set[id] = true
			any = true
		end
	end
	return any and set or nil
end

function Slots.Plan(slot)
	local category = CATEGORIES[slot.category]
	if not category then
		return nil
	end
	local filter = category.filter
	if slot.mine and not filter:find(PLAYER, 1, true) then
		filter = filter .. "|" .. PLAYER
	end
	local candidates = category.candidates
	if category.spells then
		local spells = Slots.Spells(slot.spells)
		if not spells then
			return nil
		end
		candidates = { includeSpellIDs = spells }
	end
	return { filter = filter, candidates = candidates }
end

local function AnyOn()
	local cfg = Settings.current
	for i = 1, COUNT do
		if cfg[Key(i)].category ~= OFF then
			return true
		end
	end
	return false
end
Slots.AnyOn = AnyOn

function Slots.Size(f, wanted)
	local w, h = Style.Size(f)
	local room = math.min(w, h) - 2 * Tokens.Size("gapTiny")
	return math.max(1, math.min(wanted, room))
end

local function Size(f, i)
	return function()
		return Slots.Size(f, Settings.current[Key(i)].size)
	end
end

function Slots.Placements(f)
	local cfg = Settings.current
	local w = Style.Size(f)
	local inset = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local gap = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local out, taken = {}, {}
	for i = 1, COUNT do
		local slot = cfg[Key(i)]
		local point = slot.position
		local size = Widgets.Snap(f, Slots.Size(f, slot.size))
		local x = point:find("LEFT$") and inset or (point:find("RIGHT$") and -inset or 0)
		local y = point:find("^TOP") and -inset or (point:find("^BOTTOM") and inset or 0)
		if CATEGORIES[slot.category] then
			local edge = taken[point]
			if point:find("LEFT$") or point:find("RIGHT$") then
				local shift = math.min(edge or 0, math.max(0, w - 2 * inset - size))
				taken[point] = (edge or 0) + size + gap
				x = x + (point:find("RIGHT$") and -shift or shift)
			else
				local centre = edge and edge + gap + size / 2 or 0
				centre = math.min(centre, math.max(0, w / 2 - inset - size / 2))
				taken[point] = centre + size / 2
				x = x + centre
			end
		end
		out[i] = { point = point, x = x, y = y, size = size }
	end
	return out
end

local function Place(f)
	local container = f.indicators
	local base = f:GetFrameLevel() + Auras.CONTAINER_LEVEL + SLOT_LEVEL
	local placements = Slots.Placements(f)
	for i = 1, COUNT do
		local button = container:GetAuraSlotFrame(Key(i))
		if button then
			local place = placements[i]
			button:ClearAllPoints()
			button:SetPoint(place.point, f, place.point, place.x, place.y)
			button:SetFrameLevel(base + COUNT - i)
			Auras.StyleIcon(button)
			Widgets.Size(button, place.size, place.size)
		end
	end
end

local function Restyler(f)
	if f.indicators then
		Place(f)
	end
end
Auras.restylers[#Auras.restylers + 1] = Restyler

local function Configure(f)
	local container = f.indicators
	local cfg = Settings.current
	for i = 1, COUNT do
		local key = Key(i)
		local plan = Slots.Plan(cfg[key])
		if plan then
			container:SetAuraSlotFilterString(key, plan.filter)
			container:SetAuraSlotCandidateFilters(key, plan.candidates)
			container:SetAuraSlotEnabled(key, true)
		else
			container:SetAuraSlotEnabled(key, false)
		end
	end
	Auras.Restyle(f)
end

local function NewContainer(f)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, Auras.TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraSlot) ~= "function" then
		available = false
		Style.LogOnce("slotsMissing", "the AuraContainer engine has no aura slots, so group frames show no indicators: " .. tostring(container))
		return nil
	end
	container:SetFrameLevel(f:GetFrameLevel() + Auras.CONTAINER_LEVEL)
	if type(container.SetEditModePreviewEnabled) == "function" then
		pcall(container.SetEditModePreviewEnabled, container, false)
	end
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	local added, err = pcall(function()
		for i = 1, COUNT do
			local options = {
				initializeFrame = function(button)
					Auras.Dress(button, f, Size(f, i))
				end,
			}
			if methods and directions then
				options.sortMethod = methods.Default
				options.sortDirection = directions.Normal
			end
			container:AddAuraSlot(Key(i), NEUTRAL_FILTER, options)
			container:SetAuraSlotEnabled(Key(i), false)
		end
	end)
	if not added then
		container:Hide()
		available = false
		Style.LogOnce("slotsAdd", "the indicator slots could not be added: " .. tostring(err))
		return nil
	end
	Style.LogOnce("slotsEngine", "group frame indicators run on the AuraContainer engine's aura slots")
	return container
end

local function SetUnit(f, unit)
	local container = f.indicators
	if not container or f.indicatorsUnit == unit then
		return
	end
	local ok, err = pcall(container.SetUnit, container, unit)
	if ok then
		f.indicatorsUnit = unit
	else
		Style.LogOnce("slotsUnit", "an indicator container refused a unit: " .. tostring(err))
	end
end

local function Bind(f)
	if f.sample then
		return
	end
	local on = AnyOn() and available and Unit.running
	if not on then
		if f.indicators then
			SetUnit(f, "none")
			f.indicators:Hide()
		end
		return
	end
	if not f.indicators then
		if not f.unit then
			return
		end
		if InCombatLockdown() then
			if not waiting[f] then
				waiting[f] = true
				K.Combat.Queue(function()
					waiting[f] = nil
					Bind(f)
				end)
			end
			return
		end
		f.indicators = NewContainer(f)
		if not f.indicators then
			return
		end
		local ok, err = pcall(Configure, f)
		if not ok then
			Style.LogOnce("slotsConfigure", "configuring the indicators failed: " .. tostring(err))
		end
	end
	f.indicators:Show()
	SetUnit(f, f.unit or "none")
end
Slots.Bind = Bind

local function Applied(f)
	if f.sample then
		Slots.LayoutSamples(f)
	elseif f.indicators then
		local ok, err = pcall(Configure, f)
		if not ok then
			Style.LogOnce("slotsConfigure", "configuring the indicators failed: " .. tostring(err))
		end
	end
end
Style.appliers[#Style.appliers + 1] = Applied

local function BuildSamples(f)
	if not f.sample then
		return
	end
	local holder = CreateFrame("Frame", nil, f)
	holder:SetAllPoints(f)
	holder:SetFrameLevel(f:GetFrameLevel() + Auras.CONTAINER_LEVEL + SLOT_LEVEL)
	f.sampleSlots = {}
	for i = 1, COUNT do
		local icon = CreateFrame("Frame", nil, holder)
		icon.tile = Auras.NewTile(icon)
		icon:SetFrameLevel(holder:GetFrameLevel() + COUNT - i)
		icon:Hide()
		f.sampleSlots[i] = icon
	end
end
Button.built[#Button.built + 1] = BuildSamples

function Slots.LayoutSamples(f)
	local placements = Slots.Placements(f)
	for i, icon in ipairs(f.sampleSlots or {}) do
		local place = placements[i]
		icon:ClearAllPoints()
		icon:SetPoint(place.point, f, place.point, place.x, place.y)
		icon:SetSize(place.size, place.size)
		icon.tile.chrome:Restyle()
		icon.tile.chrome:SetRimAccent(Style.Accent())
		Auras.PlaceIcon(icon.tile)
	end
end

local function PaintSample(f, sample)
	local cfg = Settings.current
	local shows = sample.indicators or {}
	for i, icon in ipairs(f.sampleSlots or {}) do
		local slot = cfg[Key(i)]
		local category = CATEGORIES[slot.category]
		local on = category ~= nil and shows[slot.category] == true
		if on then
			icon.tile.icon:SetTexture(category.icon)
		end
		icon:SetShown(on)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.changed[#Unit.changed + 1] = Bind
Unit.extra[#Unit.extra + 1] = Bind
