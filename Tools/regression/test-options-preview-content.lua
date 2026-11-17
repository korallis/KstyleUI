-- test-options-preview-content.lua: hosted previews initialise their fonts, keep portraits inside their clip, and show the full French target name in Frames.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local O = dofile("Tools/regression/options_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local failures = {}
for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 }, { 2383, 1540 }, { 1920, 1080, "frFR", "Frames" }, { 5120, 1440, "frFR", "Frames" }, { 1920, 1080, "esES", "Medallions" } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
	rawset(_G, "RENDER_HUD_STYLE", screen[4] or "Medallions")
	rawset(_G, "RENDER_LOCALE", screen[3] or "enUS")
	local env, K = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ UnitFrames = {} }),
		setup = function(e)
			Gallery.Setup(e)
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	if screen[3] == "frFR" then assert(K.L["Frost Howler"] == "Hurleur du givre", "the French preview fixture is loaded") end
	K.Options.Write("UnitFrames", "edit", "target")
	K.Options.Open("UnitFrames")
	local ns = env._addons.KstyleUI_Options
	for _, scale in ipairs({ 1, 0.65 }) do
		if scale < 1 then
			K.Layout.Set("Options.Window", "width", 880)
			K.Layout.Set("Options.Window", "height", 520)
			K.Layout.Set("Options.Window", "scale", scale)
		end
		env.RunTimers()
		O.W.Settle(env)
		env.RunTimers()
		local pane = ns.Window.Parts().preview
		local frame = pane.current
		local view = frame.views.target
		local label = (screen[3] or "enUS") .. " " .. (screen[4] or "Medallions") .. " " .. screen[1] .. "x" .. screen[2] .. " scale " .. scale
		local _, name = view.name:GetFont()
		local _, caption = view.caption:GetFont()
		if view.form == "slab" then
			local unit = env._addons.KstyleUI_UnitFrames.Unit
			assert(U.Shown(env, view.caption) == unit.Tracked(K.L["Beast"], (view.caption:GetFont())), label .. ": show the preview creature type before fitting the row")
			assert(not view.caption:IsTruncated(), label .. ": show the complete preview creature type")
			local reference = K.Widgets.FontString(view.name:GetParent(), "OVERLAY")
			reference:Hide()
			K.Widgets.ApplyFont(reference, env._addons.KstyleUI_UnitFrames.Settings.Font("target", "name"))
			local _, capsSize = reference:GetFont()
			if view.name:GetFont() == K.Tokens.Font("body") then
				assert(name <= capsSize + 0.01, label .. ": fallback " .. name .. " must not enlarge caps " .. capsSize)
			end
			if screen[3] == "esES" and scale == 1 then
				assert(view.name:GetFont() == K.Tokens.Font("body"), label .. ": exercise the Spanish body fallback")
			end
		end
		if not screen[3] and name < caption - 0.01 then failures[#failures + 1] = label .. ": initialise preview fonts before building the unit preview" end
		local scene = Common.Scene.Build(env)
		local rings = 0
		for _, item in ipairs(scene.items) do
			local node = item.object
			while node and node ~= frame do node = node:GetParent() end
			if node and item.clip and item.kind == "texture" and item.file and item.file:find("Ring", 1, true) then
				rings = rings + 1
				local x, y, w, h = Common.Scene.Rect(env, item.object)
				local c = item.clip
				if x < c[1] - 0.5 or y < c[2] - 0.5 or x + w > c[1] + c[3] + 0.5 or y + h > c[2] + c[4] + 0.5 then
					failures[#failures + 1] = label .. ": fit the portrait ring inside the preview holder"
				end
			end
		end
		assert(rings > 0, label .. ": the preview portrait ring draws")
		local Guard = dofile("Tools/render/guard.lua")
		for _, finding in ipairs(Guard.Check(scene)) do
			if finding.kind == "ellipsis" and finding.subject == K.L["Frost Howler"] then failures[#failures + 1] = label .. ": show the whole preview name " .. finding.subject end
		end
	end
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
	collectgarbage("collect")
end
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
rawset(_G, "RENDER_LOCALE", nil)
assert(#failures == 0, table.concat(failures, "\n"))
print("options preview content ok")
