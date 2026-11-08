-- test-minimap-column.lua: the minimap's button column: tracking, mail, calendar and queue buttons, their layout and settings, and the secure overlay that clicks Blizzard's own buttons.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function NoErrors(env, what)
	assert(#env._errors == 0, (what or "") .. ": " .. tostring(env._errors[1]))
end

local function Anchor(frame)
	local point, relativeTo, relativePoint = frame:GetPoint(1)
	return point, relativeTo, relativePoint
end

local function X(frame)
	return (select(4, frame:GetPoint(1)))
end

local function Y(frame)
	return (select(5, frame:GetPoint(1)))
end

local env, K, ns = M.New({ enabled = true })
M.Settle(env)
NoErrors(env, "login")

local Column = ns.Column
local column = ns.Map.column
assert(type(Column) == "table" and column and type(column.buttons) == "table", "ns.Map.column.buttons holds the column's buttons")
local buttons = column.buttons
local face = ns.Map.face
for _, name in ipairs({ "tracking", "mail", "calendar", "queue" }) do
	assert(buttons[name], "the column has a " .. name .. " button")
end

-- What shows ----------------------------------------------------------------------------------------

assert(buttons.tracking:IsShown(), "tracking shows")
assert(not buttons.mail:IsShown(), "the mail indicator hides with no new mail")
assert(buttons.calendar:IsShown(), "the calendar shows")
assert(not buttons.queue:IsShown(), "the queue button hides when you are not queued")
local function Faded(frame)
	local mouse = W.LastCall(frame, "EnableMouse")
	return frame:GetAlpha() == 0 and mouse ~= nil and mouse[1] == false
end
assert(Faded(env.QueueStatusButton), "Blizzard's queue eye is faded out and lets clicks through; the column shows the status")
assert(not K.Safe.IsHidden(env.QueueStatusButton), "the eye stays shown, because its own menu closes when its owner hides")

-- Layout: the mockup's column of round buttons on a dark plate, left of the frame ---------------------

assert(buttons.tracking:GetParent():GetFrameLevel() > face.overlay:GetFrameLevel(), "the buttons sit above the map")
local strip, plate = column.strip, column.plate
assert(not strip:IsShown(), "beside the map there is no inside strip")
assert(plate and plate:IsShown(), "a dark chamfered plate stands behind the column")
assert(W.Near(plate:GetWidth(), 34), "the plate is 34 wide: a 30 button and 2 each side, got " .. tostring(plate:GetWidth()))
local pp, prel, prelp, px, py = plate:GetPoint(1)
assert(pp == "TOPRIGHT" and prel == face.box and prelp == "TOPLEFT" and W.Near(px, -4) and W.Near(py, -4), "the plate hangs 4 left of the frame, 4 below its top")
assert(W.Near(plate:GetHeight(), 4 + 30 + 7 + 30 + 4), "the plate wraps the shown buttons with 4 above and below, got " .. tostring(plate:GetHeight()))
assert(plate.chrome and W.SameRGB(plate.chrome.inner[5], K.Tokens.Color("edgeInner")), "the plate is kit glass with the faint inner edge, not the accent")
local ip, irel, irelp = Anchor(buttons.tracking)
assert(ip == "TOP" and irel == plate and irelp == "TOP", "the buttons hang from the plate's top")
assert(W.Near(X(buttons.tracking), 0) and W.Near(Y(buttons.tracking), -4), "the first button sits 4 below the plate's top")
assert(W.Near(buttons.tracking:GetWidth(), 30), "buttons are the mockup's 30 units")
assert(W.Near(Y(buttons.calendar), -41), "the next shown button sits 37 lower: the mockup's pitch")
assert(buttons.tracking.disc:IsShown() and buttons.tracking.ring:IsShown(), "beside the map each button is a dark disc with a light ring")
assert(W.SameRGB(buttons.tracking.disc, K.Tokens.Color("buttonFill")), "the disc is the button body, the mockup's dark plate")
assert(select(4, buttons.tracking.ring:GetVertexColor()) > select(4, K.Tokens.Color("edgeInner")), "the ring is brighter than a panel's edge line, as the mockup's column rings read")
assert(W.LastCall(buttons.tracking.ring, "SetTexture")[1] == (K.Tokens.Texture("ringBevel")), "the ring is the kit's bevelled ring, the mockup's thin metal ring")
assert(select(2, buttons.tracking.ring:GetPoint(1)) == buttons.tracking, "the ring fills the button: it is the disc's edge")
assert(not buttons.tracking.chrome.fill[5]:IsShown(), "not a chamfered tile")
assert(W.Near(select(4, buttons.tracking.icon:GetPoint(1)), 7), "the glyph is 16 inside the 30 disc")

env._mail.new, env._mail.senders = true, { "Thrall", "Jaina" }
env.FireEvent("UPDATE_PENDING_MAIL")
assert(buttons.mail:IsShown(), "new mail shows the mail indicator")
assert(W.Near(Y(buttons.mail), -41), "mail takes the second place")
assert(W.Near(Y(buttons.calendar), -78), "the calendar moves down")
assert(W.Near(plate:GetHeight(), 4 + 3 * 30 + 2 * 7 + 4), "the plate grows with the column")
local tip = M.FakeTooltip()
Column.Tooltip("mail", tip, buttons.mail)
assert(tip:Has("Thrall") and tip:Has("Jaina"), "the mail tooltip lists the latest senders")

K.Options.Write("Minimap", "column.growth", "up")
pp, prel, prelp, px, py = plate:GetPoint(1)
assert(pp == "BOTTOMRIGHT" and prel == face.box and prelp == "BOTTOMLEFT" and W.Near(px, -4) and W.Near(py, 4), "growing up hangs the plate from the frame's bottom left")
ip, irel, irelp = Anchor(buttons.tracking)
assert(ip == "BOTTOM" and irel == plate and irelp == "BOTTOM" and W.Near(Y(buttons.tracking), 4), "the first button sits at the plate's bottom")
assert(W.Near(Y(buttons.mail), 41), "the next one sits above it")
K.Options.Write("Minimap", "column.growth", "down")

K.Options.Write("Minimap", "column.side", "right")
pp, prel, prelp, px = plate:GetPoint(1)
assert(pp == "TOPLEFT" and prel == face.box and prelp == "TOPRIGHT" and W.Near(px, 4), "the column can sit on the map's right")
K.Options.Write("Minimap", "column.side", "left")

K.Options.Write("Minimap", "column.size", 28)
K.Options.Write("Minimap", "column.spacing", 2)
assert(W.Near(buttons.tracking:GetWidth(), 28), "the button size follows the setting")
assert(W.Near(Y(buttons.mail), -34), "the spacing follows the setting")
K.Options.Write("Minimap", "column.size", 32)
K.Options.Write("Minimap", "column.spacing", 12)
local boxLeft = select(4, face.box:GetPoint(1))
assert(boxLeft >= 40 - 1e-6, "a wider column moves the map over, so the whole column stays inside the element: " .. tostring(boxLeft))
assert(W.Near(face.box:GetWidth(), 219), "and the map shrinks to fit")
K.Options.Write("Minimap", "column.size", 30)
K.Options.Write("Minimap", "column.spacing", 7)

-- Layout: the design's raised strip inside the frame's right edge, with bare glyph buttons down it ------

K.Options.Write("Minimap", "column.side", "inside")
K.Options.Write("Minimap", "column.size", 16)
K.Options.Write("Minimap", "column.spacing", 9)
assert(not plate:IsShown(), "inside the frame there is no plate")
assert(W.Near(face.box:GetWidth(), 221) and W.Near(select(4, face.box:GetPoint(1)), 38), "inside, the frame keeps the map's square at the element's right and leaves the column's room empty, got " .. tostring(face.box:GetWidth()))
local mapRight = select(4, face.mapArea:GetPoint(1)) + face.mapArea:GetWidth()
assert(face.box:GetWidth() - 4 - strip:GetWidth() < mapRight, "the strip lies over the map's right edge")
assert(strip and strip:IsShown(), "inside the frame, a raised strip stands behind the buttons")
assert(W.Near(strip:GetWidth(), 24), "the strip is 24 wide: a 16 button and one gap each side, got " .. tostring(strip:GetWidth()))
local sp, srel, srelp, sx, sy = strip:GetPoint(1)
assert(sp == "TOPRIGHT" and srel == face.box and srelp == "TOPRIGHT" and W.Near(sx, -4) and W.Near(sy, -4), "the strip hangs inside the frame's top right corner")
local bp, brel, brelp = strip:GetPoint(2)
assert(bp == "BOTTOMRIGHT" and brel == face.strip and brelp == "TOPRIGHT", "the strip stops on the footer")
local sa = select(4, strip.fill:GetVertexColor())
assert(W.SameRGB(strip.fill, K.Tokens.Color("surface")) and W.Near(sa, 0.8), "the strip is the footer's glass at the strip opacity")
ip, irel, irelp = Anchor(buttons.tracking)
assert(ip == "TOP" and irel == strip and irelp == "TOP", "the buttons hang from the strip's top")
assert(W.Near(X(buttons.tracking), 0) and W.Near(Y(buttons.tracking), -4), "the first button sits one gap below the strip's top")
assert(W.Near(buttons.tracking:GetWidth(), 16), "glyph buttons are 16 units")
assert(W.Near(Y(buttons.mail), -29), "the next shown button sits 25 lower: the design's pitch")
assert(not buttons.tracking.disc:IsShown() and not buttons.tracking.ring:IsShown() and not buttons.tracking.chrome.fill[5]:IsShown(), "on the strip a button is a bare glyph, not a disc or a tile")
assert(select(4, buttons.tracking.icon:GetPoint(1)) < 4, "the glyph fills its 16 button inside the kit's own inset")
local zoom = face.zoom
local zp, zrel, zrelp, zx, zy = zoom.track:GetPoint(1)
assert(zoom:IsShown() and zp == "BOTTOM" and zrel == face.mapArea and zrelp == "BOTTOMRIGHT" and W.Near(zx, -7) and W.Near(zy, 34), "inside the strip the slider keeps the strip's lower end while the buttons hang from the top")
K.Options.Write("Minimap", "column.growth", "up")
ip, irel, irelp = Anchor(buttons.tracking)
assert(ip == "BOTTOM" and irel == strip and irelp == "BOTTOM" and W.Near(Y(buttons.tracking), 4), "growing up starts at the strip's bottom, above the footer")
zp, zrel, zrelp, zx, zy = zoom.track:GetPoint(1)
assert(zoom:IsShown() and zp == "TOP" and zrel == face.mapArea and zrelp == "TOPRIGHT" and W.Near(zx, -7) and W.Near(zy, -8), "with the buttons growing up, the slider moves to the strip's top end")
K.Options.Write("Minimap", "column.size", 32)
K.Options.Write("Minimap", "column.spacing", 12)
local holder = face.holder
M.Resize(holder, 120 * 259 / 221, 120)
assert(W.Near(face.mapArea:GetWidth(), 112), "the smallest map is a 112 square")
assert(not zoom:IsShown(), "when the inside column leaves the slider no room, the slider hides rather than sit under the buttons")
M.Resize(holder, 259, 221)
assert(zoom:IsShown(), "and comes back with the room")
K.Options.Write("Minimap", "column.size", 16)
K.Options.Write("Minimap", "column.spacing", 9)
K.Options.Write("Minimap", "clock.shown", false)
K.Options.Write("Minimap", "zone.shown", false)
bp, brel, brelp = strip:GetPoint(2)
sy = select(5, strip:GetPoint(2))
assert(bp == "BOTTOMRIGHT" and brel == face.box and brelp == "BOTTOMRIGHT" and W.Near(sy, 4), "without a footer the strip runs to the frame's bottom")
K.Options.Write("Minimap", "clock.shown", true)
K.Options.Write("Minimap", "zone.shown", true)
K.Options.Write("Minimap", "column.growth", "down")
K.Options.Write("Minimap", "column.side", "left")
K.Options.Write("Minimap", "column.size", 30)
K.Options.Write("Minimap", "column.spacing", 7)

K.Options.Write("Minimap", "column.tracking", false)
assert(not buttons.tracking:IsShown(), "each button can be turned off")
assert(W.Near(Y(buttons.mail), -4), "the rest close up")
K.Options.Write("Minimap", "column.tracking", true)

env._rules[env.Enum.GameRule.IngameTrackingDisabled] = true
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
assert(not buttons.tracking:IsShown(), "a game rule that turns tracking off hides the button")
env._rules[env.Enum.GameRule.IngameTrackingDisabled] = nil
env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
assert(buttons.tracking:IsShown(), "and it comes back with the rule")

-- Tracking menu -------------------------------------------------------------------------------------

W.Click(buttons.tracking)
local entries, owner = M.Menu(env)
assert(owner == buttons.tracking, "the tracking menu opens on the button")
local boxes = {}
for _, entry in ipairs(entries) do
	if entry.kind == "checkbox" then
		boxes[entry.text] = entry
	end
end
assert(boxes.Repair and boxes["Find Herbs"], "optional filters and tracking spells are listed")
assert(not boxes["Quest Points"] and not boxes.Target, "always-on and conditional filters are not")
assert(boxes["Find Herbs"].isSelected(boxes["Find Herbs"].data) == true, "an active tracking type is checked")
boxes.Repair.setSelected(boxes.Repair.data)
assert(env._tracking[2].active == true, "checking a type turns its tracking on")
local clear
for _, entry in ipairs(entries) do
	if entry.kind == "button" then
		clear = entry
	end
end
assert(clear, "the menu can clear tracking")
clear.callback(clear.data)
assert(not env._tracking[2].active and not env._tracking[3].active, "clearing turns optional tracking off")
assert(env._tracking[1].active and env._tracking[4].active, "and keeps the always-on and conditional filters")

-- Calendar invites ------------------------------------------------------------------------------------

assert(not buttons.calendar.badge:IsShown(), "no badge without invites")
env._invites = 2
env.FireEvent("CALENDAR_UPDATE_PENDING_INVITES")
assert(buttons.calendar.badge:IsShown(), "pending invites show a badge")
tip = M.FakeTooltip()
Column.Tooltip("calendar", tip, buttons.calendar)
assert(tip:Has("2"), "the calendar tooltip counts the invites")
env._invites = 0
env.FireEvent("CALENDAR_UPDATE_PENDING_INVITES")
assert(not buttons.calendar.badge:IsShown(), "the badge clears")

-- Queue status ------------------------------------------------------------------------------------------

env.QueueStatusButton:Show()
env.EventRegistry:TriggerEvent("QueueStatusUpdate.QueuesUpdated")
assert(buttons.queue:IsShown(), "a queue shows the queue button")
env.QueueStatusButton:Hide()
env.EventRegistry:TriggerEvent("QueueStatusUpdate.QueuesUpdated")
assert(not buttons.queue:IsShown(), "leaving the queue hides it")
K.Options.Write("Minimap", "column.queue", false)
assert(env.QueueStatusButton:GetAlpha() == 1 and W.LastCall(env.QueueStatusButton, "EnableMouse")[1] == true, "turning the queue button off gives Blizzard's eye back")
K.Options.Write("Minimap", "column.queue", true)
assert(Faded(env.QueueStatusButton), "and turning it on fades the eye again")
env.QueueStatusButton:SetAlpha(1)
assert(env.QueueStatusButton:GetAlpha() == 0, "Blizzard code cannot bring the faded eye back")
env.QueueStatusButton:Show()
env.EventRegistry:TriggerEvent("QueueStatusUpdate.QueuesUpdated")

-- The secure overlay clicks Blizzard's own buttons -------------------------------------------------------

local SecureClick = ns.SecureClick
W.Enter(buttons.calendar)
local overlay = SecureClick.overlay
assert(overlay and overlay._template == "SecureActionButtonTemplate", "a secure action button carries the click")
assert(overlay:GetParent() == env.UIParent, "it sits on UIParent, so no KstyleUI frame becomes protected")
assert(overlay:IsShown(), "hovering a button puts the overlay over it")
assert(overlay:GetAttribute("type") == "click", "the overlay clicks another button")
assert(overlay:GetAttribute("clickbutton1") == env.GameTimeFrame, "a left click opens Blizzard's calendar")
assert(overlay:GetAttribute("clickbutton2") == env.TimeManagerClockButton, "a right click opens the clock options")
assert(W.Covers(env, overlay, buttons.calendar), "the overlay covers the hovered button, anchored only to UIParent")
W.Leave(overlay)
assert(not overlay:IsShown(), "leaving the overlay detaches it")

W.Enter(buttons.queue)
assert(overlay:GetAttribute("clickbutton1") == env.QueueStatusButton and overlay:GetAttribute("clickbutton2") == env.QueueStatusButton, "both clicks reach Blizzard's queue button")
W.Leave(overlay)
face.zoneHit._rect = { 100, 700, 80, 14 }
face.zoneHit:GetParent():SetScale(1.25)
W.Enter(face.zoneHit)
assert(overlay:GetAttribute("clickbutton1") == env.MinimapCluster.ZoneTextButton, "the zone name opens the world map")
assert(overlay:IsShown() and W.Covers(env, overlay, face.zoneHit), "the overlay covers the zone name at its scale, though the name's hit frame sits on a font string")
assert(#env._errors == 0, tostring(env._errors[1]))
W.Leave(overlay)
face.clockHit._rect = { 200, 700, 40, 14 }
W.Enter(face.clockHit)
assert(overlay:GetAttribute("clickbutton1") == env.TimeManagerClockButton and overlay:GetAttribute("clickbutton2") == env.GameTimeFrame, "the clock opens the clock options, or the calendar on a right click")

env.SetCombat(true)
assert(not overlay:IsShown(), "combat detaches the overlay before lockdown")
W.Enter(buttons.calendar)
assert(not overlay:IsShown(), "in combat the overlay never moves")
W.Click(buttons.calendar)
assert(M.CoreEnv.Printed(env, "after combat"), "a click in combat says it works after combat")
env.SetCombat(false)
NoErrors(env, "overlay")

-- The accent ------------------------------------------------------------------------------------------

K.Options.Write("Minimap", "accent.source", "custom")
K.Options.Write("Minimap", "accent.color", { r = 0, g = 1, b = 0 })
buttons.tracking:SetSelected(true)
assert(W.SameRGB(buttons.tracking.chrome.inner[5], 0, 1, 0), "the column's hairlines follow the minimap's accent")
buttons.tracking:SetSelected(false)
K.Options.Write("Minimap", "accent.source", "class")

-- Turning it off ----------------------------------------------------------------------------------------

K.Modules.Disable("Minimap")
M.Settle(env)
assert(env.QueueStatusButton:GetAlpha() == 1 and W.LastCall(env.QueueStatusButton, "EnableMouse")[1] == true, "turning the module off gives Blizzard's eye back")
env.EventRegistry:TriggerEvent("QueueStatusUpdate.QueuesUpdated")
assert(not overlay:IsShown(), "the overlay is detached")
NoErrors(env, "disabled")

-- The preview shows every button ------------------------------------------------------------------------

do
	local penv, PK = M.New()
	local parent = penv.CreateFrame("Frame", nil, penv.UIParent)
	local frame = PK.Options.Preview("Minimap")(parent)
	local preview = frame.column
	assert(preview and preview.buttons.tracking:IsShown() and preview.buttons.mail:IsShown(), "the preview shows the column's buttons")
	assert(preview.buttons.queue:IsShown(), "including the queue button")
	assert(PK.Layout.Element("minimap.main") == nil, "the preview registers nothing with Layout")
	NoErrors(penv, "preview")
end

print("minimap column ok")
