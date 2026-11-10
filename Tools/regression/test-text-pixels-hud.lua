-- test-text-pixels-hud.lua: the nine-screen text-pixel matrix of test-text-pixels.lua over the HUD modules it leaves out (unit frames, action bars, cooldowns, tooltips, group frames, meters, and any module added later), split so each file stays within the time budget.
local P = dofile("Tools/regression/text_pixels_lib.lua")

local measured = P.Run(false)
assert(measured > 3000, "the nine-screen matrix must measure the live modules, not an empty tree")
print("text pixels (hud) ok: " .. measured .. " live font sizes across nine screens and three requested sizes")
