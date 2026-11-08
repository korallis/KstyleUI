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
	eq(item(ns, "fps").label:GetText(), "FPS:", "fps label")
	eq(item(ns, "fps").value:GetText(), "144", "fps rounds the frame rate")
	eq(item(ns, "latency").value:GetText(), "34 ms", "home latency by default")
	eq(item(ns, "gold").value:GetText(), "143g 82s 17c", "gold")
	eq(item(ns, "durability").label:GetText(), "Durability:", "durability label")
	eq(item(ns, "durability").value:GetText(), "96%", "the lowest item's durability")
	eq(item(ns, "time").value:GetText(), "14:32", "local time on a 24-hour clock")
	assert(sameText(item(ns, "fps").value, K.Theme.Accent()), "a high frame rate reads in the accent, the class colour the mockup's green stands for")
	assert(sameText(item(ns, "fps").label, K.Tokens.Color("textEmphasis")), "labels read white, as the mockup's FPS: and Durability: do")
	eq(ns.Strip.view.chrome.fill[1]:IsShown(), true, "the strip sits on glass")
	-- The mockup's strip: 492 x 43 with 10.5-unit chamfers, text at 13 (the five items then span the mockup's 444
	-- units), 21 units each side of a separator as tall as the text's cap height, a quarter of the strip.
	eq(got.width .. "x" .. got.height, "492x43", "the strip takes the mockup's size")
	eq(ns.Strip.view.chrome:Chamfer(), math.min(12, 0.3 * 43), "the strip's ends cut 30% of its height, the shared rule (the mockup cuts its 30-unit strip 11)")
	local s = ns.Settings().strip
	eq(s.fontSize, 13, "the strip reads at 13 by default")
	eq(s.spacing, 21, "21 units each side of a separator")
	local separator = item(ns, "latency").separator
	assert(separator:GetHeight() >= 10 and separator:GetHeight() <= 11.5, "a separator is a quarter of the strip tall, got " .. tostring(separator:GetHeight()))
	local sr, sg, sb, sa = separator:GetVertexColor()
	assert(near(sr, K.Tokens.Color("text")) and near(sg, sr) and near(sb, sr) and near(sa, 1), "a separator reads in the full text grey")
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
	eq(item(ns, "latency").value:GetText(), "320 ms", "the ticker reads latency")
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
	eq(item(ns, "durability").label:GetText(), "DUR:", "short labels")
	eq(item(ns, "latency").label:GetText(), "MS:", "short latency label")
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
	Options.Write("DataBars", "strip.separators", false)
	for _, id in ipairs(ns.Strip.order) do
		eq(item(ns, id).separator:IsShown(), false, id .. "'s separator hides")
	end

	local face = K.Tokens.MediaList("font")[2].path
	Options.Write("DataBars", "strip.font", face)
	local _, defaultSize = item(ns, "gold").value:GetFont()
	eq(defaultSize, 13 * K.Theme.FontScale(), "the strip reads at 13 by default")
	Options.Write("DataBars", "strip.fontSize", 13)
	Options.Write("DataBars", "strip.outline", "OUTLINE")
	local path, size, flags = item(ns, "gold").value:GetFont()
	eq(path, face, "strip font")
	eq(size, 13 * K.Theme.FontScale(), "strip font size")
	eq(flags, "OUTLINE", "strip outline")

	Options.Write("DataBars", "strip.orientation", "VERTICAL")
	local layout = K.Layout.Get("databars.strip")
	assert(layout.width < 492 and layout.height > 43, "a column strip turns narrower and taller: " .. layout.width .. "x" .. layout.height)
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
	eq(layout.width .. "x" .. layout.height, "492x43", "a row strip returns to its footprint")
	for i = 2, 5 do
		Options.Write("DataBars", "strip.slot" .. i, "none")
	end
	Options.Write("DataBars", "strip.orientation", "VERTICAL")
	Options.Write("DataBars", "strip.orientation", "HORIZONTAL")
	layout = K.Layout.Get("databars.strip")
	eq(layout.width .. "x" .. layout.height, "492x43", "a one-item column also returns to the row footprint")
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
	eq(item(ns, "latency").value:GetText(), "41 ms", "and shows it")
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
	eq(sample.items.durability.label:GetText(), "DUR:", "the preview strip follows the labels setting")
	K.Options.Write("DataBars", "strip.labels", "full")
	frame:Refresh()
	local width = sample.frame:GetWidth() * sample.frame:GetScale()
	assert(width <= 248 + 1e-6, "the sample strip fits the preview pane, got " .. width)
	assert(sample.frame:GetWidth() >= sample.contentWidth, "and holds all its items")
	noErrors(env, K)
end

print("databars strip ok")
