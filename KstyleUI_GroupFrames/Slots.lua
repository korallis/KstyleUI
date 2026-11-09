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

function Slots.Helpful(category)
	local plan = CATEGORIES[category]
	return plan ~= nil and plan.filter:find("^HELPFUL") ~= nil
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
		return Slots.Placements(f)[i].size
	end
end

local MIN_SIZE = 7
local NAME_LINE_EXTRA = 2
local CACHE_LIMIT = 32
local cache, cached = {}, 0

local function Box(left, top, width, height)
	return { left = left, top = top, right = left + width, bottom = top + height }
end

local function Overlaps(a, b)
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

local function Within(r, field)
	return r.left >= field.left and r.top >= field.top and r.right <= field.right and r.bottom <= field.bottom
end

local function FromRect(rect)
	return Box(rect.left, rect.top, rect.width, rect.height)
end

local function Field(f, w, h)
	local parts, inset, gap = f.parts, Widgets.Snap(f, Tokens.Size("gapTiny")), Widgets.Snap(f, Tokens.Size("gapTiny"))
	local field = { left = inset, top = inset, right = w - inset, bottom = h - inset }
	local blocked = {}
	if not parts then
		return field, blocked, gap
	end
	if parts.portrait then
		field.left = math.max(field.left, parts.portrait.left + parts.portrait.width + gap)
	end
	local health = parts.health
	local k = Settings.current[f.kind]
	local fill = FromRect(health)
	if not parts.overlay then
		blocked[#blocked + 1] = fill
		fill = nil
	end
	if parts.overlay then
		local spot = parts.healthText
		blocked[#blocked + 1] = Box(spot.left, spot.top, spot.right - spot.left, spot.height)
		if parts.boss and Settings.current.auras.enabled then
			blocked[#blocked + 1] = FromRect(parts.boss)
		end
	end
	if parts.nameInside then
		local line = k.nameSize + NAME_LINE_EXTRA
		blocked[#blocked + 1] = Box(health.left, health.top + (health.height - line) / 2, health.width, line)
	else
		blocked[#blocked + 1] = FromRect(parts.name)
	end
	local icons, shown = parts.icons, Settings.current.icons
	if icons then
		for _, name in ipairs({ "role", "leader", "marker" }) do
			if icons[name] and shown[name] then
				blocked[#blocked + 1] = FromRect(icons[name])
			end
		end
	end
	if Settings.current.auras.enabled then
		local block = Auras.Block(f, k)
		if block.cells > 0 and block.left then
			blocked[#blocked + 1] = Box(block.left, block.top, block.width, block.height)
		end
	end
	if Settings.current.buffs.enabled then
		local _, count, _, _, _, _, row = Auras.HealIcons(f, k)
		if count > 0 and row then
			blocked[#blocked + 1] = FromRect(row)
		end
	end
	return field, blocked, gap, fill
end

local function Preferred(field, point, size)
	local x, y
	if point:find("LEFT$") then
		x = field.left
	elseif point:find("RIGHT$") then
		x = field.right - size
	else
		x = (field.left + field.right - size) / 2
	end
	if point:find("^TOP") then
		y = field.top
	elseif point:find("^BOTTOM") then
		y = field.bottom - size
	else
		y = (field.top + field.bottom - size) / 2
	end
	return x, y
end

local function Find(field, blocked, point, size, gap)
	local px, py = Preferred(field, point, size)
	local xs, ys = { px, field.left, field.right - size }, { py, field.top, field.bottom - size }
	for _, b in ipairs(blocked) do
		xs[#xs + 1], xs[#xs + 2] = b.right + gap, b.left - gap - size
		ys[#ys + 1], ys[#ys + 2] = b.bottom + gap, b.top - gap - size
	end
	local best, bestCost
	for _, y in ipairs(ys) do
		for _, x in ipairs(xs) do
			local cost = math.abs(x - px) + 2 * math.abs(y - py)
			if not bestCost or cost < bestCost then
				local r = Box(x, y, size, size)
				if Within(r, field) then
					local free = true
					for _, b in ipairs(blocked) do
						if Overlaps(r, b) then
							free = false
							break
						end
					end
					if free then
						best, bestCost = r, cost
					end
				end
			end
		end
	end
	return best
end

local function Share(point)
	local h = point:find("LEFT$") and 0 or (point:find("RIGHT$") and 1 or 0.5)
	local v = point:find("^TOP") and 0 or (point:find("^BOTTOM") and 1 or 0.5)
	return h, v
end

local function Centredness(point)
	local n = 0
	if not (point:find("LEFT$") or point:find("RIGHT$")) then
		n = n + 1
	end
	if not (point:find("^TOP") or point:find("^BOTTOM")) then
		n = n + 1
	end
	return n
end

local function Key2(f, w, h, field, blocked)
	local cfg = Settings.current
	local out = { f.kind, w, h, field.left, field.top, field.right, field.bottom, Widgets.Snap(f, 1) }
	for _, b in ipairs(blocked) do
		out[#out + 1] = b.left .. ":" .. b.top .. ":" .. b.right .. ":" .. b.bottom
	end
	for i = 1, COUNT do
		local slot = cfg[Key(i)]
		out[#out + 1] = (CATEGORIES[slot.category] and (Slots.Helpful(slot.category) and "h" or "1") or "0") .. slot.position .. slot.size
	end
	return table.concat(out, "|")
end

function Slots.Placements(f)
	local cfg = Settings.current
	local w, h = Style.Size(f)
	local field, blocked, gap, fill = Field(f, w, h)
	local key = Key2(f, w, h, field, blocked) .. (fill and "|fill" or "")
	if cache[key] then
		return cache[key]
	end
	local taken = {}
	for i, b in ipairs(blocked) do
		taken[i] = b
	end
	local out, order = {}, {}
	for i = 1, COUNT do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local ca, cb = Centredness(cfg[Key(a)].position), Centredness(cfg[Key(b)].position)
		if ca ~= cb then
			return ca < cb
		end
		return a < b
	end)
	for _, i in ipairs(order) do
		local slot = cfg[Key(i)]
		local point = slot.position
		local wanted = Widgets.Snap(f, Slots.Size(f, slot.size))
		local place = { point = point, x = 0, y = 0, size = wanted, fits = false }
		if CATEGORIES[slot.category] then
			local size, spot = wanted, nil
			local floor, step = math.min(wanted, MIN_SIZE), Widgets.Snap(f, 1)
			step = step > 0 and step or 1
			local avoid = taken
			if fill and Slots.Helpful(slot.category) then
				avoid = { fill }
				for j = 1, #taken do
					avoid[j + 1] = taken[j]
				end
			end
			while size >= floor and not spot do
				spot = Find(field, avoid, point, size, gap)
				if not spot then
					size = size - step
				end
			end
			if spot then
				taken[#taken + 1] = spot
				local hs, vs = Share(point)
				place.size, place.fits = size, true
				place.x = spot.left + hs * size - hs * w
				place.y = -(spot.top + vs * size - vs * h)
			end
		end
		out[i] = place
	end
	if cached >= CACHE_LIMIT then
		cache, cached = {}, 0
	end
	cache[key], cached = out, cached + 1
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
	local placements = Slots.Placements(f)
	for i = 1, COUNT do
		local key = Key(i)
		local plan = placements[i].fits and Slots.Plan(cfg[key])
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
	local placements = Slots.Placements(f)
	for i, icon in ipairs(f.sampleSlots or {}) do
		local slot = cfg[Key(i)]
		local category = CATEGORIES[slot.category]
		local on = category ~= nil and shows[slot.category] == true and placements[i].fits
		if on then
			icon.tile.icon:SetTexture(category.icon)
		end
		icon:SetShown(on)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.changed[#Unit.changed + 1] = Bind
Unit.extra[#Unit.extra + 1] = Bind
