-- Face.lua: the minimap's visible frame: the chamfered square, the zone and clock strip, the north mark and the coordinates.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets = K.L, K.Tokens, K.Widgets
local Settings, Style, Format = ns.Settings, ns.Style, ns.Format

local Face = {}
Face.__index = Face
ns.Face = Face

local LEVEL_BOX, LEVEL_MAP, LEVEL_OVERLAY, LEVEL_WHEEL = 1, 2, 6, 8
local MAP_INSET = Tokens.Size("gapSmall")
local GAP = Tokens.Size("gapSmall")
local COMPASS_ROLE = "body"
local PLATE_RISE = Tokens.Size("chamferTile")
local FOOTER = 22 - MAP_INSET
local ZONE_PAD = 11 - MAP_INSET
local CLOCK_PAD = 12 - MAP_INSET
local DIVIDER_GAP = 9
local PLATE_WIDTH, PLATE_HEIGHT = 25, 16
local min = math.min

Face.LEVEL_MAP = LEVEL_MAP

local function Level(frame, holder, offset)
	frame:SetFrameLevel(holder:GetFrameLevel() + offset)
end

local function ClearCentre(chrome)
	chrome.fill[5]:Hide()
	chrome.shadow[5]:Hide()
	if chrome.noise then
		chrome.noise:Hide()
	end
end

local function NewText(parent)
	local text = Widgets.FontString(parent, "OVERLAY")
	text:SetWordWrap(false)
	return text
end

function Face.New(holder, opts)
	opts = opts or {}
	local face = setmetatable({ holder = holder, rotating = false }, Face)

	local box = CreateFrame("Frame", nil, holder)
	Level(box, holder, LEVEL_BOX)
	face.box = box
	local chrome = Widgets.Chrome(box, { shape = "panel" })
	local paint = chrome.Paint
	chrome.Paint = function(self)
		paint(self)
		ClearCentre(self)
	end
	ClearCentre(chrome)
	face.chrome = chrome

	local mapArea = CreateFrame("Frame", nil, box)
	face.mapArea = mapArea

	local overlay = CreateFrame("Frame", nil, holder)
	Level(overlay, holder, LEVEL_OVERLAY)
	overlay:SetAllPoints(mapArea)
	face.overlay = overlay

	local strip = CreateFrame("Frame", nil, overlay)
	strip.fill = strip:CreateTexture(nil, "BACKGROUND")
	strip.fill:SetColorTexture(Tokens.Color("white"))
	strip.fill:SetAllPoints(strip)
	strip.line = strip:CreateTexture(nil, "BORDER")
	strip.line:SetColorTexture(Tokens.Color("white"))
	strip.divider = strip:CreateTexture(nil, "BORDER")
	strip.divider:SetColorTexture(Tokens.Color("white"))
	face.strip = strip
	face.zone = NewText(strip)
	face.zone:SetJustifyH("LEFT")
	face.clock = NewText(strip)
	face.clock:SetJustifyH("RIGHT")

	face.zoneHit = CreateFrame("Button", nil, strip)
	face.zoneHit:SetAllPoints(face.zone)
	face.clockHit = CreateFrame("Button", nil, strip)
	face.clockHit:SetAllPoints(face.clock)

	local plate = CreateFrame("Frame", nil, overlay)
	plate.slice = Widgets.NineSlice(plate, "chamferTile", "BACKGROUND", 0)
	face.compassPlate = plate
	face.compass = NewText(plate)
	face.compass:SetText(L["N"])

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
		self.zone:SetText(text:upper())
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
	local north = Settings.Get("compass") and not self.rotating
	self.compass:SetShown(north)
	self.compassPlate:SetShown(north)
end

function Face:Paint()
	local r, g, b = Style.Accent()
	self.chrome:SetEdgeRGBA(r, g, b, 1)
	local sr, sg, sb = Tokens.Color("surface")
	self.strip.fill:SetVertexColor(sr, sg, sb, Settings.Get("strip.opacity"))
	Widgets.Tint(self.strip.line, "edgeInner")
	Widgets.Tint(self.strip.divider, "edgeInner")
	Widgets.ColorSlice(self.compassPlate.slice, sr, sg, sb, Settings.Get("strip.opacity"))

	self.zoneSize = Style.Text(self.zone, "caption", "zone")
	self.clockSize = Style.Text(self.clock, "caption", "clock")
	self.coordsSize = Style.Text(self.coords, "number", "coords")
	self.compassSize = Style.Text(self.compass, COMPASS_ROLE, "zone", Tokens.Size(COMPASS_ROLE))
	self.clock:SetTextColor(Style.Color("textEmphasis"))
	self.coords:SetTextColor(Style.Color("textEmphasis"))
	self.compass:SetTextColor(Style.Color("textEmphasis"))

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

local function Snap(frame, units)
	return Widgets.Snap(frame, units)
end

function Face:Layout()
	local holder = self.holder
	local width, height = holder:GetWidth(), holder:GetHeight()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		return
	end
	local side = Settings.Get("column.side")
	local left, boxWidth, boxHeight = 0, width, height
	if side ~= "inside" then
		local reserve = Settings.Get("column.size") + Settings.Get("column.spacing")
		left, boxWidth = Format.MapRect(width, height, side, reserve)
		boxHeight = boxWidth
	end
	left, boxWidth, boxHeight = Snap(holder, left), Snap(holder, boxWidth), Snap(holder, boxHeight)
	local box = self.box
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", holder, "TOPLEFT", left, 0)
	box:SetSize(boxWidth, boxHeight)

	local inset = Snap(box, MAP_INSET)
	local size = min(boxWidth, boxHeight) - 2 * inset
	self.mapLeft, self.mapSize, self.inset = left, size, inset
	local area = self.mapArea
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
	area:SetSize(size, size)

	local zoneShown, clockShown = Settings.Get("zone.shown"), Settings.Get("clock.shown")
	local tallest = 0
	if zoneShown then
		tallest = self.zoneSize or 0
	end
	if clockShown and (self.clockSize or 0) > tallest then
		tallest = self.clockSize
	end
	local strip = self.strip
	local stripHeight = Snap(strip, math.max(FOOTER, tallest + 2 * GAP))
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT")
	strip:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
	strip:SetHeight(stripHeight)
	local border = Widgets.Border(strip)
	strip.line:ClearAllPoints()
	strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT")
	strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT")
	strip.line:SetHeight(border)

	local clockPad = Snap(strip, CLOCK_PAD)
	local clock, zone = self.clock, self.zone
	clock:ClearAllPoints()
	clock:SetPoint("RIGHT", strip, "RIGHT", -clockPad, 0)
	zone:ClearAllPoints()
	zone:SetPoint("LEFT", strip, "LEFT", Snap(strip, ZONE_PAD), 0)
	local divider = strip.divider
	divider:ClearAllPoints()
	divider:SetPoint("RIGHT", clock, "LEFT", -Snap(strip, DIVIDER_GAP), 0)
	divider:SetSize(border, stripHeight - 2 * Snap(strip, GAP))
	divider:SetShown(zoneShown and clockShown)
	if clockShown then
		zone:SetPoint("RIGHT", divider, "LEFT", -Snap(strip, GAP), 0)
	else
		zone:SetPoint("RIGHT", strip, "RIGHT", -clockPad, 0)
	end

	local top = Snap(area, GAP)
	local plate = self.compassPlate
	plate:ClearAllPoints()
	plate:SetPoint("TOP", area, "TOP", 0, Snap(area, PLATE_RISE))
	Widgets.Size(plate, PLATE_WIDTH, PLATE_HEIGHT)
	Widgets.LayoutSlice(plate.slice, plate, PLATE_RISE, 0)
	self.compass:ClearAllPoints()
	self.compass:SetPoint("CENTER", plate, "CENTER", 0, 0)

	local coordsFrame = self.coordsFrame
	coordsFrame:ClearAllPoints()
	coordsFrame:SetHeight(Snap(coordsFrame, self.coordsSize or 0))
	if Settings.Get("coords.position") == "bottom" then
		local below = (zoneShown or clockShown) and stripHeight or 0
		coordsFrame:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, below + top)
		coordsFrame:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, below + top)
	else
		local offset = top
		if Settings.Get("compass") then
			offset = offset + Snap(area, PLATE_HEIGHT - PLATE_RISE)
		end
		coordsFrame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -offset)
		coordsFrame:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -offset)
	end
end

function Face:Refresh()
	self:Paint()
	self:Layout()
end
