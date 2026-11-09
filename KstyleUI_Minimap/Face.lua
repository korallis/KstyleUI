-- Face.lua: the minimap's face, shared by the live map and the preview: a square map inside a thin rim whose chamfer meets the mask's cut, the zone band along the map's top edge and the clock band along its bottom edge on soft dark fades, the coordinates, and the hover group that holds the zoom slider.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Motion = K.Tokens, K.Widgets, K.Motion
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format

local Face = {}
Face.__index = Face
ns.Face = Face

local LEVEL_BOX, LEVEL_MAP, LEVEL_OVERLAY, LEVEL_REVEAL, LEVEL_WHEEL = 1, 2, 110, 111, 112
local ZONE_ROLE = "heading"
local CLOCK_ROLE = "number"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SLIDER_WIDTH, SLIDER_HEIGHT, SLIDER_HIT = 2, 52, 12
local SLIDER_INSET = 11
local SHEEN_REACH = 0.55
local BAND_PAD = Tokens.Size("gapMedium")

Face.LEVEL_MAP = LEVEL_MAP

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

local function NewBand(overlay, flipped)
	local band = CreateFrame("Frame", nil, overlay)
	local scrim = band:CreateTexture(nil, "BACKGROUND")
	scrim:SetTexture((Tokens.Texture("barSheen")))
	if flipped then
		scrim:SetTexCoord(0, 1, 1, 0)
	end
	band.scrim = scrim
	return band
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value)
end

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

function Face.New(holder, opts)
	opts = opts or {}
	local face = setmetatable({ holder = holder, onZoom = opts.onZoom, zoomShare = 0, revealed = false }, Face)

	local box = CreateFrame("Frame", nil, holder)
	Level(box, holder, LEVEL_BOX)
	box:SetAllPoints(holder)
	face.box = box
	local chrome = Widgets.Chrome(box, { shape = "socket", shadow = false, grain = false, gilt = false })
	chrome:SetFillRGBA(0, 0, 0, 0)
	Widgets.ShowSlice(chrome.fill, false)
	face.chrome = chrome

	local mapArea = CreateFrame("Frame", nil, box)
	face.mapArea = mapArea

	local overlay = CreateFrame("Frame", nil, holder)
	Level(overlay, holder, LEVEL_OVERLAY)
	overlay:SetAllPoints(mapArea)
	face.overlay = overlay

	local mask = overlay:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("minimapMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(mapArea)
	face.mask = mask

	face.zoneBand = NewBand(overlay, false)
	face.zone = NewText(face.zoneBand)
	face.zone:SetJustifyH("CENTER")
	face.clockBand = NewBand(overlay, true)
	face.clock = NewText(face.clockBand)
	face.clock:SetJustifyH("RIGHT")
	face.zoneHit = CreateFrame("Button", nil, face.zoneBand)
	face.zoneHit:SetAllPoints(face.zone)
	face.clockHit = CreateFrame("Button", nil, face.clockBand)
	face.clockHit:SetAllPoints(face.clock)

	local coordsFrame = CreateFrame("Frame", nil, face.clockBand)
	coordsFrame:SetAllPoints(face.clockBand)
	face.coordsFrame = coordsFrame
	face.coords = NewText(face.clockBand)
	face.coords:SetJustifyH("LEFT")

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
end

function Face:SetClock(text)
	self.clock:SetText(text or "")
end

function Face:SetCoords(text)
	self.coordsText = text
	self.coords:SetText(text or "")
	self.coords:SetShown(text ~= nil and Settings.Get("coords.shown"))
end

function Face:SetRevealed(on)
	self.revealed = on == true
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
	track:ClearAllPoints()
	track:SetPoint("LEFT", area, "LEFT", inset, 0)
	track:SetSize(Snap(area, SLIDER_WIDTH), Snap(area, SLIDER_HEIGHT))
	zoom:ClearAllPoints()
	zoom:SetPoint("LEFT", area, "LEFT", inset - Snap(area, (SLIDER_HIT - SLIDER_WIDTH) / 2), 0)
	zoom:SetSize(Snap(area, SLIDER_HIT), Snap(area, SLIDER_HEIGHT))
	zoom.fill:ClearAllPoints()
	zoom.fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
	zoom.fill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT")
	self:PaintZoom()
end

function Face:Paint()
	local r, g, b = Style.Accent()
	self.chrome:SetEdge("edgeInner")
	Widgets.Tint(self.zoom.track, "track")
	self.zoom.fill:SetVertexColor(r, g, b, 1)
	self.zoom:SetShown(Settings.Get("zoom.slider"))
	for _, band in ipairs({ self.zoneBand, self.clockBand }) do
		band.scrim:SetVertexColor(Tokens.Color("shadow"))
	end

	self.zoneSize = Style.Text(self.zone, ZONE_ROLE, "zone")
	self.clockSize = Style.Text(self.clock, CLOCK_ROLE, "clock")
	self.coordsSize = Style.Text(self.coords, "number", "coords")
	self.clock:SetTextColor(Style.Color("textEmphasis"))
	self.coords:SetTextColor(Style.Color("textEmphasis"))

	local zoneShown, clockShown, coordsShown = Settings.Get("zone.shown"), Settings.Get("clock.shown"), Settings.Get("coords.shown")
	self.zone:SetShown(zoneShown)
	self.zoneHit:SetShown(zoneShown)
	self.zoneBand:SetShown(zoneShown)
	self.clock:SetShown(clockShown)
	self.clockHit:SetShown(clockShown)
	self.clockBand:SetShown(clockShown or coordsShown)
	self:SetZone(self.zoneText, self.pvpType)
	self:SetCoords(self.coordsText)
	self:SetRevealed(self.revealed)
end

function Face:Layout()
	local holder, box = self.holder, self.box
	local width, height = holder:GetWidth(), holder:GetHeight()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		return
	end
	local inset = Snap(box, Format.INSET)
	local side = math.min(width, height) - 2 * inset
	self.mapSize = side
	local area = self.mapArea
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
	area:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
	self.chrome:SetRadius(Format.Chamfer(side))

	local band = Snap(area, Format.BAND)
	local reach = Snap(area, Format.BAND / SHEEN_REACH)
	local pad = Snap(area, BAND_PAD)
	local zoneBand, clockBand = self.zoneBand, self.clockBand
	zoneBand:ClearAllPoints()
	zoneBand:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
	zoneBand:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
	zoneBand:SetHeight(band)
	zoneBand.scrim:ClearAllPoints()
	zoneBand.scrim:SetPoint("TOPLEFT", zoneBand, "TOPLEFT", 0, 0)
	zoneBand.scrim:SetPoint("TOPRIGHT", zoneBand, "TOPRIGHT", 0, 0)
	zoneBand.scrim:SetHeight(reach)
	clockBand:ClearAllPoints()
	clockBand:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, 0)
	clockBand:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 0)
	clockBand:SetHeight(band)
	clockBand.scrim:ClearAllPoints()
	clockBand.scrim:SetPoint("BOTTOMLEFT", clockBand, "BOTTOMLEFT", 0, 0)
	clockBand.scrim:SetPoint("BOTTOMRIGHT", clockBand, "BOTTOMRIGHT", 0, 0)
	clockBand.scrim:SetHeight(reach)

	local zone, clock, coords = self.zone, self.clock, self.coords
	zone:ClearAllPoints()
	zone:SetPoint("CENTER", zoneBand, "CENTER", 0, 0)
	zone:SetWidth(math.max(0, width - 2 * inset - 2 * pad))
	clock:ClearAllPoints()
	coords:ClearAllPoints()
	coords:SetPoint("LEFT", clockBand, "LEFT", pad, 0)
	if Settings.Get("coords.shown") then
		clock:SetPoint("RIGHT", clockBand, "RIGHT", -pad, 0)
	else
		clock:SetPoint("CENTER", clockBand, "CENTER", 0, 0)
	end

	self:PlaceSlider()
end

function Face:Refresh()
	self:Paint()
	self:Layout()
end
