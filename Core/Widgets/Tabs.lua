-- Tabs.lua: the tab strip, with upper-case labels and an accent underline that slides to the selected tab.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion
local max = math.max

local TAB_MIN_WIDTH = 64
local TEXT_FALLBACK_WIDTH = 56
local STRIP_HEIGHT = 32
local UNDERLINE_UNITS = 2

local Tab = {}

function Tab:Paint()
	local hover = self.hoverT or 0
	if self:IsEnabled() == false then
		Widgets.TextColor(self.label, "textDisabled")
	elseif self.strip.value == self.value then
		self.label:SetTextColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, hover))
	else
		self.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
	local offset = Widgets.PressOffset(self)
	if self.placedOffset ~= offset then
		self.placedOffset = offset
		self.label:SetPoint("CENTER", self, "CENTER", 0, -offset)
	end
end

local function OnTabClick(tab)
	tab.strip:Select(tab.value)
end

local function SetLabel(tab, label)
	if Widgets.IsSecret(label) or type(label) ~= "string" then
		Widgets.SetText(tab.label, label)
	else
		tab.label:SetText(label:upper())
	end
end

local function NewTab(strip)
	local tab = CreateFrame("Button", nil, strip)
	for k, fn in pairs(Tab) do
		tab[k] = fn
	end
	tab.strip = strip
	tab.label = Widgets.Text(tab, "body", "text")
	tab.label:SetWordWrap(false)
	tab.onClick = OnTabClick
	Widgets.HookPointer(tab)
	return tab
end

local function Slide(strip, t)
	local x = strip.fromX + (strip.toX - strip.fromX) * t
	local w = strip.fromW + (strip.toW - strip.fromW) * t
	strip.underX, strip.underW = x, w
	strip.underline:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, 2 * Widgets.Border(strip))
	strip.underline:SetWidth(w)
end

local Tabs = {}

function Tabs:IndexOf(value)
	for i, item in ipairs(self.items) do
		if item.value == value then
			return i
		end
	end
end

function Tabs:GetValue()
	return self.value
end

local function Target(strip)
	local tab = strip.buttons[strip:IndexOf(strip.value) or 0]
	if not tab then
		return nil
	end
	return tab.x + tab.inset, tab.w - 2 * tab.inset
end

function Tabs:Layout()
	local height = Widgets.Snap(self, self.opts.height or STRIP_HEIGHT)
	local pad = Widgets.Snap(self, Tokens.Size("gapSmall"))
	local count = #self.items
	local equal
	if self.opts.width and count > 0 then
		equal = Widgets.Snap(self, (self.opts.width - 2 * Tokens.Size("gapSmall")) / count)
	end
	local x = pad
	for i = 1, count do
		local tab = self.buttons[i]
		local w = equal or Widgets.Snap(self, max(TAB_MIN_WIDTH, Widgets.TextWidth(tab.label, TEXT_FALLBACK_WIDTH) + 2 * Tokens.Size("gapLarge")))
		tab.x, tab.w, tab.inset = x, w, Widgets.Snap(self, Tokens.Size("gapMedium"))
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
		tab:SetSize(w, height)
		tab.placedOffset = nil
		tab:Paint()
		x = x + w
	end
	local width = self.opts.width and Widgets.Snap(self, self.opts.width) or x + pad
	self:SetSize(width, height)
	self.underline:SetHeight(Widgets.Snap(self, UNDERLINE_UNITS))
	local tx, tw = Target(self)
	self.underline:SetShown(tx ~= nil)
	if tx then
		self.fromX, self.fromW, self.toX, self.toW = tx, tw, tx, tw
		Slide(self, 1)
	end
end

function Tabs:Paint()
	for i = 1, #self.items do
		self.buttons[i]:Paint()
	end
	Widgets.Tint(self.underline, "accent")
end

function Tabs:Select(value, silent)
	local index = self:IndexOf(value)
	if not index or self.buttons[index]:IsEnabled() == false then
		return false
	end
	if value == self.value then
		return true
	end
	self.value = value
	self:Paint()
	local tx, tw = Target(self)
	self.fromX, self.fromW = self.underX or tx, self.underW or tw
	self.toX, self.toW = tx, tw
	self.underline:Show()
	Motion.Tween(self, Slide, 0, 1, Tokens.Duration("fade"), Tokens.Easing("fade"))
	local onSelect = self.opts.onSelect
	if not silent and onSelect then
		ns.Call(onSelect, value, self)
	end
	return true
end

function Tabs:SetTabEnabled(value, enabled)
	local index = self:IndexOf(value)
	if index then
		self.buttons[index]:SetEnabled(enabled)
	end
end

function Tabs:SetTabs(items, value)
	self.items = items or {}
	for i, item in ipairs(self.items) do
		local tab = self.buttons[i]
		if not tab then
			tab = NewTab(self)
			self.buttons[i] = tab
		end
		tab.value = item.value
		SetLabel(tab, item.label)
		tab:SetEnabled(not item.disabled)
		tab:Show()
	end
	for i = #self.items + 1, #self.buttons do
		self.buttons[i]:Hide()
	end
	if value == nil or not self:IndexOf(value) then
		value = self.items[1] and self.items[1].value
	end
	self.value = value
	self.underX, self.underW = nil, nil
	self:Layout()
	self:Paint()
end

function Tabs:Restyle()
	self:Layout()
	self:Paint()
end

function Widgets.Tabs(parent, opts)
	opts = opts or {}
	local strip = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Tabs) do
		strip[k] = fn
	end
	strip.opts = opts
	strip.buttons = {}
	strip.items = {}
	strip.chrome = Widgets.Chrome(strip, { shape = "tile", fill = "raised", shadow = false })
	strip.underline = strip:CreateTexture(nil, "ARTWORK")
	strip.underline:SetTexture((Tokens.Texture("divider")))
	strip:SetTabs(opts.tabs, opts.value)
	return Widgets.Track(strip)
end
