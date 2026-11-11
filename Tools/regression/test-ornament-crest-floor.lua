-- test-ornament-crest-floor.lua: a forged rail's crest on the unit frames is Crest20 or larger at Full on nine screens, at Interface size 0.6 on the two smallest screens and 1.5 on the smallest, and in the Tank and Healer presets at 1280x720, and drops rather than taking a smaller tier.
local Hud = dofile("Tools/render/scenes/hud.lua")
local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local FLOOR = 20
local CASES = {}
for _, screen in ipairs(SCREENS) do CASES[#CASES + 1] = { "DPS", false, screen } end
CASES[#CASES + 1] = { "DPS", 0.6, SCREENS[1] }
CASES[#CASES + 1] = { "DPS", 0.6, SCREENS[2] }
CASES[#CASES + 1] = { "DPS", 1.5, SCREENS[1] }
CASES[#CASES + 1] = { "Tank", false, SCREENS[1] }
CASES[#CASES + 1] = { "Healer", false, SCREENS[1] }

local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
rawset(_G, "RENDER_ORNAMENTS", "Full")
local drawn, sizes = 0, {}
for _, case in ipairs(CASES) do
	local preset, size, screen = case[1], case[2], case[3]
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = size or nil })
	local opts = { class = "PALADIN", layout = preset, applyPreset = true, settings = Hud.PresetSettings(preset),
		target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = "elite", power = 240, powerMax = 345 } }
	local scene = Hud.Module("unitframes", opts)
	local label = string.format("%s %dx%d size %s", preset, screen[1], screen[2], tostring(size or "shipped"))
	local any = false
	for _, item in ipairs(scene.items) do
		local n = tonumber(item.file and item.file:match("Crest(%d+)%.png$"))
		if n then
			assert(n >= FLOOR, string.format("%s: a unit-frame crest takes Crest%d at %.1f,%.1f, below the Crest%d floor", label, n, item.rect[1], item.rect[2], FLOOR))
			any = true
			sizes[n] = (sizes[n] or 0) + 1
		end
	end
	drawn = drawn + (any and 1 or 0)
	collectgarbage("collect")
end
rawset(_G, "RENDER_SCREEN", old)
rawset(_G, "RENDER_ORNAMENTS", oldLevel)
local list = {}
for n, count in pairs(sizes) do list[#list + 1] = string.format("Crest%d x%d", n, count) end
table.sort(list)
assert(drawn > 0, "no frame drew a unit-frame crest, so the floor was never checked")
print(string.format("ok unit-frame crests are Crest%d or larger in %d frames (%d draw one: %s)", FLOOR, #CASES, drawn, table.concat(list, ", ")))
