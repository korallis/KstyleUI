-- Auras.lua: debuff icons in the player's priority order, the dispellable debuff highlight and the boss debuff glow on each group frame, found, sorted and drawn by the AuraContainer engine.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Geometry, Style, Unit, Button = ns.Settings, ns.Geometry, ns.Style, ns.Unit, ns.Button

local Auras = {}
ns.Auras = Auras

local GROUP = "debuffs"
local DISPELS = "dispels"
local BOSS = "boss"
local IMPORTANT = "important"
local GROUPS = { BOSS, IMPORTANT, DISPELS, GROUP }
local CATEGORY_GROUP = { BOSS = BOSS, IMPORTANT = IMPORTANT, DISPEL = DISPELS, OTHER = GROUP }
local CATEGORY_ORDER = { "BOSS", "IMPORTANT", "DISPEL", "OTHER" }
local OVERFLOW = 1
local TEXT_ABOVE = 8
local MARK = "+"
local MARK_SHARE = 0.55
local MARK_MIN = 7
local MARK_BACK_ALPHA = 0.75
local MARK_BACK_SUBLEVEL = 5
local MARK_SUBLEVEL = 6
local GLOWS = { glowBoss = { isBossAura = true }, glowImportant = { isPriorityAura = true } }
local GLOW_FILTER = "HARMFUL"
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
local BUFFS = "buffs"
local BUFF_FILTER = "HELPFUL|PLAYER"
local SAMPLE_BUFF_ICONS = { 136081, 135953, 135940 }
local MARK_COLORS = { [BOSS] = "hostile", [IMPORTANT] = "neutral", [DISPELS] = "rare", [GROUP] = "textEmphasis" }
local MARK_LIFT = 2
local MORE = "dispelMore"
local MORE_PITCH = 2
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"

local available = true
local buffsAvailable = true
local parts = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })
local buffHolders = setmetatable({}, { __mode = "k" })

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

local function Order()
	local a = Settings.current.auras
	local index, seen, n = {}, {}, 0
	local function take(category)
		local key = CATEGORY_GROUP[category]
		if key and not seen[key] then
			seen[key] = true
			n = n + 1
			index[key] = n
		end
	end
	local listed = {}
	for i = 1, #CATEGORY_ORDER do
		listed[a["priority" .. i]] = true
	end
	local function missing()
		for i = 1, #CATEGORY_ORDER do
			local category = CATEGORY_ORDER[i]
			if not listed[category] and not seen[CATEGORY_GROUP[category]] then
				return category
			end
		end
	end
	for i = 1, #CATEGORY_ORDER do
		local category = a["priority" .. i]
		if seen[CATEGORY_GROUP[category]] then
			category = missing()
		end
		if category then
			take(category)
		end
	end
	for i = 1, #CATEGORY_ORDER do
		take(CATEGORY_ORDER[i])
	end
	return index
end
Auras.Order = Order

local function MarkLift(key)
	local rank = key and Order()[key]
	if not rank then
		return 0
	end
	return MARK_LIFT * (#GROUPS + 1 - rank)
end
Auras.MarkLift = MarkLift

local function Block(f, k)
	local w, h = Style.Size(f)
	local size, spacing = Widgets.Snap(f, k.auraSize), Widgets.Snap(f, k.auraSpacing)
	local inset, gap = Widgets.Snap(f, Tokens.Size("gapTiny")), Widgets.Snap(f, Tokens.Size("gapSmall"))
	local lane = f.kind == "party" and Geometry.AuraLane(k) or 0
	local block = Geometry.AuraBlock(k, w, h, size, spacing, inset, lane > 0 and lane - gap or 0)
	block.spacing, block.inset, block.gap = spacing, inset, gap
	return block
end
Auras.Block = Block

local function GroupCount(f, k, key)
	local cells = f and Block(f, k).cells or Count(k)
	if key == DISPELS then
		return math.max(1, math.min(DispelCount(k), cells))
	end
	return cells + OVERFLOW
end

local function Candidates(key, types, k)
	if key == BOSS then
		return { isBossAura = true }
	elseif key == IMPORTANT then
		return { isBossAura = false, isPriorityAura = true }
	end
	if key == GROUP and k and DispelCount(k) <= 0 then
		return { isBossAura = false, isPriorityAura = false }
	end
	local processed = key == DISPELS and types.Dispel or types.Debuff
	return { processedAuraType = processed, isBossAura = false, isPriorityAura = false }
end

local function Sizes(f, k)
	return Auras.Block(f, k).size, Widgets.Snap(f, k.auraSpacing)
end

local function BuffSizes(f, k)
	local _, h = Style.Size(f)
	local room = math.max(1, h - 2 * Widgets.Snap(f, Tokens.Size("gapTiny")))
	return math.min(Widgets.Snap(f, k.buffSize), room), Widgets.Snap(f, k.auraSpacing)
end

local function BuffLayout(f, k)
	local size, spacing = BuffSizes(f, k)
	return { elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size, layoutIndex = 1 }
end

local function BuffPolicy()
	return { ignoreBuffs = false, ignoreDebuffs = true, ignoreDispelDebuffs = true, displayOnlyDispellableDebuffs = false }
end

local function GroupLayout(f, k, key)
	local size, spacing = Sizes(f, k)
	return {
		elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size,
		layoutIndex = Order()[key or GROUP],
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
	local chrome = Widgets.IconChrome(skin)
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

local function LayoutDispel(wash, ring, owner, chamfer)
	Style.LayoutWash(wash, owner, chamfer)
	Style.LayoutRing(ring, owner, chamfer)
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
		if f.auras or f.buffs or f.indicators then
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
	local size = p.size and p.size() or (p.buff and BuffSizes(f, k) or Sizes(f, k))
	local border = Widgets.Border(p.skin)
	if p.styledSize ~= size or p.styledBorder ~= border then
		Widgets.Size(button, size, size)
		p.restyleChrome(p.chrome)
		local inset = PlaceIcon(p)
		Widgets.LayoutSlice(p.dispel, p.skin, p.chrome:Chamfer(), 0)
		p.count:ClearAllPoints()
		p.count:SetPoint("BOTTOMRIGHT", p.skin, "BOTTOMRIGHT", -inset, inset)
		p.styledSize, p.styledBorder = size, border
	end
	p.chrome:SetRimAccent(Style.Accent())
	local text = Settings.current.text
	Style.SetFont(p.count, text.healthFont, math.max(6, math.floor(size * COUNT_SHARE + 0.5)), "OUTLINE")
	p.cooldown:SetDrawSwipe(Settings.current.auras.swipe)
	if p.mark and not p.size then
		Auras.PlaceMark(p, button, f, k)
	end
end

function Auras.PlaceMark(p, button, f, k)
	local columns, rows, size, spacing, gx, gy
	if p.buff then
		local side, count, buffSize, buffSpacing = Auras.HealIcons(f, k)
		columns, rows, size, spacing = math.max(1, count), 1, buffSize, buffSpacing
		gx, gy = side == "RIGHT" and -1 or 1, -1
	else
		local block = Block(f, k)
		columns, rows, size, spacing = math.max(1, block.columns), math.max(1, block.rows), block.size, block.spacing
		gx, gy = k.auraGrowth == "LEFT" and -1 or 1, k.auraWrap == "DOWN" and -1 or 1
	end
	local step = size + spacing
	local mark, back = p.mark, p.markBack
	local badge = Widgets.Snap(f, math.max(MARK_MIN, size * MARK_SHARE))
	back:ClearAllPoints()
	back:SetSize(badge, badge)
	back:SetPoint("TOPRIGHT", button, "TOPRIGHT", (columns - 1) * step * gx, -rows * step * gy)
	Style.SetFont(mark, Settings.current.text.healthFont, math.max(MARK_MIN, math.floor(badge + 0.5)), "OUTLINE")
	mark:SetTextColor(Tokens.Color(MARK_COLORS[p.group] or "textEmphasis"))
	mark:SetText(MARK)
	p.textFrame:SetFrameLevel(button:GetFrameLevel() + TEXT_ABOVE + MarkLift(p.group))
	mark:ClearAllPoints()
	mark:SetPoint("CENTER", back, "CENTER", 0, 0)
end

local function StyleGroup(container, key)
	for i = 1, container:GetAuraGroupFrameCount(key) do
		local ok, err = pcall(StyleIcon, container:GetAuraGroupFrame(key, i))
		if not ok then
			Style.LogOnce("auraStyle", "restyling an aura icon failed: " .. tostring(err))
			return false
		end
	end
	return true
end

Auras.restylers = {}

function RestyleNow(f)
	local container = f.auras
	if f.buffs then
		StyleGroup(f.buffs, BUFFS)
	end
	for i = 1, #Auras.restylers do
		local ok, err = pcall(Auras.restylers[i], f)
		if not ok then
			Style.LogOnce("auraRestyler", "restyling a group frame aura part failed: " .. tostring(err))
		end
	end
	if not container then
		return
	end
	for _, key in ipairs(GROUPS) do
		if not StyleGroup(container, key) then
			return
		end
	end
	for _, entry in ipairs(f.debuffGlows or {}) do
		local ok, err = pcall(entry.restyle, entry.glow)
		if not ok then
			Style.LogOnce("glowStyle", "restyling the debuff glow failed: " .. tostring(err))
		end
	end
	if f.dispelWash then
		local ok, err = pcall(LayoutDispel, f.dispelWash, f.dispelRing, f.dispelFrame, f.chrome:Chamfer())
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
Auras.Restyle = Restyle
Auras.StyleIcon = StyleIcon

local function DispelStyle()
	local enum = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	return enum and enum.PreserveAsset
end

local function GateChrome(chrome, f, p)
	local restyle = chrome.Restyle
	chrome.Restyle = function(self)
		if AurasSecret() then
			if p then
				p.styledSize = nil
			end
			if f then
				Defer(f)
			end
			return
		end
		return restyle(self)
	end
	return restyle
end

local function BuildIcon(button, key)
	if button.SetMouseClickEnabled then
		if not pcall(button.SetMouseClickEnabled, button, false) then
			Style.LogOnce("auraClicks", "aura buttons refused SetMouseClickEnabled(false); debuff icons may catch clicks")
		end
	elseif not pcall(button.EnableMouse, button, false) then
		Style.LogOnce("auraMouse", "aura buttons refused EnableMouse(false); debuff icons may catch clicks")
	end
	local holder = button:GetParent()
	local f = owners[holder]
	local p = NewTile(button)
	p.owner = f
	p.buff = buffHolders[holder] == true
	p.group = key
	p.restyleChrome = GateChrome(p.chrome, f, p)
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
	textFrame:SetFrameLevel(button:GetFrameLevel() + TEXT_ABOVE)
	p.textFrame = textFrame
	local count = Widgets.FontString(textFrame, "OVERLAY")
	count:SetJustifyH("RIGHT")
	p.markBack = textFrame:CreateTexture(nil, "OVERLAY", nil, MARK_BACK_SUBLEVEL)
	p.markBack:SetColorTexture(Widgets.Rgba("black", MARK_BACK_ALPHA))
	p.mark = Widgets.FontString(textFrame, "OVERLAY")
	p.mark:SetDrawLayer("OVERLAY", MARK_SUBLEVEL)
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

local function InitIcon(button, key)
	local ok, err = pcall(BuildIcon, button, key)
	if not ok then
		Style.LogOnce("auraButton", "building a debuff icon failed: " .. tostring(err))
	end
end

local function GroupInit(key)
	return function(button)
		InitIcon(button, key)
	end
end

function Auras.Dress(button, owner, size)
	owners[button:GetParent()] = owner
	local ok, err = pcall(BuildIcon, button)
	if not ok then
		Style.LogOnce("auraButton", "building an indicator icon failed: " .. tostring(err))
		return
	end
	local p = parts[button]
	p.size = size
	if p.mark then
		p.mark:SetText("")
		p.mark:Hide()
		p.markBack:Hide()
		p.mark, p.markBack = nil, nil
	end
	return p
end
function Auras.Parts(button)
	return parts[button]
end
Auras.NewTile = NewTile
Auras.PlaceIcon = PlaceIcon
Auras.TEMPLATE = TEMPLATE
Auras.CONTAINER_LEVEL = CONTAINER_LEVEL

function Auras.BuildGlow(slot, f)
	pcall(slot.EnableMouse, slot, false)
	slot:ClearAllPoints()
	slot:SetAllPoints(f)
	local anchor = CreateFrame("Frame", nil, slot)
	anchor:SetAllPoints(f)
	local glow = Widgets.Glow(anchor, { kind = "selection", color = "hostile", spread = Tokens.Size(f.kind == "party" and "gapMedium" or "gapSmall") })
	glow.holder:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
	local restyle = GateChrome(glow, f)
	glow:SetIntensity(1)
	f.debuffGlows = f.debuffGlows or {}
	f.debuffGlows[#f.debuffGlows + 1] = { glow = glow, restyle = restyle }
	return glow
end

local function BuildDispel(slot, f)
	pcall(slot.EnableMouse, slot, false)
	slot:ClearAllPoints()
	slot:SetAllPoints(f)
	local wash, ring = NewDispel(slot)
	LayoutDispel(wash, ring, slot, f.chrome:Chamfer())
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

local function GroupOptions(f, k, key, types)
	local options = { maxFrameCount = GroupCount(f, k, key), initializeFrame = GroupInit(key or GROUP), layout = GroupLayout(f, k, key) }
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if methods and directions then
		options.sortMethod = types and methods.UnitFrameDebuff or methods.Default
		options.sortDirection = directions.Normal
	end
	if types then
		options.candidateFilters = Candidates(key, types, k)
	end
	return options
end

local function AddGroups(container, f, k, filter)
	local policy, types = Processing()
	if policy and type(container.SetAuraProcessingPolicy) == "function" then
		container:SetAuraProcessingPolicy(policy, PolicyOptions())
		for _, key in ipairs(GROUPS) do
			container:AddAuraGroup(key, filter, GroupOptions(f, k, key, types))
		end
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
	if f.highlights then
		local lit, litErr = pcall(f.highlights.SetUnit, f.highlights, unit)
		if not lit then
			Style.LogOnce("highlightUnit", "a highlight container refused a unit: " .. tostring(litErr))
		end
	end
	if f.dispelMore then
		local set, moreErr = pcall(f.dispelMore.ghost.SetUnit, f.dispelMore.ghost, unit)
		if not set then
			Style.LogOnce("dispelMoreUnit", "the dispel overflow ghost refused a unit: " .. tostring(moreErr))
		end
	end
	if ok then
		f.aurasUnit = unit
	else
		Style.LogOnce("auraUnit", "a debuff container refused a unit: " .. tostring(err))
	end
end

local function SetBuffUnit(f, unit)
	local container = f.buffs
	if not container or f.buffsUnit == unit then
		return
	end
	local ok, err = pcall(container.SetUnit, container, unit)
	if ok then
		f.buffsUnit = unit
	else
		Style.LogOnce("buffUnit", "a heal icon container refused a unit: " .. tostring(err))
	end
end

local function NewHighlights(f)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, f, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraSlot) ~= "function" then
		Style.LogOnce("dispelSlotMissing", "AddAuraSlot is missing; group frames show no dispel highlight or debuff glow")
		return nil
	end
	owners[container] = f
	container:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	if type(container.SetEditModePreviewEnabled) == "function" then
		pcall(container.SetEditModePreviewEnabled, container, false)
	end
	return container
end

local function LayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, LAYOUT_TEMPLATE)
	if ok and type(frame) == "table" then
		return frame
	end
end

local function Mute(button)
	pcall(button.EnableMouse, button, false)
end

local function NewDispelGhost(f, filter)
	local policy, types = Processing()
	if not policy then
		return nil
	end
	local host = CreateFrame("Frame", nil, f)
	host:SetAlpha(0)
	local ok, ghost = pcall(CreateFrame, "AuraContainer", nil, host, TEMPLATE)
	local window = LayoutFrame(f)
	local face = window and LayoutFrame(window)
	if not ok or type(ghost) ~= "table" or type(ghost.AddAuraGroup) ~= "function" or not face then
		host:Hide()
		Style.LogOnce("dispelMore", "the dispel overflow ghost could not be made; dispellable debuffs past the dispel count raise no mark")
		return nil
	end
	if type(ghost.SetEditModePreviewEnabled) == "function" then
		pcall(ghost.SetEditModePreviewEnabled, ghost, false)
	end
	local added, err = pcall(function()
		ghost:SetAuraProcessingPolicy(policy, PolicyOptions())
		ghost:AddAuraGroup(MORE, filter, {
			maxFrameCount = OVERFLOW + 1, initializeFrame = Mute, candidateFilters = Candidates(DISPELS, types),
			layout = { elementWidth = 1, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
		})
		ghost:SetFlowLayoutAnchorPoint("TOPLEFT")
		local direction = AnchorUtil and AnchorUtil.FlowDirection
		if direction then
			ghost:SetFlowLayoutGrowthDirection(direction.Right, direction.Down)
		end
		ghost:SetFlowLayoutMaximumLineSize(1)
	end)
	if not added then
		host:Hide()
		window:Hide()
		Style.LogOnce("dispelMoreGroup", "the dispel overflow ghost refused its group: " .. tostring(err))
		return nil
	end
	window:SetClipsChildren(true)
	local back = face:CreateTexture(nil, "OVERLAY", nil, MARK_BACK_SUBLEVEL)
	back:SetAllPoints(face)
	back:SetColorTexture(Widgets.Rgba("black", MARK_BACK_ALPHA))
	local text = Widgets.FontString(face, "OVERLAY")
	text:SetDrawLayer("OVERLAY", MARK_SUBLEVEL)
	text:SetPoint("CENTER", face, "CENTER", 0, 0)
	return { host = host, ghost = ghost, window = window, face = face, back = back, text = text, key = MORE }
end

local function MarkCorner(k, size)
	local side = k.auraGrowth == "LEFT" and "LEFT" or "RIGHT"
	local vertical = k.auraWrap == "DOWN" and "TOP" or "BOTTOM"
	return vertical .. side, side == "LEFT" and size or 0, vertical == "BOTTOM" and size or 0
end

local function ConfigureDispelGhost(f, k, a, block, filter)
	local more = f.dispelMore
	if not more then
		return
	end
	local ghost = more.ghost
	local on = a.enabled and f.processed and DispelCount(k) > 0 and block.cells > 0
	ghost:SetAuraGroupEnabled(MORE, on and true or false)
	more.window:SetShown(on and true or false)
	if not on then
		return
	end
	local cap = GroupCount(f, k, DISPELS) + OVERFLOW
	local badge = Widgets.Snap(f, math.max(MARK_MIN, block.size * MARK_SHARE))
	local pitch = badge * MORE_PITCH
	ghost:SetAuraProcessingPolicy(Processing(), PolicyOptions())
	ghost:SetAuraGroupFilterString(MORE, filter)
	ghost:SetAuraGroupMaxFrameCount(MORE, cap)
	ghost:SetAuraGroupLayout(MORE, { elementWidth = 1, elementHeight = pitch, elementSpacing = 0, lineSpacing = 0 })
	local window = more.window
	local corner, x, y = MarkCorner(k, block.size)
	window:ClearAllPoints()
	window:SetSize(badge, badge)
	window:SetPoint("TOPRIGHT", f.auraClip, corner, x, y)
	window:SetFrameLevel(f.auras:GetFrameLevel() + 1 + TEXT_ABOVE + MarkLift(DISPELS))
	ghost:ClearAllPoints()
	ghost:SetPoint("TOPLEFT", window, "TOPLEFT", 0, cap * pitch)
	local face = more.face
	face:ClearAllPoints()
	face:SetPoint("TOPLEFT", ghost, "BOTTOMLEFT", 0, 0)
	face:SetSize(badge, badge)
	face:SetFrameLevel(window:GetFrameLevel() + 1)
	Style.SetFont(more.text, Settings.current.text.healthFont, math.max(MARK_MIN, math.floor(badge + 0.5)), "OUTLINE")
	more.text:SetTextColor(Tokens.Color(MARK_COLORS[DISPELS]))
	more.text:SetText(MARK)
end

local function NewContainer(f)
	local clip = CreateFrame("Frame", nil, f)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	f.auraClip = clip
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, clip, TEMPLATE)
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
	local highlights = NewHighlights(f)
	f.highlights = highlights
	if highlights then
		f.glowSlots = {}
		for key, candidates in pairs(GLOWS) do
			local made, glowErr = pcall(highlights.AddAuraSlot, highlights, key, GLOW_FILTER, {
				candidateFilters = candidates,
				initializeFrame = function(slot)
					local built, buildErr = pcall(Auras.BuildGlow, slot, f)
					if not built then
						Style.LogOnce("glowBuild", "building the debuff glow failed: " .. tostring(buildErr))
					end
				end,
			})
			if made then
				f.glowSlots[key] = true
			else
				Style.LogOnce("glowSlot", "the debuff glow slot could not be added: " .. tostring(glowErr))
			end
		end
		local slotted, slotErr = pcall(highlights.AddAuraSlot, highlights, SLOT, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER, {
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
	end
	if f.processed then
		f.dispelMore = NewDispelGhost(f, FILTERS[a.filter] or FILTERS.ALL)
	end
	Style.LogOnce("auraEngine", "group frame debuffs run on the AuraContainer engine")
	return container
end

local function NewBuffContainer(f)
	local clip = CreateFrame("Frame", nil, f)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	f.buffClip = clip
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, clip, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		buffsAvailable = false
		Style.LogOnce("buffMissing", "the AuraContainer engine (" .. TEMPLATE .. ") is unavailable, so group frames show none of your heals over time: " .. tostring(container))
		return nil
	end
	owners[container] = f
	buffHolders[container] = true
	container:SetFrameLevel(f:GetFrameLevel() + CONTAINER_LEVEL)
	if type(container.SetEditModePreviewEnabled) == "function" then
		pcall(container.SetEditModePreviewEnabled, container, false)
	end
	local k = Settings.current[f.kind]
	local added, err = pcall(function()
		local options = { maxFrameCount = k.buffCount, initializeFrame = InitIcon, layout = BuffLayout(f, k) }
		local policy, types = Processing()
		if policy and type(container.SetAuraProcessingPolicy) == "function" then
			container:SetAuraProcessingPolicy(policy, BuffPolicy())
			options.candidateFilters = { processedAuraType = types.Buff }
		else
			Style.LogOnce("buffPolicy", "the aura processing policy is missing; group frames show every buff you cast as a heal icon")
		end
		local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
		if methods and directions then
			options.sortMethod = methods.Default
			options.sortDirection = directions.Normal
		end
		container:AddAuraGroup(BUFFS, BUFF_FILTER, options)
	end)
	if not added then
		container:Hide()
		buffsAvailable = false
		Style.LogOnce("buffGroup", "the heal icon group could not be added: " .. tostring(err))
		return nil
	end
	Style.LogOnce("buffEngine", "your heals over time on group frames run on the AuraContainer engine")
	return container
end

local function HealIcons(f, k)
	local size, spacing = BuffSizes(f, k)
	local inset = Widgets.Snap(f, Tokens.Size("gapTiny"))
	local lane = f.parts and f.parts.healLane
	if lane then
		local gap = Widgets.Snap(f, Tokens.Size("gapSmall"))
		local count = k.buffCount
		while count > 0 and Geometry.Line(count, size, spacing) > lane.width - gap + LINE_SLACK do
			count = count - 1
		end
		return "LEFT", count, size, spacing, inset, gap
	end
	local a = Settings.current.auras
	local side, count = Geometry.HealIcons(f.width or k.width, f.height or k.height, f.parts.health, {
		inset = inset, gap = Widgets.Snap(f, Tokens.Size("gapSmall")), size = size, spacing = spacing, count = k.buffCount,
		debuffs = a.enabled, debuffPosition = k.auraPosition, debuffSize = Widgets.Snap(f, k.auraSize),
		debuffColumns = k.auraColumns, debuffRows = k.auraRows, debuffCount = Count(k), dispelCount = DispelCount(k),
		reserve = Auras.BarTextReserve(f, k),
	})
	return side, count, size, spacing, inset
end
Auras.HealIcons = HealIcons

function Auras.BarTextReserve(f, k)
	if k.healthText == "NONE" or k.healthTextPlace ~= "BAR" or k.textLayout ~= "ABOVE" or not f.parts or f.parts.nameInside then
		return nil
	end
	return Style.Reserve(f, k)
end

function Auras.HealBlock(f, k)
	if not Settings.current.buffs.enabled or not f.parts then
		return 0, "RIGHT"
	end
	local side, count, size, spacing, inset, lane = HealIcons(f, k)
	if count <= 0 or lane then
		return 0, side
	end
	return Geometry.Line(count, size, spacing) + inset + Widgets.Snap(f, Tokens.Size("gapSmall")), side
end

local function ConfigureBuffs(f)
	local container = f.buffs
	local k = Settings.current[f.kind]
	local side, count, size, spacing, inset, lane = HealIcons(f, k)
	local corner = "TOP" .. side
	local clip = f.buffClip
	clip:ClearAllPoints()
	if lane then
		clip:SetPoint(corner, f.health, "RIGHT", lane, Widgets.Snap(f, size / 2))
	else
		clip:SetPoint(corner, f.health, side, side == "RIGHT" and -inset or inset, Widgets.Snap(f, size / 2))
	end
	clip:SetSize(math.max(1, Geometry.Line(count, size, spacing)), size)
	container:ClearAllPoints()
	container:SetPoint(corner, clip, corner, 0, 0)
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local direction = AnchorUtil and AnchorUtil.FlowDirection
	if axis and direction then
		container:SetFlowLayoutAxis(axis.Horizontal)
		container:SetFlowLayoutAnchorPoint(corner)
		container:SetFlowLayoutGrowthDirection(side == "RIGHT" and direction.Left or direction.Right, direction.Down)
		container:SetFlowLayoutMaximumLineSize(Geometry.Line(math.max(1, count), size, spacing) + LINE_SLACK)
	end
	container:SetAuraGroupLayout(BUFFS, BuffLayout(f, k))
	container:SetAuraGroupMaxFrameCount(BUFFS, math.max(1, count) + OVERFLOW)
	container:SetAuraGroupEnabled(BUFFS, Settings.current.buffs.enabled and count > 0)
	Restyle(f)
end

local function Configure(f)
	local container = f.auras
	local k, a = Settings.current[f.kind], Settings.current.auras
	local size, spacing = Sizes(f, k)
	local block = Block(f, k)
	local point, rel, x, y = Geometry.AuraAnchor(block.position, k.auraGrowth, k.auraWrap, block.inset, block.gap)
	local clip = f.auraClip
	clip:ClearAllPoints()
	clip:SetPoint(point, f, rel, x, y)
	clip:SetSize(math.max(1, block.width), math.max(1, block.height))
	clip:SetShown(block.cells > 0)
	container:ClearAllPoints()
	container:SetPoint(point, clip, point, 0, 0)
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis
	local direction = AnchorUtil and AnchorUtil.FlowDirection
	if axis and direction then
		container:SetFlowLayoutAxis(axis.Horizontal)
		container:SetFlowLayoutAnchorPoint(point)
		container:SetFlowLayoutGrowthDirection(k.auraGrowth == "LEFT" and direction.Left or direction.Right, k.auraWrap == "DOWN" and direction.Down or direction.Up)
		container:SetFlowLayoutMaximumLineSize(Geometry.AuraLine(math.max(1, block.columns), size, spacing) + LINE_SLACK)
	else
		Style.LogOnce("auraAnchor", "AnchorUtil is missing; debuffs keep the engine's default layout")
	end
	local filter = FILTERS[a.filter] or FILTERS.ALL
	if f.processed then
		container:SetAuraProcessingPolicy(Processing(), PolicyOptions())
		local dispels = DispelCount(k)
		for _, key in ipairs({ BOSS, IMPORTANT, DISPELS }) do
			container:SetAuraGroupLayout(key, GroupLayout(f, k, key))
			container:SetAuraGroupFilterString(key, filter)
			container:SetAuraGroupMaxFrameCount(key, GroupCount(f, k, key))
		end
		container:SetAuraGroupEnabled(BOSS, a.enabled)
		container:SetAuraGroupEnabled(IMPORTANT, a.enabled)
		container:SetAuraGroupEnabled(DISPELS, a.enabled and dispels > 0)
	end
	local highlights = f.highlights
	for key in pairs(f.glowSlots or {}) do
		highlights:SetAuraSlotEnabled(key, a.glow)
	end
	container:SetAuraGroupLayout(GROUP, GroupLayout(f, k, GROUP))
	container:SetAuraGroupMaxFrameCount(GROUP, GroupCount(f, k, GROUP))
	container:SetAuraGroupFilterString(GROUP, filter)
	if f.processed then
		local _, types = Processing()
		container:SetAuraGroupCandidateFilters(GROUP, Candidates(GROUP, types, k))
	end
	container:SetAuraGroupEnabled(GROUP, a.enabled)
	ConfigureDispelGhost(f, k, a, block, filter)
	if f.dispelSlot then
		highlights:SetAuraSlotFilterString(SLOT, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER)
		highlights:SetAuraSlotEnabled(SLOT, a.dispelHighlight)
	end
	Restyle(f)
end

local function Layout(f)
	if f.sample then
		return
	end
	if f.auras then
		local ok, err = pcall(Configure, f)
		if not ok then
			Style.LogOnce("auraConfigure", "configuring debuffs failed: " .. tostring(err))
		end
	end
	if f.buffs then
		local ok, err = pcall(ConfigureBuffs, f)
		if not ok then
			Style.LogOnce("buffConfigure", "configuring heal icons failed: " .. tostring(err))
		end
	end
end

local waiting = setmetatable({}, { __mode = "k" })

local function Bind(f)
	if f.sample then
		return
	end
	local a = Settings.current.auras
	local on = (a.enabled or a.dispelHighlight or a.glow) and available and Unit.running
	if not on then
		if f.auras then
			SetUnit(f, NONE)
			f.auras:Hide()
			if f.highlights then
				f.highlights:Hide()
			end
			if f.dispelMore then
				f.dispelMore.window:Hide()
			end
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
	if f.highlights then
		f.highlights:Show()
	end
	SetUnit(f, f.unit or NONE)
end
Auras.Bind = Bind

local buffWaiting = setmetatable({}, { __mode = "k" })

local function BindBuffs(f)
	if f.sample then
		return
	end
	local on = Settings.current.buffs.enabled and buffsAvailable and Unit.running
	if not on then
		if f.buffs then
			SetBuffUnit(f, NONE)
			f.buffs:Hide()
		end
		return
	end
	if not f.buffs then
		if not f.unit then
			return
		end
		if InCombatLockdown() then
			if not buffWaiting[f] then
				buffWaiting[f] = true
				K.Combat.Queue(function()
					buffWaiting[f] = nil
					BindBuffs(f)
				end)
			end
			return
		end
		f.buffs = NewBuffContainer(f)
		if not f.buffs then
			return
		end
		Layout(f)
	end
	f.buffs:Show()
	SetBuffUnit(f, f.unit or NONE)
end
Auras.BindBuffs = BindBuffs

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
	f.sampleBuffs = {}
	for i, fileID in ipairs(SAMPLE_BUFF_ICONS) do
		local icon = CreateFrame("Frame", nil, holder)
		local tile = NewTile(icon)
		tile.icon:SetTexture(fileID)
		icon.tile, icon.art = tile, tile.icon
		f.sampleBuffs[i] = icon
	end
	local markLayer = CreateFrame("Frame", nil, holder)
	markLayer:SetAllPoints(holder)
	markLayer:SetFrameLevel(holder:GetFrameLevel() + #SAMPLE_ICONS + 1)
	f.sampleMark = Widgets.FontString(markLayer, "OVERLAY")
	f.sampleDispel = CreateFrame("Frame", nil, holder)
	f.sampleDispel:SetAllPoints(f)
	f.sampleDispelWash, f.sampleDispelRing = NewDispel(f.sampleDispel)
end
Button.built[#Button.built + 1] = BuildSamples

local function LayoutSamples(f, k)
	local holder = f.sampleAuraHolder
	local block = Block(f, k)
	local size, spacing = block.size, block.spacing
	local inset = block.inset
	local columns = math.max(1, block.columns)
	f.sampleCells = block.cells
	local point, rel, x, y = Geometry.AuraAnchor(block.position, k.auraGrowth, k.auraWrap, inset, block.gap)
	holder:ClearAllPoints()
	holder:SetPoint(point, f, rel, x, y)
	holder:SetSize(size, size)
	local dx = k.auraGrowth == "LEFT" and -1 or 1
	local dy = k.auraWrap == "DOWN" and -1 or 1
	for i, icon in ipairs(f.sampleAuras) do
		local index = i - 1
		local col, row = index % columns, math.floor(index / columns)
		icon:ClearAllPoints()
		icon:SetSize(size, size)
		icon:SetPoint(point, holder, point, dx * col * (size + spacing), dy * row * (size + spacing))
		icon.tile.chrome:Restyle()
		icon.tile.chrome:SetRimAccent(Style.Accent())
		PlaceIcon(icon.tile)
	end
	local side, fit, buffSize, buffSpacing, _, lane = HealIcons(f, k)
	f.sampleBuffFit = fit
	local step = side == "RIGHT" and -1 or 1
	for i, icon in ipairs(f.sampleBuffs) do
		icon:ClearAllPoints()
		icon:SetSize(buffSize, buffSize)
		if lane then
			icon:SetPoint("LEFT", f.health, "RIGHT", lane + (i - 1) * (buffSize + buffSpacing), 0)
		else
			icon:SetPoint(side, f.health, side, step * (inset + (i - 1) * (buffSize + buffSpacing)), 0)
		end
		icon.tile.chrome:Restyle()
		icon.tile.chrome:SetRimAccent(Style.Accent())
		PlaceIcon(icon.tile)
	end
	LayoutDispel(f.sampleDispelWash, f.sampleDispelRing, f.sampleDispel, f.chrome:Chamfer())
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
	local cells = f.sampleCells or Count(k)
	local shown = a.enabled and math.min(sample.debuffs or 0, cells, #f.sampleAuras) or 0
	for i, icon in ipairs(f.sampleAuras) do
		icon:SetShown(i <= shown)
	end
	local more = a.enabled and shown > 0 and (sample.debuffs or 0) > shown
	f.sampleMark:ClearAllPoints()
	if more then
		f.sampleMark:SetPoint("TOPRIGHT", f.sampleAuras[shown], "TOPRIGHT", 0, 0)
		Style.SetFont(f.sampleMark, Settings.current.text.healthFont, math.max(6, math.floor(Sizes(f, k) * MARK_SHARE + 0.5)), "OUTLINE")
		f.sampleMark:SetTextColor(Tokens.Color("textEmphasis"))
		f.sampleMark:SetText(MARK)
	end
	f.sampleMark:SetShown(more)
	local hots = Settings.current.buffs.enabled and math.min(sample.hots or 0, f.sampleBuffFit or k.buffCount) or 0
	for i, icon in ipairs(f.sampleBuffs) do
		icon:SetShown(i <= hots)
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
Unit.changed[#Unit.changed + 1] = BindBuffs
Unit.extra[#Unit.extra + 1] = BindBuffs
