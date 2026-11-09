-- Map.lua: the live minimap: KstyleUI's Lumen card round Blizzard's Minimap as a round lens, the Blizzard pieces it hides, wheel and slider zoom and the foot's data.
local _, ns = ...

local K = KstyleUI
local L, Widgets = K.L, K.Widgets
local Settings, Face, Data, Column, SecureClick, Drawer = ns.Settings, ns.Face, ns.Data, ns.Column, ns.SecureClick, ns.Drawer

local Map = {}
ns.Map = Map

local MODULE = Settings.MODULE
local KEY = "minimap.main"
local HOLDER_NAME = "KstyleUI_Minimap"
local STRATA = "BACKGROUND"
local BLIZZARD_MASK = "ui-hud-minimap-frame-generic-mask"
local HYBRID_ADDON = "Blizzard_HybridMinimap"
local CLOCK_INTERVAL = 1
local COORDS_INTERVAL = 0.2
local MIN_HEIGHT, MAX_HEIGHT = 120, 480
local PIECE_COUNT = 5
local BLOB_METHODS = { "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local COLUMN_EVENTS = { "UPDATE_PENDING_MAIL", "CALENDAR_UPDATE_PENDING_INVITES" }
local QUEUE_CALLBACK = "QueueStatusUpdate.QueuesUpdated"
local MOVE_START = { "PLAYER_STARTED_MOVING", "PLAYER_CONTROL_LOST" }
local MOVE_STOP = { "PLAYER_STOPPED_MOVING", "PLAYER_CONTROL_GAINED" }

local running = false
local original
local configHooked, zoomHooked = false, false
local waitingForEditMode = false
local queueFaded, queueHooked = false, false
local checkAdded = false
local ticker
local clockElapsed, coordsElapsed = 0, 0
local zoomToken = 0
local moving = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function MaskPath()
	return (Widgets.LumenTexture("lensMask"))
end

local function RoundShape()
	return "ROUND"
end

local function ApplyMask()
	local minimap = Minimap
	if minimap and type(minimap.SetMaskTexture) == "function" then
		minimap:SetMaskTexture(MaskPath())
	end
end

local function SetBlobRings(scalar)
	local minimap = Minimap
	for _, method in ipairs(BLOB_METHODS) do
		local fn = minimap[method]
		if type(fn) == "function" then
			fn(minimap, scalar)
		end
	end
end

local function MaskHybrid()
	local hybrid = HybridMinimap
	local mask = hybrid and hybrid.CircleMask
	if mask and type(mask.SetTexture) == "function" then
		mask:SetTexture(MaskPath(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		Log("the hybrid minimap uses the square mask")
	end
end

local function UpdateZone()
	local face = Map.face
	face:SetZone(Data.Zone())
end

local function UpdateClock()
	Map.face:SetClock(Data.Clock(Settings.Get("clock.mode")))
end

local function UpdateCoords()
	Map.face:SetCoords(Data.Coords(Settings.Get("coords.precision")))
end

local function UpdateCompass()
	Map.face:SetRotating(Data.Rotating())
end

local function ClockOnUpdate(_, elapsed)
	clockElapsed = clockElapsed + elapsed
	if clockElapsed >= CLOCK_INTERVAL then
		clockElapsed = 0
		UpdateClock()
	end
end

local function StopClock()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if Map.face then
		Map.face.strip:SetScript("OnUpdate", nil)
	end
end

local function SyncClock()
	if not (running and Settings.Get("clock.shown")) then
		StopClock()
		return
	end
	if ticker or Map.face.strip:GetScript("OnUpdate") then
		return
	end
	if C_Timer and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(CLOCK_INTERVAL, UpdateClock)
	else
		clockElapsed = 0
		Map.face.strip:SetScript("OnUpdate", ClockOnUpdate)
		Log("C_Timer.NewTicker is missing; the clock counts with OnUpdate")
	end
end

local function CoordsOnUpdate(_, elapsed)
	coordsElapsed = coordsElapsed + elapsed
	if coordsElapsed >= COORDS_INTERVAL then
		coordsElapsed = 0
		UpdateCoords()
	end
end

local function SyncCoords()
	local frame = Map.face and Map.face.coordsFrame
	if not frame then
		return
	end
	if running and moving and Settings.Get("coords.shown") then
		if not frame:GetScript("OnUpdate") then
			coordsElapsed = 0
			frame:SetScript("OnUpdate", CoordsOnUpdate)
		end
	else
		frame:SetScript("OnUpdate", nil)
	end
end

local function StartCoords()
	moving = true
	SyncCoords()
end

local function StopCoords()
	moving = false
	SyncCoords()
	if running and Map.face then
		UpdateCoords()
	end
end

local function ResetZoom(token)
	if running and token == zoomToken and Minimap and type(Minimap.SetZoom) == "function" and Settings.Get("zoom.reset") then
		Minimap:SetZoom(0)
	end
end

local function ArmReset()
	if not Settings.Get("zoom.reset") then
		return
	end
	zoomToken = zoomToken + 1
	local token = zoomToken
	C_Timer.After(Settings.Get("zoom.delay"), function()
		ResetZoom(token)
	end)
end

local function CanZoom(minimap)
	return minimap and type(minimap.GetZoom) == "function" and type(minimap.SetZoom) == "function"
		and type(minimap.GetZoomLevels) == "function"
end

local function UpdateZoom()
	local minimap = Minimap
	if CanZoom(minimap) and Map.face then
		Map.face:SetZoom(minimap:GetZoom(), minimap:GetZoomLevels())
	end
end

local function ApplyZoom(zoom)
	local minimap = Minimap
	if not CanZoom(minimap) or zoom == nil then
		return
	end
	local current = minimap:GetZoom()
	if ns.Format.IsNumber(current) and current == zoom then
		return
	end
	minimap:SetZoom(zoom)
	ArmReset()
	UpdateZoom()
end

local function OnWheel(_, delta)
	if not Settings.Get("zoom.wheel") then
		return
	end
	local minimap = Minimap
	if not CanZoom(minimap) then
		return
	end
	ApplyZoom(ns.Format.NextZoom(minimap:GetZoom(), minimap:GetZoomLevels(), delta))
end

local function OnSliderZoom(share)
	local minimap = Minimap
	if not CanZoom(minimap) then
		return
	end
	ApplyZoom(ns.Format.ZoomAt(share, minimap:GetZoomLevels()))
end

local function ZoneTooltip(tip, frame)
	tip:SetOwner(frame, "ANCHOR_LEFT")
	local zone = GetZoneText and GetZoneText()
	tip:AddTitle(zone or L["Zone"])
	local sub = GetSubZoneText and GetSubZoneText()
	local _, pvpType = Data.Zone()
	local token = ns.Format.ZoneToken(pvpType, "pvp")
	if Data.IsText(sub) and Data.IsText(zone) and sub ~= zone then
		tip:AddLine(sub, token)
	end
	local label = Data.PvPLabel(pvpType)
	if label then
		tip:AddCaption(label, token)
	end
end

local function ClockTooltip(tip, frame)
	tip:SetOwner(frame, "ANCHOR_LEFT")
	tip:AddTitle(L["Time"])
	local hours = Data.Uses24(Settings.Get("clock.mode")) and "24" or "12"
	tip:AddDoubleLine(L["Local time"], Data.Clock("local" .. hours) or "")
	tip:AddDoubleLine(L["Realm time"], Data.Clock("realm" .. hours) or "")
end

local function KeepQueueFaded(queue, alpha)
	if queueFaded and alpha ~= 0 then
		queue:SetAlpha(0)
	end
end

local function SyncQueue()
	local queue = QueueStatusButton
	if not queue then
		return
	end
	local fade = running and Settings.Get("column.queue")
	if fade == queueFaded then
		return
	end
	queueFaded = fade
	if fade and not queueHooked then
		queueHooked = true
		hooksecurefunc(queue, "SetAlpha", KeepQueueFaded)
	end
	queue:SetAlpha(fade and 0 or 1)
	queue:EnableMouse(not fade)
	Log(fade and "faded Blizzard's queue eye; the column shows the queue" or "Blizzard's queue eye is back")
end

local function RefreshColumn()
	if running and Map.column then
		Map.column:Refresh()
	end
end

local function CollectButtons()
	if running and Map.drawer then
		Map.drawer:Collect()
		Map.column:Refresh()
	end
end

local Fit

function Map.Refresh()
	local face = Map.face
	if not (running and face) then
		return
	end
	face:Refresh()
	Fit()
	Map.drawer:Sync(running)
	Map.column:Refresh()
	SyncQueue()
	UpdateZone()
	UpdateClock()
	UpdateCoords()
	UpdateCompass()
	UpdateZoom()
	SyncClock()
	SyncCoords()
end

local function Relayout()
	if running and Map.face then
		Map.face:Layout()
		Fit()
		if Map.column then
			Map.column:Layout()
		end
	end
end

local function Build()
	if Map.holder then
		return
	end
	local element = K.Setup.Layouts.Element(KEY)
	local holder = CreateFrame("Frame", HOLDER_NAME, K.Scale.Root())
	holder:SetSize(element.width, element.height)
	holder:SetFrameStrata(STRATA)
	Map.holder = holder
	local face = Face.New(holder, { wheel = true, onZoom = OnSliderZoom })
	Map.face = face
	face.wheel:SetScript("OnMouseWheel", OnWheel)
	Widgets.AttachTooltip(face.zoneHit, ZoneTooltip)
	Widgets.AttachTooltip(face.clockHit, ClockTooltip)
	SecureClick.Bind(face.zoneHit, function()
		local cluster = MinimapCluster
		return cluster and cluster.ZoneTextButton
	end, ZoneTooltip)
	SecureClick.Bind(face.clockHit, function()
		return TimeManagerClockButton, GameTimeFrame
	end, ClockTooltip)
	Map.column = Column.New(face)
	Map.drawer = Drawer.New(Map.column)
	Map.column.drawer = Map.drawer
	holder:HookScript("OnSizeChanged", Relayout)
	local aspect = element.width / element.height
	Widgets.Place(holder, KEY, K.Setup.Layouts.Default(KEY), {
		label = element.label,
		module = MODULE,
		resizable = true,
		aspect = true,
		minWidth = MIN_HEIGHT * aspect,
		minHeight = MIN_HEIGHT,
		maxWidth = MAX_HEIGHT * aspect,
		maxHeight = MAX_HEIGHT,
	})
end

local function Remember(minimap)
	if original then
		return
	end
	local points = {}
	for i = 1, minimap:GetNumPoints() do
		points[i] = { n = select("#", minimap:GetPoint(i)), minimap:GetPoint(i) }
	end
	original = {
		parent = minimap:GetParent(),
		points = points,
		width = minimap:GetWidth(),
		height = minimap:GetHeight(),
		level = minimap:GetFrameLevel(),
	}
end

local Adopt, Release
local queued = {}

local function QueueOnce(what, fn)
	if queued[what] then
		return
	end
	queued[what] = true
	Log("Minimap is protected in combat; the " .. what .. " waits for combat to end")
	K.Combat.Queue(function()
		queued[what] = false
		fn()
	end)
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value)
end

local function FitLater()
	QueueOnce("fit", Fit)
end

function Fit()
	local minimap, face = Minimap, Map.face
	if not (running and minimap and face and minimap:GetParent() == Map.holder) then
		return
	end
	if not Widgets.MayMove(minimap) then
		FitLater()
		return
	end
	local width, height = face.mapArea:GetSize()
	if not (Plain(width) and Plain(height)) or width <= 0 or height <= 0 then
		return
	end
	minimap:ClearAllPoints()
	minimap:SetPoint("CENTER", face.mapArea, "CENTER")
	minimap:SetSize(width, height)
end

local function OnEditModeExit()
	if EventRegistry and EventRegistry.UnregisterCallback then
		EventRegistry:UnregisterCallback("EditMode.Exit", Map)
	end
	waitingForEditMode = false
	if running then
		Adopt()
	end
end

local function WaitForEditMode()
	if waitingForEditMode then
		return
	end
	if EventRegistry and EventRegistry.RegisterCallback then
		waitingForEditMode = true
		EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, Map)
		Log("Edit Mode is open; the map moves into KstyleUI's frame when it closes")
	end
end

function Adopt()
	if not running then
		return
	end
	local minimap = Minimap
	if not minimap then
		Log("Minimap is missing on this client; only KstyleUI's frame shows")
		return
	end
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() == true and EventRegistry then
		WaitForEditMode()
		return
	end
	if not Widgets.MayMove(minimap) then
		QueueOnce("adopt", Adopt)
		return
	end
	Remember(minimap)
	local holder = Map.holder
	minimap:SetParent(holder)
	minimap:SetFrameLevel(holder:GetFrameLevel() + Face.LEVEL_MAP)
	ApplyMask()
	Fit()
	SetBlobRings(1)
	Log("Minimap moved into KstyleUI's card with the round lens mask")
end

local function BlizzardPieces()
	local minimap = Minimap
	if not minimap then
		return { MinimapCluster, MinimapBackdrop }
	end
	return { MinimapCluster, MinimapBackdrop, minimap.ZoomIn, minimap.ZoomOut, minimap.ZoomHitArea }
end

local function HideBlizzard()
	local pieces = BlizzardPieces()
	for i = 1, PIECE_COUNT do
		K.Safe.HideBlizzard(pieces[i])
	end
end

function Release()
	if running then
		return
	end
	local minimap = Minimap
	if minimap and original and not Widgets.MayMove(minimap) then
		QueueOnce("release", Release)
		return
	end
	local Safe = K.Safe
	local pieces = BlizzardPieces()
	for i = 1, PIECE_COUNT do
		Safe.RestoreBlizzard(pieces[i])
	end
	if not (minimap and original) then
		return
	end
	minimap:SetParent(original.parent)
	minimap:ClearAllPoints()
	for _, point in ipairs(original.points) do
		minimap:SetPoint(unpack(point, 1, point.n))
	end
	if type(original.width) == "number" and type(original.height) == "number" then
		minimap:SetSize(original.width, original.height)
	end
	if type(original.level) == "number" then
		minimap:SetFrameLevel(original.level)
	end
	if type(minimap.SetMaskTexture) == "function" then
		minimap:SetMaskTexture(BLIZZARD_MASK)
	end
	SetBlobRings(1)
	Log("Minimap returned to Blizzard's cluster; a reload finishes the restore")
end

local function OnBlizzardConfig()
	if running then
		ApplyMask()
	end
end

local function OnBlizzardZoom()
	if running then
		UpdateZoom()
	end
end

local function HookBlizzard()
	local cluster = MinimapCluster
	if not configHooked and cluster and type(cluster.UpdateMinimapConfig) == "function" then
		configHooked = true
		hooksecurefunc(cluster, "UpdateMinimapConfig", OnBlizzardConfig)
	end
	local minimap = Minimap
	if not zoomHooked and minimap and type(minimap.SetZoom) == "function" then
		zoomHooked = true
		hooksecurefunc(minimap, "SetZoom", OnBlizzardZoom)
	end
end

local function RegisterEvents()
	local Events = K.Events
	local function onZone()
		UpdateZone()
		UpdateCoords()
	end
	for _, event in ipairs(ZONE_EVENTS) do
		Events.Register(MODULE, event, onZone)
	end
	Events.Register(MODULE, "PLAYER_ENTERING_WORLD", function()
		onZone()
		UpdateCompass()
		CollectButtons()
	end)
	for _, event in ipairs(COLUMN_EVENTS) do
		Events.Register(MODULE, event, RefreshColumn)
	end
	Events.Register(MODULE, "PLAYER_REGEN_DISABLED", SecureClick.Detach)
	Events.Register(MODULE, "MINIMAP_UPDATE_ZOOM", UpdateZoom)
	local registry = EventRegistry
	if registry and type(registry.RegisterCallback) == "function" then
		registry:RegisterCallback(QUEUE_CALLBACK, RefreshColumn, Map)
	end
	for _, event in ipairs(MOVE_START) do
		Events.Register(MODULE, event, StartCoords)
	end
	for _, event in ipairs(MOVE_STOP) do
		Events.Register(MODULE, event, StopCoords)
	end
	Events.Register(MODULE, "CVAR_UPDATE", function(_, name)
		if name == "rotateMinimap" then
			UpdateCompass()
		end
	end)
	Events.Register(MODULE, "ADDON_LOADED", function(_, name)
		if name == HYBRID_ADDON then
			MaskHybrid()
		end
		C_Timer.After(0, CollectButtons)
	end)
end

local function RegisterCallbacks()
	local Callbacks = K.Callbacks
	Callbacks.Register("ThemeChanged", MODULE, Map.Refresh)
	Callbacks.Register("ScaleChanged", MODULE, Map.Refresh)
	Callbacks.Register("ProfileChanged", MODULE, Map.Refresh)
	Callbacks.Register("SettingChanged", MODULE, function(_, module)
		if module == MODULE then
			Map.Refresh()
		end
	end)
end

local function Check()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	local minimap = Minimap
	if not minimap or minimap:GetParent() ~= Map.holder then
		return false, "Minimap is not in KstyleUI's frame"
	end
	return true, "Minimap is in KstyleUI's frame"
end

function Map.Enable()
	running = true
	Build()
	Map.holder:Show()
	Adopt()
	HideBlizzard()
	HookBlizzard()
	GetMinimapShape = RoundShape
	RegisterEvents()
	RegisterCallbacks()
	SecureClick.SetActive(true)
	MaskHybrid()
	if not checkAdded then
		checkAdded = true
		K.DevTest.AddCheck(MODULE, Check)
	end
	Map.Refresh()
end

function Map.Disable()
	running = false
	moving = false
	zoomToken = zoomToken + 1
	StopClock()
	StopCoords()
	SecureClick.SetActive(false)
	if Map.drawer then
		Map.drawer:Sync(false)
	end
	local registry = EventRegistry
	if registry and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(QUEUE_CALLBACK, Map)
	end
	SyncQueue()
	if Map.holder then
		Map.holder:Hide()
	end
	Release()
	if GetMinimapShape == RoundShape then
		GetMinimapShape = nil
	end
end

function Map.IsRunning()
	return running
end
