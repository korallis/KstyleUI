-- test-nameplates-overflow.lua: a plate with more of the player's debuffs than its tiles shows the important ones and a "+N" chip, counted from the engine's own frames without reading an aura.
local N = dofile("Tools/regression/nameplates_env.lua")

-- chipText(chip) -> what the chip last formatted: the stub records SetFormattedText's arguments.
local function chipText(chip)
	local call = N.Last(chip.text, "SetFormattedText")
	return call and string.format(unpack(call)) or nil
end

local function shownTiles(ns, plate)
	local container, n = plate.auras, 0
	for i = 1, container:GetAuraGroupFrameCount(ns.Auras.GROUP) do
		if container:GetAuraGroupFrame(ns.Auras.GROUP, i):IsShown() then
			n = n + 1
		end
	end
	return n
end

-- Eight debuffs on five tiles: the five show, the chip says +3 -----------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.auras, "the plate has its debuff container")
	assert(plate.auras._groups[ns.Auras.TALLY], "and a second, tallying group on the same filter")
	assert(plate.auras._groups[ns.Auras.TALLY].filter == plate.auras._groups[ns.Auras.GROUP].filter, "the tally sees the same debuffs")
	assert(plate.auras._groups[ns.Auras.TALLY].maxFrameCount == 5 + ns.Auras.OVERFLOW_MAX, "and counts up to the tiles plus the overflow cap")
	local chip = plate.auraChip
	assert(chip and not chip:IsShown(), "no debuffs, no chip")

	N.Debuffs(env, "nameplate1", 3)
	env.RunTimers()
	assert(shownTiles(ns, plate) == 3 and not chip:IsShown(), "three debuffs fit; no chip")

	N.Debuffs(env, "nameplate1", 8)
	env.RunTimers()
	assert(shownTiles(ns, plate) == 5, "five tiles show the five the engine ranks first")
	assert(chip:IsShown() and chipText(chip) == "+3", "the chip counts the three that did not fit, got " .. tostring(chipText(chip)))
	-- The chip sits at the end of the row, after the last tile, on the row's own line.
	local point, relative, relativePoint, x, y = chip:GetPoint(1)
	local size, spacing = ns.Auras.Grid(plate)
	assert(relative == plate.auras and point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT", "the chip hangs from the container's anchor corner")
	assert(N.Same(x, 5 * size + 5 * spacing) and y == 0, "one tile pitch past the fifth tile, got " .. tostring(x))
	assert(N.Same(chip:GetHeight(), size), "as tall as a tile")

	N.Debuffs(env, "nameplate1", 17)
	env.RunTimers()
	assert(chipText(chip) == "+12", "twelve more: +12")
	N.Debuffs(env, "nameplate1", 40)
	env.RunTimers()
	assert(chipText(chip) == "+" .. ns.Auras.OVERFLOW_MAX, "the count stops at the tally's cap")

	N.Debuffs(env, "nameplate1", 5)
	env.RunTimers()
	assert(not chip:IsShown(), "back to five: the chip hides")

	-- A second row takes ten before the chip appears.
	K.Options.Write("Nameplates", "debuffs.rows", 2)
	N.Debuffs(env, "nameplate1", 12)
	env.RunTimers()
	assert(shownTiles(ns, plate) == 10 and chipText(chip) == "+2", "two rows show ten, the chip the other two")
	assert(plate.auras._groups[ns.Auras.TALLY].maxFrameCount == 10 + ns.Auras.OVERFLOW_MAX, "the tally grows with the tiles")
	K.Options.Write("Nameplates", "debuffs.rows", 1)

	-- The plate leaves and comes back for another unit: the count starts over.
	N.Remove(env, "nameplate1")
	env.RunTimers()
	assert(not chip:IsShown(), "a detached plate shows no chip")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- While auras are secret, the chip still counts: it never calls the engine's buttons ------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	env._aurasSecret = true
	N.Debuffs(env, "nameplate1", 9)
	env.RunTimers()
	assert(plate.auraChip:IsShown() and chipText(plate.auraChip) == "+4", "the chip counts under secrets")
	N.Debuffs(env, "nameplate1", 2)
	env.RunTimers()
	assert(not plate.auraChip:IsShown(), "and clears under secrets")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no aura button was touched: " .. tostring(env._errors[1]))
end

-- Which debuffs win the tiles: the engine sorts, by the order setting ------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local Sort, Dir = env.AuraContainerSortMethod, env.AuraContainerSortDirection
	local function order()
		local group, tally = plate.auras._groups[ns.Auras.GROUP], plate.auras._groups[ns.Auras.TALLY]
		assert(group.sortMethod == tally.sortMethod and group.sortDirection == tally.sortDirection, "the tally sorts as the tiles do")
		return group.sortMethod, group.sortDirection
	end
	local method, direction = order()
	assert(method == Sort.ImportantOnly and direction == Dir.Normal, "by default the game's important debuffs come first")
	K.Options.Write("Nameplates", "debuffs.order", "longest")
	method, direction = order()
	assert(method == Sort.ExpirationOnly and direction == Dir.Reverse, "longest: the most time left first")
	K.Options.Write("Nameplates", "debuffs.order", "expiring")
	method, direction = order()
	assert(method == Sort.Expiration and direction == Dir.Normal, "expiring: the soonest to fade first")
	K.Options.Write("Nameplates", "debuffs.order", "default")
	method, direction = order()
	assert(method == Sort.Default and direction == Dir.Normal, "default: the game's own order")
	assert(ns.Settings.Row("debuffs.order").type == "dropdown", "the order is a dropdown on the page")
end

-- The footprint the game stacks by counts every row of tiles, so a second row never runs into the plate above ----

do
	local env, K, ns = N.New()
	local _, one = env._plateSize[1], env._plateSize[2]
	K.Options.Write("Nameplates", "debuffs.rows", 2)
	local _, two = env._plateSize[1], env._plateSize[2]
	local size, spacing = ns.Auras.Grid(ns.Preview.samplePlate)
	local ratio = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	assert(two > one and two - one <= math.ceil((size + spacing) * ratio) + 1, "a second row adds a tile pitch to the footprint, got " .. tostring(two - one))
end

print("nameplates overflow ok")
