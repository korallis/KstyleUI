-- Base.lua: the widget kit's shared parts: settings, the restyle registry, text, chrome, motion, Escape, placement and sound.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local Tokens, Scale, Motion, L = ns.Tokens, ns.Scale, ns.Motion, ns.L
local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local SECTION = "Widgets"
local FALLBACK_FONT = "GameFontHighlight"
local NOISE_ALPHA = 0.035
local PANEL_OPACITY_MIN, PANEL_OPACITY_MAX, PANEL_OPACITY_STEP = 0.5, 1, 0.01
local TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX, TOOLTIP_SCALE_STEP = 0.75, 1.5, 0.05
local SUBLEVEL_SHADOW, SUBLEVEL_FILL, SUBLEVEL_FROST, SUBLEVEL_NOISE = -8, -7, -6, -5
local SUBLEVEL_RIM, SUBLEVEL_GILT = -2, -1
local INSET_GAP = "gapSmall"
local GRAIN_CLEAR = 1 - math.sqrt(2) / 2
local SMALL_RIM_BELOW = 11
local GILT_OUTSET = 1
local LINE_HEIGHT_SHARE = 1.2
local CHAR_WIDTH_SHARE = 0.5

Widgets.TEXTURE_TEXELS = {
	lumenShape = 128,
	lumenFrost = 128,
	lumenRim = 128,
	lumenRimSmall = 128,
	lumenOutline = 128,
	chamferTile = 128,
	shadow = 128,
	lumenShadow = 128,
}
local TEXELS = Widgets.TEXTURE_TEXELS

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
Widgets.IsSecret = IsSecret

local function Log(message)
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, SECTION, message)
	end
end
Widgets.Log = Log

local logged = {}
function Widgets.LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function IsNumberIn(v, low, high)
	return not IsSecret(v) and type(v) == "number" and v == v and v >= low and v <= high
end

local function IsBoolean(v)
	return type(v) == "boolean"
end

local _, _, _, SURFACE_ALPHA = Tokens.Color("surface")

Widgets.defaults = {
	panelOpacity = SURFACE_ALPHA,
	shadows = true,
	sounds = true,
	tooltipScale = 1,
}

local VALID = {
	panelOpacity = function(v)
		return IsNumberIn(v, PANEL_OPACITY_MIN, PANEL_OPACITY_MAX)
	end,
	shadows = IsBoolean,
	sounds = IsBoolean,
	tooltipScale = function(v)
		return IsNumberIn(v, TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX)
	end,
}

function Widgets.Setting(key)
	local valid = VALID[key]
	if not valid then
		error("KstyleUI.Widgets.Setting: unknown setting " .. tostring(key), 2)
	end
	local Store = ns.Store
	if Store.IsLoaded() then
		local value = Store.Module(SECTION)[key]
		if valid(value) then
			return value
		end
	end
	return Widgets.defaults[key]
end

Widgets.schema = {
	{ type = "header", label = L["Glass"] },
	{
		type = "slider", key = "panelOpacity", label = L["Panel opacity"],
		help = L["How solid the smoked glass behind KstyleUI's panels and windows looks."],
		min = PANEL_OPACITY_MIN, max = PANEL_OPACITY_MAX, step = PANEL_OPACITY_STEP,
	},
	{
		type = "toggle", key = "shadows", label = L["Panel shadows"],
		help = L["Draws a soft shadow around KstyleUI's panels, windows and tooltips."],
	},
	{ type = "header", label = L["Feedback"] },
	{
		type = "toggle", key = "sounds", label = L["Interface sounds"],
		help = L["Plays a soft click when you press KstyleUI's buttons, tabs and switches."],
	},
	{ type = "header", label = L["Tooltips"] },
	{
		type = "slider", key = "tooltipScale", label = L["Tooltip size"],
		help = L["Makes the tooltips on KstyleUI's own controls larger or smaller."],
		min = TOOLTIP_SCALE_MIN, max = TOOLTIP_SCALE_MAX, step = TOOLTIP_SCALE_STEP,
	},
}

ns.Store.RegisterDefaults(SECTION, Widgets.defaults)
ns.Options.Register(SECTION, Widgets.schema)

local tracked = {}

function Widgets.Track(widget)
	tracked[#tracked + 1] = widget
	return widget
end

function Widgets.RestyleAll()
	for i = 1, #tracked do
		local widget = tracked[i]
		ns.Call(widget.Restyle, widget)
	end
end

local REGION_FIELDS = { "owner", "holder", "frame", "bar", "button" }

local function Region(widget)
	if type(widget.GetParent) == "function" then
		return widget
	end
	for i = 1, #REGION_FIELDS do
		local region = widget[REGION_FIELDS[i]]
		if type(region) == "table" and type(region.GetParent) == "function" then
			return region
		end
	end
	return nil
end

local function Under(node, roots)
	while node do
		if roots[node] then
			return true
		end
		node = node:GetParent()
	end
	return false
end

function Widgets.RestyleUnder(roots)
	if next(roots) == nil then
		return
	end
	for i = 1, #tracked do
		local widget = tracked[i]
		local region = Region(widget)
		if region == nil or Under(region, roots) then
			ns.Call(widget.Restyle, widget)
		end
	end
end

function Widgets.Rgba(name, alphaScale)
	local r, g, b, a = Tokens.Color(name)
	return r, g, b, (a or 1) * (alphaScale or 1)
end

function Widgets.Tint(region, name, alphaScale)
	region:SetVertexColor(Widgets.Rgba(name, alphaScale))
end

function Widgets.Mix(r1, g1, b1, a1, r2, g2, b2, a2, t)
	return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, a1 + (a2 - a1) * t
end

function Widgets.MixTokens(nameA, alphaA, nameB, alphaB, t)
	local r1, g1, b1, a1 = Widgets.Rgba(nameA, alphaA)
	local r2, g2, b2, a2 = Widgets.Rgba(nameB, alphaB)
	return Widgets.Mix(r1, g1, b1, a1, r2, g2, b2, a2, t)
end

local textRole = setmetatable({}, { __mode = "k" })

function Widgets.StyleText(text, role)
	role = role or textRole[text] or "body"
	textRole[text] = role
	local path, size, flags = Tokens.Font(role)
	if text:SetFont(path, size, flags) == false then
		text:SetFontObject(FALLBACK_FONT)
		Widgets.LogOnce("font:" .. path, "the font " .. path .. " did not load; text uses " .. FALLBACK_FONT)
	end
	if flags ~= "" then
		text:SetShadowOffset(0, 0)
	else
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	end
end

local baseFont

function Widgets.FontString(parent, layer)
	if not baseFont and type(CreateFont) == "function" and _G[FALLBACK_FONT] then
		baseFont = CreateFont("KstyleUIBaseFont")
		baseFont:CopyFontObject(_G[FALLBACK_FONT])
		baseFont:SetShadowOffset(0, 0)
	end
	local text = parent:CreateFontString(nil, layer or "OVERLAY")
	text:SetFontObject(baseFont or FALLBACK_FONT)
	return text
end

local COVER_FOLLOW_INTERVAL = 0.1
local covers = setmetatable({}, { __mode = "k" })

local function Place(overlay, entry)
	local visual = entry.visual
	local left, bottom, width, height = visual:GetRect()
	if IsSecret(left) or IsSecret(bottom) or IsSecret(width) or IsSecret(height) then
		return false
	end
	if type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return false
	end
	local own, theirs = overlay:GetEffectiveScale(), visual:GetEffectiveScale()
	if IsSecret(own) or IsSecret(theirs) or type(own) ~= "number" or type(theirs) ~= "number" or own <= 0 then
		return false
	end
	local ratio = theirs / own
	local x, y, w, h = left * ratio, bottom * ratio, width * ratio, height * ratio
	if entry.x == x and entry.y == y and entry.w == w and entry.h == h then
		return true
	end
	entry.x, entry.y, entry.w, entry.h = x, y, w, h
	overlay:ClearAllPoints()
	overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	overlay:SetSize(w, h)
	return true
end

local function StopFollowing(overlay)
	local entry = covers[overlay]
	if entry and entry.ticker then
		entry.ticker:Cancel()
		entry.ticker = nil
	end
end

local function Follow(overlay)
	local entry = covers[overlay]
	if not entry or not entry.visual or not overlay:IsShown() then
		StopFollowing(overlay)
		return
	end
	if not InCombatLockdown() then
		Place(overlay, entry)
	end
end

function Widgets.Cover(overlay, visual)
	local entry = covers[overlay]
	if not entry then
		entry = {}
		covers[overlay] = entry
		overlay:HookScript("OnHide", StopFollowing)
	end
	entry.visual = visual
	entry.x, entry.y, entry.w, entry.h = nil, nil, nil, nil
	if not Place(overlay, entry) then
		entry.visual = nil
		return false
	end
	if not entry.ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
		entry.ticker = C_Timer.NewTicker(COVER_FOLLOW_INTERVAL, function()
			Follow(overlay)
		end)
	end
	return true
end

function Widgets.Text(parent, role, colorName, layer)
	local text = Widgets.FontString(parent, layer)
	Widgets.StyleText(text, role or "body")
	text:SetTextColor(Tokens.Color(colorName or "text"))
	return text
end

function Widgets.SetText(text, value)
	if IsSecret(value) then
		text:SetText(value)
		return
	end
	if value == nil then
		text:SetText("")
		return
	end
	local _, upper = Tokens.TextStyle(textRole[text] or "body")
	if upper and type(value) == "string" then
		value = value:upper()
	end
	text:SetText(value)
end

function Widgets.TextColor(text, name, alphaScale)
	text:SetTextColor(Widgets.Rgba(name, alphaScale))
end

function Widgets.TextWidth(text, fallback)
	local width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
	if IsSecret(width) or type(width) ~= "number" then
		return fallback
	end
	return width
end

function Widgets.TextHeight(text, fallback)
	local height = text:GetStringHeight()
	if IsSecret(height) or type(height) ~= "number" or height <= 0 then
		return fallback
	end
	return height
end

function Widgets.LineHeight(text)
	local _, size = text:GetFont()
	if IsSecret(size) or type(size) ~= "number" or size <= 0 then
		size = Tokens.Size("body")
	end
	return size * LINE_HEIGHT_SHARE, size
end

function Widgets.WrappedHeight(text, width)
	local line, size = Widgets.LineHeight(text)
	local value = text:GetText()
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return 0
	end
	if IsSecret(width) or type(width) ~= "number" or width <= 0 then
		return line
	end
	text:SetWidth(width)
	local height = text:GetStringHeight()
	if not IsSecret(height) and type(height) == "number" and height > 0 then
		return height
	end
	local lines = 0
	for paragraph in (value .. "\n"):gmatch("(.-)\n") do
		lines = lines + max(1, ceil(#paragraph * size * CHAR_WIDTH_SHARE / width))
	end
	return lines * line
end

function Widgets.ScaleFactor(frame)
	local own = frame:GetEffectiveScale()
	local root = Scale.Root():GetEffectiveScale()
	if IsSecret(own) or IsSecret(root) or type(own) ~= "number" or type(root) ~= "number" or own <= 0 or root <= 0 then
		return 1
	end
	return own / root
end

local function SnapIn(units, f)
	return Scale.Snap(units * f) / f
end

function Widgets.Snap(frame, units)
	return SnapIn(units, Widgets.ScaleFactor(frame))
end

function Widgets.Border(frame)
	return Scale.Border() / Widgets.ScaleFactor(frame)
end

function Widgets.Size(frame, width, height)
	local f = Widgets.ScaleFactor(frame)
	frame:SetSize(SnapIn(width, f), SnapIn(height, f))
end

function Widgets.Inset(frame, radius, gap)
	local f = frame and Widgets.ScaleFactor(frame) or 1
	return SnapIn(radius / 2 + Scale.Border() / f + Tokens.Size(gap or INSET_GAP), f)
end

local SHAPES = {
	panel = { radius = "radius", frost = true, grain = true, shadow = true },
	card = { radius = "radius", frost = true, grain = true, shadow = true },
	window = { radius = "radius", frost = true, grain = true, shadow = true, gilt = true },
	rail = { radius = "radius", frost = true, grain = true, shadow = true, gilt = true },
	tile = { radius = "radiusTile", fill = "buttonFill" },
	socket = { radius = "radiusTile", fill = "buttonFill" },
	bar = { pill = true },
}

Widgets.RING_INSET = 8 / 128

local function SliceCoords(texture, piece, f)
	local col, row = (piece - 1) % 3, floor((piece - 1) / 3)
	local x0 = (col == 0 and 0) or (col == 1 and f) or (1 - f)
	local x1 = (col == 0 and f) or (col == 1 and 1 - f) or 1
	local y0 = (row == 0 and 0) or (row == 1 and f) or (1 - f)
	local y1 = (row == 0 and f) or (row == 1 and 1 - f) or 1
	texture:SetTexCoord(x0, x1, y0, y1)
end

local function NewTexture(owner, layer, sublevel, path)
	local texture = owner:CreateTexture(nil, layer, nil, sublevel)
	if path then
		texture:SetTexture(path)
	else
		texture:SetColorTexture(Tokens.Color("white"))
	end
	return texture
end

local function PaintSlice(p, name)
	local path, texels = Tokens.Texture(name)
	local f = texels / TEXELS[name]
	p.texture = name
	for piece = 1, 9 do
		p[piece]:SetTexture(path)
		SliceCoords(p[piece], piece, f)
	end
end

local function NewSlice(owner, name, layer, sublevel)
	local p = {}
	for piece = 1, 9 do
		p[piece] = owner:CreateTexture(nil, layer, nil, sublevel)
	end
	PaintSlice(p, name)
	p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
	p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
	p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
	p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
	p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT")
	p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
	p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT")
	p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
	p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT")
	p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
	return p
end

local function PlaceCorners(owner, tl, tr, bl, br, size, outset, drop, outsetX)
	drop = drop or 0
	outsetX = outsetX or outset
	for _, corner in ipairs({ tl, tr, bl, br }) do
		corner:ClearAllPoints()
		corner:SetSize(size, size)
	end
	tl:SetPoint("TOPLEFT", owner, "TOPLEFT", -outsetX, outset - drop)
	tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT", outsetX, outset - drop)
	bl:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -outsetX, -outset - drop)
	br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", outsetX, -outset - drop)
end

function Widgets.NineSlice(owner, name, layer, sublevel)
	if not TEXELS[name] then
		error("KstyleUI.Widgets.NineSlice: " .. tostring(name) .. " is not a sliced texture", 2)
	end
	return NewSlice(owner, name, layer or "BACKGROUND", sublevel or 0)
end

function Widgets.LayoutSlice(slice, owner, corner, outset, drop, scaleFrame, outsetX)
	local f = Widgets.ScaleFactor(scaleFrame or owner)
	local across = outsetX and SnapIn(outsetX, f)
	PlaceCorners(owner, slice[1], slice[3], slice[7], slice[9], SnapIn(corner, f), SnapIn(outset or 0, f), SnapIn(drop or 0, f), across)
end

function Widgets.ColorSlice(slice, r, g, b, a)
	for i = 1, #slice do
		slice[i]:SetVertexColor(r, g, b, a)
	end
end

function Widgets.ShowSlice(slice, shown)
	for i = 1, #slice do
		slice[i]:SetShown(shown)
	end
end

local PILL_CAP = 0.25

function Widgets.Pill(box, layer, sublevel)
	local path = Tokens.Texture("pill")
	local left = NewTexture(box, layer or "ARTWORK", sublevel or 0, path)
	local middle = NewTexture(box, layer or "ARTWORK", sublevel or 0, path)
	local right = NewTexture(box, layer or "ARTWORK", sublevel or 0, path)
	left:SetTexCoord(0, PILL_CAP, 0, 1)
	middle:SetTexCoord(PILL_CAP, 1 - PILL_CAP, 0, 1)
	right:SetTexCoord(1 - PILL_CAP, 1, 0, 1)
	left:SetPoint("TOPLEFT", box, "TOPLEFT")
	left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
	right:SetPoint("TOPRIGHT", box, "TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	return { left, middle, right }
end

function Widgets.LayoutPill(pill, height)
	local cap = height / 2
	pill[1]:SetWidth(cap)
	pill[3]:SetWidth(cap)
end

local Chrome = {}
Chrome.__index = Chrome

local function NewGilt(owner)
	local path = Tokens.Texture("gilt")
	local tl = NewTexture(owner, "BORDER", SUBLEVEL_GILT, path)
	local br = NewTexture(owner, "BORDER", SUBLEVEL_GILT, path)
	br:SetTexCoord(1, 0, 1, 0)
	return { tl, br }
end

function Widgets.Chrome(owner, opts)
	opts = opts or {}
	local shapeName = opts.shape or "panel"
	local shape = SHAPES[shapeName]
	if not shape then
		error("KstyleUI.Widgets.Chrome: shape must be panel, card, window, rail, tile, socket or bar, got " .. tostring(shapeName), 2)
	end
	local c = setmetatable({
		owner = owner,
		shape = shape,
		shapeName = shapeName,
		radius = opts.radius or opts.chamfer,
		share = opts.share,
		shadowOn = opts.shadow == true or (opts.shadow == nil and shape.shadow == true),
		fillName = opts.fill or shape.fill or "surface",
		edge = { Widgets.Rgba(opts.edge or (shape.pill and "edgeBar") or "edgeInner") },
		fillColor = { 0, 0, 0, 0 },
		ownFill = false,
		proc = false,
	}, Chrome)
	if shape.pill then
		c.fill = NewSlice(owner, "lumenShape", "BACKGROUND", SUBLEVEL_FILL)
		c.rim = NewSlice(owner, "lumenOutline", "BORDER", SUBLEVEL_RIM)
	else
		c.shadow = NewSlice(owner, "lumenShadow", "BACKGROUND", SUBLEVEL_SHADOW)
		c.fill = NewSlice(owner, "lumenShape", "BACKGROUND", SUBLEVEL_FILL)
		if shape.frost then
			c.frost = NewSlice(owner, "lumenFrost", "BACKGROUND", SUBLEVEL_FROST)
		end
		if opts.grain ~= false and shape.grain then
			local noise = owner:CreateTexture(nil, "BACKGROUND", nil, SUBLEVEL_NOISE)
			noise:SetTexture((Tokens.Texture("noise")), "REPEAT", "REPEAT")
			noise:SetHorizTile(true)
			noise:SetVertTile(true)
			c.noise = noise
		end
		c.rim = NewSlice(owner, "lumenRim", "BORDER", SUBLEVEL_RIM)
		if shape.gilt and opts.gilt ~= false then
			c.gilt = NewGilt(owner)
		end
	end
	if type(owner.HookScript) == "function" then
		owner:HookScript("OnSizeChanged", function()
			c:OnSizeChanged()
		end)
	end
	c:Restyle()
	return Widgets.Track(c)
end

local function ShortSide(owner)
	local w, h = owner:GetWidth(), owner:GetHeight()
	if IsSecret(w) or IsSecret(h) or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
		return nil
	end
	return min(w, h)
end

function Chrome:Radius()
	local short = ShortSide(self.owner)
	if self.shape.pill then
		return short and short / 2 or Tokens.Size("radiusTile")
	end
	if self.radius then
		return short and min(self.radius, short / 2) or self.radius
	end
	local cap = Tokens.Size(self.shape.radius)
	if not short then
		return cap
	end
	if self.share then
		return min(short / 2, short * self.share)
	end
	return min(cap, short / 2)
end
Chrome.Chamfer = Chrome.Radius

function Chrome:Inset(gap)
	return Widgets.Inset(self.owner, self:Radius(), gap)
end

function Widgets.WindowInset(frame)
	return Widgets.Inset(frame, Tokens.Size("radius"), "gapMedium")
end

function Chrome:OnSizeChanged()
	if self:Radius() ~= self.laidRadius then
		self:Restyle()
	end
end

function Chrome:LayoutPill()
	local radius = self:Radius()
	self.laidRadius = radius
	Widgets.LayoutSlice(self.fill, self.owner, radius, 0)
	Widgets.LayoutSlice(self.rim, self.owner, radius, 0)
end

function Chrome:Layout()
	if self.shape.pill then
		self:LayoutPill()
		return
	end
	local owner = self.owner
	local f = Widgets.ScaleFactor(owner)
	local radius = self:Radius()
	self.laidRadius = radius
	Widgets.LayoutSlice(self.fill, owner, radius, 0)
	if self.frost then
		Widgets.LayoutSlice(self.frost, owner, radius, 0)
	end
	self:PickRim()
	Widgets.LayoutSlice(self.rim, owner, radius, 0)
	local reach = Tokens.Size("shadow")
	Widgets.LayoutSlice(self.shadow, owner, 2 * reach, SnapIn(reach, f))
	if self.noise then
		local inset = SnapIn(radius * GRAIN_CLEAR, f)
		self.noise:ClearAllPoints()
		self.noise:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
		self.noise:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
	end
	if self.gilt then
		local size = SnapIn(Tokens.Size("gilt") * radius / Tokens.Size("radius"), f)
		local outset = SnapIn(GILT_OUTSET, f)
		local tl, br = self.gilt[1], self.gilt[2]
		tl:ClearAllPoints()
		br:ClearAllPoints()
		tl:SetSize(size, size)
		br:SetSize(size, size)
		tl:SetPoint("TOPLEFT", owner, "TOPLEFT", -outset, outset)
		br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", outset, -outset)
	end
end

function Chrome:Paint()
	local r, g, b, a
	if self.ownFill then
		local c = self.fillColor
		r, g, b, a = c[1], c[2], c[3], c[4]
	else
		r, g, b, a = Tokens.Color(self.fillName)
		if self.fillName == "surface" then
			a = Widgets.Setting("panelOpacity")
		end
	end
	Widgets.ColorSlice(self.fill, r, g, b, a)
	if self.frost then
		Widgets.ColorSlice(self.frost, Tokens.Color("glass"))
	end
	if self.shadow then
		Widgets.ShowSlice(self.shadow, self.shadowOn and Widgets.Setting("shadows"))
		Widgets.ColorSlice(self.shadow, Tokens.Color("shadow"))
	end
	if self.noise then
		self.noise:SetVertexColor(Widgets.Rgba("white", NOISE_ALPHA))
	end
	if self.gilt then
		Widgets.ColorSlice(self.gilt, Tokens.Color("gilt"))
	end
	self:PaintEdge()
end

function Chrome:PaintEdge()
	if self.proc then
		Widgets.ColorSlice(self.rim, Tokens.Color("giltLit"))
		return
	end
	local e = self.edge
	Widgets.ColorSlice(self.rim, e[1], e[2], e[3], e[4])
end

function Chrome:Restyle()
	if Widgets.MayMove(self.owner) then
		self:Layout()
	elseif not self.layoutQueued then
		self.layoutQueued = true
		ns.Combat.Queue(function()
			self.layoutQueued = false
			self:Layout()
		end)
	end
	self:Paint()
end

local function StoreFill(chrome, r, g, b, a)
	local c = chrome.fillColor
	c[1], c[2], c[3], c[4] = r, g, b, a
	chrome.ownFill = true
end

function Chrome:SetFill(name, alphaScale)
	self.fillName = name
	if alphaScale then
		StoreFill(self, Widgets.Rgba(name, alphaScale))
	else
		self.ownFill = false
	end
	self:Paint()
end

function Chrome:SetFillRGBA(r, g, b, a)
	StoreFill(self, r, g, b, a)
	self:Paint()
end

function Chrome:SetEdge(name, alphaScale)
	self:SetEdgeRGBA(Widgets.Rgba(name, alphaScale))
end

function Chrome:SetEdgeRGBA(r, g, b, a)
	local e = self.edge
	e[1], e[2], e[3], e[4] = r, g, b, a
	self:PaintEdge()
end

function Chrome:PickRim()
	local name = "lumenRim"
	if self.proc then
		name = "lumenOutline"
	elseif (self.laidRadius or self:Radius()) < SMALL_RIM_BELOW then
		name = "lumenRimSmall"
	end
	if self.rim.texture ~= name then
		PaintSlice(self.rim, name)
	end
end

function Chrome:SetProc(on)
	on = on and true or false
	if self.proc ~= on then
		self.proc = on
		if not self.shape.pill then
			self:PickRim()
		end
		self:PaintEdge()
	end
end

function Chrome:SetRadius(units)
	if self.radius ~= units then
		self.radius = units
		self:Restyle()
	end
end
Chrome.SetChamfer = Chrome.SetRadius

function Chrome:SetShadow(on)
	self.shadowOn = on and true or false
	self:Paint()
end

function Chrome:SetShown(shown)
	Widgets.ShowSlice(self.fill, shown)
	Widgets.ShowSlice(self.rim, shown)
	if self.frost then
		Widgets.ShowSlice(self.frost, shown)
	end
	if self.gilt then
		Widgets.ShowSlice(self.gilt, shown)
	end
	if self.noise then
		self.noise:SetShown(shown)
	end
	if self.shadow then
		Widgets.ShowSlice(self.shadow, shown and self.shadowOn and Widgets.Setting("shadows"))
	end
end

local function SetHover(widget, t)
	widget.hoverT = t
	widget:Paint()
end

local function SetPress(widget, t)
	widget.pressT = t
	widget:Paint()
end

function Widgets.Hover(widget, on)
	return Motion.Tween(widget, SetHover, widget.hoverT or 0, on and 1 or 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
end

function Widgets.Press(widget, down)
	return Motion.Tween(widget, SetPress, widget.pressT or 0, down and 1 or 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
end

function Widgets.PressOffset(widget)
	return Widgets.Snap(widget, Tokens.Size("pressOffset") * (widget.pressT or 0))
end

function Widgets.MayMove(frame)
	if not InCombatLockdown() then
		return true
	end
	local protected = frame:IsProtected()
	if IsSecret(protected) then
		return false
	end
	return not protected
end

local escapes = setmetatable({}, { __mode = "k" })
local watchingCombat = false

local function PassKeys(frame)
	if not InCombatLockdown() then
		frame:SetPropagateKeyboardInput(true)
	end
end

local function OnKeyDown(frame, key)
	if key == "ESCAPE" then
		if not InCombatLockdown() then
			frame:SetPropagateKeyboardInput(false)
		end
		local fn = escapes[frame]
		if fn then
			ns.Call(fn, frame)
		end
	else
		PassKeys(frame)
	end
end

local function WatchCombat()
	if watchingCombat then
		return
	end
	watchingCombat = true
	ns.Events.Register("Widgets.Escape", "PLAYER_REGEN_DISABLED", function()
		for frame in pairs(escapes) do
			PassKeys(frame)
		end
	end)
end

function Widgets.EscapeCloses(frame, fn)
	local first = escapes[frame] == nil
	escapes[frame] = fn
	if not first then
		return
	end
	frame:HookScript("OnKeyDown", OnKeyDown)
	frame:HookScript("OnHide", PassKeys)
	local function take()
		frame:SetPropagateKeyboardInput(true)
		frame:EnableKeyboard(true)
	end
	if InCombatLockdown() then
		ns.Combat.Queue(take)
	else
		take()
	end
	WatchCombat()
end

function Widgets.Place(frame, key, position, opts)
	local root = Scale.Root()
	frame:ClearAllPoints()
	frame:SetPoint(position.anchor, root, position.anchor, position.x or 0, position.y or 0)
	local Layout = ns.Layout
	if Layout and type(Layout.Register) == "function" then
		ns.Call(Layout.Register, frame, key, position, opts)
	else
		Log("Layout.Register is missing; " .. tostring(key) .. " keeps its default position")
	end
end

function Widgets.Sound(kit)
	if not Widgets.Setting("sounds") then
		return
	end
	local play, kits = PlaySound, SOUNDKIT
	if type(play) ~= "function" or type(kits) ~= "table" then
		return
	end
	local id = kits[kit]
	if id then
		pcall(play, id)
	end
end

local function RestyleTexts()
	for text in pairs(textRole) do
		Widgets.StyleText(text)
	end
end

ns.Callbacks.Register("ThemeChanged", SECTION, function()
	RestyleTexts()
	Widgets.RestyleAll()
end)
ns.Callbacks.Register("ScaleChanged", SECTION, Widgets.RestyleAll)
ns.Callbacks.Register("ProfileChanged", SECTION, Widgets.RestyleAll)
ns.Callbacks.Register("SettingChanged", SECTION, function(_, module, key)
	if module == SECTION or (module == "Appearance" and key == "motion") then
		Widgets.RestyleAll()
	end
end)

function Widgets.Clamp(v, low, high)
	return min(high, max(low, v))
end
