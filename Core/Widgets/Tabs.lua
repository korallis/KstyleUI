-- Tabs.lua: the tab strip, with upper-case labels and an accent underline that slides to the selected tab.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion
local max, min = math.max, math.min

local TAB_MIN_WIDTH = 64
local TEXT_FALLBACK_WIDTH = 56
local STRIP_HEIGHT = 32
local UNDERLINE_LIFT = 0.6
local GLOW_UNITS, GLOW_ALPHA = 5, 0.5
local GLOW_COLUMN, GLOW_REACH = 0.5, 0.005

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
		Widgets.Point(self.label, "CENTER", self, "CENTER", 0, -offset)
	end
end

local function OnTabClick(tab)
	tab.strip:Select(tab.value)
end

local function SetLabel(tab, label)
	local headings = Widgets.Readability("sectionHeadings")
	Widgets.StyleText(tab.label, headings and "caps" or "body")
	if headings then Widgets.CapsSize(tab.label) end
	if Widgets.IsSecret(label) or type(label) ~= "string" then
		Widgets.SetText(tab.label, label)
	else
		label = ns.Locale.Upper(label)
		if headings and ns.Locale.TrackMode((tab.label:GetFont())) == "space" then
			label = label:gsub("([%z\1-\127\194-\244][\128-\191]*)", "%1\226\128\137"):sub(1, -4)
		end
		Widgets.SetText(tab.label, label)
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
	Widgets.Point(strip.underline, "BOTTOMLEFT", strip, "BOTTOMLEFT", x, strip.underY or Widgets.Border(strip))
	strip.underline:SetWidth(w)
	strip.underGlow:SetWidth(w)
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
	return tab.x, tab.w, strip:GetHeight() - tab.y - tab:GetHeight() + Widgets.Border(strip)
end

function Tabs:Layout()
	local height = Widgets.Snap(self, self.opts.height or STRIP_HEIGHT)
	local pad = Widgets.Snap(self, Tokens.Size("gapSmall"))
	local count = #self.items
	local function Need(shrink)
		local need, widest = 0, 0
		for i = 1, count do
			local tab = self.buttons[i]
			if tab.shrunk ~= shrink then
				if tab.shrunk then SetLabel(tab, tab.text) end
				tab.shrunk = shrink
				if shrink then
					local face, size, flags = tab.label:GetFont()
					Widgets.ApplyFont(tab.label, face, size * shrink, flags)
				end
			end
			local width = Widgets.TextWidth(tab.label, TEXT_FALLBACK_WIDTH)
			need, widest = need + width, max(widest, width)
		end
		return need, widest
	end
	local wrap, equal, slack = self.opts.wrap, nil, nil
	local need, widest = Need(nil)
	if self.opts.width and count > 0 and not wrap then
		local room, gap = self.opts.width - 2 * Tokens.Size("gapSmall"), Tokens.Size("gapSmall")
		equal = Widgets.Snap(self, room / count)
		if widest + gap > equal then
			if need + count * gap > room then
				need = Need((room - count * gap) / need)
			end
			if need + count * gap > room then
				wrap, equal = true, nil
				Need(nil)
			else
				slack = (room - need) / count
			end
		end
	end
	local x, y = pad, 0
	for i = 1, count do
		local tab = self.buttons[i]
		local w = slack and Widgets.Snap(self, Widgets.TextWidth(tab.label, TEXT_FALLBACK_WIDTH) + slack) or equal
			or Widgets.Snap(self, max(TAB_MIN_WIDTH, Widgets.TextWidth(tab.label, TEXT_FALLBACK_WIDTH) + 2 * Tokens.Size("gapLarge")))
		if wrap then
			w = min(w, self.opts.width - 2 * pad)
			if x > pad and x + w > self.opts.width - pad then x, y = pad, y + height end
		end
		tab.y = y
		tab.x, tab.w, tab.inset = x, w, Widgets.Snap(self, Tokens.Size("gapMedium"))
		tab:ClearAllPoints()
		Widgets.Point(tab, "TOPLEFT", self, "TOPLEFT", x, -y)
		tab:SetSize(w, height)
		tab.placedOffset = nil
		tab:Paint()
		x = x + w
	end
	local width = self.opts.width and Widgets.Snap(self, self.opts.width) or x + pad
	self:SetSize(width, y + height)
	self.underline:SetHeight(Widgets.Border(self))
	self.underGlow:SetHeight(Widgets.Snap(self, GLOW_UNITS))
	local tx, tw, ty = Target(self)
	self.underY = ty
	self.underline:SetShown(tx ~= nil)
	self.underGlow:SetShown(tx ~= nil)
	if tx then
		self.fromX, self.fromW, self.toX, self.toW = tx, tw, tx, tw
		Slide(self, 1)
	end
end

function Tabs:Paint()
	for i = 1, #self.items do
		self.buttons[i]:Paint()
	end
	self.underline:SetVertexColor(Widgets.MixTokens("accent", 1, "textHover", 1, UNDERLINE_LIFT))
	Widgets.Tint(self.underGlow, "accent", GLOW_ALPHA)
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
	local tx, tw, ty = Target(self)
	self.underY = ty
	self.fromX, self.fromW = self.underX or tx, self.underW or tw
	self.toX, self.toW = tx, tw
	self.underline:Show()
	self.underGlow:Show()
	Motion.Tween(self, Slide, 0, 1, Motion.Slides() and Tokens.Duration("fade") or 0, Tokens.Easing("move"))
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
		tab.text = item.label
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
	for _, tab in ipairs(self.buttons) do
		if tab.text then SetLabel(tab, tab.text) end
	end
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
	strip.chrome = Widgets.Chrome(strip, { shape = "tile", fill = "buttonFill", shadow = false })
	strip.underline = strip:CreateTexture(nil, "ARTWORK")
	strip.underline:SetColorTexture(Tokens.Color("white"))
	local glow = strip:CreateTexture(nil, "ARTWORK", nil, -1)
	local shadowPath, shadowTexels = Tokens.Texture("shadow")
	glow:SetTexture(shadowPath)
	glow:SetBlendMode("ADD")
	glow:SetTexCoord(GLOW_COLUMN - GLOW_REACH, GLOW_COLUMN + GLOW_REACH, 0, shadowTexels / 2 / Widgets.TEXTURE_TEXELS.shadow)
	Widgets.Point(glow, "BOTTOMLEFT", strip.underline, "TOPLEFT")
	strip.underGlow = glow
	strip:SetTabs(opts.tabs, opts.value)
	return Widgets.Track(strip)
end
