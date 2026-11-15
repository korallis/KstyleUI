-- test-layout-medallions-hub.lua: under the Medallions HUD style the hub's footprint, a square the ring wide centred on the slots' top edge, never overlaps a slot of the action slab or the experience strip at any CREW screen, in all three presets: bars 1 and 2 stand on one baseline mirrored about the centre line with at least MEDALLIONS_HUB_GAP between them, the fit check counts the hub as a rect no other element may enter, and the scale limit is the largest step that fits it.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local env, K = CoreEnv.New({
	width = 1920, height = 1080, uiScale = 768 / 1080, size = "auto", fit = true,
	setup = function(e)
		e.GetPhysicalScreenSize = function()
			return 1920, 1080
		end
	end,
})
CoreEnv.Boot(env)
local Scale, Layouts = K.Scale, K.Setup.Layouts

local SCREENS = {
	{ 1280, 720 }, { 1920, 1080 }, { 2383, 1540 }, { 2560, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 3840, 1080 },
	{ 3840, 2160 }, { 5120, 1440 },
}
local RING, GAP = Layouts.MEDALLIONS_RING, Layouts.MEDALLIONS_HUB_GAP
assert(RING == 150 and GAP >= RING + 8, "the ring is 150 units and the gap holds 4 units each side of it")

local function Overlaps(a, b)
	return a[1] < b[3] - 1e-9 and b[1] < a[3] - 1e-9 and a[2] < b[4] - 1e-9 and b[2] < a[4] - 1e-9
end

local grid = Layouts.Grid("actionbars.bar1")
local slots = 0
for _, name in ipairs(Layouts.Names()) do
	for _, screen in ipairs(SCREENS) do
		local width, height = screen[1], screen[2]
		local label = string.format("%s %dx%d", name, width, height)
		local class = Scale.AspectClass(width, height)
		local positions = Layouts.Positions(name, "medallions", class)
		local one, two = positions["actionbars.bar1"], positions["actionbars.bar2"]
		assert(one.anchor == "BOTTOM" and two.anchor == "BOTTOM", label .. ": the slab's groups anchor to the bottom centre")
		assert(one.y == two.y and one.x == -two.x, label .. ": bar 1 and bar 2 share a baseline and mirror about the centre line")
		local columns, rows, groupWidth, groupHeight = Layouts.MedallionsGroup(class)
		assert(columns * rows == 12, label .. ": each group holds the bar's twelve slots")
		assert(two.x - groupWidth / 2 - (one.x + groupWidth / 2) >= GAP - 1e-9, label .. ": the groups stand at least the hub gap apart")
		local hub = { -RING / 2, one.y + groupHeight - RING / 2, RING / 2, one.y + groupHeight + RING / 2 }
		local _, xpHeight = Layouts.Footprint(name, "databars.xp")
		assert(hub[2] >= positions["databars.xp"].y + xpHeight, label .. ": the hub clears the experience strip")
		for _, bar in ipairs({ one, two }) do
			for column = 0, columns - 1 do
				for row = 0, rows - 1 do
					local left = bar.x - groupWidth / 2 + column * (grid.size + grid.spacing)
					local bottom = bar.y + row * (grid.size + grid.spacing)
					assert(not Overlaps(hub, { left, bottom, left + grid.size, bottom + grid.size }), string.format("%s: the hub overlaps a slot at column %d row %d", label, column, row))
					slots = slots + 1
				end
			end
		end
		local enabled = Layouts.Enabled(name)
		local maximum, fits = Layouts.ScaleLimit(width, height, name, enabled, "medallions")
		assert(maximum > 0 and fits(maximum), label .. ": the scale limit is a size that fits the slab and its hub")
		local moved = Layouts.Positions(name, "medallions", class)
		moved["actionbars.bar2"].x = moved["actionbars.bar2"].x - (GAP - RING) / 2 - 20
		assert(not Layouts.Fits(name, width, height, maximum, enabled, moved, "medallions"), label .. ": a group moved into the hub does not fit")
		local crowded = Layouts.Positions(name, "medallions", class)
		crowded["unitframes.player"].x, crowded["unitframes.player"].y = 0, one.y + groupHeight
		assert(not Layouts.Fits(name, width, height, maximum, enabled, crowded, "medallions"), label .. ": a unit frame placed on the hub does not fit")
	end
end
assert(slots > 0, "the test checked slots")
print("ok layout medallions hub: " .. slots .. " slot rects, " .. #SCREENS .. " screens, 3 presets")
