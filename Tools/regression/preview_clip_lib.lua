-- preview_clip_lib.lua: Run(module, cases) opens the settings window on a module page in each case and fails when an ornament piece in the live preview is cut by the preview's clip, when the clip removes a piece a handle would place without it, or when a previewed plate's name draws smaller than the window's body text; a case marked as a recorded limit may take smaller tiers at the clip but never drops an end.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local O = dofile("Tools/regression/options_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W
local EPS = 0.01
local WINDOW_KEY = "Options.Window"

local function clipOf(object)
	local frame = object:GetParent()
	while frame do
		if frame:DoesClipChildren() then return frame end
		frame = frame:GetParent()
	end
end

local function set(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then names[#names + 1] = (texture:GetTexture() or ""):match("([%w]+)%.png$") or "Fill" end
	end
	return table.concat(names, " ")
end

local M = {}

local function check(env, K, label, limit, sample)
	local solver = Scene.RectSolver(env)
	local seen = 0
	for _, frame in ipairs(env._frames) do
		for _, region in ipairs(frame._regions or {}) do
			local file = region._state and region._state.Texture and region._state.Texture[1]
			if type(file) == "string" and file:find("ForgedOrnaments", 1, true) and region:IsVisible() then
				local clip = clipOf(region)
				if clip and clip:IsVisible() then
					local x, y, w, h = Scene.RectIn(solver, region)
					local cx, cy, cw, ch = Scene.RectIn(solver, clip)
					if x and cx then
						assert(x >= cx - EPS and y >= cy - EPS and x + w <= cx + cw + EPS and y + h <= cy + ch + EPS,
							string.format("%s: %s [%.2f,%.2f,%.2f,%.2f] is cut by the clipping frame [%.2f,%.2f,%.2f,%.2f]",
								label, file:match("([%w]+)%.png$") or file, x, y, w, h, cx, cy, cw, ch))
						seen = seen + 1
					end
				end
			end
		end
	end
	local found = {}
	K.Widgets.RestyleUnder({ [env.UIParent] = true }, function(widget)
		if K.Widgets.IsOrnament(widget) and widget.used > 0 and widget.target:IsVisible() and clipOf(widget.owner) then found[#found + 1] = widget end
		return false
	end)
	for _, handle in ipairs(found) do
		local bounded = set(handle)
		handle.unbounded = true
		handle:Restyle()
		local free = set(handle)
		handle.unbounded = nil
		handle:Restyle()
		local function ends(names) local n = 0 for _ in names:gmatch("End%a+%d+") do n = n + 1 end return n end
		assert(ends(bounded) == ends(free), string.format("%s: the clip drops an end from a %s handle\n  without the clip %s\n  with the clip    %s", label, handle.kind, free, bounded))
		if limit and free ~= bounded then
			M.limits[#M.limits + 1] = string.format("%s: %s with the clip, %s without", label, bounded, free)
		end
		assert(limit or free == bounded, string.format("%s: the clip removes pieces from a %s handle\n  without the clip %s\n  with the clip    %s", label, handle.kind, free, bounded))
		assert(set(handle) == bounded, label .. ": a restyle with the clip places the same pieces again")
	end
	local pane = env._addons.KstyleUI_Options.Window.Parts().preview
	local current = pane.current
	if current and current.plates and pane.ruler then
		local _, body = pane.ruler:GetFont()
		local floor = body * K.Widgets.ScaleFactor(pane.ruler)
		local shown = 0
		for _, plate in ipairs(current.plates) do
			if plate:IsVisible() then
				local _, size = plate.name:GetFont()
				local drawn = size * K.Widgets.ScaleFactor(plate.name)
				assert(drawn >= floor - 0.01, string.format("%s: the plate name %s draws at %.2f, below the window's body text at %.2f", label, tostring(plate.name:GetText()), drawn, floor))
				shown = shown + 1
				assert(not sample or plate.name:GetText() == sample, string.format("%s: the preview shows %s, not %s", label, tostring(plate.name:GetText()), tostring(sample)))
				if os.getenv("PREVIEW_SAMPLES") then print("SAMPLE", label, plate.name:GetText()) end
			end
		end
		assert(shown >= 1, label .. ": the nameplates preview shows a plate")
		M.legible = (M.legible or 0) + shown
	end
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
	M.pieces, M.handles, M.checked = (M.pieces or 0) + seen, (M.handles or 0) + #found, (M.checked or 0) + 1
	collectgarbage("collect")
end

local function open(loader, module, small, before)
	local env, K = loader(Common.ScreenOpts({
		saved = Gallery.Saved({ [module] = {} }),
		setup = function(e)
			Gallery.Setup(e)
			e.C_AddOns = e.C_AddOns or {}
			e.C_AddOns.LoadAddOn = function(name)
				if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
				return true
			end
		end,
	}))
	if before then before(K) end
	assert(K.Options.Open(module) == true, "the window opens on " .. module)
	env.RunTimers()
	W.Settle(env)
	if small then
		assert(K.Layout.Set(WINDOW_KEY, "width", 880))
		assert(K.Layout.Set(WINDOW_KEY, "height", 520))
		assert(K.Layout.Set(WINDOW_KEY, "scale", 0.65))
		env.RunTimers()
		W.Settle(env)
	end
	env.RunTimers()
	return env, K
end

local LOADERS = { UnitFrames = U.New, Nameplates = N.New }

function M.Run(module, cases)
	local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
	M.pieces, M.handles, M.checked, M.limits = 0, 0, 0, {}
	for _, case in ipairs(cases) do
		rawset(_G, "RENDER_SCREEN", { width = case[1], height = case[2], uiScale = 768 / 1080 })
		rawset(_G, "RENDER_ORNAMENTS", case[3])
		local label = string.format("%s %dx%d %s preview%s", case[3], case[1], case[2], case.unit or module, case.small and " in the smallest window" or "")
		local env, K = open(LOADERS[module], module, case.small, case.unit and function(k) k.Options.Write("UnitFrames", "edit", case.unit) end)
		check(env, K, label, case.limit, case.sample)
	end
	rawset(_G, "RENDER_SCREEN", old)
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	assert(M.pieces > 0 and M.handles > 0, "no ornament piece was drawn inside a clipping frame, so nothing was checked")
	for _, limit in ipairs(M.limits) do print("recorded limit: " .. limit) end
	print(string.format("ok %d %s previews draw %d ornament pieces from %d handles, each wholly inside the preview's clip; the clip removes none outside %d recorded limits, where it takes only smaller tiers", M.checked, module, M.pieces, M.handles, #M.limits))
end

return M
