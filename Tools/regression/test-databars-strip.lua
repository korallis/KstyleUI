-- test-databars-strip.lua: the data strip against the stub game: items, order, values, colours, settings, clicks, the secure click proxy, tooltips and the ticker.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function sameText(fs, r, g, b)
	local cr, cg, cb = fs:GetTextColor()
	return near(cr, r) and near(cg, g) and near(cb, b)
end

local function noErrors(env, K)
	assert(#env._errors == 0, "errors were raised: " .. tostring(env._errors[1]))
	eq(K.ErrorCount(), 0, "errors caught by KstyleUI.Call")
end

local function element(K, key)
	for _, el in ipairs(K.Layout.Elements()) do
		if el.key == key then
			return el
		end
	end
end

local function shown(ns)
	local out = {}
	for _, id in ipairs(ns.Strip.order) do
		out[#out + 1] = id
	end
	return table.concat(out, ",")
end

local function item(ns, id)
	return assert(ns.Strip.view.items[id], id .. " exists")
end

local function tooltipText(K)
	local lines = {}
	for _, line in ipairs(K.Widgets.Tooltip().used) do
		lines[#lines + 1] = (line.left:GetText() or "") .. "=" .. (line.right:IsShown() and (line.right:GetText() or "") or "")
	end
	return (table.concat(lines, "|"):gsub("\226\128\137", ""))
end

-- Registered with Layout; the five items in the mockup's order ---------------------------------------

do
	local env, K, ns = D.New()
	local el = assert(element(K, "databars.strip"), "the strip registers with Layout")
	eq(el.module, "DataBars", "the strip belongs to the module")
	eq(el.opts.resizable, true, "the strip is resizable")
	eq(el.label, K.Setup.Layouts.Element("databars.strip").label, "the setup's label")
	local default, got = K.Setup.Layouts.Default("databars.strip"), K.Layout.Get("databars.strip")
	eq(got.anchor .. got.x .. "," .. got.y, default.anchor .. default.x .. "," .. default.y, "the setup's position")
	eq(shown(ns), "fps,latency,gold,durability,time", "the default order")
	eq(item(ns, "fps").label:GetText(), "fps", "fps unit, inline by default")
	eq(item(ns, "fps").value:GetText(), "144", "fps rounds the frame rate")
	eq(item(ns, "latency").value:GetText(), "34", "home latency by default, its unit inline")
	eq(item(ns, "latency").label:GetText(), "ms", "the latency unit")
	eq(item(ns, "gold").value:GetText(), "143g 82s 17c", "gold")
	eq(item(ns, "durability").label:GetText(), "armour", "durability reads as armour")
	eq(item(ns, "durability").value:GetText(), "96%", "the lowest item's durability")
	eq(item(ns, "time").value:GetText(), "14:32", "local time on a 24-hour clock")
	assert(sameText(item(ns, "fps").value, K.Theme.Accent()), "a high frame rate reads in the accent, the class colour the mockup's green stands for")
	-- Labels step back in the text grey and the values lead in white, the hierarchy a player scans for: the
	-- all-white strip of ingame-18 read as one flat sentence.
	assert(sameText(item(ns, "fps").label, K.Tokens.Color("text")), "labels read in the text grey")
	eq(ns.Strip.view.chrome.fill[1]:IsShown(), true, "the strip sits on glass")
	-- The Lumen readout card on the right rail's foot: 318 x 118, the readout line with the menu rows docked under it.
	-- Its values read at the HUD's bar size, 12, in fixed cells: no separators by default.
	eq(got.width .. "x" .. got.height, "318x118", "the strip takes the Lumen readout card's size")
	eq(ns.Strip.view.chrome:Chamfer(), math.min(14, 118 / 2), "the strip's corners round 14 units, the card radius, never more than half its height")
	local s = ns.Settings().strip
	eq(s.fontSize, 12, "the strip reads at 12 by default")
	eq(s.spacing, 16, "16 units of room inside each cell")
	eq(s.separators, false, "no separators by default")
	for _, id in ipairs(ns.Strip.order) do
		eq(item(ns, id).separator:IsShown(), false, id .. " has no separator by default")
	end
	local _, labelSize = item(ns, "fps").label:GetFont()
	assert(labelSize < select(2, item(ns, "fps").value:GetFont()), "the caption is smaller than its value")
	local lp, lrel, lrp = item(ns, "fps").label:GetPoint(1)
	local vp, vrel, vrp = item(ns, "fps").value:GetPoint(1)
	eq(lp .. ">" .. tostring(lrel == item(ns, "fps").value) .. ">" .. lrp, "LEFT>true>RIGHT", "the inline unit follows its value on one line")
	eq(vp .. ">" .. tostring(vrel == item(ns, "fps").button) .. ">" .. vrp, "CENTER>true>CENTER", "the value sits on the cell's centre line")
	-- The full labels still stack: a caption over the value, on the 492 by 43 strip they were drawn for (the readout
	-- card's 318 drops captions that cannot fit their cells).
	assert(K.Layout.Update("databars.strip", { width = 492, height = 43 }))
	env.RunTimers()
	K.Options.Write("DataBars", "strip.labels", "full")
	lp, lrel, lrp = item(ns, "fps").label:GetPoint(1)
	vp, vrel, vrp = item(ns, "fps").value:GetPoint(1)
	eq(lp .. ">" .. tostring(lrel == item(ns, "fps").button) .. ">" .. lrp, "BOTTOM>true>CENTER", "a full caption sits over the centre line")
	eq(vp .. ">" .. tostring(vrel == item(ns, "fps").button) .. ">" .. vrp, "TOP>true>CENTER", "the value under it")
	K.Options.Write("DataBars", "strip.labels", "inline")
	noErrors(env, K)
end

-- The ticker updates fps, latency and the clock; events update gold and durability -------------------

do
	local env, K, ns, game = D.New()
	eq(env.LiveTickers(), 1, "one ticker runs while the strip shows a timed item")
	game.fps, game.latencyHome = 25.4, 320
	game.localTime.hour, game.localTime.min = 15, 1
	env.RunTickers()
	eq(item(ns, "fps").value:GetText(), "25", "the ticker reads the frame rate")
	assert(sameText(item(ns, "fps").value, K.Tokens.Color("hostile")), "a low frame rate reads hostile")
	eq(item(ns, "latency").value:GetText(), "320", "the ticker reads latency")
	assert(sameText(item(ns, "latency").value, K.Tokens.Color("hostile")), "high latency reads hostile")
	eq(item(ns, "time").value:GetText(), "15:01", "the ticker reads the clock")

	game.money = 2000000
	env.FireEvent("PLAYER_MONEY")
	eq(item(ns, "gold").value:GetText(), "200g 0s 0c", "PLAYER_MONEY updates gold")
	game.durability[5] = { 10, 100 }
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	eq(item(ns, "durability").value:GetText(), "10%", "the most worn item")
	assert(sameText(item(ns, "durability").value, K.Tokens.Color("hostile")), "low durability reads hostile")

	-- A tick reads only the timed items, and the clock without a date table.
	local durability, tables = game.durabilityCalls, game.dateCalls["*t"] or 0
	env.RunTickers()
	eq(game.durabilityCalls, durability, "a tick leaves durability to its events")
	eq(game.dateCalls["*t"] or 0, tables, "a tick reads the clock without building a date table")
	game.localTime.hour, game.localTime.min = 9, 7
	env.RunTickers()
	eq(item(ns, "time").value:GetText(), "09:07", "the ticker still reads the clock")
	eq(item(ns, "durability").value:GetText(), "10%", "and durability keeps its last value")

	K.Modules.Disable("DataBars")
	eq(env.LiveTickers(), 0, "the ticker stops with the module")
	K.Modules.Enable("DataBars")
	eq(env.LiveTickers(), 1, "and starts again")
	noErrors(env, K)
end

-- Settings: slots, labels, colours, money, latency, clock, backdrop, separators, font ----------------

do
	local env, K, ns = D.New()
	local Options = K.Options
	Options.Write("DataBars", "strip.slot2", "none")
	eq(shown(ns), "fps,gold,durability,time", "an empty slot drops its item")
	Options.Write("DataBars", "strip.slot1", "time")
	eq(shown(ns), "time,gold,durability", "a slot can take another item, and a repeat shows once")
	eq(item(ns, "fps").button:IsShown(), false, "an item in no slot hides")
	Options.Write("DataBars", "strip.slot1", "fps")
	Options.Write("DataBars", "strip.slot2", "latency")

	Options.Write("DataBars", "strip.labels", "short")
	eq(item(ns, "durability").label:GetText(), "DUR", "short captions")
	eq(item(ns, "latency").label:GetText(), "MS", "short latency caption")
	eq(item(ns, "latency").value:GetText(), "34", "short latency drops the unit")
	Options.Write("DataBars", "strip.labels", "none")
	eq(item(ns, "fps").label:IsShown(), false, "no labels")
	Options.Write("DataBars", "strip.labels", "full")

	-- The default, "highlight": the frame rate reads in the accent (the mockup's one highlighted value, "144" in the
	-- class colour), warnings keep their threshold colours, and every other value is white.
	assert(ns.defaults.strip.valueColor == "highlight", "the strip highlights by default")
	assert(sameText(item(ns, "fps").value, K.Theme.Accent()), "a good frame rate reads in the accent")
	assert(sameText(item(ns, "latency").value, K.Tokens.Color("textEmphasis")) and sameText(item(ns, "durability").value, K.Tokens.Color("textEmphasis")), "good latency and durability stay white, as the mockup draws them")
	assert(sameText(item(ns, "gold").value, K.Tokens.Color("textEmphasis")), "gold is white")
	env._game.latencyHome = 400
	env.RunTimers()
	ns.Strip.Refresh()
	assert(sameText(item(ns, "latency").value, K.Tokens.Color("hostile")), "poor latency keeps its warning colour")
	env._game.fps = 20
	ns.Strip.Refresh()
	assert(sameText(item(ns, "fps").value, K.Tokens.Color("hostile")), "a poor frame rate warns rather than highlights")
	env._game.fps = 144.2
	env._game.latencyHome = 34
	ns.Strip.Refresh()
	Options.Write("DataBars", "strip.valueColor", "threshold")
	assert(sameText(item(ns, "latency").value, K.Tokens.Color("friendly")), "the threshold mode colours every graded value")
	Options.Write("DataBars", "strip.valueColor", "plain")
	assert(sameText(item(ns, "fps").value, K.Tokens.Color("textEmphasis")), "plain values")
	Options.Write("DataBars", "accentColor", { r = 0, g = 1, b = 0 })
	Options.Write("DataBars", "accentSource", "custom")
	Options.Write("DataBars", "strip.valueColor", "accent")
	assert(sameText(item(ns, "gold").value, 0, 1, 0), "accent values follow the custom accent")
	Options.Write("DataBars", "accentSource", "class")
	assert(sameText(item(ns, "gold").value, K.Theme.Accent()), "or the class colour")

	Options.Write("DataBars", "strip.money", "gold")
	eq(item(ns, "gold").value:GetText(), "143g", "gold only")
	Options.Write("DataBars", "strip.latency", "world")
	eq(item(ns, "latency").value:GetText(), "41 ms", "world latency")
	Options.Write("DataBars", "strip.clock24", false)
	eq(item(ns, "time").value:GetText(), "2:32 PM", "a 12-hour clock")
	Options.Write("DataBars", "strip.timeSource", "realm")
	eq(item(ns, "time").value:GetText(), "9:05 AM", "realm time")

	Options.Write("DataBars", "strip.backdrop", false)
	eq(ns.Strip.view.chrome.fill[1]:IsShown(), false, "the glass can be turned off")
	Options.Write("DataBars", "strip.separators", true)
	eq(item(ns, "fps").separator:IsShown(), false, "the first cell has no separator")
	local separator = item(ns, "latency").separator
	eq(separator:IsShown(), true, "a separator can be turned on between cells")
	assert(near(separator:GetWidth(), K.Widgets.Border(ns.Strip.view.frame)), "a separator is a hairline")
	local sp, srel, srp = separator:GetPoint(1)
	eq(sp .. ">" .. tostring(srel == item(ns, "latency").button) .. ">" .. srp, "LEFT>true>LEFT", "on the cell's left edge")
	Options.Write("DataBars", "strip.separators", false)
	for _, id in ipairs(ns.Strip.order) do
		eq(item(ns, id).separator:IsShown(), false, id .. "'s separator hides")
	end

	local face = K.Tokens.MediaList("font")[2].path
	Options.Write("DataBars", "strip.font", face)
	local _, defaultSize = item(ns, "gold").value:GetFont()
	eq(defaultSize, 12 * K.Theme.FontScale(), "the strip reads at 12 by default")
	Options.Write("DataBars", "strip.fontSize", 13)
	Options.Write("DataBars", "strip.outline", "OUTLINE")
	local path, size, flags = item(ns, "gold").value:GetFont()
	eq(path, face, "strip font")
	eq(size, 13 * K.Theme.FontScale(), "strip font size")
	eq(flags, "OUTLINE", "strip outline")

	Options.Write("DataBars", "strip.orientation", "VERTICAL")
	local layout = K.Layout.Get("databars.strip")
	assert(layout.width < 318 and layout.height > 118, "a column strip turns narrower and taller: " .. layout.width .. "x" .. layout.height)
	local first, second = item(ns, "fps").button, item(ns, "latency").button
	local _, _, _, x1, y1 = first:GetPoint(1)
	local _, _, _, _, y2 = second:GetPoint(1)
	assert(y2 < y1, "upright items stack downward")
	local inset = ns.Strip.view.chrome:Inset()
	assert(math.abs(x1 - inset) < 0.01, "upright items start one content inset from the left, the rule every text panel follows, got " .. x1 .. " for " .. inset)
	local rows = 5
	assert(math.abs(layout.height - K.Widgets.Snap(ns.Strip.view.frame, rows * 13 * 1.8 + 2 * inset)) < 1.01, "the column is its rows plus one inset above and below, got " .. layout.height)
	Options.Write("DataBars", "strip.orientation", "HORIZONTAL")
	layout = K.Layout.Get("databars.strip")
	eq(layout.width .. "x" .. layout.height, "318x118", "a row strip returns to its footprint")
	for i = 2, 5 do
		Options.Write("DataBars", "strip.slot" .. i, "none")
	end
	Options.Write("DataBars", "strip.orientation", "VERTICAL")
	Options.Write("DataBars", "strip.orientation", "HORIZONTAL")
	layout = K.Layout.Get("databars.strip")
	eq(layout.width .. "x" .. layout.height, "318x118", "a one-item column also returns to the row footprint")
	noErrors(env, K)
end

-- Fixed cells: a value never moves a cell; large money, large fonts and narrow holders stay inside the glass -

local function Cell(ns, id)
	local button = item(ns, id).button
	return select(4, button:GetPoint(1)), button:GetWidth()
end

local function Cells(ns)
	local out = {}
	for _, id in ipairs(ns.Strip.order) do
		local x, w = Cell(ns, id)
		out[#out + 1] = string.format("%.2f+%.2f", x, w)
	end
	return table.concat(out, ",")
end

local function Inside(ns, cellsOnly)
	local frame = ns.Strip.view.frame
	local pad = ns.Strip.view.chrome:Inset()
	for _, id in ipairs(ns.Strip.order) do
		local x, w = Cell(ns, id)
		if x < pad - 0.01 or x + w > frame:GetWidth() - pad + 0.01 then
			return false, id
		end
		local it = item(ns, id)
		if not cellsOnly and (it.value:GetWidth() > w + 0.01 or it.label:GetWidth() > w + 0.01) then
			return false, id .. " text"
		end
	end
	return true
end

do
	local env, K, ns, game = D.New()
	local Options = K.Options
	-- The cells and captions below are measured at the 492 by 43 strip they were drawn for; the Lumen readout card is
	-- 318 by 118.
	assert(K.Layout.Update("databars.strip", { width = 492, height = 43 }))
	env.RunTimers()
	local before = Cells(ns)
	assert(Inside(ns), "every cell sits inside the glass")
	local _, goldWidth = Cell(ns, "gold")
	local _, fpsWidth = Cell(ns, "fps")
	assert(goldWidth > fpsWidth, "gold has the widest cell: " .. goldWidth .. " for " .. fpsWidth)
	game.fps, game.latencyHome = 9, 9999
	env.RunTickers()
	eq(Cells(ns), before, "a value that narrows moves no cell")
	game.fps = 1444
	game.money = 99999999999
	env.FireEvent("PLAYER_MONEY")
	env.RunTickers()
	eq(Cells(ns), before, "a value that widens moves no cell")
	local ok, what = Inside(ns)
	assert(ok, "large money stays inside its cell: " .. tostring(what))
	W.Enter(item(ns, "gold").button)
	assert(tooltipText(K):find("Gold=9,999,999g 99s 99c", 1, true), "the tooltip carries the whole amount: " .. tooltipText(K))
	W.Leave(item(ns, "gold").button)

	-- A large font with stacked captions: the caption and the value no longer fit the strip's height, so the
	-- captions step aside and the values sit on the centre line.
	Options.Write("DataBars", "strip.labels", "full")
	Options.Write("DataBars", "strip.fontSize", 22)
	eq(item(ns, "fps").label:IsShown(), false, "a 22 font drops the captions")
	local vp, _, vrp = item(ns, "fps").value:GetPoint(1)
	eq(vp .. ">" .. vrp, "CENTER>CENTER", "and centres the values")
	eq(Cells(ns), before, "a font change moves no cell")
	-- A 22 font cannot fit "9,999,999g 99s 99c" in gold's cell. The value is never cut to "9,999,9...": a number
	-- cut short reads as a smaller number, so the text keeps its width and the cells stay put.
	assert(not item(ns, "gold").value:IsTruncated(), "a large font never cuts a value")
	assert(item(ns, "gold").value:GetWidth() >= item(ns, "gold").value:GetUnboundedStringWidth(), "the value is as wide as its text")
	Options.Write("DataBars", "strip.fontSize", 12)
	Options.Write("DataBars", "strip.labels", "inline")
	eq(item(ns, "fps").label:IsShown(), true, "the captions come back at 12")
	-- The interface text scale enlarges both: a 17 font fits at scale 1, and not at 1.3.
	Options.Write("DataBars", "strip.labels", "short")
	Options.Write("DataBars", "strip.fontSize", 17)
	eq(item(ns, "fps").label:IsShown(), true, "a 17 font keeps short captions at scale 1")
	K.Theme.SetFontScale(1.3)
	ns.Strip.Refresh()
	eq(item(ns, "fps").label:IsShown(), false, "a 17 font at 1.3 drops them: the stack is taller than the strip")
	K.Theme.SetFontScale(1)
	Options.Write("DataBars", "strip.fontSize", 12)
	Options.Write("DataBars", "strip.labels", "full")
	ns.Strip.Refresh()

	-- A narrow saved holder: the cells share what there is, a caption that cannot fit its cell drops them all,
	-- and every value draws whole; "9999 ms" overruns its 34-unit cell by a few units rather than read "9999 ...".
	K.Layout.Update("databars.strip", { width = 220, height = 43 })
	ok, what = Inside(ns, true)
	assert(ok, "a narrow strip keeps its cells inside the glass: " .. tostring(what))
	for _, id in ipairs(ns.Strip.order) do
		assert(not item(ns, id).value:IsTruncated(), id .. "'s value is never cut on a narrow strip")
	end
	eq(item(ns, "durability").label:IsShown(), false, "a narrow strip drops captions that cannot fit")
	K.Layout.Update("databars.strip", { width = 492, height = 43 })
	eq(item(ns, "durability").label:IsShown(), true, "and shows them again at the footprint")
	eq(Cells(ns), before, "the footprint gives the same cells back")

	-- A column: a caption at the left of each row, its value at the right.
	Options.Write("DataBars", "strip.orientation", "VERTICAL")
	local lp, _, lrp = item(ns, "gold").label:GetPoint(1)
	vp, _, vrp = item(ns, "gold").value:GetPoint(1)
	eq(lp .. ">" .. lrp .. "|" .. vp .. ">" .. vrp, "LEFT>LEFT|RIGHT>RIGHT", "a column row has its caption left and its value right")
	local frame = ns.Strip.view.frame
	local pad = ns.Strip.view.chrome:Inset()
	for _, id in ipairs(ns.Strip.order) do
		local button = item(ns, id).button
		assert(button:GetWidth() <= frame:GetWidth() - 2 * pad + 0.01, id .. " fits the column")
		eq(item(ns, id).separator:IsShown(), false, id .. " has no separator in a column")
	end
	noErrors(env, K)
end

-- Clicks: settings, latency source, clock format -----------------------------------------------------

do
	local env, K, ns = D.New()
	local opened
	K.Options.Open = function(page)
		opened = page
		return true
	end
	W.Click(item(ns, "fps").button)
	eq(opened, "DataBars", "clicking fps opens the data bar settings")
	W.Click(item(ns, "latency").button)
	eq(K.Options.Read("DataBars", "strip.latency"), "world", "clicking latency switches to world latency")
	eq(item(ns, "latency").value:GetText(), "41", "and shows it")
	W.Click(item(ns, "time").button, "RightButton")
	eq(K.Options.Read("DataBars", "strip.clock24"), false, "right-clicking the clock switches to 12 hours")
	noErrors(env, K)
end

-- The secure click proxy reaches Blizzard's buttons out of combat only -------------------------------

do
	local env, K, ns = D.New()
	local gold = item(ns, "gold").button
	W.Enter(gold)
	local proxy = assert(ns.Click.proxy, "hovering gold readies the secure proxy")
	eq(proxy._template, "SecureActionButtonTemplate", "a secure action button")
	eq(proxy:GetParent(), env.UIParent, "parented to UIParent, so no KstyleUI frame turns protected")
	eq(proxy:GetAttribute("type1"), "click", "a left click is a secure click")
	eq(proxy:GetAttribute("clickbutton1"), env.MainMenuBarBackpackButton, "on Blizzard's backpack button")
	eq(proxy:IsShown(), true, "the proxy covers the item")
	eq(W.Covers(env, proxy, gold), true, "over the gold item, anchored only to UIParent")
	W.Leave(gold)
	eq(K.Widgets.Tooltip():IsOwned(gold), true, "the pointer passing to the proxy keeps the tooltip")
	W.Enter(proxy)
	eq(K.Widgets.Tooltip():IsOwned(gold), true, "the item's tooltip stays up under the proxy")
	W.Leave(proxy)
	eq(proxy:IsShown(), false, "leaving the proxy puts it away")

	W.Enter(item(ns, "durability").button)
	eq(proxy:GetAttribute("clickbutton1"), env.CharacterMicroButton, "durability reaches the character button")
	W.Leave(proxy)
	W.Enter(item(ns, "time").button)
	eq(proxy:GetAttribute("clickbutton1"), env.GameTimeFrame, "the clock reaches the calendar button")
	proxy:GetScript("PostClick")(proxy, "RightButton", false)
	eq(K.Options.Read("DataBars", "strip.clock24"), false, "a right click through the proxy still switches the clock")
	proxy:GetScript("PostClick")(proxy, "LeftButton", false)
	eq(K.Options.Read("DataBars", "strip.clock24"), false, "a left click is the secure click's alone")

	W.Enter(gold)
	eq(proxy:IsShown(), true, "the proxy covers gold again")
	ns.Strip.view.frame:GetScript("OnHide")(ns.Strip.view.frame)
	eq(proxy:IsShown(), false, "hiding the strip, as a shown rule does, puts the proxy away")
	eq(K.Widgets.Tooltip():IsOwned(gold), false, "and its tooltip")
	W.Enter(gold)
	K.Options.Write("DataBars", "strip.slot3", "none")
	eq(proxy:IsShown(), false, "taking gold out of its slot puts the proxy away")
	K.Options.Write("DataBars", "strip.slot3", "gold")
	K.Options.Write("DataBars", "strip.clock24", true)

	local inCombat = {}
	local set = proxy.SetAttribute
	proxy.SetAttribute = function(self, ...)
		if env._combat then
			inCombat[#inCombat + 1] = ...
		end
		return set(self, ...)
	end
	env.SetCombat(true)
	eq(proxy:IsShown(), false, "combat puts the proxy away before lockdown")
	W.Enter(item(ns, "gold").button)
	eq(proxy:IsShown(), false, "no proxy in combat")
	eq(#inCombat, 0, "no secure attribute changes in combat")
	W.Leave(item(ns, "gold").button)
	env.SetCombat(false)
	noErrors(env, K)
end

do
	local env, K, ns = D.New({ blizzard = false })
	W.Enter(item(ns, "gold").button)
	eq(ns.Click.proxy, nil, "no Blizzard target, no proxy")
	W.Click(item(ns, "gold").button)
	noErrors(env, K)
end

-- Tooltips -------------------------------------------------------------------------------------------

do
	local env, K, ns, game = D.New()
	game.durability[5] = { 10, 100 }
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	W.Enter(item(ns, "durability").button)
	local text = tooltipText(K)
	assert(text:find("DURABILITY", 1, true), "durability tooltip title in the kit's capitals: " .. text)
	assert(text:find("Chest=10%", 1, true), "the tooltip lists each worn slot: " .. text)
	W.Leave(item(ns, "durability").button)
	W.Enter(item(ns, "latency").button)
	text = tooltipText(K)
	assert(text:find("Home=34 ms", 1, true) and text:find("World=41 ms", 1, true), "latency tooltip: " .. text)
	W.Leave(item(ns, "latency").button)
	game.money = 1438217 + 50000
	env.FireEvent("PLAYER_MONEY")
	W.Enter(item(ns, "gold").button)
	text = tooltipText(K)
	assert(text:find("This session=5g 0s 0c", 1, true), "gold tooltip shows the session: " .. text)
	noErrors(env, K)
end

-- A client without the data APIs shows placeholders, not errors ----------------------------------------

do
	local env, K, ns = D.New({ setup = function(e)
		e.GetFramerate, e.GetNetStats, e.GetInventoryItemDurability = nil, nil, nil
	end })
	eq(item(ns, "fps").value:GetText(), "--", "no frame rate")
	eq(item(ns, "latency").value:GetText(), "--", "no latency")
	eq(item(ns, "durability").value:GetText(), "--", "no durability")
	env.RunTickers()
	noErrors(env, K)
end

-- The preview shows a sample strip that follows the settings ------------------------------------------

do
	local env, K = D.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(248, 400)
	local frame = K.Options.Preview("DataBars")(parent)
	local sample = assert(frame.strip, "the preview shows a strip")
	K.Options.Write("DataBars", "strip.labels", "short")
	frame:Refresh()
	eq(sample.items.durability.label:GetText(), "DUR", "the preview strip follows the labels setting")
	K.Options.Write("DataBars", "strip.labels", "full")
	frame:Refresh()
	local width = sample.frame:GetWidth() * sample.frame:GetScale()
	assert(width <= 248 + 1e-6, "the sample strip fits the preview pane, got " .. width)
	assert(sample.frame:GetWidth() >= sample.contentWidth, "and holds all its items")
	noErrors(env, K)
end

-- The readout card hugs its rows, and its docked buttons stay readable -----------------------------------
-- The micro menu docks under the readout line in its compact set (eight buttons), the bag bar on its own
-- row at the right; no docked button shrinks under 22 units, a row that cannot fit wraps instead, and the
-- card's height follows the rows, in Layout too, so the mover plate and the glass agree.

do
	local env, K, ns = D.New({ setup = D.Menus })
	local Strip, Menus = ns.Strip, ns.Menus
	local view = Strip.view
	eq(Strip.MENU_MIN, 22, "a docked button is never under 22 units")
	local micro, bags = Menus.Shown("micro"), Menus.Shown("bags")
	eq(#micro, 8, "the compact set shows eight micro buttons: " .. #micro)
	eq(#bags, 6, "and the bag bar its six bags")
	for _, list in ipairs({ micro, bags }) do
		for _, button in ipairs(list) do
			assert(button:GetHeight() >= Strip.MENU_MIN, "a docked button reads at " .. button:GetHeight())
		end
	end
	eq(micro[1]:GetHeight(), ns.Settings().micro.size, "with room to spare the micro buttons take their set size")
	local pad, gap = view.pad, K.Widgets.Snap(view.frame, 6)
	local microH, bagsH = Menus.Holder("micro"):GetHeight(), Menus.Holder("bags"):GetHeight()
	-- Round 3 (Opus #6): the readout line holds the card's top padding itself, so the micro row starts a small gap
	-- under the text instead of a second padding lower (45 px of empty glass in the hero render), and the card fits
	-- the 118 units the layouts keep for it.
	eq(Strip.LINE, 30, "the readout line is 30 units with the card's top padding in it")
	local want = Strip.LINE + gap + microH + gap + bagsH + pad
	local h = view.frame:GetHeight()
	assert(near(h, want), string.format("the card is the readout line, the micro row and the bag row inside the padding: %s for %s", h, want))
	assert(h <= K.Setup.Layouts.Element("databars.strip").height + 0.5, "the docked card fits the footprint the layouts keep: " .. h)
	-- Fable #3: the micro row and the bag row share the card's right edge, under the right-aligned readout.
	local mp, _, mrp, mx = Menus.Content("micro"):GetPoint(1)
	local bp, _, brp, bx = Menus.Content("bags"):GetPoint(1)
	assert(mp == "TOPRIGHT" and mrp == "TOPRIGHT" and bp == "TOPRIGHT" and brp == "TOPRIGHT" and near(mx, bx), "the micro and bag rows align on the card's right edge: " .. tostring(mp) .. " " .. tostring(mx) .. " / " .. tostring(bx))
	eq(K.Layout.Get("databars.strip").height, h, "and Layout holds the same height, so the mover plate hugs too")
	local _, _, _, _, my = Menus.Content("micro"):GetPoint(1)
	local _, _, _, _, by = Menus.Content("bags"):GetPoint(1)
	assert(near(by, my - microH - gap), "the bag row sits under the micro row")
	-- The full set: fourteen buttons (the stub hides Help, so thirteen show) wrap into two rows rather than shrink under 22.
	K.Options.Write("DataBars", "micro.set", "full")
	micro = Menus.Shown("micro")
	eq(#micro, 13, "the full set shows every micro button Blizzard shows")
	for _, button in ipairs(micro) do
		assert(button:GetHeight() >= Strip.MENU_MIN, "a full-set button still reads at " .. button:GetHeight())
	end
	assert(Menus.Holder("micro"):GetHeight() > microH, "the full set wraps into a second micro row")
	assert(view.frame:GetHeight() > h, "and the card grows with it")
	K.Options.Write("DataBars", "micro.set", "compact")
	assert(near(view.frame:GetHeight(), h), "back to the compact set the card shrinks again")
	-- A player's taller card keeps its height only while the menus are free: docked, the rows set it.
	K.Options.Write("DataBars", "strip.menus", false)
	assert(K.Layout.Update("databars.strip", { width = 318, height = 90 }))
	env.RunTimers()
	eq(view.frame:GetHeight(), 90, "free menus leave the card's height to the player")
	noErrors(env, K)
end

-- No value is ever cut: on the 318 readout card the inline caption gives way first ----------------------
-- The judges read "34 ..." and "9... armour" on the readout and "14:..." for the clock. With the kit fonts' real
-- glyph widths on the strings (D.New installs them), every value draws whole at the Lumen card's 318 units, and a
-- caption that does not fit beside its value steps down to its short form or goes, never the value. The game
-- answers IsTruncated for a string drawn narrower than its text; the stub answers it from the same widths.

do
	local env, K, ns = D.New({
		setup = function(e)
			D.Menus(e)
		end,
	})
	env.RunTimers()
	assert(K.Layout.Update("databars.strip", { width = 318, height = 118 }))
	env.RunTimers()
	ns.Strip.Refresh()
	local function whole(what)
		for _, id in ipairs(ns.Strip.order) do
			local it = item(ns, id)
			assert(it.value:IsShown(), id .. " shows its value " .. what)
			assert(not it.value:IsTruncated(), string.format("%s's value %q is cut %s: drawn %s wide for %s of text", id,
				tostring(it.value:GetText()), what, tostring(it.value:GetWidth()), tostring(it.value:GetUnboundedStringWidth())))
			local pair = it.value:GetUnboundedStringWidth()
			if it.label:IsShown() then
				assert(not it.label:IsTruncated(), string.format("%s's caption %q is cut %s; a caption that does not fit shortens or goes",
					id, tostring(it.label:GetText()), what))
				pair = pair + ns.Strip.UNIT_GAP + it.label:GetUnboundedStringWidth()
			end
			assert(pair <= it.button:GetWidth() + 0.01, string.format("%s's value and caption (%s wide) spill out of their %s cell %s, over the next cell's text",
				id, tostring(pair), tostring(it.button:GetWidth()), what))
		end
	end
	whole("at 318 with the default values")
	eq(item(ns, "latency").value:GetText(), "34", "the latency value reads whole")
	eq(item(ns, "durability").value:GetText(), "96%", "the durability value reads whole")
	eq(item(ns, "time").value:GetText(), "14:32", "the clock reads whole")
	-- The widest live values the strip meets: four-digit latency, three-digit fps, full gold, 100% durability.
	local game = env._game
	game.fps, game.latencyHome, game.latencyWorld, game.money = 999.4, 1234, 1234, 99999999
	game.durability[1] = { 100, 100 }
	env.RunTickers()
	env.FireEvent("PLAYER_MONEY")
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	whole("at 318 with the widest values")
	eq(item(ns, "latency").value:GetText(), "1234", "a four-digit latency reads whole")
	-- A value and its caption never overlap: the caption starts where the value ends.
	for _, id in ipairs(ns.Strip.order) do
		local it = item(ns, id)
		if it.label:IsShown() then
			local point, rel = it.label:GetPoint(1)
			eq(point .. ">" .. tostring(rel == it.value), "LEFT>true", id .. "'s caption hangs off its value")
			assert(it.value:GetWidth() >= it.value:GetUnboundedStringWidth() - 0.01, id .. "'s value is as wide as its text")
		end
	end
	-- The short labels fit the same card whole too.
	K.Options.Write("DataBars", "strip.labels", "short")
	whole("at 318 with short labels")
	K.Options.Write("DataBars", "strip.labels", "inline")
	-- The interface text scale at its 1.3 limit: the values still draw whole, and a caption that cannot keep
	-- up steps down to its short form ("100% DUR") or goes, so the next cell's text is never overprinted.
	K.Theme.SetFontScale(1.3)
	ns.Strip.Refresh()
	whole("at 318 and text scale 1.3")
	eq(item(ns, "gold").value:GetText(), "9,999g", "money too wide for its cell in full compacts to gold; the tooltip keeps the whole amount")
	-- A resize compacts against the new cells, not the last layout's: wide, the full string returns; narrow, it compacts.
	assert(K.Layout.Update("databars.strip", { width = 600, height = 118 }))
	env.RunTimers()
	eq(item(ns, "gold").value:GetText(), "9,999g 99s 99c", "a wide card gives the full money string back")
	assert(K.Layout.Update("databars.strip", { width = 318, height = 118 }))
	env.RunTimers()
	eq(item(ns, "gold").value:GetText(), "9,999g", "and the narrow card compacts it again, against its own cells")
	W.Enter(item(ns, "gold").button)
	assert(tooltipText(K):find("Gold=9,999g 99s 99c", 1, true), "the tooltip carries the whole amount: " .. tooltipText(K))
	W.Leave(item(ns, "gold").button)
	K.Theme.SetFontScale(1)
	ns.Strip.Refresh()
	noErrors(env, K)
end

print("databars strip ok")
