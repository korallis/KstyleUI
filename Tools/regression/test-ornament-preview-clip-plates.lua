-- test-ornament-preview-clip-plates.lua: the Nameplates live preview shows one plate, the richest sample that fits whole and legible, so every piece lies wholly inside the preview's clip, the clip removes none, the plate's name is never smaller than the window's body text, and the expected sample shows, at the default and the smallest window size, at Full on 1366x768, 1920x1080, 2560x1440 and 3456x2234 and at Subtle on 1920x1080; in the smallest window at 1366x768 and 1920x1080, a recorded limit, the plate takes smaller tiers at the clip but keeps both ends.
local Lib = dofile("Tools/regression/preview_clip_lib.lua")
local ELITE, ENEMY, FRIEND = "DARK IRON SUMMONER", "ELUNARA", "THALDRIN"
Lib.Run("Nameplates", {
	{ 1366, 768, "Full", sample = FRIEND },
	{ 1366, 768, "Full", small = true, limit = true, sample = FRIEND },
	{ 1920, 1080, "Subtle", sample = ELITE },
	{ 1920, 1080, "Subtle", small = true, sample = ENEMY },
	{ 1920, 1080, "Full", sample = ENEMY },
	{ 1920, 1080, "Full", small = true, limit = true, sample = FRIEND },
	{ 2560, 1440, "Full", sample = ENEMY },
	{ 2560, 1440, "Full", small = true, sample = FRIEND },
	{ 3456, 2234, "Full", sample = ENEMY },
	{ 3456, 2234, "Full", small = true, sample = ENEMY },
})
