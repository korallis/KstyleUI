-- test-ornament-preview-clip-plates.lua: the Nameplates live preview fits its plates' ornament reach inside the preview's clip, so every piece lies wholly inside it and the clip removes none, at the default and the smallest window size, at Full on four screens and at Subtle on 1920x1080.
local Lib = dofile("Tools/regression/preview_clip_lib.lua")
local cases = {}
for _, screen in ipairs({ { 1280, 720, "Full" }, { 1671, 1080, "Full" }, { 1920, 1080, "Subtle" }, { 1920, 1080, "Full" }, { 3456, 2234, "Full" } }) do
	for _, small in ipairs({ false, true }) do
		cases[#cases + 1] = { screen[1], screen[2], screen[3], small = small }
	end
end
Lib.Run("Nameplates", cases)
