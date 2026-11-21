-- Preview.lua: the settings window's live preview of the minimap, drawn without touching Blizzard's Minimap, with its caption under the map.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Widgets = K.L, K.Tokens, K.Widgets
local Settings, Face, Data, Format, Style, Column = ns.Settings, ns.Face, ns.Data, ns.Format, ns.Style, ns.Column

local Preview = {}
ns.Preview = Preview

local build
function Preview.Build(...)
	if build then return build(...) end
	local KEY = "minimap.main"
	local SAMPLE_X, SAMPLE_Y = 0.453, 0.621
	local GRAIN_ALPHA = 0.08
	local PLAYER_SIZE = 8
	local SAMPLE_ZOOM, SAMPLE_ZOOM_LEVELS = 5, 6
	local SAMPLE_GROUP, SAMPLE_FPS, SAMPLE_MS = 25, 60, 42
	local SAMPLE_ADDONS = { { "BugSack", 132176 }, { "Details", 132153 }, { "WeakAuras", 132111 } }

	local function Refresh(frame, fitted)
		local face, drawer = frame.face, frame.column.drawer
		local width, scale = K.Setup.Layouts.Element(KEY).width, frame:GetScale()
		frame:SetScale(fitted and scale or 1)
		Widgets.Size(frame, width + 2 * Format.FRAME, width + Format.HEADING + Format.CAPTION + 2 * Format.FRAME)
		Widgets.Size(face.holder, width, width)
		Widgets.Point(face.holder, "CENTER", frame, "CENTER", 0, Widgets.Snap(face.holder, (Format.CAPTION - Format.HEADING) / 2))
		Widgets.Size(frame.player, PLAYER_SIZE, PLAYER_SIZE)
		Widgets.Point(frame.player, "CENTER", face.mapArea, "CENTER")
		frame:SetScale(scale)
		if Settings.Get("column.drawer") and Settings.Get("drawer.behaviour") == "open" then
			drawer:Refresh()
		else
			drawer:Close(true)
			drawer:Layout()
		end
		face:Refresh()
		local zone, pvpType = Data.Zone()
		if type(zone) ~= "string" or zone == "" then
			zone = L["Riverglades"]
		end
		face:SetZone(zone, pvpType)
		face:SetClock(Data.Clock(Settings.Get("clock.mode")) or Format.Time(14, 32, true))
		face:SetCoords(Format.Coords(SAMPLE_X, SAMPLE_Y, Settings.Get("coords.precision")))
		face:SetDifficulty(Data.Difficulty() or L["%dH"]:format(SAMPLE_GROUP))
		face:SetPerf(ns.Map.PerfText(SAMPLE_FPS, SAMPLE_MS))
		face:SetRevealed(true)
		face:SetZoom(SAMPLE_ZOOM, SAMPLE_ZOOM_LEVELS)
		frame.column:Refresh()
		frame.player:SetVertexColor(Style.Accent())
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		local face = Face.New(CreateFrame("Frame", nil, frame))
		frame.face = face

		local area = face.mapArea
		local terrain = area:CreateTexture(nil, "ARTWORK")
		terrain:SetColorTexture(Tokens.Color("white"))
		local r, g, b = Tokens.Color("buttonFill")
		terrain:SetVertexColor(r, g, b, 1)
		terrain:SetAllPoints(area)
		terrain:AddMaskTexture(face.mask)
		frame.terrain = terrain
		local grain = area:CreateTexture(nil, "ARTWORK", nil, 1)
		grain:SetTexture((Tokens.Texture("noise")), "REPEAT", "REPEAT")
		grain:SetHorizTile(true)
		grain:SetVertTile(true)
		grain:SetVertexColor(Widgets.Rgba("white", GRAIN_ALPHA))
		grain:SetAllPoints(area)
		grain:AddMaskTexture(face.mask)
		local player = area:CreateTexture(nil, "OVERLAY")
		player:SetTexture((Tokens.Texture("dot")))
		frame.player = player
		area:EnableMouse(true)
		area:SetScript("OnMouseUp", function(_, button)
			if button == "MiddleButton" and Settings.Get("microMenu") and ns.Map.IsRunning() then ns.Micro.Toggle(frame) end
		end)
		area:SetScript("OnLeave", ns.Micro.CheckHover)
		frame.column = Column.New(face, { preview = true })
		local drawer = ns.Drawer.New(frame.column, { preview = true })
		drawer.panel:SetFrameStrata("DIALOG")
		for _, sample in ipairs(SAMPLE_ADDONS) do
			local button = CreateFrame("Button", nil, drawer.panel)
			local icon = button:CreateTexture(nil, "ARTWORK")
			icon:SetTexture(sample[2])
			drawer.adopted[button], drawer.order[#drawer.order + 1] = { name = sample[1], icon = icon }, button
		end
		drawer.active, frame.column.drawer = true, drawer

		frame.Refresh, frame.Restyle = Refresh, function(self) Refresh(self, true) end
		Widgets.Track(frame):Refresh()
		return frame
	end
	return build(...)
end
