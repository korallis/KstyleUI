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
Widgets.SECTION_CAP_CHROME = GEM_CENTRE + TEXT_FROM_GEM + GEM_GAP + COUNT_GAP

function Widgets.CapsSize(text, plain, factor)
	Widgets.CapsSized[text] = plain or false
	local path, floor, flags = Tokens.Font("caps")
	local size = Widgets.Readability("sectionHeadings") and 10 * ns.Theme.FontScale() or math.max(floor, CAP_SIZE * ns.Theme.FontScale())
	Widgets.ApplyFont(text, path, size * (factor or 1), ns.Theme.outline or flags, plain)
end

function Widgets.PaintCapRule(rule)
	rule:SetColorTexture(Widgets.Rgba("steel", 0))
	rule:SetVertexColor(Tokens.Color("white"))
end

function Widgets.PaintCapMaterial(gem, rule)
	Widgets.PaintCapRule(rule)
	gem:SetTexture((Tokens.Texture("diamond")))
	gem:SetVertexColor(Tokens.Color("accent"))
	Widgets.CardHeader(gem)
end

function Widgets.RuleBelow(rule, cap, label, left, factor)
	local below = -Widgets.TextHeight(label, Widgets.LineHeight(label)) / 2 - Widgets.Snap(cap, 2 * (factor or 1)) - Widgets.Border(cap) / 2
	rule:ClearAllPoints()
	Widgets.Point(rule, "LEFT", cap, "LEFT", left, below)
	Widgets.Point(rule, "RIGHT", cap, "RIGHT", 0, below)
end

local function CapFactor(frame, textScale)
	local setting = frame.opts and frame.opts.textScale
	return (textScale or (setting and setting()) or 1) / Widgets.ScaleFactor(frame)
end

local function Placed(self)
	local factor = CapFactor(self)
	local count = self.counted
	if Widgets.Readability("sectionHeadings") then
		Widgets.RuleBelow(self.rule, self, self.label, Widgets.CapColumn(self), factor)
	else
		self.rule:ClearAllPoints()
		Widgets.Point(self.rule, "LEFT", self.label, "RIGHT", Widgets.Snap(self, GEM_GAP * factor - Widgets.TrackPad(self.label)), 0)
		if count then
			Widgets.Point(self.rule, "RIGHT", self.count, "LEFT", -Widgets.Snap(self, COUNT_GAP * factor), 0)
		elseif self.reserve then
			Widgets.Point(self.rule, "RIGHT", self, "RIGHT", -(self.reserve + Widgets.Snap(self, COUNT_GAP * factor)), 0)
		else
			Widgets.Point(self.rule, "RIGHT", self, "RIGHT")
		end
	end
	self.count:SetShown(count)
end

function Widgets.CapColumn(frame, textScale)
	local factor = CapFactor(frame, textScale)
	return Widgets.Snap(frame, GEM_CENTRE * factor) + Widgets.Snap(frame, TEXT_FROM_GEM * factor)
end

function Cap:Fit()
	if self.wrapWidth then
		return
	end
	local width = self:GetWidth()
	self.label:SetWidth(0)
	if Widgets.IsSecret(width) or type(width) ~= "number" or width <= 0 then
		return
	end
	local trail = self.counted and Widgets.TextWidth(self.count, 0) or self.reserve or 0
	local room = width - Widgets.CapColumn(self) - Widgets.Snap(self, (GEM_GAP + COUNT_GAP) * CapFactor(self)) - trail
	if Widgets.TextWidth(self.label, 0) > room then
		self.label:SetWidth(math.max(0, room) + Widgets.TrackPad(self.label))
	end
end

function Cap:SetText(text)
	Widgets.SetText(self.label, text)
	if self.wrapWidth then
		self:SetWrapWidth(self.wrapWidth)
	else
		self:Fit()
	end
end

function Cap:SetWrapWidth(width)
	self.wrapWidth = width
	local available = math.max(1, width - Widgets.CapColumn(self))
	local wrap = Widgets.TextWidth(self.label, 0) > available
	self.label:SetWordWrap(wrap)
	self.label:SetWidth(wrap and available or 0)
	local baseHeight = Widgets.SECTION_CAP_HEIGHT * CapFactor(self)
	local height = wrap and Widgets.WrappedHeight(self.label, available) or baseHeight
	self.label:SetHeight(wrap and height or 0)
	height = math.max(baseHeight, height)
	self:SetHeight(Widgets.Snap(self, height))
	self.rule:SetShown(not wrap)
	return height
end

function Cap:SetCount(value)
	self.counted = value ~= nil
	Widgets.SetText(self.count, value)
	Placed(self)
	self:Fit()
end

function Cap:SetReserve(width)
	self.reserve = type(width) == "number" and width > 0 and width or nil
	Placed(self)
	self:Fit()
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
	Widgets.PaintCapMaterial(self.gem, self.rule)
	Widgets.TextColor(self.label, "capsGold")
	Widgets.TextColor(self.count, "muted")
	if Widgets.Readability("sectionHeadings") then
		self.label:SetTextColor(Tokens.Color("capsGold"))
		self.gem:SetVertexColor(Tokens.Color("capsGold"))
		local r, g, b = Tokens.Color("capsGold")
		self.rule:SetColorTexture(r, g, b, RULE_ALPHA)
	end
end

function Cap:Restyle()
	local opts = self.opts
	local factor = CapFactor(self)
	Widgets.Size(self, opts.width or DEFAULT_WIDTH, Widgets.SECTION_CAP_HEIGHT * factor)
	local gem = Widgets.Snap(self, GEM_SIZE * factor)
	self.gem:SetSize(gem, gem)
	self.gem:ClearAllPoints()
	Widgets.Point(self.gem, "CENTER", self, "LEFT", Widgets.Snap(self, GEM_CENTRE * factor), 0)
	Widgets.CapsSize(self.label, nil, factor)
	local path, size, flags = Tokens.Font("number")
	Widgets.ApplyFont(self.count, path, size * factor, flags)
	self.label:ClearAllPoints()
	Widgets.Point(self.label, "LEFT", self.gem, "CENTER", Widgets.Snap(self, TEXT_FROM_GEM * factor), 0)
	self.rule:SetHeight(Widgets.Border(self))
	self.count:ClearAllPoints()
	Widgets.Point(self.count, "RIGHT", self, "RIGHT")
	Placed(self)
	if self.wrapWidth then
		self:SetWrapWidth(self.wrapWidth)
	end
	self:Fit()
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
	cap.label:SetWordWrap(false)
	cap.count = Widgets.Text(cap, "number", "muted")
	cap.count:SetJustifyH("RIGHT")
	cap.ruler = Widgets.Text(cap, "number", "muted")
	cap.ruler:Hide()
	cap:HookScript("OnSizeChanged", cap.Fit)
	cap:Restyle()
	if opts.text then
		cap:SetText(opts.text)
	end
	if opts.count ~= nil then
		cap:SetCount(opts.count)
	end
	return Widgets.Track(cap)
end
