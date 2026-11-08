-- Style.lua: builds a group frame's look on any frame and lays it out from the settings: glass tile, portrait, bars, texts and the chamfered highlight rings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Settings, Geometry = ns.Settings, ns.Geometry

local Style = {}
ns.Style = Style

local TEXT_LEVEL = 4
local NAME_LINE_EXTRA = 2
local NAME_RESERVE_EMS = 3.4
local LEVEL_SHARE = 0.36
local RING_OUTSET = 1
local BADGE = "buttonFill"
local PORTRAIT_INSET = 2
local HOVER_ALPHA = 0.6
local RING_LINES = 2
local WASH = "chamferTile"
local TRACK = "buttonFill"

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
		ring[i] = Widgets.Line(owner, layer, sublevel)
	end
	return ring
end

function Style.LayoutRing(ring, owner)
	local border = Widgets.Border(owner)
	local chamfer = Tokens.Size("chamferTile")
	for i, line in ipairs(ring) do
		Widgets.LayoutLine(line, owner, chamfer, border * (i - 1))
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

function Style.LayoutWash(wash, owner)
	local _, _, corner = Tokens.Texture(WASH)
	Widgets.LayoutSlice(wash, owner, corner, 0)
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
	f.ring:SetTexture((Tokens.Texture("ring")))
	f.text = CreateFrame("Frame", nil, f)
	f.text:SetAllPoints(f)
	f.text:SetFrameLevel(f:GetFrameLevel() + TEXT_LEVEL)
	f.badge = f.text:CreateTexture(nil, "ARTWORK")
	f.badge:SetTexture((Tokens.Texture("dot")))
	f.badgeRing = f.text:CreateTexture(nil, "ARTWORK", nil, 1)
	f.badgeRing:SetTexture((Tokens.Texture("ring")))
	f.level = Widgets.FontString(f.text, "OVERLAY")
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

function Style.Size(f)
	local k = Settings.current[f.kind]
	return f.width or k.width, f.height or k.height
end

local function LayoutTexts(f, k, parts)
	local name, healthText = f.name, f.healthText
	local cfg = Settings.current.text
	SetFont(name, cfg.nameFont, k.nameSize, cfg.nameOutline)
	SetFont(healthText, cfg.healthFont, k.healthTextSize, cfg.healthOutline)
	name:ClearAllPoints()
	healthText:ClearAllPoints()
	local showHealth = k.healthText ~= "NONE"
	healthText:SetShown(showHealth)
	local spot = parts.healthText
	if not parts.nameInside then
		local rect = parts.name
		local left, top = Widgets.Snap(f, rect.left), -Widgets.Snap(f, rect.top)
		local reserve = showHealth and k.healthTextSize * NAME_RESERVE_EMS or 0
		name:SetJustifyH("LEFT")
		name:SetPoint("TOPLEFT", f, "TOPLEFT", left, top)
		name:SetWidth(math.max(1, Widgets.Snap(f, rect.width - reserve)))
		healthText:SetJustifyH("RIGHT")
		healthText:SetWidth(0)
		healthText:SetPoint("TOPRIGHT", f, "TOPLEFT", Widgets.Snap(f, spot.right), top)
		return
	end
	local rect = parts.health
	local inset = Tokens.Size("gapTiny")
	local cx = Widgets.Snap(f, rect.left + rect.width / 2)
	local cy = -Widgets.Snap(f, spot.top)
	name:SetJustifyH("CENTER")
	name:SetWidth(math.max(1, Widgets.Snap(f, rect.width - 2 * inset)))
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

local function LayoutPortrait(f, parts)
	local rect = parts.portrait
	local shown = rect ~= nil
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
	local outset = Widgets.Border(f) * RING_OUTSET
	f.ring:ClearAllPoints()
	f.ring:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", -outset, outset)
	f.ring:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", outset, -outset)
	local badge = Widgets.Snap(f, rect.width * LEVEL_SHARE)
	f.badge:ClearAllPoints()
	f.badge:SetSize(badge, badge)
	f.badge:SetPoint("BOTTOMLEFT", f.portrait, "BOTTOMLEFT", 0, 0)
	f.badge:SetVertexColor(Tokens.Color(BADGE))
	f.badgeRing:ClearAllPoints()
	f.badgeRing:SetPoint("TOPLEFT", f.badge, "TOPLEFT", -outset, outset)
	f.badgeRing:SetPoint("BOTTOMRIGHT", f.badge, "BOTTOMRIGHT", outset, -outset)
	f.level:ClearAllPoints()
	f.level:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
	SetFont(f.level, Settings.current.text.healthFont, Tokens.Size("caption"), "NONE")
	f.level:SetTextColor(Tokens.Color("textEmphasis"))
end

function Style.Apply(f, width, height)
	local cfg = Settings.current
	local k = cfg[f.kind]
	width, height = width or k.width, height or k.height
	f.width, f.height = width, height
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
	LayoutPortrait(f, parts)
	LayoutTexts(f, k, parts)
	Style.LayoutRing(f.targetRing, f.target)
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
