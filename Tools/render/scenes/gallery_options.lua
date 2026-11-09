-- gallery_options.lua: the settings window in five states, each its own environment merged into one scene: the
-- real Unit Frames page (KstyleUI_UnitFrames loaded as the game loads it, its schema of some 150 rows for the
-- frame the picker holds, the rail listing the page's sections, the live preview on the sigil), a search for
-- "cast bar" across every frame's rows, the Profiles page, the General page at its top (the Appearance section)
-- and scrolled to the Widgets section, plus the canvas the core registers in Blizzard's Settings panel. One
-- 1040 by 680 window fits the 1671 by 1080 screen at scale 1, so the four secondary states are the window at
-- its minimum size (880 by 520) scaled to 0.65 through the Layout service, as a player could set it.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local O = dofile("Tools/regression/options_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W

local WINDOW_KEY = "Options.Window"
local SMALL_W, SMALL_H, SMALL_SCALE = 880, 520, 0.65
local MAIN = { x = 16, y = 16 }
local SEARCH = { x = 1083, y = 16 }
local PROFILES = { x = 1083, y = 372 }
local APPEARANCE = { x = 16, y = 724 }
local WIDGETS = { x = 604, y = 724 }
local ENTRY = { x = 1190, y = 724, w = 465, h = 330 }

local SAMPLE_FONT = "SourceSans3Semibold"
local SEARCH_QUERY = "cast bar"

-- The settings addon loads on demand, as C_AddOns.LoadAddOn loads it in the game.
local function loadsOptions(env)
	env.C_AddOns = env.C_AddOns or {}
	env.C_AddOns.LoadAddOn = function(name)
		if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then
			Load(O.Files(), env)
		end
		return true
	end
end

-- Build one environment with the settings window open on a page, at the owner's screen. With `unitFrames` the
-- real Unit Frames module is on, its picker on the Target frame (the sigil, whose preview fits the pane; the
-- player vitals line's name runs past the pane's left edge, KstyleUI_UnitFrames/Preview.lua). The states that
-- show no module page boot the core alone, so test-render-scenes-gallery stays within its memory budget.
local function build(page, unitFrames, setup)
	local opts = Common.ScreenOpts({
		saved = Gallery.Saved(unitFrames and { UnitFrames = {} } or {}),
		setup = function(env)
			Gallery.Setup(env)
			loadsOptions(env)
			if setup then
				setup(env)
			end
		end,
	})
	local env, K
	if unitFrames then
		env, K = U.New(opts)
		assert(K.Options.Get("UnitFrames"), "KstyleUI_UnitFrames registered its schema")
		K.Options.Write("UnitFrames", "edit", "target")
	else
		env, K = O.New(opts)
	end
	assert(K.Layout and K.Layout.Set, "the core's Layout service loaded")
	assert(K.Options.Open(page) == true, "the window opens on " .. page)
	env.RunTimers()
	W.Settle(env)
	return env, K, env._addons.KstyleUI_Options
end

local function settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

-- The real module's frames on the HUD (the player frame, its cast bar and class resource) are not this scene's
-- subject and would show through the other states' windows, so each state hides them before it builds.
local function hideHud(K)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.module == "UnitFrames" then
			local el = K.Layout.Element(element.key)
			if el and el.frame then
				el.frame:Hide()
			end
		end
	end
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
		if row.entry and row.entry.label == label and row:IsShown() then
			return row
		end
	end
	error("no rail row labelled " .. label)
end

local function count(items, fn)
	local n = 0
	for _, item in ipairs(items) do
		if fn(item) then
			n = n + 1
		end
	end
	return n
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

	-- The main state: the real Unit Frames page at scale 1, the "Target: cast bar" section row of the rail under
	-- the mouse.
	local entry
	local env, K, ns = build("UnitFrames", true, function(env)
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
	local state = ns.Window.State()
	local rows = count(state.items, function(item)
		return item.kind ~= "header" and item.kind ~= "note"
	end)
	assert(rows >= 90, "the Target frame alone offers 90 or more settings, got " .. rows)
	local sections = {}
	for _, section in ipairs(state.sections) do
		sections[#sections + 1] = section.label
	end
	assert(sections[1] == "Unit Frames" and sections[2] == "Customise" and sections[3] == "Target: frame", "the page's sections start with the module, the picker and the frame: " .. table.concat(sections, "|"))
	local hover = {}
	local hovered = railRow(ns, "Target: cast bar")
	W.Enter(hovered)
	hover[hovered] = true
	Gallery.Ticks(W, env, 40)
	settle(env)
	frames:Add(env, win, {
		name = "options_window", title = "Settings window", grade = "window", reference = "chat",
		caption = "The settings window on the real Unit Frames page: header with logo, spaced title, search field and close glyph; the rail with Unit Frames selected and its sections listed under it (Customise, then the Target frame's frame, health bar, power bar, text, icons, cast bar and auras, and Positions and sizes), the cast bar section under the mouse; the rows from the module's own schema, over 90 settings for the frame the picker holds; the live preview on the sigil; Layout Mode and Reset. Window grade.",
		match = "Surface fill, the dark outer and light inner line, the 12-unit window chamfer and the drop shadow, as the mockup's chat panel; before this branch the window took the 8-unit panel chamfer because it passed no title to Widgets.Panel.",
	})
	frames:Add(env, parts.rail, {
		name = "options_rail", title = "Category rail", grade = "window", reference = "chat",
		caption = "The rail: one row per page on the window's glass, the selected page with a 2-unit accent bar and an accent wash fading to the right, and under it the page's sections as shorter indented rows, the section on screen marked with a 2-unit accent tick; the hovered section lit by a 5% white wash and brighter text. A click on a section scrolls the rows so its header sits at the top.",
		match = "The rail draws no chrome of its own; the glass behind it is the window's, so the fill and grain match the chat panel. The bar, tick and washes are the kit's selection marks, which the mockup has only on its chat tabs (an accent underline).",
	})
	frames:Add(env, parts.content, {
		name = "options_rows", title = "Option rows", grade = "window", reference = "chat",
		caption = "The content list on the window's glass: upper-case headers with a fading rule and 48-unit rows with a label, a help line and one control each, from the Unit Frames module's own schema: the module switch, Hide Blizzard's frames, the accent, the Frame to customise picker on Target, then the Target frame's rows (Show this frame, Style, Portrait, Portrait style, shape and side, Name, Level, the health bar's texture, colour, fill direction and text format, and on down through power, text fonts, icons, cast bar and auras).",
		match = "No backdrop of its own: the rows sit on the window glass as the mockup's chat lines sit on the chat panel; each control wears the button grade (body #101214, one-border light line) or the bar grade (toggle and slider tracks).",
	})
	frames:Add(env, parts.preview, {
		name = "options_preview", title = "Live preview pane", grade = "button", reference = "datastrip",
		caption = "The live preview pane: a tile on the button body with the edgeInner hairline, the Live preview caption over an accent rule, and the Unit Frames module's own preview inside: the target sigil with its sample values, level line, hostile pill, cast line and sample sockets, following every setting on the page.",
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
	hideHud(K)
	scenes[#scenes + 1] = Gallery.Build(env, { hover = hover })
	errorsOf(scenes[#scenes], env, K, "main")

	-- Search: the rows of every frame that match "cast bar", under their page and section headers, whichever
	-- frame the picker holds.
	do
		local env2, K2, ns2 = build("UnitFrames", true)
		place(K2, SEARCH, true)
		settle(env2)
		local parts2 = ns2.Window.Parts()
		parts2.search:SetText(SEARCH_QUERY)
		parts2.search:GetScript("OnTextChanged")(parts2.search, true)
		settle(env2)
		assert(ns2.Window.State().query == SEARCH_QUERY, "the search query is set")
		assert(parts2.clear:IsShown(), "the clear glyph shows while searching")
		local hits = {}
		for _, item in ipairs(ns2.Window.State().items) do
			if item.kind == "header" and item.level == 2 then
				hits[#hits + 1] = item.label
			end
		end
		assert(#hits >= 4, "the search finds the cast bar rows of the player, target, focus and boss frames: " .. table.concat(hits, "|"))
		frames:Add(env2, ns2.Window.Frame(), {
			name = "options_search", title = "Search results", grade = "window", reference = "chat",
			caption = "The window with \"cast bar\" typed in the search field: the rail shows no selection and lists no sections, the clear glyph shows in the field, and the rows list every match under its page and section (Player: cast bar, Target: cast bar, Focus: cast bar, Boss: cast bar), whichever frame the picker holds." .. SCALE_NOTE,
			match = "Window grade as the chat panel: surface fill, two-line edge, drop shadow; the search field wears the button body with the hairline.",
		})
		hideHud(K2)
		scenes[#scenes + 1] = Gallery.Build(env2)
		errorsOf(scenes[#scenes], env2, K2, "search")
	end

	-- Profiles: dropdowns, button rows and the character assignments.
	do
		local env3, K3, ns3 = build("Profiles", false)
		place(K3, PROFILES, true)
		settle(env3)
		frames:Add(env3, ns3.Window.Frame(), {
			name = "options_profiles", title = "Profiles page", grade = "window", reference = "chat",
			caption = "The Profiles page: the active profile dropdown, New, Copy from, Rename, Delete and Reset profile, the Share section with the Export and Import buttons, and the Characters section; the preview pane shows the placeholder logo and This page has no preview." .. SCALE_NOTE,
			match = "Window grade as the chat panel; the text buttons and dropdowns wear the button body with the one-border hairline, as the mockup's data strip pill.",
		})
		scenes[#scenes + 1] = Gallery.Build(env3)
		errorsOf(scenes[#scenes], env3, K3, "profiles")
	end

	-- General at its top: the core's Appearance schema (accent, text, size, motion) with the kit sample preview.
	do
		local env4, K4, ns4 = build("General", false)
		place(K4, APPEARANCE, true)
		settle(env4)
		local list = O.Labels(ns4.Window.State().items)
		assert(list[1] == "Accent" and list[2] == "Accent colour", "General starts with the Appearance rows: " .. table.concat(list, "|"))
		frames:Add(env4, ns4.Window.Frame(), {
			name = "options_appearance", title = "General page: Appearance", grade = "window", reference = "chat",
			caption = "The General page at its top: the core's Appearance schema (Accent colour dropdown, Font, Text size, Interface size and Motion) with the kit sample in the preview pane following them." .. SCALE_NOTE,
			match = "Window grade as the chat panel; the dropdowns and sliders on the rows wear the button and bar grades.",
		})
		scenes[#scenes + 1] = Gallery.Build(env4)
		errorsOf(scenes[#scenes], env4, K4, "appearance")
	end

	-- General scrolled to the Widgets schema: panel opacity, panel shadows, sounds and the tooltip size.
	do
		local env5, K5, ns5 = build("General", false)
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
		scenes[#scenes + 1] = Gallery.Build(env5)
		errorsOf(scenes[#scenes], env5, K5, "widgets")
	end

	local scene = Scene.Merge(scenes)
	return frames:Finish(scene, env, K, "gallery options")
end)
