-- Panel.lua: the smoked-glass panel with chamfered corners, a double bevel, a shadow, an optional title bar and close button.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion

local RISE_UP_SHARE = 0.75

local Panel = {}

local PAD_GAP = "gapMedium"

local function TitleBarHeight(panel)
	return panel.chrome:Inset(PAD_GAP) + Tokens.Size("heading") + Tokens.Size("gapMedium")
end

local function BuildRise(panel)
	local rise = Tokens.Size("panelRise")
	local overshoot = Tokens.Size("panelOvershoot")
	local duration = Tokens.Duration("panelRise")
	local group = panel:CreateAnimationGroup()
	local drop = group:CreateAnimation("Translation")
	drop:SetOffset(0, -rise)
	drop:SetDuration(0)
	drop:SetOrder(1)
	local up = group:CreateAnimation("Translation")
	up:SetOffset(0, rise + overshoot)
	up:SetDuration(duration * RISE_UP_SHARE)
	up:SetSmoothing("OUT")
	up:SetOrder(2)
	local settle = group:CreateAnimation("Translation")
	settle:SetOffset(0, -overshoot)
	settle:SetDuration(duration * (1 - RISE_UP_SHARE))
	settle:SetSmoothing("IN_OUT")
	settle:SetOrder(3)
	panel.rise = group
	panel.riseParts = { drop, up, settle }
end

function Panel:SetTitle(text)
	if not self.titleText then
		return
	end
	if Widgets.IsSecret(text) or type(text) ~= "string" then
		Widgets.SetText(self.titleText, text)
	else
		self.titleText:SetText(text:upper())
	end
end

function Panel:Open()
	if self.rise and not Motion.ReducedMotion() then
		self.rise:Stop()
		self.rise:Play()
	end
	Motion.FadeIn(self, Tokens.Duration("panelOpen"))
	Widgets.Sound("IG_MAINMENU_OPEN")
end

function Panel:Close()
	if self.rise then
		self.rise:Stop()
	end
	Motion.FadeOut(self, Tokens.Duration("panelClose"))
	Widgets.Sound("IG_MAINMENU_CLOSE")
	local onClose = self.opts.onClose
	if onClose then
		ns.Call(onClose, self)
	end
end

function Panel:Toggle()
	if self:IsShown() then
		self:Close()
	else
		self:Open()
	end
end

function Panel:Restyle()
	local opts = self.opts
	if opts.width and opts.height then
		Widgets.Size(self, opts.width, opts.height)
	end
	local pad = self.chrome:Inset(PAD_GAP)
	local top = pad
	if self.titleText then
		local bar = Widgets.Snap(self, TitleBarHeight(self))
		self.titleBar:SetHeight(bar)
		self.titleText:ClearAllPoints()
		self.titleText:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		if self.closeButton then
			self.titleText:SetPoint("RIGHT", self.closeButton, "LEFT", -Widgets.Snap(self, Tokens.Size("gapSmall")), 0)
		else
			self.titleText:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
		end
		top = bar + Widgets.Snap(self, Tokens.Size("gapMedium"))
	end
	if self.closeButton then
		local gap = Widgets.Snap(self, Tokens.Size("gapMedium"))
		self.closeButton:ClearAllPoints()
		self.closeButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -gap, -gap)
	end
	self.content:ClearAllPoints()
	self.content:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -top)
	self.content:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -pad, pad)
end

local function StartDrag(bar)
	bar:GetParent():StartMoving()
end

local function StopDrag(bar)
	local panel = bar:GetParent()
	panel:StopMovingOrSizing()
	local onMoved = panel.opts.onMoved
	if onMoved then
		ns.Call(onMoved, panel)
	end
end

function Widgets.Panel(parent, opts)
	opts = opts or {}
	local panel = CreateFrame("Frame", opts.name, parent or Scale.Root())
	for k, fn in pairs(Panel) do
		panel[k] = fn
	end
	panel.opts = opts
	if opts.strata then
		panel:SetFrameStrata(opts.strata)
	end
	local titled = opts.title or opts.close or opts.movable
	local shape = opts.shape or (titled and "window" or "panel")
	panel.chrome = Widgets.Chrome(panel, { shape = shape, fill = opts.fill or "surface", shadow = opts.shadow })
	panel.content = CreateFrame("Frame", nil, panel)
	if titled then
		local bar = CreateFrame("Frame", nil, panel)
		bar:SetPoint("TOPLEFT", panel, "TOPLEFT")
		bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
		panel.titleBar = bar
		panel.titleText = Widgets.Text(panel, "body", "textEmphasis")
		panel.titleText:SetJustifyH("LEFT")
		panel.titleText:SetWordWrap(false)
		panel:SetTitle(opts.title or "")
	end
	if opts.close then
		panel.closeButton = Widgets.CloseButton(panel, function()
			panel:Close()
		end)
	end
	if opts.movable then
		panel:SetMovable(true)
		panel:SetClampedToScreen(true)
		panel.titleBar:EnableMouse(true)
		panel.titleBar:RegisterForDrag("LeftButton")
		panel.titleBar:SetScript("OnDragStart", StartDrag)
		panel.titleBar:SetScript("OnDragStop", StopDrag)
	end
	if opts.escape then
		Widgets.EscapeCloses(panel, function()
			panel:Close()
		end)
	end
	BuildRise(panel)
	panel:Restyle()
	Widgets.Track(panel)
	if opts.layout then
		Widgets.Place(panel, opts.layout.key, opts.layout.position, opts.layout.options)
	end
	if opts.hidden then
		panel:Hide()
	end
	return panel
end
