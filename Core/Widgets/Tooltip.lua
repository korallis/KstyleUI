-- Tooltip.lua: the glass tooltip for KstyleUI's own controls, with a lit icon tile, a tracked title, captions, lines, double lines, the accent rule and dividers.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale
local max, min = math.max, math.min

local MIN_WIDTH = 160
local MAX_WIDTH = 300
local ANCHOR_GAP = 6
local ICON_SIZE = 50
local ICON_INSET = 9.5
local ICON_LINES = 2
local ICON_CROP = 0.07
local TEXT_GAP = 11
local LINE_HEIGHT = 1.2
local LINE_GAP = 0.5
local TITLE_GAP = 2
local CAPTION_GAP = 4
local RULE_LENGTH = 56
local RULE_GAP = 4
local DIVIDER_GAP = 6.5
local THIN_SPACE = "\226\128\137"
local CODEPOINT = "([\1-\127\194-\244][\128-\191]*)"
Widgets.TOOLTIP_MIN_WIDTH = MIN_WIDTH

local ANCHORS = {
	RIGHT = { "LEFT", "RIGHT", 1, 0, "GetRight", "TOP", "BOTTOM" },
	LEFT = { "RIGHT", "LEFT", -1, 0, "GetLeft", "TOP", "BOTTOM" },
	TOP = { "BOTTOM", "TOP", 0, 1, "GetTop", "RIGHT", "LEFT" },
	BOTTOM = { "TOP", "BOTTOM", 0, -1, "GetBottom", "RIGHT", "LEFT" },
}

local ROLES = { title = "body", caption = "caption", line = "body", double = "body" }
local GAPS_AFTER = { title = TITLE_GAP, caption = CAPTION_GAP }

local tip
local Tip = {}

local function Tracked(text)
	if Widgets.IsSecret(text) or type(text) ~= "string" or text:find("|", 1, true) then
		return text
	end
	if ns.Locale.TrackMode((ns.Tokens.Font("title"))) ~= "space" then
		return ns.Locale.Upper(text)
	end
	local spaced = ns.Locale.Upper(text):gsub(CODEPOINT, "%1" .. THIN_SPACE)
	return spaced:sub(1, -#THIN_SPACE - 1)
end

local function NewLine(self)
	local line = {
		left = Widgets.Text(self, "body", "text"),
		right = Widgets.Text(self, "body", "textEmphasis"),
		divider = self:CreateTexture(nil, "ARTWORK"),
	}
	line.left:SetJustifyH("LEFT")
	line.right:SetJustifyH("RIGHT")
	line.right:SetWordWrap(false)
	line.divider:SetTexture((Tokens.Texture("divider")))
	return line
end

local function Acquire(self, kind)
	local line = self.pool[#self.pool]
	if line then
		self.pool[#self.pool] = nil
	else
		line = NewLine(self)
	end
	line.kind = kind
	line.left:Hide()
	line.right:Hide()
	line.divider:Hide()
	if ROLES[kind] then
		Widgets.StyleText(line.left, ROLES[kind])
		line.left:Show()
	end
	self.used[#self.used + 1] = line
	return line
end

local function Color(text, a, b, c, fallback)
	if type(a) == "string" then
		Widgets.TextColor(text, a)
	elseif type(a) == "number" and type(b) == "number" and type(c) == "number" then
		text:SetTextColor(a, b, c)
	else
		Widgets.TextColor(text, fallback)
	end
end

function Tip:SetOwner(owner, anchor, x, y, factor, bar)
	self:ClearLines()
	self.owner, self.bar, self.factor = owner, bar or owner, factor or 1
	local key = type(anchor) == "string" and anchor:gsub("^ANCHOR_", "") or "RIGHT"
	self.anchor = ANCHORS[key] and key or "RIGHT"
	self.offsetX, self.offsetY = x or 0, y or 0
end

function Tip:IsOwned(frame)
	return frame ~= nil and self.owner == frame
end

function Tip:ClearLines()
	for i = #self.used, 1, -1 do
		local line = self.used[i]
		line.left:Hide()
		line.right:Hide()
		line.divider:Hide()
		self.pool[#self.pool + 1] = line
		self.used[i] = nil
	end
	self.icon:Hide()
	self.iconShown = false
end

function Tip:SetIcon(texture, a, b, c)
	local icon = self.icon
	icon.texture:SetTexture(texture)
	local r, g, bl
	if type(a) == "string" then
		r, g, bl = Tokens.Color(a)
	elseif type(a) == "number" and type(b) == "number" and type(c) == "number" then
		r, g, bl = a, b, c
	end
	if r then
		icon.chrome:SetEdgeRGBA(r, g, bl, 1)
		icon.glow:SetColorRGB(r, g, bl)
		icon.glow:SetIntensity(1)
	else
		icon.chrome:SetEdge("edgeInner")
		icon.glow:SetIntensity(0)
	end
	icon:Show()
	self.iconShown = true
end

function Tip:AddTitle(text, a, b, c)
	local line = Acquire(self, "title")
	Widgets.SetText(line.left, Tracked(text))
	Color(line.left, a, b, c, "textEmphasis")
end

function Tip:AddCaption(text, a, b, c)
	local line = Acquire(self, "caption")
	Widgets.SetText(line.left, Tracked(text))
	Color(line.left, a, b, c, "text")
end

function Tip:AddLine(text, a, b, c, wrap)
	local line = Acquire(self, "line")
	if type(a) == "string" and type(b) == "boolean" then
		wrap = b
	end
	line.wrap = wrap ~= false
	Widgets.SetText(line.left, text)
	Color(line.left, a, b, c, "text")
end

function Tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
	local line = Acquire(self, "double")
	line.wrap = false
	Widgets.SetText(line.left, left)
	Widgets.SetText(line.right, right)
	Color(line.left, lr, lg, lb, "text")
	Color(line.right, rr, rg, rb, "textEmphasis")
	line.right:Show()
end

function Tip:AddDivider()
	local line = Acquire(self, "divider")
	line.divider:Show()
end

function Tip:AddRule()
	local line = Acquire(self, "rule")
	line.divider:Show()
end

local function Measure(self, x0, pad)
	local gap = Tokens.Size("gapLarge")
	local widest = 0
	for _, line in ipairs(self.used) do
		if ROLES[line.kind] then
			local w = Widgets.TextWidth(line.left, MIN_WIDTH)
			if line.kind == "double" then
				w = w + gap + Widgets.TextWidth(line.right, 0)
			end
			widest = max(widest, w)
		end
	end
	local total = min(MAX_WIDTH, max(MIN_WIDTH, widest + x0 + pad))
	local snapped = Widgets.Snap(self, total)
	return snapped, max(min(widest, MAX_WIDTH - x0 - pad), Widgets.Snap(self, snapped - x0 - pad))
end

local function PaintRule(texture)
	local r, g, b = Tokens.Color("accent")
	if type(texture.SetGradient) == "function" and type(CreateColor) == "function" then
		texture:SetColorTexture(Tokens.Color("white"))
		texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
	else
		texture:SetTexture((Tokens.Texture("divider")))
		texture:SetVertexColor(r, g, b, 1)
	end
end

local function PaintDivider(texture)
	texture:SetTexture((Tokens.Texture("divider")))
	Widgets.Tint(texture, "edgeFaint")
end

function Tip:Layout()
	local pad = self.chrome:Inset()
	local inset = Widgets.Snap(self, ICON_INSET)
	local iconSize = Widgets.Snap(self, ICON_SIZE)
	local border = Widgets.Border(self)
	local x0 = pad
	if self.iconShown then
		x0 = Widgets.Snap(self, ICON_INSET + ICON_SIZE + TEXT_GAP)
		local icon = self.icon
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
		icon:SetSize(iconSize, iconSize)
		local lines = border * ICON_LINES
		icon.texture:ClearAllPoints()
		icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", lines, -lines)
		icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -lines, lines)
		icon.chrome:Restyle()
		icon.glow:Restyle()
	end
	local width, inner = Measure(self, x0, pad)
	local y = inset
	for _, line in ipairs(self.used) do
		if line.kind == "rule" then
			local gap = Widgets.Snap(self, RULE_GAP)
			y = y + gap
			line.divider:ClearAllPoints()
			line.divider:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -y)
			line.divider:SetSize(Widgets.Snap(self, RULE_LENGTH), border)
			PaintRule(line.divider)
			y = y + border + gap
		elseif line.kind == "divider" then
			local gap = Widgets.Snap(self, DIVIDER_GAP)
			y = y + gap
			line.divider:ClearAllPoints()
			line.divider:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
			line.divider:SetSize(width - 2 * pad, border)
			PaintDivider(line.divider)
			y = y + border + gap
		else
			local left = line.left
			left:ClearAllPoints()
			left:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -y)
			left:SetWordWrap(line.wrap == true)
			if line.kind == "double" then
				left:SetWidth(0)
				line.right:ClearAllPoints()
				line.right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
			else
				left:SetWidth(inner)
			end
			local _, size = Tokens.Font(ROLES[line.kind])
			y = y + Widgets.TextHeight(left, size * LINE_HEIGHT) + LINE_GAP + (GAPS_AFTER[line.kind] or 0)
		end
	end
	local height = y - LINE_GAP + inset
	if self.iconShown then
		height = max(height, iconSize + 2 * inset)
	end
	height = Widgets.Snap(self, height)
	self:SetSize(width, height)
	return width, height
end

local function Plain(v)
	return not Widgets.IsSecret(v) and type(v) == "number"
end

local function Room(region, side)
	local a = ANCHORS[side]
	local screen, edge, scale, own = UIParent[a[5]](UIParent), region[a[5]](region), UIParent:GetEffectiveScale(), region:GetEffectiveScale()
	if Plain(screen) and Plain(edge) and Plain(scale) and Plain(own) then
		return (a[3] + a[4]) * (screen * scale - edge * own)
	end
end

local function Position(self, width, height)
	local owner, bar = self.owner, self.bar
	if not owner then
		return
	end
	local gap = Widgets.Snap(self, ANCHOR_GAP)
	local asked = ANCHORS[self.anchor]
	local side, x, y, extra = self.anchor, self.offsetX, self.offsetY, 0
	if not Widgets.Restricted(owner) and not Widgets.Restricted(bar) then
		local scale, most = self:GetEffectiveScale(), nil
		for _, s in ipairs({ side, asked[1], asked[6], asked[7] }) do
			local room = Room(bar, s)
			local free = room and room - ((ANCHORS[s][3] == 0 and height or width) + gap) * scale
			if free and (not most or free > most) then
				side, most = s, free
			end
			if most and most >= 0 then
				break
			end
		end
		local inner, outer = Room(owner, side), Room(bar, side)
		extra = inner and outer and (inner - outer) / scale or 0
	end
	if side ~= self.anchor then
		local flip = side == asked[1] and -1 or 0
		x, y = x * flip, y * flip
	end
	local a = ANCHORS[side]
	self:ClearAllPoints()
	self:SetPoint(a[1], owner, a[2], a[3] * (gap + extra) + x, a[4] * (gap + extra) + y)
end

function Tip:Restyle()
	self.scaled = self.factor
	self:SetScale(Widgets.Setting("tooltipScale") * self.factor)
	self.chrome:Restyle()
	if self:IsShown() then
		self:Layout()
	end
end

local function IconTile(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetFrameLevel(parent:GetFrameLevel() + ICON_LINES)
	icon.chrome = Widgets.Chrome(icon, { shape = "tile", fill = "buttonFill", shadow = false })
	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = icon:CreateMaskTexture()
	mask:SetTexture(Tokens.Texture("iconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	icon.texture, icon.mask = texture, mask
	icon.glow = Widgets.Glow(icon, { kind = "selection", spread = Tokens.Size("gapSmall") })
	icon:Hide()
	return icon
end

function Widgets.Tooltip()
	if tip then
		return tip
	end
	tip = CreateFrame("Frame", nil, Scale.Root())
	local nativeShow, nativeHide = tip.Show, tip.Hide
	for k, fn in pairs(Tip) do
		tip[k] = fn
	end
	tip:SetFrameStrata("TOOLTIP")
	tip:SetClampedToScreen(true)
	tip:EnableMouse(false)
	tip.chrome = Widgets.Chrome(tip, { shape = "panel", fill = "surface", shadow = true, popup = true })
	tip.icon = IconTile(tip)
	tip.used, tip.pool, tip.factor = {}, {}, 1
	function tip.Show(self)
		if self.scaled ~= self.factor then
			self:Restyle()
		end
		Position(self, self:Layout())
		nativeShow(self)
	end
	function tip.Hide(self)
		self.owner = nil
		nativeHide(self)
	end
	tip:ClearLines()
	nativeHide(tip)
	tip:Restyle()
	return Widgets.Track(tip)
end

local attached = setmetatable({}, { __mode = "k" })
local anchors = setmetatable({}, { __mode = "k" })

local function ShowAttached(frame)
	local content = attached[frame]
	if content == nil then
		return
	end
	local t = Widgets.Tooltip()
	local anchor = anchors[frame]
	if type(anchor) == "function" then
		anchor = anchor(frame)
	end
	t:SetOwner(frame, anchor or "ANCHOR_RIGHT")
	if type(content) == "function" then
		ns.Call(content, t, frame)
	else
		t:AddLine(content)
	end
	t:Show()
end

local function HideAttached(frame)
	if tip and tip:IsOwned(frame) then
		tip:Hide()
	end
end

function Widgets.AttachTooltip(frame, content, anchor)
	local first = attached[frame] == nil
	attached[frame] = content
	anchors[frame] = anchor
	if first then
		frame:HookScript("OnEnter", ShowAttached)
		frame:HookScript("OnLeave", HideAttached)
	end
end
