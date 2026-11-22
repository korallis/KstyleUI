-- Face.lua: the minimap's face, shared by the live map and the preview: the round map in its Medallions ring, the north badge on its top edge, the zone in capitals above the card, the coordinates and the clock under it, and the hover group that holds the zoom slider.
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
local MERIDIEM_GAP = 2
local PLAQUE_HEIGHT = 18
local PLAQUE_PAD = 6
local RING_OUTER = 0.9189
local RING_SUBLEVEL = 3
local BADGE, BADGE_BAND = 16, 2
local ROUND_CORNER = 0.146
local INSIDE = { "zone", "clock", "coords", "difficulty", "perf" }
local currentFrame

Face.LEVEL_MAP = LEVEL_MAP

function Face.Frame()
	return currentFrame or Settings.Get("frame")
end

local function RingOuter()
	return Face.Frame() ~= "classic" and 118 / 150 or RING_OUTER
end

local function CaptionX()
	return Format.CAPTION_X + PLAQUE_PAD
end

function Face.MaskPath()
	return (Tokens.Texture((Widgets.TextureName("medMinimapMask"))))
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
	if Settings.Get("clearPlaques") then
		return max(Format.ROW_CENTER, (side or face.mapSize) * (1 / RingOuter() - 1) / 2 + PlaqueHeight(face) / 2 + 2 - Format.FRAME)
	end
	return Format.ROW_CENTER
end

local function ZoneCenter(face, side)
	local card = face.card
	local mark = max(face.plate.diamond.black:GetHeight() or 0, Extent(face.north)) / 2
	local clear = mark - Snap(card, Format.FRAME) + Widgets.Border(card)
	local y = max(Snap(card, Format.ZONE_CENTER), Snap(card, clear + Extent(face.zone) / 2))
	return Settings.Get("clearPlaques") and max(y, Snap(card, side * (1 / RingOuter() - 1) / 2 + PlaqueHeight(face) / 2 + 2 - Format.FRAME)) or y
end

function Face:Clamp(left, bottom, width, height, rootWidth, rootHeight)
	local factor = Widgets.ScaleFactor(self.holder)
	local side = min(width, height) / factor
	local overhang = side * (1 / RingOuter() - 1) / 2
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
	if Settings.Get("clearPlaques") then
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
	self.clock:SetText(time)
	if self.meridiem:GetText() ~= suffix then
		self.meridiem:SetText(suffix)
		self:PlaceClock()
		if Face.Moved("clock") then self:PlaceInside() end
	end
end

function Face:SyncPlaques()
	local plaques = self.plaques
	if not plaques then
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
	if self.clockAnchor and (self.coords:GetStringWidth() or 0) > self.coordsFit then self:PlaceRound() end
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
			local corner = h ~= 0 and v ~= 0 and Snap(area, side * ROUND_CORNER) or 0
			local x = edge + corner + (h == column and reserve or 0) + (corners[point] or 0)
				+ (point == "LEFT" and Snap(area, SLIDER_INSET + SLIDER_HIT) or 0)
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
	local inset = Snap(area, SLIDER_INSET)
	Widgets.Size(track, SLIDER_WIDTH, SLIDER_HEIGHT)
	track:ClearAllPoints()
	Widgets.Point(track, "LEFT", area, "LEFT", inset, 0)
	zoom:ClearAllPoints()
	Widgets.Point(zoom, "LEFT", area, "LEFT", inset - Snap(area, (SLIDER_HIT - SLIDER_WIDTH) / 2), 0)
	Widgets.Size(zoom, SLIDER_HIT, SLIDER_HEIGHT)
	zoom.fill:ClearAllPoints()
	Widgets.Point(zoom.fill, "BOTTOMLEFT", track, "BOTTOMLEFT")
	Widgets.Point(zoom.fill, "BOTTOMRIGHT", track, "BOTTOMRIGHT")
	self:PaintZoom()
end

function Face:PlaceRound()
	local ring, plaques = self.ring, self.plaques
	self.clockAnchor = nil
	if not ring then
		ring = self.overlay:CreateTexture(nil, "OVERLAY", nil, RING_SUBLEVEL)
		self.ring = ring
		plaques = {}
		for i = 1, 2 do
			local plaque = CreateFrame("Frame", nil, self.overlay)
			plaque:SetFrameLevel(self.overlay:GetFrameLevel())
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
	end
	if self.enamel then
		local r, g, b = Style.ClassColor()
		self.enamel:SetVertexColor(r, g, b, 0.35)
		self.runes:SetVertexColor(r, g, b, 0.25)
		self.enamel:SetShown(crest)
		self.runes:SetShown(crest)
	end
	local card, side = self.card, self.mapSize or 0
	Widgets.Size(ring, side / RingOuter(), side / RingOuter())
	ring:ClearAllPoints()
	Widgets.Point(ring, "CENTER", self.mapArea, "CENTER")
	ring:Show()
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
	local rowWidth = width
	if seated then
		local coords = Face.Moved("coords") and 0 or self.coords:GetStringWidth() or 0
		local clock = self.coordsAlone and 0 or (self.clock:GetStringWidth() or 0) + (self.meridiem:GetStringWidth() or 0)
		rowWidth = Snap(card, min(width, max(side * 0.6, coords + clock + 2 * PLAQUE_PAD + 12)))
		self.coordsFit = (Face.Moved("coords") or rowWidth >= width) and math.huge or max(coords, rowWidth - clock - 2 * PLAQUE_PAD - 12)
	end
	row:SetWidth(rowWidth)
	if seated then
		row:ClearAllPoints()
		Widgets.Point(row, "CENTER", ring, "BOTTOM")
		self.plate:ClearAllPoints()
		Widgets.Point(self.plate, "CENTER", self.mapArea, "TOP", 0, Snap(self.mapArea, side * (1 / RingOuter() - 1) / 4))
	end
	if seated and not self.gem then
		self.gem = self.plate:CreateTexture(nil, "ARTWORK", nil, 1)
		self.gem:SetTexture((Tokens.Texture("medLevelPlaque")))
		self.gem:SetAllPoints(self.plate)
	end
	if self.gem then self.gem:SetShown(seated) end
	for _, layer in pairs(self.plate.diamond) do layer:SetShown(not seated) end
	self:SyncPlaques()
end

function Face:Paint()
	currentFrame = Settings.Get("frame")
	self.layoutWidth = nil
	local r, g, b = Style.Accent()
	Widgets.Tint(self.zoom.track, "track")
	self.zoom.fill:SetVertexColor(r, g, b, 1)
	self.zoom:SetShown(Settings.Get("zoom.slider"))
	self.mask:SetTexture(Face.MaskPath(), MASK_WRAP, MASK_WRAP)
	self.zone:SetJustifyH("CENTER")
	local diamond = self.plate.diamond
	local mark = (Tokens.Texture("dot"))
	for _, layer in pairs(diamond) do
		layer:SetTexture(mark)
	end
	Widgets.Tint(diamond.black, "medOutline")
	Widgets.Tint(diamond.gilt, "medGunLit")
	Widgets.Tint(diamond.fill, "medFillBottom")
	Style.Text(self.north, NORTH_ROLE, "zone", NORTH_SIZE)
	self.north:SetTextColor(Widgets.Rgba("medText"))

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
	if self.layoutWidth == width and self.layoutHeight == height and self.layoutPixel == pixel then
		return
	end
	self.layoutWidth, self.layoutHeight, self.layoutPixel = width, height, pixel
	self.zonePlaced = nil
	local side = math.min(width, height)
	self.mapSize = side

	local frame = Snap(area, Format.FRAME)
	Widgets.Fill(card, area, -frame, -frame, -frame, -frame)

	local border = Widgets.Border(area)
	local plateSize = Snap(area, BADGE)
	Widgets.Size(self.plate, BADGE, BADGE)
	self.plate:ClearAllPoints()
	Widgets.Point(self.plate, "CENTER", area, "TOP", 0, 0)
	local diamond = self.plate.diamond
	local band = Snap(area, BADGE_BAND)
	diamond.black:SetSize(plateSize, plateSize)
	diamond.gilt:SetSize(plateSize - 2 * border, plateSize - 2 * border)
	diamond.fill:SetSize(max(0, plateSize - 2 * border - 2 * band), max(0, plateSize - 2 * border - 2 * band))

	for _, layer in pairs(diamond) do
		layer:ClearAllPoints()
		Widgets.Point(layer, "CENTER", self.plate, "CENTER")
	end
	Widgets.Point(self.north, "CENTER", self.plate, "CENTER")

	local x, rowY = Snap(card, CaptionX()), Snap(card, RowCenter(self))
	local coords = self.coords
	self:PlaceZone()
	if Settings.Get("clearPlaques") and Face.Frame() ~= "medallion" then
		self.plate:ClearAllPoints()
		Widgets.Point(self.plate, "CENTER", area, "TOP", 0, frame + self.zoneY - Snap(card, PlaqueHeight(self) / 2 + BADGE / 2 + 2))
	end
	self.coordsAlone = Settings.Get("clock.shown") ~= true or Face.Moved("clock")
	self:PlaceRound()
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
