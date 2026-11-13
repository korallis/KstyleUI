-- SectionCap.lua: the rail section cap as the owner's picture draws it, a solid gilt diamond, a tracked Cinzel head, a half-strength gilt rule and an optional count at the right end, or a reserved width there for a count drawn by another frame, measured on a ruler that is never shown.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale

local GEM_ALPHA = 1
local RULE_ALPHA = 0.5
local GEM_CENTRE = 7.4
local GEM_SIZE = 8
local TEXT_FROM_GEM = 11.1
local GEM_GAP = 10
local COUNT_GAP = 8.6
local CAP_SIZE = 12
local DEFAULT_WIDTH = 278

local Cap = {}

Widgets.CAPS_SIZE = CAP_SIZE

function Widgets.CapsSize(text, plain)
	Widgets.CapsSized[text] = plain or false
	local path, floor, flags = Tokens.Font("caps")
	Widgets.ApplyFont(text, path, math.max(floor, CAP_SIZE * ns.Theme.FontScale()), flags, plain)
end

function Widgets.PaintCapRule(rule, alpha)
	local material = Tokens.Material(Widgets.Setting("cardMaterial"))
	if material and material.rule then
		rule:SetTexture((Tokens.Texture(material.rule)))
		rule:SetVertexColor(Widgets.Rgba("materialGold", alpha))
	else
		rule:SetColorTexture(Widgets.Rgba("capsGold", alpha))
		rule:SetVertexColor(Tokens.Color("white"))
	end
	return material
end

function Widgets.PaintCapMaterial(gem, rule, alpha)
	local material = Widgets.PaintCapRule(rule, alpha)
	gem:SetTexture((Tokens.Texture(material and material.gem or "diamond")))
	if material and material.rule then
		gem:SetVertexColor(Tokens.Color("materialGold"))
	end
end

local function Placed(self)
	local count = self.counted
	self.rule:ClearAllPoints()
	Widgets.Point(self.rule, "LEFT", self.label, "RIGHT", Widgets.Snap(self, GEM_GAP - Widgets.TrackPad(self.label)), 0)
	if count then
		Widgets.Point(self.rule, "RIGHT", self.count, "LEFT", -Widgets.Snap(self, COUNT_GAP), 0)
	elseif self.reserve then
		Widgets.Point(self.rule, "RIGHT", self, "RIGHT", -(self.reserve + Widgets.Snap(self, COUNT_GAP)), 0)
	else
		Widgets.Point(self.rule, "RIGHT", self, "RIGHT")
	end
	self.count:SetShown(count)
end

function Cap:SetText(text)
	Widgets.SetText(self.label, text)
	if self.wrapWidth then
		self:SetWrapWidth(self.wrapWidth)
	end
end

function Cap:SetWrapWidth(width)
	self.wrapWidth = width
	local available = math.max(1, width - Widgets.Snap(self, GEM_CENTRE) - Widgets.Snap(self, TEXT_FROM_GEM))
	local wrap = Widgets.TextWidth(self.label, 0) > available
	self.label:SetWordWrap(wrap)
	self.label:SetWidth(wrap and available or 0)
	local height = wrap and Widgets.WrappedHeight(self.label, available) or Widgets.SECTION_CAP_HEIGHT
	self.label:SetHeight(wrap and height or 0)
	height = math.max(Widgets.SECTION_CAP_HEIGHT, height)
	self:SetHeight(Widgets.Snap(self, height))
	self.rule:SetShown(not wrap)
	return height
end

function Cap:SetCount(value)
	self.counted = value ~= nil
	Widgets.SetText(self.count, value)
	Placed(self)
end

function Cap:SetReserve(width)
	self.reserve = type(width) == "number" and width > 0 and width or nil
	Placed(self)
end

function Cap:MeasureCount(value)
	local ruler = self.ruler
	local font, size, flags = self.count:GetFont()
	if font then
		ruler:SetFont(font, size, flags)
	end
	Widgets.SetText(ruler, value)
	local width = Widgets.TextWidth(ruler, 0)
	ruler:SetText("")
	return width
end

function Cap:Paint()
	self.gem:SetVertexColor(Widgets.Rgba("capsGold", GEM_ALPHA))
	self.rule:SetColorTexture(Widgets.Rgba("capsGold", RULE_ALPHA))
	Widgets.PaintCapMaterial(self.gem, self.rule, RULE_ALPHA)
	Widgets.TextColor(self.label, "capsGold")
	Widgets.TextColor(self.count, "muted")
end

function Cap:Restyle()
	local opts = self.opts
	Widgets.Size(self, opts.width or DEFAULT_WIDTH, Widgets.SECTION_CAP_HEIGHT)
	local gem = Widgets.Snap(self, GEM_SIZE)
	self.gem:SetSize(gem, gem)
	self.gem:ClearAllPoints()
	Widgets.Point(self.gem, "CENTER", self, "LEFT", Widgets.Snap(self, GEM_CENTRE), 0)
	Widgets.CapsSize(self.label)
	self.label:ClearAllPoints()
	Widgets.Point(self.label, "LEFT", self.gem, "CENTER", Widgets.Snap(self, TEXT_FROM_GEM), 0)
	self.rule:SetHeight(Widgets.Border(self))
	self.count:ClearAllPoints()
	Widgets.Point(self.count, "RIGHT", self, "RIGHT")
	Placed(self)
	if self.wrapWidth then
		self:SetWrapWidth(self.wrapWidth)
	end
	self:Paint()
end

function Widgets.SectionCap(parent, opts)
	opts = opts or {}
	local cap = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Cap) do
		cap[k] = fn
	end
	cap.opts = opts
	cap.counted = false
	cap.gem = cap:CreateTexture(nil, "ARTWORK")
	cap.gem:SetTexture((Tokens.Texture("diamond")))
	cap.rule = cap:CreateTexture(nil, "ARTWORK")
	cap.label = Widgets.Text(cap, "caps", "capsGold")
	cap.count = Widgets.Text(cap, "number", "muted")
	cap.count:SetJustifyH("RIGHT")
	cap.ruler = Widgets.Text(cap, "number", "muted")
	cap.ruler:Hide()
	cap:Restyle()
	if opts.text then
		cap:SetText(opts.text)
	end
	if opts.count ~= nil then
		cap:SetCount(opts.count)
	end
	return Widgets.Track(cap)
end
