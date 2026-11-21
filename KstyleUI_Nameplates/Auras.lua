-- Auras.lua: the plate's debuffs: the player's harmful auras on the unit, found, sorted and shown by the AuraContainer engine, each timer in its own lane under its tile (counted in the row's spacing and the plate's extent), with a "+N" chip after the row that the engine's own layout counts, so it stays true in combat.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Overflow = Widgets.Overflow
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce

local Auras = {}
ns.Auras = Auras

local GROUP = "debuffs"
local OVERFLOW_MAX = 16
local TEMPLATE = "CustomAuraContainerTemplate"
local GAP = Tokens.Size("gapTiny")
local ICON_CROP = 0.07
local RINGS = { "black", "hostile", "black" }
local RING_LEVELS, DISPEL_LEVEL = { 1, 2, 4 }, 3
local OUT_X = { TOPRIGHT = 1, BOTTOMRIGHT = 1, TOPLEFT = -1, BOTTOMLEFT = -1, CENTER = 0 }
local OUT_Y = { TOPRIGHT = 1, TOPLEFT = 1, BOTTOMRIGHT = -1, BOTTOMLEFT = -1, CENTER = 0 }
local CUE_ALPHA, CUE_HEIGHT = 0.8, 2
local IN_FRONT = 100
local SWIPE_ALPHA = 0.65
local LINE_SLACK = 0.5
local RETRY_DELAY = 1
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local COUNT_STEP, COUNT_MIN = 3, 9
local COUNT_OUT_X, COUNT_OUT_Y = 1, 2
local BADGE_PAD, BADGE_ALPHA = 1, 0.62
local TIMER_GAP, TIMER_EXTRA = 1, 3
local SAMPLE_ICONS = { 136118, 135817, 132155 }
local SAMPLE_TIMES = { "12", "4", "21" }
local TEXT_KEYS = { "timePlace", "timeX", "timeY", "countPlace", "countX", "countY" }
local SUNDER_GROUP, SUNDER_ICON = "sunder", 132363
local SUNDER = { [7386] = true, [7405] = true, [8380] = true, [11596] = true, [11597] = true }
local KINDS = {
	buffs = { ring = "edgeInner", magic = { [135940] = true, [135953] = true },
		icons = { important = { 135940, 135932 }, dispellable = { 135940, 135953 }, all = { 135940, 135932, 135987, 136104 } } },
	ccs = { ring = "hostile", icons = { 135963, 136071 }, filter = "HARMFUL|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY" },
}
local KIND_ORDER, CC_FIRST = { "buffs", "ccs" }, { "ccs", "buffs" }
local BUFF_FILTERS = { important = "HELPFUL|IMPORTANT|INCLUDE_NAME_PLATE_ONLY", dispellable = "HELPFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY", all = "HELPFUL|INCLUDE_NAME_PLATE_ONLY" }
local PLACES = {
	LEFT = { "RIGHT", "LEFT", "TOPRIGHT", "Left", -1, 0 }, RIGHT = { "LEFT", "RIGHT", "TOPLEFT", "Right", 1, 0 },
	TOP = { "BOTTOM", "TOP", "BOTTOMLEFT", "Right", 0, 1 }, TOPLEFT = { "BOTTOMLEFT", "TOPLEFT", "BOTTOMLEFT", "Right", 0, 1 },
	TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "Left", 0, 1 }, BOTTOM = { "TOP", "BOTTOM", "TOPLEFT", "Right", 0, -1 },
}

local available, refused = true, {}
local parts = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local flushScheduled = false
local ScheduleFlush

local function AurasSecret()
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		return not ok or IsSecret(secret) or secret == true
	end
	return InCombatLockdown()
end

local function Grid(frame)
	local raw = Settings.Get("debuffs.size")
	local size = Widgets.Snap(frame, raw)
	local spacing = Widgets.Snap(frame, Settings.Get("debuffs.spacing"))
	local height = Settings.Get("debuffs.cropped") and Widgets.Snap(frame, raw * (1 - Settings.Get("debuffs.crop") / 50)) or size
	return size, spacing, Settings.Get("debuffs.columns"), Settings.Get("debuffs.rows"), height
end
Auras.GROUP, Auras.OVERFLOW_MAX, Auras.Grid = GROUP, OVERFLOW_MAX, Grid

local function SettingsLane(frame, kind)
	if not Settings.Get((kind or "debuffs") .. ".showTime") or Settings.Get("debuffs.timePlace") ~= "BELOW" then
		return 0
	end
	local lane = TIMER_GAP + Settings.Get("debuffs.textSize") + TIMER_EXTRA
	return frame and Widgets.Snap(frame, lane) or lane
end

local function Lane(frame)
	return frame and frame.timerLane or SettingsLane(frame)
end
Auras.Lane = Lane

local ORDERS = {
	important = { "ImportantOnly", "Normal" },
	longest = { "ExpirationOnly", "Reverse" },
	expiring = { "Expiration", "Normal" },
	default = { "Default", "Normal" },
}

local function SortOptions()
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if not (methods and directions) then
		return nil
	end
	local order = ORDERS[Settings.Get("debuffs.order")] or ORDERS.default
	local method, direction = methods[order[1]], directions[order[2]]
	if method == nil or direction == nil then
		LogOnce("aura-order", "this client lacks the " .. order[1] .. " aura sort; debuffs keep the engine's default order")
		return methods.Default, directions.Normal
	end
	return method, direction
end

local function GroupLayout(plate)
	local size, spacing, _, _, height = Grid(plate)
	return { elementSpacing = spacing, lineSpacing = spacing + Lane(plate), elementWidth = size, elementHeight = height }
end

local function KindShows(plate, kind)
	return Settings.Get(kind .. ".enabled") and plate.kind == "enemy" and not plate.nameOnly
end

local function Filter(plate)
	local filter = Settings.Get("debuffs.onlyMine") and "HARMFUL|PLAYER" or "HARMFUL"
	if Settings.Get("debuffs.includePlateOnly") then filter = filter .. "|INCLUDE_NAME_PLATE_ONLY" end
	if KindShows(plate, "ccs") and not refused.ccs then filter = filter .. "|!CROWD_CONTROL" end
	return K.Options.AuraFilterString({ dispellable = Settings.Get("debuffs.dispellable") }, filter)
end

function Auras.Warrior()
	local class = type(UnitClass) == "function" and select(2, UnitClass("player"))
	return not IsSecret(class) and class == "WARRIOR"
end

local function Sunder()
	return Settings.Get("debuffs.sunder") and Settings.Get("debuffs.onlyMine") and Auras.Warrior()
end

local function Cap()
	return Settings.Get("debuffs.columns") * Settings.Get("debuffs.rows") - (Sunder() and 1 or 0)
end

local function KindFilter(kind)
	return KINDS[kind].filter or BUFF_FILTERS[Settings.Get("buffs.filter")]
end

local function Candidates()
	return K.Options.AuraCandidates({ allowSpells = Settings.Get("debuffs.allowSpells"), blockSpells = Settings.Get("debuffs.blockSpells") })
end

local function StyleText(text, size)
	local flags = OUTLINE_FLAGS[Settings.Get("debuffs.outline")] or "OUTLINE"
	size = size or Settings.Get("debuffs.textSize")
	local font = Settings.Get("debuffs.readableText") and Tokens.Font("number") or Settings.Get("font")
	if not Widgets.ApplyFont(text, font, size, flags) then
		Widgets.ApplyFont(text, (Tokens.Font("world")), size, flags)
	end
end

local function NewTile(owner, kind)
	local skin = CreateFrame("Frame", nil, owner)
	skin:SetAllPoints(owner)
	local rings = {}
	for i, color in ipairs(RINGS) do
		local ring = Widgets.Crisp(skin:CreateTexture(nil, "BACKGROUND", nil, RING_LEVELS[i]))
		ring:SetColorTexture(Tokens.Color(i == 2 and KINDS[kind] and KINDS[kind].ring or color))
		rings[i] = ring
	end
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	return { skin = skin, icon = icon, rings = rings, bare = false, crop = 0, kind = kind or "debuffs" }
end

local function Inset(region, skin, inset)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	region:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
end

local function LayoutTile(tile)
	local skin = tile.skin
	local px = K.Scale.Pixel(1) / Widgets.ScaleFactor(skin)
	local bare = not Settings.Get("debuffs.border")
	for i, ring in ipairs(tile.rings) do
		Inset(ring, skin, px * (i - 1))
		if bare ~= tile.bare then ring:SetShown(not bare) end
	end
	tile.bare = bare
	if tile.dispel then Inset(tile.dispel, skin, tile.kind == "buffs" and -2 * px or px) end
	Inset(tile.icon, skin, bare and 0 or px * #tile.rings)
	local crop = Settings.Get("debuffs.cropped") and Settings.Get("debuffs.crop") / 100 or 0
	if crop ~= tile.crop then
		tile.crop = crop
		local edge = 0.5 - (0.5 - ICON_CROP) * (1 - 2 * crop)
		tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, edge, 1 - edge)
	end
end

local function AddTexts(tile, owner, level)
	local textFrame = CreateFrame("Frame", nil, owner)
	textFrame:SetAllPoints(owner)
	textFrame:SetFrameLevel(level)
	local countHolder = CreateFrame("Frame", nil, textFrame)
	countHolder:SetAllPoints(textFrame)
	local count = Widgets.Fitted(Widgets.FontString(countHolder, "OVERLAY"))
	count:SetJustifyH("RIGHT")
	local badge = countHolder:CreateTexture(nil, "BACKGROUND")
	local pad = Widgets.Snap(countHolder, BADGE_PAD)
	badge:SetPoint("TOPLEFT", count, "TOPLEFT", -pad, pad)
	badge:SetPoint("BOTTOMRIGHT", count, "BOTTOMRIGHT", pad, -pad)
	badge:SetColorTexture(Widgets.Rgba("black", BADGE_ALPHA))
	local timeHolder = CreateFrame("Frame", nil, textFrame)
	timeHolder:SetAllPoints(textFrame)
	local time = Widgets.FontString(timeHolder, "OVERLAY")
	time:SetJustifyH("CENTER")
	tile.count, tile.time, tile.countHolder, tile.timeHolder, tile.over = count, time, countHolder, timeHolder, textFrame
end

local function StyleTexts(p, size)
	local place, x, y = Settings.Get("debuffs.countPlace"), Settings.Get("debuffs.countX"), Settings.Get("debuffs.countY")
	p.count:ClearAllPoints()
	p.count:SetPoint(place, p.countHolder, place, Widgets.Snap(p.countHolder, COUNT_OUT_X) * OUT_X[place] + Widgets.Snap(p.countHolder, x),
		Widgets.Snap(p.countHolder, COUNT_OUT_Y) * OUT_Y[place] + Widgets.Snap(p.countHolder, y))
	StyleText(p.count, math.max(COUNT_MIN, Settings.Get("debuffs.textSize") - COUNT_STEP))
	StyleText(p.time)
	place, x, y = Settings.Get("debuffs.timePlace"), Widgets.Snap(p.skin, Settings.Get("debuffs.timeX")), Widgets.Snap(p.skin, Settings.Get("debuffs.timeY"))
	p.time:ClearAllPoints()
	if place == "BELOW" then
		p.time:SetPoint("TOP", p.timeHolder, "BOTTOM", Widgets.Snap(p.skin, size / 2) - size / 2 + x, -Widgets.Snap(p.skin, TIMER_GAP) + y)
	else
		p.time:SetPoint(place, p.timeHolder, place, x, y)
	end
	p.countHolder:SetShown(Settings.Get("debuffs.showCount"))
	p.timeHolder:SetShown(Settings.Get(p.kind .. ".showTime"))
end

local function Cue(p)
	if not p.cue then
		p.cue = (p.cooldown and p.over or p.skin):CreateTexture(nil, "OVERLAY")
		p.cue:SetColorTexture(Widgets.Rgba("capsGold", CUE_ALPHA))
		p.cue:Hide()
	end
	local px = Widgets.Snap(p.skin, CUE_HEIGHT)
	p.cue:SetHeight(px)
	p.cue:ClearAllPoints()
	p.cue:SetPoint("BOTTOMLEFT", p.skin, "BOTTOMLEFT", px, 0)
	p.cue:SetPoint("BOTTOMRIGHT", p.skin, "BOTTOMRIGHT", -px, 0)
	return p.cue
end

local function Dispel(p)
	if not p.dispel then
		local glow = p.kind == "buffs"
		p.dispel = p.skin:CreateTexture(nil, "BACKGROUND", nil, glow and 0 or DISPEL_LEVEL)
		if not glow then Widgets.Crisp(p.dispel) end
		p.dispel:SetColorTexture(Tokens.Color("white"))
		Inset(p.dispel, p.skin, (glow and -2 or 1) * K.Scale.Pixel(1) / Widgets.ScaleFactor(p.skin))
	end
	return p.dispel
end

local dispelOptions
local function DispelOptions(kind)
	if dispelOptions == nil then
		local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
		dispelOptions = styles and styles.PreserveAsset ~= nil and { style = styles.PreserveAsset, showWhenHarmful = true } or false
		if not dispelOptions then
			LogOnce("aura-dispel", "Enum.CustomAuraButtonDispelTypeTextureStyle is missing; aura tiles show no dispel colour")
		else
			dispelOptions.buffs = { style = dispelOptions.style, showWhenHelpful = true, showWhenHarmful = false }
		end
	end
	return dispelOptions and (kind == "buffs" and dispelOptions.buffs or dispelOptions) or nil
end

local function Cues(button, p)
	local buffs = p.kind == "buffs"
	local dispel = (buffs and Settings.Get("buffs.dispelGlow") or not buffs and Settings.Get("debuffs.dispelColor") and Settings.Get("debuffs.border")) and DispelOptions(p.kind) ~= nil
	if dispel ~= (p.dispelBound == true) and type(button.AddDispelTypeTexture) == "function" and type(button.RemoveDispelTypeTexture) == "function" then
		if dispel then
			button:AddDispelTypeTexture(Dispel(p), DispelOptions(p.kind))
		else
			button:RemoveDispelTypeTexture(p.dispel)
			p.dispel:Hide()
		end
		p.dispelBound = dispel
	end
	local cue = Settings.Get("debuffs.pandemic") and p.kind == "debuffs"
	if cue ~= (p.cueBound == true) and type(button.AddPandemicRegion) == "function" and type(button.RemovePandemicRegion) == "function" then
		if cue then
			button:AddPandemicRegion(Cue(p))
		else
			button:RemovePandemicRegion(p.cue)
			p.cue:Hide()
		end
		p.cueBound = cue
	end
	local tooltips = Settings.Get("debuffs.tooltips")
	if tooltips ~= (p.tooltips == true) and type(button.SetMouseMotionEnabled) == "function" then
		button:SetMouseMotionEnabled(tooltips)
		p.tooltips = tooltips
	end
end

local function StyleButton(button)
	local p = parts[button]
	if not p then
		return
	end
	local size, _, _, _, height = Grid(p.skin)
	local endings = K.Appearance.Get("auraEndings")
	if p.cooldown and type(p.cooldown.SetDrawBling) == "function" then
		p.cooldown:SetDrawBling(not endings)
	end
	button:SetSize(size, height)
	LayoutTile(p)
	StyleTexts(p, size)
	button:SetDurationText(p.time, {
		textFormatter = endings and Widgets.Duration.Formatter("short", true) or nil,
		textColor = Widgets.Duration.ExpiringColor(Settings.Get("debuffs.expiring")),
	})
	Cues(button, p)
end

local function BuildButton(button, kind)
	if not pcall(button.EnableMouse, button, false) then
		LogOnce("aura-mouse", "aura buttons refused EnableMouse(false); debuff icons may catch clicks")
	end
	local tile = NewTile(button, kind)
	local cooldown = CreateFrame("Cooldown", nil, tile.skin)
	cooldown:SetAllPoints(tile.icon)
	cooldown:SetSwipeTexture((Tokens.Texture("barFlat")))
	cooldown:SetDrawEdge(false)
	cooldown:SetReverse(true)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	AddTexts(tile, button, cooldown:GetFrameLevel() + 1)
	tile.cooldown = cooldown
	parts[button] = tile
	StyleButton(button)
	button:SetIcon(tile.icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(tile.count)
end

local inits = {}
local function InitButton(kind)
	inits[kind] = inits[kind] or function(button)
		local ok, err = pcall(BuildButton, button, kind)
		if not ok then
			LogOnce("aura-button", "building an aura button failed: " .. tostring(err))
		end
	end
	return inits[kind]
end

local function GroupOptions(plate)
	local options = {
		maxFrameCount = Cap(),
		initializeFrame = InitButton("debuffs"),
		layout = GroupLayout(plate),
		candidateFilters = Candidates(),
	}
	options.sortMethod, options.sortDirection = SortOptions()
	return options
end

local function SyncSunder(plate, container)
	local on = Sunder()
	if plate.sunderGroup then
		container:SetAuraGroupEnabled(SUNDER_GROUP, on)
		if on then container:SetAuraGroupLayout(SUNDER_GROUP, GroupLayout(plate)) end
	elseif on then
		local ok, err = pcall(container.AddAuraGroup, container, SUNDER_GROUP, "HARMFUL|!PLAYER",
			{ maxFrameCount = 1, initializeFrame = InitButton("debuffs"), layout = GroupLayout(plate), candidateFilters = { includeSpellIDs = SUNDER } })
		plate.sunderGroup = ok
		if not ok then LogOnce("aura-sunder", "the Sunder Armor group could not be added: " .. tostring(err)) end
	end
end

local function Bind(plate, unit)
	local container = plate.auras
	if not container or plate.aurasUnit == unit then
		return
	end
	local ok, err = pcall(container.SetUnit, container, unit)
	if ok and plate.auraChip then
		ok, err = pcall(Overflow.SetUnit, plate.auraChip, unit)
	end
	if ok then
		plate.aurasUnit = unit
	else
		LogOnce("aura-unit", "the debuff container refused a unit: " .. tostring(err))
	end
end

local function NewContainer(plate)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, plate, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		if InCombatLockdown() then
			LogOnce("aura-combat", "the debuff container could not be made in combat; it waits for combat to end")
			if not plate.aurasRetry then
				plate.aurasRetry = true
				K.Combat.Queue(function()
					plate.aurasRetry = false
					if plate.unit then
						plate:Refresh()
					end
				end)
			end
		else
			available = false
			LogOnce("aura-missing", "the AuraContainer engine (" .. TEMPLATE .. ") is unavailable, so plates show no debuffs: " .. tostring(container))
		end
		return nil
	end
	if type(container.SetEditModePreviewEnabled) == "function" then
		pcall(container.SetEditModePreviewEnabled, container, false)
	end
	local added, err = pcall(container.AddAuraGroup, container, GROUP, Filter(plate), GroupOptions(plate))
	if not added then
		container:Hide()
		available = false
		LogOnce("aura-group", "the debuff group could not be added: " .. tostring(err))
		return nil
	end
	K.DevTest.Log(Settings.MODULE, "nameplate debuffs run on the AuraContainer engine")
	local chip, why = Overflow.New(plate, "none", Filter(plate), Cap(), { labels = OVERFLOW_MAX })
	if chip then
		plate.auraChip = chip
	else
		LogOnce("aura-chip", "the overflow chip has no counting container (" .. tostring(why) .. "); a full row shows no +N")
	end
	return container
end

local function RestyleGroup(container, key)
	for i = 1, container:GetAuraGroupFrameCount(key) do
		local ok, err = pcall(StyleButton, container:GetAuraGroupFrame(key, i))
		if not ok then
			LogOnce("aura-style", "restyling an aura button failed: " .. tostring(err))
			return
		end
	end
end

local function RestyleNow(plate)
	if plate.auras then
		RestyleGroup(plate.auras, GROUP)
		if plate.sunderGroup then RestyleGroup(plate.auras, SUNDER_GROUP) end
	end
	if plate.kinds then
		for kind, container in pairs(plate.kinds) do RestyleGroup(container, kind) end
	end
end

local LayoutContainer

local function Flush()
	flushScheduled = false
	if AurasSecret() then
		ScheduleFlush()
		return
	end
	for plate in pairs(pending) do
		pending[plate] = nil
		if plate.auras then
			LayoutContainer(plate)
		else
			RestyleNow(plate)
		end
	end
end

function ScheduleFlush()
	if flushScheduled then
		return
	end
	if InCombatLockdown() then
		flushScheduled = true
		K.Combat.Queue(Flush)
	elseif C_Timer and C_Timer.After then
		flushScheduled = true
		C_Timer.After(RETRY_DELAY, Flush)
	else
		LogOnce("aura-timer", "C_Timer.After is missing; aura buttons restyle at the next settings change")
	end
end

local function RestyleButtons(plate)
	if AurasSecret() then
		pending[plate] = true
		ScheduleFlush()
		return
	end
	RestyleNow(plate)
end

local function Shows(plate)
	return Settings.Get("debuffs.enabled") and not plate.nameOnly
end

local function RoomAbove(plate)
	if Settings.Get("name.show") and not plate.nameOnly then
		return ns.Plate.NAME_GAP + (plate.subtitleRoom or 0) + (plate.whoSize or Settings.Get("name.size")) + Settings.Get("debuffs.nameGap") + ns.Resource.Room(plate, "TOP")
			+ ns.Plate.QuestRise(plate)

	end
	return GAP + ns.Resource.Room(plate, "TOP")
end

local function RoomBelow(plate)
	local room = GAP
	for _, component in ipairs(ns.Components) do
		if component.Room then
			room = room + component.Room(plate)
		end
	end
	return room
end

local LayoutChip

local function AnchorTo(plate, anchor)
	local left = anchor:find("LEFT$") ~= nil
	if anchor:find("^BOTTOM") then
		return left and "TOPLEFT" or "TOPRIGHT", Widgets.Snap(plate, RoomAbove(plate)) + Lane(plate)
	end
	return left and "BOTTOMLEFT" or "BOTTOMRIGHT", -Widgets.Snap(plate, RoomBelow(plate))
end

local function Anchor(plate, frame, anchor)
	local relPoint, y = AnchorTo(plate, anchor)
	frame:ClearAllPoints()
	frame:SetPoint(anchor, plate.health, relPoint, 0, Widgets.Snap(plate, y))
end

local function DebuffExtent(plate, rowsCap)
	local above, below = RoomAbove(plate), RoomBelow(plate)
	if not Shows(plate) then
		return above, below
	end
	local _, spacing, _, rows, height = Grid(plate)
	if rowsCap then
		rows = math.min(rows, rowsCap)
	end
	local block = rows * (height + Lane(plate)) + (rows - 1) * spacing
	if Settings.Get("debuffs.growthY") == "DOWN" then
		return above, below + block
	end
	return above + block, below
end

local function Span(kind, size, spacing)
	local place, half = Settings.Get(kind .. ".place"), ns.state.width / 2
	local row = Logic.AuraLineSize(Settings.Get(kind .. ".count"), size, spacing)
	local left = place == "TOPLEFT" and -half or place == "TOPRIGHT" and half - row or -row / 2
	return left, left + row
end

local function KindSpot(plate, kind)
	local size, spacing, _, _, height = Grid(plate)
	local place, step = Settings.Get(kind .. ".place"), 0
	local v, left, right = PLACES[place][6], Span(kind, size, spacing)
	for _, other in ipairs(Settings.Get("ccs.first") and CC_FIRST or KIND_ORDER) do
		if other == kind then break end
		local there, l, r = Settings.Get(other .. ".place"), Span(other, size, spacing)
		if KindShows(plate, other) and (there == place or v ~= 0 and PLACES[there][6] == v and l < right and left < r) then
			step = step + (PLACES[place][5] ~= 0 and Settings.Get(other .. ".count") * (size + spacing) or height + SettingsLane(plate, other) + spacing)
		end
	end
	return place, step, size, spacing, height
end

local function SideReach(plate, sign, bare)
	local Plate = ns.Plate
	local reach
	if sign < 0 then
		reach = (Settings.Get("level.show") or Settings.Get("markers.classification")) and Plate.DiamondReach(plate) or Plate.MarkerReach()
	else
		reach = Plate.MarkerReach() + (Settings.Get("markers.raid") and Settings.Get("markers.raidSize") + GAP or 0)
	end
	local icon = ns.Cast.FullIcon(plate, sign)
	if not icon then return reach end
	reach = math.max(reach, sign < 0 and ns.Cast.BadgeReach(plate) or 0) + GAP
	return bare and reach or reach + icon
end

Auras.SideReach = SideReach

local function PlaceKind(plate, kind, frame)
	local place, step, _, spacing = KindSpot(plate, kind)
	local spot = PLACES[place]
	local x, y = 0, 0
	if spot[5] ~= 0 then
		x = spot[5] * (SideReach(plate, spot[5]) + GAP + step)
	else
		local above, below = DebuffExtent(plate)
		y = spot[6] > 0 and above + spacing + step + SettingsLane(plate, kind) or -(below + spacing + step)
	end
	frame:ClearAllPoints()
	frame:SetPoint(spot[1], plate.health, spot[2], Widgets.Snap(plate, x), Widgets.Snap(plate, y))
	return spot
end

local function AnyKind()
	return Settings.Get("buffs.enabled") or Settings.Get("ccs.enabled")
end

function Auras.Extent(plate, rowsCap)
	local above, below = DebuffExtent(plate, rowsCap)
	if not AnyKind() then return above, below end
	local up, down = 0, 0
	for _, kind in ipairs(KIND_ORDER) do
		if KindShows(plate, kind) then
			local place, step, _, spacing, height = KindSpot(plate, kind)
			local lane, v = SettingsLane(plate, kind), PLACES[place][6]
			if v > 0 then
				up = math.max(up, spacing + step + lane + height)
			elseif v < 0 then
				down = math.max(down, spacing + step + height + lane)
			else
				local over = (height - ns.state.height) / 2
				above, below = math.max(above, over), math.max(below, over + lane)
			end
		end
	end
	return above + up, below + down
end

function Auras.Reach(plate)
	local left, right = 0, 0
	if not AnyKind() then return left, right end
	for _, kind in ipairs(KIND_ORDER) do
		if KindShows(plate, kind) then
			local place, step, size, spacing = KindSpot(plate, kind)
			local sign = PLACES[place][5]
			if sign ~= 0 then
				local reach = SideReach(plate, sign) + GAP + step + Settings.Get(kind .. ".count") * (size + spacing) - spacing
				if sign < 0 then left = math.max(left, reach) else right = math.max(right, reach) end
			end
		end
	end
	return left, right
end

local function StyleChipText(text)
	StyleText(text)
	text:SetTextColor(Tokens.Color("textEmphasis"))
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
end

function LayoutChip(plate, anchor, size, spacing, columns)
	local chip = plate.auraChip
	if not chip then
		return
	end
	local relPoint, y = AnchorTo(plate, anchor)
	local sign = Settings.Get("debuffs.growthX") == "LEFT" and -1 or 1
	Overflow.Apply(chip, {
		enabled = Shows(plate), groups = { { filter = Filter(plate), candidates = Candidates() } }, cap = Cap(), cell = size, after = true,
		point = anchor, rel = plate.health, relPoint = relPoint, x = sign * (Logic.AuraLineSize(columns, size, spacing) + spacing), y = y,
		level = plate.auras:GetFrameLevel() + 2, style = StyleChipText,
	})
end

local function ShowChip(plate, on)
	local chip = plate.auraChip
	if chip then
		chip.window:SetShown(on)
		Overflow.Enable(chip, on)
	end
end

function LayoutContainer(plate)
	local lane = SettingsLane(plate)
	if AurasSecret() then
		lane = math.max(plate.timerLane or 0, lane)
	end
	plate.timerLane = lane
	local container = plate.auras
	local size, spacing, columns = Grid(plate)
	local anchor, horizontal, vertical = Logic.AuraGrowth(Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local direction = AnchorUtil and AnchorUtil.FlowDirection
	if not (axis and direction) then
		LogOnce("aura-anchor", "AnchorUtil is missing; debuffs keep the engine's default layout")
	else
		container:SetFlowLayoutAxis(axis.Horizontal)
		container:SetFlowLayoutAnchorPoint(anchor)
		container:SetFlowLayoutGrowthDirection(direction[horizontal], direction[vertical])
		container:SetFlowLayoutMaximumLineSize(Logic.AuraLineSize(columns, size, spacing) + LINE_SLACK)
	end
	container:SetAuraGroupLayout(GROUP, GroupLayout(plate))
	container:SetAuraGroupMaxFrameCount(GROUP, Cap())
	SyncSunder(plate, container)
	container:SetAuraGroupFilterString(GROUP, Filter(plate))
	if type(container.SetAuraGroupCandidateFilters) == "function" then
		container:SetAuraGroupCandidateFilters(GROUP, Candidates())
	end
	local method, order = SortOptions()
	if method ~= nil then
		container:SetAuraGroupSortMethod(GROUP, method, order)
	end
	local raise = Settings.Get("debuffs.raise")
	if raise or plate.aurasRaised then
		plate.aurasRaised = raise
		container:SetFrameLevel(plate:GetFrameLevel() + (raise and IN_FRONT or 1))
	end
	Anchor(plate, container, anchor)
	LayoutChip(plate, anchor, size, spacing, columns)
	RestyleButtons(plate)
end

local function LayoutKind(plate, kind, container)
	local spot = PlaceKind(plate, kind, container)
	local size, spacing = Grid(plate)
	local count = Settings.Get(kind .. ".count")
	local axis, direction = AnchorUtil and AnchorUtil.FlowLayoutAxis, AnchorUtil and AnchorUtil.FlowDirection
	if axis and direction then
		container:SetFlowLayoutAxis(axis.Horizontal)
		container:SetFlowLayoutAnchorPoint(spot[3])
		container:SetFlowLayoutGrowthDirection(direction[spot[4]], direction.Down)
		container:SetFlowLayoutMaximumLineSize(Logic.AuraLineSize(count, size, spacing) + LINE_SLACK)
	end
	container:SetAuraGroupLayout(kind, GroupLayout(plate))
	container:SetAuraGroupMaxFrameCount(kind, count)
	container:SetAuraGroupFilterString(kind, KindFilter(kind))
	local raise = Settings.Get("debuffs.raise")
	if raise or container.raised then
		container.raised = raise
		container:SetFrameLevel(plate:GetFrameLevel() + (raise and IN_FRONT or 1))
	end
end

local function NewKind(plate, kind)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, plate, TEMPLATE)
	local added, err = ok and type(container) == "table" and type(container.AddAuraGroup) == "function", container
	if added then
		if type(container.SetEditModePreviewEnabled) == "function" then pcall(container.SetEditModePreviewEnabled, container, false) end
		added, err = pcall(container.AddAuraGroup, container, kind, KindFilter(kind),
			{ maxFrameCount = Settings.Get(kind .. ".count"), initializeFrame = InitButton(kind), layout = GroupLayout(plate) })
		if not added then container:Hide() end
	end
	if added then return container end
	LogOnce("aura-" .. kind, "the " .. kind .. " container could not be made: " .. tostring(err))
	if not InCombatLockdown() then
		refused[kind] = true
	elseif not plate.kindsRetry then
		plate.kindsRetry = true
		K.Combat.Queue(function()
			plate.kindsRetry = nil
			if plate.unit then plate:Refresh() end
		end)
	end
end

local function RefreshKinds(plate)
	local moved = false
	for _, kind in ipairs(KIND_ORDER) do
		local container = plate.kinds and plate.kinds[kind]
		local unit = plate.unit and KindShows(plate, kind) and plate.unit or "none"
		if unit ~= "none" and not container and not plate.kindsRetry and not refused[kind] then
			container = NewKind(plate, kind)
			if container then
				plate.kinds, plate.kindUnits = plate.kinds or {}, plate.kindUnits or {}
				plate.kinds[kind] = container
				LayoutKind(plate, kind, container)
				RestyleButtons(plate)
			end
		end
		local was = container and plate.kindUnits[kind]
		if container and was ~= unit then
			local ok, err = pcall(container.SetUnit, container, unit)
			plate.kindUnits[kind] = ok and unit or nil
			container:SetShown(unit ~= "none")
			moved = moved or (was == nil or was == "none") ~= (unit == "none")
			if not ok then LogOnce("aura-kind-unit", "an aura container refused a unit: " .. tostring(err)) end
		end
	end
	if moved then
		if plate.auras then plate.auras:SetAuraGroupFilterString(GROUP, Filter(plate)) end
		Auras.Reanchor(plate)
		if plate.rise then ns.Stacking.Bound(plate, plate.rise) end
	end
end

local function KindSamples(plate)
	for _, kind in ipairs(KIND_ORDER) do
		local shown = KindShows(plate, kind)
		local holder = plate.sampleKinds and plate.sampleKinds[kind]
		if shown and not holder then
			holder = CreateFrame("Frame", nil, plate)
			holder.icons = {}
			plate.sampleKinds = plate.sampleKinds or {}
			plate.sampleKinds[kind] = holder
		end
		if holder then
			holder:SetShown(shown)
			if shown then
				local size, spacing, _, _, height = Grid(plate)
				local n, icons = Settings.Get(kind .. ".count"), KINDS[kind].icons
				icons = icons[Settings.Get("buffs.filter")] or icons
				for i = #holder.icons + 1, n do
					local frame = CreateFrame("Frame", nil, holder)
					frame.tile = NewTile(frame, kind)
					AddTexts(frame.tile, frame.tile.skin, frame.tile.skin:GetFrameLevel() + 1)
					frame.tile.time:SetText(SAMPLE_TIMES[(i - 1) % #SAMPLE_TIMES + 1])
					holder.icons[i] = frame
				end
				local spot = PlaceKind(plate, kind, holder)
				Widgets.Size(holder, Logic.AuraLineSize(n, size, spacing), height)
				for i, icon in ipairs(holder.icons) do
					local tile, fileID = icon.tile, icons[(i - 1) % #icons + 1]
					tile.icon:SetTexture(fileID)
					Widgets.Size(icon, size, height)
					icon:ClearAllPoints()
					icon:SetPoint(spot[3], holder, spot[3], (spot[4] == "Left" and -1 or 1) * (i - 1) * (size + spacing), 0)
					icon:SetShown(i <= n)
					LayoutTile(tile)
					StyleTexts(tile, size)
					local glow = kind == "buffs" and Settings.Get("buffs.dispelGlow") and KINDS.buffs.magic[fileID] or false
					if glow or tile.dispel then
						Dispel(tile):SetVertexColor(Tokens.Color("magic"))
						tile.dispel:SetShown(glow)
					end
				end
			end
		end
	end
end

local function SampleTexts(tile, i, size)
	local texts = false
	for _, key in ipairs(TEXT_KEYS) do
		if Settings.Get("debuffs." .. key) ~= Settings.defaults.debuffs[key] then texts = true end
	end
	if texts and not tile.time then
		AddTexts(tile, tile.skin, tile.skin:GetFrameLevel() + 1)
		tile.time:SetText(SAMPLE_TIMES[i])
		tile.count:SetText(i == 1 and "3" or "")
	end
	if tile.time then
		tile.over:SetShown(texts)
		StyleTexts(tile, size)
	end
	local cue = Settings.Get("debuffs.pandemic") and i == 2
	if cue or tile.cue then Cue(tile):SetShown(cue) end
	local dispel = Settings.Get("debuffs.dispelColor") and Settings.Get("debuffs.border") and i == 1
	if dispel or tile.dispel then
		Dispel(tile):SetVertexColor(Tokens.Color("magic"))
		tile.dispel:SetShown(dispel)
	end
end

local function LayoutSamples(plate)
	local icons = plate.sampleAuras
	local size, spacing, columns, rows, height = Grid(plate)
	local anchor = Logic.AuraGrowth(Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
	local holder = plate.sampleAuraHolder
	Widgets.Size(holder, size, height)
	Anchor(plate, holder, anchor)
	local shown = Shows(plate)
	local texts = plate ~= ns.Preview.samplePlate
	for i, icon in ipairs(icons) do
		Widgets.Size(icon, size, height)
		local x, y = Logic.AuraOffset(i, columns, size, spacing, Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"), Lane(plate), height)
		icon:ClearAllPoints()
		icon:SetPoint(anchor, holder, anchor, x, y)
		icon:SetShown(shown and i <= columns * rows)
		LayoutTile(icon.tile)
		if texts then SampleTexts(icon.tile, i, size) end
	end
	local last = icons[#icons]
	local sunder = Sunder()
	if sunder or last.sunder then
		last.sunder = sunder
		last.icon:SetTexture(last.sunder and SUNDER_ICON or SAMPLE_ICONS[#icons])
	end
	if texts and (plate.sampleKinds or AnyKind()) then KindSamples(plate) end
end

local function BuildSamples(plate)
	local holder = CreateFrame("Frame", nil, plate)
	plate.sampleAuraHolder = holder
	plate.sampleAuras = {}
	for i, fileID in ipairs(SAMPLE_ICONS) do
		local frame = CreateFrame("Frame", nil, holder)
		local tile = NewTile(frame)
		tile.icon:SetTexture(fileID)
		frame.tile, frame.icon = tile, tile.icon
		plate.sampleAuras[i] = frame
	end
end

function Auras.Reanchor(plate)
	if plate.sample then
		LayoutSamples(plate)
		return
	end
	if plate.auras then
		local size, spacing, columns = Grid(plate)
		local anchor = Logic.AuraGrowth(Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
		Anchor(plate, plate.auras, anchor)
		LayoutChip(plate, anchor, size, spacing, columns)
	end
	if plate.kinds then
		for kind, container in pairs(plate.kinds) do PlaceKind(plate, kind, container) end
	end
end

local Component = { events = {} }
ns.Components[#ns.Components + 1] = Component

function Component.Build(plate)
	if plate.sample then
		BuildSamples(plate)
	end
end

function Component.Restyle(plate)
	if plate.sample then
		LayoutSamples(plate)
		return
	end
	if plate.auras then
		LayoutContainer(plate)
	end
	if plate.kinds then
		for kind, container in pairs(plate.kinds) do LayoutKind(plate, kind, container) end
		if not plate.auras then RestyleButtons(plate) end
	end
end

function Component.Refresh(plate)
	if plate.sample then
		LayoutSamples(plate)
		return
	end
	if plate.kinds or AnyKind() then RefreshKinds(plate) end
	if not (plate.unit and Shows(plate)) then
		if plate.auras then
			Bind(plate, "none")
			plate.auras:Hide()
		end
		ShowChip(plate, false)
		return
	end
	if not plate.auras and available and not plate.aurasRetry then
		plate.auras = NewContainer(plate)
		if plate.auras then
			LayoutContainer(plate)
		end
	end
	if plate.auras then
		plate.auras:Show()
		Bind(plate, plate.unit)
		ShowChip(plate, true)
	end
end

function Component.Clear(plate)
	ShowChip(plate, false)
	Bind(plate, "none")
	if plate.kinds then RefreshKinds(plate) end
end

Auras.AurasSecret = AurasSecret
