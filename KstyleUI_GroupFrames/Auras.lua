-- Auras.lua: a few debuff icons and the dispellable debuff highlight on each group frame, found, sorted and drawn by the AuraContainer engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Geometry, Style, Unit, Button = ns.Settings, ns.Geometry, ns.Style, ns.Unit, ns.Button

local Auras = {}
ns.Auras = Auras

local GROUP = "debuffs"
local DISPELS = "dispels"
local GROUPS = { DISPELS, GROUP }
local SLOT = "dispel"
local TEMPLATE = "CustomAuraContainerTemplate"
local NONE = "none"
local FILTERS = { ALL = "HARMFUL", RAID = "HARMFUL|RAID_IN_COMBAT", DISPELLABLE = "HARMFUL|RAID" }
local DISPEL_FILTERS = { PLAYER = "HARMFUL|RAID", GROUP = "HARMFUL|RAID_PLAYER_DISPELLABLE" }
local ICON_CROP = 0.07
local SWIPE_ALPHA = 0.65
local LINE_SLACK = 0.5
local RETRY_DELAY = 1
local CONTAINER_LEVEL = 6
local WASH_ALPHA = 0.16
local ICON_INSET_LINES = 2
local DISPEL_SUBLEVEL = 7
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local COUNT_SHARE = 0.6
local SAMPLE_ICONS = { 136207, 135848, 136139 }
local SAMPLE_COUNT = 2

local available = true
local parts = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })

local issecretvalue = issecretvalue or function()
	return false
end

local function AurasSecret()
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		return not ok or issecretvalue(secret) or secret == true
	end
	return InCombatLockdown()
end
Auras.AurasSecret = AurasSecret

local function Count(k)
	return math.max(1, math.min(k.auraCount, k.auraColumns * k.auraRows))
end

local function DispelCount(k)
	return math.min(k.auraDispelCount, k.auraColumns * k.auraRows)
end

local LAYOUT_INDEX = { [DISPELS] = 1, [GROUP] = 2 }

local function Sizes(f, k)
	return Widgets.Snap(f, k.auraSize), Widgets.Snap(f, k.auraSpacing)
end

local function GroupLayout(f, k, key)
	local size, spacing = Sizes(f, k)
	return {
		elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size,
		layoutIndex = LAYOUT_INDEX[key or GROUP],
	}
end

local function Processing()
	local policy = CustomAuraContainerAuraProcessingPolicy
	local types = AuraUtil and AuraUtil.AuraUpdateChangedType
	if policy and policy.ProcessAura and types and types.Debuff and types.Dispel then
		return policy.ProcessAura, types
	end
end

local function PolicyOptions()
	return { ignoreBuffs = true, displayOnlyDispellableDebuffs = Settings.current.auras.filter == "DISPELLABLE" }
end

local function NewTile(holder)
	local skin = CreateFrame("Frame", nil, holder)
	skin:SetAllPoints(holder)
	local chrome = Widgets.Chrome(skin, { shape = "tile", fill = "raised", shadow = false })
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	return { skin = skin, chrome = chrome, icon = icon, mask = mask }
end

local function PlaceIcon(tile)
	local skin, icon = tile.skin, tile.icon
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	return inset
end

local function NewDispel(owner)
	local wash = Style.Wash(owner, "ARTWORK")
	for _, piece in ipairs(wash) do
		piece:SetAlpha(WASH_ALPHA)
	end
	return wash, Style.Ring(owner, "OVERLAY")
end

local function LayoutDispel(wash, ring, owner)
	Style.LayoutWash(wash, owner)
	Style.LayoutRing(ring, owner)
end

local pending = setmetatable({}, { __mode = "k" })
local flushScheduled = false
local ScheduleFlush, RestyleNow

local function Flush()
	flushScheduled = false
	if AurasSecret() then
		ScheduleFlush()
		return
	end
	for f in pairs(pending) do
		pending[f] = nil
		if f.auras then
			RestyleNow(f)
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
	end
end

local function Defer(f)
	pending[f] = true
	ScheduleFlush()
end

local function StyleIcon(button)
	local p = parts[button]
	local f = p and p.owner
	if not f then
		return
	end
	local k = Settings.current[f.kind]
	Widgets.Size(button, k.auraSize, k.auraSize)
	p.restyleChrome(p.chrome)
	local inset = PlaceIcon(p)
	local _, _, corner = Tokens.Texture("chamferTile")
	Widgets.LayoutSlice(p.dispel, p.skin, corner, 0)
	p.count:ClearAllPoints()
	p.count:SetPoint("BOTTOMRIGHT", p.skin, "BOTTOMRIGHT", -inset, inset)
	local text = Settings.current.text
	Style.SetFont(p.count, text.healthFont, math.max(6, math.floor(k.auraSize * COUNT_SHARE + 0.5)), "OUTLINE")
	p.cooldown:SetDrawSwipe(Settings.current.auras.swipe)
end

function RestyleNow(f)
	local container = f.auras
	for _, key in ipairs(GROUPS) do
		for i = 1, container:GetAuraGroupFrameCount(key) do
			local ok, err = pcall(StyleIcon, container:GetAuraGroupFrame(key, i))
			if not ok then
				Style.LogOnce("auraStyle", "restyling a debuff icon failed: " .. tostring(err))
				return
			end
		end
	end
	if f.dispelWash then
		local ok, err = pcall(LayoutDispel, f.dispelWash, f.dispelRing, f.dispelFrame)
		if not ok then
			Style.LogOnce("dispelStyle", "laying out the dispel highlight failed: " .. tostring(err))
		end
	end
end

local function Restyle(f)
	if AurasSecret() then
		Defer(f)
		return
	end
	RestyleNow(f)
end

local function DispelStyle()
	local enum = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	return enum and enum.PreserveAsset
end

local function GateChrome(chrome, f)
	local restyle = chrome.Restyle
	chrome.Restyle = function(self)
		if AurasSecret() then
			if f then
				Defer(f)
			end
			return
		end
		return restyle(self)
	end
	return restyle
end

local function BuildIcon(button)
	if button.SetMouseClickEnabled then
		if not pcall(button.SetMouseClickEnabled, button, false) then
			Style.LogOnce("auraClicks", "aura buttons refused SetMouseClickEnabled(false); debuff icons may catch clicks")
		end
	elseif not pcall(button.EnableMouse, button, false) then
		Style.LogOnce("auraMouse", "aura buttons refused EnableMouse(false); debuff icons may catch clicks")
	end
	local f = owners[button:GetParent()]
	local p = NewTile(button)
	p.owner = f
	p.restyleChrome = GateChrome(p.chrome, f)
	p.dispel = Widgets.NineSlice(p.skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
	Widgets.ShowSlice(p.dispel, false)
	local cooldown = CreateFrame("Cooldown", nil, p.skin)
	cooldown:SetAllPoints(p.icon)
	cooldown:SetSwipeTexture((Tokens.Texture("iconMask")))
	cooldown:SetDrawEdge(false)
	cooldown:SetReverse(true)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	local textFrame = CreateFrame("Frame", nil, p.skin)
	textFrame:SetAllPoints(p.skin)
	textFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = textFrame:CreateFontString(nil, "OVERLAY")
	count:SetJustifyH("RIGHT")
	p.cooldown, p.count = cooldown, count
	parts[button] = p
	StyleIcon(button)
	button:SetIcon(p.icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	local style = DispelStyle()
	if style then
		local options = { style = style, showWhenHarmful = true, showWithoutDispelType = true }
		for _, piece in ipairs(p.dispel) do
			button:AddDispelTypeTexture(piece, options)
		end
	end
end

local function InitIcon(button)
	local ok, err = pcall(BuildIcon, button)
	if not ok then
		Style.LogOnce("auraButton", "building a debuff icon failed: " .. tostring(err))
	end
end

local function BuildDispel(slot, f)
	pcall(slot.EnableMouse, slot, false)
	slot:ClearAllPoints()
	slot:SetAllPoints(f)
	local wash, ring = NewDispel(slot)
	LayoutDispel(wash, ring, slot)
	f.dispelWash, f.dispelRing, f.dispelFrame = wash, ring, slot
	local style = DispelStyle()
	if style then
		local options = { style = style, showWhenHarmful = true }
		for _, piece in ipairs(wash) do
			slot:AddDispelTypeTexture(piece, options)
		end
		Style.Pieces(ring, function(piece)
			slot:AddDispelTypeTexture(piece, options)
		end)
	else
		Style.LogOnce("dispelStyle", "the dispel texture styles are missing; the dispel highlight stays off")
	end
end

local function GroupOptions(f, k, key, processedType)
	local count = key == DISPELS and math.max(1, DispelCount(k)) or Count(k)
	local options = { maxFrameCount = count, initializeFrame = InitIcon, layout = GroupLayout(f, k, key) }
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if methods and directions then
		options.sortMethod = processedType and methods.UnitFrameDebuff or methods.Default
		options.sortDirection = directions.Normal
	end
	if processedType then
		options.candidateFilters = { processedAuraType = processedType }
	end
	return options
end

local function AddGroups(container, f, k, filter)
	local policy, types = Processing()
	if policy and type(container.SetAuraProcessingPolicy) == "function" then
		container:SetAuraProcessingPolicy(policy, PolicyOptions())
		container:AddAuraGroup(DISPELS, filter, GroupOptions(f, k, DISPELS, types.Dispel))
		container:AddAuraGroup(GROUP, filter, GroupOptions(f, k, GROUP, types.Debuff))
		return true
	end
	Style.LogOnce("auraPolicy", "the aura processing policy is missing; group frames show debuffs in the default order")
	container:AddAuraGroup(GROUP, filter, GroupOptions(f, k, GROUP, nil))
	return false
end

local function SetUnit(f, unit)
	local container = f.auras
	if not container or f.aurasUnit == unit then
		return
	end
	local ok, err = pcall(container.SetUnit, container, unit)
	if ok then
		f.aurasUnit = unit
	else
		Style.LogOnce("auraUnit", "a debuff container refused a unit: " .. tostring(err))
	end
end

local function NewContainer(f)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		available = false
		Style.LogOnce("auraMissing", "the AuraContainer engine (" .. TEMPLATE .. ") is unavailable, so group frames show no debuffs: " .. tostring(container))
		return nil
	end
	owners[container] = f
	container:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	if type(container.SetEditModePreviewEnabled) == "function" then
		pcall(container.SetEditModePreviewEnabled, container, false)
	end
	local k, a = Settings.current[f.kind], Settings.current.auras
	local added, processed = pcall(AddGroups, container, f, k, FILTERS[a.filter] or FILTERS.ALL)
	local err = processed
	f.processed = added and processed
	if not added then
		container:Hide()
		available = false
		Style.LogOnce("auraGroup", "the debuff group could not be added: " .. tostring(err))
		return nil
	end
	if type(container.AddAuraSlot) == "function" then
		local slotted, slotErr = pcall(container.AddAuraSlot, container, SLOT, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER, {
			initializeFrame = function(slot)
				local built, buildErr = pcall(BuildDispel, slot, f)
				if not built then
					Style.LogOnce("dispelBuild", "building the dispel highlight failed: " .. tostring(buildErr))
				end
			end,
		})
		f.dispelSlot = slotted
		if not slotted then
			Style.LogOnce("dispelSlot", "the dispel highlight slot could not be added: " .. tostring(slotErr))
		end
	else
		Style.LogOnce("dispelSlotMissing", "AddAuraSlot is missing; group frames show no dispel highlight")
	end
	Style.LogOnce("auraEngine", "group frame debuffs run on the AuraContainer engine")
	return container
end

local function Configure(f)
	local container = f.auras
	local k, a = Settings.current[f.kind], Settings.current.auras
	local size, spacing = Sizes(f, k)
	local inset = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local gap = Widgets.Snap(f, Tokens.Size("gapSmall"))
	local point, rel, x, y = Geometry.AuraAnchor(k.auraPosition, k.auraGrowth, k.auraWrap, inset, gap)
	container:ClearAllPoints()
	container:SetPoint(point, f, rel, x, y)
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local direction = AnchorUtil and AnchorUtil.FlowDirection
	if axis and direction then
		container:SetFlowLayoutAxis(axis.Horizontal)
		container:SetFlowLayoutAnchorPoint(point)
		container:SetFlowLayoutGrowthDirection(k.auraGrowth == "LEFT" and direction.Left or direction.Right, k.auraWrap == "DOWN" and direction.Down or direction.Up)
		container:SetFlowLayoutMaximumLineSize(Geometry.AuraLine(k.auraColumns, size, spacing) + LINE_SLACK)
	else
		Style.LogOnce("auraAnchor", "AnchorUtil is missing; debuffs keep the engine's default layout")
	end
	local filter = FILTERS[a.filter] or FILTERS.ALL
	if f.processed then
		container:SetAuraProcessingPolicy(Processing(), PolicyOptions())
		local dispels = DispelCount(k)
		container:SetAuraGroupLayout(DISPELS, GroupLayout(f, k, DISPELS))
		container:SetAuraGroupFilterString(DISPELS, filter)
		if dispels > 0 then
			container:SetAuraGroupMaxFrameCount(DISPELS, dispels)
		end
		container:SetAuraGroupEnabled(DISPELS, a.enabled and dispels > 0)
	end
	container:SetAuraGroupLayout(GROUP, GroupLayout(f, k, GROUP))
	container:SetAuraGroupMaxFrameCount(GROUP, Count(k))
	container:SetAuraGroupFilterString(GROUP, filter)
	container:SetAuraGroupEnabled(GROUP, a.enabled)
	if f.dispelSlot then
		container:SetAuraSlotFilterString(SLOT, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER)
		container:SetAuraSlotEnabled(SLOT, a.dispelHighlight)
	end
	Restyle(f)
end

local function Layout(f)
	if f.sample or not f.auras then
		return
	end
	local ok, err = pcall(Configure, f)
	if not ok then
		Style.LogOnce("auraConfigure", "configuring debuffs failed: " .. tostring(err))
	end
end

local waiting = setmetatable({}, { __mode = "k" })

local function Bind(f)
	if f.sample then
		return
	end
	local a = Settings.current.auras
	local on = (a.enabled or a.dispelHighlight) and available and Unit.running
	if not on then
		if f.auras then
			SetUnit(f, NONE)
			f.auras:Hide()
		end
		return
	end
	if not f.auras then
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
		f.auras = NewContainer(f)
		if not f.auras then
			return
		end
		Layout(f)
	end
	f.auras:Show()
	SetUnit(f, f.unit or NONE)
end
Auras.Bind = Bind

local function BuildSamples(f)
	if not f.sample then
		return
	end
	local holder = CreateFrame("Frame", nil, f)
	holder:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	f.sampleAuraHolder = holder
	f.sampleAuras = {}
	for i, fileID in ipairs(SAMPLE_ICONS) do
		local icon = CreateFrame("Frame", nil, holder)
		local tile = NewTile(icon)
		tile.icon:SetTexture(fileID)
		icon.tile, icon.art = tile, tile.icon
		f.sampleAuras[i] = icon
	end
	f.sampleDispel = CreateFrame("Frame", nil, holder)
	f.sampleDispel:SetAllPoints(f)
	f.sampleDispelWash, f.sampleDispelRing = NewDispel(f.sampleDispel)
end
Button.built[#Button.built + 1] = BuildSamples

local function LayoutSamples(f, k)
	local holder = f.sampleAuraHolder
	local size, spacing = Sizes(f, k)
	local inset = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local gap = Widgets.Snap(f, Tokens.Size("gapSmall"))
	local point, rel, x, y = Geometry.AuraAnchor(k.auraPosition, k.auraGrowth, k.auraWrap, inset, gap)
	holder:ClearAllPoints()
	holder:SetPoint(point, f, rel, x, y)
	holder:SetSize(size, size)
	local dx = k.auraGrowth == "LEFT" and -1 or 1
	local dy = k.auraWrap == "DOWN" and -1 or 1
	for i, icon in ipairs(f.sampleAuras) do
		local index = i - 1
		local col, row = index % k.auraColumns, math.floor(index / k.auraColumns)
		icon:ClearAllPoints()
		icon:SetSize(size, size)
		icon:SetPoint(point, holder, point, dx * col * (size + spacing), dy * row * (size + spacing))
		icon.tile.chrome:Restyle()
		PlaceIcon(icon.tile)
	end
	LayoutDispel(f.sampleDispelWash, f.sampleDispelRing, f.sampleDispel)
end

local function Applied(f, _, k)
	if f.sample then
		LayoutSamples(f, k)
	else
		Layout(f)
	end
end
Style.appliers[#Style.appliers + 1] = Applied

local function PaintSample(f, sample)
	local k, a = Settings.current[f.kind], Settings.current.auras
	local shown = a.enabled and math.min(sample.debuffs or 0, Count(k), SAMPLE_COUNT) or 0
	for i, icon in ipairs(f.sampleAuras) do
		icon:SetShown(i <= shown)
	end
	local dispel = a.dispelHighlight and sample.dispel
	if dispel then
		local r, g, b = Tokens.Color("rare")
		Widgets.ColorSlice(f.sampleDispelWash, r, g, b, 1)
		Style.ColorRing(f.sampleDispelRing, r, g, b, 1)
	end
	f.sampleDispel:SetShown(dispel and true or false)
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.changed[#Unit.changed + 1] = Bind
Unit.extra[#Unit.extra + 1] = Bind
