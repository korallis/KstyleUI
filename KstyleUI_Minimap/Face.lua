-- Face.lua: the minimap's face, shared by the live map and the preview: the square map seated in a forged card with gilt brackets on its corners, the north diamond on its top edge, the zone in capitals above the card, the coordinates and the clock under it, and the hover group that holds the zoom slider.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets, Motion, Scale = K.L, K.Tokens, K.Widgets, K.Motion, K.Scale
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format
local floor, max, min = math.floor, math.max, math.min

local Face = {}
Face.__index = Face
ns.Face = Face

local LEVEL_CARD, LEVEL_MAP, LEVEL_OVERLAY, LEVEL_REVEAL, LEVEL_WHEEL = 1, 2, 110, 111, 112
local LEVEL_PLATE = 111
local ZONE_ROLE = "caps"
local NORTH_ROLE = "number"
local CLOCK_ROLE = "time"
local COORDS_ROLE = "number"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SLIDER_WIDTH, SLIDER_HEIGHT, SLIDER_HIT = 2, 52, 12
local SLIDER_INSET = 11
local NORTH_SIZE = 7
local SHADE_ALPHA = 0.85
local VIGNETTE, VIGNETTE_ALPHA = 14, 0.5
local MERIDIEM_GAP = 2
local BRACKET_ARM, BRACKET_LINES = 8, 2
local BRACKET_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local VIGNETTE_EDGES = { "top", "bottom", "left", "right" }
local PLAQUE_HEIGHT = 18
local PLAQUE_PAD = 6
local RING_OUTER = 0.9189
local RING_SUBLEVEL = 3
local BADGE, BADGE_BAND = 16, 2
local NORTH_RUNE, NORTH_GAP, NORTH_TOP, NORTH_BOTTOM = 0.045, 0.045, 0.015, 0.106
local ROUND_CORNER = 0.146
local INSIDE = { "zone", "clock", "coords", "difficulty", "perf" }
local currentFrame

Face.LEVEL_MAP, Face.ROUND_CORNER = LEVEL_MAP, ROUND_CORNER

local function SliderSide()
	if Settings.Get("column.side") == "left" then return "RIGHT", -1 end
	return "LEFT", 1
end

function Face.Round()
	return Widgets.Medallions()
end

function Face.Frame()
	return Face.Round() and (currentFrame or Settings.Get("frame")) or "classic"
end

local function RingOuter()
	return Face.Frame() ~= "classic" and 118 / 150 or RING_OUTER
end

local function CaptionX()
	return Format.CAPTION_X + (Face.Round() and PLAQUE_PAD or 0)
end

function Face.MaskPath()
	if Face.Round() then
		return (Tokens.Texture((Widgets.TextureName("medMinimapMask"))))
	end
	return (Tokens.Texture("minimapMask"))
end

local function Level(frame, holder, offset)
	frame:SetFrameLevel(holder:GetFrameLevel() + offset)
end

local function Snap(frame, units)
	return Widgets.Snap(frame, units)
end

local function NewText(parent)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetWordWrap(false)
	return text
end

local function NewLines(overlay, sublevel)
	local lines = {}
	for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
		local line = Widgets.Crisp(overlay:CreateTexture(nil, "OVERLAY", nil, sublevel))
		line:SetColorTexture(Tokens.Color("white"))
		lines[edge] = line
	end
	return lines
end

local function PlaceLines(lines, area, inset, border)
	local top, bottom, left, right = lines.top, lines.bottom, lines.left, lines.right
	for _, line in pairs(lines) do
		line:ClearAllPoints()
	end
	Widgets.Point(top, "TOPLEFT", area, "TOPLEFT", inset, -inset)
	Widgets.Point(top, "TOPRIGHT", area, "TOPRIGHT", -inset, -inset)
	top:SetHeight(border)
	Widgets.Point(bottom, "BOTTOMLEFT", area, "BOTTOMLEFT", inset, inset)
	Widgets.Point(bottom, "BOTTOMRIGHT", area, "BOTTOMRIGHT", -inset, inset)
	bottom:SetHeight(border)
	Widgets.Point(left, "TOPLEFT", area, "TOPLEFT", inset, -inset)
	Widgets.Point(left, "BOTTOMLEFT", area, "BOTTOMLEFT", inset, inset)
	left:SetWidth(border)
	Widgets.Point(right, "TOPRIGHT", area, "TOPRIGHT", -inset, -inset)
	Widgets.Point(right, "BOTTOMRIGHT", area, "BOTTOMRIGHT", -inset, inset)
	right:SetWidth(border)
end

local function NewVignette(overlay)
	local edges = {}
	for _, edge in ipairs(VIGNETTE_EDGES) do
		local texture = overlay:CreateTexture(nil, "ARTWORK")
		texture:SetColorTexture(Tokens.Color("white"))
		edges[edge] = texture
	end
	return edges
end

local function Fade(texture, orientation, darkFirst)
	local r, g, b = Tokens.Color("black")
	if type(texture.SetGradient) == "function" and type(CreateColor) == "function" then
		local dark, clear = CreateColor(r, g, b, VIGNETTE_ALPHA), CreateColor(r, g, b, 0)
		if darkFirst then
			texture:SetGradient(orientation, dark, clear)
		else
			texture:SetGradient(orientation, clear, dark)
		end
		return
	end
	texture:SetVertexColor(r, g, b, VIGNETTE_ALPHA / 4)
end

local function PlaceVignette(edges, area, depth)
	local top, bottom, left, right = edges.top, edges.bottom, edges.left, edges.right
	for _, texture in pairs(edges) do
		texture:ClearAllPoints()
	end
	Widgets.Point(top, "TOPLEFT", area, "TOPLEFT")
	Widgets.Point(top, "TOPRIGHT", area, "TOPRIGHT")
	top:SetHeight(depth)
	Widgets.Point(bottom, "BOTTOMLEFT", area, "BOTTOMLEFT")
	Widgets.Point(bottom, "BOTTOMRIGHT", area, "BOTTOMRIGHT")
	bottom:SetHeight(depth)
	Widgets.Point(left, "TOPLEFT", area, "TOPLEFT")
	Widgets.Point(left, "BOTTOMLEFT", area, "BOTTOMLEFT")
	left:SetWidth(depth)
	Widgets.Point(right, "TOPRIGHT", area, "TOPRIGHT")
	Widgets.Point(right, "BOTTOMRIGHT", area, "BOTTOMRIGHT")
	right:SetWidth(depth)
end

local function PaintVignette(edges)
	Fade(edges.top, "VERTICAL", false)
	Fade(edges.bottom, "VERTICAL", true)
	Fade(edges.left, "HORIZONTAL", true)
	Fade(edges.right, "HORIZONTAL", false)
end

function Face.Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value)
end
local Plain = Face.Plain

local function ShareAtCursor(zoom)
	local track = zoom.track
	local bottom, height, scale = track:GetBottom(), track:GetHeight(), track:GetEffectiveScale()
	if type(GetCursorPosition) ~= "function" then
		return nil
	end
	local _, y = GetCursorPosition()
	if not (Plain(bottom) and Plain(height) and Plain(scale) and Plain(y)) or height <= 0 or scale <= 0 then
		return nil
	end
	return (y / scale - bottom) / height
end

local function Drag(zoom)
	local share, onZoom = ShareAtCursor(zoom), zoom.face.onZoom
	if share and onZoom then
		onZoom(share)
	end
end

local function StopDrag(zoom)
	zoom:SetScript("OnUpdate", nil)
end

local function StartDrag(zoom, button)
	if button and button ~= "LeftButton" then
		return
	end
	Drag(zoom)
	zoom:SetScript("OnUpdate", Drag)
end

local function NewDiamond(plate)
	local layers = {}
	for i, name in ipairs({ "black", "gilt", "fill" }) do
		local texture = plate:CreateTexture(nil, "ARTWORK", nil, i)
		texture:SetTexture((Tokens.Texture("diamond")))
		layers[name] = texture
	end
	return layers
end

function Face.New(holder, opts)
	opts = opts or {}
	local face = setmetatable({ holder = holder, onZoom = opts.onZoom, zoomShare = 0, revealed = false }, Face)

	local card = CreateFrame("Frame", nil, holder)
	Level(card, holder, LEVEL_CARD)
	face.card = card
	face.fill = card:CreateTexture(nil, "BACKGROUND")
	face.fill:SetAllPoints(card)
	face.frames = {}

	local mapArea = CreateFrame("Frame", nil, holder)
	mapArea:SetAllPoints(holder)
	face.mapArea = mapArea

	local overlay = CreateFrame("Frame", nil, holder)
	Level(overlay, holder, LEVEL_OVERLAY)
	overlay:SetAllPoints(mapArea)
	face.overlay = overlay

	local mask = overlay:CreateMaskTexture()
	mask:SetTexture(Face.MaskPath(), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(mapArea)
	face.mask = mask

	face.vignette = NewVignette(overlay)
	face.shade = NewLines(overlay, 0)
	face.brackets = {}
	for i = 1, #BRACKET_CORNERS do
		local bracket = {}
		for _, arm in ipairs({ "across", "down" }) do
			bracket[arm] = Widgets.Crisp(overlay:CreateTexture(nil, "OVERLAY", nil, 2))
			bracket[arm]:SetColorTexture(Tokens.Color("white"))
		end
		face.brackets[i] = bracket
	end

	local plate = CreateFrame("Frame", nil, holder)
	Level(plate, holder, LEVEL_PLATE)
	plate.diamond = NewDiamond(plate)
	face.north = Widgets.Fitted(NewText(plate))
	face.north:SetText(L["N"])
	Widgets.Point(face.north, "CENTER", plate, "CENTER", 0, 0)
	face.plate = plate

	local caption = CreateFrame("Frame", nil, overlay)
	caption:SetAllPoints(card)
	face.caption = caption
	face.zone = NewText(caption)
	face.zone:SetJustifyH("LEFT")
	face.clock = NewText(caption)
	face.clock:SetJustifyH("RIGHT")
	face.meridiem = NewText(caption)
	face.meridiem:SetJustifyH("LEFT")
	face.zoneHit = CreateFrame("Button", nil, caption)
	face.zoneHit:SetAllPoints(face.zone)
	face.clockHit = CreateFrame("Button", nil, caption)
	face.clockHit:SetPoint("TOPLEFT", face.clock, "TOPLEFT")
	face.clockHit:SetPoint("BOTTOMRIGHT", face.meridiem, "BOTTOMRIGHT")

	local coordsFrame = CreateFrame("Frame", nil, caption)
	coordsFrame:SetAllPoints(caption)
	face.coordsFrame = coordsFrame
	face.coords = NewText(caption)
	face.coords:SetJustifyH("LEFT")
	face.difficulty = NewText(caption)
	face.perf = NewText(caption)
	face.perfHit = CreateFrame("Button", nil, caption)
	face.perfHit:SetAllPoints(face.perf)
	face.perfHit:Hide()

	local reveal = CreateFrame("Frame", nil, holder)
	Level(reveal, holder, LEVEL_REVEAL)
	reveal:SetAllPoints(mapArea)
	reveal:Hide()
	face.reveal = reveal

	local zoom = CreateFrame("Frame", nil, reveal)
	zoom.face = face
	zoom:EnableMouse(true)
	zoom.rim = zoom:CreateTexture(nil, "ARTWORK", nil, -1)
	zoom.rim:SetColorTexture(Tokens.Color("white"))
	zoom.track = zoom:CreateTexture(nil, "ARTWORK")
	zoom.track:SetColorTexture(Tokens.Color("white"))
	zoom.fill = zoom:CreateTexture(nil, "ARTWORK", nil, 1)
	zoom.fill:SetColorTexture(Tokens.Color("white"))
	zoom:SetScript("OnMouseDown", StartDrag)
	zoom:SetScript("OnMouseUp", StopDrag)
	zoom:SetScript("OnHide", StopDrag)
	face.zoom = zoom

	if opts.wheel then
		local wheel = CreateFrame("Frame", nil, holder)
		Level(wheel, holder, LEVEL_WHEEL)
		wheel:SetAllPoints(mapArea)
		wheel:EnableMouseWheel(true)
		face.wheel = wheel
	end
	return face
end

function Face:SetZone(text, pvpType)
	self.zoneText, self.pvpType = text, pvpType
	if issecretvalue and issecretvalue(text) then
		self.zone:SetText(text)
	elseif type(text) == "string" then
		self.zone:SetText(K.Locale.Upper(text))
	else
		self.zone:SetText("")
	end
	self.zone:SetTextColor(Style.Color(Format.ZoneToken(pvpType, Settings.Get("zone.color"))))
	self:PlaceZone()
end

local function Extent(text)
	local height = text:GetStringHeight()
	if Plain(height) and height > 0 then
		return height
	end
	local _, size = text:GetFont()
	return Plain(size) and size or 0
end

local function PlaqueHeight(face)
	return max(PLAQUE_HEIGHT, max(Extent(face.zone), Extent(face.clock), Extent(face.coords)) + 2 * Widgets.Border(face.card))
end

local function RowCenter(face, side)
	if Face.Frame() == "medallion" then return (side or face.mapSize) * (1 / RingOuter() - 1) / 2 - Format.FRAME end
	if Face.Round() and Settings.Get("clearPlaques") then
		return max(Format.ROW_CENTER, (side or face.mapSize) * (1 / RingOuter() - 1) / 2 + PlaqueHeight(face) / 2 + 2 - Format.FRAME)
	end
	return Format.ROW_CENTER
end

local function ZoneCenter(face, side)
	local card = face.card
	local mark = max(face.plate.diamond.black:GetHeight() or 0, Extent(face.north)) / 2
	local clear = mark - Snap(card, Format.FRAME) + Widgets.Border(card)
	local y = max(Snap(card, Format.ZONE_CENTER), Snap(card, clear + Extent(face.zone) / 2))
	return Face.Round() and (Settings.Get("clearPlaques") or Face.Frame() ~= "classic") and max(y, Snap(card, side * (1 / RingOuter() - 1) / 2 + PlaqueHeight(face) / 2 + 2 - Format.FRAME)) or y
end

function Face:Clamp(left, bottom, width, height, rootWidth, rootHeight)
	local factor = Widgets.ScaleFactor(self.holder)
	local side = min(width, height) / factor
	local overhang = Face.Round() and side * (1 / RingOuter() - 1) / 2 or 0
	local half = PlaqueHeight(self) / 2
	local x = max(overhang, Format.FRAME) * factor
	local top = max(overhang, Format.FRAME + ZoneCenter(self, side) + max(half, Extent(self.zone) / 2)) * factor
	local lower = max(overhang, Format.FRAME + RowCenter(self, side) + max(half, Extent(self.clock) / 2, Extent(self.coords) / 2)) * factor
	local margin, origin = Tokens.Size("screenMargin") + (Face.Frame() ~= "classic" and Scale.Pixel(1) or 0), Scale.Origin()
	return max(margin + x - origin, min(left, rootWidth + origin - margin - x - width)), max(margin + lower, min(bottom, rootHeight - margin - top - height))
end

function Face:PlaceZone()
	local card, zone = self.card, self.zone
	local side = self.mapSize
	if not side or self.zonePlaced then
		return
	end
	self.zonePlaced = true
	local y = ZoneCenter(self, side)
	if Face.Round() and Settings.Get("clearPlaques") then
		local _, _, top = Widgets.Edges(card)
		local _, _, screen = Widgets.Edges(Scale.Root())
		local factor = Widgets.ScaleFactor(card)
		if Plain(top) and Plain(screen) and Plain(factor) and factor > 0 then
			y = min(y, Snap(card, (screen - top * factor - Tokens.Size("screenMargin")) / factor - PLAQUE_HEIGHT / 2))
		end
	end
	self.zoneX, self.zoneY = Snap(card, CaptionX()), y
	if Face.Moved("zone") then
		return
	end
	zone:ClearAllPoints()
	Widgets.Point(zone, "LEFT", card, "TOPLEFT", self.zoneX + Snap(card, Settings.Get("zone.x")), self.zoneY + Snap(card, Settings.Get("zone.y")))
	zone:SetWidth(Snap(card, max(0, side + 2 * Format.FRAME - 2 * CaptionX())))
end

local MERIDIEMS = { { L["AM"], " " .. L["AM"] }, { L["PM"], " " .. L["PM"] } }

local function SplitClock(text)
	if type(text) ~= "string" then
		return "", ""
	end
	for _, pair in ipairs(MERIDIEMS) do
		local tail = pair[2]
		if #text > #tail and text:sub(-#tail) == tail then
			return text:sub(1, #text - #tail), pair[1]
		end
	end
	return text, ""
end

function Face:PlaceClock()
	local card, clock, meridiem = self.clockAnchor or self.card, self.clock, self.meridiem
	local pixel = self.clockPixel
	if not pixel then
		return
	end
	local gap = 0
	local width = 0
	if meridiem:GetText() ~= nil and meridiem:GetText() ~= "" then
		width = meridiem:GetStringWidth()
		if not Plain(width) then
			width = 0
		end
		gap = self.clockGap
	end
	meridiem:ClearAllPoints()
	meridiem:SetPoint("BOTTOMLEFT", clock, "BOTTOMRIGHT", gap, 0)
	if Face.Moved("clock") then
		return
	end
	clock:ClearAllPoints()
	local x = (floor(-(self.clockInset + width + gap) / pixel + self.clockRight + 0.5) - self.clockRight) * pixel
	local y = -(floor(self.clockRow / pixel + self.clockBottom + 0.5) - self.clockBottom) * pixel
	clock:SetPoint("RIGHT", card, self.clockAnchor and "RIGHT" or "BOTTOMRIGHT", x + Snap(self.card, Settings.Get("clock.x")), y + Snap(self.card, Settings.Get("clock.y")))
end

function Face:SetClock(text)
	local time, suffix = SplitClock(text)
	if self.clockText ~= time then
		self.clock:SetText(time)
		self.clockText = time
	end
	if self.meridiem:GetText() ~= suffix then
		self.meridiem:SetText(suffix)
		self:PlaceClock()
		if Face.Moved("clock") then self:PlaceInside() end
	end
end

function Face:SyncPlaques()
	local plaques = self.plaques
	if not plaques or not Face.Round() then
		return
	end
	plaques[1].chrome:SetShown(Settings.Get("zone.shown") == true and not Face.Moved("zone"))
	plaques[2].chrome:SetShown(Settings.Get("clock.shown") == true and not Face.Moved("clock")
		or self.coordsText ~= nil and Settings.Get("coords.shown") == true and not Face.Moved("coords") and (not Settings.Get("coords.hover") or self.revealed))
end

function Face:SetCoords(text)
	local placed = (text == nil) ~= (self.coordsText == nil)
	self.coordsText = text
	self.coords:SetText(text or "")
	self.coords:SetShown(text ~= nil and Settings.Get("coords.shown") and (not Settings.Get("coords.hover") or self.revealed))
	self:SyncPlaques()
	if placed then self:PlaceInside() end
	if self.clockAnchor and (self.coords:GetStringWidth() or 0) > self.coordsFit then self:PlaceRound(true) end
end

function Face:SetDifficulty(text)
	local placed = (text == nil) ~= (self.difficultyText == nil)
	self.difficultyText = text
	self.difficulty:SetText(text or "")
	self.difficulty:SetShown(text ~= nil and Settings.Get("difficulty.shown"))
	if placed then self:PlaceInside() end
end

function Face:SetPerf(text)
	local placed = (text == nil) ~= (self.perfText == nil)
	self.perfText = text
	self.perf:SetText(text or "")
	self.perf:SetShown(text ~= nil and Settings.Get("perf.shown"))
	self.perfHit:SetShown(self.perf:IsShown() and Settings.Get("perf.hover") ~= "none")
	if placed then self:PlaceInside() end
end

function Face.Moved(name)
	local point = Settings.Get(name .. ".position")
	return point ~= "" and point or nil
end

function Face:PlaceInside()
	local area, side = self.mapArea, self.mapSize
	if not side then
		return
	end
	local edge, gap = Snap(area, Format.EDGE), Snap(area, 2)
	local column = Settings.Get("column.side") == "left" and 1 or -1
	local reserve = max(0, Snap(area, Format.EDGE + Settings.Get("column.offset")) + ns.Column.Size(self.holder))
	local corners = { [Settings.Get("column.mail") and Settings.Get("mail.position") or ""] = reserve }
	if self.compartment then
		local corner = Settings.Get("compartment.position")
		corners[corner] = max(corners[corner] or 0, reserve + ns.Column.Size(self.holder) * (Settings.Get("compartment.scale") - 1))
	end
	local used = {}
	for _, name in ipairs(INSIDE) do
		local point, text = Face.Moved(name), self[name]
		if point then
			local h = point:find("LEFT") and 1 or point:find("RIGHT") and -1 or 0
			local v = point:find("TOP") and -1 or point:find("BOTTOM") and 1 or 0
			local corner = Face.Round() and h ~= 0 and v ~= 0 and Snap(area, side * ROUND_CORNER) or 0
			local x = edge + corner + (h == column and reserve or 0) + (corners[point] or 0)
				+ (point == SliderSide() and Snap(area, SLIDER_INSET + SLIDER_HIT) or 0)
			local y = (v == 0 and 0 or edge + corner) + (used[point] or 0)
			x = h * x + Snap(area, Settings.Get(name .. ".x"))
			if name == "clock" and h == -1 and (self.meridiem:GetText() or "") ~= "" then
				local width = self.meridiem:GetStringWidth()
				x = x - (Plain(width) and width + self.clockGap or 0)
			end
			text:ClearAllPoints()
			Widgets.Point(text, point, area, point, x, (v == 1 and 1 or -1) * y + Snap(area, Settings.Get(name .. ".y")))
			text:SetJustifyH(h == 1 and "LEFT" or h == -1 and "RIGHT" or "CENTER")
			if name == "zone" then
				text:SetWidth(max(0, side - 2 * edge - reserve))
			end
			if Settings.Get(name .. ".shown") and (name == "clock" or self[name .. "Text"] ~= nil) then
				used[point] = (used[point] or 0) + Extent(text) + gap
			end
		end
	end
end

function Face:SetRevealed(on)
	self.revealed = on == true
	if Settings.Get("coords.hover") then self:SetCoords(self.coordsText) end
	local reveal = self.reveal
	if self.revealed then
		if not reveal:IsShown() or reveal:GetAlpha() < 1 then
			Motion.FadeIn(reveal, Tokens.Duration("fade"))
		end
	else
		Motion.FadeOut(reveal, Tokens.Duration("fade"))
	end
end

function Face:PaintZoom()
	local zoom = self.zoom
	local height = Widgets.Snap(self.mapArea, self.zoomShare * SLIDER_HEIGHT)
	zoom.fill:SetHeight(height)
	zoom.fill:SetShown(height > 0)
end

function Face:SetZoom(level, levels)
	self.zoomShare = Format.ZoomShare(level, levels) or 0
	self:PaintZoom()
end

function Face:PlaceSlider()
	local area, zoom = self.mapArea, self.zoom
	local track = zoom.track
	local fits = (self.mapSize or 0) >= 2 * (SLIDER_INSET + SLIDER_HIT) + SLIDER_HEIGHT
	zoom:SetShown(fits and Settings.Get("zoom.slider"))
	local side, toward = SliderSide()
	local inset = toward * Snap(area, SLIDER_INSET)
	Widgets.Size(track, SLIDER_WIDTH, SLIDER_HEIGHT)
	track:ClearAllPoints()
	Widgets.Point(track, side, area, side, inset, 0)
	zoom:ClearAllPoints()
	Widgets.Point(zoom, side, area, side, inset - toward * Snap(area, (SLIDER_HIT - SLIDER_WIDTH) / 2), 0)
	Widgets.Size(zoom, SLIDER_HIT, SLIDER_HEIGHT)
	zoom.fill:ClearAllPoints()
	Widgets.Point(zoom.fill, "BOTTOMLEFT", track, "BOTTOMLEFT")
	Widgets.Point(zoom.fill, "BOTTOMRIGHT", track, "BOTTOMRIGHT")
	local line = Widgets.Border(area)
	if zoom.rimLine ~= line then
		zoom.rimLine = line
		zoom.rim:SetPoint("TOPLEFT", track, "TOPLEFT", -line, line)
		zoom.rim:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", line, -line)
	end
	self:PaintZoom()
end

local function FramePixels(card)
	local pixel = Scale.Pixel(1) / Widgets.ScaleFactor(card)
	if not Plain(pixel) or pixel <= 0 then
		return 1, 1
	end
	return min(3, max(1, floor(Widgets.Border(card) / pixel + 0.5))), pixel
end

function Face:PlaceRound(round)
	local ring, plaques = self.ring, self.plaques
	self.clockAnchor = nil
	if not round then
		for _, layer in pairs(self.plate.diamond) do layer:Show() end
		if ring then
			ring:Hide()
			if self.enamel then self.enamel:Hide(); self.runes:Hide(); self.northBand:Hide() end
			for _, plaque in ipairs(plaques) do
				plaque.chrome:SetShown(false)
			end
		end
		return
	end
	if not ring then
		ring = self.overlay:CreateTexture(nil, "OVERLAY", nil, RING_SUBLEVEL)
		self.ring = ring
		plaques = {}
		for i = 1, 2 do
			local plaque = CreateFrame("Frame", nil, self.overlay)
			plaque:SetFrameLevel(self.overlay:GetFrameLevel() + 1)
			plaque.chrome = Widgets.Chrome(plaque, { shape = "card", fill = "surface", shadow = false, gilt = false })
			plaques[i] = plaque
		end
		self.plaques = plaques
	end
	local crest = Face.Frame() ~= "classic"
	local name, standin = Widgets.TextureName("medMinimapRing")
	local path = crest and Tokens.Texture("medMinimapCrestRing") or Tokens.Texture(name)
	ring:SetTexture(path)
	ring:SetVertexColor(Widgets.Rgba(not crest and standin and "steel" or "white"))
	if crest and not self.enamel then
		self.enamel = self.overlay:CreateTexture(nil, "OVERLAY", nil, RING_SUBLEVEL + 1)
		self.enamel:SetTexture((Tokens.Texture("medMinimapCrestEnamel")))
		self.enamel:SetAllPoints(ring)
		self.runes = self.overlay:CreateTexture(nil, "OVERLAY", nil, RING_SUBLEVEL + 2)
		self.runes:SetTexture((Tokens.Texture("medRuneGlyphs")))
		self.runes:SetAllPoints(ring)
		self.runes:SetBlendMode("ADD")
		self.northBand = self.overlay:CreateTexture(nil, "OVERLAY", nil, RING_SUBLEVEL + 3)
		self.northBand:SetTexture(path)
		self.northBand:SetTexCoord(0.5 - NORTH_GAP, 0.5 + NORTH_GAP, NORTH_TOP, NORTH_BOTTOM)
	end
	if self.enamel then
		local r, g, b = Style.ClassColor()
		self.enamel:SetVertexColor(r, g, b, 0.35)
		self.runes:SetVertexColor(r, g, b, 0.25)
		self.enamel:SetShown(crest)
		self.runes:SetShown(crest)
		self.northBand:SetShown(crest and self.north:IsShown())
	end
	local card, side = self.card, self.mapSize or 0
	local outer = side / RingOuter()
	Widgets.Size(ring, outer, outer)
	ring:ClearAllPoints()
	Widgets.Point(ring, "CENTER", self.mapArea, "CENTER")
	ring:Show()
	if crest then
		local band = self.northBand
		Widgets.Size(band, outer * 2 * NORTH_GAP, outer * (NORTH_BOTTOM - NORTH_TOP))
		Widgets.Point(band, "TOP", ring, "TOP", 0, -outer * NORTH_TOP)
		Widgets.Point(self.plate, "CENTER", self.mapArea, "TOP", 0, Snap(self.mapArea, (outer - side) / 4))
		Style.Text(self.north, NORTH_ROLE, "zone", outer * NORTH_RUNE)
		self.north:SetTextColor(Widgets.Rgba("steelLit"))
	end
	local height = Snap(card, PlaqueHeight(self))
	local width = Snap(card, side + 2 * Format.FRAME)
	local zone, row = plaques[1], plaques[2]
	for _, plaque in ipairs(plaques) do
		plaque:SetSize(width, height)
	end
	zone:ClearAllPoints()
	Widgets.Point(zone, "LEFT", card, "TOPLEFT", self.zoneX - Snap(card, PLAQUE_PAD) + Snap(card, Settings.Get("zone.x")), self.zoneY + Snap(card, Settings.Get("zone.y")))
	row:ClearAllPoints()
	Widgets.Point(row, "CENTER", card, "BOTTOM", 0, -Snap(card, RowCenter(self)))
	local seated = Face.Frame() == "medallion"
	self.clockAnchor = seated and row or nil
	if seated then
		local coords = Face.Moved("coords") and 0 or self.coords:GetStringWidth() or 0
		local clock = self.coordsAlone and 0 or (self.clock:GetStringWidth() or 0) + (self.meridiem:GetStringWidth() or 0)
		local rowWidth = Snap(card, min(width, max(side * 0.6, coords + clock + 2 * PLAQUE_PAD + 12)))
		self.coordsFit = (Face.Moved("coords") or rowWidth >= width) and math.huge or max(coords, rowWidth - clock - 2 * PLAQUE_PAD - 12)
		row:SetWidth(rowWidth)
		row:ClearAllPoints()
		Widgets.Point(row, "CENTER", ring, "BOTTOM")
	end
	for _, layer in pairs(self.plate.diamond) do layer:SetShown(not crest) end
	self:SyncPlaques()
end

function Face:PlaceFrame()
	local card = self.card
	local round = Face.Round()
	local w, h = card:GetWidth(), card:GetHeight()
	local pixels, pixel = FramePixels(card)
	local name = "forgedFrame" .. pixels
	for key, slice in pairs(self.frames) do
		Widgets.ShowSlice(slice, key == name)
	end
	local slice = self.frames[name]
	if not slice then
		slice = Widgets.NineSlice(card, name, "BORDER", 0)
		for i = 1, #slice do
			Widgets.Crisp(slice[i])
		end
		self.frames[name] = slice
	end
	local size = 8 * pixels * pixel
	local shown = not round and Plain(w) and Plain(h) and min(w, h) >= 2 * size
	Widgets.ShowSlice(slice, shown)
	if shown then
		Widgets.LayoutSlice(slice, card, size, 0)
		Widgets.ColorSlice(slice, Tokens.Color("white"))
	end
	local arm = Snap(card, BRACKET_ARM)
	local line = BRACKET_LINES * Widgets.Border(card)
	for i, corner in ipairs(BRACKET_CORNERS) do
		local bracket = self.brackets[i]
		local across, down = bracket.across, bracket.down
		across:SetShown(shown)
		down:SetShown(shown)
		if shown then
			across:ClearAllPoints()
			Widgets.Point(across, corner, card, corner)
			across:SetSize(arm, line)
			down:ClearAllPoints()
			Widgets.Point(down, corner, card, corner)
			down:SetSize(line, arm)
		end
	end
end

function Face:Paint()
	currentFrame = Settings.Get("frame")
	self.layoutWidth = nil
	local r, g, b = Style.Accent()
	Widgets.Tint(self.zoom.track, "track")
	Widgets.LumenTint(self.zoom.rim, "rimLight", 2.5)
	self.zoom.fill:SetVertexColor(r, g, b, 1)
	self.zoom:SetShown(Settings.Get("zoom.slider"))
	local round = Face.Round()
	self.mask:SetTexture(Face.MaskPath(), MASK_WRAP, MASK_WRAP)
	for _, line in pairs(self.shade) do
		Widgets.Tint(line, "black", SHADE_ALPHA)
		line:SetShown(not round)
	end
	PaintVignette(self.vignette)
	for _, texture in pairs(self.vignette) do
		texture:SetShown(not round)
	end
	Widgets.Tint(self.fill, "materialForged")
	self.fill:SetShown(not round)
	self.zone:SetJustifyH(round and "CENTER" or "LEFT")
	for _, bracket in ipairs(self.brackets) do
		Widgets.Tint(bracket.across, "gilt")
		Widgets.Tint(bracket.down, "gilt")
	end
	local diamond = self.plate.diamond
	local mark = (Tokens.Texture(round and "dot" or "diamond"))
	for _, layer in pairs(diamond) do
		layer:SetTexture(mark)
	end
	Widgets.Tint(diamond.black, round and "medOutline" or "black")
	Widgets.Tint(diamond.gilt, round and "medGunLit" or "gilt")
	Widgets.Tint(diamond.fill, round and "medFillBottom" or "materialForged")
	Style.Text(self.north, NORTH_ROLE, "zone", NORTH_SIZE)
	self.north:SetTextColor(Widgets.Rgba(round and "medText" or "giltLit"))

	self.zoneSize = Style.Text(self.zone, ZONE_ROLE, "zone")
	self.clockSize = Style.Text(self.clock, CLOCK_ROLE, "clock")
	Style.Text(self.meridiem, CLOCK_ROLE, "clock", Settings.Get("clock.size") * Format.MERIDIEM)
	self.coordsSize = Style.Text(self.coords, COORDS_ROLE, "coords")
	Style.Text(self.difficulty, COORDS_ROLE, "difficulty")
	Style.Text(self.perf, COORDS_ROLE, "perf")
	self.clock:SetTextColor(Style.Color("textEmphasis"))
	self.meridiem:SetTextColor(Style.Color(Settings.Get("clock.accent") and "accent" or "textEmphasis"))
	self.coords:SetTextColor(Style.Color("text"))
	self.difficulty:SetTextColor(Style.Color(Settings.Get("difficulty.accent") and "accent" or "textEmphasis"))
	self.perf:SetTextColor(Style.Color("text"))
	self.north:SetShown(not ns.Data.Rotated())

	local zoneShown, clockShown = Settings.Get("zone.shown"), Settings.Get("clock.shown")
	self.zone:SetShown(zoneShown)
	self.zoneHit:SetShown(zoneShown)
	self.clock:SetShown(clockShown)
	self.meridiem:SetShown(clockShown)
	self.clockHit:SetShown(clockShown)
	self:SetZone(self.zoneText, self.pvpType)
	self:SetCoords(self.coordsText)
	self:SetDifficulty(self.difficultyText)
	self:SetPerf(self.perfText)
	self:SetRevealed(self.revealed)
end

function Face:Layout()
	local holder, area, card = self.holder, self.mapArea, self.card
	local width, height = holder:GetWidth(), holder:GetHeight()
	if not (Plain(width) and Plain(height)) or width <= 0 or height <= 0 then
		return
	end
	local pixel = Scale.Pixel(1) / Widgets.ScaleFactor(holder)
	local round = Face.Round()
	if self.layoutWidth == width and self.layoutHeight == height and self.layoutPixel == pixel and self.layoutRound == round then
		return
	end
	self.layoutWidth, self.layoutHeight, self.layoutPixel, self.layoutRound = width, height, pixel, round
	self.zonePlaced = nil
	local side = math.min(width, height)
	self.mapSize = side

	local frame = Snap(area, Format.FRAME)
	Widgets.Fill(card, area, -frame, -frame, -frame, -frame)
	self:PlaceFrame()

	local border = Widgets.Border(area)
	PlaceLines(self.shade, area, 0, border)
	PlaceVignette(self.vignette, area, Snap(area, VIGNETTE))

	local north = round and BADGE or Format.NORTH
	local plateSize = Snap(area, north)
	Widgets.Size(self.plate, north, north)
	self.plate:ClearAllPoints()
	Widgets.Point(self.plate, "CENTER", area, "TOP", 0, 0)
	local diamond = self.plate.diamond
	if round then
		local band = Snap(area, BADGE_BAND)
		diamond.black:SetSize(plateSize, plateSize)
		diamond.gilt:SetSize(plateSize - 2 * border, plateSize - 2 * border)
		diamond.fill:SetSize(max(0, plateSize - 2 * border - 2 * band), max(0, plateSize - 2 * border - 2 * band))
	else
		diamond.black:SetSize(plateSize + 3 * border, plateSize + 3 * border)
		diamond.gilt:SetSize(plateSize, plateSize)
		diamond.fill:SetSize(max(0, plateSize - 4 * border), max(0, plateSize - 4 * border))
	end

	for _, layer in pairs(diamond) do
		layer:ClearAllPoints()
		Widgets.Point(layer, "CENTER", self.plate, "CENTER")
	end
	Widgets.Point(self.north, "CENTER", self.plate, "CENTER")

	local x, rowY = Snap(card, CaptionX()), Snap(card, RowCenter(self))
	local coords = self.coords
	self:PlaceZone()
	if round and Settings.Get("clearPlaques") and Face.Frame() == "classic" then
		self.plate:ClearAllPoints()
		Widgets.Point(self.plate, "CENTER", area, "TOP", 0, frame + self.zoneY - Snap(card, PlaqueHeight(self) / 2 + BADGE / 2 + 2))
	end
	self.coordsAlone = round and (Settings.Get("clock.shown") ~= true or Face.Moved("clock"))
	self:PlaceRound(round)
	local seated = self.clockAnchor ~= nil
	local dx, dy = Snap(card, Settings.Get("coords.x")), Snap(card, Settings.Get("coords.y"))
	coords:ClearAllPoints()
	if self.coordsAlone then
		Widgets.Point(coords, "CENTER", self.plaques[2], "CENTER", dx, dy)
	else
		Widgets.Point(coords, "LEFT", self.clockAnchor or card, seated and "LEFT" or "BOTTOMLEFT", x + dx, (seated and 0 or -rowY) + dy)
	end
	local w, h = (self.clockAnchor or card):GetSize()
	self.clockPixel = pixel
	self.clockRight = Plain(w) and w / pixel or 0
	self.clockBottom = Plain(h) and h / pixel or 0
	self.clockInset, self.clockGap = x, Snap(card, MERIDIEM_GAP)
	self.clockRow = seated and 0 or rowY
	self:PlaceClock()

	self:PlaceSlider()
	self:PlaceInside()
end

function Face:Refresh()
	self:Paint()
	self:Layout()
end
