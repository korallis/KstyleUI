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
local TYPE_SLOT = "dispelType"
local BOSS_SLOT = "boss"
local BOSS_CANDIDATES = { isBossAura = true }
local TEMPLATE = "CustomAuraContainerTemplate"
local NONE = "none"
local FILTERS = { ALL = "HARMFUL", RAID = "HARMFUL|RAID_IN_COMBAT", DISPELLABLE = "HARMFUL|RAID", CROWD_CONTROL = "HARMFUL|CROWD_CONTROL" }
local PICKS = { BOSS = { isBossOrRoleAura = true, isRoleAura = false }, ROLE = { isRoleAura = true }, IMPORTANT = { isPriorityAura = true } }
local SOURCES = { NPC = false, PLAYERS = true }
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
local TIMER_LINE = 1.3
local SAMPLE_ICONS = { 136207, 135848, 136139, 136071, 135894, 136207, 135848, 136139, 136071, 135894 }
local SAMPLE_TYPES = { "magic", "curse", "poison", "disease", "bleed" }
local SAMPLE_LASTING = 6
local BUFFS = "buffs"
local BUFF_FILTER = "HELPFUL|PLAYER"
local SAMPLE_BUFF_ICONS = { 136081, 135953, 135940 }
local SAMPLE_BOSS_ICON = 136207
local MARK_COLORS = { [BOSS] = "hostile", [IMPORTANT] = "neutral", [DISPELS] = "rare", [GROUP] = "textEmphasis" }
local MARK_LIFT = 2
local MORE = "dispelMore"
local MORE_PITCH = 2
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local CHIP_LABELS = 12
local CHIP_LEVEL = TEXT_ABOVE + 1
local CHIP_TEXT_MIN = 7
local CHIP_TEXT_SHARE = 0.5
local CHIP_TEXT_WIDE = 1.6

local available = true
local buffsAvailable = true
local parts = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })
local buffHolders = setmetatable({}, { __mode = "k" })
local styleGeneration = 0

for _, event in ipairs({ "ThemeChanged", "ScaleChanged" }) do
	K.Callbacks.Register(event, "GroupFrames.AuraInputs", function()
		styleGeneration = styleGeneration + 1
	end)
end

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

local function OneRow(block)
	if Settings.current.auras.timers and block.rows > 1 then
		block.rows, block.cells, block.height = 1, block.columns, block.size
	end
	return block
end

local function Block(f, k)
	local w, h = Style.Size(f)
	local size, spacing = Widgets.Snap(f, k.auraSize), Widgets.Snap(f, k.auraSpacing)
	local inset, gap = Widgets.Snap(f, Tokens.Size("gapTiny")), Widgets.Snap(f, Tokens.Size("gapSmall"))
	local lane = f.kind == "party" and Geometry.AuraLane(k) or 0
	local place, outside = Geometry.AuraPlace(k, lane)
	if not outside then
		local b = f.parts and f.parts.block
		if not b then
			return { position = place, columns = 0, rows = 0, cells = 0, size = size, width = 0, height = 0, left = 0, top = 0, spacing = spacing, inset = inset, gap = gap }
		end
		return OneRow({
			position = b.position, columns = b.columns, rows = b.rows, cells = b.cells, size = b.size, width = b.width, height = b.height,
			left = b.left + k.auraX, top = b.top - k.auraY, spacing = spacing, inset = inset, gap = gap,
		})
	end
	local block = OneRow(Geometry.AuraBlock(k, w, h, size, spacing, inset, lane - gap))
	block.spacing, block.inset, block.gap = spacing, inset, gap
	block.left = (place == "OUTSIDE_LEFT" and -gap - block.width or w + gap) + k.auraX
	block.top = (k.auraWrap == "UP" and h - block.height or 0) - k.auraY
	return block
end
Auras.Block = Block

local function Anchor(f, block, k)
	local point = Geometry.AuraAnchor(block.position, k.auraGrowth, k.auraWrap, block.inset, block.gap)
	local px = point:find("RIGHT$") and block.left + block.width or block.left
	local py = point:find("^BOTTOM") and block.top + block.height or block.top
	return point, Widgets.Snap(f, px), -Widgets.Snap(f, py)
end

local function GroupCount(f, k, key)
	local cells = f and Block(f, k).cells or Count(k)
	if key == DISPELS then
		return math.max(1, math.min(DispelCount(k), cells))
	end
	return cells + OVERFLOW
end

local DISPEL_TYPES = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease", bleed = "Bleed" }

local function Narrowed()
	local a = Settings.current.auras
	return not (a.magic and a.curse and a.poison and a.disease and a.bleed and a.lasting) or a.typeMode == "ONLY" or a.canApply
		or SOURCES[a.source] ~= nil or PICKS[a.filter] ~= nil
end

local function Narrow(candidates)
	if not Narrowed() then
		return candidates
	end
	local a = Settings.current.auras
	local only = a.typeMode == "ONLY"
	local field = only and "includeDispelTypes" or "excludeDispelTypes"
	if only then candidates[field] = {} end
	for key, name in pairs(DISPEL_TYPES) do
		if a[key] == only then
			candidates[field] = candidates[field] or {}
			candidates[field][name] = true
		end
	end
	if not a.lasting then
		candidates.maxDuration = math.huge
	end
	if a.canApply then candidates.canApplyAura = true end
	candidates.isFromPlayerOrPlayerPet = SOURCES[a.source]
	for k, v in pairs(PICKS[a.filter] or {}) do
		if candidates[k] == nil or candidates[k] == v then candidates[k] = v else candidates.includeDispelTypes = {} end
	end
	return candidates
end

local function Candidates(key, types, k)
	if key == BOSS then
		return Narrow({ isBossAura = true })
	elseif key == IMPORTANT then
		return Narrow({ isBossAura = false, isPriorityAura = true })
	end
	if key == GROUP and k and DispelCount(k) <= 0 then
		return Narrow({ isBossAura = false, isPriorityAura = false })
	end
	local processed = key == DISPELS and types.Dispel or types.Debuff
	return Narrow({ processedAuraType = processed, isBossAura = false, isPriorityAura = false })
end

local function Filter()
	local a = Settings.current.auras
	return K.Options.AuraFilterString(a, FILTERS[a.filter] or FILTERS.ALL)
end

local function Sizes(f, k)
	return Auras.Block(f, k).size, Widgets.Snap(f, k.auraSpacing)
end

local function BuffSizes(f, k)
	local _, h = Style.Size(f)
	local room = math.max(1, h - 2 * Widgets.Snap(f, Tokens.Size("gapTiny")))
	local row = f.parts and f.parts.healRow
	if row then
		room = math.min(room, row.height)
	end
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

local function TimerSize(size)
	local own = Settings.current.auras.timerSize
	return own > 0 and own or math.max(6, math.floor(size * COUNT_SHARE + 0.5))
end

local function TimerRoom(f, size)
	local a = Settings.current.auras
	if not a.timers then return 0, 0, 0 end
	local x, y = Widgets.Snap(f, a.timerX), Widgets.Snap(f, a.timerY)
	return math.ceil(TimerSize(size) * TIMER_LINE) + Widgets.Border(f) + math.max(0, -y), math.abs(x), math.max(0, y - size)
end

local function PlaceTimer(timer, skin)
	local a = Settings.current.auras
	timer:ClearAllPoints()
	timer:SetPoint("TOP", skin, "BOTTOM", Widgets.Snap(skin, a.timerX), Widgets.Snap(skin, a.timerY) - Widgets.Border(skin))
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
	wash.alpha = WASH_ALPHA
	return wash, Style.Ring(owner, "OVERLAY")
end

local function DispelStyle()
	local enum = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	return enum and enum.PreserveAsset
end

local colorKey, colorGeneration
local function ColorKey()
	if colorKey and colorGeneration == Settings.generation then return colorKey end
	local d = Settings.current.dispel
	colorGeneration, colorKey = Settings.generation, "game"
	if not d.custom or type(CreateColor) ~= "function" then return colorKey end
	local out = {}
	for _, key in ipairs(SAMPLE_TYPES) do
		local c = d[key]
		out[#out + 1] = c.r .. "," .. c.g .. "," .. c.b
	end
	colorKey = table.concat(out, ";")
	return colorKey
end

local function Tinted(options)
	local d = Settings.current.dispel
	if not d.custom or type(CreateColor) ~= "function" then return options end
	local map = {}
	for key, name in pairs(DISPEL_TYPES) do
		local c = d[key]
		map[name] = CreateColor(c.r, c.g, c.b, 1)
	end
	options.customDispelColorMap = map
	return options
end

local function Retint(owner, pieces, options)
	for _, piece in ipairs(pieces) do
		owner:RemoveDispelTypeTexture(piece)
		owner:AddDispelTypeTexture(piece, options)
	end
end

local function IconKey()
	local d = Settings.current.dispel
	if not d.custom then return d.iconBorder and "game+" or "game-" end
	return ColorKey() .. (d.iconBorder and "+" or "-")
end

local function TintIcon(button, p)
	local key = IconKey()
	if p.tint == key or not DispelStyle() then return end
	local on = Settings.current.dispel.iconBorder
	if p.tintOn then
		for _, piece in ipairs(p.dispel) do button:RemoveDispelTypeTexture(piece) end
	end
	local options = Tinted({ style = DispelStyle(), showWhenHarmful = true, showWithoutDispelType = true })
	for _, piece in ipairs(p.dispel) do
		if on then button:AddDispelTypeTexture(piece, options) else piece:Hide() end
	end
	p.tint, p.tintOn = key, on
end

local function LayoutDispel(wash, ring, owner, chamfer, engine)
	Style.LayoutWash(wash, owner, chamfer)
	Style.LayoutRing(ring, owner, chamfer)
	local a = Settings.current.auras
	if wash.alpha ~= a.dispelAlpha then
		for _, piece in ipairs(wash) do
			piece:SetAlpha(a.dispelAlpha)
		end
		wash.alpha = a.dispelAlpha
	end
	local key = engine and DispelStyle() and ColorKey()
	if key and wash.tint ~= key then
		local options = Tinted({ style = DispelStyle(), showWhenHarmful = true })
		Retint(owner, wash, options)
		for _, line in ipairs(ring) do
			if line.on ~= false then Retint(owner, line, options) end
		end
		wash.tint = key
	end
	for i, line in ipairs(ring) do
		local on = i <= a.dispelLines
		if engine and (line.on ~= false) ~= on and DispelStyle() then
			local options = on and Tinted({ style = DispelStyle(), showWhenHarmful = true })
			for _, piece in ipairs(line) do
				if on then
					owner:AddDispelTypeTexture(piece, options)
				else
					owner:RemoveDispelTypeTexture(piece)
					piece:Hide()
				end
			end
		elseif not engine then
			for _, piece in ipairs(line) do
				piece:SetShown(on)
			end
		end
		line.on = on
	end
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

local function Zoom(icon, zoom)
	icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
end

local function IconZoom(kind)
	local a = Settings.current.auras
	if not a.zoomEach then return a.zoom end
	return kind == "buff" and Settings.current.buffs.zoom or kind == BOSS_SLOT and a.bossZoom or a.zoom
end

local function Tips(p)
	return Settings.current[p.buff and "buffs" or "auras"].tooltips
end

local function StyleIcon(button)
	local p = parts[button]
	local f = p and p.owner
	if not f then
		return
	end
	local k = Settings.current[f.kind]
	TintIcon(button, p)
	if p.dispelLetter then p.dispelLetter:SetAlpha(Settings.current.auras.typeLetters and 1 or 0) end
	local size = p.size and p.size() or (p.buff and BuffSizes(f, k) or Sizes(f, k))
	local border = Widgets.Border(p.skin)
	local text, a = Settings.current.text, Settings.current.auras
	local ar, ag, ab = Style.Accent()
	local mark = p.mark and not p.size and (p.buff or not f.debuffChip)
	local block = mark and (p.buff and f.parts and f.parts.healRow or Block(f, k))
	local columns = block and (block.columns or block.width)
	local rows = block and (block.rows or block.height)
	local side = p.buff and block and block.side
	local tips = Tips(p)
	local zoom = IconZoom(p.buff and "buff" or p.group)
	if p.styledCursor == a.tipCursor and p.styledCountX == a.countX and p.styledCountY == a.countY and p.styledTimerX == a.timerX and p.styledTimerY == a.timerY
		and p.styledGeneration == styleGeneration and p.styledSize == size and p.styledBorder == border and p.styledFont == text.healthFont and p.styledSwipe == a.swipe and p.styledR == ar and p.styledG == ag and p.styledB == ab and p.styledMark == mark and p.styledColumns == columns and p.styledRows == rows and p.styledSide == side and p.styledGrowth == k.auraGrowth and p.styledWrap == k.auraWrap and p.styledSpacing == k.auraSpacing and p.styledBuffCount == k.buffCount and p.styledStacks == a.stacks and p.styledTimers == a.timers and p.styledTimerSize == a.timerSize and p.styledZoom == zoom and p.styledTips == tips and p.styledTipCombat == a.tipCombat and p.styledOutline == a.textOutline and (not mark or p.styledPriority == MarkLift(p.group)) then
		return
	end
	local moved = p.styledSize ~= size or p.styledBorder ~= border or p.styledCountX ~= a.countX or p.styledCountY ~= a.countY
	if p.styledSize ~= size or p.styledBorder ~= border then
		Widgets.Size(button, size, size)
		p.restyleChrome(p.chrome)
		p.inset = PlaceIcon(p)
		Widgets.LayoutSlice(p.dispel, p.skin, p.chrome:Chamfer(), 0)
		if p.dispelLetter then Widgets.Size(p.dispelLetter, math.min(14, size), math.min(14, size)) end
		p.styledSize, p.styledBorder = size, border
	end
	if moved then
		p.count:ClearAllPoints()
		p.count:SetPoint("BOTTOMRIGHT", p.skin, "BOTTOMRIGHT", Widgets.Snap(p.skin, a.countX) - p.inset, p.inset + Widgets.Snap(p.skin, a.countY))
	end
	p.chrome:SetRimAccent(ar, ag, ab)
	local textSize = math.max(6, math.floor(size * COUNT_SHARE + 0.5))
	Style.SetFont(p.count, text.healthFont, textSize, a.textOutline)
	p.count:SetAlpha(a.stacks and 1 or 0)
	if a.timers and type(button.SetDurationText) == "function" then
		local timer = p.timer or Widgets.Fitted(Widgets.FontString(p.textFrame, "OVERLAY"))
		Style.SetFont(timer, text.healthFont, TimerSize(size), a.textOutline)
		PlaceTimer(timer, p.skin)
		if not (p.timer and p.styledTimers) then button:SetDurationText(timer) end
		p.timer = timer
		timer:Show()
	elseif p.timer and p.styledTimers then
		button:ClearDurationText()
		p.timer:Hide()
	end
	p.cooldown:SetDrawSwipe(Settings.current.auras.swipe)
	if zoom ~= (p.styledZoom or ICON_CROP) then Zoom(p.icon, zoom) end
	if a.tipCursor ~= (p.styledCursor or false) and type(button.SetTooltipAnchorPoint) == "function" then
		pcall(button.SetTooltipAnchorPoint, button, a.tipCursor and "ANCHOR_CURSOR" or "ANCHOR_BOTTOMLEFT")
	end
	if tips ~= (p.styledTips ~= false) and button.SetMouseMotionEnabled then
		pcall(button.SetMouseMotionEnabled, button, tips)
	end
	if a.tipCombat ~= (p.styledTipCombat ~= false) and type(button.SetHideTooltipInCombat) == "function" then
		pcall(button.SetHideTooltipInCombat, button, not a.tipCombat)
	end
	if p.mark and not p.size then
		if p.buff or not f.debuffChip then
			Auras.PlaceMark(p, button, f, k)
		else
			p.mark:SetText("")
			p.mark:Hide()
			p.markBack:Hide()
		end
	end
	p.styledFont, p.styledSwipe, p.styledStacks, p.styledTimers, p.styledTimerSize = text.healthFont, a.swipe, a.stacks, a.timers, a.timerSize
	p.styledZoom, p.styledTips, p.styledTipCombat, p.styledOutline = zoom, tips, a.tipCombat, a.textOutline
	p.styledCursor, p.styledCountX, p.styledCountY, p.styledTimerX, p.styledTimerY = a.tipCursor, a.countX, a.countY, a.timerX, a.timerY
	p.styledR, p.styledG, p.styledB = ar, ag, ab
	p.styledMark, p.styledColumns, p.styledRows, p.styledSide = mark, columns, rows, side
	p.styledGrowth, p.styledWrap, p.styledSpacing, p.styledBuffCount = k.auraGrowth, k.auraWrap, k.auraSpacing, k.buffCount
	p.styledGeneration, p.styledPriority = styleGeneration, mark and MarkLift(p.group)
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

local styledGroups = setmetatable({}, { __mode = "k" })

local function StyleGroup(container, key)
	local f = owners[container]
	local k, cfg = Settings.current[f.kind], Settings.current
	local buff = buffHolders[container]
	local size, spacing
	if buff then size, spacing = BuffSizes(f, k) else size, spacing = Sizes(f, k) end
	local block = Block(f, k)
	local row = f.parts and f.parts.healRow
	local ar, ag, ab = Style.Accent()
	local count = container:GetAuraGroupFrameCount(key)
	local inputs = { styleGeneration, size, spacing, block.columns, block.rows, k.auraGrowth, k.auraWrap, k.buffCount, cfg.text.healthFont, cfg.auras.swipe, Widgets.Border(f), ar, ag, ab, MarkLift(key), f.debuffChip ~= nil, k.buffSize, row and row.width, row and row.height, row and row.side, cfg.auras.typeLetters, cfg.auras.stacks, cfg.auras.timers, cfg.auras.timerSize, cfg.auras.zoom, cfg.auras.tooltips, cfg.buffs.tooltips, cfg.auras.tipCombat, cfg.auras.textOutline, IconKey(),
		cfg.auras.zoomEach, cfg.auras.bossZoom, cfg.buffs.zoom, cfg.auras.tipCursor, cfg.auras.countX, cfg.auras.countY, cfg.auras.timerX, cfg.auras.timerY }
	local groups = styledGroups[container]
	local old = groups and groups[key]
	local changed = f.auraInputsDirty or not old or old.count ~= count
	if not changed then
		for i = 1, #inputs do
			if old[i] ~= inputs[i] then changed = true; break end
		end
	end
	if not changed then return true end
	for i = 1, count do
		local ok, err = pcall(StyleIcon, container:GetAuraGroupFrame(key, i))
		if not ok then
			Style.LogOnce("auraStyle", "restyling an aura icon failed: " .. tostring(err))
			return false
		end
	end
	groups = groups or {}
	styledGroups[container], groups[key], inputs.count = groups, inputs, count
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
		f.auraInputsDirty = nil
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
		local ok, err = pcall(LayoutDispel, f.dispelWash, f.dispelRing, f.dispelFrame, f.chrome:Chamfer(), true)
		if not ok then
			Style.LogOnce("dispelStyle", "laying out the dispel highlight failed: " .. tostring(err))
		end
	end
	f.auraInputsDirty = nil
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

local function GateChrome(chrome, f, p)
	local restyle = chrome.Restyle
	local draw = chrome.DrawSlices
	if draw then
		chrome.DrawSlices = function(self)
			if AurasSecret() then
				if f then
					f.auraInputsDirty = true
					Defer(f)
				end
				return
			end
			return draw(self)
		end
	end
	chrome.Restyle = function(self)
		if AurasSecret() then
			if p then
				p.styledSize = nil
			end
			if f then
				f.auraInputsDirty = true
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
	local count = Widgets.Fitted(Widgets.FontString(textFrame, "OVERLAY"))
	count:SetJustifyH("RIGHT")
	p.markBack = textFrame:CreateTexture(nil, "OVERLAY", nil, MARK_BACK_SUBLEVEL)
	p.markBack:SetColorTexture(Widgets.Rgba("black", MARK_BACK_ALPHA))
	p.mark = Widgets.Fitted(Widgets.FontString(textFrame, "OVERLAY"))
	p.mark:SetDrawLayer("OVERLAY", MARK_SUBLEVEL)
	p.cooldown, p.count = cooldown, count
	parts[button] = p
	StyleIcon(button)
	p.chrome:DrawSlices()
	button:SetIcon(p.icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	local types = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	if not p.buff and types and types.CustomAsset ~= nil and K.ColorVision and type(button.AddDispelTypeTexture) == "function" then
		p.dispelLetter = textFrame:CreateTexture(nil, "OVERLAY")
		p.dispelLetter:SetPoint("TOPRIGHT", p.skin, "TOPRIGHT")
		local letter = math.min(14, p.styledSize or 14)
		Widgets.Size(p.dispelLetter, letter, letter)
		p.dispelLetter:Hide()
		p.dispelLetter:SetAlpha(Settings.current.auras.typeLetters and 1 or 0)
		button:AddDispelTypeTexture(p.dispelLetter, { style = types.CustomAsset, showWhenHarmful = true, customDispelAssetMap = K.ColorVision.DispelAssets() })
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

function Auras.Dress(button, owner, size, key)
	owners[button:GetParent()] = owner
	local ok, err = pcall(BuildIcon, button, key)
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
	f.dispelWash, f.dispelRing, f.dispelFrame = wash, ring, slot
	local style = DispelStyle()
	if style then
		local options = Tinted({ style = style, showWhenHarmful = true })
		wash.tint = ColorKey()
		for _, piece in ipairs(wash) do
			slot:AddDispelTypeTexture(piece, options)
		end
		Style.Pieces(ring, function(piece)
			slot:AddDispelTypeTexture(piece, options)
		end)
	else
		Style.LogOnce("dispelStyle", "the dispel texture styles are missing; the dispel highlight stays off")
	end
	LayoutDispel(wash, ring, slot, f.chrome:Chamfer(), true)
end

local function PlaceType(f)
	local d, slot = Settings.current.dispel, f.typeFrame
	if not slot or d.icon == "NONE" then return end
	slot:SetFrameLevel(f.highlights:GetFrameLevel() + TEXT_ABOVE)
	Style.Pin(f, f.typeIcon, d.icon, Widgets.Snap(f, math.min(d.iconSize, f.parts.health.height)), d.x, d.y)
end

local function TypeOptions()
	return Tinted({ style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset, showWhenHarmful = true, customDispelAssetMap = K.ColorVision.DispelAssets() })
end

local function BuildType(slot, f)
	pcall(slot.EnableMouse, slot, false)
	slot:ClearAllPoints()
	slot:SetAllPoints(f)
	f.typeFrame, f.typeIcon, f.typeTint = slot, slot:CreateTexture(nil, "OVERLAY"), ColorKey()
	slot:AddDispelTypeTexture(f.typeIcon, TypeOptions())
	PlaceType(f)
end

Auras.restylers[#Auras.restylers + 1] = function(f)
	if f.typeFrame and f.typeTint ~= ColorKey() then
		Retint(f.typeFrame, { f.typeIcon }, TypeOptions())
		f.typeTint = ColorKey()
	end
end

local function ConfigureType(f, filter)
	local highlights, on = f.highlights, Settings.current.dispel.icon ~= "NONE"
	if on and highlights and f.typeSlot == nil and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and K.ColorVision then
		f.typeSlot = pcall(highlights.AddAuraSlot, highlights, TYPE_SLOT, filter, { initializeFrame = function(slot)
			local built, err = pcall(BuildType, slot, f)
			if not built then Style.LogOnce("typeBuild", "building the dispel type icon failed: " .. tostring(err)) end
		end })
	end
	if f.typeSlot then
		highlights:SetAuraSlotFilterString(TYPE_SLOT, filter)
		highlights:SetAuraSlotEnabled(TYPE_SLOT, on)
		PlaceType(f)
	end
end

local function GroupOptions(f, k, key, types)
	local options = { maxFrameCount = GroupCount(f, k, key), initializeFrame = GroupInit(key or GROUP), layout = GroupLayout(f, k, key) }
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if methods and directions then
		options.sortMethod = types and methods.UnitFrameDebuff or methods.Default
		options.sortDirection = directions.Normal
		options.sortMethod, options.sortDirection = K.Options.AuraSort(Settings.current.auras.sort, options.sortMethod, options.sortDirection)
	end
	if types then options.candidateFilters = Candidates(key, types, k) end
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
	if f.debuffChip then
		local set, chipErr = pcall(Widgets.Overflow.SetUnit, f.debuffChip, unit)
		if not set then
			Style.LogOnce("debuffChipUnit", "the debuff count chip refused a unit: " .. tostring(chipErr))
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
	if ok and container then
		Widgets.KeepOut(container)
	end
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
	local policy, types = Processing()
	ghost:SetAuraProcessingPolicy(policy, PolicyOptions())
	ghost:SetAuraGroupFilterString(MORE, filter)
	if more.narrowed or Narrowed() then ghost:SetAuraGroupCandidateFilters(MORE, Candidates(DISPELS, types)) end
	more.narrowed = Narrowed()
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

local function LastCell(f, k, block)
	local step = block.size + block.spacing
	local col, row = math.max(0, block.columns - 1), math.max(0, block.rows - 1)
	local x = k.auraGrowth == "LEFT" and block.left + block.width - block.size - col * step or block.left + col * step
	local y = k.auraWrap == "UP" and block.top + block.height - block.size - row * step or block.top + row * step
	return x, y
end
Auras.LastCell = LastCell

local function ChipSpec(k, filter, cells)
	local policy, types = Processing()
	local dispels = DispelCount(k) > 0 and math.max(1, math.min(DispelCount(k), cells)) or 0
	local more = CHIP_LABELS + 1
	local groups = {}
	for _, key in ipairs(GROUPS) do
		groups[#groups + 1] = {
			key = key, filter = filter, candidates = Candidates(key, types, k),
			cap = key == DISPELS and math.max(1, dispels) or cells + more, off = key == DISPELS and dispels == 0,
		}
	end
	return { groups = groups, policy = policy, policyOptions = PolicyOptions(), cap = cells }
end

local function NewChip(f, k, filter)
	local Overflow = Widgets.Overflow
	local cells = math.max(1, Block(f, k).cells)
	local chip, why = Overflow.New(f, NONE, { ChipSpec(k, filter, cells) }, cells, { labels = CHIP_LABELS, saturate = true })
	if not chip then
		Style.LogOnce("debuffChip", "the debuff count chip has no counting container (" .. tostring(why) .. "); a full debuff row shows no +N")
	end
	return chip
end

local function ConfigureChip(f, k, a, block, filter)
	local chip = f.debuffChip
	if not chip then
		return
	end
	local on = a.enabled and block.cells > 0
	local x, y = LastCell(f, k, block)
	local spec = ChipSpec(k, filter, math.max(1, block.cells))
	Widgets.Overflow.Apply(chip, {
		enabled = on, groups = { spec }, cap = spec.cap, cell = block.size, width = block.size,
		point = "TOPLEFT", rel = f, relPoint = "TOPLEFT", x = Widgets.Snap(f, x), y = -Widgets.Snap(f, y),
		level = f.auras:GetFrameLevel() + CHIP_LEVEL, textSize = math.max(CHIP_TEXT_MIN, math.floor(math.min(block.size * CHIP_TEXT_SHARE, block.size / CHIP_TEXT_WIDE))),
	})
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
	local added, processed = pcall(AddGroups, container, f, k, Filter())
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
		local bossMade, bossErr = pcall(highlights.AddAuraSlot, highlights, BOSS_SLOT, GLOW_FILTER, {
			candidateFilters = BOSS_CANDIDATES,
			initializeFrame = function(button)
				Auras.Dress(button, f, function()
					return Auras.BossSize(f)
				end, BOSS_SLOT)
			end,
		})
		f.bossSlot = bossMade or nil
		if not bossMade then
			Style.LogOnce("bossSlot", "the boss debuff slot could not be added; boss debuffs stay in the debuff row: " .. tostring(bossErr))
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
		f.dispelMore = NewDispelGhost(f, Filter())
		f.debuffChip = NewChip(f, k, Filter())
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
	local layout = f.parts
	local row = layout and layout.healRow
	if not row then
		return "LEFT", 0, size, spacing, inset
	end
	local count = k.buffCount
	while count > 0 and Geometry.Line(count, size, spacing) > row.width + LINE_SLACK do
		count = count - 1
	end
	if k.buffX ~= 0 or k.buffY ~= 0 then
		row = { left = row.left + k.buffX, top = row.top - k.buffY, width = row.width, height = row.height, side = row.side }
	end
	return row.side or "LEFT", count, size, spacing, inset, nil, row
end
Auras.HealIcons = HealIcons

function Auras.BossSize(f)
	local rect = f.parts and f.parts.boss
	return rect and Widgets.Snap(f, rect.width) or 1
end

function Auras.BossOn(f)
	return f.bossSlot == true and f.parts ~= nil and f.parts.boss ~= nil and Settings.current.auras.enabled
end

local function PlaceBoss(f)
	local highlights = f.highlights
	local button = f.bossSlot and highlights and highlights:GetAuraSlotFrame(BOSS_SLOT)
	local rect = f.parts and f.parts.boss
	if not button or not rect then
		return
	end
	local size = Widgets.Snap(f, rect.width)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top))
	button:SetFrameLevel(highlights:GetFrameLevel() + TEXT_ABOVE)
	StyleIcon(button)
	Widgets.Size(button, size, size)
end
Auras.restylers[#Auras.restylers + 1] = PlaceBoss

local function ConfigureBuffs(f)
	local container = f.buffs
	local k = Settings.current[f.kind]
	local side, count, size, spacing, _, _, row = HealIcons(f, k)
	local corner = "TOP" .. side
	local clip = f.buffClip
	local room, across, up = TimerRoom(f, size)
	local out = side == "RIGHT" and across or -across
	clip:ClearAllPoints()
	if row then
		local x = side == "RIGHT" and row.left + row.width or row.left
		clip:SetPoint(corner, f, "TOPLEFT", Widgets.Snap(f, x) + out, up - Widgets.Snap(f, row.top))
	else
		clip:SetPoint(corner, f, corner, Widgets.Snap(f, k.buffX) + out, Widgets.Snap(f, k.buffY) + up)
	end
	clip:SetSize(math.max(1, Geometry.Line(count, size, spacing)) + 2 * across, size + room + up)
	container:ClearAllPoints()
	container:SetPoint(corner, clip, corner, -out, -up)
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
	local narrow = f.narrowed or Narrowed()
	local size, spacing = Sizes(f, k)
	local block = Block(f, k)
	local point, x, y = Anchor(f, block, k)
	local room, across, up = TimerRoom(f, block.size)
	local lift, rise = point:find("^BOTTOM") and room or 0, point:find("^TOP") and up or 0
	local out = point:find("RIGHT$") and across or -across
	local clip = f.auraClip
	clip:ClearAllPoints()
	clip:SetPoint(point, f, "TOPLEFT", x + out, y - lift + rise)
	clip:SetSize(math.max(1, block.width) + 2 * across, math.max(1, block.height + room) + up)
	clip:SetShown(block.cells > 0)
	container:ClearAllPoints()
	container:SetPoint(point, clip, point, -out, lift - rise)
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
	local filter = Filter()
	local policy, types = Processing()
	if f.processed then
		container:SetAuraProcessingPolicy(policy, PolicyOptions())
		local dispels = DispelCount(k)
		for _, key in ipairs({ BOSS, IMPORTANT, DISPELS }) do
			container:SetAuraGroupLayout(key, GroupLayout(f, k, key))
			container:SetAuraGroupFilterString(key, filter)
			container:SetAuraGroupMaxFrameCount(key, GroupCount(f, k, key))
			if narrow then container:SetAuraGroupCandidateFilters(key, Candidates(key, types, k)) end
		end
		container:SetAuraGroupEnabled(BOSS, a.enabled)
		container:SetAuraGroupEnabled(IMPORTANT, a.enabled)
		container:SetAuraGroupEnabled(DISPELS, a.enabled and dispels > 0)
	end
	local highlights = f.highlights
	for key in pairs(f.glowSlots or {}) do
		highlights:SetAuraSlotEnabled(key, a.glow)
	end
	if f.bossSlot then
		highlights:SetAuraSlotFilterString(BOSS_SLOT, filter)
		if narrow then highlights:SetAuraSlotCandidateFilters(BOSS_SLOT, Narrow({ isBossAura = true })) end
		highlights:SetAuraSlotEnabled(BOSS_SLOT, Auras.BossOn(f))
	end
	container:SetAuraGroupLayout(GROUP, GroupLayout(f, k, GROUP))
	container:SetAuraGroupMaxFrameCount(GROUP, GroupCount(f, k, GROUP))
	container:SetAuraGroupFilterString(GROUP, filter)
	if f.processed then
		container:SetAuraGroupCandidateFilters(GROUP, Candidates(GROUP, types, k))
	elseif narrow then
		container:SetAuraGroupCandidateFilters(GROUP, Narrow({}))
	end
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if methods and directions and type(container.SetAuraGroupSortMethod) == "function" then
		local method, order = K.Options.AuraSort(a.sort, f.processed and methods.UnitFrameDebuff or methods.Default, directions.Normal)
		for _, key in ipairs(f.processed and GROUPS or { GROUP }) do container:SetAuraGroupSortMethod(key, method, order) end
	end
	container:SetAuraGroupEnabled(GROUP, a.enabled)
	ConfigureDispelGhost(f, k, a, block, filter)
	ConfigureChip(f, k, a, block, filter)
	f.narrowed = Narrowed()
	if f.dispelSlot then
		highlights:SetAuraSlotFilterString(SLOT, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER)
		highlights:SetAuraSlotEnabled(SLOT, a.dispelHighlight)
	end
	ConfigureType(f, DISPEL_FILTERS[a.dispelFilter] or DISPEL_FILTERS.PLAYER)
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
	local on = (a.enabled or a.dispelHighlight or a.glow or Settings.current.dispel.icon ~= "NONE") and available and Unit.running
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
			if f.debuffChip then
				f.debuffChip.window:Hide()
				Widgets.Overflow.Enable(f.debuffChip, false)
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
	local boss = CreateFrame("Frame", nil, holder)
	boss.tile = NewTile(boss)
	boss.tile.icon:SetTexture(SAMPLE_BOSS_ICON)
	boss:SetFrameLevel(holder:GetFrameLevel() + #SAMPLE_ICONS + 1)
	f.sampleBoss = boss
	local chip = CreateFrame("Frame", nil, holder)
	chip:SetFrameLevel(holder:GetFrameLevel() + #SAMPLE_ICONS + 1)
	chip.chrome = Widgets.IconChrome(chip)
	chip.text = Widgets.FontString(chip, "OVERLAY")
	chip.text:SetPoint("CENTER", chip, "CENTER", 0, 0)
	f.sampleChip = chip
	f.sampleDispel = CreateFrame("Frame", nil, holder)
	f.sampleDispel:SetAllPoints(f)
	f.sampleDispelWash, f.sampleDispelRing = NewDispel(f.sampleDispel)
end
Button.built[#Button.built + 1] = BuildSamples

local function SampleLabel(icon, key, on, text, size)
	local label = icon[key]
	if on and not label then
		label = Widgets.Fitted(Widgets.FontString(icon.tile.skin, "OVERLAY"))
		label:SetText(text)
		icon[key] = label
	end
	if label then
		Style.SetFont(label, Settings.current.text.healthFont, size, Settings.current.auras.textOutline)
		label:SetShown(on)
	end
	return label
end

local function LayoutSamples(f, k)
	local holder = f.sampleAuraHolder
	local block = Block(f, k)
	local size, spacing = block.size, block.spacing
	local columns = math.max(1, block.columns)
	f.sampleCells = block.cells
	local point, x, y = Anchor(f, block, k)
	holder:ClearAllPoints()
	holder:SetPoint(point, f, "TOPLEFT", x, y)
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
		Zoom(icon.art, Settings.current.auras.zoom)
	end
	local first, a = f.sampleAuras[1], Settings.current.auras
	local textSize = math.max(6, math.floor(size * COUNT_SHARE + 0.5))
	local count = SampleLabel(first, "count", a.stacks, "3", textSize)
	if count then
		local inset = PlaceIcon(first.tile)
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", first.tile.skin, "BOTTOMRIGHT", Widgets.Snap(first.tile.skin, a.countX) - inset, inset + Widgets.Snap(first.tile.skin, a.countY))
	end
	local timer = SampleLabel(first, "timer", a.timers, "12s", TimerSize(size))
	if timer then PlaceTimer(timer, first.tile.skin) end
	local chip = f.sampleChip
	local last = f.sampleAuras[math.max(1, block.cells)]
	chip:ClearAllPoints()
	chip:SetAllPoints(last)
	chip.chrome:Restyle()
	local r, g, b = Tokens.Color("buttonFill")
	chip.chrome:SetFillRGBA(r, g, b, 1)
	Style.SetFont(chip.text, Settings.current.text.healthFont, math.max(8, math.floor(size * 0.42 + 0.5)), "")
	chip.text:SetTextColor(Tokens.Color("textEmphasis"))
	local side, fit, buffSize, buffSpacing, _, _, row = HealIcons(f, k)
	f.sampleBuffFit = fit
	for i, icon in ipairs(f.sampleBuffs) do
		icon:ClearAllPoints()
		icon:SetSize(buffSize, buffSize)
		local along = (i - 1) * (buffSize + buffSpacing)
		if row and side == "RIGHT" then
			icon:SetPoint("TOPRIGHT", f, "TOPLEFT", Widgets.Snap(f, row.left + row.width - along), -Widgets.Snap(f, row.top))
		elseif row then
			icon:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, row.left + along), -Widgets.Snap(f, row.top))
		else
			icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		end
		icon.tile.chrome:Restyle()
		icon.tile.chrome:SetRimAccent(Style.Accent())
		PlaceIcon(icon.tile)
		Zoom(icon.art, IconZoom("buff"))
	end
	local rect, boss = f.parts and f.parts.boss, f.sampleBoss
	if rect then
		boss:ClearAllPoints()
		boss:SetSize(Widgets.Snap(f, rect.width), Widgets.Snap(f, rect.height))
		boss:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top))
		boss.tile.chrome:Restyle()
		boss.tile.chrome:SetRimAccent(Style.Accent())
		PlaceIcon(boss.tile)
		Zoom(boss.tile.icon, IconZoom(BOSS_SLOT))
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
	local cells = math.min(f.sampleCells or Count(k), #f.sampleAuras)
	local kept = {}
	local enemy = not (a.canApply or a.source == "PLAYERS" or a.filter == "ROLE" or a.filter == "CROWD_CONTROL")
	for i = 1, a.enabled and enemy and a.filter ~= "BOSS" and a.filter ~= "IMPORTANT" and (sample.debuffs or 0) or 0 do
		local kind = SAMPLE_TYPES[i]
		if (kind and a[kind] or not kind and a.typeMode ~= "ONLY") and (i ~= SAMPLE_LASTING or a.lasting) then
			kept[#kept + 1] = i
		end
	end
	local debuffs = #kept
	local more = cells > 0 and debuffs > cells
	local shown = more and cells - 1 or math.min(debuffs, cells)
	local d = Settings.current.dispel
	for i, icon in ipairs(f.sampleAuras) do
		icon:SetShown(i <= shown)
		if kept[i] then icon.art:SetTexture(SAMPLE_ICONS[kept[i]]) end
		local c = d.iconBorder and kept[i] and (d.custom and d or Settings.defaults.dispel)[SAMPLE_TYPES[kept[i]] or ""]
		if c and not icon.typeBorder then icon.typeBorder = Widgets.NineSlice(icon.tile.skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL) end
		if icon.typeBorder then
			Widgets.ShowSlice(icon.typeBorder, c and true or false)
			if c then
				Widgets.LayoutSlice(icon.typeBorder, icon.tile.skin, icon.tile.chrome:Chamfer(), 0)
				Widgets.ColorSlice(icon.typeBorder, c.r, c.g, c.b, 1)
			end
		end
	end
	if more then
		Widgets.SetText(f.sampleChip.text, MARK .. (debuffs - shown))
	end
	f.sampleChip:SetShown(more)
	f.sampleBoss:SetShown(a.enabled and enemy and a.typeMode ~= "ONLY" and a.filter ~= "IMPORTANT" and sample.boss == true and f.parts ~= nil and f.parts.boss ~= nil)
	local hots = Settings.current.buffs.enabled and math.min(sample.hots or 0, f.sampleBuffFit or k.buffCount) or 0
	for i, icon in ipairs(f.sampleBuffs) do
		icon:SetShown(i <= hots)
	end
	local own = sample.dispel and d.custom and d[sample.dispel:lower()]
	if sample.dispel and d.icon ~= "NONE" then
		f.sampleType = f.sampleType or f.text:CreateTexture(nil, "OVERLAY")
		f.sampleType:SetTexture((Tokens.Texture("dispel" .. sample.dispel:sub(1, 1))))
		f.sampleType:SetVertexColor(own and own.r or 1, own and own.g or 1, own and own.b or 1)
		Style.Pin(f, f.sampleType, d.icon, Widgets.Snap(f, math.min(d.iconSize, f.parts.health.height)), d.x, d.y)
	end
	if f.sampleType then f.sampleType:SetShown(sample.dispel ~= nil and d.icon ~= "NONE") end
	local dispel = a.dispelHighlight and sample.dispel
	if dispel then
		local r, g, b = Tokens.Color("rare")
		if own then r, g, b = own.r, own.g, own.b end
		Widgets.ColorSlice(f.sampleDispelWash, r, g, b, a.dispelAlpha)
		Style.ColorRing(f.sampleDispelRing, r, g, b, 1)
	end
	f.sampleDispel:SetShown(dispel and true or false)
end
Style.painters[#Style.painters + 1] = PaintSample

Unit.changed[#Unit.changed + 1] = Bind
Unit.extra[#Unit.extra + 1] = Bind
Unit.changed[#Unit.changed + 1] = BindBuffs
Unit.extra[#Unit.extra + 1] = BindBuffs
