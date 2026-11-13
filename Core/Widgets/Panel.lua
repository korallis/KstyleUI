-- Panel.lua: the card panel, the quest card's material with an optional title cap (a gilt diamond, the title in caps, a rule that fades right to the one close glyph), and its open and close motion, which the client plays and which never runs in combat.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion

local Panel = {}

local PAD_GAP = "gapMedium"
local GEM_SIZE, GEM_CENTRE, TEXT_FROM_GEM, RULE_GAP, RULE_ALPHA = 8, 7.4, 11.1, 10, 0.5

local function IsSecret(value)
	return Widgets.IsSecret(value)
end

local function TitleBarHeight(panel)
	return panel.chrome:Inset(PAD_GAP) + Tokens.Size("heading") + Tokens.Size("gapMedium")
end

local function MayToggle(frame)
	if not InCombatLockdown() then
		return true
	end
	local protected = frame:IsProtected()
	if IsSecret(protected) then
		return false
	end
	return not protected
end

local function Animated()
	return not InCombatLockdown() and not Motion.ReducedMotion()
end

local function Hidden(panel)
	if MayToggle(panel) then
		panel:Hide()
	end
	panel:SetAlpha(1)
end

local function AlphaGroup(panel, from, to, duration, smoothing)
	local group = panel:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetFromAlpha(from)
	alpha:SetToAlpha(to)
	alpha:SetDuration(duration)
	alpha:SetSmoothing(smoothing)
	return group
end

local function BuildMotion(panel)
	local rise = Tokens.Size("panelRise")
	local duration = Tokens.Duration("panelOpen")
	local group = panel:CreateAnimationGroup()
	local drop = group:CreateAnimation("Translation")
	drop:SetOffset(0, -rise)
	drop:SetDuration(0)
	drop:SetOrder(1)
	local up = group:CreateAnimation("Translation")
	up:SetOffset(0, rise)
	up:SetDuration(duration)
	up:SetSmoothing("OUT")
	up:SetOrder(2)
	panel.rise = group
	panel.riseParts = { drop, up }
	panel.fadeIn = AlphaGroup(panel, 0, 1, duration, "OUT")
	local fadeOut = AlphaGroup(panel, 1, 0, Tokens.Duration("panelClose"), "IN")
	fadeOut:SetToFinalAlpha(true)
	fadeOut:SetScript("OnFinished", function()
		if panel.closing then
			panel.closing = false
			Hidden(panel)
		end
	end)
	panel.fadeOut = fadeOut
	panel:HookScript("OnHide", function()
		panel.closing = false
		panel.rise:Stop()
		panel.fadeIn:Stop()
		panel.fadeOut:Stop()
		panel:SetAlpha(1)
	end)
end

function Panel:SetTitle(text)
	if not self.titleText then
		return
	end
	if Widgets.IsSecret(text) or type(text) ~= "string" then
		Widgets.SetText(self.titleText, text)
	else
		self.titleText:SetText(ns.Locale.Upper(text))
	end
end

function Panel:Open()
	self.closing = false
	self.fadeOut:Stop()
	self:SetAlpha(1)
	local shown = self:IsShown()
	if not IsSecret(shown) and not shown and MayToggle(self) then
		self:Show()
	end
	if Animated() then
		self.rise:Stop()
		self.rise:Play()
		self.fadeIn:Stop()
		self.fadeIn:Play()
	end
	Widgets.Sound("IG_MAINMENU_OPEN")
end

function Panel:Close()
	self.rise:Stop()
	self.fadeIn:Stop()
	local shown = self:IsShown()
	if not IsSecret(shown) and shown then
		if Animated() then
			self.closing = true
			self.fadeOut:Stop()
			self.fadeOut:Play()
		else
			Hidden(self)
		end
	end
	Widgets.Sound("IG_MAINMENU_CLOSE")
	local onClose = self.opts.onClose
	if onClose then
		ns.Call(onClose, self)
	end
end

function Panel:Toggle()
	local shown = self:IsShown()
	if not IsSecret(shown) and shown and not self.closing then
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
	if self.cap then
		local bar = Widgets.Snap(self, TitleBarHeight(self))
		self.titleBar:SetHeight(bar)
		local heading = Widgets.Snap(self, Tokens.Size("heading"))
		local cap = self.cap
		local gem = Widgets.Snap(self, GEM_SIZE)
		cap.gem:SetSize(gem, gem)
		cap.gem:ClearAllPoints()
		cap.gem:SetPoint("CENTER", cap, "LEFT", Widgets.Snap(self, GEM_CENTRE), 0)
		Widgets.CapsSize(cap.label)
		cap.label:ClearAllPoints()
		cap.label:SetPoint("LEFT", cap.gem, "CENTER", Widgets.Snap(self, TEXT_FROM_GEM), 0)
		cap.label:SetSize(0, heading)
		cap.rule:ClearAllPoints()
		cap.rule:SetPoint("LEFT", cap.label, "RIGHT", Widgets.Snap(self, RULE_GAP - Widgets.TrackPad(cap.label)), 0)
		cap.rule:SetPoint("RIGHT", cap, "RIGHT")
		cap.rule:SetHeight(Widgets.Border(self))
		cap.gem:SetVertexColor(Widgets.Rgba("capsGold", 1))
		Widgets.PaintCapMaterial(cap.gem, cap.rule, RULE_ALPHA)
		Widgets.TextColor(cap.label, "capsGold")
		cap:SetHeight(heading)
		self.cap:ClearAllPoints()
		self.cap:SetPoint("LEFT", self, "TOPLEFT", pad, -(pad + heading / 2))
		if self.closeButton then
			self.cap:SetPoint("RIGHT", self.closeButton, "LEFT", -Widgets.Snap(self, Tokens.Size("gapSmall")), 0)
		else
			self.cap:SetPoint("RIGHT", self, "TOPRIGHT", -pad, -(pad + heading / 2))
		end
		top = bar + Widgets.Snap(self, Tokens.Size("gapMedium"))
	end
	if self.closeButton then
		local gap = Widgets.Snap(self, Tokens.Size("gapMedium"))
		self.closeButton:ClearAllPoints()
		if self.cap then
			local heading = Widgets.Snap(self, Tokens.Size("heading"))
			self.closeButton:SetPoint("RIGHT", self, "TOPRIGHT", -gap, -(pad + heading / 2))
		else
			self.closeButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -gap, -gap)
		end
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
	panel.chrome = Widgets.Chrome(panel, { shape = shape, fill = opts.fill or "surface", shadow = opts.shadow, popup = opts.popup, ornament = opts.ornament, inside = opts.inside })
	panel.content = CreateFrame("Frame", nil, panel)
	if titled then
		local bar = CreateFrame("Frame", nil, panel)
		bar:SetPoint("TOPLEFT", panel, "TOPLEFT")
		bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
		panel.titleBar = bar
		local cap = CreateFrame("Frame", nil, panel)
		cap.gem = cap:CreateTexture(nil, "ARTWORK")
		cap.rule = cap:CreateTexture(nil, "ARTWORK")
		cap.label = Widgets.Text(panel, "caps", "capsGold")
		Widgets.CapsSize(cap.label)
		panel.cap = cap
		panel.titleText = cap.label
		panel.titleText:SetJustifyH("LEFT")
		panel.titleText:SetJustifyV("MIDDLE")
		panel.titleText:SetWordWrap(false)
		panel:SetTitle(opts.title or "")
	end
	if opts.close then
		panel.closeButton = Widgets.CloseButton(panel, function()
			panel:Close()
		end)
	end
	local crest = panel.chrome.ornament
	if crest and not opts.inside then
		crest.inside = { panel.content }
		crest.inside[#crest.inside + 1] = panel.titleText
		crest.inside[#crest.inside + 1] = panel.closeButton
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
	BuildMotion(panel)
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
