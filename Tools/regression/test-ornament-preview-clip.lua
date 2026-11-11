-- test-ornament-preview-clip.lua: in the settings window's live preview, which clips its children, every shown ornament piece of the real Unit Frames preview lies wholly inside the clip, so an end is drawn whole or not at all, for the player, target and focus frames at Subtle and Full on 1671x1080 and 1920x1080 and at Full on 3456x2234.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local O = dofile("Tools/regression/options_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = O.W
local EPS = 0.01

local function clipOf(object)
	local frame = object:GetParent()
	while frame do
		if frame:DoesClipChildren() then return frame end
		frame = frame:GetParent()
	end
end

local checked, pieces = 0, 0
local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
for _, screen in ipairs({ { 1671, 1080 }, { 1920, 1080 }, { 3456, 2234 } }) do
	for _, level in ipairs(screen[1] == 3456 and { "Full" } or { "Subtle", "Full" }) do
		for _, unit in ipairs({ "player", "target", "focus" }) do
			rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
			rawset(_G, "RENDER_ORNAMENTS", level)
			local env, K = U.New(Common.ScreenOpts({
				saved = Gallery.Saved({ UnitFrames = {} }),
				setup = function(e)
					Gallery.Setup(e)
					e.C_AddOns = e.C_AddOns or {}
					e.C_AddOns.LoadAddOn = function(name)
						if name == "KstyleUI_Options" and not e._addons.KstyleUI_Options then Load(O.Files(), e) end
						return true
					end
				end,
			}))
			K.Options.Write("UnitFrames", "edit", unit)
			assert(K.Options.Open("UnitFrames") == true, "the window opens on Unit Frames")
			env.RunTimers()
			W.Settle(env)
			env.RunTimers()
			local label = string.format("%s %dx%d %s preview", level, screen[1], screen[2], unit)
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
			assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
			pieces = pieces + seen
			checked = checked + 1
			collectgarbage("collect")
		end
	end
end
rawset(_G, "RENDER_SCREEN", old)
rawset(_G, "RENDER_ORNAMENTS", oldLevel)
assert(pieces > 0, "no ornament piece was drawn inside a clipping frame, so nothing was checked")
print(string.format("ok %d live previews draw %d ornament pieces, each wholly inside the preview's clip", checked, pieces))
