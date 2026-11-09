-- test-databars-compact.lua: the readout card is one line by default (the micro menu and bag rows hidden, Blizzard's still hidden, the keybinds left alone), each row comes back from its setting and the card grows to fit, the layouts keep the rows' room clear, and older saved data keeps a bar its player had set up.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W
local CoreEnv = D.CoreEnv

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.5)
end

local function noErrors(env)
	eq(#env._errors, 0, "errors: " .. tostring(env._errors[1]))
end

local function row(K, key)
	return K.Options.Row("DataBars", key)
end

-- By default the card is the readout line alone ------------------------------------------------------------------

do
	local env, K, ns = D.New({ setup = D.Menus })
	env.RunTimers()
	local Strip, Menus, Layouts = ns.Strip, ns.Menus, K.Setup.Layouts
	local view = Strip.view
	local s = ns.Settings()
	eq(s.micro.shown, false, "the micro menu row is hidden by default")
	eq(s.bags.shown, false, "the bag row is hidden by default")
	eq(s.strip.menus, true, "the rows still dock in the card when shown")
	eq(#Menus.Shown("micro"), 0, "no micro button shows")
	eq(#Menus.Shown("bags"), 0, "no bag button shows")
	assert(not Menus.Content("micro"):IsShown() and not Menus.Content("bags"):IsShown(), "neither row draws")
	assert(not K.Layout.Live("databars.micro") and not K.Layout.Live("databars.bags"), "a hidden row has no plate in Layout Mode")
	-- Blizzard's bars stay hidden through Safe, so nothing returns to the bottom centre; the keybinds are Blizzard's own.
	eq(K.Safe.IsHidden(env.MicroMenuContainer), true, "Blizzard's micro menu stays hidden")
	eq(K.Safe.IsHidden(env.BagsBar), true, "Blizzard's bag bar stays hidden")
	-- The card hugs the line: its top padding is in the line, the bottom padding under it, the text centred.
	local compact = Strip.LINE + view.pad
	local h = view.frame:GetHeight()
	assert(near(h, compact), "the card is the readout line and its padding: " .. h .. " for " .. compact)
	assert(near(K.Layout.Get("databars.strip").height, compact), "Layout holds the same height, so the mover plate hugs it")
	eq(view.line, nil, "with no rows the items fill the card, so the line sits on its centre")
	eq(Layouts.Element("databars.strip").height, Strip.COMPACT, "the strip builds at the compact card's height")
	assert(near(Strip.COMPACT, compact), "and that height is the line and its padding: " .. tostring(Strip.COMPACT))
	for _, id in ipairs(ns.Strip.order) do
		local button = ns.Strip.view.items[id].button
		assert(near(button:GetHeight(), h), id .. " fills the card's height, so its text is centred")
	end

	-- Out of combat the strip still clicks through to Blizzard's buttons and shows its tooltips.
	local gold = ns.Strip.view.items.gold.button
	W.Enter(gold)
	local proxy = assert(ns.Click.proxy, "hovering gold readies the secure proxy")
	eq(proxy:GetAttribute("clickbutton1"), env.MainMenuBarBackpackButton, "gold opens Blizzard's bags")
	assert(K.Widgets.Tooltip():IsOwned(gold), "and shows its tooltip")
	W.Leave(proxy)
	W.Enter(ns.Strip.view.items.durability.button)
	eq(proxy:GetAttribute("clickbutton1"), env.CharacterMicroButton, "durability opens the character sheet")
	W.Leave(proxy)

	-- The settings: one toggle per row, each with help text.
	for _, id in ipairs({ "micro", "bags" }) do
		local r = assert(row(K, id .. ".shown"), id .. ".shown has a settings row")
		eq(r.type, "toggle", id .. ".shown is a toggle")
		assert(type(r.help) == "string" and r.help ~= "", id .. ".shown has help text")
	end

	-- The micro row back on: eight buttons under the line, and the card grows to hold them.
	K.Options.Write("DataBars", "micro.shown", true)
	env.RunTimers()
	eq(#Menus.Shown("micro"), 8, "the compact set returns")
	eq(#Menus.Shown("bags"), 0, "the bag row stays hidden")
	local gap = K.Widgets.Snap(view.frame, 6)
	local microH = Menus.Holder("micro"):GetHeight()
	eq(view.line, Strip.LINE, "with a row the line holds the card's top again")
	assert(near(view.frame:GetHeight(), Strip.LINE + gap + microH + view.pad), "the card holds the line and the micro row: " .. view.frame:GetHeight())
	assert(near(K.Layout.Get("databars.strip").height, view.frame:GetHeight()), "and Layout follows")
	assert(not K.Layout.Live("databars.micro"), "a docked row is not live")

	-- The bag row too: both rows, as before the change.
	K.Options.Write("DataBars", "bags.shown", true)
	env.RunTimers()
	eq(#Menus.Shown("bags"), 6, "the six bags return")
	local bagsH = Menus.Holder("bags"):GetHeight()
	local full = Strip.LINE + gap + microH + gap + bagsH + view.pad
	assert(near(view.frame:GetHeight(), full), "the card holds both rows: " .. view.frame:GetHeight() .. " for " .. full)
	local _, reserved = Layouts.Footprint("DPS", "databars.strip")
	assert(view.frame:GetHeight() <= reserved + 0.5, "the full card fits the room the layouts keep: " .. view.frame:GetHeight() .. " in " .. reserved)

	-- Off again: the card shrinks back to the line.
	K.Options.Write("DataBars", "micro.shown", false)
	K.Options.Write("DataBars", "bags.shown", false)
	env.RunTimers()
	assert(near(view.frame:GetHeight(), compact), "both rows off, the card is one line again: " .. view.frame:GetHeight())
	eq(#Menus.Shown("micro") + #Menus.Shown("bags"), 0, "and no button shows")
	eq(K.Safe.IsHidden(env.MicroMenuContainer), true, "Blizzard's micro menu is still hidden")

	-- Free of the card, a hidden row is not live either; shown, it is its own element again.
	K.Options.Write("DataBars", "strip.menus", false)
	env.RunTimers()
	assert(not K.Layout.Live("databars.micro") and not K.Layout.Live("databars.bags"), "free but hidden rows have no plate")
	assert(not Menus.Content("micro"):IsShown(), "and draw nothing")
	K.Options.Write("DataBars", "micro.shown", true)
	env.RunTimers()
	assert(K.Layout.Live("databars.micro") and Menus.Content("micro"):IsShown(), "a free row shown is live and draws")
	assert(not K.Layout.Live("databars.bags"), "the hidden bag row stays out of Layout Mode")
	K.Options.Write("DataBars", "micro.shown", false)
	K.Options.Write("DataBars", "strip.menus", true)
	env.RunTimers()
	assert(near(view.frame:GetHeight(), compact), "docked and hidden, one line")
	noErrors(env)
end

-- A row turned on in combat: the card holds its size until combat ends (its docked secure buttons make it protected) --

do
	local env, K, ns = D.New({ setup = D.Menus })
	env.RunTimers()
	local view = ns.Strip.view
	local before = view.frame:GetHeight()
	local SECURE = { SetHeight = true, SetSize = true, SetWidth = true, SetPoint = true, ClearAllPoints = true, SetAllPoints = true }
	local mark = #view.frame._calls
	env.SetCombat(true)
	K.Options.Write("DataBars", "micro.shown", true)
	K.Options.Write("DataBars", "bags.shown", true)
	env.RunTimers()
	for n = mark + 1, #view.frame._calls do
		assert(not SECURE[view.frame._calls[n].method], "the card's " .. view.frame._calls[n].method .. " waits for combat to end")
	end
	assert(near(view.frame:GetHeight(), before), "in combat the card keeps its line: " .. view.frame:GetHeight())
	env.SetCombat(false)
	env.RunTimers()
	assert(view.frame:GetHeight() > before + 40, "after combat it grows to hold the rows: " .. view.frame:GetHeight())
	eq(#ns.Menus.Shown("micro"), 8, "and the micro buttons show")
	noErrors(env)
end

-- The layouts keep the rows' room on the right rail's foot, so turning them on moves nothing -----------------------

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	local element = Layouts.Element("databars.strip")
	local reserves = {}
	for _, entry in ipairs(Layouts.Reserves()) do
		reserves[entry.key] = entry
	end
	local reserve = assert(reserves["databars.strip"], "the readout card reserves the room its rows take")
	eq(reserve.width, element.width, "the reserve is as wide as the card")
	assert(reserve.height > element.height, "and taller than the one-line card: " .. reserve.height .. " over " .. element.height)
	for _, name in ipairs(Layouts.Names()) do
		local w, h = Layouts.Footprint(name, "databars.strip")
		eq(w .. "x" .. h, reserve.width .. "x" .. reserve.height, name .. " keeps the full card's room")
	end
end

-- Saved data from before: a bar its player set up stays shown; an untouched one takes the new default --------------

do
	local saved = {
		version = 3,
		profiles = {
			Default = { DataBars = { enabled = true, micro = { enabled = true, size = 26, spacing = 4, rows = 1, backdrop = true, tint = "none", shape = "round", set = "compact" }, bags = { enabled = true, size = 26, spacing = 4, rows = 1, backdrop = true, freeSlots = true, shape = "round" }, strip = { menus = true } } },
			Tuned = { DataBars = { micro = { enabled = true, size = 30, set = "compact" }, bags = { enabled = true, shape = "tile" } } },
			Free = { DataBars = { strip = { menus = false }, micro = { enabled = true }, bags = { enabled = true } } },
			Sparse = { DataBars = { strip = { menus = false } } },
			SparseBlizzard = { DataBars = { strip = { menus = false }, micro = { enabled = false } } },
			Chosen = { DataBars = { micro = { shown = false, size = 40 } } },
			Blizzard = { DataBars = { micro = { enabled = false, size = 30 } } },
			Empty = {},
		},
	}
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	local profiles = env.KstyleUIDB.profiles
	eq(env.KstyleUIDB.version, K.Store.DB_VERSION, "the saved data is upgraded")
	eq(profiles.Default.DataBars.micro.shown, nil, "an untouched micro menu takes the new default")
	eq(profiles.Default.DataBars.bags.shown, nil, "an untouched bag bar takes the new default")
	eq(profiles.Tuned.DataBars.micro.shown, true, "a resized micro menu stays shown")
	eq(profiles.Tuned.DataBars.bags.shown, true, "a reshaped bag bar stays shown")
	eq(profiles.Free.DataBars.micro.shown, true, "bars set free of the card stay shown")
	eq(profiles.Free.DataBars.bags.shown, true, "both of them")
	eq(profiles.Sparse.DataBars.micro and profiles.Sparse.DataBars.micro.shown, true, "free bars saved with every other setting at its default stay shown")
	eq(profiles.Sparse.DataBars.bags and profiles.Sparse.DataBars.bags.shown, true, "the bag bar too")
	eq(profiles.SparseBlizzard.DataBars.micro.shown, nil, "a free bar handed back to Blizzard is left alone")
	eq(profiles.SparseBlizzard.DataBars.bags.shown, true, "while its free bag bar stays shown")
	eq(profiles.Chosen.DataBars.micro.shown, false, "a saved choice is never overwritten")
	eq(profiles.Blizzard.DataBars.micro.shown, nil, "a bar handed back to Blizzard is left alone")
	eq(profiles.Empty.DataBars, nil, "a profile without DataBars gets nothing")
	noErrors(env)
end

-- A fresh profile through the module: hidden ----------------------------------------------------------------------

do
	local env, K = D.New({ setup = D.Menus, saved = { version = 3, profiles = { Default = { DataBars = { enabled = true, micro = { size = 30 } } } } } })
	env.RunTimers()
	eq(K.Options.Read("DataBars", "micro.shown"), true, "a migrated profile's tuned micro menu shows")
	eq(K.Options.Read("DataBars", "bags.shown"), false, "and its untouched bag row is hidden")
	noErrors(env)
end

print("databars compact ok")
