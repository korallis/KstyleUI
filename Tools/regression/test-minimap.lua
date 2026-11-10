-- test-minimap.lua: the square minimap as the owner's picture draws it: off until enabled, its Layout element, the square mask inside a gilt pixel rim, the north plate, the caption under the map, the buttons at rest, the hover group, the Blizzard pieces it hides, wheel zoom, coordinates, the migration from the lens card, the accent and turning it off.
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
-- The picture (LEE-20, which wins over #207): the map is 188 units square, the element itself, with 28 units of
-- caption under it in the element's reserve.
assert(holder:GetWidth() == 188 and holder:GetHeight() == 188, "the element is a 188-unit square at the 1080 reference: " .. tostring(holder:GetWidth()) .. "x" .. tostring(holder:GetHeight()))
assert(K.Setup.Layouts.Element("minimap.main").reserve[2] == 188 + ns.Format.CAPTION, "the layout reserves the caption's 36 units under the map")
assert(element.opts.minWidth == 100 and element.opts.maxWidth == 320 and element.opts.minHeight == 100 and element.opts.maxHeight == 320, "it resizes from 100 to 320 units, square")

local minimap = env.Minimap
local face = Map(ns)
assert(minimap:GetParent() == holder, "Blizzard's minimap moves into KstyleUI's frame")
local mw, mh = face.mapArea:GetSize()
assert(mw == mh, "the map stays square")
-- The engine draws the terrain at the size the Minimap was given with SetSize, from the frame's bottom left
-- corner; anchors alone leave Blizzard's 198 render in a larger square (ingame-18: a dark band on the right and
-- the top). So the map takes an explicit size equal to the map square and one CENTER point on it. Fitting never
-- touches the zoom: nothing in Forever's source shows the engine needs a zoom change to draw at a new size.
local function Fits(what)
	local size = W.LastCall(minimap, "SetSize")
	local sw, sh = face.mapArea:GetSize()
	assert(size and W.Near(size[1], sw) and W.Near(size[2], sh), what .. ": the minimap's own size is the map square's: " .. tostring(size and size[1]) .. " for " .. tostring(sw))
	local point, relative, relativePoint = minimap:GetPoint(1)
	assert(minimap:GetNumPoints() == 1 and point == "CENTER" and relative == face.mapArea and relativePoint == "CENTER", what .. ": one CENTER point on the map square")
end
Fits("adopted")
assert(env._zoom == 2 and (env._zoomCalls or 0) == 0, "fitting the map leaves the player's zoom alone: " .. tostring(env._zoomCalls) .. " zoom calls")
-- The square: the map is the element, with square corners (no chamfer, no inset, no card), edged by one gilt
-- pixel line on each side and a dark line just inside it.
local Format = ns.Format
assert(W.Near(face.box:GetWidth(), holder:GetWidth()) and W.Near(face.box:GetHeight(), holder:GetHeight()), "the map fills the element")
assert(face.dome == nil and face.foot == nil and face.strip == nil and face.chrome == nil, "no dome, no foot card, no strip and no chrome: the rim is lines")
assert(W.Near(mw, 188, 0.5), "the map is the element, 188 units: " .. tostring(mw))
local ap, arel, arelp = face.mapArea:GetPoint(1)
assert(ap == "TOPLEFT" and arel == face.box and arelp == "TOPLEFT", "the map starts at the element's corner, with no inset")
local pixel = K.Widgets.Border(face.mapArea)
for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
	local line = face.rim[edge]
	assert(line and line:IsShown() and W.SameRGB(line, K.Tokens.Color("gilt")), "the " .. edge .. " rim line is the kit's gilt")
	local thickness = (edge == "top" or edge == "bottom") and line:GetHeight() or line:GetWidth()
	assert(W.Near(thickness, pixel, 1e-6), "the " .. edge .. " rim line is one physical pixel thick")
	local shade = face.shade[edge]
	assert(shade and W.SameRGB(shade, K.Tokens.Color("black")), "a dark line follows it on the inside")
end
local rp, rrel, rrelp, rx, ry = face.rim.top:GetPoint(1)
assert(rp == "TOPLEFT" and rrel == face.mapArea and rrelp == "TOPLEFT" and rx == 0 and ry == 0, "the rim sits on the map's own edge")
local sp, _, _, sx, sy = face.shade.top:GetPoint(1)
assert(sp == "TOPLEFT" and W.Near(sx, pixel, 1e-6) and W.Near(sy, -pixel, 1e-6), "and the dark line one pixel inside it")
-- The square mask: the plain square MinimapMask on the Minimap frame, the face's own mask (the preview's terrain)
-- and the hybrid map. The lens mask stays in the kit for the portraits.
local mask = face.mask
local squareMask = (K.Tokens.Texture("minimapMask"))
assert(mask and W.LastCall(mask, "SetTexture")[1] == squareMask, "the face owns a mask texture with the square mask")
assert(LastArg(mask, "SetAllPoints") == face.mapArea, "the mask covers the map square")
assert(LastArg(minimap, "SetMaskTexture") == squareMask, "the minimap wears the square mask")
-- The N plate: a round gilt plate 16 units across, centred on the map's top edge at its horizontal centre.
local plate = face.plate
assert(plate and W.Near(plate:GetWidth(), Format.NORTH, 1) and W.Near(plate:GetHeight(), Format.NORTH, 1), "the north plate is 16 units across: " .. tostring(plate and plate:GetWidth()))
local pp, prel, prelp, px, py = plate:GetPoint(1)
assert(pp == "CENTER" and prel == face.mapArea and prelp == "TOP" and px == 0 and py == 0, "centred on the middle of the map's top edge")
assert(plate.crystal and plate.crystal.disc:IsShown() and plate.crystal.ring:IsShown(), "a dark disc with a ring")
local ring = plate.crystal.ring
local gr, gg, gb = K.Tokens.Color("gilt")
local rr, rg, rb = ring:GetVertexColor()
assert(W.Near(rr, gr) and W.Near(rg, gg) and W.Near(rb, gb), "its ring is gilt")
assert(face.north:GetText() == K.L["N"] and face.north:GetParent() == plate, "its letter is the N the locale gives")
local nr, ng, nb = face.north:GetTextColor()
assert(W.Near(nr, gr) and W.Near(ng, gg) and W.Near(nb, gb), "in gilt")
assert(select(1, face.north:GetFont()) == (K.Tokens.Font("heading")), "in the heading face")
assert(plate:GetFrameLevel() > face.overlay:GetFrameLevel(), "the plate lies over the rim")
-- The caption under the map: no band and no fade inside the map. The zone name's caps are centred 13.7 units under
-- the map's bottom edge, 2 units in from its left; the coordinates sit under it at the left and the clock at the
-- right edge less 2, both 31.2 under the map's bottom edge. Nothing draws inside the map.
assert(face.zoneBand == nil and face.clockBand == nil, "no bands")
local zp1, zrel1, zrelp1, zx, zy = face.zone:GetPoint(1)
assert(zp1 == "LEFT" and zrel1 == face.mapArea and zrelp1 == "BOTTOMLEFT" and W.Near(zx, Format.CAPTION_X, 1) and W.Near(zy, -Format.ZONE_CENTER, 1), "the zone name starts 2 units in from the map's left edge, under the map: " .. tostring(zx) .. ", " .. tostring(zy))
assert(W.LastCall(face.zone, "SetJustifyH")[1] == "LEFT", "and reads from the left")
assert(W.Near(face.zone:GetWidth(), 188 - 2 * Format.CAPTION_X, 1), "its width is the map's less 2 at each end, so a long name truncates")
local cp1, crel1, crelp1, cx1, cy1 = face.coords:GetPoint(1)
assert(cp1 == "LEFT" and crel1 == face.mapArea and crelp1 == "BOTTOMLEFT" and W.Near(cx1, Format.CAPTION_X, 1) and W.Near(cy1, -Format.ROW_CENTER, 1), "the coordinates sit under the zone name, at the left")
local kp1, krel1, krelp1, kx1, ky1 = face.clock:GetPoint(1)
assert(kp1 == "RIGHT" and krel1 == face.mapArea and krelp1 == "BOTTOMRIGHT" and W.Near(kx1, -Format.CAPTION_X, 1) and W.Near(ky1, -Format.ROW_CENTER, 1), "the clock sits at the right edge less 2, on the coordinates' line")
assert(W.LastCall(face.clock, "SetJustifyH")[1] == "RIGHT", "reading from the right")
assert(face.zone:GetParent() == face.caption and face.caption:GetFrameLevel() > 100, "the caption lies over the map and the hybrid map")
local _, zoneSize = face.zone:GetFont()
local _, clockSize = face.clock:GetFont()
local _, coordsSize = face.coords:GetFont()
assert(W.Near(zoneSize, 12 * K.Theme.FontScale(), 1) and W.Near(clockSize, 12.5 * K.Theme.FontScale(), 1) and W.Near(coordsSize, 11.5 * K.Theme.FontScale(), 1), "the zone reads at 12, the clock at 12.5 and the coordinates at 11.5, snapped to the pixel grid: " .. tostring(zoneSize) .. ", " .. tostring(clockSize) .. ", " .. tostring(coordsSize))
assert(select(1, face.zone:GetFont()) == (K.Tokens.Font("names")), "the zone reads in the names role, the picture's white names: lightly tracked, with the kit's shadow")
local zoneShadow = W.LastCall(face.zone, "SetShadowOffset")
assert(zoneShadow and zoneShadow[1] ~= 0 and zoneShadow[2] ~= 0, "and the zone keeps the kit's text shadow")
local zr0, zg0, zb0 = face.zone:GetTextColor()
local zer, zeg, zeb = K.Tokens.Color("textEmphasis")
assert(W.Near(zr0, zer) and W.Near(zg0, zeg) and W.Near(zb0, zeb), "and near white (the picture measures #f3f5f8), not capsGold")
assert(select(1, face.clock:GetFont()) == (K.Tokens.Font("number")), "the clock reads in the bold number face")
assert(select(1, face.coords:GetFont()) == (K.Tokens.Font("body")), "the coordinates read in the body face")
local mr, mg, mb = face.coords:GetTextColor()
local qr, qg, qb = K.Tokens.Color("muted")
assert(W.Near(mr, qr) and W.Near(mg, qg) and W.Near(mb, qb), "the coordinates are muted grey")
local wr, wg, wb = face.clock:GetTextColor()
local er0, eg0, eb0 = K.Tokens.Color("textEmphasis")
assert(W.Near(wr, er0) and W.Near(wg, eg0) and W.Near(wb, eb0), "the clock is white")
assert(face.compass == nil and face.compassPlate == nil, "the old compass fields stay gone: the plate is face.plate")

-- Hidden until hover: the zoom slider lives in a reveal group that shows while the pointer is over the element and
-- hides a short grace after it leaves. The tracking, calendar and drawer buttons join it only with the Buttons only
-- on hover setting (off by default: the picture shows them at rest). The mail and queue indicators, which carry
-- information, stay out of it.
local reveal = face.reveal
assert(reveal and not reveal:IsShown(), "the reveal group waits hidden")
assert(reveal:GetParent() == holder and LastArg(reveal, "SetAllPoints") == face.mapArea, "it covers the map square")
assert(reveal:GetFrameLevel() > face.overlay:GetFrameLevel(), "above the caption")
assert(face.zoom:GetParent() == reveal, "the zoom slider is in the group")
local column = ns.Map.column
assert(column.buttons.tracking:GetParent() == column.host and column.buttons.calendar:GetParent() == column.host and column.buttons.drawer:GetParent() == column.host, "at rest the three buttons are on the always-shown host")
K.Options.Write("Minimap", "column.hover", true)
assert(column.buttons.tracking:GetParent() == reveal and column.buttons.calendar:GetParent() == reveal and column.buttons.drawer:GetParent() == reveal, "so are the tracking, calendar and drawer buttons")
assert(column.buttons.mail:GetParent() == column.host and column.buttons.queue:GetParent() == column.host and column.host:GetParent() == holder, "the mail and queue indicators stay on the always-shown host")
holder._mouseOver = true
env.Minimap:GetScript("OnEnter")(env.Minimap)
M.Settle(env)
assert(reveal:IsShown() and reveal:GetAlpha() == 1, "hovering Blizzard's map frame reveals the group")
env.Minimap:GetScript("OnLeave")(env.Minimap)
M.Settle(env)
assert(reveal:IsShown() and reveal:GetAlpha() == 1, "leaving the map frame for one of the buttons over it keeps the group: the pointer is still over the element")
holder._mouseOver = false
column.buttons.tracking:GetScript("OnLeave")(column.buttons.tracking)
M.Settle(env)
assert(not reveal:IsShown(), "once the pointer leaves the element, the group hides after a short grace")
holder._mouseOver = true
column.buttons.mail:GetScript("OnEnter")(column.buttons.mail)
M.Settle(env)
assert(reveal:IsShown(), "entering the element over the mail indicator reveals the group too")
-- A menu one of the buttons opened keeps the group: Blizzard_Menu closes a menu whose owner is not visible, so
-- the tracking button must stay while its menu is open, even with the pointer in the menu off the map.
W.Click(column.buttons.tracking)
local menu = env._menus[#env._menus].menu
assert(menu and menu.open, "the tracking menu is open")
holder._mouseOver = false
column.buttons.tracking:GetScript("OnLeave")(column.buttons.tracking)
for _ = 1, 40 do
	W.Tick(env, 0.016)
end
assert(reveal:IsShown() and reveal:GetAlpha() == 1, "the group stays while the tracking menu is open")
menu.open = false
M.Settle(env)
assert(not reveal:IsShown(), "and hides once the menu closes")
-- The secure overlay takes a button's hover: leaving the element from the overlay hides the group too.
holder._mouseOver = true
env.Minimap:GetScript("OnEnter")(env.Minimap)
M.Settle(env)
W.Enter(column.buttons.calendar)
local overlay = ns.SecureClick.overlay
assert(overlay and overlay:IsShown(), "the secure overlay covers the hovered calendar button")
holder._mouseOver = false
W.Leave(overlay)
M.Settle(env)
assert(not reveal:IsShown(), "leaving the element from the secure overlay hides the group")
holder._mouseOver = true
env.Minimap:GetScript("OnEnter")(env.Minimap)
M.Settle(env)
NoErrors(env, "hover")
K.Options.Write("Minimap", "column.hover", false)

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
assert(LastArg(minimap, "SetMaskTexture") == squareMask, "the minimap uses the chamfered square mask")
for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
	assert(LastArg(minimap, method) == 0, method .. "(0) drops the round blob ring, which would cut across a square map's corners")
end
for _, frame in ipairs({ env.MinimapCluster, env.MinimapBackdrop, minimap.ZoomIn, minimap.ZoomOut, minimap.ZoomHitArea }) do
	assert(K.Safe.IsHidden(frame), "Blizzard's cluster, border and zoom buttons are hidden through Safe")
end
assert(env.GetMinimapShape and env.GetMinimapShape() == "SQUARE", "minimap button libraries see a square map")

env.MinimapCluster.UpdateMinimapConfig()
assert(LastArg(minimap, "SetMaskTexture") == squareMask, "a Blizzard minimap refresh keeps the square mask")

M.Resize(holder, 200, 200)
mw, mh = face.mapArea:GetSize()
assert(mw == mh and W.Near(mw, 200, 0.5), "a 200 element gives a 200 map: " .. tostring(mw))
assert(W.Near(face.zone:GetWidth(), 200 - 2 * Format.CAPTION_X, 1), "and the zone name's room grows with it")
assert(W.Near(face.plate:GetWidth(), Format.NORTH, 1) and select(3, face.plate:GetPoint(1)) == "TOP", "while the north plate stays 16 units on the top edge")
Fits("resized")
M.Resize(holder, 168, 166)
Fits("shrunk")
M.Resize(holder, 188, 188)

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

-- The caption: zone, coordinates and clock -------------------------------------------------------------

assert(face.zone:GetText() == "RIVERGLADES", "the caption shows the zone in capitals: " .. tostring(face.zone:GetText()))
env._zone.text = "Hall of Thanes"
env.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(face.zone:GetText() == "HALL OF THANES", "a zone change updates the caption")
-- Capitals keep their accents (the round 4 localisation carry list): a French zone name reads in accented capitals.
env._zone.text = "For\195\170t d'\195\137lwynn"
env.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(face.zone:GetText() == "FOR\195\138T D'\195\137LWYNN", "accented capitals: " .. tostring(face.zone:GetText()))
env._zone.text = "Hall of Thanes"
env.FireEvent("ZONE_CHANGED_NEW_AREA")
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
assert(W.Near(clockSizeNow, 12.5 * K.Theme.FontScale(), 1), "the clock reads at size 12.5 by default, snapped to the pixel grid: " .. tostring(clockSizeNow))
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

assert(face.clock:IsShown() and face.zone:IsShown(), "the zone and the clock each show under the map")
K.Options.Write("Minimap", "clock.shown", false)
assert(not face.clock:IsShown() and not face.clockHit:IsShown(), "the clock hides with its hit area")
assert(face.zone:IsShown() and face.zoneHit:IsShown(), "the zone stays")
K.Options.Write("Minimap", "zone.shown", false)
assert(not face.zone:IsShown() and not face.zoneHit:IsShown(), "the zone hides with its hit area")
K.Options.Write("Minimap", "zone.shown", true)
K.Options.Write("Minimap", "clock.shown", true)
assert(face.zone:IsShown() and face.zoneHit:IsShown() and face.clock:IsShown() and face.clockHit:IsShown(), "the zone and the clock come back")

K.Options.Write("Minimap", "clock.size", 16)
local _, size = face.clock:GetFont()
assert(W.Near(size, 16 * K.Theme.FontScale()), "the clock takes its own text size")
K.Options.Write("Minimap", "clock.outline", "OUTLINE")
local _, _, flags = face.clock:GetFont()
assert(flags == "OUTLINE", "the clock takes its own outline")

-- Coordinates -------------------------------------------------------------------------------------

env._position = { 0.4532, 0.6218 }
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
assert(K.Store.Defaults("Minimap").coords.shown == true, "coordinates are on by default: the picture shows them (LEE-20); the setting stays")
assert(face.coords:GetText() == "45.3, 62.2", "coordinates show in tenths: " .. tostring(face.coords:GetText()))
assert(face.coords:IsShown(), "and show")
local xp, xrel, xrelp = face.coords:GetPoint(1)
assert(xp == "LEFT" and xrel == face.mapArea and xrelp == "BOTTOMLEFT", "the coordinates sit under the zone name, at the left")
local cpoint, crel, crelp = face.clock:GetPoint(1)
assert(cpoint == "RIGHT" and crel == face.mapArea and crelp == "BOTTOMRIGHT", "and the clock at the right")
assert(K.Store.Defaults("Minimap").coords.position == nil, "the coordinate position setting is gone: the caption is the one place")
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
cpoint = face.clock:GetPoint(1)
assert(cpoint == "RIGHT", "and the clock stays at the right")
K.Options.Write("Minimap", "coords.shown", true)

-- No north mark: a rotating map changes nothing the module draws ------------------------------------

assert(K.Store.Defaults("Minimap").compass == nil, "the north mark setting is gone")
env._cvars.rotateMinimap = true
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "1")
env.MinimapCluster.UpdateMinimapConfig()
assert(LastArg(minimap, "SetMaskTexture") == squareMask, "a rotating map keeps the square mask")
env._cvars.rotateMinimap = false
env.FireEvent("CVAR_UPDATE", "rotateMinimap", "0")
NoErrors(env, "rotation")

-- Blizzard's hybrid map is a child of Minimap fixed at BACKGROUND strata, level 100, so the holder sits on
-- BACKGROUND under that level and the overlay above it: the hybrid map draws between the map and the rim.

K.Widgets.RestyleAll()
assert(W.SameRGB(face.rim.top, K.Tokens.Color("gilt")) and face.rim.top:IsShown(), "a restyle keeps the gilt rim")
assert(holder:GetFrameStrata() == "BACKGROUND", "the element sits on the BACKGROUND strata, where the hybrid map is fixed")
assert(face.box:GetFrameLevel() < 100 and minimap:GetFrameLevel() < 100, "the rim and the map sit under the hybrid map's fixed level 100")
assert(face.overlay:GetFrameLevel() > 100 and face.wheel:GetFrameLevel() > face.reveal:GetFrameLevel(), "the overlay and the wheel catcher sit above it")

-- The accent: the rim is gilt, not the class colour; the accent colours the zoom fill ------------------

local inner = face.rim.top
assert(W.SameRGB(inner, K.Tokens.Color("gilt")), "the rim is the kit's gilt, not the class colour")
assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the zoom fill follows the class colour")
K.Options.Write("Minimap", "accent.source", "custom")
K.Options.Write("Minimap", "accent.color", { r = 1, g = 0, b = 0 })
assert(W.SameRGB(zoom.fill, 1, 0, 0), "a custom accent colours the zoom fill")
assert(W.SameRGB(inner, K.Tokens.Color("gilt")) and W.SameRGB(plate.crystal.ring, K.Tokens.Color("gilt")), "and leaves the rim and the north plate alone")
K.Options.Write("Minimap", "accent.source", "class")
assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the class colour comes back")

-- The hybrid minimap gets the square mask too -------------------------------------------------------

env.HybridMinimap = { CircleMask = env.CreateFrame("Frame", nil, env.UIParent):CreateMaskTexture() }
env.FireEvent("ADDON_LOADED", "Blizzard_HybridMinimap")
assert(LastArg(env.HybridMinimap.CircleMask, "SetTexture") == squareMask, "the hybrid minimap wears the square mask")

NoErrors(env, "enabled")

-- Turning it off ------------------------------------------------------------------------------------

K.Modules.Disable("Minimap")
M.Settle(env)
assert(not holder:IsShown(), "turning the module off hides its frame")
assert(minimap:GetParent() == env.MinimapCluster.MinimapContainer, "Blizzard's minimap goes back to its container")
assert(not K.Safe.IsHidden(env.MinimapCluster), "Blizzard's cluster comes back")
assert(M.LiveTickers(env) == 0, "the clock stops ticking")
assert(env.GetMinimapShape == nil, "the square shape is withdrawn")
for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
	assert(LastArg(minimap, method) == 1, method .. "(1) gives Blizzard's round map its blob ring back")
end
assert(M.CoreEnv.Printed(env, "/reload"), "turning a reskin off asks for a reload")
NoErrors(env, "disabled")

-- Migration from the lens card: version 4 data loses the north mark and the coordinate position, and a saved size
-- for the element, which was the lens card's 318 by 346 footprint, so the square takes its new default size.
-- Tuned button sizes and the element's position stay.

do
	local saved = {
		version = 4,
		profiles = { Default = { Minimap = { enabled = true, compass = false, coords = { shown = true, position = "bottom" }, column = { size = 26 } } },
			Alt = { Minimap = { compass = true } } },
		characters = {},
		layouts = { Default = { ["minimap.main"] = { anchor = "TOPRIGHT", x = -40, y = -30, width = 318, height = 346 } } },
		account = { setupSeen = true },
		devlog = {},
	}
	local menv, mK, mns = M.New({ saved = saved, position = { 0.5, 0.5 } })
	M.Settle(menv)
	local db = menv.KstyleUIDB
	assert(db.version == mK.Store.DB_VERSION and db.version >= 5, "the saved data migrates to the current version: " .. tostring(db.version))
	local section = db.profiles.Default.Minimap
	assert(section.compass == nil and db.profiles.Alt.Minimap.compass == nil, "the north mark setting is dropped from every profile")
	assert(section.coords.position == nil and section.coords.shown == true, "the coordinate position is dropped and the other coordinate settings stay")
	assert(section.column.size == 26, "a tuned button size stays")
	local entry = db.layouts.Default["minimap.main"]
	assert(entry.width == nil and entry.height == nil, "the lens card's saved size is dropped")
	assert(entry.anchor == "TOPRIGHT" and entry.x == -40 and entry.y == -30, "the element's position stays")
	local mholder = M.Holder(mK)
	assert(mholder and mholder:GetWidth() == 188 and mholder:GetHeight() == 188, "so the square builds at its default size: " .. tostring(mholder:GetWidth()))
	assert(mns.Map.face.coords:IsShown(), "and the coordinates the player turned on still show")
	assert(#menv._errors == 0, "the migration raises no error: " .. tostring(menv._errors[1]))
end

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
	assert(pface.coords:IsShown() and pface.coords:GetText() == "45.3, 62.1", "the preview shows the coordinates, on by default: " .. tostring(pface.coords:GetText()))
	assert(pface.plate:IsShown() and pface.north:GetText() == PK.L["N"], "the preview shows the north plate")
	assert(W.Near(select(5, frame:GetPoint(1)), 18, 1), "the preview stands the map half the caption's 36 units above the centre, so the map and its caption sit centred together")
	assert(pface.zoom:IsShown() and W.Near(pface.zoom.fill:GetHeight(), 52, 0.5), "the preview shows the zoom slider full, as the mockup draws it")
	assert(frame.terrain and frame.terrain:GetMaskTexture(1) == pface.mask, "the preview's drawn terrain clips to the same chamfered mask as the live map")
	PK.Options.Write("Minimap", "clock.shown", false)
	frame:Refresh()
	assert(not pface.clock:IsShown(), "the preview follows the settings")
	NoErrors(penv, "preview")
end

print("minimap ok")
