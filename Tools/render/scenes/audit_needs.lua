-- audit_needs.lua: setup and settings journeys for the accessibility audit; RENDER_NEED selects general, bars, profiles, modules, summary, welcome or movers.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local W = dofile("Tools/regression/widget_env.lua")
local need = os.getenv("RENDER_NEED") or "general"

return Common.Run(function()
	local env, K
	if need == "welcome" or need == "modules" or need == "summary" then
		env, K = W.New(Common.ScreenOpts({ boot = false, saved = Gallery.Saved({}), setup = function(e)
			Common.ForceScreen(e)
			e.C_AddOns = { IsAddOnLoaded = function(name) return name == "Bartender4" or name == "Plater" or name == "Grid2" end }
		end }))
		for _, entry in ipairs(K.Setup.PICKER) do K.Modules.Register(W.CoreEnv.Module(entry.name)) end
		W.CoreEnv.Boot(env)
		dofile("Tools/render/scenes/_audit.lua").Apply(K)
		if os.getenv("RENDER_CLOSE") == "later" and K.Options.Row("Setup", "closeBehaviour") then K.Options.Write("Setup", "closeBehaviour", "later") end
		if need == "summary" then
			local Fake = dofile("Tools/regression/editmode_fake.lua")
			local saved = {}
			for i = 1, 5 do saved[i] = { layoutName = "My layout " .. i, layoutType = Fake.ACCOUNT, systems = Fake.Modern().systems } end
			Fake.Install(env, { saved = saved, active = 3, max = 5 })
		end
		assert(K.Setup.Open(true))
		K.Setup.Go(need == "modules" and 4 or need == "summary" and 6 or 1)
	else
		local AB = dofile("Tools/regression/actionbars_env.lua")
		env, K = AB.New(Common.ScreenOpts({ saved = Gallery.Saved({ ActionBars = { bar4 = { enabled = false }, bar5 = { enabled = false } } }), setup = Common.ForceScreen }))
		AB.Enable(env, K)
		if need == "movers" then
			assert(K.Layout.Enter())
		else
			local Load = dofile("Tools/regression/load_files.lua")
			local O = dofile("Tools/regression/options_env.lua")
			env.C_AddOns = { LoadAddOn = function() Load(O.Files(), env); return true end }
			local page = (need == "bars" or need == "numeric") and "ActionBars" or (need == "profiles" or need == "import") and "Profiles" or "General"
			K.Options.Open(page)
			if need == "general" and K.Profiles then
				K.Profiles.Readable("Readable")
				K.Options.Write("ColorVision", "mode", "redGreen")
				K.Options.Write("Integrations", "timerLane", true)
				K.Options.Write("Integrations", "announcementLane", true)
			end
			if need == "readable" and K.Profiles then K.Profiles.Readable("Readable") end
			if need == "numeric" then K.Options.Write("ActionBars", "bar1.size", 40) end
			env.RunTimers()
			local ns = env._addons.KstyleUI_Options
			if need == "numeric" then
				for i, item in ipairs(ns.Window.State().items) do
					if item.key == "bar1.size" then ns.Window.Parts().content:ScrollToIndex(i, true, "TOP"); break end
				end
				env.RunTimers()
				W.Settle(env)
				for _, row in ipairs(ns.Window.Parts().content.rows) do
					if row.item and row.item.key == "bar1.size" and row.controls.slider.valueButton then W.Click(row.controls.slider.valueButton) end
				end
			elseif need == "import" and K.Profiles then
				K.Options.Write("ActionBars", "bar1.buttons", 6)
				local text = assert(K.Profiles.Export("ActionBars"))
				K.Options.Write("ActionBars", "bar1.buttons", 12)
				ns.Pages.ReviewImport(text)
			end
			if need == "general" or need == "profiles" or need == "readable" then
				local wanted = need == "profiles" and "Share" or need == "readable" and "Readability" or "Colour vision"
				for i, item in ipairs(ns.Window.State().items) do
					if item.label == wanted then ns.Window.Parts().content:ScrollToIndex(i, true, "TOP"); break end
				end
			end
		end
	end
	dofile("Tools/render/scenes/_audit.lua").Apply(K)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Common.Scene.Build(env, Common.ScreenOpts({ iconDirs = Common.IconDirs() }))
end)
