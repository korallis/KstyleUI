-- Slider.lua: the slider, a pill track with an accent fill and a ringed knob, its value readout, step snapping and clamping.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale
local floor, max, min = math.floor, math.max, math.min
local format = string.format

local DEFAULT_WIDTH = 200
local TRACK_HEIGHT = 4
local KNOB_SIZE = 12
local RING_ALPHA, RING_HOVER_ALPHA = 0.7, 1
local MAX_DECIMALS = 10
local PRECISION = 1e-7

local function Decimals(x)
	if type(x) ~= "number" or x ~= x then
		return 0
	end
	local scaled = math.abs(x)
	for d = 0, MAX_DECIMALS do
		if math.abs(scaled - floor(scaled + 0.5)) < PRECISION then
			return d
		end
		scaled = scaled * 10
	end
	return MAX_DECIMALS
end

function Widgets.Quantize(value, low, high, step)
	if Widgets.IsSecret(value) or type(value) ~= "number" or value ~= value then
		return nil
	end
	value = min(high, max(low, value))
	if type(step) == "number" and step > 0 then
		local snapped = low + floor((value - low) / step + 0.5) * step
		local scale = 10 ^ max(Decimals(step), Decimals(low))
		snapped = floor(snapped * scale + 0.5) / scale
		if snapped > high or high - value < value - snapped then
			snapped = high
		end
		value = min(high, max(low, snapped))
	end
	return value
end

local Slider = {}

local function DefaultFormat(self, value)
	local decimals = Decimals(self.step or (self.max - self.min) / 100)
	if decimals == 0 then
		return format("%d", floor(value + 0.5))
	end
	return format("%." .. decimals .. "f", value)
end

local function Text(self, value)
	local fn = self.opts.format
	if fn then
		local ok, text = pcall(fn, value)
		if ok and text ~= nil then
			return tostring(text)
		end
	end
	return DefaultFormat(self, value)
end

function Slider:GetValue()
	return self.value
end

function Slider:IsEnabled()
	return self.enabled
end

function Slider:SetEnabled(enabled)
	self.enabled = enabled and true or false
	if not self.enabled then
		self:SetScript("OnUpdate", nil)
	end
	self:EnableMouse(self.enabled)
	self:EnableMouseWheel(self.enabled)
	self:Paint()
end

function Slider:SetValue(value, silent)
	local q = Widgets.Quantize(value, self.min, self.max, self.step)
	if q == nil or q == self.value then
		return
	end
	self.value = q
	self:Paint()
	local onChange = self.opts.onChange
	if not silent and onChange then
		ns.Call(onChange, q, self)
	end
end

function Slider:SetRange(low, high, step)
	if type(low) ~= "number" or type(high) ~= "number" or low >= high then
		error("KstyleUI.Widgets.Slider:SetRange: min must be a number below max", 2)
	end
	self.min, self.max, self.step = low, high, step
	Widgets.SetText(self.minText, Text(self, low))
	Widgets.SetText(self.maxText, Text(self, high))
	local q = Widgets.Quantize(self.value or low, low, high, step) or low
	self.value = q
	self:Paint()
end

function Slider:Paint()
	local enabled = self.enabled
	local hover = enabled and (self.hoverT or 0) or 0
	local range = self.max - self.min
	local share = range > 0 and (self.value - self.min) / range or 0
	local width = self.trackBox:GetWidth() or 0
	local filled = Widgets.Snap(self, width * share)
	local height = Widgets.Snap(self, TRACK_HEIGHT)
	self.fillBox:SetWidth(filled)
	local showFill = filled >= height
	Widgets.ShowSlice(self.fill, showFill)
	Widgets.ColorSlice(self.track, Widgets.Rgba("track"))
	if enabled then
		Widgets.ColorSlice(self.fill, Widgets.Rgba("accent"))
		self.ring:SetVertexColor(Widgets.MixTokens("accent", RING_ALPHA, "accent", RING_HOVER_ALPHA, hover))
		self.knob:SetVertexColor(Widgets.MixTokens("textEmphasis", 1, "textHover", 1, hover))
		Widgets.TextColor(self.readout, "textEmphasis")
	else
		Widgets.ColorSlice(self.fill, Widgets.Rgba("textDisabled"))
		Widgets.Tint(self.ring, "textDisabled")
		Widgets.Tint(self.knob, "textDisabled")
		Widgets.TextColor(self.readout, "textDisabled")
	end
	self.knob:SetPoint("CENTER", self.trackBox, "LEFT", filled, 0)
	Widgets.SetText(self.readout, Text(self, self.value))
end

function Slider:Restyle()
	local knob = Tokens.Size("gapTiny") + KNOB_SIZE
	local readout = Tokens.Size("body") + Tokens.Size("gapTiny")
	local range = Tokens.Size("gapTiny") + Tokens.Size("caption")
	local width = self.opts.width or DEFAULT_WIDTH
	Widgets.Size(self, width, readout + knob + range)
	local half = Widgets.Snap(self, KNOB_SIZE / 2)
	self.trackBox:ClearAllPoints()
	self.trackBox:SetPoint("TOPLEFT", self, "TOPLEFT", half, -Widgets.Snap(self, readout + knob / 2 - TRACK_HEIGHT / 2))
	Widgets.Size(self.trackBox, width - 2 * half, TRACK_HEIGHT)
	self.fillBox:ClearAllPoints()
	self.fillBox:SetPoint("TOPLEFT", self.trackBox, "TOPLEFT")
	self.fillBox:SetPoint("BOTTOMLEFT", self.trackBox, "BOTTOMLEFT")
	local height = Widgets.Snap(self, TRACK_HEIGHT)
	Widgets.LayoutPill(self.track, height)
	Widgets.LayoutPill(self.fill, height)
	Widgets.Size(self.knob, KNOB_SIZE, KNOB_SIZE)
	self.ring:ClearAllPoints()
	self.ring:SetPoint("CENTER", self.knob, "CENTER")
	Widgets.Size(self.ring, KNOB_SIZE, KNOB_SIZE)
	self.readout:ClearAllPoints()
	self.readout:SetPoint("BOTTOM", self.knob, "TOP", 0, Widgets.Snap(self, Tokens.Size("gapTiny")))
	self.minText:ClearAllPoints()
	self.minText:SetPoint("TOPLEFT", self.trackBox, "BOTTOMLEFT", 0, -Widgets.Snap(self, knob / 2))
	self.maxText:ClearAllPoints()
	self.maxText:SetPoint("TOPRIGHT", self.trackBox, "BOTTOMRIGHT", 0, -Widgets.Snap(self, knob / 2))
	self:Paint()
end

local function ValueAtCursor(self)
	local track = self.trackBox
	local left, width, scale = track:GetLeft(), track:GetWidth(), track:GetEffectiveScale()
	local x = GetCursorPosition()
	if type(left) ~= "number" or type(width) ~= "number" or width <= 0 or type(scale) ~= "number" or scale <= 0 or type(x) ~= "number" then
		return nil
	end
	local share = (x / scale - left) / width
	return self.min + share * (self.max - self.min)
end

local function Drag(self)
	if not self.enabled then
		self:SetScript("OnUpdate", nil)
		return
	end
	local value = ValueAtCursor(self)
	if value then
		self:SetValue(value)
	end
end

local function StopDrag(self)
	self:SetScript("OnUpdate", nil)
end

local function StartDrag(self, mouse)
	if not self.enabled or (mouse and mouse ~= "LeftButton") then
		return
	end
	Drag(self)
	self:SetScript("OnUpdate", Drag)
end

local function Wheel(self, delta)
	if not self.enabled then
		return
	end
	local step = self.step or (self.max - self.min) / 100
	self:SetValue(self.value + step * (delta > 0 and 1 or -1))
end

function Widgets.Slider(parent, opts)
	opts = opts or {}
	local low, high = opts.min or 0, opts.max or 1
	if type(low) ~= "number" or type(high) ~= "number" or low >= high then
		error("KstyleUI.Widgets.Slider: min must be a number below max", 2)
	end
	local slider = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Slider) do
		slider[k] = fn
	end
	slider.opts = opts
	slider.min, slider.max, slider.step = low, high, opts.step
	slider.enabled = true
	slider.value = Widgets.Quantize(opts.value or low, low, high, opts.step) or low
	slider.trackBox = CreateFrame("Frame", nil, slider)
	slider.track = Widgets.Pill(slider.trackBox, "BORDER", 0)
	slider.fillBox = CreateFrame("Frame", nil, slider.trackBox)
	slider.fill = Widgets.Pill(slider.fillBox, "ARTWORK", 0)
	slider.knob = slider.fillBox:CreateTexture(nil, "OVERLAY", nil, 0)
	slider.knob:SetTexture((Tokens.Texture("dot")))
	slider.ring = slider.fillBox:CreateTexture(nil, "OVERLAY", nil, 1)
	slider.ring:SetTexture((Tokens.Texture("ring")))
	slider.readout = Widgets.Text(slider, "body", "textEmphasis")
	slider.minText = Widgets.Text(slider, "caption", "text")
	slider.maxText = Widgets.Text(slider, "caption", "text")
	Widgets.SetText(slider.minText, Text(slider, low))
	Widgets.SetText(slider.maxText, Text(slider, high))
	slider:EnableMouse(true)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseDown", StartDrag)
	slider:SetScript("OnMouseUp", StopDrag)
	slider:SetScript("OnHide", StopDrag)
	slider:SetScript("OnMouseWheel", Wheel)
	slider:SetScript("OnEnter", function(self)
		Widgets.Hover(self, true)
	end)
	slider:SetScript("OnLeave", function(self)
		Widgets.Hover(self, false)
	end)
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(slider, opts.tooltip)
	end
	slider:Restyle()
	return Widgets.Track(slider)
end
