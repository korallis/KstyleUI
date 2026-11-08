-- gallery_options.lua: the settings window in five states, each its own environment merged into one scene: a
-- stand-in module page with every row kind the schemas support (the rail hovered, the live preview showing the
-- kit sample), a search, the Profiles page, the General page at its top (the Appearance section) and scrolled
-- to the Widgets section, plus the canvas the core registers in Blizzard's Settings panel. One 1040 by 680
-- window fits the 1671 by 1080 screen at scale 1, so the four secondary states are the window at its minimum
-- size (880 by 520) scaled to 0.65 through the Layout service, as a player could set it.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local Module = W.CoreEnv.Module

local WINDOW_KEY = "Options.Window"
local SMALL_W, SMALL_H, SMALL_SCALE = 880, 520, 0.65
local MAIN = { x = 16, y = 16 }
local SEARCH = { x = 1083, y = 16 }
local PROFILES = { x = 1083, y = 372 }
local APPEARANCE = { x = 16, y = 724 }
local WIDGETS = { x = 604, y = 724 }
local ENTRY = { x = 1190, y = 724, w = 465, h = 330 }

local SAMPLE_FONT = "SourceSans3Semibold"

-- The stand-in modules every environment registers before the settings addon loads: Unit Frames with a schema
-- holding every row kind and a preview, and Minimap so the rail has pages to hover.
local function registerStandIns(env, K)
	K.Modules.Register(Module("UnitFrames", {
		defaults = {
			portraits = true, size = 24, style = "glass", colour = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3], a = 1 },
			label = "Valerin", font = (K.Tokens.FontPath(SAMPLE_FONT)), bar = K.Tokens.MediaList("statusbar")[1].path,
		},
	}))
	local schema = {
		{ type = "toggle", key = "portraits", label = "Show portraits", help = "Show a portrait on the player and target frames." },
		{ type = "slider", key = "size", label = "Portrait size", help = "The portrait's diameter in units.", min = 10, max = 40, step = 1 },
		{ type = "dropdown", key = "style", label = "Health bar style", help = "The look of the health and power fills.", options = {
			{ value = "solid", label = "Solid" }, { value = "glass", label = "Glass" }, { value = "flat", label = "Flat" },
		} },
		{ type = "color", key = "colour", label = "Ring colour", help = "The portrait ring, by default the class colour.", hasAlpha = true },
		{ type = "text", key = "label", label = "Frame label", help = "Text shown over the player frame.", maxLetters = 16 },
		{ type = "font", key = "font", label = "Frame font", help = "The face of the frame's name and values." },
		{ type = "texture", key = "bar", label = "Bar texture", help = "The status bar fill texture." },
	}
	schema.preview = function(parent)
		return env._addons.KstyleUI_Options.Preview.Sample(parent)
	end
	K.Options.Register("UnitFrames", schema)
	K.Modules.Register(Module("Minimap", { defaults = { zoneText = true } }))
	K.Options.Register("Minimap", {
		{ type = "toggle", key = "zoneText", label = "Zone text", help = "Show the zone name under the map." },
	})
end

-- Build one environment with the settings window open on a page, at the owner's screen.
local function build(page, setup)
	local env, K, ns = O.New(Common.ScreenOpts({
		saved = Gallery.Saved({ UnitFrames = {}, Minimap = {} }),
		setup = function(env)
			Gallery.Setup(env)
			if setup then
				setup(env)
			end
		end,
		before = registerStandIns,
	}))
	assert(K.Layout and K.Layout.Set, "the core's Layout service loaded")
	K.Layout.Register(env.CreateFrame("Frame", nil, K.Scale.Root()), "UnitFrames.Player", { anchor = "BOTTOM", x = -200, y = 260 }, {
		label = "Player frame", module = "UnitFrames", resizable = true, minWidth = 120, maxWidth = 400, minHeight = 30, maxHeight = 90,
	})
	assert(K.Options.Open(page) == true, "the window opens on " .. page)
	env.RunTimers()
	W.Settle(env)
	return env, K, ns
end

local function settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

-- Move the window to a top-left origin in screen units through Layout, and shrink and scale it when asked.
local function place(K, at, small)
	if small then
		assert(K.Layout.Set(WINDOW_KEY, "width", SMALL_W))
		assert(K.Layout.Set(WINDOW_KEY, "height", SMALL_H))
		assert(K.Layout.Set(WINDOW_KEY, "scale", SMALL_SCALE))
	end
	assert(K.Layout.Set(WINDOW_KEY, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(WINDOW_KEY, "x", at.x))
	assert(K.Layout.Set(WINDOW_KEY, "y", -at.y))
end

local function scrollTo(ns, label)
	local parts = ns.Window.Parts()
	local _, index = O.Find(ns.Window.State().items, function(item)
		return item.label == label
	end)
	assert(index, "no row labelled " .. label)
	parts.content:ScrollToIndex(index, true)
end

local function railRow(ns, label)
	for _, row in ipairs(ns.Window.Parts().rail.rows) do
		if row.page and row.page.label == label and row:IsShown() then
			return row
		end
	end
	error("no rail row labelled " .. label)
end

local function errorsOf(scene, env, K, what)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. what .. ": " .. err
	end
end

local SCALE_NOTE = " The window is at its minimum size and scaled to 0.65 so five states fit one screen, so its chamfer and lines read smaller than the main window's."

return Common.Run(function()
	local frames = Gallery.Frames()
	local scenes = {}

	-- The main state: the Unit Frames stand-in page at scale 1, the Minimap rail row under the mouse.
	local entry
	local env, K, ns = build("UnitFrames", function(env)
		env.Settings = {
			RegisterCanvasLayoutCategory = function(frame, name)
				entry = frame
				return { name = name }
			end,
			RegisterAddOnCategory = function() end,
		}
	end)
	place(K, MAIN)
	settle(env)
	local win = ns.Window.Frame()
	local parts = ns.Window.Parts()
	local hover = {}
	local hovered = railRow(ns, "Minimap")
	W.Enter(hovered)
	hover[hovered] = true
	Gallery.Ticks(W, env, 40)
	settle(env)
	frames:Add(env, win, {
		name = "options_window", title = "Settings window", grade = "window", reference = "chat",
		caption = "The settings window on a module page: header with logo, spaced title, search field and close glyph; the rail with Unit Frames selected and Minimap under the mouse; rows for every schema kind (toggle, slider, dropdown, colour, text, font, texture) and the element section; the live preview; Layout Mode and Reset. Window grade.",
		match = "Surface fill, the dark outer and light inner line, the 12-unit window chamfer and the drop shadow, as the mockup's chat panel; before this branch the window took the 8-unit panel chamfer because it passed no title to Widgets.Panel.",
	})
	frames:Add(env, parts.rail, {
		name = "options_rail", title = "Category rail", grade = "window", reference = "chat",
		caption = "The rail: one row per page on the window's glass, the selected page with a 2-unit accent bar and an accent wash fading to the right, the hovered page lit by a 5% white wash and brighter text.",
		match = "The rail draws no chrome of its own; the glass behind it is the window's, so the fill and grain match the chat panel. The bar and washes are the kit's selection marks, which the mockup has only on its chat tabs (an accent underline).",
	})
	frames:Add(env, parts.content, {
		name = "options_rows", title = "Option rows", grade = "window", reference = "chat",
		caption = "The content list on the window's glass: upper-case headers with a fading rule, a second-level header with an accent mark, and 48-unit rows with a label, a help line and one control each: toggle pill, slider, dropdown, colour swatch with its hex, edit box, font and texture pickers, and the element rows.",
		match = "No backdrop of its own: the rows sit on the window glass as the mockup's chat lines sit on the chat panel; each control wears the button grade (body #101214, one-border light line) or the bar grade (toggle and slider tracks).",
	})
	frames:Add(env, parts.preview, {
		name = "options_preview", title = "Live preview pane", grade = "button", reference = "datastrip",
		caption = "The live preview pane: a tile on the button body with the edgeInner hairline, the Live preview caption over an accent rule, and the kit sample inside (heading, body text, a status bar, a toggle, a slider and a primary button).",
		match = "Body #101214 with the one-border light line and the 3.5-unit tile chamfer, as the mockup's data strip pill; no shadow, because the pane sits inside the window glass. It moved from the kit's raised tone to buttonFill on this branch.",
	})

	-- The Settings panel canvas the core registers: its content built on show, placed by the scene.
	assert(entry, "the core registered a canvas category in the Settings panel")
	entry:SetParent(K.Scale.Root())
	entry:ClearAllPoints()
	entry:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", ENTRY.x, -ENTRY.y)
	entry:SetSize(ENTRY.w, ENTRY.h)
	entry:Show()
	entry:GetScript("OnShow")(entry)
	-- The stub's GetUnboundedStringWidth returns nothing, so an auto-width button takes the kit's fallback width,
	-- 84 units, narrower than this label; the game sizes it to the text. The scene sizes it as the game would.
	local open = entry.openButton
	open.opts.width = Scene.TextWidth(open:GetText(), K.Tokens.Size("body"), (K.Tokens.FontPath(SAMPLE_FONT))) + 2 * K.Tokens.Size("gapLarge")
	open:Restyle()
	frames:Add(env, entry, {
		name = "options_entry", title = "Settings panel canvas", grade = "button", reference = "datastrip",
		caption = "The canvas the core registers in Blizzard's Settings panel: the logo, the KSTYLEUI display title, one line of body text, the primary Open KstyleUI settings button and the /kstyle hint. The canvas itself has no backdrop; in the game Blizzard's Settings panel is behind it, here the plate.",
		match = "Only the button has chrome: body #101214, the accent hairline of a primary button, the tile chamfer, as the mockup's data strip pill. Nothing else on the canvas is a backdrop.",
	})
	scenes[#scenes + 1] = Scene.Build(env, { hover = hover })
	errorsOf(scenes[#scenes], env, K, "main")

	-- Search: the rows of every page that match "size", under their page and section headers.
	do
		local env2, K2, ns2 = build("UnitFrames")
		place(K2, SEARCH, true)
		settle(env2)
		local parts2 = ns2.Window.Parts()
		parts2.search:SetText("size")
		parts2.search:GetScript("OnTextChanged")(parts2.search, true)
		settle(env2)
		assert(ns2.Window.State().query == "size", "the search query is set")
		assert(parts2.clear:IsShown(), "the clear glyph shows while searching")
		frames:Add(env2, ns2.Window.Frame(), {
			name = "options_search", title = "Search results", grade = "window", reference = "chat",
			caption = "The window with \"size\" typed in the search field: the rail shows no selection, the clear glyph shows in the field, and the rows list every match across the pages under their page and section headers." .. SCALE_NOTE,
			match = "Window grade as the chat panel: surface fill, two-line edge, drop shadow; the search field wears the button body with the hairline.",
		})
		scenes[#scenes + 1] = Scene.Build(env2)
		errorsOf(scenes[#scenes], env2, K2, "search")
	end

	-- Profiles: dropdowns, button rows and the character assignments.
	do
		local env3, K3, ns3 = build("Profiles")
		place(K3, PROFILES, true)
		settle(env3)
		frames:Add(env3, ns3.Window.Frame(), {
			name = "options_profiles", title = "Profiles page", grade = "window", reference = "chat",
			caption = "The Profiles page: the active profile dropdown, New, Copy from, Rename, Delete and Reset profile, the Share section with the Export and Import buttons, and the Characters section; the preview pane shows the placeholder logo and This page has no preview." .. SCALE_NOTE,
			match = "Window grade as the chat panel; the text buttons and dropdowns wear the button body with the one-border hairline, as the mockup's data strip pill.",
		})
		scenes[#scenes + 1] = Scene.Build(env3)
		errorsOf(scenes[#scenes], env3, K3, "profiles")
	end

	-- General at its top: the core's Appearance schema (accent, text, size, motion) with the kit sample preview.
	do
		local env4, K4, ns4 = build("General")
		place(K4, APPEARANCE, true)
		settle(env4)
		local list = O.Labels(ns4.Window.State().items)
		assert(list[1] == "Accent" and list[2] == "Accent colour", "General starts with the Appearance rows: " .. table.concat(list, "|"))
		frames:Add(env4, ns4.Window.Frame(), {
			name = "options_appearance", title = "General page: Appearance", grade = "window", reference = "chat",
			caption = "The General page at its top: the core's Appearance schema (Accent colour dropdown, Font, Text size, Interface size and Motion) with the kit sample in the preview pane following them." .. SCALE_NOTE,
			match = "Window grade as the chat panel; the dropdowns and sliders on the rows wear the button and bar grades.",
		})
		scenes[#scenes + 1] = Scene.Build(env4)
		errorsOf(scenes[#scenes], env4, K4, "appearance")
	end

	-- General scrolled to the Widgets schema: panel opacity, panel shadows, sounds and the tooltip size.
	do
		local env5, K5, ns5 = build("General")
		place(K5, WIDGETS, true)
		settle(env5)
		scrollTo(ns5, "Tooltip size")
		settle(env5)
		local list = O.Labels(ns5.Window.State().items)
		local found = false
		for _, label in ipairs(list) do
			found = found or label == "Panel opacity"
		end
		assert(found, "General lists the Widgets rows: " .. table.concat(list, "|"))
		frames:Add(env5, ns5.Window.Frame(), {
			name = "options_widgets_page", title = "General page: Widgets", grade = "window", reference = "chat",
			caption = "The General page scrolled to the core's Widgets schema: the Glass section (Panel opacity slider, Panel shadows toggle), Feedback (Interface sounds) and Tooltips (Tooltip size), with the scroll bar's thumb low in its track." .. SCALE_NOTE,
			match = "Window grade as the chat panel; the slider and toggle tracks wear the bar grade's surface fill with a faint line.",
		})
		scenes[#scenes + 1] = Scene.Build(env5)
		errorsOf(scenes[#scenes], env5, K5, "widgets")
	end

	local scene = Scene.Merge(scenes)
	return frames:Finish(scene, env, K, "gallery options")
end)
