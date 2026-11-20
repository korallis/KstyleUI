-- shell_parity.lua: one shell module's real Options page or affected frames, with parity switches applied through Options.Write.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local module = os.getenv("RENDER_SHELL_MODULE") or "Minimap"
local loaders = { Minimap = "minimap", DataBars = "databars", Chat = "chat", Bags = "bags", Tooltips = "tooltips", QoL = "qol" }
local keys = { Minimap = "zone.subzone", DataBars = "strip.modules", Chat = "whisperSound", Bags = "desaturateJunk", Tooltips = "maxStack", QoL = "autoGossip" }
local driver = assert(loaders[module], "RENDER_SHELL_MODULE must name a shell module")
local D = dofile("Tools/regression/" .. driver .. "_env.lua")

return Common.Run(function()
	local opts = Common.ScreenOpts({
		saved = Gallery.Saved({ [module] = {} }),
		setup = function(env)
			Gallery.Setup(env)
			env.GetZoneText = function() return "Elwynn Forest" end
			env.GetAverageItemLevel = function() return 62.8, 58.3 end
			if env.C_Item then env.C_Item.GetItemMaxStackSizeByID = function() return 20 end end
			env.C_AddOns = env.C_AddOns or {}
			env.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons.KstyleUI_Options then Load(O.Files(), env) end
				return true
			end
		end,
	})
	if module == "Bags" then
		opts.bags = { [0] = { size = 20, items = { D.Item("potion"), D.Item("sword"), D.Item("junk"), D.Item("helm"), D.Item("cloth") } } }
	end
	local env, K, ns = D.New(opts)
	if not K.Modules.IsRunning(module) then assert(K.Modules.Enable(module)) end
	env.RunTimers()
	local defaults = os.getenv("RENDER_SHELL_DEFAULTS") == "1"
	if not defaults then
		if module ~= "DataBars" then assert(K.Options.Write(module, keys[module], module ~= "Minimap") ~= false) end
		if module == "DataBars" then
			local s = K.Store.Module(module).strip
			for _, key in ipairs({ "modules", "dockModules", "railModules" }) do
				for _, entry in ipairs(s[key]) do if entry.id == "location" or entry.id == "itemLevel" then entry.shown = true end end
				assert(K.Options.Write(module, "strip." .. key, s[key]) ~= false)
			end
		elseif module == "QoL" then
			assert(K.Options.Write(module, "skipCinematics", true) ~= false)
		end
	end
	if module == "Bags" then env.ToggleAllBags() end
	if module == "Tooltips" then
		local tip = env.GameTooltip
		env._items[2447] = { quality = 1, icon = 133939 }
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		tip:AddLine("Peacebloom")
		tip:AddLine("Crafting Reagent")
		D.BlizzardShow(tip, true)
		D.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 2447 })
		dofile("Tools/render/scenes/tooltip.lua").Layout(env, tip)
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", K.Scale.Root(), "TOPRIGHT", -80, -180)
	end
	env.RunTimers()
	O.W.Settle(env)
	if os.getenv("RENDER_SHELL_OPTIONS") ~= "0" then
		assert(K.Options.Open(module))
		if module == "DataBars" then
			if not defaults then K.Options.Write(module, "strip.labels", "short") end
			ns.Strip.view.frame:Hide()
		end
		env.RunTimers()
		assert(K.Layout.Set("Options.Window", "height", 900))
		if module == "DataBars" then assert(K.Layout.Set("Options.Window", "width", 1120)) end
		assert(K.Layout.Set("Options.Window", "anchor", "TOPLEFT"))
		assert(K.Layout.Set("Options.Window", "x", 28))
		assert(K.Layout.Set("Options.Window", "y", -28))
		local options = env._addons.KstyleUI_Options
		options.Window.Jump({ page = module, module = module, key = module ~= "DataBars" and keys[module] or nil,
			labelTarget = module == "DataBars" and K.L["Location"] or nil })
		env.RunTimers()
		O.W.Settle(env)
	end
	local scene = Gallery.Build(env)
	local errors = Common.Errors(env, K)
	assert(not errors, errors)
	scene.log[#scene.log + 1] = "shell parity: " .. module .. (defaults and " defaults" or " options applied")
	return scene
end)
