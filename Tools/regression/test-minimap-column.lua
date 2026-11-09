-- test-minimap-column.lua: the minimap's rim buttons: tracking, mail, calendar and queue as crystal discs on the lens's edge, their layout and settings, and the secure overlay that clicks Blizzard's own buttons.
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

-- Layout: small round crystal buttons on the lens's edge, down the right side of the circle -----------

assert(buttons.tracking:GetParent():GetFrameLevel() > face.overlay:GetFrameLevel(), "the buttons sit above the map")
assert(column.strip == nil and column.plate == nil, "no strip and no plate: the buttons sit on the lens's rim")
local Format = ns.Format
local size, spacing = K.Options.Get and 22 or 22, 7
assert(W.Near(buttons.tracking:GetWidth(), size), "buttons are small crystal discs, 22 units by default: " .. tostring(buttons.tracking:GetWidth()))
local radius = face.mapArea:GetWidth() / 2
local function OnRim(button, slot, side, up)
	local point, rel, relPoint = Anchor(button)
	local x, y = Format.Arc(slot, size, spacing, radius, side, up)
	assert(point == "CENTER" and rel == face.mapArea and relPoint == "CENTER", button.minimapName .. " is centred on a point of the lens")
	assert(W.Near(X(button), x, 0.5) and W.Near(Y(button), y, 0.5), button.minimapName .. " sits on the rim at slot " .. slot .. ": " .. tostring(X(button)) .. ", " .. tostring(Y(button)) .. " for " .. tostring(x) .. ", " .. tostring(y))
	assert(W.Near(math.sqrt(X(button) ^ 2 + Y(button) ^ 2), radius, 0.5), button.minimapName .. "'s centre lies on the circle")
end
OnRim(buttons.tracking, 1, "right", false)
OnRim(buttons.calendar, 2, "right", false)
assert(X(buttons.tracking) > 0 and Y(buttons.tracking) > 0, "the first button sits on the upper right of the rim, as the mockup's discs do")
assert(Y(buttons.calendar) < Y(buttons.tracking), "the next one is further round, lower")
local step = Format.ArcStep(size, spacing, radius)
assert(W.Near(step * radius, size + spacing, 0.01), "the pitch along the arc is one button and one gap")
assert(buttons.tracking.disc:IsShown() and buttons.tracking.ring:IsShown(), "each button is a dark disc with a light ring")
assert(W.SameRGB(buttons.tracking.disc, K.Tokens.Color("buttonFill")), "the disc is the button body")
assert(select(4, buttons.tracking.ring:GetVertexColor()) > select(4, K.Tokens.Color("edgeInner")), "the ring is brighter than a panel's edge line")
assert(W.LastCall(buttons.tracking.ring, "SetTexture")[1] == (K.Tokens.Texture("ringBevel")), "the ring is the kit's bevelled ring")
assert(select(2, buttons.tracking.ring:GetPoint(1)) == buttons.tracking, "the ring fills the button: it is the disc's edge")
assert(not buttons.tracking.chrome.fill[5]:IsShown(), "not a chamfered tile")
assert(select(4, buttons.tracking.icon:GetPoint(1)) >= 4, "the glyph sits inside the disc")

env._mail.new, env._mail.senders = true, { "Thrall", "Jaina" }
env.FireEvent("UPDATE_PENDING_MAIL")
assert(buttons.mail:IsShown(), "new mail shows the mail indicator")
OnRim(buttons.mail, 2, "right", false)
OnRim(buttons.calendar, 3, "right", false)
local tip = M.FakeTooltip()
Column.Tooltip("mail", tip, buttons.mail)
assert(tip:Has("Thrall") and tip:Has("Jaina"), "the mail tooltip lists the latest senders")

K.Options.Write("Minimap", "column.growth", "up")
OnRim(buttons.tracking, 1, "right", true)
assert(Y(buttons.tracking) < 0, "growing up starts at the lower right of the rim")
assert(Y(buttons.mail) > Y(buttons.tracking), "and climbs")
K.Options.Write("Minimap", "column.growth", "down")

K.Options.Write("Minimap", "column.side", "left")
OnRim(buttons.tracking, 1, "left", false)
assert(X(buttons.tracking) < 0, "the buttons can sit on the lens's left side")
K.Options.Write("Minimap", "column.side", "inside")
OnRim(buttons.tracking, 1, "right", false)
assert(X(buttons.tracking) > 0, "the old inside strip reads as the right side")
K.Options.Write("Minimap", "column.side", "right")

K.Options.Write("Minimap", "column.size", 28)
K.Options.Write("Minimap", "column.spacing", 2)
assert(W.Near(buttons.tracking:GetWidth(), 28), "the button size follows the setting")
size, spacing = 28, 2
OnRim(buttons.mail, 2, "right", false)
K.Options.Write("Minimap", "column.size", 22)
K.Options.Write("Minimap", "column.spacing", 7)
size, spacing = 22, 7
local zoom = face.zoom
local zp, zrel, zrelp, zx = zoom.track:GetPoint(1)
assert(zoom:IsShown() and zp == "LEFT" and zrel == face.mapArea and zrelp == "LEFT" and W.Near(zx, 11), "the slider stands inside the lens's left edge whatever the buttons do")
local holder = face.holder
M.Resize(holder, 140, 120)
assert(face.mapArea:GetWidth() <= 120 - Format.RIM - Format.FOOT + 0.5 and face.mapArea:GetWidth() > 0, "a small element shrinks the lens between the rim and the foot, got " .. tostring(face.mapArea:GetWidth()))
assert(not zoom:IsShown(), "when the lens is too small for the slider, the slider hides")
local footprint = K.Setup.Layouts.Element("minimap.main")
M.Resize(holder, footprint.width, footprint.height)
assert(zoom:IsShown(), "and comes back with the room at the footprint")

K.Options.Write("Minimap", "column.tracking", false)
assert(not buttons.tracking:IsShown(), "each button can be turned off")
OnRim(buttons.mail, 1, "right", false)
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
assert(W.SameRGB(buttons.tracking.chrome.rim[5], 0, 1, 0), "the column's hairlines follow the minimap's accent")
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
