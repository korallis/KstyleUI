-- Map.lua: the live minimap: Blizzard's Minimap hosted in KstyleUI's square frame behind the square mask, the Blizzard pieces it hides, wheel and slider zoom, the hover that reveals the controls, and the caption's data.
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
local MIN_SIZE, MAX_SIZE = 100, 320
local HOVER_GRACE = 0.3
local PIECE_COUNT = 5
local BLOB_METHODS = { "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local COLUMN_EVENTS = { "UPDATE_PENDING_MAIL", "CALENDAR_UPDATE_PENDING_INVITES" }
local QUEUE_CALLBACK = "QueueStatusUpdate.QueuesUpdated"
local MOVE_START = { "PLAYER_STARTED_MOVING", "PLAYER_CONTROL_LOST" }
local MOVE_STOP = { "PLAYER_STOPPED_MOVING", "PLAYER_CONTROL_GAINED" }

local running = false
local original
local configHooked, zoomHooked, compartmentHooked = false, false, false
local waitingForEditMode = false
local queueFaded, queueHooked = false, false
local checkAdded = false
local ticker
local clockElapsed, coordsElapsed = 0, 0
local coordsTicker
local fighting = false
local zoomToken = 0
local moving = false
local hoverHooked = false
local graceLeft = 0
local openMenu
local perfTicker, perfEvery

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function MaskPath()
	return Face.MaskPath()
end

local function MapShape()
	return Face.Round() and "ROUND" or "SQUARE"
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
		Log("the hybrid minimap uses the module's mask")
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

local function UpdateDifficulty()
	if Settings.Get("difficulty.shown") then
		Map.face:SetDifficulty(Data.Difficulty())
	end
end

local function Hex(r, g, b)
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function Map.PerfText(fps, ms)
	if not fps then
		return nil
	end
	local open, close = "", ""
	if Settings.Get("perf.accent") then
		open, close = Hex(ns.Style.Accent()), "|r"
	end
	return ("%d %s%s%s  %d %s%s%s"):format(fps, open, L["fps"], close, ms, open, L["ms"], close)
end

local function UpdatePerf()
	if running and Map.face and Settings.Get("perf.shown") then
		Map.face:SetPerf(Map.PerfText(Data.Perf(Settings.Get("perf.latency"))))
	end
end

local function SyncPerf()
	local every = running and Settings.Get("perf.shown") and Settings.Get("perf.interval") or nil
	if every == perfEvery then
		return
	end
	if perfTicker then
		perfTicker:Cancel()
		perfTicker = nil
	end
	perfEvery = every
	if every and C_Timer and type(C_Timer.NewTicker) == "function" then
		perfTicker = C_Timer.NewTicker(every, UpdatePerf)
	elseif every then
		Log("C_Timer.NewTicker is missing; the frame rate updates only when the map refreshes")
	end
end

local function SyncRotate()
	local want, account, key = running and Settings.Get("rotate"), K.Store.Account(), K.Store.CharacterKey()
	local memory = account.minimapRotate or {}
	local own = memory[key]
	local current = (want or own ~= nil) and type(key) == "string" and K.CVars.Get("rotateMinimap")
	if not current then
		return
	end
	if want then
		if own == nil and current ~= "1" then
			if K.CVars.Set("rotateMinimap", "1") then
				memory[key], account.minimapRotate = current, memory
			else
				Log("the game refused rotateMinimap; the map keeps its rotation")
			end
		end
	elseif own ~= nil then
		if current == "1" then
			K.CVars.Set("rotateMinimap", own)
		end
		memory[key] = nil
	end
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
		Map.face.caption:SetScript("OnUpdate", nil)
	end
end

local function SyncClock()
	if not (running and Settings.Get("clock.shown")) then
		StopClock()
		return
	end
	if ticker or Map.face.caption:GetScript("OnUpdate") then
		return
	end
	if C_Timer and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(CLOCK_INTERVAL, UpdateClock)
	else
		clockElapsed = 0
		Map.face.caption:SetScript("OnUpdate", ClockOnUpdate)
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

local function StopCoordsTicker(frame)
	if coordsTicker then
		coordsTicker:Cancel()
		coordsTicker = nil
	end
	frame:SetScript("OnUpdate", nil)
end

local function SyncCoords()
	local frame = Map.face and Map.face.coordsFrame
	if not frame then
		return
	end
	if not (running and moving and not fighting and Settings.Get("coords.shown")) then
		StopCoordsTicker(frame)
		return
	end
	if coordsTicker or frame:GetScript("OnUpdate") then
		return
	end
	if C_Timer and type(C_Timer.NewTicker) == "function" then
		coordsTicker = C_Timer.NewTicker(COORDS_INTERVAL, UpdateCoords)
	else
		coordsElapsed = 0
		frame:SetScript("OnUpdate", CoordsOnUpdate)
		Log("C_Timer.NewTicker is missing; the coordinates count with OnUpdate")
	end
end

local function EnterCombat()
	fighting = true
	for _, button in pairs(Map.column.buttons) do
		Column.Drag(button, false, true)
	end
	SecureClick.Detach()
	ns.Micro.Close()
	SyncCoords()
end

local function LeaveCombat()
	fighting = false
	SyncCoords()
	if running and Map.face then
		UpdateCoords()
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
	tip:SetOwner(frame, "ANCHOR_LEFT", 0, 0, Settings.Get("tooltipScale"))
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

local function Lockouts(tip, redraw)
	if not redraw and type(RequestRaidInfo) == "function" then
		RequestRaidInfo()
	end
	local list = Data.Lockouts()
	if #list == 0 then
		tip:AddLine(L["No saved instances"], "text")
	end
	for _, entry in ipairs(list) do
		tip:AddDoubleLine(entry.name, Widgets.Duration.Format(entry.reset, "long"))
	end
end

local function ClockTooltip(tip, frame, redraw)
	tip:SetOwner(frame, "ANCHOR_LEFT", 0, 0, Settings.Get("tooltipScale"))
	tip:AddTitle(L["Time"])
	local hours = Data.Uses24(Settings.Get("clock.mode")) and "24" or "12"
	tip:AddDoubleLine(L["Local time"], Data.Clock("local" .. hours) or "")
	tip:AddDoubleLine(L["Realm time"], Data.Clock("realm" .. hours) or "")
	if Settings.Get("clock.hover") == "lockouts" then
		tip:AddCaption(L["Instance lockouts"])
		Lockouts(tip, redraw)
	end
end

local function PerfTooltip(tip, frame, redraw)
	tip:SetOwner(frame, "ANCHOR_LEFT", 0, 0, Settings.Get("tooltipScale"))
	tip:AddTitle(L["Instance lockouts"])
	Lockouts(tip, redraw)
end

local function RedrawLockouts()
	local tip, face = Widgets.Tooltip(), Map.face
	local frame = tip:IsOwned(face.clockHit) and face.clockHit or tip:IsOwned(face.perfHit) and face.perfHit
	if frame then
		local content = frame == face.clockHit and ClockTooltip or PerfTooltip
		tip:SetOwner(frame, "ANCHOR_LEFT")
		content(tip, frame, true)
		tip:Show()
	end
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

local function Reveal()
	if running and Map.face then
		Map.face:SetRevealed(true)
	end
end

local function PointerStays()
	if Map.holder:IsMouseOver() then
		return true
	end
	local drawer = Map.drawer
	return drawer ~= nil and drawer.open == true and drawer.panel:IsMouseOver()
end

local function MenuOpen()
	if openMenu == nil then
		return false
	end
	local manager = Menu and type(Menu.GetManager) == "function" and Menu.GetManager()
	if not (manager and type(manager.IsMenuOpen) == "function") then
		openMenu = nil
		return false
	end
	local open = manager:IsMenuOpen(openMenu)
	if Widgets.IsSecret(open) or open ~= true then
		openMenu = nil
		return false
	end
	return true
end

function Map.SetMenu(menu)
	openMenu = type(menu) == "table" and menu or nil
end

local function WatchHover(frame, elapsed)
	if not (running and Map.face) then
		frame:SetScript("OnUpdate", nil)
		return
	end
	if MenuOpen() then
		graceLeft = HOVER_GRACE
		return
	end
	if PointerStays() then
		frame:SetScript("OnUpdate", nil)
		return
	end
	graceLeft = graceLeft - elapsed
	if graceLeft <= 0 then
		frame:SetScript("OnUpdate", nil)
		Map.face:SetRevealed(false)
	end
end

function Map.CheckHover()
	ns.Micro.CheckHover()
	if running and Map.face and Map.face.revealed then
		graceLeft = HOVER_GRACE
		Map.face.overlay:SetScript("OnUpdate", WatchHover)
	end
end

local function HookHover(frame)
	frame:HookScript("OnEnter", Reveal)
	frame:HookScript("OnLeave", Map.CheckHover)
end

local function OnMapClick(_, button)
	if running and button == "MiddleButton" and Settings.Get("microMenu") then
		ns.Micro.Toggle(Map.holder)
	end
end

local function CollectButtons()
	if running and Map.drawer then
		Map.drawer:Collect()
		Map.column:Refresh()
		ns.Pins.Sync(running)
	end
end

local Fit

function Map.Refresh()
	local face = Map.face
	if not (running and face) then
		return
	end
	SyncRotate()
	if not Settings.Get("microMenu") then ns.Micro.Close() end
	face:Paint()
	if Face.Round() then K.Layout.Restore(KEY) end
	face:Layout()
	ApplyMask()
	MaskHybrid()
	Fit()
	Map.drawer:Sync(running)
	Map.column:Refresh()
	ns.Pins.Sync(running)
	SyncQueue()
	UpdateZone()
	UpdateClock()
	UpdateCoords()
	UpdateDifficulty()
	UpdatePerf()
	UpdateZoom()
	SyncClock()
	SyncCoords()
	SyncPerf()
end

local function Relayout()
	if running and Map.face and Map.face.zoneSize then
		Map.face.layoutWidth = nil
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
	Widgets.Size(holder, element.width, element.height)
	holder:SetFrameStrata(STRATA)
	Map.holder = holder
	local face = Face.New(holder, { wheel = true, onZoom = OnSliderZoom })
	Map.face = face
	face.wheel:SetScript("OnMouseWheel", OnWheel)
	Widgets.AttachTooltip(face.zoneHit, ZoneTooltip)
	Widgets.AttachTooltip(face.clockHit, ClockTooltip)
	Widgets.AttachTooltip(face.perfHit, PerfTooltip, "ANCHOR_LEFT")
	SecureClick.Bind(face.zoneHit, function()
		local cluster = MinimapCluster
		return cluster and cluster.ZoneTextButton
	end, ZoneTooltip)
	SecureClick.Bind(face.clockHit, function()
		return TimeManagerClockButton, GameTimeFrame
	end, ClockTooltip)
	Map.column = Column.New(face, { hook = HookHover })
	Map.drawer = Drawer.New(Map.column)
	Map.column.drawer = Map.drawer
	for _, frame in ipairs({ face.zoneHit, face.clockHit, face.perfHit, face.zoom }) do
		HookHover(frame)
	end
	holder:HookScript("OnSizeChanged", Relayout)
	hooksecurefunc(holder, "SetPoint", function(_, point, _, _, x, y)
		if face.positionPoint ~= point or face.positionX ~= x or face.positionY ~= y then
			face.positionPoint, face.positionX, face.positionY = point, x, y
			if Face.Round() then Relayout() end
		end
	end)
	Widgets.Place(holder, KEY, K.Setup.Layouts.Default(KEY), {
		label = element.label,
		module = MODULE,
		clamp = function(...) return face:Clamp(...) end,
		resizable = true,
		aspect = true,
		minWidth = MIN_SIZE,
		minHeight = MIN_SIZE,
		maxWidth = MAX_SIZE,
		maxHeight = MAX_SIZE,
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
	local scale = minimap:GetScale()
	original = {
		parent = minimap:GetParent(),
		points = points,
		width = minimap:GetWidth(),
		height = minimap:GetHeight(),
		level = minimap:GetFrameLevel(),
		scale = ns.Format.IsNumber(scale) and scale > 0 and scale or 1,
		nativeScale = Widgets.ScaleFactor(minimap) / Widgets.ScaleFactor(UIParent),
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
	local scale = original.scale
	if not Settings.Get("compactIcons") then
		scale = math.max(scale, original.nativeScale * Widgets.ScaleFactor(UIParent) / Widgets.ScaleFactor(Map.holder))
	end
	minimap:SetScale(scale)
	minimap:SetSize(width / scale, height / scale)
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
	SetBlobRings(0)
	if not hoverHooked and type(minimap.HookScript) == "function" then
		hoverHooked = true
		HookHover(minimap)
		minimap:HookScript("OnMouseUp", OnMapClick)
	end
	Log("Minimap moved into KstyleUI's square frame with the square mask")
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
	minimap:SetScale(original.scale)
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
		Map.face.north:SetShown(not Data.Rotated())
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
	local compartment = AddonCompartmentFrame
	if not compartmentHooked and compartment and type(compartment.UpdateDisplay) == "function" then
		compartmentHooked = true
		hooksecurefunc(compartment, "UpdateDisplay", RefreshColumn)
	end
end

local function RegisterEvents()
	local Events = K.Events
	local function onZone()
		UpdateZone()
		UpdateCoords()
		UpdateDifficulty()
	end
	Events.Register(MODULE, "PLAYER_DIFFICULTY_CHANGED", UpdateDifficulty)
	Events.Register(MODULE, "UPDATE_INSTANCE_INFO", function()
		UpdateDifficulty()
		RedrawLockouts()
	end)
	for _, event in ipairs(ZONE_EVENTS) do
		Events.Register(MODULE, event, onZone)
	end
	Events.Register(MODULE, "PLAYER_ENTERING_WORLD", function()
		onZone()
		CollectButtons()
		C_Timer.After(0, CollectButtons)
	end)
	for _, event in ipairs(COLUMN_EVENTS) do
		Events.Register(MODULE, event, RefreshColumn)
	end
	Events.Register(MODULE, "PLAYER_REGEN_DISABLED", EnterCombat)
	Events.Register(MODULE, "PLAYER_REGEN_ENABLED", LeaveCombat)
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
	Events.Register(MODULE, "ADDON_LOADED", function(_, name)
		if name == HYBRID_ADDON then
			MaskHybrid()
		end
		C_Timer.After(0, CollectButtons)
	end)
end

local function RegisterCallbacks()
	local Callbacks = K.Callbacks
	local function ClockChanged()
		local shown = Settings.Get("clock.shown")
		if Map.face and Map.face.clock:IsShown() ~= shown then
			Map.Refresh()
		end
	end
	Callbacks.Register("ThemeChanged", MODULE, Map.Refresh)
	Callbacks.Register("ClassChanged", MODULE, Map.Refresh)
	Callbacks.Register("ScaleChanged", MODULE, Map.Refresh)
	Callbacks.Register("ProfileChanged", MODULE, Map.Refresh)
	Callbacks.Register("ModuleChanged", MODULE, function(_, module)
		if module == "DataBars" then ClockChanged() end
	end)
	Callbacks.Register("LayoutChanged", MODULE, function(_, key)
		if key == "databars.strip" then ClockChanged() end
	end)
	Callbacks.Register("SettingChanged", MODULE, function(_, module, key, value)
		if module == MODULE then
			if not Settings.Mirror(key, value) then Map.Refresh() end
		elseif module == "DataBars" then
			ClockChanged()
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
	fighting = InCombatLockdown() == true
	Build()
	Map.holder:Show()
	Adopt()
	HideBlizzard()
	HookBlizzard()
	GetMinimapShape = MapShape
	RegisterEvents()
	RegisterCallbacks()
	SecureClick.SetActive(true)
	MaskHybrid()
	if not checkAdded then
		checkAdded = true
		K.DevTest.AddCheck(MODULE, Check)
	end
	Map.Refresh()
	Map.drawer:Reposition()
end

function Map.Disable()
	running = false
	moving = false
	zoomToken = zoomToken + 1
	StopClock()
	StopCoords()
	SyncPerf()
	SyncRotate()
	SecureClick.SetActive(false)
	ns.Micro.Close()
	if Map.drawer then
		Map.drawer:Sync(false)
	end
	ns.Pins.Sync(false)
	local registry = EventRegistry
	if registry and type(registry.UnregisterCallback) == "function" then
		registry:UnregisterCallback(QUEUE_CALLBACK, Map)
	end
	SyncQueue()
	if Map.holder then
		Map.holder:Hide()
	end
	Release()
	if GetMinimapShape == MapShape then
		GetMinimapShape = nil
	end
	if Map.drawer then
		Map.drawer:Reposition()
	end
end

function Map.IsRunning()
	return running
end
