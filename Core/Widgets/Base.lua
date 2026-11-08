-- Base.lua: the widget kit's shared parts: settings, the restyle registry, text, chrome, motion, Escape, placement and sound.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local Tokens, Scale, Motion, L = ns.Tokens, ns.Scale, ns.Motion, ns.L
local floor, max, min = math.floor, math.max, math.min

local SECTION = "Widgets"
local FALLBACK_FONT = "GameFontHighlight"
local NOISE_ALPHA = 0.035
local PANEL_OPACITY_MIN, PANEL_OPACITY_MAX, PANEL_OPACITY_STEP = 0.5, 1, 0.01
local TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX, TOOLTIP_SCALE_STEP = 0.75, 1.5, 0.05
local SUBLEVEL_SHADOW, SUBLEVEL_BEZEL, SUBLEVEL_FILL, SUBLEVEL_NOISE = -8, -7, -6, -5
local LINE_SUBLEVELS = { outer = -2, inner = -1, fade = -3, plate = -4 }
local BEVEL = { top = 1.4, bottom = 1.1, side = 1, cut = 1.6 }
local FADE = 0.65
local PLATE_ALPHA = 1.25
local LINE_BAND_START, LINE_BAND_SIZE = 0.25, 0.25
local LINE_COLUMN = 0.5
local SQRT2 = math.sqrt(2)

Widgets.TEXTURE_TEXELS = {
	chamferPanel = 128,
	chamferTile = 32,
	chamferWindow = 128,
	shadow = 128,
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

local LINES = {
	{ key = "outer", color = "edgeOuter", borders = 0 },
	{ key = "inner", borders = 1, edge = true },
	{ key = "fade", borders = 2, edge = true, scale = FADE },
}
local ICON_LINES = { LINES[1], LINES[2] }

local SHAPES = {
	panel = { fill = "chamferPanel", chamfer = "chamferPanel", edgeColor = "edgeInner", shadow = true, grain = true },
	tile = { fill = "chamferTile", chamfer = "chamferTile", edgeColor = "edgeInner" },
	window = { fill = "chamferWindow", chamfer = "chamferWindow", edgeColor = "edgeInner", shadow = true, grain = true },
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

local function NewSlice(owner, name, layer, sublevel)
	local path, texels = Tokens.Texture(name)
	local f = texels / TEXELS[name]
	local p = { texture = name }
	for piece = 1, 9 do
		p[piece] = NewTexture(owner, layer, sublevel, path)
		SliceCoords(p[piece], piece, f)
	end
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

local function PlaceCorners(owner, tl, tr, bl, br, size, outset, drop)
	drop = drop or 0
	for _, corner in ipairs({ tl, tr, bl, br }) do
		corner:ClearAllPoints()
		corner:SetSize(size, size)
	end
	tl:SetPoint("TOPLEFT", owner, "TOPLEFT", -outset, outset - drop)
	tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT", outset, outset - drop)
	bl:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -outset, -outset - drop)
	br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", outset, -outset - drop)
end

function Widgets.NineSlice(owner, name, layer, sublevel)
	if not TEXELS[name] then
		error("KstyleUI.Widgets.NineSlice: " .. tostring(name) .. " is not a sliced texture", 2)
	end
	return NewSlice(owner, name, layer or "BACKGROUND", sublevel or 0)
end

function Widgets.LayoutSlice(slice, owner, corner, outset, drop)
	local f = Widgets.ScaleFactor(owner)
	PlaceCorners(owner, slice[1], slice[3], slice[7], slice[9], SnapIn(corner, f), SnapIn(outset or 0, f), SnapIn(drop or 0, f))
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

function Widgets.ColorLine(line, r, g, b, a, factors)
	if not factors then
		Widgets.ColorSlice(line, r, g, b, a)
		return
	end
	local cut = min(1, a * factors.cut)
	for i = 1, 4 do
		line[i]:SetVertexColor(r, g, b, cut)
	end
	line[5]:SetVertexColor(r, g, b, min(1, a * factors.top))
	line[6]:SetVertexColor(r, g, b, min(1, a * factors.bottom))
	local side = min(1, a * factors.side)
	line[7]:SetVertexColor(r, g, b, side)
	line[8]:SetVertexColor(r, g, b, side)
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

function Widgets.Line(owner, layer, sublevel)
	local path = Tokens.Texture("line")
	local parts = {}
	for i = 1, 4 do
		local diagonal = owner:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
		diagonal:SetTexture(path, "CLAMP", "CLAMP")
		parts[i] = diagonal
	end
	for i = 5, 8 do
		parts[i] = NewTexture(owner, layer or "BORDER", sublevel or 0)
	end
	return parts
end

local CORNER_SUMS = { { 0, 1, 1, 2 }, { 1, 2, 0, 1 }, { 1, 0, 2, 1 }, { 2, 1, 1, 0 } }

local function MapDiagonal(texture, sums, square, outerSum, thick)
	local scale = LINE_BAND_SIZE / (thick * SQRT2)
	local function T(k)
		return LINE_BAND_START + (k * square - outerSum) * scale
	end
	texture:SetTexCoord(LINE_COLUMN, T(sums[1]), LINE_COLUMN, T(sums[2]), LINE_COLUMN, T(sums[3]), LINE_COLUMN, T(sums[4]))
end

function Widgets.LayoutLine(line, owner, chamfer, at)
	local f = Widgets.ScaleFactor(owner)
	local thick = Scale.Border() / f
	local outerSum = SnapIn(chamfer, f) - at * (2 - SQRT2)
	local square = SnapIn(outerSum + thick * (SQRT2 - 1), f)
	local tl, tr, bl, br, top, bottom, left, right = line[1], line[2], line[3], line[4], line[5], line[6], line[7], line[8]
	for i = 1, 8 do
		line[i]:ClearAllPoints()
	end
	for i = 1, 4 do
		line[i]:SetSize(square, square)
		MapDiagonal(line[i], CORNER_SUMS[i], square, outerSum, thick)
	end
	tl:SetPoint("TOPLEFT", owner, "TOPLEFT", at, -at)
	tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -at, -at)
	bl:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", at, at)
	br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -at, at)
	local reach = at + square
	top:SetPoint("TOPLEFT", owner, "TOPLEFT", reach, -at)
	top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -reach, -at)
	top:SetHeight(thick)
	bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", reach, at)
	bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -reach, at)
	bottom:SetHeight(thick)
	left:SetPoint("TOPLEFT", owner, "TOPLEFT", at, -reach)
	left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", at, reach)
	left:SetWidth(thick)
	right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -at, -reach)
	right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -at, reach)
	right:SetWidth(thick)
end

local Chrome = {}
Chrome.__index = Chrome

function Widgets.Chrome(owner, opts)
	opts = opts or {}
	local shapeName = opts.shape or "panel"
	local shape = SHAPES[shapeName]
	if not shape then
		error("KstyleUI.Widgets.Chrome: shape must be panel, tile or window, got " .. tostring(shapeName), 2)
	end
	local c = setmetatable({
		owner = owner,
		shape = shape,
		shapeName = shapeName,
		chamfer = opts.chamfer,
		share = opts.share,
		lines = opts.fade == false and ICON_LINES or LINES,
		bevel = opts.bevel or BEVEL,
		bezelUnits = opts.bezel,
		shadowOn = opts.shadow == true or (opts.shadow == nil and shape.shadow == true),
		fillName = opts.fill or "surface",
		edge = { Widgets.Rgba(opts.edge or shape.edgeColor) },
		fillColor = { 0, 0, 0, 0 },
		ownFill = false,
		outerColor = { 0, 0, 0, 0 },
		ownOuter = false,
	}, Chrome)
	c.shadow = NewSlice(owner, "shadow", "BACKGROUND", SUBLEVEL_SHADOW)
	if opts.bezel then
		c.bezel = NewSlice(owner, shape.fill, "BACKGROUND", SUBLEVEL_BEZEL)
	end
	c.fill = NewSlice(owner, shape.fill, "BACKGROUND", SUBLEVEL_FILL)
	if opts.grain ~= false and shape.grain then
		local noise = owner:CreateTexture(nil, "BACKGROUND", nil, SUBLEVEL_NOISE)
		noise:SetTexture((Tokens.Texture("noise")), "REPEAT", "REPEAT")
		noise:SetHorizTile(true)
		noise:SetVertTile(true)
		c.noise = noise
	end
	for _, spec in ipairs(c.lines) do
		c[spec.key] = Widgets.Line(owner, "BORDER", LINE_SUBLEVELS[spec.key])
	end
	if opts.bezel then
		c.plate = Widgets.Line(owner, "BORDER", LINE_SUBLEVELS.plate)
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

function Chrome:Chamfer()
	if self.chamfer then
		return self.chamfer
	end
	local cap = Tokens.Size(self.shape.chamfer)
	local short = ShortSide(self.owner)
	if not short then
		return cap
	end
	if self.share then
		return short * self.share
	end
	return min(cap, short * Tokens.Share("chamfer"))
end

function Chrome:OnSizeChanged()
	if self.chamfer == nil and self:Chamfer() ~= self.laidChamfer then
		self:Restyle()
	end
end

function Chrome:Layout()
	local owner = self.owner
	local f = Widgets.ScaleFactor(owner)
	local chamfer = self:Chamfer()
	self.laidChamfer = chamfer
	Widgets.LayoutSlice(self.fill, owner, chamfer, 0)
	local outset = 0
	if self.bezel then
		outset = SnapIn(self.bezelUnits, f)
		Widgets.LayoutSlice(self.bezel, owner, chamfer + self.bezelUnits * (2 - SQRT2), outset)
		Widgets.LayoutLine(self.plate, owner, chamfer, -outset)
	end
	local reach = Tokens.Size("shadow")
	Widgets.LayoutSlice(self.shadow, owner, 2 * reach, SnapIn(reach, f) + outset, Tokens.Size("shadowOffset"))
	local border = Scale.Border() / f
	for _, spec in ipairs(self.lines) do
		Widgets.LayoutLine(self[spec.key], owner, chamfer, spec.borders * border)
	end
	if self.noise then
		local inset = SnapIn(chamfer, f)
		self.noise:ClearAllPoints()
		self.noise:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
		self.noise:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
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
	if self.bezel then
		Widgets.ColorSlice(self.bezel, Tokens.Color("buttonFill"))
	end
	local shadowShown = self.shadowOn and Widgets.Setting("shadows")
	Widgets.ShowSlice(self.shadow, shadowShown)
	Widgets.ColorSlice(self.shadow, Tokens.Color("shadow"))
	if self.noise then
		self.noise:SetVertexColor(Widgets.Rgba("white", NOISE_ALPHA))
	end
	self:PaintEdge()
	if self.ownOuter then
		local o = self.outerColor
		Widgets.ColorSlice(self.outer, o[1], o[2], o[3], o[4])
	else
		Widgets.ColorSlice(self.outer, Tokens.Color(LINES[1].color))
	end
	if self.plate then
		local pr, pg, pb, pa = Tokens.Color("edgeInner")
		Widgets.ColorLine(self.plate, pr, pg, pb, pa * PLATE_ALPHA, BEVEL)
	end
end

function Chrome:PaintEdge()
	local e = self.edge
	for _, spec in ipairs(self.lines) do
		if spec.edge then
			Widgets.ColorLine(self[spec.key], e[1], e[2], e[3], e[4] * (spec.scale or 1), self.bevel)
		end
	end
end

local function ShapeColor(chrome, key)
	for _, spec in ipairs(chrome.lines) do
		if spec.key == key then
			return Tokens.Color(spec.color)
		end
	end
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

function Chrome:SetOuterRGBA(r, g, b, a)
	local o = self.outerColor
	o[1], o[2], o[3], o[4] = r, g, b, a
	self.ownOuter = true
	Widgets.ColorSlice(self.outer, r, g, b, a)
end

function Chrome:SetOuter(name, alphaScale)
	if name then
		self:SetOuterRGBA(Widgets.Rgba(name, alphaScale))
	else
		self.ownOuter = false
		Widgets.ColorSlice(self.outer, ShapeColor(self, "outer"))
	end
end

function Chrome:SetChamfer(units)
	if self.chamfer ~= units then
		self.chamfer = units
		self:Restyle()
	end
end

function Chrome:SetShadow(on)
	self.shadowOn = on and true or false
	self:Paint()
end

function Chrome:SetShown(shown)
	Widgets.ShowSlice(self.fill, shown)
	if self.bezel then
		Widgets.ShowSlice(self.bezel, shown)
	end
	for _, spec in ipairs(self.lines) do
		Widgets.ShowSlice(self[spec.key], shown)
	end
	if self.plate then
		Widgets.ShowSlice(self.plate, shown)
	end
	if self.noise then
		self.noise:SetShown(shown)
	end
	Widgets.ShowSlice(self.shadow, shown and self.shadowOn and Widgets.Setting("shadows"))
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
