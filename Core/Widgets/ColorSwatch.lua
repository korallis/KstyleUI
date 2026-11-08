-- ColorSwatch.lua: a chamfered tile filled with a colour that opens Blizzard's colour picker through its public setup function.
local _, ns = ...

local Widgets = ns.Widgets
local Scale = ns.Scale

local DEFAULT_SIZE = 20

local Swatch = {}

local function IsUnit(v)
	return not Widgets.IsSecret(v) and type(v) == "number" and v == v and v >= 0 and v <= 1
end

function Swatch:GetColor()
	local c = self.color
	return c[1], c[2], c[3], c[4]
end

function Swatch:SetColor(r, g, b, a, silent)
	if not (IsUnit(r) and IsUnit(g) and IsUnit(b)) then
		return false
	end
	if not IsUnit(a) then
		a = 1
	end
	local c = self.color
	c[1], c[2], c[3], c[4] = r, g, b, a
	self.chrome:SetFillRGBA(r, g, b, a)
	local onChange = self.opts.onChange
	if not silent and onChange then
		ns.Call(onChange, r, g, b, a, self)
	end
	return true
end

function Swatch:Paint()
	if self:IsEnabled() == false then
		self.chrome:SetEdge("textDisabled")
	else
		self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", 1, self.hoverT or 0))
	end
end

function Swatch:Restyle()
	local size = self.opts.size or DEFAULT_SIZE
	Widgets.Size(self, size, size)
	self:Paint()
end

local function Picker()
	local picker = ColorPickerFrame
	if type(picker) == "table" and type(picker.SetupColorPickerAndShow) == "function" then
		return picker
	end
	return nil
end

local function ReadPicker(picker, fallbackAlpha, hasAlpha)
	if type(picker.GetColorRGB) ~= "function" then
		return nil
	end
	local r, g, b = picker:GetColorRGB()
	local a = fallbackAlpha
	if hasAlpha and type(picker.GetColorAlpha) == "function" then
		a = picker:GetColorAlpha()
	end
	if IsUnit(r) and IsUnit(g) and IsUnit(b) and IsUnit(a) then
		return r, g, b, a
	end
	return nil
end

function Swatch:Open()
	local picker = Picker()
	if not picker then
		Widgets.LogOnce("colorpicker", "ColorPickerFrame:SetupColorPickerAndShow is missing; the colour swatch cannot open the picker")
		return false
	end
	local r, g, b, a = self:GetColor()
	local hasAlpha = self.opts.hasAlpha == true
	local swatch = self
	local function picked()
		local nr, ng, nb, na = ReadPicker(picker, a, hasAlpha)
		if nr then
			swatch:SetColor(nr, ng, nb, na)
		end
	end
	local function cancelled(previous)
		if type(previous) == "table" then
			swatch:SetColor(previous.r, previous.g, previous.b, previous.a or a)
		else
			swatch:SetColor(r, g, b, a)
		end
	end
	ns.Call(picker.SetupColorPickerAndShow, picker, {
		r = r, g = g, b = b,
		opacity = a,
		hasOpacity = hasAlpha,
		swatchFunc = picked,
		opacityFunc = picked,
		cancelFunc = cancelled,
	})
	return true
end

function Widgets.ColorSwatch(parent, opts)
	opts = opts or {}
	local swatch = CreateFrame("Button", opts.name, parent or Scale.Root())
	for k, fn in pairs(Swatch) do
		swatch[k] = fn
	end
	swatch.opts = opts
	swatch.color = { 1, 1, 1, 1 }
	swatch.chrome = Widgets.Chrome(swatch, { shape = "tile", fill = "buttonFill", shadow = false })
	local c = opts.color or {}
	swatch:SetColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1, true)
	swatch.onClick = function(self)
		self:Open()
	end
	Widgets.HookPointer(swatch)
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(swatch, opts.tooltip)
	end
	swatch:Restyle()
	return Widgets.Track(swatch)
end
