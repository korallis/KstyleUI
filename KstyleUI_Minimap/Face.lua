-- Face.lua: the minimap's face, shared by the live map and the preview: a square map in a gilt rim, the north plate on its top edge, the zone, coordinates and clock in a caption under it, and the hover group that holds the zoom slider.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets, Motion = K.L, K.Tokens, K.Widgets, K.Motion
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format

local Face = {}
Face.__index = Face
ns.Face = Face

local LEVEL_BOX, LEVEL_MAP, LEVEL_OVERLAY, LEVEL_REVEAL, LEVEL_WHEEL = 1, 2, 110, 111, 112
local LEVEL_PLATE = 111
local ZONE_ROLE = "names"
local NORTH_ROLE = "heading"
local CLOCK_ROLE = "number"
local COORDS_ROLE = "body"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SLIDER_WIDTH, SLIDER_HEIGHT, SLIDER_HIT = 2, 52, 12
local SLIDER_INSET = 11
local NORTH_SIZE = 8.5
local SHADE_ALPHA = 0.7

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
	top:SetPoint("TOPLEFT", area, "TOPLEFT", inset, -inset)
	top:SetPoint("TOPRIGHT", area, "TOPRIGHT", -inset, -inset)
	top:SetHeight(border)
	bottom:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", inset, inset)
	bottom:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -inset, inset)
	bottom:SetHeight(border)
	left:SetPoint("TOPLEFT", area, "TOPLEFT", inset, -inset)
	left:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", inset, inset)
	left:SetWidth(border)
	right:SetPoint("TOPRIGHT", area, "TOPRIGHT", -inset, -inset)
	right:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -inset, inset)
	right:SetWidth(border)
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

	local mapArea = CreateFrame("Frame", nil, box)
	mapArea:SetAllPoints(box)
	face.mapArea = mapArea

	local overlay = CreateFrame("Frame", nil, holder)
	Level(overlay, holder, LEVEL_OVERLAY)
	overlay:SetAllPoints(mapArea)
	face.overlay = overlay

	local mask = overlay:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("minimapMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(mapArea)
	face.mask = mask

	face.shade = NewLines(overlay, 0)
	face.rim = NewLines(overlay, 1)

	local plate = CreateFrame("Frame", nil, holder)
	Level(plate, holder, LEVEL_PLATE)
	plate.crystal = Widgets.CrystalDisc(plate)
	face.north = NewText(plate)
	face.north:SetText(L["N"])
	face.north:SetPoint("CENTER", plate, "CENTER", 0, 0)
	face.plate = plate

	local caption = CreateFrame("Frame", nil, overlay)
	caption:SetAllPoints(mapArea)
	face.caption = caption
	face.zone = NewText(caption)
	face.zone:SetJustifyH("LEFT")
	face.clock = NewText(caption)
	face.clock:SetJustifyH("RIGHT")
	face.zoneHit = CreateFrame("Button", nil, caption)
	face.zoneHit:SetAllPoints(face.zone)
	face.clockHit = CreateFrame("Button", nil, caption)
	face.clockHit:SetAllPoints(face.clock)

	local coordsFrame = CreateFrame("Frame", nil, caption)
	coordsFrame:SetAllPoints(caption)
	face.coordsFrame = coordsFrame
	face.coords = NewText(caption)
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
	Widgets.Size(track, SLIDER_WIDTH, SLIDER_HEIGHT)
	zoom:ClearAllPoints()
	zoom:SetPoint("LEFT", area, "LEFT", inset - Snap(area, (SLIDER_HIT - SLIDER_WIDTH) / 2), 0)
	Widgets.Size(zoom, SLIDER_HIT, SLIDER_HEIGHT)
	zoom.fill:ClearAllPoints()
	zoom.fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
	zoom.fill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT")
	self:PaintZoom()
end

function Face:Paint()
	local r, g, b = Style.Accent()
	Widgets.Tint(self.zoom.track, "track")
	self.zoom.fill:SetVertexColor(r, g, b, 1)
	self.zoom:SetShown(Settings.Get("zoom.slider"))
	for _, line in pairs(self.rim) do
		Widgets.Tint(line, "gilt")
	end
	for _, line in pairs(self.shade) do
		Widgets.Tint(line, "black", SHADE_ALPHA)
	end
	self.plate.crystal:SetRim(Tokens.Color("gilt"))
	self.plate.crystal:Paint()
	Style.Text(self.north, NORTH_ROLE, "zone", NORTH_SIZE)
	self.north:SetTextColor(Tokens.Color("gilt"))

	self.zoneSize = Style.Text(self.zone, ZONE_ROLE, "zone")
	self.clockSize = Style.Text(self.clock, CLOCK_ROLE, "clock")
	self.coordsSize = Style.Text(self.coords, COORDS_ROLE, "coords")
	self.clock:SetTextColor(Style.Color("textEmphasis"))
	self.coords:SetTextColor(Style.Color("muted"))

	local zoneShown, clockShown = Settings.Get("zone.shown"), Settings.Get("clock.shown")
	self.zone:SetShown(zoneShown)
	self.zoneHit:SetShown(zoneShown)
	self.clock:SetShown(clockShown)
	self.clockHit:SetShown(clockShown)
	self:SetZone(self.zoneText, self.pvpType)
	self:SetCoords(self.coordsText)
	self:SetRevealed(self.revealed)
end

function Face:Layout()
	local holder, area = self.holder, self.mapArea
	local width, height = holder:GetWidth(), holder:GetHeight()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		return
	end
	local side = math.min(width, height)
	self.mapSize = side

	local border = Widgets.Border(area)
	PlaceLines(self.rim, area, 0, border)
	PlaceLines(self.shade, area, border, border)

	Widgets.Size(self.plate, Format.NORTH, Format.NORTH)
	self.plate:ClearAllPoints()
	self.plate:SetPoint("CENTER", area, "TOP", 0, 0)

	local x, zoneY, rowY = Snap(area, Format.CAPTION_X), Snap(area, Format.ZONE_CENTER), Snap(area, Format.ROW_CENTER)
	local zone, clock, coords = self.zone, self.clock, self.coords
	zone:ClearAllPoints()
	zone:SetPoint("LEFT", area, "BOTTOMLEFT", x, -zoneY)
	zone:SetWidth(Snap(area, math.max(0, side - 2 * x)))
	coords:ClearAllPoints()
	coords:SetPoint("LEFT", area, "BOTTOMLEFT", x, -rowY)
	clock:ClearAllPoints()
	clock:SetPoint("RIGHT", area, "BOTTOMRIGHT", -x, -rowY)

	self:PlaceSlider()
end

function Face:Refresh()
	self:Paint()
	self:Layout()
end
