-- Slots.lua: the player's indicator slots: up to six aura slots per group frame, each a category the game's own aura filters define, placed where the player chooses, found and drawn by the AuraContainer engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Button, Auras, Geometry = ns.Settings, ns.Style, ns.Unit, ns.Button, ns.Auras, ns.Geometry

local Slots = {}
ns.Slots = Slots

local COUNT = Settings.INDICATOR_SLOTS
local OFF = "OFF"
local PLAYER = "PLAYER"
local SLOT_LEVEL = 8
local BAR_BACK_ALPHA = 0.5
local SAMPLE_FILL = 0.6
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

local SHOWN_ON = { party = "PARTY", raid = "RAID" }
local function Category(slot, kind)
	return (slot.show == "BOTH" or slot.show == SHOWN_ON[kind]) and CATEGORIES[slot.category] or nil
end
Slots.Category = Category

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

local NAME_LINE_EXTRA = 2
local CLEAR = 1
local CACHE_LIMIT = 32
local cache, cached = {}, 0
local seen = setmetatable({}, { __mode = "v" })

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
		blocked[#blocked + 1] = Box(health.left, health.top - CLEAR, health.width, health.height + CLEAR)
		fill = nil
	end
	if parts.overlay then
		local spot = parts.healthText
		blocked[#blocked + 1] = Box(spot.left, spot.top, spot.right - spot.left, spot.height)
		if parts.boss and Settings.current.auras.enabled then
			blocked[#blocked + 1] = FromRect(parts.boss)
		end
		if parts.power then
			blocked[#blocked + 1] = FromRect(parts.power)
		end
	end
	if parts.nameInside then
		local line = k.nameSize + NAME_LINE_EXTRA
		blocked[#blocked + 1] = Box(health.left, health.top + (health.height - line) / 2, health.width, line)
	elseif parts.overlay then
		blocked[#blocked + 1] = FromRect(parts.name)
	else
		local name = parts.name
		blocked[#blocked + 1] = Box(name.left, name.top, name.width, math.min(name.height, k.nameSize + CLEAR))
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
	local heal
	if Settings.current.buffs.enabled then
		local side, count, size, spacing, _, _, row = Auras.HealIcons(f, k)
		if count > 0 and row then
			blocked[#blocked + 1] = FromRect(row)
			local drawn = Geometry.Line(count, size, spacing)
			heal = (k.buffX ~= 0 or k.buffY ~= 0) and Box(side == "RIGHT" and row.left + row.width - drawn or row.left, row.top, drawn, row.height) or nil
		end
	end
	return field, blocked, gap, fill, heal
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
		ys[#ys + 1], ys[#ys + 2] = b.bottom, b.top - size
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

local function Spots(f)
	local parts = f.parts
	local lane = parts and (parts.indicatorLane or parts.overlay and parts.lane)
	if not lane or not lane.legible then
		return nil
	end
	local out = { lane = {} }
	for j = 1, lane.count do
		local along = (j - 1) * lane.step
		local left = lane.fromRight and lane.left + lane.width - lane.size - along or lane.left + along
		out.lane[j] = Box(left, lane.top, lane.size, lane.size)
	end
	return out
end

local function Key2(f, w, h, field, blocked, spots)
	local cfg = Settings.current
	local out = { f.kind, w, h, field.left, field.top, field.right, field.bottom, Widgets.Snap(f, 1) }
	for _, spot in ipairs(spots and spots.lane or {}) do
		out[#out + 1] = "l" .. spot.left .. ":" .. spot.top .. ":" .. spot.right
	end
	for _, b in ipairs(blocked) do
		out[#out + 1] = b.left .. ":" .. b.top .. ":" .. b.right .. ":" .. b.bottom
	end
	for i = 1, COUNT do
		local slot = cfg[Key(i)]
		out[#out + 1] = (Category(slot, f.kind) and (Slots.Helpful(slot.category) and "h" or "1") or "0") .. slot.position .. slot.size .. (slot.style == "BAR" and "b" or "")
	end
	return table.concat(out, "|")
end

local function Put(place, spot, w, h)
	local size = spot.right - spot.left
	local hs, vs = Share(place.point)
	place.size, place.fits = size, true
	place.x = spot.left + hs * size - hs * w
	place.y = -(spot.top + vs * size - vs * h)
end

local function Search(f, field, taken, fill, gap, slot, place)
	local wanted = place.size
	local size, spot = wanted, nil
	local floor, step = math.min(wanted, Geometry.LEGIBLE - Widgets.Snap(f, 1) / 2), Widgets.Snap(f, 1)
	step = step > 0 and step or 1
	local avoid = taken
	if fill and Slots.Helpful(slot.category) then
		avoid = { fill }
		for j = 1, #taken do
			avoid[j + 1] = taken[j]
		end
	end
	while size >= floor and not spot do
		spot = Find(field, avoid, place.point, size, gap)
		if not spot then
			size = size - step
		end
	end
	return spot
end

function Slots.Placements(f)
	local cfg = Settings.current
	seen[f.kind] = f
	local w, h = Style.Size(f)
	local field, blocked, gap, fill, heal = Field(f, w, h)
	local spots = Spots(f)
	local key = Key2(f, w, h, field, blocked, spots) .. (fill and "|fill" or "")
	if cache[key] then
		return cache[key]
	end
	local taken = {}
	for i, b in ipairs(blocked) do
		taken[i] = b
	end
	for _, spot in ipairs(spots and spots.lane or {}) do
		taken[#taken + 1] = spot
	end
	local out, order = {}, {}
	for i = 1, COUNT do
		order[i] = i
	end
	if not spots then
		table.sort(order, function(a, b)
			local ca, cb = Centredness(cfg[Key(a)].position), Centredness(cfg[Key(b)].position)
			if ca ~= cb then
				return ca < cb
			end
			return a < b
		end)
	end
	local lane, crowded = 1, false
	for _, i in ipairs(order) do
		local slot = cfg[Key(i)]
		local place = { point = slot.position, x = 0, y = 0, size = Widgets.Snap(f, Slots.Size(f, slot.size)), fits = false }
		if slot.style == "BAR" then
			place.fits = Category(slot, f.kind) ~= nil
			place.bar = place.fits
		elseif Category(slot, f.kind) then
			local spot
			while heal and spots and spots.lane[lane] and Overlaps(spots.lane[lane], heal) do lane, crowded = lane + 1, true end
			if spots and spots.lane[lane] then
				spot, lane = spots.lane[lane], lane + 1
			end
			if spot then
				local full = spot.right - spot.left
				if place.size < full then
					local inset = Widgets.Snap(f, (full - place.size) / 2)
					spot = Box(spot.left + full - place.size, spot.top + inset, place.size, place.size)
				end
				Put(place, spot, w, h)
			elseif crowded or not (f.parts and f.parts.tidyLanes) then
				spot = Search(f, field, taken, fill, gap, slot, place)
				if spot then
					taken[#taken + 1] = spot
					Put(place, spot, w, h)
				end
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

function Slots.Misfit(kind, i)
	local f = seen[kind]
	local slot = Settings.current[Key(i)]
	if not f or not f.parts or not Category(slot, kind) then
		return false
	end
	return not Slots.Placements(f)[i].fits
end

local EDGES = { TOPLEFT = "TOP", TOP = "TOP", TOPRIGHT = "TOP", BOTTOMLEFT = "BOTTOM", BOTTOM = "BOTTOM", BOTTOMRIGHT = "BOTTOM", LEFT = "LEFT", RIGHT = "RIGHT", CENTER = "CENTER" }
local ACROSS = { BOTTOM = "TOP", TOP = "BOTTOM", LEFT = "RIGHT", RIGHT = "LEFT" }

local function LineOn(f, edge)
	local p = Settings.current.prediction
	local shield = p.shield and Widgets.Border(f) * p.shieldLines or 0
	if p.shield and p.shieldPlace == edge then return shield end
	if p.healAbsorbLine and ACROSS[p.shieldPlace] == edge then return p.healAbsorbLines > 0 and Widgets.Border(f) * p.healAbsorbLines or Widgets.Border(f) * p.shieldLines end
	return 0
end

function Slots.Bar(f, slot)
	local health = f.parts.health
	local edge = EDGES[slot.position] or "BOTTOM"
	local upright = edge == "LEFT" or edge == "RIGHT"
	local line = LineOn(f, edge)
	local thick = math.min(slot.thick, (upright and health.width or health.height) - line)
	local left = edge == "RIGHT" and health.left + health.width - line - thick or edge == "LEFT" and health.left + line or health.left
	local top = edge == "BOTTOM" and health.top + health.height - line - thick or edge == "CENTER" and health.top + (health.height - thick) / 2 or edge == "TOP" and health.top + line or health.top
	return left, top, upright and thick or health.width, upright and health.height or thick, upright
end

local function Look(button, slot, upright)
	local p = Auras.Parts(button)
	local key = p and slot.style ~= "ICON" and table.concat({ slot.style, slot.color.r, slot.color.g, slot.color.b, tostring(slot.reverse), tostring(upright), Settings.current.health.texture }, ":")
	if not p or p.look == key then return end
	p.look = key or nil
	local c, bar = slot.color, slot.style == "BAR"
	if bar and type(button.SetDurationBar) ~= "function" then
		Style.LogOnce("slotBar", "aura buttons have no SetDurationBar; bar indicators stay squares")
		bar = false
	end
	if not bar and slot.style ~= "ICON" and not p.square then
		p.square = p.skin:CreateTexture(nil, "ARTWORK", nil, 1)
		p.square:SetAllPoints(p.icon)
		p.square:AddMaskTexture(p.mask)
	end
	if p.square then
		p.square:SetShown(not bar and slot.style ~= "ICON")
		p.square:SetColorTexture(c.r, c.g, c.b, 1)
	end
	p.skin:SetAlpha(bar and 0 or 1)
	if bar and not p.bar then
		p.bar = CreateFrame("StatusBar", nil, button)
		p.bar:SetAllPoints(button)
		p.bar.back = p.bar:CreateTexture(nil, "BACKGROUND")
		p.bar.back:SetAllPoints(p.bar)
		p.bar.back:SetColorTexture(Widgets.Rgba("black", BAR_BACK_ALPHA))
	end
	if not p.bar then return end
	p.bar:SetShown(bar)
	if bar then
		p.bar:SetStatusBarTexture(Settings.current.health.texture)
		p.bar:SetStatusBarColor(c.r, c.g, c.b, 1)
		p.bar:SetOrientation(upright and "VERTICAL" or "HORIZONTAL")
		p.bar:SetReverseFill(slot.reverse)
	end
	if bar ~= (p.timed == true) then
		local direction = Enum and Enum.StatusBarTimerDirection
		if bar then button:SetDurationBar(p.bar, direction and { direction = direction.RemainingTime } or nil) else button:ClearDurationBar() end
		p.timed = bar
	end
end

local function Place(f)
	local container = f.indicators
	local base = f:GetFrameLevel() + Auras.CONTAINER_LEVEL + SLOT_LEVEL
	local placements = Slots.Placements(f)
	for i = 1, COUNT do
		local button = container:GetAuraSlotFrame(Key(i))
		if button then
			local place, slot = placements[i], Settings.current[Key(i)]
			button:ClearAllPoints()
			if place.bar then
				local left, top, w, h, upright = Slots.Bar(f, slot)
				button:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, left + slot.x), -Widgets.Snap(f, top - slot.y))
				button:SetFrameLevel(slot.over and base + COUNT - i or f:GetFrameLevel() + Auras.CONTAINER_LEVEL)
				Auras.StyleIcon(button)
				Widgets.Size(button, Widgets.Snap(f, w), Widgets.Snap(f, h))
				Look(button, slot, upright)
			else
				button:SetPoint(place.point, f, place.point, place.x + Widgets.Snap(f, slot.x), place.y + Widgets.Snap(f, slot.y))
				button:SetFrameLevel(base + COUNT - i)
				Auras.StyleIcon(button)
				Widgets.Size(button, place.size, place.size)
				if slot.style ~= "ICON" or (Auras.Parts(button) or {}).look then Look(button, slot) end
			end
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
		local place, slot = placements[i], Settings.current[Key(i)]
		icon:ClearAllPoints()
		icon.tile.skin:SetAlpha(place.bar and 0 or 1)
		if place.bar and not icon.bar then
			icon.bar, icon.barBack = icon:CreateTexture(nil, "ARTWORK"), icon:CreateTexture(nil, "BACKGROUND")
			icon.barBack:SetAllPoints(icon)
			icon.barBack:SetColorTexture(Widgets.Rgba("black", BAR_BACK_ALPHA))
		end
		if icon.bar then
			icon.bar:SetShown(place.bar == true)
			icon.barBack:SetShown(place.bar == true)
		end
		if place.bar then
			local left, top, w, h, upright = Slots.Bar(f, slot)
			icon:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, left + slot.x), -Widgets.Snap(f, top - slot.y))
			icon:SetSize(Widgets.Snap(f, w), Widgets.Snap(f, h))
			icon.bar:ClearAllPoints()
			local from = upright and (slot.reverse and "TOP" or "BOTTOM") or (slot.reverse and "RIGHT" or "LEFT")
			icon.bar:SetPoint(from, icon, from)
			icon.bar:SetSize(Widgets.Snap(f, upright and w or w * SAMPLE_FILL), Widgets.Snap(f, upright and h * SAMPLE_FILL or h))
			icon.bar:SetColorTexture(slot.color.r, slot.color.g, slot.color.b, 1)
		else
			icon:SetPoint(place.point, f, place.point, place.x + Widgets.Snap(f, slot.x), place.y + Widgets.Snap(f, slot.y))
			icon:SetSize(place.size, place.size)
		end
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
		local category = Category(slot, f.kind)
		local on = category ~= nil and shows[slot.category] == true and placements[i].fits
		if on and slot.style == "SQUARE" then
			icon.tile.icon:SetColorTexture(slot.color.r, slot.color.g, slot.color.b, 1)
		elseif on then
			icon.tile.icon:SetTexture(category.icon)
		end
		icon:SetShown(on)
	end
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.changed[#Unit.changed + 1] = Bind
Unit.extra[#Unit.extra + 1] = Bind
