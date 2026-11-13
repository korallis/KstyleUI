-- test-layout-ultrawide.lua: the ultrawide layouts (KSTY-59). The layout class is the HUD's own shape, read at login and on a display change and never in combat; Centred keeps the HUD in the HUD width's centred column and Spread gives the side columns the screen edges while the centre cluster stays put; a class's places move only elements at their defaults, a placement is saved whole so a class never moves it, migration 30 makes old partial placements whole, and a class change re-places Blizzard's viewers that Apply put.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function New(width, height, saved)
	local env, K = CoreEnv.New({
		width = width, height = height, uiScale = 768 / 1080, size = "auto", fit = true, saved = saved,
		setup = function(e)
			e._physical = { width, height }
			e.GetPhysicalScreenSize = function()
				return e._physical[1], e._physical[2]
			end
		end,
	})
	CoreEnv.Boot(env)
	local function Element(key)
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		local element = K.Setup.Layouts.Element(key)
		frame:SetSize(element.width, element.height)
		K.Layout.Register(frame, key, K.Setup.Layouts.Default(key), { label = key })
		return frame
	end
	return env, K, Element
end

local function Screen(env, width, height)
	env._physical = { width, height }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
end

-- Physical(K, key) -> the element's left edge and centre in physical pixels from the screen's left edge.
local function Physical(K, key)
	local left, _, width = K.Layout.Rect(key)
	local pixel = K.Scale.Pixel(1)
	return (K.Scale.Origin() + left) / pixel, (K.Scale.Origin() + left + width / 2) / pixel
end

-- The class is the HUD root's shape: the HUD width's column under Centred, the whole screen under Spread.
local CLASSES = {
	{ 1920, 1080, "16:9", "16:9" }, { 2560, 1600, "16:9", "16:9" }, { 3456, 2234, "16:9", "16:9" }, { 1280, 720, "16:9", "16:9" },
	{ 2560, 1080, "21:9", "21:9" }, { 3440, 1440, "21:9", "21:9" },
	{ 3840, 1080, "21:9", "32:9" }, { 5120, 1440, "21:9", "32:9" },
}
for _, case in ipairs(CLASSES) do
	local width, height, centred, spread = case[1], case[2], case[3], case[4]
	local name = width .. "x" .. height
	local env, K = New(width, height)
	local Scale, Layout = K.Scale, K.Layout
	assert(Layout.Setting("arrangement") == "centred", name .. ": Centred is the default arrangement")
	assert(Scale.Aspect() == centred, name .. ": Centred lays out the " .. centred .. " class, got " .. Scale.Aspect())
	local rw, rh = Layout.RootSize()
	assert(near(rw / rh, math.min(width / height, 12 / 5), 0.01), name .. ": Centred keeps the HUD in the 21:9 column")
	K.Options.Write("Layout", "arrangement", "spread")
	assert(Scale.Aspect() == spread, name .. ": Spread lays out the " .. spread .. " class, got " .. Scale.Aspect())
	rw, rh = Layout.RootSize()
	assert(near(rw / rh, width / height, 0.01) and near(Scale.Origin(), 0), name .. ": Spread gives the HUD the whole screen")
	K.Options.Write("Layout", "arrangement", "centred")
	assert(Scale.Aspect() == centred, name .. ": Centred again")
	assert(#env._errors == 0, name .. ": " .. tostring(env._errors[1]))
end

-- The HUD width still picks the column: 16:9 at 5120x1440 lays out the 16:9 class, Full width the 32:9 class.
do
	local _, K = New(5120, 1440)
	K.Options.Write("Layout", "canvas", "16:9")
	assert(K.Scale.Aspect() == "16:9", "a 16:9 HUD width lays out the 16:9 class")
	K.Options.Write("Layout", "canvas", "full")
	assert(K.Scale.Aspect() == "32:9", "Full width lays out the 32:9 class")
	assert(K.Scale.AspectClass(2560, 1080) == "21:9" and K.Scale.AspectClass(1920, 1200) == "16:9" and K.Scale.AspectClass(3840, 1080) == "32:9")
	assert(K.Scale.AspectClass(0, 1080) == "16:9", "an unreadable width is the 16:9 class")
end

-- A display change picks the class again, out of combat; in combat it waits for combat to end.
do
	local env, K = New(1920, 1080)
	local Scale = K.Scale
	K.Options.Write("Layout", "arrangement", "spread")
	assert(Scale.Aspect() == "16:9")
	Screen(env, 5120, 1440)
	assert(Scale.Aspect() == "32:9", "moving the game to an ultrawide picks the 32:9 class")
	env.SetCombat(true)
	Screen(env, 1920, 1080)
	env.RunTimers()
	assert(Scale.Aspect() == "32:9", "a display change in combat keeps the class until combat ends")
	env.SetCombat(false)
	assert(Scale.Aspect() == "16:9", "leaving combat picks the class for the new screen")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Spread: the side columns go to fixed margins from the screen edges, and the centre cluster stays put.
do
	local env, K, Element = New(5120, 1440)
	Element("chat.main")
	Element("minimap.main")
	Element("unitframes.player")
	Element("actionbars.bar1")
	local margin = K.Tokens.Size("screenMargin")
	local chatLeft = Physical(K, "chat.main")
	local _, playerCentre = Physical(K, "unitframes.player")
	local _, barCentre = Physical(K, "actionbars.bar1")
	local column = (5120 - 3456) / 2
	assert(near(chatLeft, column + margin, 0.5), "Centred: chat sits a margin inside the 21:9 column, got " .. chatLeft)
	local mapLeft = Physical(K, "minimap.main")
	K.Options.Write("Layout", "arrangement", "spread")
	assert(near(Physical(K, "chat.main"), margin, 0.5), "Spread: chat sits a margin from the screen's left edge")
	assert(near(Physical(K, "minimap.main"), mapLeft + column, 0.5), "Spread: the map moves out to the screen's right edge")
	local _, playerNow = Physical(K, "unitframes.player")
	local _, barNow = Physical(K, "actionbars.bar1")
	assert(near(playerNow, playerCentre, 0.5) and near(barNow, barCentre, 0.5), "Spread: the centre cluster stays put")
	assert(near(playerCentre, 2560, 0.5), "the centre cluster is centred on the screen")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Spread keeps the party, raid and boss frames on the 21:9 column's line, and only the rails go to the screen edges
-- (the Captain's ruling on KSTY-60 item 6: on a 32:9 screen a healer's party had gone to the far corner, 2,400 px
-- from the character). On another screen of the same class they keep to that screen's column, and nothing is saved.
do
	local env, K, Element = New(5120, 1440)
	local GROUP = { "groupframes.party", "groupframes.raid", "unitframes.boss" }
	for _, key in ipairs(GROUP) do
		Element(key)
	end
	Element("chat.main")
	local function Edges(key)
		local left, _, width = K.Layout.Rect(key)
		local pixel = K.Scale.Pixel(1)
		return (K.Scale.Origin() + left) / pixel, (K.Scale.Origin() + left + width) / pixel
	end
	for _, screen in ipairs({ { 5120, 1440 }, { 3840, 1080 } }) do
		local label = screen[1] .. "x" .. screen[2]
		Screen(env, screen[1], screen[2])
		K.Options.Write("Layout", "arrangement", "centred")
		local centred = {}
		for _, key in ipairs(GROUP) do
			centred[key] = { Edges(key) }
		end
		K.Options.Write("Layout", "arrangement", "spread")
		local column = (screen[1] - math.floor(screen[2] * 12 / 5 + 0.5)) / 2
		assert(near(Edges("chat.main"), K.Tokens.Size("screenMargin") / K.Scale.Pixel(1), 0.5), label .. ": Spread takes chat out to a margin from the screen's left edge")
		for _, key in ipairs(GROUP) do
			local left, right = Edges(key)
			assert(near(left, centred[key][1], 0.5) and near(right, centred[key][2], 0.5), label .. ": " .. key .. " stays on the 21:9 column's line under Spread, got " .. left .. " for " .. centred[key][1])
			assert(K.Store.Layout()[key] == nil, label .. ": and nothing is saved for it")
		end
		assert(near(K.Scale.Band() / K.Scale.Pixel(1), column, 0.5), label .. ": the band is the 21:9 column's inset, " .. column .. " px")
		K.Options.Write("Layout", "canvas", "16:9")
		local narrow = (screen[1] - math.floor(screen[2] * 16 / 9 + 0.5)) / 2
		assert(near(Edges("groupframes.party") - centred["groupframes.party"][1], narrow - column, 0.5), label .. ": a HUD width change under Spread moves the group frames to the new column's line")
		K.Options.Write("Layout", "canvas", "21:9")
		assert(near(Edges("groupframes.party"), centred["groupframes.party"][1], 0.5), label .. ": and back")
		assert(K.Setup.Apply({ layout = "Healer", modules = {} }), label .. ": Apply runs under Spread")
		for _, key in ipairs(GROUP) do
			local left = Edges(key)
			assert(near(left, centred[key][1], 0.5) and K.Store.Layout()[key] == nil, label .. ": after Apply " .. key .. " still keeps to the column's line and nothing is saved, got " .. left)
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A class's places move an element at its defaults and never one the player placed, whose place is saved whole.
do
	local env, K, Element = New(5120, 1440)
	local Layouts, Layout = K.Setup.Layouts, K.Layout
	Layouts.PLACES["32:9"].frames["chat.main"] = { anchor = "BOTTOMLEFT", x = 120, y = 40 }
	Layouts.PLACES["32:9"].frames["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 999 }
	Element("chat.main")
	Element("unitframes.player")
	local default = Layouts.Default("unitframes.player")
	assert(Layout.Set("unitframes.player", "x", 50), "the player drags the player frame sideways")
	local saved = K.Store.Layout()["unitframes.player"]
	assert(saved.anchor == default.anchor and saved.x == 50 and near(saved.y, default.y), "a drag saves the whole place, the untouched y included")
	local fired = {}
	K.Callbacks.Register("LayoutChanged", "test", function(_, key)
		fired[key] = true
	end)
	K.Options.Write("Layout", "arrangement", "spread")
	local chat, player = Layout.Get("chat.main"), Layout.Get("unitframes.player")
	assert(chat.anchor == "BOTTOMLEFT" and chat.x == 120 and chat.y == 40, "chat, at its default, takes the 32:9 place")
	assert(fired["chat.main"], "a class change fires LayoutChanged")
	assert(player.anchor == default.anchor and player.x == 50 and near(player.y, default.y), "the placed player frame never moves")
	assert(K.Store.Layout()["chat.main"] == nil, "nothing is saved for an element a class placed")
	K.Options.Write("Layout", "arrangement", "centred")
	assert(Layout.Get("chat.main").x == Layouts.Default("chat.main").x, "chat follows its class back")
	Screen(env, 3840, 1080)
	K.Options.Write("Layout", "arrangement", "spread")
	assert(Layout.Get("unitframes.player").x == 50 and near(Layout.Get("unitframes.player").y, default.y), "a display change never moves a placement either")
	assert(Layout.Set("unitframes.player", "x", Layout.Get("unitframes.player").x) and Layout.Reset("unitframes.player"), "Reset clears the placement")
	assert(near(Layout.Get("unitframes.player").y, 999) and K.Store.Layout()["unitframes.player"] == nil, "a reset element follows its class again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Apply on an ultrawide saves no positions for the elements it places: they sit at their class's defaults.
do
	local env, K, Element = New(5120, 1440)
	K.Setup.Layouts.PLACES["32:9"].frames["minimap.main"] = { anchor = "TOPRIGHT", x = -40, y = -60 }
	K.Options.Write("Layout", "arrangement", "spread")
	Element("chat.main")
	Element("minimap.main")
	assert(K.Setup.Apply(K.Setup.NewChoice()), "Apply runs")
	local stored = K.Store.Layout()
	for _, key in ipairs({ "chat.main", "minimap.main" }) do
		local entry = stored[key]
		assert(entry == nil or (entry.anchor == nil and entry.x == nil and entry.y == nil), key .. ": Apply saves no position at a class default")
	end
	assert(K.Layout.Get("minimap.main").x == -40, "the map stands at its 32:9 place")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Apply before an element registers (its module switches on with the reload) saves no place at the class default,
-- so after the reload the element follows its class; a place that is not the default is still saved for it.
do
	local _, K, Element = New(5120, 1440)
	local Layouts = K.Setup.Layouts
	Layouts.PLACES["32:9"].frames["chat.main"] = { anchor = "BOTTOMLEFT", x = 120, y = 40 }
	K.Options.Write("Layout", "arrangement", "spread")
	assert(K.Setup.Apply(K.Setup.NewChoice()), "Apply runs with nothing registered")
	local stored = K.Store.Layout()
	local chat = stored["chat.main"]
	assert(chat == nil or (chat.anchor == nil and chat.x == nil and chat.y == nil), "chat, unregistered, gets no saved place")
	Element("chat.main")
	assert(K.Layout.Get("chat.main").x == 120, "chat registers at its 32:9 place")
	K.Options.Write("Layout", "arrangement", "centred")
	assert(K.Layout.Get("chat.main").x == Layouts.Default("chat.main").x, "and follows its class back")
end

-- The arrangement chosen in combat applies when combat ends.
do
	local env, K = New(5120, 1440)
	env.SetCombat(true)
	K.Options.Write("Layout", "arrangement", "spread")
	assert(K.Scale.Aspect() == "21:9", "the arrangement waits for combat to end")
	env.SetCombat(false)
	assert(K.Scale.Aspect() == "32:9", "and applies when it ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Migration 30: a placement saved one field at a time is made whole against the default it was measured from.
do
	local _, K0 = New(1920, 1080)
	local Layouts = K0.Setup.Layouts
	local chat, cast = Layouts.Default("chat.main"), Layouts.Style("orbs", "DPS", "unitframes.castbar.player")
	local env, K = New(1920, 1080, {
		version = 29,
		profiles = { Default = { Layout = { preset = "DPS" } } },
		layouts = { Default = {
			["chat.main"] = { x = 60, alphaIdle = 0.5 },
			["orbs:unitframes.castbar.player"] = { y = 400 },
			["minimap.main"] = { anchor = "TOPLEFT", x = 10, y = -10 },
			["meters.damage"] = { width = 300 },
			["Options.Window"] = { x = 5 },
		} },
	})
	local layout = env.KstyleUIDB.layouts.Default
	assert(env.KstyleUIDB.version >= 30, "the saved data reaches version 30")
	local c = layout["chat.main"]
	assert(c.anchor == chat.anchor and c.x == 60 and near(c.y, chat.y) and c.alphaIdle == 0.5, "a partial chat placement is made whole")
	local o = layout["orbs:unitframes.castbar.player"]
	assert(o.anchor == cast.anchor and near(o.x, cast.x) and o.y == 400, "a partial Orbs placement is made whole against the Orbs default")
	local m = layout["minimap.main"]
	assert(m.anchor == "TOPLEFT" and m.x == 10 and m.y == -10, "a whole placement is unchanged")
	assert(layout["meters.damage"].width == 300 and layout["meters.damage"].anchor == nil, "a size alone stays a size")
	assert(layout["Options.Window"].x == 5 and layout["Options.Window"].anchor == nil, "a window Layouts does not place is left alone")
	assert(#env._errors == 0 and K.Store.DB_VERSION >= 30, tostring(env._errors[1]))
end

-- A class change re-places the Blizzard viewers Apply put in the active KstyleUI Edit Mode layout, out of combat.
do
	local env, K = New(5120, 1440)
	local EditMode = K.Setup.EditMode
	local restyled = {}
	EditMode.ActiveName = function()
		return "DPS"
	end
	EditMode.Restyle = function(name)
		restyled[#restyled + 1] = name
		return true
	end
	K.Options.Write("Layout", "arrangement", "spread")
	assert(#restyled == 1 and restyled[1] == "DPS", "Spread re-places Apply's viewers for the new class")
	K.Options.Write("Layout", "arrangement", "spread")
	assert(#restyled == 1, "no class change, no re-place")
	env.SetCombat(true)
	Screen(env, 1920, 1080)
	assert(#restyled == 1, "nothing moves in combat")
	env.SetCombat(false)
	assert(#restyled == 2, "the re-place runs when combat ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("layout ultrawide ok")
