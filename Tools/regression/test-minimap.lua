-- test-minimap.lua: the square minimap: off until enabled, its frame and Layout element, the Blizzard pieces it hides, wheel zoom, the zone and clock strip, coordinates, the accent and turning it off.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function NoErrors(env, what)
	assert(#env._errors == 0, (what or "") .. ": " .. tostring(env._errors[1]))
end

local function LastArg(frame, method)
	local call = W.LastCall(frame, method)
	return call and call[1]
end

local function Map(ns)
	local map = ns.Map
	assert(type(map) == "table" and map.face, "ns.Map.face holds the built frame's parts")
	return map.face
end

-- Off by default: loading registers the module and touches nothing -----------------------------

do
	local env, K = M.New()
	M.Settle(env)
	local found = false
	for _, name in ipairs(K.Modules.List()) do
		found = found or name == "Minimap"
	end
	assert(found, "the module registers with KstyleUI.Modules")
	assert(K.Store.Defaults("Minimap").enabled == false, "the module is off by default")
	assert(not K.Modules.IsRunning("Minimap"), "the module does not run before the player turns it on")
	assert(env.Minimap:GetParent() == env.MinimapCluster.MinimapContainer, "an off module leaves Blizzard's minimap alone")
	assert(not K.Safe.IsHidden(env.MinimapCluster), "an off module hides nothing")
	assert(K.Layout.Element("minimap.main") == nil, "an off module builds no frame")
	assert(env.GetMinimapShape == nil, "an off module sets no globals")
	assert(type(K.Options.Get("Minimap")) == "table", "the module declares its settings page")
	assert(type(K.Options.Preview("Minimap")) == "function", "the module gives the settings window a preview")
	NoErrors(env, "loading")
end

-- Enabled at login: the square map in KstyleUI's frame -----------------------------------------

local env, K, ns = M.New({ enabled = true })
M.Settle(env)
NoErrors(env, "login")
assert(K.Modules.IsRunning("Minimap"), "the saved switch starts the module at login")

local holder = M.Holder(K)
assert(holder, "the minimap registers as the Layout element minimap.main")
local element = K.Layout.Element("minimap.main")
assert(element.label == K.Setup.Layouts.Element("minimap.main").label, "the mover plate uses the setup's label")
assert(element.module == "Minimap", "Layout knows the element belongs to the Minimap module")
assert(element.opts.resizable and element.opts.aspect, "the minimap resizes in Layout Mode and keeps its proportions")
assert(holder:GetWidth() == 226 and holder:GetHeight() == 196, "the element fills its footprint at the 1080 reference")

local minimap = env.Minimap
local face = Map(ns)
assert(minimap:GetParent() == holder, "Blizzard's minimap moves into KstyleUI's frame")
assert(LastArg(minimap, "SetAllPoints") == face.mapArea, "the minimap fills the frame's map square")
local mw, mh = face.mapArea:GetSize()
assert(mw == mh, "the minimap stays square")
assert(mw > 180 and mw < 196, "the minimap sits just inside the frame: " .. tostring(mw))
assert(W.Near(select(4, face.box:GetPoint(1)), 30), "with the column on the left, the map square sits at the right")
assert(LastArg(minimap, "SetMaskTexture") == (K.Tokens.Texture("minimapMask")), "the minimap uses KstyleUI's square mask")
for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
	assert(LastArg(minimap, method) == 0, method .. "(0) removes the round blob ring on a square map")
end
for _, frame in ipairs({ env.MinimapCluster, env.MinimapBackdrop, minimap.ZoomIn, minimap.ZoomOut, minimap.ZoomHitArea }) do
	assert(K.Safe.IsHidden(frame), "Blizzard's cluster, border and zoom buttons are hidden through Safe")
end
assert(env.GetMinimapShape and env.GetMinimapShape() == "SQUARE", "minimap button libraries see a square map")

env.MinimapCluster.UpdateMinimapConfig()
assert(LastArg(minimap, "SetMaskTexture") == (K.Tokens.Texture("minimapMask")), "a Blizzard minimap refresh keeps the square mask")

M.Resize(holder, 346, 300)
mw, mh = face.mapArea:GetSize()
assert(mw == mh and mw > 280 and mw < 300, "a resized element resizes the square map: " .. tostring(mw))
M.Resize(holder, 226, 196)

-- Wheel zoom ----------------------------------------------------------------------------------------

local wheel = face.wheel
assert(wheel and W.LastCall(wheel, "EnableMouseWheel")[1] == true, "a wheel catcher covers the square map")
env._zoom = 2
M.Wheel(wheel, 1)
assert(env._zoom == 3, "wheel up zooms in")
M.Wheel(wheel, -1)
assert(env._zoom == 2, "wheel down zooms out")
env._zoom, env._zoomCalls = 5, 0
M.Wheel(wheel, 1)
assert(env._zoomCalls == 0, "no zoom past the last level")
K.Options.Write("Minimap", "zoom.wheel", false)
env._zoom = 2
M.Wheel(wheel, 1)
assert(env._zoom == 2, "the wheel does nothing when wheel zoom is off")
K.Options.Write("Minimap", "zoom.wheel", true)
K.Options.Write("Minimap", "zoom.reset", true)
M.Wheel(wheel, 1)
assert(env._zoom == 3, "the wheel zooms before the reset")
env.RunTimers()
assert(env._zoom == 0, "with zoom reset on, the map zooms back out after the delay")
M.Wheel(wheel, 1)
K.Options.Write("Minimap", "zoom.reset", false)
env.RunTimers()
assert(env._zoom == 1, "turning zoom reset off cancels a pending zoom-out")

-- The strip: zone and clock -----------------------------------------------------------------------

assert(face.zone:GetText() == "RIVERGLADES", "the strip shows the zone in capitals: " .. tostring(face.zone:GetText()))
env._zone.text = "Hall of Thanes"
env.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(face.zone:GetText() == "HALL OF THANES", "a zone change updates the strip")
local er, eg, eb = K.Tokens.Color("textEmphasis")
local tr, tg, tb = face.zone:GetTextColor()
assert(W.Near(tr, er) and W.Near(tg, eg) and W.Near(tb, eb), "plain zone text is the emphasis colour")
env._zone.pvp = "hostile"
K.Options.Write("Minimap", "zone.color", "pvp")
local hr, hg, hb = K.Tokens.Color("hostile")
local zr, zg, zb = face.zone:GetTextColor()
assert(W.Near(zr, hr) and W.Near(zg, hg) and W.Near(zb, hb), "PvP colouring shows a hostile zone in the hostile colour")
K.Options.Write("Minimap", "zone.color", "plain")

assert(face.clock:GetText() == "14:32", "the clock follows the game's clock by default: " .. tostring(face.clock:GetText()))
env._clock.minute = 33
local tables = env._dateCalls["*t"] or 0
M.RunTickers(env)
assert(face.clock:GetText() == "14:33", "the clock ticks")
assert((env._dateCalls["*t"] or 0) == tables, "a tick reads the clock without building a date table")
env._cvars.timeMgrUseLocalTime, env._cvars.timeMgrUseMilitaryTime = false, false
M.RunTickers(env)
assert(face.clock:GetText() == "9:05 AM", "the game's clock settings pick realm time in 12 hours")
env._cvars.timeMgrUseLocalTime, env._cvars.timeMgrUseMilitaryTime = true, true
K.Options.Write("Minimap", "clock.mode", "realm24")
assert(face.clock:GetText() == "09:05", "realm time in 24 hours: " .. tostring(face.clock:GetText()))
K.Options.Write("Minimap", "clock.mode", "realm12")
assert(face.clock:GetText() == "9:05 AM", "realm time in 12 hours")
K.Options.Write("Minimap", "clock.mode", "local24")
assert(face.clock:GetText() == "14:33", "local time in 24 hours")

assert(face.strip.divider:IsShown(), "a hairline parts the zone from the clock, as in the kit")
K.Options.Write("Minimap", "clock.shown", false)
assert(not face.clock:IsShown(), "the clock hides from the strip")
assert(not face.strip.divider:IsShown(), "and the hairline goes with it")
assert(face.strip:IsShown(), "the strip stays while the zone shows")
K.Options.Write("Minimap", "zone.shown", false)
assert(not face.strip:IsShown(), "the strip hides when it has nothing to show")
K.Options.Write("Minimap", "zone.shown", true)
K.Options.Write("Minimap", "clock.shown", true)
assert(face.strip:IsShown() and face.clock:IsShown(), "the strip comes back")

K.Options.Write("Minimap", "clock.size", 16)
local _, size = face.clock:GetFont()
assert(W.Near(size, 16 * K.Theme.FontScale()), "the clock takes its own text size")
K.Options.Write("Minimap", "clock.outline", "OUTLINE")
local _, _, flags = face.clock:GetFont()
assert(flags == "OUTLINE", "the clock takes its own outline")

-- Coordinates -------------------------------------------------------------------------------------

env._position = { 0.4532, 0.6218 }
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
assert(face.coords:GetText() == "45.3, 62.2", "coordinates show in tenths by default: " .. tostring(face.coords:GetText()))
K.Options.Write("Minimap", "coords.precision", 0)
assert(face.coords:GetText() == "45, 62", "the coordinate format follows the setting")
env.FireEvent("PLAYER_STARTED_MOVING")
local mover = face.coordsFrame
assert(mover:GetScript("OnUpdate"), "coordinates update every frame only while the player moves")
env._position = { 0.5, 0.25 }
mover:GetScript("OnUpdate")(mover, 1)
assert(face.coords:GetText() == "50, 25", "moving updates the coordinates")
K.Options.Write("Minimap", "coords.shown", false)
assert(not mover:GetScript("OnUpdate"), "hidden coordinates stop updating")
K.Options.Write("Minimap", "coords.shown", true)
assert(mover:GetScript("OnUpdate"), "showing them again while moving resumes the updates")
env.FireEvent("PLAYER_STOPPED_MOVING")
assert(not mover:GetScript("OnUpdate"), "stopping ends the updates")
env._position = nil
env.FireEvent("ZONE_CHANGED")
assert(not face.coords:IsShown(), "no position, such as in an instance, hides the coordinates")
env._position = { 0.5, 0.25 }
env.FireEvent("ZONE_CHANGED")
assert(face.coords:IsShown(), "the coordinates come back with a position")
K.Options.Write("Minimap", "coords.shown", false)
assert(not face.coords:IsShown(), "the coordinates can be turned off")
K.Options.Write("Minimap", "coords.shown", true)

-- The compass mark --------------------------------------------------------------------------------

assert(face.compass:IsShown(), "the north mark shows on a fixed map")
assert(face.compassPlate:IsShown() and #face.compassPlate.slice == 9, "on the kit's dark glass tab at the top of the map")
env._cvars.rotateMinimap = true
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "1")
assert(not face.compass:IsShown() and not face.compassPlate:IsShown(), "a rotating map hides the north mark and its tab")
env._cvars.rotateMinimap = env.Secret(false)
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "0")
assert(not face.compass:IsShown(), "a secret rotation hides the north mark rather than guess")
env._cvars.rotateMinimap = false
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "0")
assert(face.compass:IsShown(), "the north mark comes back")

-- The panel's centre stays clear for Blizzard's hybrid map, which draws below KstyleUI's strata -----

K.Widgets.RestyleAll()
assert(not face.chrome.fill[5]:IsShown(), "the fill's centre stays hidden after a restyle")
assert(not face.chrome.shadow[5]:IsShown(), "the shadow's centre stays hidden after a restyle")

-- The accent hairline -----------------------------------------------------------------------------

local inner = face.chrome.inner[5]
assert(W.SameRGB(inner, K.Theme.Accent()), "the hairline follows the class colour")
K.Options.Write("Minimap", "accent.source", "custom")
K.Options.Write("Minimap", "accent.color", { r = 1, g = 0, b = 0 })
assert(W.SameRGB(inner, 1, 0, 0), "a custom accent colours the hairline")
K.Options.Write("Minimap", "accent.source", "class")
assert(W.SameRGB(inner, K.Theme.Accent()), "the class colour comes back")

-- The column side moves the map --------------------------------------------------------------------

K.Options.Write("Minimap", "column.side", "right")
assert(W.Near(select(4, face.box:GetPoint(1)), 0), "with the column on the right, the map square sits at the left")
K.Options.Write("Minimap", "column.side", "left")

-- The hybrid minimap gets the square mask too -------------------------------------------------------

env.HybridMinimap = { CircleMask = env.CreateFrame("Frame", nil, env.UIParent):CreateMaskTexture() }
env.FireEvent("ADDON_LOADED", "Blizzard_HybridMinimap")
assert(LastArg(env.HybridMinimap.CircleMask, "SetTexture") == (K.Tokens.Texture("minimapMask")), "the hybrid minimap is masked square")

NoErrors(env, "enabled")

-- Turning it off ------------------------------------------------------------------------------------

K.Modules.Disable("Minimap")
M.Settle(env)
assert(not holder:IsShown(), "turning the module off hides its frame")
assert(minimap:GetParent() == env.MinimapCluster.MinimapContainer, "Blizzard's minimap goes back to its container")
assert(not K.Safe.IsHidden(env.MinimapCluster), "Blizzard's cluster comes back")
assert(M.LiveTickers(env) == 0, "the clock stops ticking")
assert(env.GetMinimapShape == nil, "the square shape is withdrawn")
assert(M.CoreEnv.Printed(env, "/reload"), "turning a reskin off asks for a reload")
NoErrors(env, "disabled")

K.Modules.Enable("Minimap")
M.Settle(env)
assert(minimap:GetParent() == holder and holder:IsShown(), "turning it on again reuses the frame")
assert(K.Safe.IsHidden(env.MinimapCluster), "and hides the cluster again")
NoErrors(env, "enabled again")

-- A bad saved value falls back to the default ---------------------------------------------------------

do
	local benv, _, bns = M.New({ enabled = true, settings = { clock = { mode = "bogus" }, column = { side = "up" } } })
	M.Settle(benv)
	local bface = Map(bns)
	assert(bface.clock:GetText() == "14:32", "an unknown clock mode uses the game's clock")
	assert(bns.Settings.Get("column.side") == "inside", "an unknown column side uses the default, inside the frame")
	NoErrors(benv, "bad values")
end

-- Logging in during combat --------------------------------------------------------------------------

do
	local cenv, CK = M.New({ enabled = true, combat = true })
	cenv.RunTimers()
	assert(cenv.Minimap:GetParent() == M.Holder(CK), "the map moves into KstyleUI's frame at a combat login")
	assert(not CK.Safe.IsHidden(cenv.MinimapCluster), "Blizzard frames wait for combat to end")
	cenv.SetCombat(false)
	M.Settle(cenv)
	assert(CK.Safe.IsHidden(cenv.MinimapCluster), "and hide once it ends")
	NoErrors(cenv, "combat login")
end

-- The preview ---------------------------------------------------------------------------------------

do
	local penv, PK = M.New()
	local parent = penv.CreateFrame("Frame", nil, penv.UIParent)
	parent:SetSize(400, 300)
	local frame = PK.Options.Preview("Minimap")(parent)
	assert(type(frame) == "table" and type(frame.Refresh) == "function", "the preview is a frame with Refresh")
	assert(penv.Minimap:GetParent() == penv.MinimapCluster.MinimapContainer, "the preview never takes Blizzard's minimap")
	local pface = frame.face
	assert(pface.zone:GetText() and pface.zone:GetText() ~= "", "the preview shows a zone")
	assert(pface.clock:IsShown(), "the preview shows the clock")
	PK.Options.Write("Minimap", "clock.shown", false)
	frame:Refresh()
	assert(not pface.clock:IsShown(), "the preview follows the settings")
	NoErrors(penv, "preview")
end

print("minimap ok")
