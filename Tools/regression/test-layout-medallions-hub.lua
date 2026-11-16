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
		local columns, rows, groupWidth, groupHeight, size, spacing = Layouts.MedallionsGroup(class)
		assert(rows == 1 and columns == 12, label .. ": each group holds the bar's twelve slots in one row, got " .. columns .. "x" .. rows)
		assert(size >= Layouts.MEDALLIONS_SLOT.floor, label .. ": the slots keep the slot floor")
		assert(two.x - groupWidth / 2 - (one.x + groupWidth / 2) >= GAP - 1e-9, label .. ": the groups stand at least the hub gap apart")
		local hub = { -RING / 2, one.y + groupHeight - RING / 2, RING / 2, one.y + groupHeight + RING / 2 }
		local xp, slab = Layouts.Aspect(class, "medallions", name, "databars.xp") or Layouts.Style("medallions", name, "databars.xp"), Layouts.MEDALLIONS_SLAB
		assert(xp.anchor == "BOTTOM" and xp.x == 0 and math.abs(xp.width - (two.x + groupWidth / 2 - (one.x - groupWidth / 2))) < 1e-9, label .. ": the experience strip spans both groups and the gap")
		assert(math.abs(xp.y + xp.height + slab.stripGap - one.y) < 1e-9, label .. ": the experience strip runs along the slab's lower edge, under the slots")
		for _, bar in ipairs({ one, two }) do
			for column = 0, columns - 1 do
				for row = 0, rows - 1 do
					local left = bar.x - groupWidth / 2 + column * (size + spacing)
					local bottom = bar.y + row * (size + spacing)
					assert(not Overlaps(hub, { left, bottom, left + size, bottom + size }), string.format("%s: the hub overlaps a slot at column %d row %d", label, column, row))
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
do
	local function Only(key, other)
		return setmetatable({ [key] = true, [other or key] = true }, { __index = function() return false end })
	end
	for key, diameter in pairs({ ["unitframes.player"] = 86, ["unitframes.target"] = 86, ["unitframes.pet"] = 56 }) do
		assert(Layouts.MEDALLIONS_MEDALS[key].d == diameter, key .. ": Fits must use the rendered medallion diameter")
		local at = Layouts.Positions("DPS", "medallions", "16:9")
		local right = key == "unitframes.target"
		at[key] = { anchor = right and "BOTTOMRIGHT" or "BOTTOMLEFT", x = 0, y = 200 }
		assert(not Layouts.Fits("DPS", 1920, 1080, 1, Only(key), at, "medallions"), key .. ": Fits must count the square medallion overhang at the screen edge")
		at[key].x = right and -50 or 50
		assert(Layouts.Fits("DPS", 1920, 1080, 1, Only(key), at, "medallions"), key .. ": moving the whole medallion on screen must fit")
	end
	local at = Layouts.Positions("DPS", "medallions", "16:9")
	at["unitframes.player"] = { anchor = "BOTTOMLEFT", x = 300, y = 200 }
	at["unitframes.targettarget"] = { anchor = "BOTTOMLEFT", x = 90, y = 205 }
	local enabled = Only("unitframes.player", "unitframes.targettarget")
	assert(not Layouts.Fits("DPS", 1920, 1080, 1, enabled, at, "medallions"), "Fits must reject another slab on the medallion's square, even when the unit slabs are clear")
	at["unitframes.targettarget"].x = 80
	assert(Layouts.Fits("DPS", 1920, 1080, 1, enabled, at, "medallions"), "Fits must accept the same slabs once the medallion is clear")
end
assert(slots > 0, "the test checked slots")
print("ok layout medallions hub: " .. slots .. " slot rects, " .. #SCREENS .. " screens, 3 presets")
