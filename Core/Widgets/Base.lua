-- Base.lua: the widget kit's shared parts: settings, the restyle registry, text, chrome, motion, Escape, placement and sound.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local Tokens, Scale, Motion, L = ns.Tokens, ns.Scale, ns.Motion, ns.L
local abs, ceil, floor, log, max, min = math.abs, math.ceil, math.floor, math.log, math.max, math.min

local SECTION = "Widgets"
local DEFAULT_CARD_MATERIAL = "ForgedBrackets"
local FALLBACK_FONT = "GameFontHighlight"
local PANEL_OPACITY_MIN, PANEL_OPACITY_MAX, PANEL_OPACITY_STEP = 0.5, 1, 0.01
local TOOLTIP_SCALE_MIN, TOOLTIP_SCALE_MAX, TOOLTIP_SCALE_STEP = 0.75, 1.5, 0.05
local SUBLEVEL_SHADOW, SUBLEVEL_FILL = -8, -7
local SUBLEVEL_LINE, SUBLEVEL_RIM, SUBLEVEL_GILT = -3, -2, -1
local RINGS = { 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32 }
local INSET_GAP = "gapSmall"
local BORDER_UNITS = 1
local LINE_HEIGHT_SHARE = 1.2
local CHAR_WIDTH_SHARE = 0.5

Widgets.TEXTURE_TEXELS = {
	forgedFrame1 = 32,
	forgedFrame2 = 64,
	forgedFrame3 = 128,
	lumenShape = 128,
	cardShape = 128,
	lumenOutline = 128,
	ringLine2 = 128,
	ringLine3 = 128,
	ringLine4 = 128,
	ringLine5 = 128,
	ringLine6 = 128,
	ringLine8 = 128,
	ringLine10 = 128,
	ringLine12 = 128,
	ringLine16 = 128,
	ringLine20 = 128,
	ringLine24 = 128,
	ringLine32 = 128,
	chamferTile = 128,
	shadow = 128,
	lumenShadow = 128,
}
local TEXELS = Widgets.TEXTURE_TEXELS

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
Widgets.IsSecret = IsSecret

function Widgets.Restricted(region)
	if type(region.IsAnchoringRestricted) ~= "function" then
		return false
	end
	local restricted = region:IsAnchoringRestricted()
	return IsSecret(restricted) or restricted == true
end

function Widgets.Edges(region)
	if Widgets.Restricted(region) then
		return false, false, false, false
	end
	return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
end

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
	cardMaterial = DEFAULT_CARD_MATERIAL,
	ornaments = "Full",
	panelOpacity = SURFACE_ALPHA,
	shadows = false,
	sounds = true,
	tooltipScale = 1,
}

local VALID = {
	ornaments = function(v)
		return not IsSecret(v) and (v == "Off" or v == "Subtle" or v == "Full")
	end,
	cardMaterial = function(v)
		return not IsSecret(v) and type(v) == "string" and Tokens.Material(v) ~= nil
	end,
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
	{ type = "header", label = L["Ornaments"] },
	{ type = "segmented", key = "ornaments", label = L["Ornaments"], help = L["Adds forged trim without changing the HUD layout or its colours."], options = { { value = "Off", label = L["Off"] }, { value = "Subtle", label = L["Subtle"] }, { value = "Full", label = L["Full"] } } },
	{ type = "header", label = L["Card material"] },
	{
		type = "dropdown", key = "cardMaterial", label = L["Material"],
		help = L["Choose the surface of KstyleUI's cards and windows. Glass keeps the original smoked glass."],
		options = {
			{ value = "Glass", label = L["Glass"] },
			{ value = "Flat", label = L["Flat"] },
			{ value = "Slate", label = L["Slate"] },
			{ value = "ForgedTicks", label = L["Forged iron, gilt ticks"] },
			{ value = "ForgedBrackets", label = L["Forged iron, brackets"] },
		},
	},
	{ type = "header", label = L["Panel appearance"] },
	{
		type = "slider", key = "panelOpacity", label = L["Panel opacity"],
		help = L["How solid the selected material looks. Glass keeps the original smoked-glass opacity."],
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
Widgets.Cards = setmetatable({}, { __mode = "k" })

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

function Widgets.RestyleUnder(roots, only)
	if next(roots) == nil then
		return
	end
	for i = 1, #tracked do
		local widget = tracked[i]
		local region = Region(widget)
		if (region == nil or Under(region, roots)) and (only == nil or only(widget)) then
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
Widgets.CapsSized = setmetatable({}, { __mode = "k" })

local function TextFrame(text)
	if type(text.GetEffectiveScale) == "function" then
		return text
	end
	return nil
end

local function TextFactor(text)
	local frame = TextFrame(text)
	return frame and Widgets.ScaleFactor(frame) or 1
end

local function SnapSize(size, f)
	local px = Scale.Pixel(1) / f
	return max(px, floor(size / px + 0.5) * px)
end

local function Shadow(text, flags, f)
	local face = Tokens.FaceShadow((text:GetFont()))
	if flags ~= "" or face == false then
		text:SetShadowOffset(0, 0)
		return
	end
	local offset = Scale.Border() / f
	local r, g, b, a = Tokens.Color("textShadow")
	if face == true then
		text:SetShadowColor(r, g, b, a)
		text:SetShadowOffset(offset, -offset)
		return
	end
	text:SetShadowColor(r, g, b, face.alpha)
	text:SetShadowOffset(face.x * offset, -face.y * offset)
end

function Widgets.FontSize(text, size)
	return SnapSize(size, TextFactor(text))
end

function Widgets.TextShadow(text, flags)
	Shadow(text, flags or "", TextFactor(text))
end

local trackers = setmetatable({}, { __mode = "k" })

local function Side(point)
	if point:find("LEFT", 1, true) then
		return "LEFT"
	end
	if point:find("RIGHT", 1, true) then
		return "RIGHT"
	end
	return "CENTER"
end

local function TrackShift(text, state)
	local first = state.points[1]
	if state.pad == 0 or not first then
		return 0
	end
	local left, right = false, false
	for _, p in ipairs(state.points) do
		local side = Side(p.point)
		left, right = left or side == "LEFT", right or side == "RIGHT"
	end
	local side = (state.width or (left and right)) and state.justify or Side(first.point)
	local shift = (side == "RIGHT" and state.pad) or (side == "CENTER" and state.pad / 2) or 0
	local f = TextFactor(text)
	return Scale.Snap(shift * f) / f
end

local function Anchor(text, state, p, shift)
	if not p.rel then
		state.native.SetPoint(text, p.point, p.x + shift, p.y)
	elseif not p.relPoint then
		state.native.SetPoint(text, p.point, p.rel, p.x + shift, p.y)
	else
		state.native.SetPoint(text, p.point, p.rel, p.relPoint, p.x + shift, p.y)
	end
end

local function Refresh(text, state)
	local shift = TrackShift(text, state)
	if shift == state.shift then
		return false
	end
	state.shift = shift
	state.native.ClearAllPoints(text)
	for _, p in ipairs(state.points) do
		Anchor(text, state, p, shift)
	end
	return true
end

local function Tracker(text)
	local state = trackers[text]
	if state then
		return state
	end
	local native = {
		SetPoint = text.SetPoint,
		GetPoint = text.GetPoint,
		ClearAllPoints = text.ClearAllPoints,
		SetJustifyH = text.SetJustifyH,
		SetWidth = text.SetWidth,
		SetSize = text.SetSize,
	}
	state = { pad = 0, shift = 0, justify = "CENTER", points = {}, spare = {}, native = native }
	trackers[text] = state
	for i = 1, text:GetNumPoints() do
		local point, rel, relPoint, x, y = native.GetPoint(text, i)
		state.points[i] = { point = point, rel = rel or false, relPoint = relPoint or false, x = x, y = y }
	end
	function text.SetPoint(self, point, a, b, c, d)
		local points = state.points
		local at = #points + 1
		for i, existing in ipairs(points) do
			if existing.point == point then
				at = i
			end
		end
		local p = points[at]
		if not p then
			local spare = state.spare
			p = spare[#spare]
			if p then
				spare[#spare] = nil
			else
				p = { point = false, rel = false, relPoint = false, x = 0, y = 0 }
			end
			points[at] = p
		end
		p.point, p.rel, p.relPoint, p.x, p.y = point, false, false, 0, 0
		if type(a) == "number" then
			p.x, p.y = a, b or 0
		elseif type(b) == "number" then
			p.rel, p.x, p.y = a, b, c or 0
		else
			p.rel, p.relPoint, p.x, p.y = a or false, b or false, c or 0, d or 0
		end
		if not Refresh(self, state) then
			Anchor(self, state, p, state.shift)
		end
	end
	function text.GetPoint(self, i)
		local p = state.points[i or 1]
		if not p then
			return nil
		end
		local _, rel, relPoint = native.GetPoint(self, i or 1)
		return p.point, rel, relPoint, p.x, p.y
	end
	function text.ClearAllPoints(self)
		local points, spare = state.points, state.spare
		for i = #points, 1, -1 do
			spare[#spare + 1] = points[i]
			points[i] = nil
		end
		state.shift = 0
		native.ClearAllPoints(self)
	end
	function text.SetJustifyH(self, justify)
		state.justify = justify
		native.SetJustifyH(self, justify)
		Refresh(self, state)
	end
	function text.SetWidth(self, width)
		state.width = type(width) == "number" and width > 0
		native.SetWidth(self, width)
		Refresh(self, state)
	end
	function text.SetSize(self, width, height)
		state.width = type(width) == "number" and width > 0
		native.SetSize(self, width, height)
		Refresh(self, state)
	end
	return state
end

function Widgets.TrackPad(text)
	local state = trackers[text]
	return state and state.pad or 0
end

function Widgets.SyncTracking(text)
	local path, size = text:GetFont()
	local tracking = type(path) == "string" and type(size) == "number" and Tokens.FaceTracking(path) or 0
	if tracking ~= 0 or trackers[text] then
		local state = Tracker(text)
		state.pad = tracking * (type(size) == "number" and size or 0)
		Refresh(text, state)
	end
end

function Widgets.ApplyFont(text, path, size, flags, plain)
	flags = flags or ""
	local f = TextFactor(text)
	local ok = text:SetFont(path, SnapSize(size, f), flags) ~= false
	Shadow(text, flags, f)
	if not plain then
		Widgets.SyncTracking(text)
	end
	Widgets.Refollow(text)
	return ok
end

function Widgets.StyleText(text, role)
	role = role or textRole[text] or "body"
	textRole[text] = role
	if role == "caps" and Widgets.CapsSized[text] ~= nil then
		return Widgets.CapsSize(text, Widgets.CapsSized[text])
	end
	local path, size, flags = Tokens.Font(role)
	if not Widgets.ApplyFont(text, path, size, flags) then
		text:SetFontObject(FALLBACK_FONT)
		Widgets.TextShadow(text, flags)
		Widgets.LogOnce("font:" .. path, "the font " .. path .. " did not load; text uses " .. FALLBACK_FONT)
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
	if Widgets.Restricted(visual) then
		return false
	end
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
		value = ns.Locale.Upper(value)
	end
	text:SetText(value)
	Widgets.Refollow(text)
end

function Widgets.TextColor(text, name, alphaScale)
	text:SetTextColor(Widgets.Rgba(name, alphaScale))
end

function Widgets.TextWidth(text, fallback)
	local width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()
	if IsSecret(width) or type(width) ~= "number" then
		return fallback
	end
	return width - Widgets.TrackPad(text)
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

function Widgets.DotGap(fontSize, pixel, em)
	if IsSecret(fontSize) or type(fontSize) ~= "number" or fontSize ~= fontSize or fontSize <= 0 then
		fontSize = 0
	end
	if IsSecret(pixel) or type(pixel) ~= "number" or pixel ~= pixel or pixel <= 0 then
		pixel = 1
	end
	if IsSecret(em) or type(em) ~= "number" or em ~= em or em <= 0 then
		em = 0
	end
	local snapped = math.floor(em * fontSize / pixel + 0.5) * pixel
	if snapped < pixel then
		return pixel
	end
	return snapped
end

function Widgets.Border(frame)
	return Scale.Border() / Widgets.ScaleFactor(frame)
end

local POINT_SHARES = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function PixelsOf(region)
	if Widgets.Restricted(region) then
		return nil
	end
	local w, h = region:GetWidth(), region:GetHeight()
	if IsSecret(w) or IsSecret(h) or type(w) ~= "number" or type(h) ~= "number" or w ~= w or h ~= h then
		return nil
	end
	local px = Scale.Pixel(1) / Widgets.ScaleFactor(region)
	return w / px, h / px
end

function Widgets.Remainder(region)
	local w, h = PixelsOf(region)
	if not w then
		return 0, 0
	end
	return floor(w + 0.5) - w, floor(h + 0.5) - h
end

local function Waits(region, fn, ...)
	if type(region.IsProtected) ~= "function" or Widgets.MayMove(region) then
		return false
	end
	local args = { n = select("#", ...), ... }
	ns.Combat.Queue(function()
		fn(unpack(args, 1, args.n))
	end)
	return true
end

local helped = setmetatable({}, { __mode = "k" })
local dependents = setmetatable({}, { __mode = "k" })

local function OnPixel(raw, relShare, relPx, ownShare, ownPx)
	local target = relShare * (relPx or 0) - (ownShare == 0.5 and ownPx and ownPx / 2 or 0)
	return floor(raw + target + 0.5) - target
end

local function Plain(region)
	if Widgets.Restricted(region) then
		return false
	end
	if type(region.IsAnchoringSecret) == "function" then
		local secret = region:IsAnchoringSecret()
		if IsSecret(secret) or secret == true then
			return false
		end
	end
	return true
end

local function IsFrame(region)
	if type(region.IsObjectType) ~= "function" then
		return false
	end
	local frame = region:IsObjectType("Frame")
	return not IsSecret(frame) and frame == true
end

local function Record(region)
	local record = helped[region]
	if not record then
		record = { points = {} }
		helped[region] = record
	end
	return record
end

local Reown, Refollow
local TEXT_CHANGES = { "SetText", "SetFormattedText", "SetFont", "SetFontObject", "SetWidth" }

local function HookText(text)
	if text.kstyleTextFollowed or type(text.IsObjectType) ~= "function" then
		return
	end
	local isText = text:IsObjectType("FontString")
	if IsSecret(isText) or isText ~= true then
		return
	end
	text.kstyleTextFollowed = true
	for _, method in ipairs(TEXT_CHANGES) do
		hooksecurefunc(text, method, function(self)
			Refollow(self)
		end)
	end
end

local function HookFollow(frame)
	if dependents[frame] and not frame.kstyleFollowed and type(frame.HookScript) == "function" and IsFrame(frame) then
		frame.kstyleFollowed = frame:HookScript("OnSizeChanged", Refollow) ~= false
	end
end

function Widgets.Point(region, point, relativeTo, relativePoint, x, y)
	local relative = relativeTo or region:GetParent()
	relativePoint = relativePoint or point
	local own, rel = POINT_SHARES[point], POINT_SHARES[relativePoint]
	if not (own and rel) then
		error("KstyleUI.Widgets.Point: unknown anchor point " .. tostring(own and relativePoint or point), 2)
	end
	if Waits(region, Widgets.Point, region, point, relativeTo, relativePoint, x, y) then
		return
	end
	local px = Scale.Pixel(1) / Widgets.ScaleFactor(region)
	local ownW, ownH
	local kind = not Widgets.Restricted(region) and region:GetObjectType()
	if kind and not IsSecret(kind) and kind ~= "FontString" then
		ownW, ownH = PixelsOf(region)
	end
	local relW, relH
	if type(relative) == "table" and relative.GetWidth then
		relW, relH = PixelsOf(relative)
	end
	local dx = OnPixel((x or 0) / px, rel[1], relW, own[1], ownW)
	local dy = -OnPixel(-(y or 0) / px, 1 - rel[2], relH, 1 - own[2], ownH)
	region:SetPoint(point, relative, relativePoint, dx * px, dy * px)
	local record = Record(region)
	local entry = record.points[point]
	if entry then
		entry[1], entry[2], entry[3], entry[4], entry[5], entry[6] = relative, relativePoint, x, y, dx * px, dy * px
	else
		record.points[point] = { relative, relativePoint, x, y, dx * px, dy * px }
	end
	if (own[1] ~= 0 or own[2] ~= 1) and not region.kstyleOwnHooked and type(region.HookScript) == "function" and IsFrame(region) then
		region.kstyleOwnHooked = region:HookScript("OnSizeChanged", Reown) ~= false
	end
	if type(relative) == "table" and (rel[1] ~= 0 or rel[2] ~= 1) then
		local set = dependents[relative]
		if not set then
			set = setmetatable({}, { __mode = "k" })
			dependents[relative] = set
		end
		set[region] = true
		if helped[relative] then
			HookFollow(relative)
		end
		HookText(relative)
	end
end

local function Refill(region)
	if region.kstyleFilling then
		return
	end
	region.kstyleFilling = true
	local fill = region.kstyleFill
	ns.Call(Widgets.Fill, region, fill[1], fill[2], fill[3], fill[4], fill[5])
	region.kstyleFilling = false
end

function Widgets.Fill(region, relativeTo, left, top, right, bottom)
	local relative = relativeTo or region:GetParent()
	region.kstyleFill = { relativeTo, left, top, right, bottom }
	if Waits(region, Widgets.Fill, region, relativeTo, left, top, right, bottom) then
		return
	end
	local px = Scale.Pixel(1) / Widgets.ScaleFactor(region)
	local w, h = PixelsOf(relative)
	local l, t = floor((left or 0) / px + 0.5), floor((top or 0) / px + 0.5)
	local r, b = (right or 0) / px, (bottom or 0) / px
	local dx, dy = -floor(r + 0.5), floor(b + 0.5)
	if w then
		dx, dy = floor(w - r + 0.5) - w, h - floor(h - b + 0.5)
	end
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", relative, "TOPLEFT", l * px, -t * px)
	region:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", dx * px, dy * px)
	local record = Record(region)
	local fill = record.fill
	if fill then
		fill[1], fill[2], fill[3], fill[4], fill[5], fill[6], fill[7], fill[8], fill[9] = relative, left, top, right, bottom, l * px, -t * px, dx * px, dy * px
	else
		record.fill = { relative, left, top, right, bottom, l * px, -t * px, dx * px, dy * px }
	end
	if not region.kstyleSettles and type(region.HookScript) == "function" and IsFrame(region) then
		region.kstyleSettles = region:HookScript("OnSizeChanged", Refill) ~= false
	end
	HookFollow(region)
end

local function Anchored(region, point, relative, relativePoint, x, y)
	if not Plain(region) then
		return false
	end
	for i = 1, region:GetNumPoints() do
		local own, to, toPoint, ox, oy = region:GetPoint(i)
		if IsSecret(own) or IsSecret(to) or IsSecret(toPoint) or IsSecret(ox) or IsSecret(oy) then
			return false
		end
		if own == point then
			return to == relative and toPoint == relativePoint and type(ox) == "number" and type(oy) == "number"
				and abs(ox - x) < 1e-6 and abs(oy - y) < 1e-6
		end
	end
	return false
end

local function Depth(region)
	local depth, node = 0, region:GetParent()
	while node do
		depth, node = depth + 1, node:GetParent()
	end
	return depth
end

local function Replay(region, record, only)
	for point, p in pairs(record.points) do
		if (only == nil or p[1] == only) and Anchored(region, point, p[1], p[2], p[5], p[6]) then
			Widgets.Point(region, point, p[1], p[2], p[3], p[4])
		end
	end
end

function Reown(region)
	local record = helped[region]
	if not record or region.kstyleReowning then
		return
	end
	region.kstyleReowning = true
	ns.Call(Replay, region, record)
	region.kstyleReowning = false
end

function Refollow(frame)
	local set = dependents[frame]
	if not set or frame.kstyleFollowing then
		return
	end
	frame.kstyleFollowing = true
	for region in pairs(set) do
		local record = helped[region]
		if record then
			ns.Call(Replay, region, record, frame)
		end
	end
	frame.kstyleFollowing = false
end

Widgets.Refollow = Refollow

function Widgets.PlaceAgain(roots)
	local list, depth = {}, {}
	for region in pairs(helped) do
		if Plain(region) and (roots == nil or Under(region, roots)) then
			list[#list + 1] = region
			depth[region] = Depth(region)
		end
	end
	table.sort(list, function(a, b)
		return depth[a] < depth[b]
	end)
	for _, region in ipairs(list) do
		local record = helped[region]
		local size = record.size
		local w, h = region:GetWidth(), region:GetHeight()
		if size and not IsSecret(w) and not IsSecret(h) and type(w) == "number" and type(h) == "number" and abs(w - size[3]) < 1e-6 and abs(h - size[4]) < 1e-6 then
			Widgets.Size(region, size[1], size[2])
		end
		local fill = record.fill
		if fill and Anchored(region, "TOPLEFT", fill[1], "TOPLEFT", fill[6], fill[7]) and Anchored(region, "BOTTOMRIGHT", fill[1], "BOTTOMRIGHT", fill[8], fill[9]) then
			Widgets.Fill(region, fill[1], fill[2], fill[3], fill[4], fill[5])
		end
		Replay(region, record)
	end
end

function Widgets.Size(frame, width, height)
	if type(frame.IsProtected) == "function" and not Widgets.MayMove(frame) then
		ns.Combat.Queue(function()
			Widgets.Size(frame, width, height)
		end)
		return
	end
	local f = Widgets.ScaleFactor(frame)
	local w, h = SnapIn(width, f), SnapIn(height, f)
	frame:SetSize(w, h)
	Refollow(frame)
	local record = Record(frame)
	local size = record.size
	if size then
		size[1], size[2], size[3], size[4] = width, height, w, h
	else
		record.size = { width, height, w, h }
	end
	HookFollow(frame)
end

function Widgets.Inset(frame, radius, gap)
	local f = frame and Widgets.ScaleFactor(frame) or 1
	return SnapIn(radius / 2 + Scale.Border() / f + Tokens.Size(gap or INSET_GAP), f)
end

function Widgets.InsetUnits(radius, gap)
	return radius / 2 + BORDER_UNITS + Tokens.Size(gap or INSET_GAP)
end

local BRACKET_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local SHAPES = {
	panel = { radius = "radius", lines = 6, card = true, line = "edgeOuter", shadow = true },
	card = { radius = "radius", lines = 6, card = true, line = "edgeOuter", shadow = true },
	window = { radius = "radius", lines = 6, card = true, line = "edgeOuter", shadow = true },
	rail = { radius = "radius", lines = 6, card = true, line = "edgeOuter", shadow = true },
	tile = { radius = "radiusTile", lines = 3, line = "socketEdge", fill = "buttonFill" },
	socket = { radius = "radiusTile", lines = 3, line = "socketEdge", fill = "buttonFill" },
	bar = { pill = true },
}

Widgets.RING_INSET = 8 / 128

function Widgets.Crisp(texture)
	if type(texture.SetSnapToPixelGrid) == "function" then
		texture:SetSnapToPixelGrid(true)
	end
	if type(texture.SetTexelSnappingBias) == "function" then
		texture:SetTexelSnappingBias(0)
	end
	return texture
end

local function Unbiased(texture)
	if type(texture.SetSnapToPixelGrid) == "function" then
		texture:SetSnapToPixelGrid(false)
	end
	if type(texture.SetTexelSnappingBias) == "function" then
		texture:SetTexelSnappingBias(0)
	end
	return texture
end

local SOFT = { lumenShadow = true, shadow = true }
local RUN_PIECES = { 2, 4, 6, 8 }
local RUNS = { lumenOutline = true }
for _, lines in ipairs(RINGS) do
	RUNS["ringLine" .. lines] = true
end

local function SliceCoords(texture, piece, f)
	local col, row = (piece - 1) % 3, floor((piece - 1) / 3)
	local x0 = (col == 0 and 0) or (col == 1 and f) or (1 - f)
	local x1 = (col == 0 and f) or (col == 1 and 1 - f) or 1
	local y0 = (row == 0 and 0) or (row == 1 and f) or (1 - f)
	local y1 = (row == 0 and f) or (row == 1 and 1 - f) or 1
	texture:SetTexCoord(x0, x1, y0, y1)
end

local function CreateTexture(owner, layer, sublevel)
	if type(owner.AttachTexture) == "function" then
		local texture = owner:AttachTexture()
		texture:SetDrawLayer(layer, sublevel)
		return texture
	end
	return owner:CreateTexture(nil, layer, nil, sublevel)
end

local function NewTexture(owner, layer, sublevel, path)
	local texture = Unbiased(CreateTexture(owner, layer, sublevel))
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
	p.runs = RUNS[name] == true
	for piece = 1, 9 do
		if p.runs and piece % 2 == 0 then
			Widgets.Crisp(p[piece])
			p[piece]:SetColorTexture(Tokens.Color("white"))
		else
			p[piece]:SetTexture(path)
			SliceCoords(p[piece], piece, f)
		end
	end
end

local function AnchorRuns(p, thickness)
	thickness = thickness or false
	if p.runThickness == thickness then
		return
	end
	local placed = p.runThickness ~= nil
	p.runThickness = thickness
	local run = p
	if placed then
		for _, piece in ipairs(RUN_PIECES) do
			run[piece]:ClearAllPoints()
		end
	end
	if not thickness then
		run[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
		run[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
		run[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
		run[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
		run[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT")
		run[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
		run[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT")
		run[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
		return
	end
	run[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
	run[2]:SetPoint("BOTTOMRIGHT", p[3], "TOPLEFT", 0, -thickness)
	run[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
	run[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPLEFT", thickness, 0)
	run[6]:SetPoint("TOPLEFT", p[3], "BOTTOMRIGHT", -thickness, 0)
	run[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
	run[8]:SetPoint("TOPLEFT", p[7], "BOTTOMRIGHT", 0, thickness)
	run[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
end

local function NewSlice(owner, name, layer, sublevel)
	local p = {}
	local soft = SOFT[name]
	for piece = 1, 9 do
		local texture = CreateTexture(owner, layer, sublevel)
		p[piece] = soft and texture or Unbiased(texture)
	end
	PaintSlice(p, name)
	if not p.runs then
		AnchorRuns(p, nil)
	end
	p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT")
	p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
	return p
end

local function SizeCorner(corner, size)
	corner:ClearAllPoints()
	corner:SetSize(size, size)
end

local function PlaceCorners(owner, tl, tr, bl, br, size, outset, drop, outsetX, farX, farY)
	drop = drop or 0
	outsetX = outsetX or outset
	farX, farY = farX or 0, farY or 0
	SizeCorner(tl, size)
	SizeCorner(tr, size)
	SizeCorner(bl, size)
	SizeCorner(br, size)
	tl:SetPoint("TOPLEFT", owner, "TOPLEFT", -outsetX, outset - drop)
	tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT", outsetX + farX, outset - drop)
	bl:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -outsetX, -outset - drop - farY)
	br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", outsetX + farX, -outset - drop - farY)
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
	local farX, farY = Widgets.Remainder(owner)
	local px = Scale.Pixel(1) / f
	slice.remainder = farX .. ":" .. farY
	PlaceCorners(owner, slice[1], slice[3], slice[7], slice[9], SnapIn(corner, f), SnapIn(outset or 0, f), SnapIn(drop or 0, f), across, farX * px, farY * px)
	AnchorRuns(slice, slice.runs and Scale.Border() / f or nil)
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
	local cap = Widgets.Snap(pill[1], height / 2)
	pill[1]:SetWidth(cap)
	pill[3]:SetWidth(cap)
	local box = pill[1]:GetParent()
	local farX, farY = Widgets.Remainder(box)
	local px = Scale.Pixel(1) / Widgets.ScaleFactor(box)
	pill[1]:ClearAllPoints()
	pill[1]:SetPoint("TOPLEFT", box, "TOPLEFT")
	pill[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, -farY * px)
	pill[3]:ClearAllPoints()
	pill[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", farX * px, 0)
	pill[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", farX * px, -farY * px)
end

local Chrome = {}
Chrome.__index = Chrome

local function NewTicks(owner)
	local ticks = {}
	for i = 1, 6 do
		ticks[i] = NewTexture(owner, "BORDER", SUBLEVEL_GILT)
		if i % 3 ~= 1 then
			Widgets.Crisp(ticks[i])
		end
	end
	return ticks
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
		materialOn = opts.grain ~= false,
		popup = opts.popup == true,
		shadowOn = opts.shadow == true or (opts.shadow == nil and shape.shadow == true),
		fillName = opts.fill or shape.fill or "surface",
		ownEdge = opts.edge ~= nil and opts.edge ~= "edgeInner",
		edge = { Widgets.Rgba(opts.edge or (shape.pill and "edgeBar") or "edgeInner") },
		fillColor = { 0, 0, 0, 0 },
		ownFill = false,
		proc = false,
		visible = true,
		ticksShown = false,
	}, Chrome)
	if shape.pill then
		c.fill = NewSlice(owner, "lumenShape", "BACKGROUND", SUBLEVEL_FILL)
		c.rim = NewSlice(owner, "lumenOutline", "BORDER", SUBLEVEL_RIM)
	else
		c.shadow = NewSlice(owner, "lumenShadow", "BACKGROUND", SUBLEVEL_SHADOW)
		Widgets.ColorSlice(c.shadow, Tokens.Color("shadow"))
		c.fill = NewSlice(owner, shape.card and "cardShape" or "lumenShape", "BACKGROUND", SUBLEVEL_FILL)
		c.rim = NewSlice(owner, "ringLine" .. shape.lines, "BORDER", SUBLEVEL_RIM)
		c.line = NewSlice(owner, "ringLine" .. shape.lines, "BORDER", SUBLEVEL_LINE)
		if shape.card and opts.gilt ~= false then
			c.gilt = NewTicks(owner)
			Widgets.ColorSlice(c.gilt, Tokens.Color("gilt"))
		end
		if shape.card then
			Widgets.Cards[c] = true
		end
	end
	if opts.ornament == "crest" and Widgets.Ornament and type(owner.AttachTexture) ~= "function" then
		c.ornament = Widgets.Ornament(owner, "crest", nil, true)
		c.ornament.chrome, c.ornament.inside, c.ornament.avoid, c.ornament.span = c, opts.inside, opts.avoid, opts.span
		owner:HookScript("OnHide", function()
			c.ornament.stale = true
		end)
		if type(owner.StopMovingOrSizing) == "function" then
			hooksecurefunc(owner, "StopMovingOrSizing", function()
				c:RestyleOrnament()
			end)
		end
	end
	c:Restyle()
	if type(owner.HookScript) == "function" then
		owner:HookScript("OnSizeChanged", function()
			c:OnSizeChanged()
		end)
	end
	if type(owner.AttachTexture) == "function" then
		return c
	end
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
	local radius
	if self.radius then
		radius = self.radius
	elseif self.share and short then
		radius = short * self.share
	else
		radius = self.shape.lines * Widgets.Border(self.owner)
	end
	return short and min(radius, short / 2) or radius
end
Chrome.Chamfer = Chrome.Radius

function Chrome:PadRadius()
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

function Chrome:Inset(gap)
	return Widgets.Inset(self.owner, self:PadRadius(), gap)
end

function Chrome:InsetUnits(gap)
	return Widgets.InsetUnits(self:PadRadius(), gap)
end

function Widgets.WindowInset(frame)
	return Widgets.Inset(frame, Tokens.Size("radius"), "gapMedium")
end

function Chrome:TicksWanted()
	if not self.gilt or self.radius or self.share then
		return false
	end
	local short = ShortSide(self.owner)
	return short == nil or short >= 2 * Widgets.Snap(self.owner, Tokens.Size("tick"))
end

function Chrome:OnSizeChanged()
	if self.released then
		return
	end
	if self.ornament and not Widgets.MayMove(self.owner) then
		self.ornament:Yield()
	end
	local farX, farY = Widgets.Remainder(self.owner)
	if self:Radius() ~= self.laidRadius or self:TicksWanted() ~= self.ticksShown then
		self:Restyle()
	else
		if self.fill.remainder ~= farX .. ":" .. farY then
			self:Layout()
		end
		self:PaintMaterial()
		self:RestyleOrnament()
	end
end

function Chrome:LayoutPill()
	local radius = self:Radius()
	self.laidRadius = radius
	Widgets.LayoutSlice(self.fill, self.owner, radius, 0)
	Widgets.LayoutSlice(self.rim, self.owner, radius, 0)
end

local function PickRing(slice, corner, line)
	local want, lines = corner / line, RINGS[1]
	for _, n in ipairs(RINGS) do
		if abs(log(n / want)) < abs(log(lines / want)) then
			lines = n
		end
	end
	local name = "ringLine" .. lines
	if slice.texture ~= name then
		PaintSlice(slice, name)
	end
end

function Chrome:LayoutTicks(corner, line, f)
	local ticks, owner = self.gilt, self.owner
	self.ticksShown = self:TicksWanted()
	local path, texels = Tokens.Texture(self.rim.texture)
	local share = texels / TEXELS[self.rim.texture]
	local leg = max(0, SnapIn(Tokens.Size("tick"), f) - line - corner)
	local arcTL, topLeg, leftLeg, arcBR, bottomLeg, rightLeg = ticks[1], ticks[2], ticks[3], ticks[4], ticks[5], ticks[6]
	for i = 1, #ticks do
		ticks[i]:ClearAllPoints()
	end
	arcTL:SetTexture(path)
	SliceCoords(arcTL, 1, share)
	arcBR:SetTexture(path)
	SliceCoords(arcBR, 9, share)
	arcTL:SetSize(corner, corner)
	arcBR:SetSize(corner, corner)
	local farX, farY = Widgets.Remainder(owner)
	local px = Scale.Pixel(1) / f
	arcTL:SetPoint("TOPLEFT", owner, "TOPLEFT", line, -line)
	arcBR:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -line + farX * px, line - farY * px)
	topLeg:SetSize(leg, line)
	topLeg:SetPoint("TOPLEFT", arcTL, "TOPRIGHT")
	leftLeg:SetSize(line, leg)
	leftLeg:SetPoint("TOPLEFT", arcTL, "BOTTOMLEFT")
	bottomLeg:SetSize(leg, line)
	bottomLeg:SetPoint("BOTTOMRIGHT", arcBR, "BOTTOMLEFT")
	rightLeg:SetSize(line, leg)
	rightLeg:SetPoint("BOTTOMRIGHT", arcBR, "TOPRIGHT")
end

function Chrome:Layout()
	if self.shape.pill then
		self:LayoutPill()
		return
	end
	local owner = self.owner
	local f = Widgets.ScaleFactor(owner)
	local line = Scale.Border() / f
	local radius = self:Radius()
	self.laidRadius = radius
	local corner = SnapIn(radius, f)
	local inner = max(line, corner - line)
	PickRing(self.line, corner, line)
	Widgets.LayoutSlice(self.line, owner, corner, 0)
	Widgets.LayoutSlice(self.fill, owner, inner, -line)
	PickRing(self.rim, inner, line)
	Widgets.LayoutSlice(self.rim, owner, inner, -line)
	local reach = Tokens.Size("shadow")
	Widgets.LayoutSlice(self.shadow, owner, 2 * reach, SnapIn(reach, f))
	if self.gilt then
		self:LayoutTicks(inner, line, f)
	end
end

local function ShowOnce(chrome, key, slice, shown)
	shown = shown and true or false
	if chrome[key] ~= shown then
		chrome[key] = shown
		Widgets.ShowSlice(slice, shown)
	end
end

function Chrome:Material()
	if (self.shape.card or self.popup) and self.materialOn and not self.radius and not self.share and self.fillName == "surface" then
		if self.ownFill then
			local r, g, b = Tokens.Color("surface")
			local c = self.fillColor
			for i = 1, 4 do
				if IsSecret(c[i]) or type(c[i]) ~= "number" then
					return nil
				end
			end
			if c[1] ~= r or c[2] ~= g or c[3] ~= b then
				return nil
			end
		end
		return Tokens.Material(Widgets.Setting("cardMaterial"))
	end
end

function Chrome:MaterialOpacity()
	if self.popup then
		return 1
	end
	local alpha = self.ownFill and self.fillColor[4] or Widgets.Setting("panelOpacity")
	return max(0, alpha / SURFACE_ALPHA)
end

function Chrome:SyncMaterialFrame()
	if not self.frameWanted and not self.materialFrame then
		return
	end
	local active = self.frameWanted and self.frameReady
	local accent = active and (self.ownEdge or self.proc)
	if self.line then
		Widgets.ShowSlice(self.line, self.visible and not active)
	end
	Widgets.ShowSlice(self.rim, self.visible and not active)
	if self.materialEdge then
		Widgets.ShowSlice(self.materialEdge, self.visible and accent and true or false)
	end
	if self.materialFrame then
		Widgets.ShowSlice(self.materialFrame, self.visible and active)
	end
	if self.materialBrackets then
		Widgets.ShowSlice(self.materialBrackets, self.visible and active and self.bracketsWanted)
	end
	if self.gilt then
		ShowOnce(self, "giltState", self.gilt, self.visible and self.ticksShown and not (active and self.bracketsWanted))
	end
end

function Chrome:PaintMaterial()
	if self.released then
		return
	end
	local material = self:Material()
	local framed = self.shape.card and material and material.frame
	self.frameWanted = framed
	self.bracketsWanted = material and material.brackets
	if not framed then
		self.frameReady = false
	end
	self:SyncMaterialFrame()
	if not material or not material.texture then
		if self.grain then
			self.grain:Hide()
		end
		return
	end
	if self.grain then
		self.grain:SetShown(self.visible)
	end
	if not Widgets.MayMove(self.owner) then
		if not self.materialQueued then
			self.materialQueued = true
			ns.Combat.Queue(function()
				self.materialQueued = false
				self:PaintMaterial()
			end)
		end
		return
	end
	local owner = self.owner
	local w, h = owner:GetWidth(), owner:GetHeight()
	if IsSecret(w) or IsSecret(h) or type(w) ~= "number" or type(h) ~= "number" then
		return
	end
	local inset = Widgets.Snap(owner, self:Radius())
	local pixel = Scale.Pixel(1) / Widgets.ScaleFactor(owner)
	if framed then
		local pixels = min(3, max(1, floor(Widgets.Border(owner) / pixel + 0.5)))
		local name = "forgedFrame" .. pixels
		if not self.materialFrame then
			self.materialFrame = NewSlice(owner, name, "BORDER", SUBLEVEL_RIM)
			for i = 1, #self.materialFrame do
				Widgets.Crisp(self.materialFrame[i])
			end
		elseif self.materialFrame.texture ~= name then
			PaintSlice(self.materialFrame, name)
		end
		self.frameReady = min(w, h) >= 16 * pixels * pixel
		if self.frameReady then
			Widgets.LayoutSlice(self.materialFrame, owner, 8 * pixels * pixel, 0)
			Widgets.ColorSlice(self.materialFrame, Widgets.Rgba("white", min(1, self:MaterialOpacity())))
			local edge, fresh = self.materialEdge, not self.materialEdge
			if fresh then
				edge = {}
				for i = 1, 4 do
					edge[i] = Widgets.Crisp(NewTexture(owner, "BORDER", SUBLEVEL_RIM))
				end
				self.materialEdge = edge
			end
			local band, line = 3 * pixels * pixel, pixels * pixel
			local top, bottom, left, right = edge[1], edge[2], edge[3], edge[4]
			for i = 1, 4 do
				edge[i]:ClearAllPoints()
			end
			top:SetPoint("TOPLEFT", owner, "TOPLEFT", band, -band)
			top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -band, -band)
			top:SetHeight(line)
			bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", band, band)
			bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -band, band)
			bottom:SetHeight(line)
			left:SetPoint("TOPLEFT", owner, "TOPLEFT", band, -band - line)
			left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", band, band + line)
			left:SetWidth(line)
			right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -band, -band - line)
			right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -band, band + line)
			right:SetWidth(line)
			if fresh then
				self:PaintEdge()
			end
		end
		if material.brackets then
			if not self.materialBrackets then
				self.materialBrackets = {}
				for i = 1, 4 do
					self.materialBrackets[i] = Widgets.Crisp(NewTexture(owner, "BORDER", SUBLEVEL_GILT))
				end
			end
			for i, corner in ipairs(BRACKET_CORNERS) do
				local bracket = self.materialBrackets[i]
				bracket:SetTexture(Tokens.Texture("forgedBracket" .. pixels))
				bracket:SetVertexColor(Widgets.Rgba("white", min(1, self:MaterialOpacity())))
				local share = pixels == 3 and 0.75 or 1
				local left, right = i % 2 == 1 and 0 or share, i % 2 == 1 and share or 0
				local top, bottom = i <= 2 and 0 or share, i <= 2 and share or 0
				bracket:SetTexCoord(left, right, top, bottom)
				bracket:ClearAllPoints()
				bracket:SetPoint(corner, owner, corner)
				bracket:SetSize(8 * pixels * pixel, 8 * pixels * pixel)
				bracket:SetShown(self.visible and min(w, h) >= 16 * pixels * pixel)
			end
		end
		self:SyncMaterialFrame()
	end
	if w <= 2 * inset or h <= 2 * inset or pixel <= 0 then
		if self.grain then
			self.grain:Hide()
		end
		return
	end
	if not self.grain then
		self.grain = NewTexture(owner, "BACKGROUND", SUBLEVEL_FILL + 1)
		self.grain:SetBlendMode("BLEND")
	end
	self.grain:ClearAllPoints()
	self.grain:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
	self.grain:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
	if self.grain:SetTexture(Tokens.Texture(material.texture), "REPEAT", "REPEAT") == false then
		self.grain:Hide()
		return
	end
	self.grain:SetTexCoord(0, (w - 2 * inset) / pixel / material.texels, 0, (h - 2 * inset) / pixel / material.texels)
	self.grain:SetVertexColor(Widgets.Rgba("white", min(1, material.grain * self:MaterialOpacity())))
	self.grain:SetShown(self.visible)
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
	local material = self:Material()
	if material and material.fill then
		r, g, b, a = Tokens.Color(material.fill)
		a = self.popup and 1 or min(1, a * self:MaterialOpacity())
	end
	Widgets.ColorSlice(self.fill, r, g, b, a)
	self:PaintMaterial()
	if self.shadow then
		ShowOnce(self, "shadowState", self.shadow, self.visible and self.shadowOn and Widgets.Setting("shadows"))
	end
	if self.gilt then
		ShowOnce(self, "giltState", self.gilt, self.visible and self.ticksShown and not (self.frameReady and material and material.brackets))
	end
	self:PaintEdge()
end

function Chrome:PaintEdge()
	self:SyncMaterialFrame()
	local e = self.edge
	local material = self:Material()
	if material and material.edge and not self.ownEdge then
		e = { Tokens.Color(material.edge) }
	end
	if self.line then
		local name = self.proc and "giltLit" or self.shape.line
		if self.lineName ~= name then
			self.lineName = name
			Widgets.ColorSlice(self.line, Tokens.Color(name))
		end
	elseif self.proc then
		Widgets.ColorSlice(self.rim, Tokens.Color("gilt"))
		return
	end
	local r, g, b, a = e[1], e[2], e[3], e[4]
	if self.frameWanted and self.frameReady and self.proc then
		r, g, b, a = Tokens.Color("giltLit")
	end
	Widgets.ColorSlice(self.rim, r, g, b, a)
	if self.materialEdge then
		Widgets.ColorSlice(self.materialEdge, r, g, b, a)
	end
end

function Chrome:Restyle()
	if self.released then
		return
	end
	if Widgets.MayMove(self.owner) then
		self:Layout()
	elseif not self.layoutQueued then
		self.layoutQueued = true
		ns.Combat.Queue(function()
			self.layoutQueued = false
			if not self.released then
				self:Layout()
				self:Paint()
			end
		end)
	end
	self:Paint()
	self:RestyleOrnament()
end

function Chrome:RestyleOrnament()
	if not self.ornament or self.ornamentQueued then
		return
	end
	if self.ornament.kind == "crest" or not (C_Timer and C_Timer.After) then
		if not self.released then
			self.ornament:Restyle()
		end
		return
	end
	self.ornamentQueued = true
	if not self.ornamentRun then
		self.ornamentRun = function()
			self.ornamentQueued = false
			if not self.released then
				self.ornament:Restyle()
			end
		end
	end
	C_Timer.After(0, self.ornamentRun)
end

function Chrome:Release()
	self.released = true
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
	if name == "edgeInner" and (alphaScale == nil or alphaScale == 1) then
		self.ownEdge = false
		self:PaintEdge()
	end
end

function Chrome:SetEdgeRGBA(r, g, b, a)
	self.ownEdge = true
	local e = self.edge
	e[1], e[2], e[3], e[4] = r, g, b, a
	self:PaintEdge()
end

function Chrome:SetProc(on)
	on = on and true or false
	if self.proc ~= on then
		self.proc = on
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
	self.visible = shown and true or false
	if self.ornament then
		self.ornament.enabled = self.visible
		self:RestyleOrnament()
	end
	if self.grain then
		self:PaintMaterial()
	end
	Widgets.ShowSlice(self.fill, shown)
	Widgets.ShowSlice(self.rim, shown)
	if self.line then
		Widgets.ShowSlice(self.line, shown)
	end
	if self.gilt then
		ShowOnce(self, "giltState", self.gilt, self.visible and self.ticksShown)
	end
	if self.shadow then
		ShowOnce(self, "shadowState", self.shadow, self.visible and self.shadowOn and Widgets.Setting("shadows"))
	end
	self:PaintMaterial()
	local material = self:Material()
	if self.gilt and self.frameReady and material and material.brackets then
		ShowOnce(self, "giltState", self.gilt, false)
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
	if widget.AnimateHover then
		return widget:AnimateHover(on)
	end
	return Motion.Tween(widget, SetHover, widget.hoverT or 0, on and 1 or 0, Tokens.Duration("hover"), Tokens.Easing("hover"))
end

function Widgets.Press(widget, down)
	if widget.AnimatePress then
		return widget:AnimatePress(down)
	end
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
ns.Callbacks.Register("ScaleChanged", SECTION, function()
	RestyleTexts()
	Widgets.RestyleAll()
	Widgets.PlaceAgain()
end)
ns.Callbacks.Register("ProfileChanged", SECTION, Widgets.RestyleAll)
ns.Callbacks.Register("SettingChanged", SECTION, function(_, module, key)
	if module == SECTION or (module == "Appearance" and key == "motion") then
		Widgets.RestyleAll()
	end
end)

function Widgets.Clamp(v, low, high)
	return min(high, max(low, v))
end
