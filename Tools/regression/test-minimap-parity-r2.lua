-- test-minimap-parity-r2.lua: the second EllesmereUI parity round for the minimap: each new option keeps today's default, applies switched on, refreshes on its events and restores when switched off.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, (what or "") .. ": " .. tostring(env._errors[1]))
end

local function point(frame)
	return frame:GetPoint(1)
end

local function apart(a, b, what)
	local al, ar, ab, at = a:GetLeft(), a:GetRight(), a:GetBottom(), a:GetTop()
	local bl, br, bb, bt = b:GetLeft(), b:GetRight(), b:GetBottom(), b:GetTop()
	assert(al and bl, what .. ": both frames have a rect")
	assert(ar <= bl + 0.01 or br <= al + 0.01 or at <= bb + 0.01 or bt <= ab + 0.01,
		what .. string.format(": [%.1f %.1f %.1f %.1f] overlaps [%.1f %.1f %.1f %.1f]", al, ar, ab, at, bl, br, bb, bt))
end

local function setup(env)
	env._lib = M.FakeLibDBIcon(env)
	env._lib:Add("BugSack")
	env._lib:Add("Details")
	for _, name in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "StoreMicroButton" }) do
		env.CreateFrame("Button", name, env.UIParent)
	end
	env.StoreMicroButton:Hide()
end

-- A v0.2.8-shaped profile loads with every new option at today's default and nothing new on the map.
local saved = { version = 42, profiles = { Default = { Minimap = { enabled = true, column = { size = 19.5 }, drawer = { size = 24 } } } },
	characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
local env, K, ns = M.New({ saved = saved, setup = setup })
M.Settle(env)
local S, face, column, drawer = ns.Settings, ns.Map.face, ns.Map.column, ns.Map.drawer
local buttons, area = column.buttons, face.mapArea
for key, want in pairs({ microMenu = false, tooltipScale = 1, ["compartment.shown"] = false, ["compartment.position"] = "TOPRIGHT",
	["compartment.scale"] = 1, ["drawer.button"] = "", ["drawer.place"] = "drawer" }) do
	assert(S.Get(key) == want, key .. " keeps today's default")
end
assert(next(S.Get("drawer.places")) == nil, "no addon button has a place of its own")
assert(buttons.compartment == nil, "the compartment button is not even built by default")
assert(drawer:Count() == 2, "both addon buttons sit in the drawer")
local bugsack, details = env._lib.objects.BugSack, env._lib.objects.Details
assert(bugsack:GetParent() == drawer.panel and details:GetParent() == drawer.panel, "and are parented to it")
local trackingPoint = { point(buttons.tracking) }
clean(env, K, "defaults")

-- The compartment button: off until asked; on, it shows in its corner with the addon count, and the column steps past it.
env.AddonCompartmentFrame.registeredAddons = { { text = "Zeta", func = function() end }, { text = "Alpha", func = function() end } }
K.Options.Write("Minimap", "column.hover", false)
K.Options.Write("Minimap", "compartment.shown", true)
local cb = buttons.compartment
assert(cb:IsShown() and cb:GetParent() == column.host, "on, the compartment button shows at rest when the buttons do")
local cp, crel, _, cx, cy = point(cb)
assert(cp == "TOPRIGHT" and crel == area and cx < 0 and cy < 0, "it sits in the top right corner")
assert(tostring(cb.tally:GetText()) == "2", "its face counts the compartment's addons: " .. tostring(cb.tally:GetText()))
assert(cb.tally:GetLeft() == cb:GetLeft() and cb.tally:GetRight() == cb:GetRight() and cb.tally:GetJustifyH() == "CENTER", "centred on the button")
for _, name in ipairs({ "tracking", "calendar", "drawer" }) do
	apart(cb, buttons[name], "the compartment and the " .. name .. " button")
end
cb.onClick(cb, "LeftButton")
local entries = M.Menu(env)
assert(entries[2] and entries[2].text == "Alpha" and entries[3].text == "Zeta", "a click lists the compartment, sorted")
env._menus[#env._menus].menu.open = false
local tip = M.FakeTooltip()
ns.Column.Tooltip("compartment", tip, cb)
assert(tip:Has("Addon compartment") and tip.factor == 1, "its tooltip names it at the usual size")
K.Options.Write("Minimap", "compartment.position", "BOTTOMLEFT")
K.Options.Write("Minimap", "compartment.x", 6)
K.Options.Write("Minimap", "compartment.y", 4)
cp, _, _, cx, cy = point(cb)
assert(cp == "BOTTOMLEFT" and cx > 6 and cy > 4, "the corner and offsets move it: " .. tostring(cp) .. " " .. tostring(cx))
local small = cb:GetWidth()
K.Options.Write("Minimap", "compartment.scale", 1.5)
assert(cb:GetWidth() > small * 1.4, "its size grows with the size slider")
assert(cb.tallyFont and cb.tallyFont:find("%d+$") and tonumber(cb.tallyFont:match("(%d+)$")) > 10, "and its count grows with it")
env._mail.new = true
env.FireEvent("UPDATE_PENDING_MAIL")
K.Options.Write("Minimap", "mail.position", "BOTTOMLEFT")
apart(cb, buttons.mail, "the mail and the compartment in one corner stack")
K.Options.Write("Minimap", "compartment.position", "TOPRIGHT")
K.Options.Write("Minimap", "mail.position", "TOPRIGHT")
apart(cb, buttons.mail, "the stack at the column's starting corner")
for _, name in ipairs({ "tracking", "calendar", "drawer" }) do
	apart(cb, buttons[name], "the column steps past the stacked compartment: " .. name)
end
K.Options.Write("Minimap", "difficulty.shown", true)
K.Options.Write("Minimap", "difficulty.position", "TOPRIGHT")
face:SetDifficulty("25H")
local dp, _, _, dx = point(face.difficulty)
assert(dp == "TOPRIGHT" and dx < select(4, point(cb)) - cb:GetWidth(), "a text in that corner stands clear of the larger compartment")
K.Options.Write("Minimap", "difficulty.shown", false)
K.Options.Write("Minimap", "difficulty.position", "TOPLEFT")
K.Options.Write("Minimap", "mail.position", "column")
env.AddonCompartmentFrame.registeredAddons = {}
column:Refresh()
assert(not cb:IsShown(), "with nothing in the compartment the button hides")
env.AddonCompartmentFrame.registeredAddons = { { text = "Solo", func = function() end } }
env.FireEvent("ADDON_LOADED", "Solo")
env.RunTimers()
assert(cb:IsShown() and tostring(cb.tally:GetText()) == "1", "an addon that registers later brings it back with its count")
K.Options.Write("Minimap", "column.hover", true)
assert(cb:GetParent() == face.reveal, "with buttons only on hover it waits in the hover group")
K.Options.Write("Minimap", "compartment.shown", false)
K.Options.Write("Minimap", "compartment.scale", 1)
assert(not cb:IsShown(), "off hides it")
local now = { point(buttons.tracking) }
for i = 1, 5 do
	assert(now[i] == trackingPoint[i], "and the column is exactly as before")
end
env._mail.new = false
env.FireEvent("UPDATE_PENDING_MAIL")
clean(env, K, "compartment")

-- Each addon button's place: the row lists the collected buttons, picking one reads its place back, and the place applies.
local options = S.AddonButtons()
assert(#options == 3 and options[1].value == "" and options[2].label == "BugSack" and options[3].value == "Details", "the row lists each collected addon button")
assert(S.Get("drawer.button") == "" and K.Options.Row("Minimap", "drawer.place"), "the place row exists")
K.Options.Write("Minimap", "column.hover", false)
K.Options.Write("Minimap", "drawer.button", "Details")
assert(S.Get("drawer.place") == "drawer", "a button with no place of its own reads In the drawer")
K.Options.Write("Minimap", "drawer.place", "column")
assert(S.Get("drawer.places").Details == "column", "the place is saved for that button")
assert(details:GetParent() == column.host and details:IsVisible(), "the button moves to the column")
local dp2, drel = point(details)
assert(drel == area and dp2 == "TOPRIGHT", "into a column slot inside the map")
for _, name in ipairs({ "tracking", "calendar", "drawer" }) do
	apart(details, buttons[name], "the addon button and the " .. name .. " button")
end
assert(drawer:Count() == 1, "the drawer counts only what it holds")
env._lib:Move("Details")
assert(point(details) == "TOPRIGHT" and select(2, point(details)) == area, "the library's re-anchor puts it back in its column slot")
K.Options.Write("Minimap", "drawer.button", "BugSack")
assert(S.Get("drawer.place") == "drawer", "picking another button reads its own place")
K.Options.Write("Minimap", "drawer.place", "hidden")
assert(bugsack:GetParent() == drawer.attic and not bugsack:IsVisible(), "hidden takes it off the map and out of the drawer")
assert(drawer:Count() == 0 and not drawer:Open(), "an empty drawer does not open")
K.Options.Write("Minimap", "drawer.button", "Details")
assert(S.Get("drawer.place") == "column", "picking the first button again reads its place back")
local slotY = select(5, point(details))
K.Options.Write("Minimap", "drawer.button", "BugSack")
K.Options.Write("Minimap", "drawer.place", "column")
assert(select(5, point(bugsack)) == slotY and select(5, point(details)) < slotY, "a second column button takes the first slot by name and Details the next")
bugsack:Hide()
assert(select(5, point(details)) == slotY, "an addon that hides its button frees the slot")
bugsack:Show()
assert(select(5, point(bugsack)) == slotY and bugsack:GetParent() == column.host, "and showing it puts it back")
K.Options.Write("Minimap", "drawer.place", "hidden")
K.Options.Write("Minimap", "drawer.button", "Details")
K.Options.Write("Minimap", "column.hover", true)
assert(details:GetParent() == face.reveal, "with buttons only on hover it waits in the hover group too")
details.IsProtected = function() return true end
env.SetCombat(true)
K.Options.Write("Minimap", "drawer.place", "drawer")
assert(details:GetParent() == face.reveal and #env._errors == 0, "a protected button waits for combat to end")
env.SetCombat(false)
assert(details:GetParent() == drawer.panel, "and moves into the drawer after combat")
details.IsProtected = nil
K.Options.Write("Minimap", "drawer.places", { Details = "column", BugSack = "hidden" })
K.Options.Write("Minimap", "column.drawer", false)
assert(details:GetParent() == env.Minimap and bugsack:GetParent() == env.Minimap, "the drawer off hands every button back to its addon")
K.Options.Write("Minimap", "column.drawer", true)
assert(details:GetParent() == face.reveal and bugsack:GetParent() == drawer.attic, "and on again keeps each place")
K.Options.Write("Minimap", "drawer.places", {})
K.Options.Write("Minimap", "drawer.button", "Gone")
assert(S.Get("drawer.button") == "Gone" and S.Get("drawer.place") == "drawer", "a saved button whose addon is gone is kept")
K.Options.Write("Minimap", "drawer.button", "")
assert(details:GetParent() == drawer.panel and bugsack:GetParent() == drawer.panel, "with no places every button is back in the drawer")
clean(env, K, "places")

-- Tooltip size scales the map's own tooltips, and the next owner gets the shared size back.
local real = K.Widgets.Tooltip()
local base = real:GetScale()
K.Options.Write("Minimap", "tooltipScale", 1.5)
ns.Column.Tooltip("tracking", real, buttons.tracking)
real:Show()
assert(W.Near(real:GetScale(), base * 1.5, 0.001), "a button tooltip is scaled: " .. tostring(real:GetScale()))
real:SetOwner(env.UIParent, "ANCHOR_RIGHT")
real:Show()
assert(W.Near(real:GetScale(), base, 0.001), "another owner's tooltip is the usual size")
face.zoneHit:GetScript("OnEnter")(face.zoneHit)
assert(real:IsOwned(face.zoneHit) and W.Near(real:GetScale(), base * 1.5, 0.001), "the zone tooltip is scaled")
face.zoneHit:GetScript("OnLeave")(face.zoneHit)
K.Options.Write("Minimap", "tooltipScale", 1)
ns.Column.Tooltip("tracking", real, buttons.tracking)
real:Show()
assert(W.Near(real:GetScale(), base, 0.001), "at 1 the map's tooltips are the usual size")
clean(env, K, "tooltips")

-- The micro menu: middle-click opens it only when asked and out of combat; each entry clicks Blizzard's button securely.
local click = env.Minimap:GetScript("OnMouseUp")
click(env.Minimap, "MiddleButton")
assert(not ns.Micro.panel, "off, a middle-click does nothing new")
K.Options.Write("Minimap", "microMenu", true)
click(env.Minimap, "LeftButton")
assert(not ns.Micro.panel, "a left click still only pings")
click(env.Minimap, "MiddleButton")
local panel = ns.Micro.panel
assert(panel and panel:IsShown(), "a middle-click opens the micro menu")
panel._mouseOver = true
for _ = 1, 60 do W.Tick(env, 0.016) end
assert(panel:IsShown(), "it stays open while the pointer is over it")
local shown = {}
for _, row in ipairs(panel.rows) do
	if row:IsShown() then shown[#shown + 1] = row end
end
assert(#shown == 2 and shown[1]:GetText() == "Character" and shown[2]:GetText() == "Spellbook", "it lists the game's shown micro buttons only")
apart(shown[1], shown[2], "the menu's rows")
shown[1]:GetScript("OnEnter")(shown[1])
local overlay = ns.SecureClick.overlay
assert(overlay:IsShown() and overlay:GetAttribute("clickbutton1") == env.CharacterMicroButton, "an entry clicks Blizzard's own button through the secure overlay")
overlay:GetScript("PostClick")(overlay, "LeftButton")
M.Settle(env)
assert(not panel:IsShown(), "and the menu closes after the click")
click(env.Minimap, "MiddleButton")
panel._mouseOver = false
M.Settle(env)
assert(not panel:IsShown(), "the pointer leaving the menu and the map closes it")
click(env.Minimap, "MiddleButton")
panel._mouseOver = true
for _ = 1, 60 do W.Tick(env, 0.016) end
assert(panel:IsShown(), "it opens again")
env.SetCombat(true)
M.Settle(env)
assert(not panel:IsShown(), "combat closes it")
click(env.Minimap, "MiddleButton")
M.Settle(env)
assert(not panel:IsShown() and M.CoreEnv.Printed(env, "opens after combat"), "and a middle-click in combat says it opens after combat")
env.SetCombat(false)
K.Options.Write("Minimap", "microMenu", false)
click(env.Minimap, "MiddleButton")
M.Settle(env)
assert(not panel:IsShown(), "off again, a middle-click does nothing new")
clean(env, K, "micro menu")

-- The settings preview shows the compartment, the samples' places and the micro menu.
K.Options.Write("Minimap", "compartment.shown", true)
K.Options.Write("Minimap", "drawer.places", { Details = "column" })
K.Options.Write("Minimap", "microMenu", true)
local preview = ns.Preview.Build(env.UIParent)
M.Settle(env)
local pc = preview.column
assert(pc.buttons.compartment:IsShown() and tostring(pc.buttons.compartment.tally:GetText()) == "3", "the preview shows the compartment button")
local sample
for button, state in pairs(pc.drawer.adopted) do
	if state.name == "Details" then sample = button end
end
assert(sample:GetParent() == preview.face.reveal and point(sample) == "TOPRIGHT", "the preview puts a sample in the column")
preview.face.mapArea:GetScript("OnMouseUp")(preview.face.mapArea, "MiddleButton")
assert(panel:IsShown() and panel.anchor == preview, "a middle-click on the preview opens the micro menu beside it")
ns.Micro.Close()
M.Settle(env)
K.Options.Write("Minimap", "drawer.places", {})
preview:Refresh()
assert(sample:GetParent() == pc.drawer.panel, "and the sample goes back to the drawer")
clean(env, K, "preview")

-- Turning the module off closes the menu and hands the buttons back.
K.Modules.Disable("Minimap")
M.Settle(env)
assert(details:GetParent() == env.Minimap and not panel:IsShown(), "off hands the buttons back and closes the menu")
clean(env, K, "disable")
print("ok: minimap parity round 2")
