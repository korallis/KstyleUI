-- options_bars.lua: six real module pages using the same bar rows, with custom colours and textures selected.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

return Common.Run(function()
	local scenes = {}
	for i, spec in ipairs({
		{ "UnitFrames", "unitframes", "player.healthTexture", "player.healthColor", "player.healthCustom" },
		{ "Nameplates", "nameplates", "cast.texture", "cast.colorSource", "cast.color", "cast.height" },
		{ "GroupFrames", "group", "health.texture", "health.colorSource", "health.color" },
		{ "Cooldowns", "cooldowns", "bars.texture", "bars.colorSource", "bars.color", "bars.height" },
		{ "Meters", "meters", "damage.texture", "damage.colorSource", "damage.color", "damage.rowHeight" },
		{ "DataBars", "databars", "xp.texture", "xp.colorSource", "xp.color" },
	}) do
		local env, K = dofile("Tools/regression/" .. spec[2] .. "_env.lua").New(Common.ScreenOpts({
			saved = Gallery.Saved({ [spec[1]] = {} }), setup = function(env)
				Gallery.Setup(env)
				env.C_AddOns = env.C_AddOns or {}
				env.C_AddOns.LoadAddOn = function(name)
					if name == "KstyleUI_Options" and not env._addons[name] then Load(O.Files(), env) end
					return true
				end
			end,
		}))
		K.Options.Write(spec[1], spec[3], K.Tokens.Texture("barGlass"))
		K.Options.Write(spec[1], spec[4], "custom")
		K.Options.Write(spec[1], spec[5], { r = 0.3, g = 0.6, b = 0.7 })
		if spec[6] then K.Options.Write(spec[1], spec[6], 18) end
		if spec[1] == "UnitFrames" then
			K.Options.Write(spec[1], "edit", "player")
			K.Options.Write(spec[1], "player.healthText", "percent")
		end
		assert(K.Options.Open(spec[1]))
		for _, element in ipairs(K.Layout.Elements()) do
			if element.module == spec[1] then
				local frame = K.Layout.Element(element.key).frame
				if frame then frame:Hide() end
			end
		end
		K.Layout.Set("Options.Window", "width", 1100)
		K.Layout.Set("Options.Window", "scale", 0.55)
		K.Layout.Set("Options.Window", "anchor", "TOPLEFT")
		K.Layout.Set("Options.Window", "x", 16 + (i - 1) % 3 * 620)
		K.Layout.Set("Options.Window", "y", -16 - math.floor((i - 1) / 3) * 430)
		env.RunTimers()
		Gallery.Ticks(O.W, env, 40)
		local ns = env._addons.KstyleUI_Options
		for index, item in ipairs(ns.Window.State().items) do
			if item.key == spec[3] then
				ns.Window.Parts().content:ScrollToIndex(index, true, "TOP")
				break
			end
		end
		env.RunTimers()
		O.W.Settle(env)
		assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
		scenes[#scenes + 1] = Gallery.Build(env)
	end
	return Common.Scene.Merge(scenes)
end)
