-- Preview.lua: the settings window's live preview of the minimap, drawn without touching Blizzard's Minimap.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets = K.L, K.Tokens, K.Widgets
local Settings, Face, Data, Format, Style, Column = ns.Settings, ns.Face, ns.Data, ns.Format, ns.Style, ns.Column

local Preview = {}
ns.Preview = Preview

local KEY = "minimap.main"
local SAMPLE_X, SAMPLE_Y = 0.453, 0.621
local GRAIN_ALPHA = 0.08
local PLAYER_SIZE = 8

local function Refresh(frame)
	local face = frame.face
	face:Refresh()
	local zone, pvpType = Data.Zone()
	if type(zone) ~= "string" or zone == "" then
		zone = L["Riverglades"]
	end
	face:SetZone(zone, pvpType)
	face:SetClock(Data.Clock(Settings.Get("clock.mode")) or Format.Time(14, 32, true))
	face:SetCoords(Format.Coords(SAMPLE_X, SAMPLE_Y, Settings.Get("coords.precision")))
	face:SetRotating(false)
	frame.column:Refresh()
	frame.player:SetVertexColor(Style.Accent())
end

function Preview.Build(parent)
	local element = K.Setup.Layouts.Element(KEY)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(element.width, element.height)
	frame:SetPoint("CENTER", parent, "CENTER")
	local face = Face.New(frame)
	frame.face = face

	local area = face.mapArea
	local terrain = area:CreateTexture(nil, "ARTWORK")
	terrain:SetColorTexture(Tokens.Color("white"))
	Widgets.Tint(terrain, "raised")
	terrain:SetAllPoints(area)
	local grain = area:CreateTexture(nil, "ARTWORK", nil, 1)
	grain:SetTexture((Tokens.Texture("noise")), "REPEAT", "REPEAT")
	grain:SetHorizTile(true)
	grain:SetVertTile(true)
	grain:SetVertexColor(Widgets.Rgba("white", GRAIN_ALPHA))
	grain:SetAllPoints(area)
	local player = area:CreateTexture(nil, "OVERLAY")
	player:SetTexture((Tokens.Texture("dot")))
	player:SetSize(PLAYER_SIZE, PLAYER_SIZE)
	player:SetPoint("CENTER", area, "CENTER")
	frame.player = player
	frame.column = Column.New(face, { preview = true })

	frame.Refresh = Refresh
	frame:Refresh()
	return frame
end
