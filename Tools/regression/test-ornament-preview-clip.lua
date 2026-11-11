-- test-ornament-preview-clip.lua: the Unit Frames live preview reserves its ornaments' reach, so for the player, target and focus frames every piece lies wholly inside the preview's clip and the clip removes none, at Full on 1280x720, 1920x1080 and 3456x2234 and at Subtle on 1920x1080.
local Lib = dofile("Tools/regression/preview_clip_lib.lua")
local cases = {}
for _, screen in ipairs({ { 1280, 720, "Full" }, { 1920, 1080, "Subtle" }, { 1920, 1080, "Full" }, { 3456, 2234, "Full" } }) do
	for _, unit in ipairs({ "player", "target", "focus" }) do
		cases[#cases + 1] = { screen[1], screen[2], screen[3], unit = unit }
	end
end
Lib.Run("UnitFrames", cases)
