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
local NAME_GAP = Tokens.Size("gapMedium")
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

local available = true
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

local function SettingsLane(frame)
	if not Settings.Get("debuffs.showTime") or Settings.Get("debuffs.timePlace") ~= "BELOW" then
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

local function Filter()
	local filter = Settings.Get("debuffs.onlyMine") and "HARMFUL|PLAYER" or "HARMFUL"
	if Settings.Get("debuffs.includePlateOnly") then filter = filter .. "|INCLUDE_NAME_PLATE_ONLY" end
	return K.Options.AuraFilterString({ dispellable = Settings.Get("debuffs.dispellable") }, filter)
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

local function NewTile(owner)
	local skin = CreateFrame("Frame", nil, owner)
	skin:SetAllPoints(owner)
	local rings = {}
	for i, color in ipairs(RINGS) do
		local ring = Widgets.Crisp(skin:CreateTexture(nil, "BACKGROUND", nil, RING_LEVELS[i]))
		ring:SetColorTexture(Tokens.Color(color))
		rings[i] = ring
	end
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	return { skin = skin, icon = icon, rings = rings, bare = false, crop = 0 }
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
	if tile.dispel then Inset(tile.dispel, skin, px) end
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
	p.timeHolder:SetShown(Settings.Get("debuffs.showTime"))
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
		p.dispel = Widgets.Crisp(p.skin:CreateTexture(nil, "BACKGROUND", nil, DISPEL_LEVEL))
		p.dispel:SetColorTexture(Tokens.Color("white"))
		Inset(p.dispel, p.skin, K.Scale.Pixel(1) / Widgets.ScaleFactor(p.skin))
	end
	return p.dispel
end

local dispelOptions
local function DispelOptions()
	if dispelOptions == nil then
		local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
		dispelOptions = styles and styles.PreserveAsset ~= nil and { style = styles.PreserveAsset, showWhenHarmful = true } or false
		if not dispelOptions then
			LogOnce("aura-dispel", "Enum.CustomAuraButtonDispelTypeTextureStyle is missing; debuffs keep their red ring")
		end
	end
	return dispelOptions or nil
end

local function Cues(button, p)
	local dispel = Settings.Get("debuffs.dispelColor") and Settings.Get("debuffs.border") and DispelOptions() ~= nil
	if dispel ~= (p.dispelBound == true) and type(button.AddDispelTypeTexture) == "function" and type(button.RemoveDispelTypeTexture) == "function" then
		if dispel then
			button:AddDispelTypeTexture(Dispel(p), DispelOptions())
		else
			button:RemoveDispelTypeTexture(p.dispel)
			p.dispel:Hide()
		end
		p.dispelBound = dispel
	end
	local cue = Settings.Get("debuffs.pandemic")
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

local function BuildButton(button)
	if not pcall(button.EnableMouse, button, false) then
		LogOnce("aura-mouse", "aura buttons refused EnableMouse(false); debuff icons may catch clicks")
	end
	local tile = NewTile(button)
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

local function InitButton(button)
	local ok, err = pcall(BuildButton, button)
	if not ok then
		LogOnce("aura-button", "building an aura button failed: " .. tostring(err))
	end
end

local function GroupOptions(plate)
	local _, _, columns, rows = Grid(plate)
	local options = {
		maxFrameCount = columns * rows,
		initializeFrame = InitButton,
		layout = GroupLayout(plate),
		candidateFilters = Candidates(),
	}
	options.sortMethod, options.sortDirection = SortOptions()
	return options
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
	local added, err = pcall(container.AddAuraGroup, container, GROUP, Filter(), GroupOptions(plate))
	if not added then
		container:Hide()
		available = false
		LogOnce("aura-group", "the debuff group could not be added: " .. tostring(err))
		return nil
	end
	K.DevTest.Log(Settings.MODULE, "nameplate debuffs run on the AuraContainer engine")
	local _, _, columns, rows = Grid(plate)
	local chip, why = Overflow.New(plate, "none", Filter(), columns * rows, { labels = OVERFLOW_MAX })
	if chip then
		plate.auraChip = chip
	else
		LogOnce("aura-chip", "the overflow chip has no counting container (" .. tostring(why) .. "); a full row shows no +N")
	end
	return container
end

local function RestyleNow(plate)
	local container = plate.auras
	for i = 1, container:GetAuraGroupFrameCount(GROUP) do
		local ok, err = pcall(StyleButton, container:GetAuraGroupFrame(GROUP, i))
		if not ok then
			LogOnce("aura-style", "restyling an aura button failed: " .. tostring(err))
			return
		end
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
		return ns.Plate.NAME_GAP + Settings.Get("name.size") + NAME_GAP + ns.Resource.Room(plate, "TOP")
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

function Auras.Extent(plate, rowsCap)
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
	local _, _, _, rows = Grid(plate)
	local relPoint, y = AnchorTo(plate, anchor)
	local sign = Settings.Get("debuffs.growthX") == "LEFT" and -1 or 1
	Overflow.Apply(chip, {
		enabled = Shows(plate), groups = { { filter = Filter(), candidates = Candidates() } }, cap = columns * rows, cell = size, after = true,
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
	local size, spacing, columns, rows = Grid(plate)
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
	container:SetAuraGroupMaxFrameCount(GROUP, columns * rows)
	container:SetAuraGroupFilterString(GROUP, Filter())
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
	elseif plate.auras then
		local size, spacing, columns = Grid(plate)
		local anchor = Logic.AuraGrowth(Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
		Anchor(plate, plate.auras, anchor)
		LayoutChip(plate, anchor, size, spacing, columns)
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
	elseif plate.auras then
		LayoutContainer(plate)
	end
end

function Component.Refresh(plate)
	if plate.sample then
		LayoutSamples(plate)
		return
	end
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
end

Auras.AurasSecret = AurasSecret
