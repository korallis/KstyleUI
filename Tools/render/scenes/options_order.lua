-- options_order.lua: the real Options window with sample ordered modules, until the data bar adopts the generic row.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Fixture = dofile("Tools/regression/options_order_fixture.lua")
local Load = dofile("Tools/regression/load_files.lua")

return Common.Run(function()
	local before = os.getenv("RENDER_ORDER_BEFORE") == "1"
	local loader = before and dofile("Tools/regression/databars_env.lua") or O
	local env, K = loader.New(Common.ScreenOpts({
		saved = Gallery.Saved({}), setup = function(env)
			Gallery.Setup(env)
			env.C_AddOns = { LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not env._addons[name] then Load(O.Files(), env) end
				return true
			end }
		end,
		before = not before and function(_, K) Fixture(K) end or nil,
	}))
	if before then K.Options.Write("DataBars", "strip.labels", "short") end
	assert(K.Options.Open("DataBars"))
	K.Layout.Set("Options.Window", "scale", 1)
	for _, element in ipairs(K.Layout.Elements()) do
		if element.module == "DataBars" then K.Layout.Element(element.key).frame:Hide() end
	end
	env.RunTimers()
	Gallery.Ticks(O.W, env, 40)
	env.RunTimers()
	if before then
		local ns = env._addons.KstyleUI_Options
		for i, item in ipairs(ns.Window.State().items) do
			if item.kind == "header" and item.label == K.L["Data strip"] then
				ns.Window.Parts().content:ScrollToIndex(i, true, "TOP")
				break
			end
		end
	end
	assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
	return Gallery.Build(env)
end)
