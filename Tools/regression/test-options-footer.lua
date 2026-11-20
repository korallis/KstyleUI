-- test-options-footer.lua: the settings footer buttons never cover the option list in any shipped locale, at 1080 (the pre-Auto size), 1440 (5120x1440 has the same units) and 2160 Auto, at the default and the smallest window.
local O = dofile("Tools/regression/options_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

local function apart(env, a, b)
	local ax, ay, aw, ah = Common.Scene.Rect(env, a)
	local bx, by, bw, bh = Common.Scene.Rect(env, b)
	return ax >= bx + bw or bx >= ax + aw or ay >= by + bh or by >= ay + ah
end

for _, locale in ipairs({ "enUS", "deDE", "frFR", "esES", "zhCN" }) do
	for _, screen in ipairs({ { 1920, 1080, "default" }, { 2560, 1440 }, { 3840, 2160 } }) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = screen[3] or "auto" })
		rawset(_G, "RENDER_LOCALE", locale)
		local env, K = O.New(Common.ScreenOpts({ saved = Gallery.Saved({}), setup = Gallery.Setup }))
		assert(K.Options.Open("General") == true)
		env.RunTimers()
		O.W.Settle(env)
		local parts = env._addons.KstyleUI_Options.Window.Parts()
		for _, small in ipairs({ false, true }) do
			if small then
				K.Layout.Set("Options.Window", "width", 880)
				K.Layout.Set("Options.Window", "height", 520)
				K.Layout.Set("Options.Window", "scale", 0.65)
				env.RunTimers()
				O.W.Settle(env)
			end
			assert(parts.preview:IsShown(), "the General page shows its preview")
			local case = string.format("%s at %dx%d %s%s", locale, screen[1], screen[2], screen[3] or "auto", small and ", smallest window" or "")
			assert(apart(env, parts.layoutButton, parts.content) and apart(env, parts.resetButton, parts.content),
				case .. ": give the footer its own row under the list when its buttons outgrow the preview column")
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_LOCALE", nil)
print("options footer: no button covers the list in any locale, screen or window size")
