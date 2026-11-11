-- test-ornament-preview-clip-plates.lua: the Nameplates live preview shows one plate, the richest sample that fits whole and legible, so every piece lies wholly inside the preview's clip, the clip removes none, and the plate's name is never smaller than the window's body text, at the default and the smallest window size, at Full on 1366x768, 1920x1080, 2560x1440 and 3456x2234 and at Subtle on 1920x1080; in the smallest window at 1366x768 and 1920x1080, a recorded limit, the plate takes smaller tiers at the clip but keeps both ends.
local Lib = dofile("Tools/regression/preview_clip_lib.lua")
local cases = {}
for _, screen in ipairs({ { 1366, 768, "Full" }, { 1920, 1080, "Subtle" }, { 1920, 1080, "Full" }, { 2560, 1440, "Full" }, { 3456, 2234, "Full" } }) do
	for _, small in ipairs({ false, true }) do
		cases[#cases + 1] = { screen[1], screen[2], screen[3], small = small, limit = small and screen[3] == "Full" and screen[1] <= 1920 }
	end
end
Lib.Run("Nameplates", cases)
