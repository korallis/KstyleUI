-- Face.lua: the minimap's Lumen card: the lens plus its foot, a glass dome round the lens's top half over a frost foot card, so no square corners of glass show; the round lens and its mask, the gilt north mark on a crystal disc at the lens's top, the zone and clock foot, the zoom slider and the coordinates.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets = K.L, K.Tokens, K.Widgets
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format

local Face = {}
Face.__index = Face
ns.Face = Face

local LEVEL_BOX, LEVEL_MAP, LEVEL_OVERLAY, LEVEL_COMPASS, LEVEL_WHEEL = 1, 2, 110, 111, 112
local GAP = Tokens.Size("gapSmall")
local COMPASS_ROLE = "heading"
local ZONE_ROLE = "heading"
local CLOCK_ROLE = "number"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SLIDER_WIDTH, SLIDER_HEIGHT, SLIDER_HIT = 2, 52, 12
local SLIDER_INSET = 11

Face.LEVEL_MAP = LEVEL_MAP

local function Level(frame, holder, offset)
	frame:SetFrameLevel(holder:GetFrameLevel() + offset)
end

local function Snap(frame, units)
	return Widgets.Snap(frame, units)
end

local function NewDisc(card, sublevel)
	local disc = card:CreateTexture(nil, "BORDER", nil, sublevel)
	disc:SetTexture((Widgets.LumenTexture("lensMask")))
	disc:SetTexCoord(0, 1, 0, 0.5)
	return disc
end

local function NewText(parent)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetWordWrap(false)
	return text
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
	local face = setmetatable({ holder = holder, rotating = false, onZoom = opts.onZoom, zoomShare = 0 }, Face)

	local box = CreateFrame("Frame", nil, holder)
	Level(box, holder, LEVEL_BOX)
	box:SetAllPoints(holder)
	face.box = box
	local foot = CreateFrame("Frame", nil, box)
	Level(foot, holder, LEVEL_BOX)
	face.foot = foot
	face.chrome = Widgets.Chrome(foot, { shape = "panel" })
	local dome = CreateFrame("Frame", nil, foot)
	Level(dome, holder, LEVEL_BOX)
	dome.edge, dome.fill, dome.frost = NewDisc(foot, 1), NewDisc(foot, 2), NewDisc(foot, 3)
	face.dome = dome

	local mapArea = CreateFrame("Frame", nil, box)
	face.mapArea = mapArea

	local overlay = CreateFrame("Frame", nil, holder)
	Level(overlay, holder, LEVEL_OVERLAY)
	overlay:SetAllPoints(mapArea)
	face.overlay = overlay

	local mask = overlay:CreateMaskTexture()
	mask:SetTexture((Widgets.LumenTexture("lensMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(mapArea)
	face.mask = mask

	local strip = CreateFrame("Frame", nil, box)
	Level(strip, holder, LEVEL_OVERLAY)
	face.strip = strip
	face.zone = NewText(strip)
	face.zone:SetJustifyH("LEFT")
	face.clock = NewText(strip)
	face.clock:SetJustifyH("RIGHT")

	face.zoneHit = CreateFrame("Button", nil, strip)
	face.zoneHit:SetAllPoints(face.zone)
	face.clockHit = CreateFrame("Button", nil, strip)
	face.clockHit:SetAllPoints(face.clock)

	local plate = CreateFrame("Frame", nil, holder)
	Level(plate, holder, LEVEL_COMPASS)
	plate.crystal = Widgets.CrystalDisc(plate)
	face.compassPlate = plate
	face.compass = NewText(plate)
	face.compass:SetText(L["N"])
	face.compass:SetPoint("CENTER", plate, "CENTER")

	local zoom = CreateFrame("Frame", nil, overlay)
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

	local coordsFrame = CreateFrame("Frame", nil, overlay)
	face.coordsFrame = coordsFrame
	face.coords = NewText(coordsFrame)
	face.coords:SetPoint("CENTER", coordsFrame, "CENTER")

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

function Face:SetRotating(rotating)
	self.rotating = rotating == true
	local shown = Settings.Get("compass") and not self.rotating
	self.compass:SetShown(shown)
	self.compassPlate:SetShown(shown)
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
	local dome = self.dome
	local sr, sg, sb = Tokens.Color("surface")
	dome.fill:SetVertexColor(sr, sg, sb, Widgets.Setting("panelOpacity"))
	dome.frost:SetVertexColor(Tokens.Color("glass"))
	dome.edge:SetVertexColor(Tokens.Color("edgeInner"))
	Widgets.Tint(self.zoom.track, "track")
	self.zoom.fill:SetVertexColor(r, g, b, 1)
	self.zoom:SetShown(Settings.Get("zoom.slider"))

	self.zoneSize = Style.Text(self.zone, ZONE_ROLE, "zone")
	self.clockSize = Style.Text(self.clock, CLOCK_ROLE, "clock")
	self.coordsSize = Style.Text(self.coords, "number", "coords")
	self.compassSize = Style.Text(self.compass, COMPASS_ROLE, "zone", Tokens.Size(COMPASS_ROLE))
	self.clock:SetTextColor(Style.Color("textEmphasis"))
	self.coords:SetTextColor(Style.Color("textEmphasis"))
	self.compass:SetTextColor(Widgets.LumenColor("gilt"))
	self.compassPlate.crystal:Restyle()

	local zoneShown, clockShown = Settings.Get("zone.shown"), Settings.Get("clock.shown")
	self.zone:SetShown(zoneShown)
	self.zoneHit:SetShown(zoneShown)
	self.clock:SetShown(clockShown)
	self.clockHit:SetShown(clockShown)
	self.strip:SetShown(zoneShown or clockShown)
	self:SetZone(self.zoneText, self.pvpType)
	self:SetCoords(self.coordsText)
	self:SetRotating(self.rotating)
end

function Face:Layout()
	local holder, box = self.holder, self.box
	local width, height = holder:GetWidth(), holder:GetHeight()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		return
	end
	local pad = self.chrome:Inset()
	local footed = Settings.Get("zone.shown") or Settings.Get("clock.shown")
	local foot = footed and Format.FOOT or Format.RIM
	local left, top, lens = Format.Lens(width, height, Format.RIM, foot)
	left, top, lens = Snap(box, left), Snap(box, top), Snap(box, lens)
	self.pad, self.mapLeft, self.mapSize = pad, left, lens
	local area = self.mapArea
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", box, "TOPLEFT", left, -top)
	area:SetSize(lens, lens)

	local rim = Snap(box, Format.RIM)
	local across = lens + 2 * rim
	local dome = self.dome
	dome:ClearAllPoints()
	dome:SetPoint("TOPLEFT", box, "TOPLEFT", left - rim, -(top - rim))
	dome:SetSize(across, across / 2)
	local line = Widgets.Border(box)
	for _, disc in ipairs({ dome.fill, dome.frost }) do
		disc:ClearAllPoints()
		disc:SetAllPoints(dome)
	end
	dome.edge:ClearAllPoints()
	dome.edge:SetPoint("BOTTOMLEFT", dome, "BOTTOMLEFT", -line, 0)
	dome.edge:SetSize(across + 2 * line, across / 2 + line)
	local card = self.foot
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", box, "TOPLEFT", left - rim, -Snap(box, top + lens / 2 - self.chrome:Radius()))
	card:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", left - rim, 0)
	card:SetWidth(across)

	local strip = self.strip
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", Snap(box, pad), 0)
	strip:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -Snap(box, pad), 0)
	strip:SetHeight(Snap(box, foot))
	local clock, zone = self.clock, self.zone
	clock:ClearAllPoints()
	clock:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
	zone:ClearAllPoints()
	zone:SetPoint("LEFT", strip, "LEFT", 0, 0)
	if Settings.Get("clock.shown") then
		zone:SetPoint("RIGHT", clock, "LEFT", -Snap(strip, Tokens.Size("gapMedium")), 0)
	else
		zone:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
	end

	local plate = self.compassPlate
	plate:ClearAllPoints()
	plate:SetPoint("CENTER", area, "TOP", 0, 0)
	plate:SetSize(Snap(area, Format.COMPASS_PLATE), Snap(area, Format.COMPASS_PLATE))

	self:PlaceSlider()

	local rise = Snap(area, GAP)
	local coordsFrame = self.coordsFrame
	coordsFrame:ClearAllPoints()
	coordsFrame:SetHeight(Snap(coordsFrame, self.coordsSize or 0))
	if Settings.Get("coords.position") == "bottom" then
		coordsFrame:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, rise)
		coordsFrame:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, rise)
	else
		local drop = rise + (plate:IsShown() and Snap(area, Format.COMPASS_PLATE / 2) or 0)
		coordsFrame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -drop)
		coordsFrame:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -drop)
	end
end

function Face:Refresh()
	self:Paint()
	self:Layout()
end
