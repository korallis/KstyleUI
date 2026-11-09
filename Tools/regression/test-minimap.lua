-- test-minimap.lua: the Lumen lens minimap: off until enabled, its card and Layout element, the round lens and its mask, the Blizzard pieces it hides, wheel zoom, the zone and clock foot, coordinates, the accent and turning it off.
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
assert(holder:GetWidth() == 318 and holder:GetHeight() == 326, "the element fills the Lumen lens card's footprint at the 1080 reference")

local minimap = env.Minimap
local face = Map(ns)
assert(minimap:GetParent() == holder, "Blizzard's minimap moves into KstyleUI's frame")
local mw, mh = face.mapArea:GetSize()
assert(mw == mh, "the lens stays square")
-- The engine draws the terrain at the size the Minimap was given with SetSize, from the frame's bottom left
-- corner; anchors alone leave Blizzard's 198 render in a larger square (ingame-18: a dark band on the right and
-- the top). So the map takes an explicit size equal to the lens square and one CENTER point on it. Fitting never
-- touches the zoom: nothing in Forever's source shows the engine needs a zoom change to draw at a new size.
local function Fits(what)
	local size = W.LastCall(minimap, "SetSize")
	local sw, sh = face.mapArea:GetSize()
	assert(size and W.Near(size[1], sw) and W.Near(size[2], sh), what .. ": the minimap's own size is the lens square's: " .. tostring(size and size[1]) .. " for " .. tostring(sw))
	local point, relative, relativePoint = minimap:GetPoint(1)
	assert(minimap:GetNumPoints() == 1 and point == "CENTER" and relative == face.mapArea and relativePoint == "CENTER", what .. ": one CENTER point on the lens square")
end
Fits("adopted")
assert(env._zoom == 2 and (env._zoomCalls or 0) == 0, "fitting the map leaves the player's zoom alone: " .. tostring(env._zoomCalls) .. " zoom calls")
-- The Lumen card: the element is one rounded card; the round lens sits under a head that carries the north mark
-- and over a foot that carries the zone and the clock. The lens is as large as the card's width or the room
-- between head and foot allows, and it is centred.
local Format = ns.Format
assert(W.Near(face.box:GetWidth(), holder:GetWidth()) and W.Near(face.box:GetHeight(), holder:GetHeight()), "the card fills the element")
assert(face.chrome.fill[5]:IsShown(), "the card's glass stays under the lens: the frost shows round the circle")
local pad = face.chrome:Inset()
local lensLeft, lensTop, lens = Format.Lens(holder:GetWidth(), holder:GetHeight(), pad, Format.HEAD, Format.FOOT)
assert(W.Near(mw, lens, 0.5), "the lens is the largest circle under the head and over the foot: " .. tostring(mw) .. " for " .. tostring(lens))
assert(W.Near(select(4, face.mapArea:GetPoint(1)), lensLeft, 0.5) and W.Near(select(5, face.mapArea:GetPoint(1)), -lensTop, 0.5), "the lens is centred under the head")
assert(W.Near(lensLeft, (holder:GetWidth() - lens) / 2, 0.5), "Format.Lens centres the lens")
assert(W.Near(lensTop, Format.HEAD), "and hangs it under the head")
-- The round mask: the lens mask the material foundation names, or the kit's round dot until it lands, on the
-- Minimap frame, the face's own mask and the hybrid map.
local mask = face.mask
local lensMask = (K.Widgets.LumenTexture("lensMask"))
assert(mask and W.LastCall(mask, "SetTexture")[1] == lensMask, "the face owns a mask texture with the round lens mask")
assert(LastArg(mask, "SetAllPoints") == face.mapArea, "the mask covers the lens square")
assert(LastArg(minimap, "SetMaskTexture") == lensMask, "the minimap wears the round lens mask")
-- The foot: zone at the left in the heading role, clock at the right in the number role, on the card's glass.
assert(face.strip.fill == nil and face.strip.divider == nil, "the foot has no plate and no divider of its own: the card is the surface")
assert(W.Near(face.strip:GetHeight(), Format.FOOT), "the foot is the card's foot height: " .. tostring(face.strip:GetHeight()))
local sp, srel, srelp, sx = face.strip:GetPoint(1)
assert(sp == "TOPLEFT" and srel == face.mapArea and srelp == "BOTTOMLEFT" and W.Near(sx, pad - lensLeft, 0.5), "the foot hangs under the lens, from the card's inset")
local _, stripRel, stripRelPoint, stripX = face.strip:GetPoint(2)
assert(stripRel == face.box and stripRelPoint == "BOTTOMRIGHT" and W.Near(stripX, -pad), "and reaches the card's inset at the right")
assert(select(1, face.zone:GetPoint(1)) == "LEFT" and W.Near(select(4, face.zone:GetPoint(1)), 0), "the zone name starts at the foot's left")
assert(select(1, face.clock:GetPoint(1)) == "RIGHT" and W.Near(select(4, face.clock:GetPoint(1)), 0), "the clock ends at the foot's right")
local _, zoneSize = face.zone:GetFont()
local _, clockSize = face.clock:GetFont()
assert(W.Near(zoneSize, 14 * K.Theme.FontScale()) and W.Near(clockSize, 14 * K.Theme.FontScale()), "the zone and the clock read at size 14")
assert(select(1, face.zone:GetFont()) == (K.Tokens.Font("heading")), "the zone reads in the heading face: Cinzel once the material lands")
assert(select(1, face.clock:GetFont()) == (K.Tokens.Font("number")), "the clock reads in the number face")
-- The north mark: a gilt letter in the head, on the glass, with no plate of its own.
assert(face.compassPlate == nil, "the north mark has no plate: it sits on the card")
local cp, crel, crelp, _, cy = face.compass:GetPoint(1)
assert(cp == "TOP" and crel == face.box and crelp == "TOP" and W.Near(-cy, (Format.HEAD - face.compassSize) / 2, 1), "the N is centred in the head: " .. tostring(cy))
local gr, gg, gb = K.Widgets.LumenColor("gilt")
assert(W.SameRGB(face.compass, gr, gg, gb) or select(1, face.compass:GetTextColor()) == gr, "the N is gilt")
local _, compassSize = face.compass:GetFont()
assert(W.Near(compassSize, 16 * K.Theme.FontScale()), "the N reads at the heading size: " .. tostring(compassSize))

-- The zoom slider inside the map's right edge ------------------------------------------------------

local zoom = face.zoom
assert(zoom and zoom:IsShown() and zoom.track and zoom.fill, "a zoom slider stands inside the map's right edge")
assert(W.Near(zoom.track:GetWidth(), 2) and W.Near(zoom.track:GetHeight(), 52), "the track is the mockup's 2 by 52 line")
local tp, trel, trelp, tx, ty = zoom.track:GetPoint(1)
assert(tp == "LEFT" and trel == face.mapArea and trelp == "LEFT" and W.Near(tx, 11) and W.Near(ty, 0), "it stands inside the lens's left edge, at its widest, 11 in: " .. tostring(tp) .. " " .. tostring(tx) .. " " .. tostring(ty))
assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the fill takes the accent")
assert(W.Near(zoom.fill:GetHeight(), 52 * 2 / 5, 0.5), "zoom 2 of 6 levels fills two fifths of the track: " .. tostring(zoom.fill:GetHeight()))
env._zoom = 5
env.FireEvent("MINIMAP_UPDATE_ZOOM")
assert(W.Near(zoom.fill:GetHeight(), 52, 0.5), "MINIMAP_UPDATE_ZOOM refills the track: the last level fills it")
assert(zoom:GetWidth() > 2, "the hit area is wider than the line")
zoom.track.GetBottom = function()
	return 100
end
local zscale = zoom.track:GetEffectiveScale()
env.GetCursorPosition = function()
	return 0, (100 + 52 * 0.62) * zscale
end
env._zoomCalls = 0
zoom:GetScript("OnMouseDown")(zoom, "LeftButton")
assert(env._zoom == 3 and env._zoomCalls == 1, "pressing on the track sets the nearest zoom level: " .. tostring(env._zoom))
env.GetCursorPosition = function()
	return 0, (100 + 52 * 1.5) * zscale
end
zoom:GetScript("OnUpdate")(zoom, 0.016)
assert(env._zoom == 5, "dragging past the top clamps to the last level")
zoom:GetScript("OnMouseUp")(zoom, "LeftButton")
assert(zoom:GetScript("OnUpdate") == nil, "the drag ends on release")
env.GetCursorPosition = function()
	return 0, (100 + 52 * 0.2) * zscale
end
K.Options.Write("Minimap", "zoom.reset", true)
zoom:GetScript("OnMouseDown")(zoom, "LeftButton")
zoom:GetScript("OnMouseUp")(zoom, "LeftButton")
assert(env._zoom == 1, "a press zooms before the reset")
env.RunTimers()
assert(env._zoom == 0, "with zoom back out on, a slider zoom returns to 0 after the delay")
assert(not zoom.fill:IsShown() and zoom.fill:GetHeight() == 0, "and the fill empties with it, without waiting for an event")
K.Options.Write("Minimap", "zoom.reset", false)
-- A client without a zoom API or a cursor position leaves the slider and the wheel inert, with no error.
do
	local getZoom, setZoom, levels, cursor = env.Minimap.GetZoom, env.Minimap.SetZoom, env.Minimap.GetZoomLevels, env.GetCursorPosition
	env.Minimap.GetZoom, env.Minimap.GetZoomLevels = nil, nil
	env.GetCursorPosition = nil
	local ok, err = pcall(function()
		env.FireEvent("MINIMAP_UPDATE_ZOOM")
		zoom:GetScript("OnMouseDown")(zoom, "LeftButton")
		zoom:GetScript("OnMouseUp")(zoom, "LeftButton")
	end)
	assert(ok, "a missing zoom API or cursor position raises nothing: " .. tostring(err))
	env.Minimap.GetZoom, env.Minimap.SetZoom, env.Minimap.GetZoomLevels, env.GetCursorPosition = getZoom, setZoom, levels, cursor
end
env.Minimap:SetZoom(4)
assert(W.Near(zoom.fill:GetHeight(), 52 * 4 / 5, 0.5), "a zoom by Blizzard's own code, as the gamepad stick makes, refills the track through a secure hook")
K.Options.Write("Minimap", "zoom.slider", false)
assert(not zoom:IsShown(), "the slider can be turned off")
K.Options.Write("Minimap", "zoom.slider", true)
assert(zoom:IsShown(), "and on again")
assert(LastArg(minimap, "SetMaskTexture") == lensMask, "the minimap uses the round lens mask")
for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
	assert(LastArg(minimap, method) == 1, method .. "(1) keeps the round blob ring, which fits a round lens")
end
for _, frame in ipairs({ env.MinimapCluster, env.MinimapBackdrop, minimap.ZoomIn, minimap.ZoomOut, minimap.ZoomHitArea }) do
	assert(K.Safe.IsHidden(frame), "Blizzard's cluster, border and zoom buttons are hidden through Safe")
end
assert(env.GetMinimapShape and env.GetMinimapShape() == "ROUND", "minimap button libraries see a round map")

env.MinimapCluster.UpdateMinimapConfig()
assert(LastArg(minimap, "SetMaskTexture") == lensMask, "a Blizzard minimap refresh keeps the round mask")

M.Resize(holder, 318, 326)
mw, mh = face.mapArea:GetSize()
local bigLeft, bigTop, bigLens = Format.Lens(318, 326, face.chrome:Inset(), Format.HEAD, Format.FOOT)
assert(mw == mh and W.Near(mw, bigLens, 0.5), "the Lumen footprint, 318 by 326, gives the mockup's lens: " .. tostring(mw) .. " for " .. tostring(bigLens))
assert(bigLens >= 250 and bigLens <= 272, "a lens of about 262 on the 318 card, got " .. tostring(bigLens))
assert(W.Near(select(4, face.mapArea:GetPoint(1)), bigLeft, 0.5) and W.Near(select(5, face.mapArea:GetPoint(1)), -bigTop, 0.5), "the lens is centred under the head at the new size")
Fits("resized")
M.Resize(holder, 168, 166)
Fits("shrunk")

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
local _, clockSizeNow = face.clock:GetFont()
assert(W.Near(clockSizeNow, 14 * K.Theme.FontScale()), "the clock reads at the mockup's size 14 by default: " .. tostring(clockSizeNow))
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

assert(face.clock:IsShown() and face.zone:IsShown(), "the zone and the clock share the foot")
K.Options.Write("Minimap", "clock.shown", false)
assert(not face.clock:IsShown(), "the clock hides from the strip")
assert(face.zone:IsShown(), "the zone stays")
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
assert(not face.coords:IsShown(), "coordinates are off by default, as the design file has none")
K.Options.Write("Minimap", "coords.shown", true)
assert(face.coords:GetText() == "45.3, 62.2", "coordinates show in tenths once turned on: " .. tostring(face.coords:GetText()))
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
assert(face.compass:GetText() == "N", "a single letter in the head")
env._cvars.rotateMinimap = true
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "1")
assert(not face.compass:IsShown(), "a rotating map hides the north mark")
env._cvars.rotateMinimap = env.Secret(false)
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "0")
assert(not face.compass:IsShown(), "a secret rotation hides the north mark rather than guess")
env._cvars.rotateMinimap = false
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "0")
assert(face.compass:IsShown(), "the north mark comes back")

-- Blizzard's hybrid map is a child of Minimap fixed at BACKGROUND strata, level 100. The card keeps its frost
-- under the lens, so the holder sits on BACKGROUND under that level and the overlay above it: the hybrid map draws
-- between the card and the lens's slider and coordinates.

K.Widgets.RestyleAll()
assert(face.chrome.fill[5]:IsShown(), "the fill's centre stays after a restyle")
assert(holder:GetFrameStrata() == "BACKGROUND", "the card sits on the BACKGROUND strata, where the hybrid map is fixed")
assert(face.box:GetFrameLevel() < 100 and minimap:GetFrameLevel() < 100, "the card and the map sit under the hybrid map's fixed level 100")
assert(face.overlay:GetFrameLevel() > 100 and face.wheel:GetFrameLevel() > face.overlay:GetFrameLevel(), "the overlay and the wheel catcher sit above it")

-- The accent: the card's rim is the Lumen rim light like every rail card; the accent colours the zoom fill ------

local inner = face.chrome.rim[5]
assert(W.SameRGB(inner, K.Tokens.Color("edgeInner")), "the card's rim is the kit's rim, not the class colour")
assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the zoom fill follows the class colour")
K.Options.Write("Minimap", "accent.source", "custom")
K.Options.Write("Minimap", "accent.color", { r = 1, g = 0, b = 0 })
assert(W.SameRGB(zoom.fill, 1, 0, 0), "a custom accent colours the zoom fill")
assert(W.SameRGB(inner, K.Tokens.Color("edgeInner")), "and leaves the rim alone")
K.Options.Write("Minimap", "accent.source", "class")
assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the class colour comes back")

-- The hybrid minimap gets the square mask too -------------------------------------------------------

env.HybridMinimap = { CircleMask = env.CreateFrame("Frame", nil, env.UIParent):CreateMaskTexture() }
env.FireEvent("ADDON_LOADED", "Blizzard_HybridMinimap")
assert(LastArg(env.HybridMinimap.CircleMask, "SetTexture") == lensMask, "the hybrid minimap wears the lens mask")

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
	assert(bns.Settings.Get("column.side") == "right", "an unknown button side uses the default, the lens's right")
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
	assert(pface.zoom:IsShown() and W.Near(pface.zoom.fill:GetHeight(), 52, 0.5), "the preview shows the zoom slider full, as the mockup draws it")
	assert(frame.terrain and frame.terrain:GetMaskTexture(1) == pface.mask, "the preview's drawn terrain clips to the same chamfered mask as the live map")
	PK.Options.Write("Minimap", "clock.shown", false)
	frame:Refresh()
	assert(not pface.clock:IsShown(), "the preview follows the settings")
	NoErrors(penv, "preview")
end

print("minimap ok")
