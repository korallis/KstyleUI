-- test-minimap-drawer.lua: the addon-button drawer: LibDBIcon buttons collected into a flyout, its behaviours and grid, the addon compartment list, and handing the buttons back.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function NoErrors(env, what)
	assert(#env._errors == 0, (what or "") .. ": " .. tostring(env._errors[1]))
end

local function X(frame)
	return (select(4, frame:GetPoint(1)))
end

local function Y(frame)
	return (select(5, frame:GetPoint(1)))
end

local lib
local env, K, ns = M.New({
	enabled = true,
	setup = function(e)
		lib = M.FakeLibDBIcon(e)
		lib:Add("Bravo")
		lib:Add("Alpha")
		lib:Add("Hidden", true)
	end,
})
M.Settle(env)
NoErrors(env, "login")

local drawer = ns.Map.drawer
assert(drawer and drawer.panel, "ns.Map.drawer holds the drawer")
local toggle = ns.Map.column.buttons.drawer
assert(toggle and toggle:IsShown(), "the column ends with the drawer button while the drawer has buttons")
local alpha, bravo, hidden = lib.objects.Alpha, lib.objects.Bravo, lib.objects.Hidden

-- Collecting -------------------------------------------------------------------------------------------

for _, button in ipairs({ alpha, bravo, hidden }) do
	assert(button:GetParent() == drawer.panel, "LibDBIcon buttons move into the drawer")
end
local drag = W.LastCall(alpha, "RegisterForDrag")
assert(drag and drag.n == 0, "dragging a collected button round the map is turned off")
assert(W.LastCall(alpha, "SetFixedFrameStrata")[1] == false, "the library's fixed strata is released")
assert(alpha:GetFrameStrata() == drawer.panel:GetFrameStrata(), "buttons take the drawer's strata, so the drawer never covers them")
assert(alpha.icon:GetAlpha() ~= 0 and alpha.border:GetAlpha() == 0, "the library's ring and background are stripped, the icon stays")
assert(not drawer.panel:IsShown(), "the drawer starts closed")

-- Opening and the grid ---------------------------------------------------------------------------------

-- The rim buttons sit on the lens's right by default, where the card meets the screen's edge, so "auto" opens the
-- drawer inward, to the left of its button.
W.Click(toggle)
M.Settle(env)
assert(drawer.panel:IsShown(), "a click opens the drawer")
local point, relativeTo, relativePoint = drawer.panel:GetPoint(1)
assert(point == "TOPRIGHT" and relativeTo == toggle and relativePoint == "TOPLEFT", "with the rim buttons on the right, the drawer opens inward, to the left of its button")
assert(alpha:GetPoint(1) == "TOPRIGHT" and W.Near(X(alpha), -4) and W.Near(Y(alpha), -4), "buttons sort by name: Alpha first")
assert(W.Near(X(bravo), -(4 + 24 + 4)), "Bravo next to it")
assert(W.Near(alpha:GetWidth(), 24), "buttons take the drawer's icon size")
assert(not hidden:GetPoint(1) or select(2, hidden:GetPoint(1)) ~= drawer.panel, "a button its addon hid takes no place")
assert(W.Near(drawer.panel:GetWidth(), 4 + 24 + 4 + 24 + 4), "the drawer fits its shown buttons")

lib:Move("Alpha")
assert(select(2, alpha:GetPoint(1)) == drawer.panel and W.Near(X(alpha), -4), "the library moving a button puts it straight back in its place")

hidden:Show()
assert(W.Near(X(hidden), -(4 + 2 * 28)), "a button its addon shows again joins the grid")
hidden:Hide()

lib:Add("Charlie")
assert(lib.objects.Charlie:GetParent() == drawer.panel, "a button made later is collected at once")
assert(W.Near(X(lib.objects.Charlie), -(4 + 2 * 28)), "and sorted into place")

K.Options.Write("Minimap", "drawer.columns", 1)
assert(W.Near(X(bravo), -4) and W.Near(Y(bravo), -(4 + 28)), "one column stacks the buttons")
K.Options.Write("Minimap", "drawer.columns", 6)
K.Options.Write("Minimap", "drawer.direction", "down")
point, relativeTo, relativePoint = drawer.panel:GetPoint(1)
assert(point == "TOPLEFT" and relativeTo == toggle and relativePoint == "BOTTOMLEFT", "the drawer can open downward")
assert(alpha:GetPoint(1) == "TOPLEFT" and W.Near(X(alpha), 4), "and fills from its top left")
K.Options.Write("Minimap", "drawer.direction", "auto")
K.Options.Write("Minimap", "drawer.size", 30)
assert(W.Near(alpha:GetWidth(), 30), "the icon size follows the setting")
K.Options.Write("Minimap", "drawer.size", 24)

-- Clicking an addon button closes the drawer ----------------------------------------------------------

W.Click(alpha)
M.Settle(env)
assert(alpha.clicked == 1, "the addon's own click still runs")
assert(not drawer.panel:IsShown(), "clicking an addon button closes the drawer")
K.Options.Write("Minimap", "drawer.autoClose", false)
W.Click(toggle)
W.Click(alpha)
M.Settle(env)
assert(drawer.panel:IsShown(), "with auto-close off the drawer stays open")
W.Click(toggle)
M.Settle(env)
assert(not drawer.panel:IsShown(), "a second click on its button closes it")
K.Options.Write("Minimap", "drawer.autoClose", true)

-- Hover and always-open behaviours ------------------------------------------------------------------------

K.Options.Write("Minimap", "drawer.behaviour", "hover")
toggle._mouseOver = true
W.Enter(toggle)
assert(drawer.panel:IsShown(), "hovering the button opens a hover drawer")
local watch = drawer.panel:GetScript("OnUpdate")
assert(watch, "a hover drawer watches the pointer while open")
drawer.panel._mouseOver = true
toggle._mouseOver = false
watch(drawer.panel, 1)
assert(drawer.open, "the pointer on the drawer keeps it open")
drawer.panel._mouseOver = false
watch(drawer.panel, 1)
M.Settle(env)
assert(not drawer.panel:IsShown() and not drawer.panel:GetScript("OnUpdate"), "leaving both closes it and stops watching")
K.Options.Write("Minimap", "drawer.behaviour", "hover")
W.Enter(toggle)
assert(drawer.panel:GetScript("OnUpdate"), "watching again")
K.Options.Write("Minimap", "drawer.behaviour", "click")
assert(not drawer.panel:GetScript("OnUpdate") and drawer.open, "switching away from mouseover stops the watch and leaves the drawer open")
W.Click(toggle)
M.Settle(env)
K.Options.Write("Minimap", "drawer.behaviour", "open")
M.Settle(env)
assert(drawer.panel:IsShown(), "an always-open drawer opens as soon as it is chosen")
K.Options.Write("Minimap", "drawer.behaviour", "click")
W.Click(toggle)
M.Settle(env)

-- Turning the drawer button off hands the buttons back ----------------------------------------------------

K.Options.Write("Minimap", "column.drawer", false)
assert(alpha:GetParent() == env.Minimap and lib.refreshed.Alpha, "with the drawer button off, the library places its buttons on the map again")
lib.refreshed.Alpha = nil
K.Options.Write("Minimap", "column.drawer", true)
assert(alpha:GetParent() == drawer.panel, "turning it on collects them again")

-- The library's show-on-mouseover fading never hides a collected button ---------------------------------

alpha.fadeOut:Play()
assert(not alpha.fadeOut.playing and alpha:GetAlpha() == 1, "a fade the library starts is stopped while the button is in the drawer")
alpha:SetAlpha(0)
assert(alpha:GetAlpha() == 1, "and the library cannot set it transparent")

-- The addon compartment ----------------------------------------------------------------------------------

local ran = {}
env.AddonCompartmentFrame.registeredAddons = {
	{ text = "Zeta", func = function() ran.Zeta = true end },
	{ text = "echo", func = function() ran.echo = true end },
	{ text = "Broken" },
}
W.Click(toggle, "RightButton")
local entries, owner = M.Menu(env)
assert(owner == toggle, "a right click lists the addon compartment on the drawer button")
local buttons = {}
for _, entry in ipairs(entries) do
	if entry.kind == "button" then
		buttons[#buttons + 1] = entry
	end
end
assert(#buttons == 2 and buttons[1].text == "echo" and buttons[2].text == "Zeta", "entries sort by name, ignoring case, and skip broken ones")
buttons[2].callback()
assert(ran.Zeta, "choosing an entry runs the addon's own function")
local registered
for _, init in ipairs(buttons[2].initializers) do
	init({ RegisterForClicks = function(_, which) registered = which end })
end
assert(registered == "AnyUp", "entries take right clicks too, as Blizzard's compartment does")
assert(#env.AddonCompartmentFrame.registeredAddons == 3 and env.AddonCompartmentFrame.registeredAddons[1].text == "Zeta", "Blizzard's list is read, never sorted or changed")

-- Turning it off -------------------------------------------------------------------------------------------

K.Modules.Disable("Minimap")
M.Settle(env)
for _, button in ipairs({ alpha, bravo, hidden, lib.objects.Charlie }) do
	assert(button:GetParent() == env.Minimap, "turning the module off hands the buttons back to the map")
end
assert(W.LastCall(alpha, "RegisterForDrag")[1] == "LeftButton", "and lets them drag again")
assert(lib.refreshed.Alpha and lib.refreshed.Charlie, "and asks the library to place them again")
assert(alpha:GetNumPoints() == 1 and select(2, alpha:GetPoint(1)) == env.Minimap, "with the drawer's anchor cleared first")
alpha:SetAlpha(0)
assert(alpha:GetAlpha() == 0, "the library's fading works again on the map")
alpha:SetAlpha(1)
assert(lib.callbacks.LibDBIcon_IconCreated == nil, "the drawer stops listening for new buttons")
lib:Move("Alpha")
assert(select(2, alpha:GetPoint(1)) == env.Minimap, "the library places its own buttons again")
NoErrors(env, "disabled")

K.Modules.Enable("Minimap")
M.Settle(env)
assert(alpha:GetParent() == drawer.panel, "turning it back on collects the buttons again")
NoErrors(env, "enabled again")

-- LibDBIcon loading after the minimap ------------------------------------------------------------------------

do
	local lenv, _, lns = M.New({ enabled = true })
	M.Settle(lenv)
	local late = M.FakeLibDBIcon(lenv)
	late:Add("Late")
	lenv.FireEvent("ADDON_LOADED", "SomeAddon")
	lenv.RunTimers()
	local ldrawer = lns.Map.drawer
	assert(late.objects.Late:GetParent() == ldrawer.panel, "a library that loads later is found on the next addon load")
	late:Add("Later")
	assert(late.objects.Later:GetParent() == ldrawer.panel, "and the drawer listens for its new buttons from then on")
	assert(lns.Map.column.buttons.drawer:IsShown(), "the drawer button appears")
	NoErrors(lenv, "late library")
end

-- Empty drawers ----------------------------------------------------------------------------------------------

do
	local eenv, EK, ens = M.New({ enabled = true })
	M.Settle(eenv)
	local etoggle = ens.Map.column.buttons.drawer
	assert(not etoggle:IsShown(), "with no addon buttons and no compartment entries, the drawer button hides")
	eenv.AddonCompartmentFrame.registeredAddons = { { text = "Solo", func = function() end } }
	EK.Options.Write("Minimap", "drawer.hideEmpty", true)
	assert(etoggle:IsShown(), "compartment entries alone show it")
	W.Click(etoggle)
	assert(#M.Menu(eenv) >= 2, "and a left click lists them, since the drawer itself is empty")
	eenv.AddonCompartmentFrame.registeredAddons = {}
	EK.Options.Write("Minimap", "drawer.hideEmpty", false)
	assert(etoggle:IsShown(), "the drawer button can stay when empty")
	EK.Options.Write("Minimap", "column.drawer", false)
	assert(not etoggle:IsShown(), "and can be turned off")
	NoErrors(eenv, "empty")
end

-- The preview -------------------------------------------------------------------------------------------------

do
	local penv, PK = M.New()
	local frame = PK.Options.Preview("Minimap")(penv.CreateFrame("Frame", nil, penv.UIParent))
	assert(frame.column.buttons.drawer:IsShown(), "the preview shows the drawer button")
	NoErrors(penv, "preview")
end

print("minimap drawer ok")
