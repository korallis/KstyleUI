-- Preview.lua: the settings window's live sample: an item and a unit tooltip drawn with the module's fonts, colours, edges, icon and health bar.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, L = K.Tokens, K.Widgets, K.Theme, K.L
local Logic, Settings, Style = ns.Logic, ns.Settings, ns.Style

local Preview = {}
ns.Preview = Preview

local SAMPLE_WIDTH = 190
local SAMPLE_QUALITY = 3
local SAMPLE_HEALTH = 0.72
local SAMPLE_ICON = "Interface\\Icons\\INV_Weapon_Bow_07"
local SAMPLE_GAP = 24
local LINE_GAP = 2
local DIVIDER_GAP = 1
local DIVIDER_SUBLEVEL = 7
local BAR_GAP = 4
local FRIENDLY = 5

local ITEM = {
	header = 2,
	{ left = L["Ranger's Long Bow"], role = "title", color = "quality", upper = true },
	{ left = L["Rare"], role = "small", color = "quality", upper = true },
	{ left = L["Binds when equipped"], color = "highlight" },
	{ left = L["Two-Hand"], right = L["Bow"], color = "highlight" },
	{ left = L["142 - 198 Damage"], right = L["Speed 1.80"], color = "highlight" },
	{ left = L["+24 Agility"], color = "bonus" },
	{ left = L["Durability 96 / 100"], color = "highlight" },
	{ left = L["Requires Level 38"], color = "highlight" },
	{ left = L["Sold by a ranger in Thunder Bluff."], role = "small", color = "normal" },
}

local UNIT = {
	{ left = L["Valerin"], role = "title", color = "class", upper = true },
	{ left = "", color = "guild", key = "guildLine" },
	{ left = L["Level 60 Hunter (Player)"], color = "highlight" },
	{ left = L["Target"], right = L["You"], color = "text", rightColor = "accent", key = "targetLine" },
}

local BLIZZARD = { highlight = "HIGHLIGHT_FONT_COLOR", normal = "NORMAL_FONT_COLOR", bonus = "GREEN_FONT_COLOR" }
local FALLBACK = { highlight = "textEmphasis", normal = "text", bonus = "friendly" }

local function ClassColor()
	local class = Theme.Class()
	if class then
		return Theme.ClassColor(class)
	end
	return Theme.Accent()
end

local function LineColor(kind)
	if kind == "quality" then
		return Theme.QualityColor(SAMPLE_QUALITY)
	elseif kind == "class" then
		if Settings.Get("classNames") then
			return ClassColor()
		end
		kind = "highlight"
	elseif kind == "accent" then
		return Settings.Accent()
	elseif kind == "guild" or kind == "text" then
		return Tokens.Color(kind == "guild" and "friendly" or "text")
	end
	local color = _G[BLIZZARD[kind]]
	local r, g, b
	if type(color) == "table" and type(color.GetRGB) == "function" then
		r, g, b = color:GetRGB()
	else
		r, g, b = Tokens.Color(FALLBACK[kind])
	end
	if Settings.Get("softColors") then
		local token = Logic.Soften(r, g, b, Style.Palette())
		if token then
			r, g, b = Tokens.Color(token)
		end
	end
	return r, g, b
end

local function Sample(frame, spec)
	local glass = CreateFrame("Frame", nil, frame)
	glass.chrome = Widgets.Chrome(glass, { shape = "panel", fill = "surface" })
	glass.divider = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
	glass.divider:SetTexture((Tokens.Texture("divider")))
	glass.spec, glass.rows = spec, {}
	for i, line in ipairs(spec) do
		local row = { left = Widgets.FontString(glass, "OVERLAY") }
		row.left:SetJustifyH("LEFT")
		row.left:SetText(line.upper and Logic.Upper(line.left) or line.left)
		if line.right then
			row.right = Widgets.FontString(glass, "OVERLAY")
			row.right:SetJustifyH("RIGHT")
			row.right:SetText(line.right)
		end
		glass.rows[i] = row
	end
	return glass
end

local function Shown(line)
	return line.key == nil or Settings.Get(line.key)
end

local function LayoutSample(glass)
	local pad = Widgets.Snap(glass, Tokens.Size("gapMedium"))
	local gap = Widgets.Snap(glass, LINE_GAP)
	local x = pad + (glass.indent or 0)
	local y = pad
	local shown = 0
	for i, row in ipairs(glass.rows) do
		local line = glass.spec[i]
		local role = line.role or "body"
		local visible = Shown(line)
		row.left:SetShown(visible)
		if row.right then
			row.right:SetShown(visible)
		end
		if visible then
			shown = shown + 1
			Style.StyleFont(row.left, role)
			row.left:SetTextColor(LineColor(line.color))
			row.left:ClearAllPoints()
			row.left:SetPoint("TOPLEFT", glass, "TOPLEFT", x, -y)
			row.left:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
			if row.right then
				Style.StyleFont(row.right, role)
				row.right:SetTextColor(LineColor(line.rightColor or line.color))
				row.right:ClearAllPoints()
				row.right:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -pad, -y)
			end
			local _, size = Style.FontSpec(role)
			y = y + Widgets.TextHeight(row.left, size) + gap
		end
	end
	if glass.spec[2] and glass.spec[2].key == "guildLine" and Settings.Get("guildRank") then
		glass.rows[2].left:SetText(Logic.GuildText(L["Kstyle"], L["Officer"]))
	elseif glass.spec[2] and glass.spec[2].key == "guildLine" then
		glass.rows[2].left:SetText(Logic.GuildText(L["Kstyle"]))
	end
	Widgets.Size(glass, SAMPLE_WIDTH + (glass.indent or 0), y - gap + pad)
	local divider = glass.divider
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", glass.rows[glass.spec.header or 1].left, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
	divider:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
	divider:SetHeight(Widgets.Border(glass))
	divider:SetVertexColor(Settings.Accent())
	divider:SetShown(Settings.Get("divider") and shown >= 2)
	glass.chrome:Restyle()
end

local function Edge(glass, on, r, g, b)
	if on then
		glass.chrome:SetEdgeRGBA(r, g, b, 1)
	else
		glass.chrome:SetEdge("edgeInner")
	end
end

local function BarColor()
	local source = Settings.Get("bar.color")
	if source == "custom" then
		local c = Settings.Get("bar.custom")
		return c.r, c.g, c.b
	elseif source == "reaction" then
		return Theme.ReactionColor(FRIENDLY)
	end
	return ClassColor()
end

local function LayoutBar(frame)
	local bar, unit = frame.bar, frame.unit
	local size = Settings.Get("bar.size")
	local gap = Widgets.Snap(unit, BAR_GAP)
	local vertical = Settings.Get("bar.orientation") == "VERTICAL"
	bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
	bar:SetReverseFill(Settings.Get("bar.reverse"))
	bar:SetBarTexture(Settings.Get("bar.texture"))
	bar:SetBarColor(BarColor())
	bar:ClearAllPoints()
	if vertical then
		bar.opts.width = size
		bar:SetPoint("TOPLEFT", unit, "TOPRIGHT", gap, 0)
		bar:SetPoint("BOTTOMLEFT", unit, "BOTTOMRIGHT", gap, 0)
	else
		bar.opts.height = size
		bar:SetPoint("TOPLEFT", unit, "BOTTOMLEFT", 0, -gap)
		bar:SetPoint("TOPRIGHT", unit, "BOTTOMRIGHT", 0, -gap)
	end
	bar:Restyle()
	bar:SetShown(Settings.Get("healthBar"))
end

local function LayoutIcon(frame)
	local icon = frame.icon
	local size = Settings.Get("iconSize")
	Style.PlaceIcon(icon, frame.item, size)
	Style.PaintIcon(icon, SAMPLE_QUALITY)
	icon:SetShown(Settings.Get("icon"))
end

local function Refresh(frame)
	frame.item.indent = Settings.Get("icon") and Settings.Get("iconSize") + Tokens.Size("gapLarge") or 0
	LayoutSample(frame.item)
	LayoutSample(frame.unit)
	local qr, qg, qb = Theme.QualityColor(SAMPLE_QUALITY)
	Edge(frame.item, Settings.Get("qualityEdge"), qr, qg, qb)
	local cr, cg, cb = ClassColor()
	Edge(frame.unit, Settings.Get("unitEdge"), cr, cg, cb)
	LayoutIcon(frame)
	LayoutBar(frame)
	frame.unit:ClearAllPoints()
	frame.unit:SetPoint("TOPLEFT", frame.item, "BOTTOMLEFT", 0, -Widgets.Snap(frame.unit, SAMPLE_GAP))
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	frame.item = Sample(frame, ITEM)
	frame.item:SetPoint("TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
	frame.unit = Sample(frame, UNIT)
	frame.icon = Style.IconTile(frame.item)
	frame.icon.texture:SetTexture(SAMPLE_ICON)
	frame.bar = Widgets.StatusBar(frame.unit, { background = "track", border = true, min = 0, max = 1, value = SAMPLE_HEALTH })
	frame.glass, frame.title, frame.caption = frame.item, frame.item.rows[1].left, frame.item.rows[2].left
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end

