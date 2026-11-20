-- parity_core.lua: actual core Options rows and two linked unit frames, with optional bright-grid Layout Mode, a fading toolbar, corner-aligned links and the round 1 palette, outline and attach points.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

return Common.Run(function()
	local view = os.getenv("RENDER_CORE_PAGE") or "layout"
	local saved = Gallery.Saved({ UnitFrames = {} })
	saved.profiles.Default.HudStyle = { style = "frames" }
	local env, K = U.New(Common.ScreenOpts({
		saved = saved,
		setup = function(e)
			Gallery.Setup(e)
			for unit, name in pairs({ player = "Valerin", target = "Training Dummy" }) do
				e._units[unit] = { name = name, class = "WARRIOR", level = 38, health = 2750, healthMax = 3350,
					power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = unit == "player", reaction = unit == "player" and 5 or 2 }
			end
			e.C_AddOns = { LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
				return true
			end }
		end,
	}))
	local layout = K.Layout
	assert(layout.Update("unitframes.player", { anchor = "CENTER", x = -270, y = -170, width = 300, height = 100 }))
	assert(layout.Update("unitframes.target", { attachTo = "unitframes.player", side = os.getenv("RENDER_CORE_SIDE") or "right", offset = 50, matchHeight = true, extraHeight = 10 }))
	K.Options.Write("Layout", "grid", true)
	K.Options.Write("Layout", "gridAlpha", 0.15)
	K.Options.Write("Layout", "nudgeStep", 100)
	K.Options.Write("Layout", "overlap", "ctrl")
	local account = K.Store.Account()
	if view == "toolbar" then account.layoutToolbarHover = true end
	if view == "gametext" then account.gameFont, account.gameTextScale, account.combatFont = true, 1.2, true end
	if view == "palette" or view == "colours" then
		K.Options.Write("Appearance", "classColors.WARRIOR", { r = 0.85, g = 0.33, b = 0.2 })
		K.Options.Write("Appearance", "powerColors.RAGE", { r = 0.95, g = 0.55, b = 0.1 })
		K.Options.Write("Appearance", "outline", "OUTLINE")
		assert(layout.Set("unitframes.target", "link", { point = "BOTTOMLEFT", target = "TOPRIGHT", x = 40, y = 10 }))
	end
	if view == "palette" then
		layout.Element("unitframes.player").frame:Show()
	elseif view == "mode" or view == "hidden" or view == "toolbar" then
		assert(layout.Enter())
		layout.Mode.Select("unitframes.target")
		if view == "hidden" then
			local plate = layout.Mode.Plate("unitframes.target")
			plate:GetScript("OnClick")(plate, "MiddleButton")
		end
	else
		local pages = { layout = "Elements", links = "Elements", profiles = "Profiles", import = "Profiles", sharing = "Profiles", appearance = "General", window = "General", search = "General", movers = "Elements", gametext = "General", about = "About",
			colours = "General", points = "Elements", extras = "Profiles", hotkeys = "Profiles", cpu = "About", conveniences = "General" }
		assert(K.Options.Open(assert(pages[view], "unknown core page")))
		assert(layout.Update("Options.Window", { width = 1240, height = 860, scale = 1 }))
		local ns = env._addons.KstyleUI_Options
		if view == "sharing" then
			for _, item in ipairs(ns.Window.State().items) do
				if item.label == "Share scope" then item.set("modules") end
			end
			ns.Pages.shareModules = { UnitFrames = true, Appearance = true }
			ns.Pages.includeLayout = false
			ns.Changed()
		end
		if view == "import" then assert(ns.Pages.ReviewImport(assert(K.Store.Export()))) end
		if view == "extras" then ns.Pages.shareSpecs, ns.Pages.shareEditMode = true, true; ns.Changed() end
		if view == "cpu" then
			env.C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function(name) return name == "KstyleUI" and 0.42 or 0.03 end }
			account.optionsCpuMetric = 1
			ns.Changed()
		end
		if view == "conveniences" then account.optionsSearchMemory, account.optionsFold, account.gameMenuOptions, account.gameMenuLayout = true, true, true, true; ns.Changed() end
		for _, element in ipairs(layout.Elements()) do
			if element.module == "UnitFrames" then layout.Element(element.key).frame:Hide() end
		end
		env.RunTimers()
		Gallery.Ticks(O.W, env, 30)
		env.RunTimers()
		local label = os.getenv("RENDER_CORE_KEY") or ({ profiles = "Active profile", sharing = "Share scope", appearance = "Text", window = "Window size and opacity", search = "Window conveniences", movers = "Mover controls", links = "Target frame", gametext = "Game text", about = "Tools",
			colours = "Class and power colours", points = "Point on this element", extras = "Include specialization assignments", hotkeys = "Profile hotkeys", cpu = "CPU readout", conveniences = "Remember search picks" })[view]
		if label then
			local found
			for i, item in ipairs(ns.Window.State().items) do
				if item.label == label or item.key == label then
					ns.Window.Parts().content:ScrollToIndex(i, true, "TOP")
					found = true
					break
				end
			end
			assert(found, "missing Options section " .. label)
		end
	end
	Gallery.Ticks(O.W, env, 40)
	env.RunTimers()
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
