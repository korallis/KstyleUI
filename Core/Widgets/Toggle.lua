-- Toggle.lua: the on and off switch, a pill track whose round knob slides right and lights the accent when on.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion

local TRACK_WIDTH = 36
local TRACK_HEIGHT = 18
local KNOB_GAP = 3
local ON_FILL_MIX = 0.3
local OFF_EDGE_ALPHA, OFF_EDGE_HOVER_ALPHA = 0.35, 0.7

local Toggle = {}

local function SetOn(self, t)
	self.onT = t
	self:Paint()
end

function Toggle:GetValue()
	return self.value
end

function Toggle:SetValue(value, silent)
	value = value and true or false
	if value == self.value then
		return
	end
	self.value = value
	Motion.Tween(self, SetOn, self.onT or 0, value and 1 or 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
	if not silent then
		Widgets.Sound(value and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
		local onChange = self.opts.onChange
		if onChange then
			ns.Call(onChange, value, self)
		end
	end
end

function Toggle:Paint()
	local on, hover = self.onT or 0, self.hoverT or 0
	local enabled = self:IsEnabled() ~= false
	local er, eg, eb, ea = Widgets.MixTokens("text", OFF_EDGE_ALPHA, "text", OFF_EDGE_HOVER_ALPHA, enabled and hover or 0)
	local ar, ag, ab, aa = Widgets.Rgba("accent")
	Widgets.ColorSlice(self.track, Widgets.Mix(er, eg, eb, ea, ar, ag, ab, aa, on))
	Widgets.ColorSlice(self.fill, Widgets.MixTokens("raised", 1, "accent", 1, ON_FILL_MIX * on))
	self.knob:SetVertexColor(Widgets.MixTokens("text", 1, "textHover", 1, on))
	local width = Widgets.Snap(self, TRACK_WIDTH)
	local gap = Widgets.Snap(self, KNOB_GAP)
	local knob = Widgets.Snap(self, TRACK_HEIGHT - 2 * KNOB_GAP)
	local x = Widgets.Snap(self, gap + (width - knob - 2 * gap) * on)
	self.knob:SetPoint("LEFT", self.trackBox, "LEFT", x, 0)
	if not enabled then
		Widgets.TextColor(self.label, "textDisabled")
	else
		self.label:SetTextColor(Widgets.MixTokens("text", 1, "textHover", 1, hover))
	end
end

function Toggle:Restyle()
	local width, height = TRACK_WIDTH, TRACK_HEIGHT
	Widgets.Size(self.trackBox, width, height)
	local h = Widgets.Snap(self, height)
	local border = Widgets.Border(self)
	Widgets.LayoutPill(self.track, h)
	self.fillBox:ClearAllPoints()
	self.fillBox:SetPoint("TOPLEFT", self.trackBox, "TOPLEFT", border, -border)
	self.fillBox:SetPoint("BOTTOMRIGHT", self.trackBox, "BOTTOMRIGHT", -border, border)
	Widgets.LayoutPill(self.fill, h - 2 * border)
	Widgets.Size(self.knob, TRACK_HEIGHT - 2 * KNOB_GAP, TRACK_HEIGHT - 2 * KNOB_GAP)
	local labelWidth = self.label:GetText() ~= "" and (Widgets.TextWidth(self.label, 0) + Tokens.Size("gapMedium")) or 0
	Widgets.Size(self, width + labelWidth, height)
	self:Paint()
end

function Widgets.Toggle(parent, opts)
	opts = opts or {}
	local toggle = CreateFrame("Button", opts.name, parent or Scale.Root())
	for k, fn in pairs(Toggle) do
		toggle[k] = fn
	end
	toggle.opts = opts
	toggle.value = opts.value == true
	toggle.onT = toggle.value and 1 or 0
	toggle.trackBox = CreateFrame("Frame", nil, toggle)
	toggle.trackBox:SetPoint("LEFT", toggle, "LEFT")
	toggle.track = Widgets.Pill(toggle.trackBox, "BORDER", 0)
	toggle.fillBox = CreateFrame("Frame", nil, toggle.trackBox)
	toggle.fill = Widgets.Pill(toggle.fillBox, "ARTWORK", 0)
	toggle.knob = toggle.fillBox:CreateTexture(nil, "OVERLAY")
	toggle.knob:SetTexture((Tokens.Texture("dot")))
	toggle.label = Widgets.Text(toggle, "body", "text")
	toggle.label:SetPoint("LEFT", toggle.trackBox, "RIGHT", Widgets.Snap(toggle, Tokens.Size("gapMedium")), 0)
	Widgets.SetText(toggle.label, opts.label or "")
	toggle.onClick = function(self)
		self:SetValue(not self.value)
	end
	Widgets.HookPointer(toggle)
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(toggle, opts.tooltip)
	end
	toggle:Restyle()
	return Widgets.Track(toggle)
end
