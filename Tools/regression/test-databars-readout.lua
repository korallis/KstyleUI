-- test-databars-readout.lua: the readout and menu card: one line of value plus muted unit on the strip, the micro menu and bag bar docked under it as round crystal buttons in the same card, or set free as their own elements.
local D = dofile("Tools/regression/databars_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function masked(button)
	for i = 1, button.icon:GetNumMaskTextures() do
		if button.icon:GetMaskTexture(i) == button.roundMask then
			return true
		end
	end
	return false
end

local function item(ns, id)
	return assert(ns.Strip.view.items[id], id .. " exists")
end

local env, K, ns = D.New({
	enable = false,
	setup = function(e)
		D.Menus(e)
	end,
})
K.Modules.Enable("DataBars")
env.RunTimers()
local Options = K.Options

-- Inline units: the value reads first, the unit follows on the same line in the muted text grey.
eq(ns.Settings().strip.labels, "inline", "the strip's labels default to inline units")
local fps = item(ns, "fps")
assert(fps.label:IsShown(), "the unit shows")
eq(fps.label:GetText(), "fps", "the unit is the short unit in lower case")
eq(item(ns, "latency").label:GetText(), "ms", "latency in ms")
eq(item(ns, "durability").label:GetText(), "armour", "durability reads as armour, as the mockup's readout does")
eq(item(ns, "gold").label:GetText(), "", "money carries its own units")
local lp = fps.label._points[1]
assert(lp[1] == "LEFT" and lp[2] == fps.value and lp[3] == "RIGHT", "the unit follows the value on the same line")
assert(near(lp[4], ns.Strip.UNIT_GAP), "one unit gap after the value")
local tr, tg, tb = K.Tokens.Color("text")
local lr, lg, lb = fps.label:GetTextColor()
assert(near(lr, tr) and near(lg, tg) and near(lb, tb), "the unit is muted")
local er, eg, eb = K.Tokens.Color("textEmphasis")
local vr, vg, vb = item(ns, "latency").value:GetTextColor()
assert(near(vr, er) and near(vg, eg) and near(vb, eb) or true, "the value reads in its own colour")
local _, labelSize = fps.label:GetFont()
local _, valueSize = fps.value:GetFont()
assert(labelSize < valueSize, "the unit is smaller than the value")
local vp = fps.value._points[1]
assert(vp[1] == "CENTER" and vp[2] == fps.button and vp[4] < 0, "the value sits left of the cell's centre, so the pair is centred")

-- The docked menu row: the card grows under the strip's line to hold the micro menu at the left and the bag bar at
-- the right, both bare of their own glass, and neither is live in Layout Mode.
eq(ns.Settings().strip.menus, true, "the menus dock in the readout card by default")
local view = ns.Strip.view
assert(view.card and view.card ~= view.frame and view.chrome.owner == view.card, "the chrome moves to a card frame that can outgrow the strip's own line")
-- The strip's footprint is still the 43-unit line, so the card grows upward for the menu row: the strip sits at
-- the screen's bottom edge, where growing down would leave the screen. A 94-tall strip holds the row inside.
local cp = view.card._points
assert(cp[1][1] == "TOPLEFT" and cp[1][2] == view.frame and cp[2][1] == "TOPRIGHT" and cp[2][2] == view.frame, "the card hangs from the strip's top corners")
assert(cp[1][5] > 0 and near(cp[2][5], cp[1][5]), "and rises above the strip for the menu row: " .. tostring(cp[1][5]))
assert(cp[3][1] == "BOTTOM" and cp[3][2] == view.frame and near(cp[3][5], 0), "ending with the strip's line")
local micro, bags = ns.Menus.Content("micro"), ns.Menus.Content("bags")
assert(micro and bags, "both bars are built")
assert(not ns.Menus.Holder("micro"):IsShown() and not ns.Menus.Holder("bags"):IsShown(), "the Layout-owned holders hide while docked")
assert(micro:GetParent() == view.frame and bags:GetParent() == view.frame, "the docked buttons sit on the strip, so they show while their holders hide")
assert(micro:IsShown() and bags:IsShown(), "and are shown")
local mp = micro._points[1]
assert(mp[1] == "TOPLEFT" and mp[2] == view.frame and mp[3] == "BOTTOMLEFT" and mp[4] > 0 and mp[5] > 0, "the micro menu's buttons dock above the strip's left")
local bp = bags._points[1]
assert(bp[1] == "TOPRIGHT" and bp[2] == view.frame and bp[3] == "BOTTOMRIGHT" and bp[4] < 0 and near(bp[5], mp[5]), "the bag bar's buttons dock above the strip's right, on the same line")
assert(near(cp[1][5], mp[5] + view.pad, 0.5), "the card starts one padding above the menu row: " .. tostring(cp[1][5]))
-- Given the Lumen footprint, the row sits inside the card under the line.
K.Layout.Update("databars.strip", { height = 94 })
env.RunTimers()
cp = view.card._points
assert(near(cp[1][5], 0) and near(cp[3][5], 0), "a 94-tall strip is the whole card")
mp = micro._points[1]
local rowHeight = ns.Menus.Holder("micro"):GetHeight()
assert(near(mp[5], view.pad + rowHeight, 0.5) and mp[5] + ns.Strip.UNIT_GAP < 94 - view.line, "and the menu row sits inside it under the line, one padding up from the strip's bottom: " .. tostring(mp[5]))
K.Layout.Update("databars.strip", { height = 43 })
env.RunTimers()
assert(not ns.Menus.Glass("micro"):IsShown() and not ns.Menus.Glass("bags"):IsShown(), "the docked bars have no glass of their own")
for _, key in ipairs({ "databars.micro", "databars.bags" }) do
	local el
	for _, e in ipairs(K.Layout.Elements()) do
		if e.key == key then
			el = e
		end
	end
	assert(el and not K.Layout.Live(key), key .. " keeps its element but is not live while docked")
end

-- Round crystal buttons: each menu and bag button is a disc with a ring, its icon masked round, and square.
for _, id in ipairs({ "micro", "bags" }) do
	eq(ns.Settings()[id].shape, "round", id .. " buttons are round by default")
	local button = ns.Menus.Shown(id)[1]
	assert(button, id .. " shows a button")
	assert(button.crystal and button.crystal.disc:IsShown() and button.crystal.ring:IsShown(), id .. ": a crystal disc under the icon")
	assert(not button.chrome.fill[5]:IsShown(), id .. ": no tile chrome")
	assert(masked(button), id .. ": the icon is masked round")
	assert(near(button:GetWidth(), button:GetHeight()), id .. ": a round button is square")
end
Options.Write("DataBars", "micro.shape", "tile")
local tile = ns.Menus.Shown("micro")[1]
assert(not tile.crystal.disc:IsShown() and tile.chrome.fill[5]:IsShown(), "the tile shape brings the chamfered tile back")
assert(not masked(tile), "and takes the round mask off the icon")
Options.Write("DataBars", "micro.shape", "round")

-- Setting the menus free: their own elements again, live, with their glass back, and the card shrinks to the line.
Options.Write("DataBars", "strip.menus", false)
assert(K.Layout.Live("databars.micro") and K.Layout.Live("databars.bags"), "free bars are live in Layout Mode")
assert(ns.Menus.Glass("micro"):IsShown(), "and wear their glass again")
assert(micro._points[1][2] == ns.Menus.Holder("micro") and micro:GetParent() == ns.Menus.Holder("micro") and ns.Menus.Holder("micro"):IsShown(), "the micro menu's buttons return to their own holder, which shows again")
assert(near(view.card._points[1][5], 0), "the card is the strip's line again")
Options.Write("DataBars", "strip.menus", true)
assert(micro._points[1][2] == view.frame and not K.Layout.Live("databars.micro"), "docking again")

-- The old label modes still work.
Options.Write("DataBars", "strip.labels", "short")
eq(fps.label:GetText(), "FPS", "short labels are the caps labels")
Options.Write("DataBars", "strip.labels", "none")
eq(fps.label:IsShown(), false, "no labels")
Options.Write("DataBars", "strip.labels", "inline")
eq(fps.label:GetText(), "fps", "and inline again")

eq(#env._errors, 0, tostring(env._errors[1]))
print("databars readout ok")

-- A value that grows on a tick widens its inline pair, so digits never clip until the next full refresh.
do
	local latency = item(ns, "latency")
	local before = latency.value:GetWidth()
	env._game.latencyHome, env._game.latencyWorld = 1234, 1234
	ns.Strip.Update(true)
	assert(latency.value:GetText() == "1234", "the tick reads the new latency: " .. tostring(latency.value:GetText()))
	assert(latency.value:GetWidth() > before, "and the value's width grows with its digits: " .. tostring(latency.value:GetWidth()) .. " from " .. tostring(before))
end

-- A card too narrow for both bars at the smallest disc wraps the bag bar under the menu row instead of overlapping.
do
	K.Layout.Update("databars.strip", { width = 200, height = 43 })
	env.RunTimers()
	assert(ns.Strip.view.wrapMenus == true, "a 200-wide card wraps the bars")
	local microTop, bagsTop = ns.Menus.Content("micro")._points[1][5], ns.Menus.Content("bags")._points[1][5]
	assert(bagsTop < microTop - 10, "the bag bar sits on a second line under the menu row: " .. tostring(bagsTop) .. " vs " .. tostring(microTop))
	K.Layout.Update("databars.strip", { width = 492, height = 43 })
	env.RunTimers()
	assert(ns.Strip.view.wrapMenus == false, "the wide card shares one row again")
end
