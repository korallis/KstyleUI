-- StatusBar.lua: the status bar, with a texture, a background framed by a dark keyline, an optional spark and sheen, and values that only reach the engine's setters.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale, Motion = ns.Tokens, ns.Scale, ns.Motion
local min = math.min

local DEFAULT_TEXTURE = "Glass"
local SPARK_WIDTH = 10
local SPARK_HEIGHT_SHARE = 1.8
local SPARK_ALPHA = 0.8
local SHEEN_WIDTH = 28
local SHEEN_ALPHA = 0.35
local BORDER_LINES = 2
local SHEEN_TOP_ALPHA = 0.35
local SHEEN_TOP_SUBLEVEL = 7
local GLOW_REACH, GLOW_ALPHA = 4, 0.5
local CAP_WRAP = "CLAMPTOWHITE"
local KEYLINE = "edgeOuter"
local KEYLINE_SUBLEVEL = -1
local LIT_ALPHA = 0.3
local LIT_SUBLEVEL = 6
local SHADE_ALPHA = 0.28
local SHADE_SUBLEVEL = 5

local SPARK_EDGE = {
	HORIZONTAL = { normal = "RIGHT", reverse = "LEFT" },
	VERTICAL = { normal = "TOP", reverse = "BOTTOM" },
}

local COLOR_CHANNELS = 4
local EDGE_PIXELS = 2
local RAMP_KINDS = {
	plate = { { 208 / 195, 74 / 67, 67 / 61 }, { 179 / 195, 59 / 67, 54 / 61 } },
	health = { { 46 / 44, 109 / 105, 213 / 204 }, { 41 / 44, 98 / 105, 192 / 204 } },
	target = { { 208 / 197, 74 / 68, 67 / 62 }, { 179 / 197, 58 / 68, 53 / 62 } },
	power = { { 62 / 61, 62 / 61, 242 / 236 }, { 57 / 61, 57 / 61, 221 / 236 } },
}

local TEXTURE_PATHS = {}
for _, item in ipairs(Tokens.MediaList("statusbar")) do
	TEXTURE_PATHS[item.key] = item.path
end

local function ResolveTexture(key)
	key = key or DEFAULT_TEXTURE
	return TEXTURE_PATHS[key] or key
end

local function Interpolation()
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.ExponentialEaseOut
end

local Bar = {}

local function Shade(texture)
	if type(texture.SetGradient) ~= "function" or type(CreateColor) ~= "function" then
		texture:Hide()
		Widgets.LogOnce("bar-shade", "Texture:SetGradient or CreateColor is missing; bars draw without their shade")
		return
	end
	local r, g, b = Tokens.Color("black")
	texture:SetGradient("VERTICAL", CreateColor(r, g, b, SHADE_ALPHA), CreateColor(r, g, b, 0))
end

function Bar:SetBarValue(value)
	local interpolation = self.smooth and Interpolation()
	if interpolation then
		self:SetValue(value, interpolation)
	else
		self:SetValue(value)
	end
end

function Bar:SetBarRange(low, high)
	self:SetMinMaxValues(low, high)
end

function Bar:SetBarDuration(duration)
	if type(self.SetTimerDuration) ~= "function" then
		Widgets.LogOnce("bar-timer", "StatusBar:SetTimerDuration is missing; the timer bar is not shown")
		return false
	end
	self:SetTimerDuration(duration)
	return true
end

function Bar:Paint()
	local c = self.colorRGBA
	if self.ownColor then
		self:SetStatusBarColor(unpack(c, 1, c.n))
	else
		self:SetStatusBarColor(Tokens.Color(self.colorName))
	end
	if self.background then
		Widgets.Tint(self.background, self.backgroundName)
	end
	if self.spark then
		self.spark:SetVertexColor(Widgets.Rgba("textHover", SPARK_ALPHA))
	end
	if self.sheen then
		self.sheen:SetVertexColor(Widgets.Rgba("textHover", SHEEN_ALPHA))
	end
	if self.sheenTop then
		self.sheenTop:SetVertexColor(Widgets.Rgba("white", SHEEN_TOP_ALPHA))
	end
	if self.lit then
		self.lit:SetVertexColor(Widgets.Rgba("white", LIT_ALPHA))
	end
end

local function Clamp01(value)
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

function Widgets.FillRamp(r, g, b, kind)
	if Widgets.IsSecret(r) or Widgets.IsSecret(g) or Widgets.IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	local ratio = RAMP_KINDS[kind] or RAMP_KINDS.plate
	local top, bottom = ratio[1], ratio[2]
	return Clamp01(r * top[1]), Clamp01(g * top[2]), Clamp01(b * top[3]),
		Clamp01(r * bottom[1]), Clamp01(g * bottom[2]), Clamp01(b * bottom[3])
end

local function WriteColor(color, r, g, b, a)
	if type(color.SetRGBA) == "function" then
		color:SetRGBA(r, g, b, a)
	else
		color.r, color.g, color.b, color.a = r, g, b, a
	end
	return color
end

function Bar:RampColors()
	local colors = self.rampColors
	if colors or type(CreateColor) ~= "function" then
		return colors
	end
	local wr, wg, wb, wa = Tokens.Color("white")
	colors = { CreateColor(wr, wg, wb, wa), CreateColor(wr, wg, wb, wa), CreateColor(wr, wg, wb, wa) }
	self.rampColors = colors
	return colors
end

function Bar:FlatTexture()
	local path = self.texturePath
	if type(path) ~= "string" then
		return false
	end
	local flat = Tokens.Texture("barFlat")
	return path == flat
end

local function Extrapolate(self, topR, topG, topB, botR, botG, botB)
	if not self.innerEdgeOn then
		return topR, topG, topB, botR, botG, botB
	end
	local height = self:GetHeight()
	local unit = Scale.Pixel(1) / Widgets.ScaleFactor(self)
	if type(height) ~= "number" or Widgets.IsSecret(height) or height <= 0 or type(unit) ~= "number" or unit <= 0 then
		return topR, topG, topB, botR, botG, botB
	end
	local pixels = height / unit
	local edge = EDGE_PIXELS
	if pixels <= edge * 2 + 1 then
		return topR, topG, topB, botR, botG, botB
	end
	local tHi = (edge + 0.5) / pixels
	local tLo = (pixels - edge - 0.5) / pixels
	local span = tLo - tHi
	local function ends(visibleTop, visibleBot)
		return Clamp01((visibleTop * tLo - visibleBot * tHi) / span),
			Clamp01(((1 - tHi) * visibleBot - (1 - tLo) * visibleTop) / span)
	end
	local hiR, loR = ends(topR, botR)
	local hiG, loG = ends(topG, botG)
	local hiB, loB = ends(topB, botB)
	return hiR, hiG, hiB, loR, loG, loB
end

function Bar:ApplyFillRamp()
	local source = self.fillSource
	if not source then
		return
	end
	local r, g, b = source[1], source[2], source[3]
	local topR, topG, topB, botR, botG, botB = Widgets.FillRamp(r, g, b, self.rampKind)
	local texture = self:GetStatusBarTexture()
	local colors = self:RampColors()
	local canGradient = self.rampOn == true and texture and colors and type(texture.SetGradient) == "function" and self:FlatTexture()
	if not topR or not canGradient then
		if canGradient and self.fillRamped then
			texture:SetGradient("VERTICAL", colors[1], colors[1])
		elseif texture and colors and type(texture.SetGradient) == "function" and self.fillRamped then
			texture:SetGradient("VERTICAL", colors[1], colors[1])
		end
		self.fillRamped = false
		self:SetStatusBarColor(r, g, b)
		return
	end
	local wr, wg, wb, wa = Tokens.Color("white")
	self:SetStatusBarColor(wr, wg, wb, wa)
	topR, topG, topB, botR, botG, botB = Extrapolate(self, topR, topG, topB, botR, botG, botB)
	texture:SetGradient("VERTICAL", WriteColor(colors[2], botR, botG, botB, wa), WriteColor(colors[3], topR, topG, topB, wa))
	self.fillRamped = true
end

function Bar:SetFillRamp(r, g, b, kind)
	local source = self.fillSource
	if not source then
		source = {}
		self.fillSource = source
	end
	source[1], source[2], source[3] = r, g, b
	self.rampKind = kind
	self.rampOn = true
	local c = self.colorRGBA
	c.n = 3
	c[1], c[2], c[3], c[4] = r, g, b, nil
	self.ownColor = true
	self:ApplyFillRamp()
end

function Bar:PlaceInnerEdge()
	local edge = self.innerEdge
	if not edge then
		return
	end
	local px = Widgets.Snap(self, Scale.Pixel(EDGE_PIXELS) / Widgets.ScaleFactor(self))
	local token = self.innerEdgeToken or "black"
	for i = 1, 4 do
		Widgets.Tint(edge[i], token)
		edge[i]:SetShown(self.innerEdgeOn == true)
	end
	edge[1]:ClearAllPoints()
	edge[1]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
	edge[1]:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
	edge[1]:SetHeight(px)
	edge[2]:ClearAllPoints()
	edge[2]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
	edge[2]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
	edge[2]:SetHeight(px)
	edge[3]:ClearAllPoints()
	edge[3]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -px)
	edge[3]:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, px)
	edge[3]:SetWidth(px)
	edge[4]:ClearAllPoints()
	edge[4]:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -px)
	edge[4]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, px)
	edge[4]:SetWidth(px)
end

function Bar:SetInnerEdge(on, token)
	if on and not self.innerEdge then
		local edge = {}
		for i = 1, 4 do
			local texture = Widgets.Crisp(self:CreateTexture(nil, "OVERLAY", nil, 2))
			texture:SetColorTexture(Tokens.Color("white"))
			edge[i] = texture
		end
		self.innerEdge = edge
	end
	self.innerEdgeOn = on == true
	if token then
		self.innerEdgeToken = token
	end
	self:PlaceInnerEdge()
end

function Bar:SetBarColor(...)
	local c = self.colorRGBA
	c.n = min(select("#", ...), COLOR_CHANNELS)
	c[1], c[2], c[3], c[4] = ...
	self.ownColor = true
	if self.rampOn then
		self:SetFillRamp(c[1], c[2], c[3], self.rampKind)
		return
	end
	if self.fillRamped then
		self:ApplyFillRamp()
	end
	self:Paint()
end

function Bar:SetFillColor(r, g, b, a)
	local c = self.colorRGBA
	c[1], c[2], c[3], c[4] = r, g, b, a
	c.n = a ~= nil and 4 or 3
	self.ownColor = true
	self:SetStatusBarColor(r, g, b, a)
end

function Bar:SetColorToken(name)
	Tokens.Color(name)
	self.colorName = name
	self.ownColor = false
	self:Paint()
end

function Bar:SetBarTexture(key)
	local path = ResolveTexture(key)
	self.textureKey = key
	if path == self.texturePath then
		return
	end
	self.texturePath = path
	self:SetStatusBarTexture(path)
	if self.background then
		self.background:SetTexture(path)
	end
end

function Bar:PlaceLit()
	local lit, fill = self.lit, self:GetStatusBarTexture()
	if lit.fill ~= fill then
		lit.fill = fill
		lit:ClearAllPoints()
		lit:SetPoint("TOPLEFT", fill, "TOPLEFT")
		lit:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
		self.shade:ClearAllPoints()
		self.shade:SetPoint("TOPLEFT", fill, "TOPLEFT")
		self.shade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	end
	local height = Widgets.Border(self)
	if lit.height ~= height then
		lit.height = height
		lit:SetHeight(height)
	end
end

function Bar:SetSparkShown(shown)
	if self.spark then
		self.spark:SetShown(shown)
	end
end

local function SheenDistance(self)
	local width = self:GetWidth()
	if type(width) ~= "number" or Widgets.IsSecret(width) then
		width = self.opts.width or Tokens.Size("buffBarWidth")
	end
	return width + 2 * Widgets.Snap(self, SHEEN_WIDTH)
end

function Bar:PlaySheen(loop)
	if not self.sheenAnim or Motion.ReducedMotion() then
		return
	end
	self.sheenMove:SetOffset(SheenDistance(self), 0)
	self.sheenAnim:SetLooping(loop and "REPEAT" or "NONE")
	self.sheenAnim:Stop()
	self.sheen:Show()
	self.sheenAnim:Play()
	self.sheenLooping = loop and true or false
end

function Bar:StopSheen()
	if self.sheenAnim then
		self.sheenAnim:Stop()
		self.sheen:Hide()
		self.sheenLooping = false
	end
end

function Bar:Restyle()
	local opts = self.opts
	Widgets.Size(self, opts.width or Tokens.Size("buffBarWidth"), opts.height or Tokens.Size("buffBarHeight"))
	local height = self:GetHeight()
	if type(height) ~= "number" or Widgets.IsSecret(height) then
		height = opts.height or Tokens.Size("buffBarHeight")
	end
	if self.spark then
		if self.vertical then
			local width = self:GetWidth()
			if type(width) ~= "number" or Widgets.IsSecret(width) then
				width = opts.width or Tokens.Size("buffBarHeight")
			end
			Widgets.Size(self.spark, width * SPARK_HEIGHT_SHARE, SPARK_WIDTH)
		else
			Widgets.Size(self.spark, SPARK_WIDTH, height * SPARK_HEIGHT_SHARE)
		end
	end
	if self.sheen then
		self.sheen:ClearAllPoints()
		self.sheen:SetPoint("TOPRIGHT", self.sheenClip, "TOPLEFT")
		self.sheen:SetPoint("BOTTOMRIGHT", self.sheenClip, "BOTTOMLEFT")
		self.sheen:SetWidth(Widgets.Snap(self, SHEEN_WIDTH))
	end
	if self.sheenLooping and Motion.ReducedMotion() then
		self:StopSheen()
	end
	if self.keyline then
		local px = Widgets.Border(self)
		self.keyline:ClearAllPoints()
		self.keyline:SetPoint("TOPLEFT", self, "TOPLEFT", -px, px)
		self.keyline:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", px, -px)
		Widgets.Tint(self.keyline, KEYLINE)
	end
	if self.lit then
		self:PlaceLit()
	end
	if self.borderFrame then
		local outset = Widgets.Border(self) * BORDER_LINES
		self.borderFrame:ClearAllPoints()
		self.borderFrame:SetPoint("TOPLEFT", self, "TOPLEFT", -outset, outset)
		self.borderFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", outset, -outset)
		self.chrome:OnSizeChanged()
	end
	if self.caps then
		self:SizeCaps(height)
		Widgets.LayoutSlice(self.glow, self:GetStatusBarTexture(), 2 * GLOW_REACH, GLOW_REACH, 0, self, 0)
	end
	self:Paint()
	if self.rampOn or self.fillRamped then
		self:ApplyFillRamp()
	end
	self:PlaceInnerEdge()
end

local function CapMask(bar, name)
	local mask = bar:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture(name)), CAP_WRAP, CAP_WRAP)
	return mask
end

local function Pin(mask, side, region)
	mask:ClearAllPoints()
	mask:SetPoint("TOP" .. side, region, "TOP" .. side)
	mask:SetPoint("BOTTOM" .. side, region, "BOTTOM" .. side)
end

local function Masks(texture, a, b, on)
	if on then
		texture:AddMaskTexture(a)
		texture:AddMaskTexture(b)
	else
		texture:RemoveMaskTexture(a)
		texture:RemoveMaskTexture(b)
	end
end

function Bar:SizeCaps(height)
	if type(height) ~= "number" or Widgets.IsSecret(height) or height <= 0 then
		return
	end
	local side = Widgets.Snap(self, height)
	for _, mask in ipairs(self.caps) do
		mask:SetWidth(side)
	end
end

function Bar:PlaceCaps()
	local reverse = self:GetReverseFill()
	reverse = not Widgets.IsSecret(reverse) and reverse == true
	local fill, caps = self:GetStatusBarTexture(), self.caps
	Pin(caps[1], "LEFT", reverse and fill or self)
	Pin(caps[2], "RIGHT", reverse and self or fill)
end

function Bar:ShowPill(on)
	if self.pillOn == on then
		return
	end
	self.pillOn = on
	local caps = self.caps
	Masks(self:GetStatusBarTexture(), caps[1], caps[2], on)
	Masks(self.sheenTop, caps[1], caps[2], on)
	if self.background then
		Masks(self.background, caps[3], caps[4], on)
	end
	self.sheenTop:SetShown(on)
	Widgets.ShowSlice(self.glow, on)
end

local function PillFill(bar)
	local fill = bar:GetStatusBarTexture()
	bar.caps = {
		CapMask(bar, "pillCapLeft"), CapMask(bar, "pillCapRight"), CapMask(bar, "pillCapLeft"), CapMask(bar, "pillCapRight"),
	}
	Pin(bar.caps[3], "LEFT", bar)
	Pin(bar.caps[4], "RIGHT", bar)
	bar:PlaceCaps()
	local sheen = bar:CreateTexture(nil, "ARTWORK", nil, SHEEN_TOP_SUBLEVEL)
	sheen:SetTexture((Tokens.Texture("barSheen")))
	sheen:SetAllPoints(fill)
	bar.sheenTop = sheen
	bar.glow = Widgets.NineSlice(bar, "shadow", "BACKGROUND", 1)
	for _, piece in ipairs(bar.glow) do
		piece:SetAlpha(GLOW_ALPHA)
	end
	bar.pillOn = false
	bar:ShowPill(not bar.vertical)
	local setColor, setReverse, setOrientation = bar.SetStatusBarColor, bar.SetReverseFill, bar.SetOrientation
	bar.SetStatusBarColor = function(self, r, g, b, a)
		setColor(self, r, g, b, a)
		Widgets.ColorSlice(self.glow, r, g, b, a)
	end
	bar.SetReverseFill = function(self, ...)
		setReverse(self, ...)
		self:PlaceCaps()
	end
	bar.SetOrientation = function(self, orientation, ...)
		setOrientation(self, orientation, ...)
		self.vertical = orientation == "VERTICAL"
		self:ShowPill(not self.vertical)
	end
	bar:HookScript("OnSizeChanged", function(self, _, height)
		self:SizeCaps(height)
	end)
end

function Widgets.StatusBar(parent, opts)
	opts = opts or {}
	local bar = CreateFrame("StatusBar", opts.name, parent or Scale.Root())
	for k, fn in pairs(Bar) do
		bar[k] = fn
	end
	bar.opts = opts
	bar.smooth = opts.smooth == true
	bar.colorName = opts.color or "accent"
	bar.colorRGBA = { 0, 0, 0, 0, n = 0 }
	bar.ownColor = false
	Tokens.Color(bar.colorName)
	local orientation = opts.orientation or "HORIZONTAL"
	bar.vertical = orientation == "VERTICAL"
	bar:SetOrientation(orientation)
	if opts.reverse then
		bar:SetReverseFill(true)
	end
	if opts.background ~= false then
		bar.backgroundName = type(opts.background) == "string" and opts.background or "track"
		bar.background = bar:CreateTexture(nil, "BACKGROUND")
		bar.background:SetAllPoints(bar)
		if not opts.border then
			bar.keyline = Widgets.Crisp(bar:CreateTexture(nil, "BACKGROUND", nil, KEYLINE_SUBLEVEL))
			bar.keyline:SetColorTexture(Tokens.Color("white"))
			bar.lit = Widgets.Crisp(bar:CreateTexture(nil, "ARTWORK", nil, LIT_SUBLEVEL))
			bar.lit:SetColorTexture(Tokens.Color("white"))
			bar.shade = bar:CreateTexture(nil, "ARTWORK", nil, SHADE_SUBLEVEL)
			bar.shade:SetColorTexture(Tokens.Color("white"))
			Shade(bar.shade)
		end
	end
	bar:SetBarTexture(opts.texture)
	if opts.border then
		local frame = CreateFrame("Frame", nil, bar)
		frame:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
		bar.borderFrame = frame
		bar.chrome = Widgets.Chrome(frame, { shape = "bar", fill = "surface", shadow = false, edge = opts.edge or "edgeBar" })
		PillFill(bar)
	end
	if opts.spark then
		local spark = bar:CreateTexture(nil, "OVERLAY")
		spark:SetTexture((Tokens.Texture("glow")))
		spark:SetBlendMode("ADD")
		local edges = SPARK_EDGE[orientation] or SPARK_EDGE.HORIZONTAL
		spark:SetPoint("CENTER", bar:GetStatusBarTexture(), opts.reverse and edges.reverse or edges.normal)
		bar.spark = spark
	end
	if opts.sheen then
		local clip = CreateFrame("Frame", nil, bar)
		clip:SetAllPoints(bar)
		clip:SetClipsChildren(true)
		local sheen = clip:CreateTexture(nil, "OVERLAY")
		sheen:SetTexture((Tokens.Texture("glow")))
		sheen:SetBlendMode("ADD")
		sheen:Hide()
		local anim = sheen:CreateAnimationGroup()
		local move = anim:CreateAnimation("Translation")
		move:SetDuration(Tokens.Duration("castSheen"))
		move:SetSmoothing("IN_OUT")
		anim:SetScript("OnFinished", function()
			sheen:Hide()
		end)
		bar.sheenClip, bar.sheen, bar.sheenAnim, bar.sheenMove = clip, sheen, anim, move
	end
	if type(opts.min) ~= "nil" and type(opts.max) ~= "nil" then
		bar:SetBarRange(opts.min, opts.max)
	end
	if type(opts.value) ~= "nil" then
		bar:SetBarValue(opts.value)
	end
	bar:Restyle()
	return Widgets.Track(bar)
end
