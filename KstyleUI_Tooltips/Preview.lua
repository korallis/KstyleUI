-- Preview.lua: the settings window's live sample: an item tooltip drawn with the module's fonts, colours, edge and divider.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, L = K.Tokens, K.Widgets, K.Theme, K.L
local Logic, Settings, Style = ns.Logic, ns.Settings, ns.Style

local Preview = {}
ns.Preview = Preview

local SAMPLE_WIDTH = 220
local SAMPLE_QUALITY = 3
local LINE_GAP = 2
local DIVIDER_GAP = 1
local DIVIDER_SUBLEVEL = 7

local SAMPLE = {
	{ left = L["Ranger's Long Bow"], role = "title", color = "quality" },
	{ left = L["Binds when equipped"], color = "highlight" },
	{ left = L["Two-Hand"], right = L["Bow"], color = "highlight" },
	{ left = L["142 - 198 Damage"], right = L["Speed 1.80"], color = "highlight" },
	{ left = L["+24 Agility"], color = "bonus" },
	{ left = L["Durability 96 / 100"], color = "highlight" },
	{ left = L["Requires Level 38"], color = "highlight" },
	{ left = L["Sold by a ranger in Thunder Bluff."], role = "small", color = "normal" },
}

local BLIZZARD = { highlight = "HIGHLIGHT_FONT_COLOR", normal = "NORMAL_FONT_COLOR", bonus = "GREEN_FONT_COLOR" }
local FALLBACK = { highlight = "textEmphasis", normal = "text", bonus = "friendly" }

local function LineColor(kind)
	if kind == "quality" then
		return Theme.QualityColor(SAMPLE_QUALITY)
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

local function Paint(text, kind)
	local r, g, b = LineColor(kind)
	text:SetTextColor(r, g, b)
end

local function Height(text, role)
	local _, size = Style.FontSpec(role)
	return Widgets.TextHeight(text, size)
end

local function Layout(frame)
	local glass = frame.glass
	local pad = Widgets.Snap(glass, Tokens.Size("gapMedium"))
	local gap = Widgets.Snap(glass, LINE_GAP)
	local y = pad
	for i, row in ipairs(frame.rows) do
		local left, right = row.left, row.right
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", glass, "TOPLEFT", pad, -y)
		left:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
		if right then
			right:ClearAllPoints()
			right:SetPoint("TOPRIGHT", glass, "TOPRIGHT", -pad, -y)
		end
		y = y + Height(left, SAMPLE[i].role or "body") + gap
	end
	Widgets.Size(glass, SAMPLE_WIDTH, y - gap + pad)
	local divider = glass.divider
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -Widgets.Snap(glass, DIVIDER_GAP))
	divider:SetPoint("RIGHT", glass, "RIGHT", -pad, 0)
	divider:SetHeight(Widgets.Border(glass))
end

local function Refresh(frame)
	for i, row in ipairs(frame.rows) do
		local spec = SAMPLE[i]
		local role = spec.role or "body"
		Style.StyleFont(row.left, role)
		Paint(row.left, spec.color)
		if row.right then
			Style.StyleFont(row.right, role)
			Paint(row.right, spec.color)
		end
	end
	Layout(frame)
	local chrome = frame.glass.chrome
	chrome:Restyle()
	if Settings.Get("qualityEdge") then
		local r, g, b = Theme.QualityColor(SAMPLE_QUALITY)
		chrome:SetEdgeRGBA(r, g, b, 1)
	else
		chrome:SetEdge("edgeInner")
	end
	local divider = frame.glass.divider
	divider:SetVertexColor(Settings.Accent())
	divider:SetShown(Settings.Get("divider"))
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local glass = CreateFrame("Frame", nil, frame)
	glass:SetPoint("TOP", frame, "TOP", 0, -Tokens.Size("gapLarge"))
	glass.chrome = Widgets.Chrome(glass, { shape = "panel", fill = "surface" })
	glass.divider = glass:CreateTexture(nil, "BORDER", nil, DIVIDER_SUBLEVEL)
	glass.divider:SetTexture((Tokens.Texture("divider")))
	frame.glass = glass
	frame.rows = {}
	for i, spec in ipairs(SAMPLE) do
		local row = { left = glass:CreateFontString(nil, "OVERLAY") }
		row.left:SetJustifyH("LEFT")
		row.left:SetText(spec.left)
		if spec.right then
			row.right = glass:CreateFontString(nil, "OVERLAY")
			row.right:SetJustifyH("RIGHT")
			row.right:SetText(spec.right)
		end
		frame.rows[i] = row
	end
	frame.title = frame.rows[1].left
	frame.Refresh = Refresh
	Refresh(frame)
	return frame
end
