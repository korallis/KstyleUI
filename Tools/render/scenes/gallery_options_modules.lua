-- gallery_options_modules.lua: the settings window on two more module pages, each the real module loaded as
-- the game loads it so its own schema fills the page: Party and Raid at scale 1, jumped to its Debuffs section
-- from the rail (the header at the top of the rows, the section marked in the rail), and Nameplates at the
-- window's minimum size scaled to 0.65, as gallery_options.lua draws its secondary states. Together with
-- gallery_options.lua this shows the depth a player can reach from the window. Two states, not more, keep
-- test-render-scenes-gallery within its time budget.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W

local WINDOW_KEY = "Options.Window"
local SMALL_W, SMALL_H, SMALL_SCALE = 880, 520, 0.65
local MAIN = { x = 16, y = 16 }
local NAMEPLATES = { x = 1083, y = 16 }
-- The Debuffs section, looked up by its string key so the scene builds in every shipped locale (RENDER_LOCALE).
local JUMP_TO = "Debuffs"
local MIN_ROWS = 60

local SCALE_NOTE = " The window is at its minimum size and scaled to 0.65 so the states fit one screen, so its chamfer and lines read smaller than the main window's."

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

local function railRow(ns, label)
	for _, row in ipairs(ns.Window.Parts().rail.rows) do
		if row.entry and row.entry.label == label and row:IsShown() then
			return row
		end
	end
	error("no rail row labelled " .. label)
end

local function settingRows(ns)
	local n = 0
	for _, item in ipairs(ns.Window.State().items) do
		if item.kind ~= "header" and item.kind ~= "note" then
			n = n + 1
		end
	end
	return n
end

-- Open(loader, module, at, small) -> env, K, ns: one module's environment built by its regression loader, with
-- the owner's screen and the settings addon on demand, the window open on the module's page and placed.
local function Open(loader, module, at, small, extra)
	local opts = Common.ScreenOpts({
		saved = Gallery.Saved({ [module] = {} }),
		setup = function(env)
			Gallery.Setup(env)
			loadsOptions(env)
		end,
	})
	for k, v in pairs(extra or {}) do
		opts[k] = v
	end
	local env, K = loader(opts)
	assert(K.Layout and K.Layout.Set, "the core's Layout service loaded")
	assert(K.Options.Get(module), module .. " registered its schema")
	assert(K.Options.Open(module) == true, "the window opens on " .. module)
	settle(env)
	place(K, at, small)
	settle(env)
	local ns = env._addons.KstyleUI_Options
	assert(ns.Window.State().page == module, "the window shows " .. module)
	assert(settingRows(ns) >= MIN_ROWS, module .. " offers " .. MIN_ROWS .. " or more settings, got " .. settingRows(ns))
	-- The module's own frames on the HUD are not this scene's subject and would show between the windows.
	for _, element in ipairs(K.Layout.Elements()) do
		if element.module == module then
			local el = K.Layout.Element(element.key)
			if el and el.frame then
				el.frame:Hide()
			end
		end
	end
	return env, K, ns
end

local function errorsOf(scene, env, K, what)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. what .. ": " .. err
	end
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local scenes = {}
	local mainEnv, mainK

	-- Party and Raid at scale 1, jumped to Debuffs from the rail.
	do
		local G = dofile("Tools/regression/group_env.lua")
		local env, K, ns = Open(G.New, "GroupFrames", MAIN)
		mainEnv, mainK = env, K
		local parts = ns.Window.Parts()
		local jumpTo = K.L[JUMP_TO]
		W.Click(railRow(ns, jumpTo))
		settle(env)
		local state = ns.Window.State()
		local _, index = O.Find(state.items, function(item)
			return item.kind == "header" and item.label == jumpTo
		end)
		assert(index and state.section == index, "the Debuffs section is current after the jump")
		local first
		for _, row in ipairs(parts.content.rows) do
			if row:IsShown() and row.index and (first == nil or row.index < first) then
				first = row.index
			end
		end
		assert(first == index, "the Debuffs header is the first row on screen")
		assert(railRow(ns, jumpTo).mark:IsShown(), "the rail marks the Debuffs section")
		frames:Add(env, ns.Window.Frame(), {
			name = "options_groupframes", title = "Party and Raid page", grade = "window", reference = "chat",
			caption = "The settings window on the real Party and Raid page after a click on Debuffs in the rail: the rail lists the page's sixteen sections (Blizzard frames, Party frames, Raid frames, Health bar, Power bar, Text, Status icons, Debuffs, Debuff priority, Indicators, Your heals over time, Automatic layout, Click casting, Incoming heals and absorbs, Range and highlight, Positions and sizes) with Debuffs marked, the rows start at the Debuffs header (Debuff icons, Which debuffs, Duration swipe, Dispel highlight, Highlight debuffs) and run on into Debuff priority, and the live preview shows the module's sample party and raid frames.",
			match = "Surface fill, the dark outer and light inner line, the 12-unit window chamfer and the drop shadow, as the mockup's chat panel; the controls wear the button and bar grades.",
		})
		frames:Add(env, parts.rail, {
			name = "options_groupframes_rail", title = "Party and Raid rail", grade = "window", reference = "chat",
			caption = "The rail on a long page: Party and Raid selected with its accent bar and wash, its sixteen sections under it as indented rows, Debuffs marked with the accent tick as the section on screen, Profiles and About after them.",
			match = "The rail draws no chrome of its own; the glass behind it is the window's. The bar, tick and wash are the kit's selection marks.",
		})
		scenes[#scenes + 1] = Gallery.Build(env)
		errorsOf(scenes[#scenes], env, K, "groupframes")
	end

	-- Nameplates, at the top of its page.
	do
		local N = dofile("Tools/regression/nameplates_env.lua")
		local env, K, ns = Open(N.New, "Nameplates", NAMEPLATES, true)
		frames:Add(env, ns.Window.Frame(), {
			name = "options_nameplates", title = "Nameplates page", grade = "window", reference = "chat",
			caption = "The settings window on the real Nameplates page at its top: the module switch, then the module's own sections in the rail and the rows, from the plate's size and style down through its health, name, cast bar, auras, colours and presets." .. SCALE_NOTE,
			match = "Window grade as the chat panel: surface fill, two-line edge, drop shadow; the controls wear the button and bar grades.",
		})
		scenes[#scenes + 1] = Gallery.Build(env)
		errorsOf(scenes[#scenes], env, K, "nameplates")
	end

	local scene = Scene.Merge(scenes)
	return frames:Finish(scene, mainEnv, mainK, "gallery options modules")
end)
