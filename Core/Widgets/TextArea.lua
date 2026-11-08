-- TextArea.lua: the multi-line text field, a raised tile with a scrolling edit box, the kit's slim scroll bar, a read-only mode and select-all.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion
local max, min = math.max, math.min

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 300, 160
local WHEEL_LINES = 3
local BAR_WIDTH = 3
local BAR_GAP = 2
local THUMB_MIN = 16
local THUMB_ALPHA, THUMB_HOVER_ALPHA = 0.35, 1

local Area = {}

local function Plain(v, fallback)
	if Widgets.IsSecret(v) or type(v) ~= "number" or v ~= v then
		return fallback
	end
	return v
end

local function ViewHeight(self)
	return max(0, Plain(self.scroll:GetHeight(), 0))
end

local function LineHeight(self)
	local _, size = self.box:GetFont()
	return Plain(size, Tokens.Size("body")) + Tokens.Size("gapTiny")
end

function Area:GetMaxOffset()
	return max(0, Plain(self.scroll:GetVerticalScrollRange(), 0))
end

function Area:GetOffset()
	return self.offset
end

function Area:SetOffset(offset)
	self.offset = offset
	self.scroll:SetVerticalScroll(offset)
	self:PaintBar()
end

function Area:ScrollTo(offset, instant)
	local target = min(self:GetMaxOffset(), max(0, offset))
	self.target = target
	if instant or Motion.ReducedMotion() then
		Motion.Tween(self, "SetOffset", target, target, 0)
	else
		Motion.Tween(self, "SetOffset", self.offset, target, Tokens.Duration("fade"), Tokens.Easing("hover"))
	end
end

function Area:ScrollToBottom(instant)
	self:ScrollTo(self:GetMaxOffset(), instant)
end

function Area:Scroll(delta)
	local step = LineHeight(self) * WHEEL_LINES * (delta > 0 and -1 or 1)
	self:ScrollTo((self.target or self.offset) + step)
end

function Area:PaintBar()
	local view = ViewHeight(self)
	local range = self:GetMaxOffset()
	local overflow = range > 0 and view > 0
	self.bar:SetShown(overflow)
	if not overflow then
		return
	end
	local content = view + range
	local thumb = max(Widgets.Snap(self, THUMB_MIN), Widgets.Snap(self, view * view / content))
	local share = min(1, max(0, self.offset / range))
	self.thumbHeight = thumb
	self.thumbTop = Widgets.Snap(self, (view - thumb) * share)
	self.thumb:SetHeight(thumb)
	self.thumb:ClearAllPoints()
	self.thumb:SetPoint("TOP", self.bar, "TOP", 0, -self.thumbTop)
	self.thumb:SetVertexColor(Widgets.MixTokens("text", THUMB_ALPHA, "accent", THUMB_HOVER_ALPHA, self.hoverT or 0))
end

function Area:Paint()
	self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, self.focused and 1 or 0))
	self:PaintBar()
end

function Area:Refresh()
	local maxOffset = self:GetMaxOffset()
	if self.offset > maxOffset or (self.target or 0) > maxOffset then
		self:ScrollTo(maxOffset, true)
	end
	self:PaintBar()
end

local function Put(box, text)
	if Widgets.IsSecret(text) then
		box:SetText(text)
	elseif type(text) == "string" then
		box:SetText(text)
	else
		box:SetText("")
	end
end

function Area:SetText(text)
	self.text = text
	Put(self.box, text)
	self:Refresh()
end

function Area:GetText()
	return self.box:GetText()
end

function Area:SetReadOnly(on)
	self.readOnly = on and true or false
	self.text = self.box:GetText()
end

function Area:SelectAll()
	self.box:SetFocus()
	self.box:HighlightText()
end

local function Fit(self)
	local opts = self.opts
	local pad = Widgets.Snap(self, Tokens.Size("gapMedium"))
	local barSpace = Widgets.Snap(self, BAR_WIDTH + 2 * BAR_GAP)
	local width = Plain(self:GetWidth(), opts.width or DEFAULT_WIDTH)
	local height = Plain(self:GetHeight(), opts.height or DEFAULT_HEIGHT)
	self.box:SetWidth(max(1, width - 2 * pad - barSpace))
	self.box:SetHeight(max(1, height - 2 * pad))
end

function Area:Restyle()
	local opts = self.opts
	if (opts.width and opts.height) or Plain(self:GetWidth(), 0) <= 0 or Plain(self:GetHeight(), 0) <= 0 then
		Widgets.Size(self, opts.width or DEFAULT_WIDTH, opts.height or DEFAULT_HEIGHT)
	end
	local pad = Widgets.Snap(self, Tokens.Size("gapMedium"))
	local barSpace = Widgets.Snap(self, BAR_WIDTH + 2 * BAR_GAP)
	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
	self.scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -(pad + barSpace), pad)
	Fit(self)
	self.bar:ClearAllPoints()
	self.bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -Widgets.Snap(self, BAR_GAP + pad / 2), -pad)
	self.bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -Widgets.Snap(self, BAR_GAP + pad / 2), pad)
	self.bar:SetWidth(Widgets.Snap(self, BAR_WIDTH))
	self.thumb:SetWidth(Widgets.Snap(self, BAR_WIDTH))
	self.track:SetVertexColor(Widgets.Rgba("track"))
	self:Paint()
end

local function OnTextChanged(box, userInput)
	local self = box.area
	if userInput and self.readOnly then
		Put(box, self.text)
		box:HighlightText()
		return
	end
	self.text = box:GetText()
	self:Refresh()
	local onChange = self.opts.onChange
	if onChange then
		ns.Call(onChange, box:GetText(), self, userInput)
	end
end

local function OnCursorChanged(box, _, y, _, height)
	local self = box.area
	y, height = Plain(y, nil), Plain(height, 0)
	if not y then
		return
	end
	local top = -y
	local view = ViewHeight(self)
	local offset = self.target or self.offset
	if top < offset then
		self:ScrollTo(top, true)
	elseif top + height > offset + view then
		self:ScrollTo(top + height - view, true)
	end
end

local function CursorInBar(bar)
	local top, scale = bar:GetTop(), bar:GetEffectiveScale()
	local _, y = GetCursorPosition()
	top, scale = Plain(top, nil), Plain(scale, nil)
	if not top or not scale or scale <= 0 or type(y) ~= "number" then
		return nil
	end
	return top - y / scale
end

local function ThumbDrag(bar)
	local self = bar.area
	local depth, height = CursorInBar(bar), Plain(bar:GetHeight(), 0)
	local travel = height - (self.thumbHeight or 0)
	if not depth or travel <= 0 then
		return
	end
	local share = min(1, max(0, (depth - self.grab) / travel))
	self:ScrollTo(share * self:GetMaxOffset(), true)
end

local function ThumbGrab(bar)
	local self = bar.area
	local depth = CursorInBar(bar)
	if not depth then
		return
	end
	local thumbTop, thumbHeight = self.thumbTop or 0, self.thumbHeight or 0
	if depth >= thumbTop and depth <= thumbTop + thumbHeight then
		self.grab = depth - thumbTop
	else
		self.grab = thumbHeight / 2
	end
	bar:SetScript("OnUpdate", ThumbDrag)
	ThumbDrag(bar)
end

local function StopDrag(bar)
	bar:SetScript("OnUpdate", nil)
end

function Widgets.TextArea(parent, opts)
	opts = opts or {}
	local area = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Area) do
		area[k] = fn
	end
	area.opts = opts
	area.offset = 0
	area.readOnly = opts.readOnly == true
	area.chrome = Widgets.Chrome(area, { shape = "tile", fill = "buttonFill", shadow = false })
	area.scroll = CreateFrame("ScrollFrame", nil, area)
	area.scroll:SetClipsChildren(true)
	area.box = CreateFrame("EditBox", nil, area.scroll)
	area.box.area = area
	area.box:SetMultiLine(true)
	area.box:SetAutoFocus(false)
	if opts.maxLetters then
		area.box:SetMaxLetters(opts.maxLetters)
	end
	Widgets.StyleText(area.box, "body")
	area.box:SetTextColor(Tokens.Color("textEmphasis"))
	area.scroll:SetScrollChild(area.box)
	area.box:HookScript("OnTextChanged", OnTextChanged)
	area.box:HookScript("OnCursorChanged", OnCursorChanged)
	area.box:HookScript("OnEscapePressed", function(box)
		box:ClearFocus()
	end)
	area.box:HookScript("OnEditFocusGained", function(box)
		box.area.focused = true
		box.area:Paint()
	end)
	area.box:HookScript("OnEditFocusLost", function(box)
		box.area.focused = false
		box.area:Paint()
	end)
	area.bar = CreateFrame("Button", nil, area)
	area.bar.area = area
	area.track = area.bar:CreateTexture(nil, "BACKGROUND")
	area.track:SetColorTexture(Tokens.Color("white"))
	area.track:SetAllPoints(area.bar)
	area.thumb = area.bar:CreateTexture(nil, "ARTWORK")
	area.thumb:SetColorTexture(Tokens.Color("white"))
	area.bar:SetScript("OnMouseDown", ThumbGrab)
	area.bar:SetScript("OnMouseUp", StopDrag)
	area.bar:SetScript("OnHide", StopDrag)
	area.bar:SetScript("OnEnter", function()
		Widgets.Hover(area, true)
	end)
	area.bar:SetScript("OnLeave", function()
		Widgets.Hover(area, false)
	end)
	area:EnableMouse(true)
	area:SetScript("OnMouseDown", function(self)
		self.box:SetFocus()
	end)
	area:EnableMouseWheel(true)
	area:SetScript("OnMouseWheel", function(self, delta)
		self:Scroll(delta)
	end)
	area:SetScript("OnSizeChanged", function(self)
		Fit(self)
		self:Refresh()
	end)
	area:Restyle()
	if opts.text ~= nil then
		area:SetText(opts.text)
	end
	return Widgets.Track(area)
end
