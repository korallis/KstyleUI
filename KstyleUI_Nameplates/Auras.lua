-- Auras.lua: the plate's debuffs: the player's harmful auras on the unit, found, sorted and shown by the AuraContainer engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce

local Auras = {}
ns.Auras = Auras

local GROUP = "debuffs"
local TEMPLATE = "CustomAuraContainerTemplate"
local GAP = Tokens.Size("gapTiny")
local ICON_CROP = 0.07
local ICON_INSET_LINES = 2
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SWIPE_ALPHA = 0.65
local LINE_SLACK = 0.5
local RETRY_DELAY = 1
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local SAMPLE_ICONS = { 136118, 135817, 132155 }

local available = true
local parts = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local waitingChromes = setmetatable({}, { __mode = "k" })
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
	local size = Widgets.Snap(frame, Settings.Get("debuffs.size"))
	local spacing = Widgets.Snap(frame, Settings.Get("debuffs.spacing"))
	return size, spacing, Settings.Get("debuffs.columns"), Settings.Get("debuffs.rows")
end

local function GroupLayout(plate)
	local size, spacing = Grid(plate)
	return { elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size }
end

local function Filter()
	return Logic.AuraFilter(Settings.Get("debuffs.includePlateOnly"))
end

local function StyleText(text)
	local flags = OUTLINE_FLAGS[Settings.Get("debuffs.outline")] or "OUTLINE"
	local size = Settings.Get("debuffs.textSize")
	if text:SetFont(Settings.Get("font"), size, flags) == false then
		text:SetFont((Tokens.Font("world")), size, flags)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

local function NewTile(owner)
	local skin = CreateFrame("Frame", nil, owner)
	skin:SetAllPoints(owner)
	local chrome = Widgets.Chrome(skin, { shape = "tile", fill = "raised", shadow = false })
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	return { skin = skin, chrome = chrome, restyleChrome = chrome.Restyle, icon = icon }
end

local function LayoutTile(tile)
	local skin, icon = tile.skin, tile.icon
	tile.restyleChrome(tile.chrome)
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
end

local function GateChrome(tile)
	local restyle = tile.restyleChrome
	tile.chrome.Restyle = function(chrome)
		if AurasSecret() then
			waitingChromes[chrome] = restyle
			ScheduleFlush()
			return
		end
		restyle(chrome)
	end
end

local function StyleButton(button)
	local p = parts[button]
	if not p then
		return
	end
	local size = Grid(p.skin)
	button:SetSize(size, size)
	LayoutTile(p)
	StyleText(p.count)
	StyleText(p.time)
	p.countHolder:SetShown(Settings.Get("debuffs.showCount"))
	p.timeHolder:SetShown(Settings.Get("debuffs.showTime"))
end

local function BuildButton(button)
	if not pcall(button.EnableMouse, button, false) then
		LogOnce("aura-mouse", "aura buttons refused EnableMouse(false); debuff icons may catch clicks")
	end
	local tile = NewTile(button)
	GateChrome(tile)
	local icon = tile.icon
	local cooldown = CreateFrame("Cooldown", nil, tile.skin)
	cooldown:SetAllPoints(icon)
	cooldown:SetSwipeTexture((Tokens.Texture("iconMask")))
	cooldown:SetDrawEdge(false)
	cooldown:SetReverse(true)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	local textFrame = CreateFrame("Frame", nil, button)
	textFrame:SetAllPoints(button)
	textFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local countHolder = CreateFrame("Frame", nil, textFrame)
	countHolder:SetAllPoints(textFrame)
	local count = Widgets.FontString(countHolder, "OVERLAY")
	count:SetPoint("TOPRIGHT", countHolder, "TOPRIGHT", 0, 0)
	count:SetJustifyH("RIGHT")
	local timeHolder = CreateFrame("Frame", nil, textFrame)
	timeHolder:SetAllPoints(textFrame)
	local time = Widgets.FontString(timeHolder, "OVERLAY")
	time:SetPoint("BOTTOM", timeHolder, "BOTTOM", 0, 0)
	time:SetJustifyH("CENTER")
	tile.count, tile.time, tile.countHolder, tile.timeHolder = count, time, countHolder, timeHolder
	parts[button] = tile
	StyleButton(button)
	button:SetIcon(icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	button:SetDurationText(time)
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
	}
	if AuraContainerSortMethod and AuraContainerSortDirection then
		options.sortMethod = AuraContainerSortMethod.Default
		options.sortDirection = AuraContainerSortDirection.Normal
	end
	return options
end

local function Bind(plate, unit)
	local container = plate.auras
	if not container or plate.aurasUnit == unit then
		return
	end
	local ok, err = pcall(container.SetUnit, container, unit)
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

local function Flush()
	flushScheduled = false
	if AurasSecret() then
		ScheduleFlush()
		return
	end
	for plate in pairs(pending) do
		pending[plate] = nil
		if plate.auras then
			RestyleNow(plate)
		end
	end
	for chrome, restyle in pairs(waitingChromes) do
		waitingChromes[chrome] = nil
		local ok, err = pcall(restyle, chrome)
		if not ok then
			LogOnce("aura-chrome", "restyling a debuff tile failed: " .. tostring(err))
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

local function Anchor(plate, frame, anchor)
	local up = anchor:find("^BOTTOM") ~= nil
	local left = anchor:find("LEFT$") ~= nil
	local health = plate.health
	frame:ClearAllPoints()
	if up then
		local room = GAP
		if Settings.Get("name.show") and not plate.nameOnly then
			room = Settings.Get("name.size") + GAP * 2
		end
		frame:SetPoint(anchor, health, left and "TOPLEFT" or "TOPRIGHT", 0, Widgets.Snap(plate, room))
	else
		local room = GAP
		for _, component in ipairs(ns.Components) do
			if component.Room then
				room = room + component.Room(plate)
			end
		end
		frame:SetPoint(anchor, health, left and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -Widgets.Snap(plate, room))
	end
end

local function LayoutContainer(plate)
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
	Anchor(plate, container, anchor)
	RestyleButtons(plate)
end

local function Shows(plate)
	return Settings.Get("debuffs.enabled") and not plate.nameOnly
end

local function LayoutSamples(plate)
	local icons = plate.sampleAuras
	local size, spacing, columns, rows = Grid(plate)
	local anchor = Logic.AuraGrowth(Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
	local holder = plate.sampleAuraHolder
	Widgets.Size(holder, size, size)
	Anchor(plate, holder, anchor)
	local shown = Shows(plate)
	for i, icon in ipairs(icons) do
		Widgets.Size(icon, size, size)
		local x, y = Logic.AuraOffset(i, columns, size, spacing, Settings.Get("debuffs.growthX"), Settings.Get("debuffs.growthY"))
		icon:ClearAllPoints()
		icon:SetPoint(anchor, holder, anchor, x, y)
		icon:SetShown(shown and i <= columns * rows)
		LayoutTile(icon.tile)
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

local Component = {}
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
	end
end

function Component.Clear(plate)
	Bind(plate, "none")
end

Auras.AurasSecret = AurasSecret
