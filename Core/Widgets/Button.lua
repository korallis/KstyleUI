-- Button.lua: the text button and the close button, chamfered tiles whose hairline and text follow hover and press.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale
local max = math.max

local BUTTON_MIN_WIDTH = 80
local TEXT_FALLBACK_WIDTH = 60
local PRIMARY_EDGE_ALPHA = 0.7
local CLOSE_SIZE = 20
local CLOSE_GLYPH = 10
local CLOSE_RING_ALPHA = 0.7
local CLICK_SOUND = "U_CHAT_SCROLL_BUTTON"

local function ButtonHeight()
	return Tokens.Size("rowHeight") + Tokens.Size("gapSmall")
end

local function PlaceContent(self, region)
	if not Widgets.MayMove(self) then
		return
	end
	local offset = Widgets.PressOffset(self)
	if self.placedOffset ~= offset then
		self.placedOffset = offset
		Widgets.Point(region, "CENTER", self, "CENTER", 0, -offset)
	end
end

local function OnEnter(self)
	Widgets.Hover(self, true)
end

local function OnLeave(self)
	Widgets.Hover(self, false)
	Widgets.Press(self, false)
end

local function OnMouseDown(self)
	if self:IsEnabled() then
		Widgets.Press(self, true)
	end
end

local function OnMouseUp(self)
	Widgets.Press(self, false)
end

local function OnStateChanged(self)
	self:Paint()
end

local function OnClick(self, mouse)
	if not self.silent then
		Widgets.Sound(CLICK_SOUND)
	end
	local onClick = self.onClick
	if onClick then
		ns.Call(onClick, self, mouse)
	end
end

function Widgets.HookPointer(frame)
	frame:HookScript("OnEnter", OnEnter)
	frame:HookScript("OnLeave", OnLeave)
	frame:HookScript("OnMouseDown", OnMouseDown)
	frame:HookScript("OnMouseUp", OnMouseUp)
	frame:HookScript("OnEnable", OnStateChanged)
	frame:HookScript("OnDisable", OnStateChanged)
	frame:HookScript("OnClick", OnClick)
end

local Button = {}

function Button:Paint()
	local hover = self.hoverT or 0
	if self:IsEnabled() == false then
		self.chrome:SetEdge("edgeInner")
		Widgets.TextColor(self.label, "textDisabled")
	elseif self.primary then
		self.chrome:SetEdgeRGBA(Widgets.MixTokens("accent", PRIMARY_EDGE_ALPHA, "accent", 1, hover))
		self.label:SetTextColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, hover))
	else
		self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, hover))
		self.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
	PlaceContent(self, self.label)
end

function Button:SetText(text)
	Widgets.SetText(self.label, text)
	if not self.opts.width then
		self:Restyle()
	end
end

function Button:GetText()
	return self.label:GetText()
end

function Button:Restyle()
	local width = self.opts.width or max(BUTTON_MIN_WIDTH, Widgets.TextWidth(self.label, TEXT_FALLBACK_WIDTH) + 2 * Tokens.Size("gapLarge"))
	if Widgets.MayMove(self) then
		Widgets.Size(self, width, self.opts.height or ButtonHeight())
		self.placedOffset = nil
	end
	self:Paint()
end

function Widgets.Button(parent, opts)
	opts = opts or {}
	local button = CreateFrame("Button", opts.name, parent or Scale.Root(), opts.template)
	for k, fn in pairs(Button) do
		button[k] = fn
	end
	button.opts = opts
	button.primary = opts.primary == true
	button.onClick = opts.onClick
	button.chrome = Widgets.Chrome(button, { shape = "tile", fill = "buttonFill", shadow = false })
	button.label = Widgets.Text(button, "body", "text")
	button.label:SetWordWrap(false)
	Widgets.SetText(button.label, opts.text or "")
	Widgets.HookPointer(button)
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(button, opts.tooltip)
	end
	button:Restyle()
	return Widgets.Track(button)
end

function Widgets.CloseRing(owner, below, store)
	store = store or owner
	local ring = store.closeRing
	if not Widgets.Medallions() then
		if ring then
			ring.chrome:SetShown(false)
		end
		return
	end
	if not ring then
		local frame = owner
		if below then
			frame = CreateFrame("Frame", nil, owner)
			frame:SetFrameLevel(owner:GetFrameLevel() + 1)
			frame:SetPoint("CENTER", owner, "CENTER")
		end
		ring = { frame = frame, chrome = Widgets.Chrome(frame, { shape = "tile", fill = "buttonFill", shadow = false, radius = CLOSE_SIZE / 2 }) }
		store.closeRing = ring
	end
	if ring.frame ~= owner and Widgets.MayMove(ring.frame) then
		Widgets.Size(ring.frame, CLOSE_SIZE, CLOSE_SIZE)
	end
	ring.chrome:SetEdge("steel", CLOSE_RING_ALPHA)
	ring.chrome:SetShown(true)
end

local Close = {}

function Close:Paint()
	Widgets.CloseRing(self)
	if self:IsEnabled() == false then
		Widgets.Tint(self.glyph, "textDisabled")
	else
		self.glyph:SetVertexColor(Widgets.MixTokens("text", 1, "textHover", 1, self.hoverT or 0))
	end
	PlaceContent(self, self.glyph)
end

function Close:Restyle()
	if Widgets.MayMove(self) then
		Widgets.Size(self, CLOSE_SIZE, CLOSE_SIZE)
		Widgets.Size(self.glyph, CLOSE_GLYPH, CLOSE_GLYPH)
		self.placedOffset = nil
	end
	self:Paint()
end

function Widgets.CloseButton(parent, onClick)
	parent = parent or Scale.Root()
	local button = CreateFrame("Button", nil, parent)
	button:SetFrameLevel(parent:GetFrameLevel() + 2)
	for k, fn in pairs(Close) do
		button[k] = fn
	end
	button.onClick = onClick
	button.glyph = button:CreateTexture(nil, "ARTWORK")
	button.glyph:SetTexture((Tokens.Texture("glyphClose")))
	Widgets.HookPointer(button)
	button:Restyle()
	return Widgets.Track(button)
end
