-- test-qol-feed.lua: the loot feed reads the player's own loot and money lines through the client's global strings, and shows them as short lines above the chat card.
local Q = dofile("Tools/regression/qol_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local BUG_EYE = "|cnIQ0:|Hitem:7101::::::::11:1489:::::::::|h[Bug Eye]|h|r"
local VEST = "|cnIQ0:|Hitem:1425::::::::11:1489:::::::::|h[Worn Leather Vest]|h|r"
local CLOTH = "|cff1eff00|Hitem:2589::::::::38:::::|h[Linen Cloth]|h|r"
local EPIC = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
local OTHER = "|cffffffff|Hitem:4304::::::::38:::::|h[Rugged Hide]|h|r"
local ITEMS = {
	[7101] = { icon = 133884, quality = 0 },
	[1425] = { icon = 135009, quality = 1 },
	[2589] = { icon = 132889, quality = 2 },
	[19019] = { icon = 135349, quality = 5 },
	[4304] = { icon = 134252, quality = 1 },
}

local function New(opts)
	local env, K, ns = Q.New(opts)
	for id, item in pairs(ITEMS) do
		env._items[id] = { icon = item.icon, quality = item.quality }
	end
	Q.Enable(env, K)
	return env, K, ns
end

local function Settle(env)
	Q.W.Settle(env)
	env.RunTimers()
end

local function Loot(env, text)
	env.FireEvent("CHAT_MSG_LOOT", text, "Korallis", "", "", "Korallis", "", 0, 0, "", 0, 1, "Player-1-1", 0)
	Settle(env)
end

local function Money(env, text)
	env.FireEvent("CHAT_MSG_MONEY", text, "Korallis", "", "", "Korallis", "", 0, 0, "", 0, 1, "Player-1-1", 0)
	Settle(env)
end

local function Names(ns)
	local out = {}
	for _, line in ipairs(ns.Feed.lines) do
		out[#out + 1] = line.name:GetText()
	end
	return table.concat(out, "|")
end

-- The pure reads: every loot string the client has, single and stacked, and nothing from other players ---------
do
	local env, _, ns = Q.New()
	local T = ns.LootText
	local id, name, count = T.Item("You receive loot: " .. BUG_EYE)
	assert(id == 7101 and name == "Bug Eye" and count == 1, "one item: " .. tostring(id) .. " " .. tostring(name) .. " " .. tostring(count))
	id, name, count = T.Item("You receive loot: " .. CLOTH .. "x4")
	assert(id == 2589 and name == "Linen Cloth" and count == 4, "a stack reads its count, not as part of the link")
	id, _, count = T.Item("You receive item: " .. VEST)
	assert(id == 1425 and count == 1, "a pushed item")
	id, _, count = T.Item("You create: " .. EPIC .. "x2.")
	assert(id == 19019 and count == 2, "a created stack")
	assert(T.Item(OTHER) == nil and T.Item("Leduc receives loot: " .. OTHER .. ".") == nil, "another player's loot is never the player's own")
	assert(T.Item("You receive loot: Bug Eye") == nil, "text with no item link is not an item")
	assert(T.Item(env.Secret("You receive loot: " .. BUG_EYE)) == nil and T.Item(nil) == nil, "a secret or missing line is skipped, never read")
	assert(T.Money("You loot 14 Copper") == 14, "copper alone")
	assert(T.Money("You loot 1 Gold, 4 Silver, 14 Copper") == 10414, "gold, silver and copper")
	assert(T.Money("Your share of the loot is 5 Silver.") == 500, "a split share")
	assert(T.Money("You loot 1,234 Gold") == 12340000, "a thousands separator")
	assert(T.Money("You loot 5 Silver (2 Silver deposited to guild bank)") == nil, "text beyond the amounts is not guessed at")
	assert(T.Money("Leduc loots 14 Copper.") == nil and T.Money(env.Secret("You loot 14 Copper")) == nil, "other players and secrets are skipped")
end

-- The client's strings in another locale: positional arguments and other words ----------------------------------
do
	local env, _, ns = Q.New()
	env.LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s"
	env.LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %2$dx %1$s"
	env.YOU_LOOT_MONEY = "Ihr plundert %s"
	env.GOLD_AMOUNT = "%d Gold"
	env.SILVER_AMOUNT = "%d Silber"
	env.COPPER_AMOUNT = "%d Kupfer"
	ns.LootText.Reset()
	local id, _, count = ns.LootText.Item("Ihr erhaltet Beute: 3x " .. CLOTH)
	assert(id == 2589 and count == 3, "a positional string reads its arguments in the string's own order")
	assert(ns.LootText.Item("You receive loot: " .. CLOTH) == nil, "the English line is not this locale's")
	assert(ns.LootText.Money("Ihr plundert 2 Silber, 7 Kupfer") == 207, "the locale's coin words")
end

-- A string the client lacks leaves the feed silent ----------------------------------------------------------------
do
	local env, K, ns = Q.New()
	env._items[7101] = { icon = 133884, quality = 0 }
	env.LOOT_ITEM_SELF, env.LOOT_ITEM_SELF_MULTIPLE, env.LOOT_ITEM_PUSHED_SELF, env.LOOT_ITEM_PUSHED_SELF_MULTIPLE = nil, nil, nil, nil
	env.LOOT_ITEM_CREATED_SELF, env.LOOT_ITEM_CREATED_SELF_MULTIPLE, env.LOOT_ITEM_BONUS_ROLL_SELF, env.LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = nil, nil, nil, nil
	env.YOU_LOOT_MONEY, env.LOOT_MONEY_SPLIT = nil, nil
	ns.LootText.Reset()
	Q.Enable(env, K)
	Loot(env, "You receive loot: " .. BUG_EYE)
	Money(env, "You loot 14 Copper")
	assert(#ns.Feed.lines == 0 and K.ErrorCount() == 0, "no string, no line, no error")
end

-- Off while the module is off, and behind its own switch ----------------------------------------------------------
do
	local env, K, ns = Q.New()
	assert(ns.Feed.Holder() == nil, "no frame is built while the module is off")
	Q.Enable(env, K)
	assert(ns.Get("lootFeed") == true and ns.Feed.Holder() ~= nil, "the feed is on by default and builds with the module")
	Q.Write(env, K, "lootFeed", false)
	env._items[7101] = { icon = 133884, quality = 0 }
	Loot(env, "You receive loot: " .. BUG_EYE)
	assert(#ns.Feed.lines == 0, "its own switch turns it off")
	Q.Write(env, K, "lootFeed", true)
	Loot(env, "You receive loot: " .. BUG_EYE)
	assert(#ns.Feed.lines == 1, "and back on")
	Q.Disable(env, K)
	assert(#ns.Feed.lines == 0 and not ns.Feed.Backdrop():IsShown(), "switching the module off clears the feed")
end

-- One line per gain: the name in its quality colour, a count for a stack, coin colours for money -------------
do
	local env, K, ns = New()
	local Theme = K.Theme
	Loot(env, "You receive loot: " .. BUG_EYE)
	Loot(env, "You receive loot: " .. VEST)
	Money(env, "You loot 14 Copper")
	assert(Names(ns) == "Bug Eye|Worn Leather Vest|" .. ns.Feed.lines[3].name:GetText(), "the three lines of the reference, oldest first")
	local bug, vest, coin = ns.Feed.lines[1], ns.Feed.lines[2], ns.Feed.lines[3]
	local r, g, b = Theme.QualityColor(0)
	local tr, tg, tb = bug.name:GetTextColor()
	assert(tr == r and tg == g and tb == b, "Bug Eye is drawn in poor grey, from the item API's quality and not the link's colour")
	r, g, b = Theme.QualityColor(1)
	tr, tg, tb = vest.name:GetTextColor()
	assert(tr == r and tg == g and tb == b, "the vest is common even though its link says IQ0")
	assert(bug.icon:GetTexture() == 133884 and coin.icon:GetTexture() == 133784, "the item's own icon, and a coin for money")
	assert(not bug.count:IsShown(), "one item shows no count")
	assert(coin.name:GetText():find("|cff%x%x%x%x%x%x14c|r"), "copper is drawn in its own colour: " .. coin.name:GetText())
	Money(env, "You loot 1 Gold, 4 Silver, 14 Copper")
	local text = ns.Feed.lines[3].name:GetText()
	assert(#ns.Feed.lines == 3 and text:find("1g") and text:find("4s") and text:find("28c"), "money gains merge into one line: " .. text)
	local gold, silver, copper = text:match("(|c%x%x%x%x%x%x%x%x)1g"), text:match("(|c%x%x%x%x%x%x%x%x)4s"), text:match("(|c%x%x%x%x%x%x%x%x)28c")
	assert(gold and silver and copper and gold ~= silver and silver ~= copper, "gold, silver and copper each have a colour of their own")
	assert(K.ErrorCount() == 0, "and raise nothing")
end

-- A stack shows its count, and the same item merges into one line ----------------------------------------------
do
	local env, K, ns = New()
	Loot(env, "You receive loot: " .. CLOTH .. "x3")
	local line = ns.Feed.lines[1]
	assert(line.count:IsShown() and line.count:GetText() == "x3", "a stack of three shows x3")
	Loot(env, "You receive loot: " .. CLOTH)
	assert(#ns.Feed.lines == 1 and line.count:GetText() == "x4", "the same item merges: " .. tostring(line.count:GetText()))
	assert(K.ErrorCount() == 0)
end

-- The rim is the item's quality from uncommon up, and plain below it -----------------------------------------
do
	local env, K, ns = New()
	local rims = {}
	local Widgets = K.Widgets
	local make = Widgets.IconChrome
	Widgets.IconChrome = function(owner, opts)
		local chrome = make(owner, opts)
		local set = chrome.SetRim
		chrome.SetRim = function(self, r, g, b, a)
			rims[owner] = r and { r, g, b } or false
			return set(self, r, g, b, a)
		end
		return chrome
	end
	Loot(env, "You receive loot: " .. EPIC)
	Loot(env, "You receive loot: " .. VEST)
	local epic, vest = ns.Feed.lines[1], ns.Feed.lines[2]
	local r, g, b = K.Theme.QualityColor(5)
	local rim = rims[epic.tile]
	assert(rim and rim[1] == r and rim[2] == g and rim[3] == b, "an epic's tile has its quality rim")
	assert(rims[vest.tile] == false, "a common item's tile keeps the plain rim")
end

-- Item data that has not loaded: the line shows at once, then takes its quality when the client says so -------
do
	local env, K, ns = New()
	env._items[2589] = { icon = 132889, quality = 2, cached = false }
	Loot(env, "You receive loot: " .. CLOTH)
	local line = ns.Feed.lines[1]
	assert(#ns.Feed.lines == 1 and #Q.Calls(env, "RequestLoadItemDataByID") == 1 and Q.Calls(env, "RequestLoadItemDataByID")[1][1] == 2589, "the data is requested by item ID")
	assert(line.entry.quality == nil, "no quality is invented from the link's colour")
	env._items[2589].cached = true
	env.FireEvent("ITEM_DATA_LOAD_RESULT", 2589, true)
	assert(line.entry.quality == 2, "the load result paints the quality")
	env.FireEvent("ITEM_DATA_LOAD_RESULT", 999, true)
	assert(K.ErrorCount() == 0, "a result for another item is ignored")
end

-- Lines cap at the layout's count, the oldest leaving first, and each leaves after its hold -------------------
do
	local env, K, ns = New()
	local cap = K.Setup.Layouts.FEED_LINES
	assert(cap == 4, "four lines is the footprint's capacity")
	local links = { BUG_EYE, VEST, CLOTH, EPIC, OTHER }
	for i = 1, #links do
		Loot(env, "You receive loot: " .. links[i])
	end
	assert(#ns.Feed.lines == cap, "the feed holds at most " .. cap .. " lines")
	assert(Names(ns) == "Worn Leather Vest|Linen Cloth|Thunderfury|Rugged Hide", "the oldest made way: " .. Names(ns))
	assert(ns.Feed.lines[1]:GetAlpha() == 1 and ns.Feed.Backdrop():IsShown(), "lines and backdrop are showing")
	env.Release()
	Settle(env)
	assert(#ns.Feed.lines == 0, "every line leaves after its hold")
	assert(not ns.Feed.Backdrop():IsShown(), "and the backdrop leaves with the last one")
	Loot(env, "You receive loot: " .. BUG_EYE)
	assert(#ns.Feed.lines == 1 and ns.Feed.Backdrop():IsShown(), "a new line brings it back")
	assert(K.ErrorCount() == 0)
end

-- A new gain during the backdrop's fade-out keeps the backdrop, and a row that outlives an older one moves down -----
do
	local env, K, ns = New({ layout = true })
	Loot(env, "You receive loot: " .. BUG_EYE)
	env.Release()
	Loot(env, "You receive loot: " .. VEST)
	local backdrop = ns.Feed.Backdrop()
	assert(#ns.Feed.lines == 1 and backdrop:IsShown() and backdrop:GetAlpha() == 1, "loot during the fade-out keeps the backdrop: " .. tostring(backdrop:GetAlpha()))
	Settle(env)
	assert(#ns.Feed.lines == 1 and K.ErrorCount() == 0, "the new line is still live")
end

do
	local env, K, ns = New({ layout = true })
	local backdrop = ns.Feed.Backdrop()
	Loot(env, "You receive loot: " .. CLOTH)
	local before = #env._held
	Loot(env, "You receive loot: " .. EPIC)
	assert(#env._held == before + 1, "the epic's hold is the one new timer")
	local epicHold = env._held[#env._held]
	Loot(env, "You receive loot: " .. CLOTH)
	local cloth, epic = ns.Feed.lines[1], ns.Feed.lines[2]
	assert(#ns.Feed.lines == 2 and cloth.entry.id == 2589 and epic.entry.id == 19019 and cloth.entry.count == 2, "the older item merged and kept its row")
	local root = K.Scale.Root()
	env._held = {}
	epicHold()
	Settle(env)
	assert(#ns.Feed.lines == 1 and ns.Feed.lines[1] == cloth, "the newer row leaves first when the older one was refreshed")
	assert(cloth.y == 0, "the surviving row moved to the bottom slot: " .. tostring(cloth.y))
	local card, rect = assert(Geometry.Rect(backdrop, root)), assert(Geometry.Rect(cloth, root))
	assert(rect.left >= card.left and rect.right <= card.right + 0.01 and rect.bottom >= card.bottom - 0.01 and rect.top <= card.top + 0.01, "and it lies on the shrunken backdrop")
	assert(K.ErrorCount() == 0)
end

-- Money gains merge into one amount and never show a stack count ------------------------------------------------
do
	local env, K, ns = New()
	Money(env, "You loot 14 Copper")
	Money(env, "You loot 14 Copper")
	local coin = ns.Feed.lines[1]
	assert(#ns.Feed.lines == 1 and coin.name:GetText():find("28c") and not coin.count:IsShown(), "two copper gains read 28c with no x2")
	assert(K.ErrorCount() == 0)
end

-- The look of the chat card: its window glass with gold corner marks, its body text size, gilt plus marks ---------
do
	local env, K, ns = New()
	Loot(env, "You receive loot: " .. CLOTH .. "x2")
	local line, backdrop = ns.Feed.lines[1], ns.Feed.Backdrop()
	assert(backdrop.opts and backdrop.opts.shape == "window" and backdrop.chrome.shapeName == "window" and backdrop.chrome.shape.gilt == true, "the backdrop is the chat card's window panel, gold corner marks included")
	local path = K.Tokens.Font("body")
	local want = K.Widgets.FontSize(line.name, K.Tokens.Size("lootText"))
	for _, text in ipairs({ line.name, line.plus, line.count }) do
		local _, size = text:GetFont()
		assert(size == want, "the text is the lootText size " .. want .. ", got " .. tostring(size))
	end
	assert(line.name:GetFont() == path, "the name is in the body font the chat uses")
	assert(K.Tokens.Size("lootText") == 14, "the size is the chat's default body size")
	local r, g, b = line.plus:GetTextColor()
	local gr, gg, gb = K.Tokens.Color("gilt")
	assert(r == gr and g == gg and b == gb, "the plus mark is gilt, as the corner marks")
	assert(K.ErrorCount() == 0)
end

-- Geometry: inside the element's footprint, the backdrop hugs the lines, left edges line up -----------------------
do
	local env, K, ns = New({ layout = true })
	local links = { BUG_EYE, VEST, CLOTH, EPIC }
	for _, link in ipairs(links) do
		Loot(env, "You receive loot: " .. link)
	end
	local root = K.Scale.Root()
	local holder, backdrop = ns.Feed.Holder(), ns.Feed.Backdrop()
	local box = assert(Geometry.Rect(holder, root))
	local card = assert(Geometry.Rect(backdrop, root))
	assert(card.left >= box.left - 0.01 and card.right <= box.right + 0.01 and card.bottom >= box.bottom - 0.01 and card.top <= box.top + 0.01,
		"the backdrop of a full feed lies inside the footprint the layouts plan")
	for _, line in ipairs(ns.Feed.lines) do
		local rect = assert(Geometry.Rect(line, root))
		assert(rect.left >= card.left and rect.right <= card.right + 0.01 and rect.bottom >= card.bottom - 0.01 and rect.top <= card.top + 0.01,
			"each line lies on the backdrop")
	end
	local width, height = holder:GetSize()
	local planned, plannedHeight = K.Setup.Layouts.Footprint("DPS", "qol.lootfeed")
	assert(math.abs(width - planned) < 1 and math.abs(height - plannedHeight) < 1, "the holder is built at the footprint the layouts keep")
	local registered
	for _, entry in ipairs(env._layout) do
		if entry.key == "qol.lootfeed" then
			registered = entry
		end
	end
	assert(registered and registered.frame == holder and registered.opts.module == "QoL", "the feed registers with Layout under its key")
	assert(env._live["qol.lootfeed"] == true, "and is live while it runs")
	Q.Write(env, K, "lootFeed", false)
	assert(env._live["qol.lootfeed"] == false, "and not live while it is off")
end

-- The layouts: above the chat card on its left edge in every preset ------------------------------------------------
do
	local _, K = Q.New()
	local Layouts = K.Setup.Layouts
	local chat, feed
	for _, name in ipairs(Layouts.Names()) do
		local layout = Layouts.Get(name)
		chat, feed = layout["chat.main"], layout["qol.lootfeed"]
		assert(feed.anchor == chat.anchor and feed.x == chat.x, name .. ": the feed shares the chat card's left edge")
		local _, chatHeight = Layouts.Footprint(name, "chat.main")
		assert(feed.y >= chat.y + chatHeight, name .. ": the feed stands above the chat card")
	end
end

local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
for _, uiScale in ipairs({ 0.65, 768 / 1080, 1.15 }) do
	local env, K, ns = New({ fit = true, size = "default", uiScale = uiScale })
	env._textWidth = function(text, _, size) return #text * size * 0.53 end
	Loot(env, "You receive loot: " .. BUG_EYE)
	Loot(env, "You receive loot: " .. CLOTH .. "x3")
	Loot(env, "You receive loot: " .. EPIC)
	Money(env, "You loot 1 Gold, 4 Silver, 14 Copper")
	for _, screen in ipairs(screens) do
		env.GetPhysicalScreenSize = function() return screen[1], screen[2] end
		env.UIParent:SetSize(768 * screen[1] / screen[2] / uiScale, 768 / uiScale)
		env.FireEvent("DISPLAY_SIZE_CHANGED")
		for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
			K.Scale.SetUserScale(size)
			Settle(env)
			local root = K.Scale.Root()
			local px = root:GetEffectiveScale() * screen[2] / 768
			local where = string.format("feed %dx%d UI %.4f requested %.4f", screen[1], screen[2], uiScale, size)
			local function whole(value, label)
				assert(math.abs(value - math.floor(value + 0.5)) < 1e-6, where .. ": " .. label .. " is fractional: " .. value)
			end
			local holder = ns.Feed.Holder()
			local function edges(object, label)
				local rect = assert(Geometry.Rect(object, root), where .. ": " .. label .. " has no rect")
				for key, value in pairs(rect) do
					whole(value * px, label .. "." .. key)
				end
				return rect
			end
			local box = edges(holder, "holder")
			local card = edges(ns.Feed.Backdrop(), "backdrop")
			assert(card.left >= box.left - 1e-6 and card.right <= box.right + 1e-6 and card.bottom >= box.bottom - 1e-6 and card.top <= box.top + 1e-6, where .. ": backdrop fits the planned holder")
			assert(K.Setup.Layouts.Fits("DPS", screen[1], screen[2], K.Scale.AppliedUserScale()), where .. ": production cap includes the feed")
			assert(#ns.Feed.lines == K.Setup.Layouts.FEED_LINES, where .. ": all four rows remain live")
			for _, line in ipairs(ns.Feed.lines) do
				assert(not line.name:IsTruncated(), where .. ": a short name must fit its snapped text box: " .. line.name:GetText())
				whole(line.name:GetWidth() * px, "name width")
				edges(line, "line")
				edges(line.tile, "tile")
				edges(line.icon, "icon")
				for _, text in ipairs({ line.plus, line.name, line.count }) do
					local _, fontSize = text:GetFont()
					local k = text:GetEffectiveScale() * screen[2] / 768
					whole(fontSize * k, "font height")
					local x, y = text:GetShadowOffset()
					whole(x * k, "shadow x")
					whole(y * k, "shadow y")
				end
			end
			assert(K.ErrorCount() == 0 and #env._errors == 0, where .. ": no callback errors")
		end
	end
end

print("qol feed ok")
