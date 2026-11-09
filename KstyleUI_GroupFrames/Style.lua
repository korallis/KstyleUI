-- Style.lua: builds a group frame's Lumen look on any frame and lays it out from the settings: glass tile, role ring or portrait, class pill, name and class caption, and the rounded highlight rings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings, Geometry = ns.Settings, ns.Geometry

local Style = {}
ns.Style = Style

local TEXT_LEVEL = 4
local NAME_LINE_EXTRA = 2
local ON_BAR_OUTLINE = "OUTLINE"
local ON_FILL_OUTLINE = "THICKOUTLINE"
local LEVEL_SHARE = 0.36
local BADGE = "buttonFill"
local PORTRAIT_INSET = 2
local HOVER_ALPHA = 0.6
local RING_LINES = 2
local WASH = "chamferTile"
local TRACK = "buttonFill"
local ROLE_RING = 24
local ROLE_LETTERS = { TANK = "T", HEALER = "H", DAMAGER = "D" }
local PILL_HEIGHT = 6
local PILL_RISE = 2
local CLASS_LINE_COLOR = "text"
local BOSS_SLOT = 16
local NAME_STEPS = 2
local NAME_FLOOR = 7
Style.BOSS_SLOT = BOSS_SLOT

function Style.NameMin(k)
	return math.max(NAME_FLOOR, math.min(k.nameSize, k.nameSize - NAME_STEPS))
end
local RESERVE = {
	party = { DEFICIT = { "-88.8k", "-888" }, PERCENT = { "100%" } },
	raid = {
		DEFICIT = { "-8.8k", "-88k", "-888" }, PERCENT = { "100%" }, CURRENT = { "88.8k" }, CURRENT_MAX = { "88.8k / 88.8k" },
		CURRENT_PERCENT = { "88.8k  100%" },
	},
}
Style.ROLE_RING = ROLE_RING
Style.ROLE_LETTERS = ROLE_LETTERS
Style.PILL_HEIGHT = PILL_HEIGHT
Style.PILL_RISE = PILL_RISE

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(Settings.MODULE, message)
	end
end
Style.LogOnce = LogOnce

function Style.Ring(owner, layer, sublevel)
	layer, sublevel = layer or "OVERLAY", sublevel or 0
	local ring = {}
	for i = 1, RING_LINES do
		ring[i] = Widgets.NineSlice(owner, "lumenOutline", layer, sublevel)
	end
	return ring
end

function Style.LayoutRing(ring, owner, radius)
	local border = Widgets.Border(owner)
	radius = radius or Tokens.Size("radiusTile")
	for i, line in ipairs(ring) do
		Widgets.LayoutSlice(line, owner, radius, -border * (i - 1))
	end
end

function Style.ColorRing(ring, r, g, b, a)
	for _, line in ipairs(ring) do
		for _, piece in ipairs(line) do
			piece:SetVertexColor(r, g, b, a)
		end
	end
end

function Style.Pieces(ring, fn)
	for i = 1, #ring do
		for _, piece in ipairs(ring[i]) do
			fn(piece)
		end
	end
end

function Style.Wash(owner, layer, sublevel)
	return Widgets.NineSlice(owner, WASH, layer, sublevel)
end

function Style.LayoutWash(wash, owner, chamfer)
	local _, _, corner = Tokens.Texture(WASH)
	Widgets.LayoutSlice(wash, owner, chamfer or corner, 0)
end

function Style.Build(f, kind)
	f.kind = kind
	f.chrome = Widgets.Chrome(f, { shape = "tile", fill = "surface", shadow = kind == "party" })
	f.health = Widgets.StatusBar(f, { smooth = true, background = TRACK })
	f.power = Widgets.StatusBar(f, { smooth = true, background = TRACK })
	f.portrait = f:CreateTexture(nil, "ARTWORK")
	f.portraitMask = f:CreateMaskTexture()
	f.portraitMask:SetTexture((Tokens.Texture("dot")))
	f.portraitMask:SetAllPoints(f.portrait)
	f.portrait:AddMaskTexture(f.portraitMask)
	f.ring = f:CreateTexture(nil, "OVERLAY")
	f.ring:SetTexture((Tokens.Texture("ringBevel")))
	f.text = CreateFrame("Frame", nil, f)
	f.text:SetAllPoints(f)
	f.text:SetFrameLevel(f:GetFrameLevel() + TEXT_LEVEL)
	f.badge = f.text:CreateTexture(nil, "ARTWORK")
	f.badge:SetTexture((Tokens.Texture("dot")))
	f.badgeRing = f.text:CreateTexture(nil, "ARTWORK", nil, 1)
	f.badgeRing:SetTexture((Tokens.Texture("ringBevel")))
	f.level = Widgets.FontString(f.text, "OVERLAY")
	f.roleText = Widgets.FontString(f.text, "OVERLAY")
	f.classLine = Widgets.FontString(f.text, "OVERLAY")
	f.classLine:SetWordWrap(false)
	f.classLine:SetJustifyH("RIGHT")
	f.name = Widgets.FontString(f.text, "OVERLAY")
	f.name:SetWordWrap(false)
	f.healthText = Widgets.FontString(f.text, "OVERLAY")
	f.healthText:SetWordWrap(false)
	f.target = CreateFrame("Frame", nil, f.text)
	f.target:SetAllPoints(f)
	f.targetRing = Style.Ring(f.target, "OVERLAY")
	f.target:SetAlpha(0)
	return f
end

local function SetFont(text, path, size, outline)
	local flags = outline == "NONE" and "" or outline
	if text:SetFont(path, size, flags) == false then
		local fallback = Tokens.Font("body")
		text:SetFont(fallback, size, flags)
		LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; group frames use the KstyleUI font")
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end
Style.SetFont = SetFont

local function Place(f, region, rect)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top))
end

local function PlaceBar(f, bar, rect)
	bar.opts.width, bar.opts.height = rect.width, rect.height
	Place(f, bar, rect)
	bar:Restyle()
end

function Style.Accent()
	local accent = Settings.current.accent
	if accent.source == "custom" then
		local c = accent.color
		return c.r, c.g, c.b
	end
	return Theme.Accent()
end

function Style.MemberWidth(kind)
	local k = Settings.current[kind]
	if kind == "party" then
		return Geometry.MemberWidth(k)
	end
	return k.width
end

function Style.Size(f)
	local k = Settings.current[f.kind]
	return f.width or Style.MemberWidth(f.kind), f.height or k.height
end

local function OnBar(outline)
	return outline == "NONE" and ON_BAR_OUTLINE or outline
end

local function LayoutTexts(f, k, parts)
	local name, healthText = f.name, f.healthText
	local cfg = Settings.current.text
	local inside = parts.nameInside
	local nameOutline = inside and OnBar(cfg.nameOutline) or cfg.nameOutline
	SetFont(name, cfg.nameFont, k.nameSize, nameOutline)
	f.nameFit = {
		size = k.nameSize, min = Style.NameMin(k),
		set = function(text, size)
			SetFont(text, cfg.nameFont, size, nameOutline)
		end,
	}
	SetFont(healthText, cfg.healthFont, k.healthTextSize, inside and OnBar(cfg.healthOutline) or cfg.healthOutline)
	name:ClearAllPoints()
	healthText:ClearAllPoints()
	local showHealth = k.healthText ~= "NONE"
	healthText:SetShown(showHealth or f.status ~= nil)
	local spot = parts.healthText
	if not inside then
		local rect = parts.name
		local left, top = Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top)
		name:SetJustifyH("LEFT")
		name:SetPoint("TOPLEFT", f, "TOPLEFT", left, top)
		healthText:SetWidth(0)
		return
	end
	local rect = parts.health
	local inset = Tokens.Size("gapTiny")
	local cx = Widgets.Snap(f, rect.left + rect.width / 2)
	local cy = -Widgets.Snap(f, spot.top)
	name:SetJustifyH("CENTER")
	f.nameWidth = math.max(1, Widgets.Snap(f, rect.width - 2 * inset))
	name:SetWidth(f.nameWidth)
	healthText:SetJustifyH("CENTER")
	if spot.width then
		healthText:SetWidth(math.max(1, Widgets.Snap(f, spot.width)))
	else
		healthText:SetWidth(0)
	end
	if showHealth then
		name:SetPoint("BOTTOM", f, "TOPLEFT", cx, cy)
		healthText:SetPoint("TOP", f, "TOPLEFT", Widgets.Snap(f, spot.center), cy)
	else
		name:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
	end
end

local function LayoutRoleRing(f, rect)
	local size = Widgets.Snap(f, math.min(ROLE_RING, rect.width - 2 * PORTRAIT_INSET))
	local ring = f.ring
	ring:ClearAllPoints()
	ring:SetSize(size, size)
	ring:SetPoint("LEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left + PORTRAIT_INSET), -Widgets.Snap(f, rect.top + rect.height / 2))
	f.roleText:ClearAllPoints()
	f.roleText:SetPoint("CENTER", ring, "CENTER", 0, 0)
	SetFont(f.roleText, Settings.current.text.healthFont, Tokens.Size("caption"), "NONE")
	f.roleText:SetTextColor(Tokens.Color("textEmphasis"))
	f.portrait:Hide()
	f.badge:Hide()
	f.badgeRing:Hide()
	f.level:Hide()
	f.ring:Show()
	f.roleText:Show()
	f.showPortrait = false
	f.showRoleRing = true
end

local function LayoutPortrait(f, parts, k)
	local rect = parts.portrait
	local shown = rect ~= nil
	f.showRoleRing = false
	f.roleText:Hide()
	if shown and k.roleRing then
		LayoutRoleRing(f, rect)
		return
	end
	f.portrait:SetShown(shown)
	f.ring:SetShown(shown)
	f.badge:SetShown(shown)
	f.badgeRing:SetShown(shown)
	f.level:SetShown(shown)
	f.showPortrait = shown
	if not shown then
		return
	end
	local inset = PORTRAIT_INSET
	local size = Widgets.Snap(f, rect.width - 2 * inset)
	f.portrait:ClearAllPoints()
	f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left + inset), -Widgets.Snap(f, rect.top + inset))
	f.portrait:SetSize(size, size)
	local outset = Widgets.Snap(f, size * Widgets.RING_INSET / (1 - 2 * Widgets.RING_INSET))
	f.ring:ClearAllPoints()
	f.ring:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", -outset, outset)
	f.ring:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", outset, -outset)
	local badge = Widgets.Snap(f, rect.width * LEVEL_SHARE)
	f.badge:ClearAllPoints()
	f.badge:SetSize(badge, badge)
	f.badge:SetPoint("BOTTOMLEFT", f.portrait, "BOTTOMLEFT", 0, 0)
	f.badge:SetVertexColor(Tokens.Color(BADGE))
	local badgeOutset = Widgets.Snap(f, badge * Widgets.RING_INSET / (1 - 2 * Widgets.RING_INSET))
	f.badgeRing:ClearAllPoints()
	f.badgeRing:SetPoint("TOPLEFT", f.badge, "TOPLEFT", -badgeOutset, badgeOutset)
	f.badgeRing:SetPoint("BOTTOMRIGHT", f.badge, "BOTTOMRIGHT", badgeOutset, -badgeOutset)
	f.level:ClearAllPoints()
	f.level:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
	SetFont(f.level, Settings.current.text.healthFont, Tokens.Size("caption"), "NONE")
	f.level:SetTextColor(Tokens.Color("textEmphasis"))
end

local function health_orientation(cfg)
	return cfg.health.orientation ~= "VERTICAL"
end

function Style.Reserve(f, k, size)
	local samples = RESERVE[f.kind] and RESERVE[f.kind][k.healthText]
	local Names = ns.Names
	if not samples or not Names then
		return nil
	end
	local widest = 0
	for _, sample in ipairs(samples) do
		widest = math.max(widest, Names.Width(f.healthText, sample, size or k.healthTextSize))
	end
	return Widgets.Snap(f, math.ceil(widest))
end

local function ApplyName(f)
	local Names = ns.Names
	if Names then
		Names.Apply(f)
	end
end

function Style.StatusWidth(f, size)
	local Names, Unit = ns.Names, ns.Unit
	local text = f.status and Unit and Unit.STATUS_TEXT and Unit.STATUS_TEXT[f.status]
	if not text or not Names then
		return nil
	end
	return Widgets.Snap(f, math.ceil(Names.Width(f.healthText, text, size)))
end

local function PlaceOverlay(f, k, parts)
	local cfg = Settings.current.text
	local name, healthText = f.name, f.healthText
	local rect, spot = parts.name, parts.healthText
	local status = f.status ~= nil
	local shown = k.healthText ~= "NONE"
	f.classLine:Hide()
	local outline = cfg.healthOutline == "NONE" and ON_FILL_OUTLINE or cfg.healthOutline
	local size, lane = k.healthTextSize, spot.right - spot.left
	SetFont(healthText, cfg.healthFont, size, outline)
	local reserve = not status and Style.Reserve(f, k)
	while reserve and reserve > lane and size > NAME_FLOOR do
		size = size - 1
		SetFont(healthText, cfg.healthFont, size, outline)
		reserve = Style.Reserve(f, k, size)
	end
	healthText:SetShown(shown or status)
	healthText:ClearAllPoints()
	if status then
		healthText:SetJustifyH("CENTER")
		healthText:SetWidth(0)
		healthText:SetPoint("CENTER", f, "TOPLEFT", Widgets.Snap(f, spot.center), -Widgets.Snap(f, spot.middle))
	else
		healthText:SetJustifyH(spot.justify)
		healthText:SetWidth(math.max(1, Widgets.Snap(f, math.max(lane, reserve or 0))))
		healthText:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, spot.left), -Widgets.Snap(f, spot.top))
	end
	name:ClearAllPoints()
	name:SetJustifyH("LEFT")
	name:SetPoint("TOPLEFT", f, "TOPLEFT", Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top))
	f.nameWidth = math.max(1, Widgets.Snap(f, rect.width))
	name:SetWidth(f.nameWidth)
	ApplyName(f)
end

function Style.PlaceRowEnd(f)
	local parts = f.parts
	if not parts then
		return
	end
	if parts.overlay then
		PlaceOverlay(f, Settings.current[f.kind], parts)
		return
	end
	if parts.nameInside then
		f.healthText:SetShown(Settings.current[f.kind].healthText ~= "NONE" or f.status ~= nil)
		ApplyName(f)
		return
	end
	local k = Settings.current[f.kind]
	local spot, rect = parts.healthText, parts.name
	local right = f.marked and spot.markedRight or spot.right
	local left, top = Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top)
	local gap = Widgets.Snap(f, Tokens.Size("gapSmall"))
	local shown = k.healthText ~= "NONE"
	local status = f.status ~= nil
	local onBar = shown and not status and k.healthTextPlace == "BAR"
	local inRow = status or (shown and not onBar)
	local name, healthText, classLine = f.name, f.healthText, f.classLine
	local cfg = Settings.current.text
	SetFont(healthText, cfg.healthFont, k.healthTextSize, inRow and cfg.healthOutline or OnBar(cfg.healthOutline))
	healthText:SetShown(shown or status)
	healthText:ClearAllPoints()
	local reserve = (inRow or onBar) and Style.Reserve(f, k)
	if status then
		reserve = math.max(reserve or 0, Style.StatusWidth(f, k.healthTextSize) or 0)
	end
	healthText:SetWidth(reserve or 0)
	local bar = parts.health
	local cy = -Widgets.Snap(f, bar.top + bar.height / 2)
	if inRow then
		healthText:SetJustifyH("RIGHT")
		healthText:SetPoint("TOPRIGHT", f, "TOPLEFT", Widgets.Snap(f, right), top)
	else
		healthText:SetJustifyH("CENTER")
		healthText:SetPoint("CENTER", f, "TOPLEFT", Widgets.Snap(f, bar.left + bar.width / 2), cy)
		reserve = nil
	end
	local captioned = k.classLine == true and not status
	classLine:SetShown(captioned)
	if captioned then
		classLine:ClearAllPoints()
		if inRow then
			classLine:SetPoint("TOPRIGHT", healthText, "TOPLEFT", -gap, 0)
		else
			classLine:SetPoint("TOPRIGHT", f, "TOPLEFT", Widgets.Snap(f, right), top)
		end
	end
	name:ClearAllPoints()
	name:SetPoint("TOPLEFT", f, "TOPLEFT", left, top)
	f.nameWidth = nil
	if captioned then
		name:SetWidth(0)
		name:SetPoint("RIGHT", classLine, "LEFT", -gap, 0)
	elseif inRow and not reserve then
		name:SetWidth(0)
		name:SetPoint("RIGHT", healthText, "LEFT", -gap, 0)
	else
		f.nameWidth = math.max(1, Widgets.Snap(f, right - rect.left - (reserve and reserve + gap or 0)))
		name:SetWidth(f.nameWidth)
	end
	ApplyName(f)
end

function Style.SetMarked(f, marked)
	marked = marked and true or false
	if f.marked ~= marked then
		f.marked = marked
		Style.PlaceRowEnd(f)
	end
end

function Style.Apply(f, width, height)
	local cfg = Settings.current
	local k = cfg[f.kind]
	width, height = width or Style.MemberWidth(f.kind), height or k.height
	f.width, f.height = width, height
	local overlay = f.kind == "raid"
	local place, outside = Geometry.AuraPlace(k, f.kind == "party" and Geometry.AuraLane(k) or 0)
	local aura = cfg.auras.enabled and not outside and {
		position = place, count = math.max(1, math.min(k.auraCount, k.auraColumns * k.auraRows)), columns = k.auraColumns, rows = k.auraRows,
		size = Widgets.Snap(f, k.auraSize), spacing = Widgets.Snap(f, k.auraSpacing),
	} or nil
	local healRow = cfg.buffs.enabled and k.buffCount > 0 and Widgets.Snap(f, k.buffSize) or nil
	local nameMin = Style.NameMin(k)
	local parts = Geometry.Button(width, height, {
		portrait = f.kind == "party" and k.portrait,
		power = k.power,
		powerHeight = k.powerHeight,
		nameAbove = k.textLayout == "ABOVE",
		nameHeight = k.nameSize + NAME_LINE_EXTRA,
		iconSize = k.iconSize,
		role = cfg.icons.role,
		leader = cfg.icons.leader,
		marker = cfg.icons.marker,
		pill = f.kind == "party" and health_orientation(cfg) and PILL_HEIGHT or nil,
		pillRise = PILL_RISE,
		roleRing = f.kind == "party" and k.roleRing,
		aura = aura,
		healRow = healRow,
		healCount = k.buffCount,
		healSpacing = Widgets.Snap(f, k.auraSpacing),
		overlay = overlay,
		boss = overlay and cfg.auras.enabled and BOSS_SLOT or nil,
		nameMin = nameMin,
		healthLine = k.healthTextSize + NAME_LINE_EXTRA,
		pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(f),
	})
	f.parts = parts
	local health = cfg.health
	f.health:SetBarTexture(health.texture)
	f.health:SetOrientation(health.orientation)
	PlaceBar(f, f.health, parts.health)
	f.showPower = parts.power ~= nil
	f.power:SetShown(f.showPower)
	if parts.power then
		f.power:SetBarTexture(health.texture)
		PlaceBar(f, f.power, parts.power)
	end
	LayoutPortrait(f, parts, k)
	LayoutTexts(f, k, parts)
	local classLine = f.classLine
	classLine:ClearAllPoints()
	local captioned = k.classLine == true and not parts.nameInside and not parts.overlay
	classLine:SetShown(captioned)
	if captioned then
		SetFont(classLine, cfg.text.healthFont, Tokens.Size("caption"), cfg.text.healthOutline)
		classLine:SetTextColor(Tokens.Color(CLASS_LINE_COLOR))
		classLine:SetHeight(Widgets.Snap(f, parts.name.height))
	end
	Style.PlaceRowEnd(f)
	Style.LayoutRing(f.targetRing, f.target, f.chrome:Chamfer())
	f.tileless = f.kind == "party" and k.roleRing == true
	if not f.chromeHooked then
		f.chromeHooked = true
		local restyle = f.chrome.Restyle
		f.chrome.Restyle = function(chrome)
			restyle(chrome)
			chrome:SetShown(not f.tileless)
		end
	end
	f.chrome:SetShadow(f.kind == "party" and not f.tileless)
	f.chrome:Restyle()
	for i = 1, #Style.appliers do
		Style.appliers[i](f, parts, k)
	end
	Style.Paint(f)
end

Style.appliers = {}
Style.painters = {}

local function PaintEdge(f, r, g, b)
	if not r then
		r, g, b = Style.Accent()
	end
	local er, eg, eb, ea = Tokens.Color("edgeInner")
	f.chrome:SetEdgeRGBA(Widgets.Mix(er, eg, eb, ea or 1, r, g, b, HOVER_ALPHA, f.hoverT or 0))
end

local function SetHoverT(f, t)
	f.hoverT = t
	PaintEdge(f)
end

function Style.Paint(f)
	local r, g, b = Style.Accent()
	Style.ColorRing(f.targetRing, r, g, b, 1)
	f.badgeRing:SetVertexColor(r, g, b, 1)
	PaintEdge(f, r, g, b)
	f.healthText:SetTextColor(Tokens.Color("textEmphasis"))
	local text = Settings.current.text
	if text.nameColorSource == "custom" then
		local c = text.nameColor
		f.name:SetTextColor(c.r, c.g, c.b)
	elseif text.nameColorSource == "text" then
		f.name:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

function Style.SetHovered(f, hovered)
	f.hovered = hovered and true or false
	K.Motion.Tween(f, SetHoverT, f.hoverT or 0, f.hovered and 1 or 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
end
