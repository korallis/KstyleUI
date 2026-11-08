-- StatusBar.lua: the status bar, with a texture, a background, an optional spark and sheen, and values that only reach the engine's setters.
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

local SPARK_EDGE = {
	HORIZONTAL = { normal = "RIGHT", reverse = "LEFT" },
	VERTICAL = { normal = "TOP", reverse = "BOTTOM" },
}

local COLOR_CHANNELS = 4

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
end

function Bar:SetBarColor(...)
	local c = self.colorRGBA
	c.n = min(select("#", ...), COLOR_CHANNELS)
	c[1], c[2], c[3], c[4] = ...
	self.ownColor = true
	self:Paint()
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
	if self.borderFrame then
		local outset = Widgets.Border(self) * BORDER_LINES
		self.borderFrame:ClearAllPoints()
		self.borderFrame:SetPoint("TOPLEFT", self, "TOPLEFT", -outset, outset)
		self.borderFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", outset, -outset)
	end
	self:Paint()
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
	end
	bar:SetBarTexture(opts.texture)
	if opts.border then
		local frame = CreateFrame("Frame", nil, bar)
		frame:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
		bar.borderFrame = frame
		bar.chrome = Widgets.Chrome(frame, { shape = "tile", fill = "surface", shadow = false, edge = opts.edge or "edgeBar" })
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
