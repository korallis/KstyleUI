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

local function TextIs(text, r, g, b)
	local tr, tg, tb = text:GetTextColor()
	return W.Near(tr, r) and W.Near(tg, g) and W.Near(tb, b)
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
-- The overhaul (KSTY-44's mock-ups, binding by the Captain's COMMON.md): the map is still 188 units square and the
-- element itself; the zone moved above it, so the element's reserve keeps only the 14-unit coordinate row under it.
assert(holder:GetWidth() == 188 and holder:GetHeight() == 188, "the element is a 188-unit square at the 1080 reference: " .. tostring(holder:GetWidth()) .. "x" .. tostring(holder:GetHeight()))
assert(K.Setup.Layouts.Element("minimap.main").reserve[2] == 188 + ns.Format.CAPTION and ns.Format.CAPTION == 14, "the layout reserves the 14-unit coordinate row under the map")
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
-- The card: the map is the element, seated in a forged card 3 units wider on every side, under the map. The card's
-- frame is the kit's forged nine-slice and its corners the kit's forged brackets, drawn over the map's corners so
-- they read whole; a dark pixel line edges the map and a soft dark fall-off sits inside it.
local Format = ns.Format
assert(W.Near(face.mapArea:GetWidth(), holder:GetWidth()) and W.Near(face.mapArea:GetHeight(), holder:GetHeight()), "the map fills the element")
assert(W.Near(mw, 188, 0.5), "the map is the element, 188 units: " .. tostring(mw))
assert(face.rim == nil and face.ornament == nil and face.plaqueOrnament == nil, "no gilt rim and no forged ornament pieces: the card's brackets are the only ornament")
local card = face.card
assert(card:GetFrameLevel() < minimap:GetFrameLevel() and card:GetFrameLevel() > holder:GetFrameLevel(), "the card lies under the map")
assert(W.Near(card:GetWidth(), 188 + 2 * Format.FRAME, 1) and W.Near(card:GetHeight(), 188 + 2 * Format.FRAME, 1), "the card is 3 units wider than the map on every side: " .. tostring(card:GetWidth()))
local cardPoint, cardRel, cardRelPoint, cardX, cardY = card:GetPoint(1)
assert(cardPoint == "TOPLEFT" and cardRel == face.mapArea and cardRelPoint == "TOPLEFT" and W.Near(cardX, -Format.FRAME) and W.Near(cardY, Format.FRAME), "centred on the map")
assert(Format.FRAME == K.Setup.Layouts.MAP_FRAME, "the layouts set the map in by the card's frame, so the card's edge, not the square's, stands on the card margin (KSTY-60 item 28)")
do
	local Geometry = dofile("Tools/regression/geometry.lua")
	local root = K.Scale.Root()
	local cardBox = assert(Geometry.ScaledRect(card, env.UIParent, root))
	local rootBox = assert(Geometry.ScaledRect(root, env.UIParent, root))
	assert(W.Near(rootBox.right - cardBox.right, K.Tokens.Size("screenMargin"), 0.5), "the card ends on the card margin with the cards under it, got " .. tostring(rootBox.right - cardBox.right))
end
assert(W.SameRGB(face.fill, K.Tokens.Color("materialForged")) and face.fill:IsShown(), "its fill is the forged iron")
local pixel = K.Widgets.Border(face.mapArea)
local frameSlice
for name, slice in pairs(face.frames) do
	if slice[1]:IsShown() then
		frameSlice = name
	end
end
assert(frameSlice and frameSlice:find("^forgedFrame") and face.frames[frameSlice][1]:GetParent() == card, "its frame is the kit's forged nine-slice: " .. tostring(frameSlice))
for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
	local bracket = face.brackets[i]
	for _, arm in ipairs({ bracket.across, bracket.down }) do
		local point, relative = arm:GetPoint(1)
		assert(arm:IsShown() and point == corner and relative == card, "a gilt bracket arm on the card's " .. corner .. " corner")
		assert(W.SameRGB(arm, K.Tokens.Color("gilt")), "in the kit's gilt, as the mock-up's brackets")
		assert(arm:GetParent() == face.overlay, "over the map, so the map does not cover it")
	end
	assert(W.Near(bracket.across:GetWidth(), 8, 1) and W.Near(bracket.across:GetHeight(), 2 * pixel, 1e-6), "the arm across is 8 units long and two physical pixels thick")
	assert(W.Near(bracket.down:GetHeight(), 8, 1) and W.Near(bracket.down:GetWidth(), 2 * pixel, 1e-6), "and so is the arm down")
end
for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
	local shade = face.shade[edge]
	assert(shade and shade:IsShown() and W.SameRGB(shade, K.Tokens.Color("black")), "a dark line edges the map's " .. edge)
	local thickness = (edge == "top" or edge == "bottom") and shade:GetHeight() or shade:GetWidth()
	assert(W.Near(thickness, pixel, 1e-6), "one physical pixel thick")
	assert(face.vignette[edge]:GetParent() == face.overlay, "and a soft dark fall-off lies inside the " .. edge .. " edge")
end
local sp, srel, _, sx, sy = face.shade.top:GetPoint(1)
assert(sp == "TOPLEFT" and srel == face.mapArea and sx == 0 and sy == 0, "the dark line sits on the map's own edge")
-- The square mask: the plain square MinimapMask on the Minimap frame, the face's own mask (the preview's terrain)
-- and the hybrid map. The lens mask stays in the kit for the portraits.
local mask = face.mask
local squareMask = (K.Tokens.Texture("minimapMask"))
assert(mask and W.LastCall(mask, "SetTexture")[1] == squareMask, "the face owns a mask texture with the square mask")
assert(LastArg(mask, "SetAllPoints") == face.mapArea, "the mask covers the map square")
assert(LastArg(minimap, "SetMaskTexture") == squareMask, "the minimap wears the square mask")
-- The N plate: the mock-up's small diamond, gilt-edged dark iron with a black outer edge, centred on the map's top
-- edge, with a gilt-lit N in the number face.
local plate = face.plate
assert(plate and W.Near(plate:GetWidth(), Format.NORTH, 1) and W.Near(plate:GetHeight(), Format.NORTH, 1), "the north plate is " .. Format.NORTH .. " units across: " .. tostring(plate and plate:GetWidth()))
local pp, prel, prelp, px, py = plate:GetPoint(1)
assert(pp == "CENTER" and prel == face.mapArea and prelp == "TOP" and px == 0 and py == 0, "centred on the middle of the map's top edge")
local diamond = plate.diamond
assert(diamond and W.LastCall(diamond.gilt, "SetTexture")[1] == (K.Tokens.Texture("diamond")), "a diamond")
assert(W.SameRGB(diamond.gilt, K.Tokens.Color("gilt")) and W.SameRGB(diamond.fill, K.Tokens.Color("materialForged")) and W.SameRGB(diamond.black, K.Tokens.Color("black")), "gilt-edged forged iron with a black edge")
assert(diamond.black:GetWidth() > diamond.gilt:GetWidth() and diamond.gilt:GetWidth() > diamond.fill:GetWidth(), "nested from the black edge in")
assert(face.north:GetText() == K.L["N"] and face.north:GetParent() == plate, "its letter is the N the locale gives")
assert(TextIs(face.north, K.Tokens.Color("giltLit")), "in lit gilt")
assert(select(1, face.north:GetFont()) == (K.Tokens.Font("number")), "in the number face")
assert(plate:GetFrameLevel() > face.overlay:GetFrameLevel(), "the plate lies over the map's edge")
-- The zone in capitals above the card, from its left edge; the coordinates and the clock under it, at its left and
-- right edges. The texts stand on the world, so they take an outline and the kit's shadow (the world layer).
local zp1, zrel1, zrelp1, zx, zy = face.zone:GetPoint(1)
assert(zp1 == "LEFT" and zrel1 == face.card and zrelp1 == "TOPLEFT" and W.Near(zx, Format.CAPTION_X, 1) and W.Near(zy, Format.ZONE_CENTER, 1), "the zone name stands above the card from its left edge: " .. tostring(zx) .. ", " .. tostring(zy))
assert(Format.ZONE_CENTER - Format.FRAME > Format.NORTH / 2, "clear of the north diamond")
assert(W.LastCall(face.zone, "SetJustifyH")[1] == "LEFT", "and reads from the left")
assert(W.Near(face.zone:GetWidth(), 188 + 2 * Format.FRAME - 2 * Format.CAPTION_X, 1), "its width is the card's, so a long name truncates")
local cp1, crel1, crelp1, cx1, cy1 = face.coords:GetPoint(1)
assert(cp1 == "LEFT" and crel1 == face.card and crelp1 == "BOTTOMLEFT" and W.Near(cx1, Format.CAPTION_X, 1) and W.Near(cy1, -Format.ROW_CENTER, 1), "the coordinates sit under the card, at the left")
local kp1, krel1, krelp1, _, ky1 = face.clock:GetPoint(1)
assert(kp1 == "RIGHT" and krel1 == face.card and krelp1 == "BOTTOMRIGHT" and W.Near(ky1, -Format.ROW_CENTER, 1), "the clock sits under the card's right edge, on the coordinates' line")
assert(W.LastCall(face.clock, "SetJustifyH")[1] == "RIGHT", "reading from the right")
assert(face.zone:GetParent() == face.caption and face.caption:GetFrameLevel() > 100, "the caption lies over the map and the hybrid map")
local _, zoneSize = face.zone:GetFont()
local _, clockSize = face.clock:GetFont()
local _, coordsSize = face.coords:GetFont()
assert(W.Near(zoneSize, 12 * K.Theme.FontScale(), 1) and W.Near(clockSize, 12.5 * K.Theme.FontScale(), 1) and W.Near(coordsSize, 11.5 * K.Theme.FontScale(), 1), "the zone reads at 12, the clock at 12.5 and the coordinates at 11.5, snapped to the pixel grid: " .. tostring(zoneSize) .. ", " .. tostring(clockSize) .. ", " .. tostring(coordsSize))
assert(select(1, face.zone:GetFont()) == (K.Tokens.Font("caps")), "the zone reads in the caps role")
for _, text in ipairs({ face.zone, face.clock, face.coords }) do
	assert(select(3, text:GetFont()) == "OUTLINE", "the world layer: an outline")
	local shadow = W.LastCall(text, "SetShadowOffset")
	assert(shadow and shadow[1] > 0 and shadow[2] < 0, "and the kit's shadow under it")
end
assert(TextIs(face.zone, K.Tokens.Color("giltLit")), "the zone is lit gilt, as the mock-up draws it")
assert(select(1, face.clock:GetFont()) == (K.Tokens.Font("time")), "the clock reads in the time role")
assert(select(1, face.coords:GetFont()) == (K.Tokens.Font("number")), "the coordinates read in the number face")
assert(TextIs(face.coords, K.Tokens.Color("text")), "the coordinates are the light text colour")
assert(TextIs(face.clock, K.Tokens.Color("textEmphasis")), "the clock is white")
assert(face.compass == nil and face.compassPlate == nil, "the old compass fields stay gone: the plate is face.plate")

-- Hidden until hover: the zoom slider lives in a reveal group that shows while the pointer is over the element and
-- hides a short grace after it leaves. The tracking, calendar and drawer buttons join it with the Buttons only on
-- hover setting (on by default since the overhaul: the mock-up shows no buttons at rest). The mail and queue indicators, which carry
-- information, stay out of it.
local reveal = face.reveal
assert(reveal and not reveal:IsShown(), "the reveal group waits hidden")
assert(reveal:GetParent() == holder and LastArg(reveal, "SetAllPoints") == face.mapArea, "it covers the map square")
assert(reveal:GetFrameLevel() > face.overlay:GetFrameLevel(), "above the caption")
assert(face.zoom:GetParent() == reveal, "the zoom slider is in the group")
local column = ns.Map.column
assert(column.buttons.tracking:GetParent() == reveal and column.buttons.calendar:GetParent() == reveal and column.buttons.drawer:GetParent() == reveal, "by default the tracking, calendar and drawer buttons wait in the hover group: the mock-up shows none at rest")
K.Options.Write("Minimap", "column.hover", false)
assert(column.buttons.tracking:GetParent() == column.host and column.buttons.calendar:GetParent() == column.host and column.buttons.drawer:GetParent() == column.host, "with Buttons only on hover off, the three buttons are on the always-shown host")
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
assert(W.Near(face.zone:GetWidth(), 200 + 2 * Format.FRAME - 2 * Format.CAPTION_X, 1), "and the zone name's room grows with the card")
assert(W.Near(face.plate:GetWidth(), Format.NORTH, 1) and select(3, face.plate:GetPoint(1)) == "TOP", "while the north plate keeps its size on the top edge")
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
assert(TextIs(face.zone, K.Tokens.Color("giltLit")), "plain zone text is lit gilt")
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
assert(face.clock:GetText() == "9:05" and face.meridiem:GetText() == "AM", "the game's clock settings pick realm time in 12 hours, the AM smaller beside it")
local _, meridiemSize = face.meridiem:GetFont()
assert(W.Near(meridiemSize, math.max(12.5 * ns.Format.MERIDIEM * K.Theme.FontScale(), K.Scale.TextFloor() * K.Scale.Pixel(1)), 1), "at 0.8 of the clock's size, never under the 11 px text floor: " .. tostring(meridiemSize))
local mp, mrel, mrelp = face.meridiem:GetPoint(1)
assert(mp == "BOTTOMLEFT" and mrel == face.clock and mrelp == "BOTTOMRIGHT", "on the clock's line, after it")
env._cvars.timeMgrUseLocalTime, env._cvars.timeMgrUseMilitaryTime = true, true
K.Options.Write("Minimap", "clock.mode", "realm24")
assert(face.clock:GetText() == "09:05" and face.meridiem:GetText() == "", "realm time in 24 hours: " .. tostring(face.clock:GetText()))
K.Options.Write("Minimap", "clock.mode", "realm12")
assert(face.clock:GetText() == "9:05" and face.meridiem:GetText() == "AM", "realm time in 12 hours")
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
assert(xp == "LEFT" and xrel == face.card and xrelp == "BOTTOMLEFT", "the coordinates sit under the card, at the left")
local cpoint, crel, crelp = face.clock:GetPoint(1)
assert(cpoint == "RIGHT" and crel == face.card and crelp == "BOTTOMRIGHT", "and the clock at the right")
assert(K.Store.Defaults("Minimap").coords.position == nil, "the coordinate position setting is gone: the caption is the one place")
K.Options.Write("Minimap", "coords.precision", 0)
assert(face.coords:GetText() == "45, 62", "the coordinate format follows the setting")
local function CoordsTickers()
	local live = 0
	for _, ticker in ipairs(env._tickers) do
		if ticker.interval == 0.2 and not ticker.cancelled then
			live = live + 1
		end
	end
	return live
end
local mover = face.coordsFrame
assert(CoordsTickers() == 0, "standing still, nothing updates the coordinates")
env.FireEvent("PLAYER_STARTED_MOVING")
assert(CoordsTickers() == 1 and not mover:GetScript("OnUpdate"), "moving starts one 0.2 s ticker, never a per-frame OnUpdate")
env._position = { 0.5, 0.25 }
M.RunTickers(env)
assert(face.coords:GetText() == "50, 25", "each tick updates the coordinates")
env._combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
assert(CoordsTickers() == 0, "combat pauses the ticker")
env._position = { 0.6, 0.3 }
M.RunTickers(env)
assert(face.coords:GetText() == "50, 25", "and the coordinates keep their last value in combat")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(CoordsTickers() == 1 and face.coords:GetText() == "60, 30", "leaving combat while moving reads them at once and starts the ticker again")
K.Options.Write("Minimap", "coords.shown", false)
assert(CoordsTickers() == 0, "hidden coordinates stop updating")
K.Options.Write("Minimap", "coords.shown", true)
assert(CoordsTickers() == 1, "showing them again while moving resumes the updates")
env.FireEvent("PLAYER_STOPPED_MOVING")
assert(CoordsTickers() == 0, "stopping ends the updates")
env._combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
env.FireEvent("PLAYER_STARTED_MOVING")
assert(CoordsTickers() == 0, "starting to move in combat starts nothing")
env.FireEvent("PLAYER_STOPPED_MOVING")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(CoordsTickers() == 0, "and leaving combat standing still starts nothing")
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
assert(face.brackets[1].across:IsShown() and face.shade.top:IsShown(), "a restyle keeps the brackets and the map's edge")
assert(holder:GetFrameStrata() == "BACKGROUND", "the element sits on the BACKGROUND strata, where the hybrid map is fixed")
assert(face.card:GetFrameLevel() < 100 and minimap:GetFrameLevel() < 100, "the card and the map sit under the hybrid map's fixed level 100")
assert(face.overlay:GetFrameLevel() > 100 and face.wheel:GetFrameLevel() > face.reveal:GetFrameLevel(), "the overlay and the wheel catcher sit above it")

-- The accent: the card and the diamond keep the kit's gilt; the accent colours the zoom fill -----------

assert(W.SameRGB(zoom.fill, K.Theme.Accent()), "the zoom fill follows the class colour")
K.Options.Write("Minimap", "accent.source", "custom")
K.Options.Write("Minimap", "accent.color", { r = 1, g = 0, b = 0 })
assert(W.SameRGB(zoom.fill, 1, 0, 0), "a custom accent colours the zoom fill")
assert(W.SameRGB(plate.diamond.gilt, K.Tokens.Color("gilt")), "and leaves the north diamond alone")
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
	assert(W.Near(select(5, frame:GetPoint(1)), (14 - 22) / 2, 1), "the preview stands the map 4 units below the centre, so the zone above it, the map and the row under it sit centred together")
	assert(pface.zoom:IsShown() and W.Near(pface.zoom.fill:GetHeight(), 52, 0.5), "the preview shows the zoom slider full, as the mockup draws it")
	assert(frame.terrain and frame.terrain:GetMaskTexture(1) == pface.mask, "the preview's drawn terrain clips to the same chamfered mask as the live map")
	PK.Options.Write("Minimap", "clock.shown", false)
	frame:Refresh()
	assert(not pface.clock:IsShown(), "the preview follows the settings")
	NoErrors(penv, "preview")
end

print("minimap ok")
