-- test-nameplates-overflow.lua: a plate with more of the player's debuffs than its tiles shows the ones the engine ranks first and a "+N" chip after the row, counted by hidden AuraContainers' own flow layout through anchors alone, so the count stays true in combat while aura data is secret and the module never asks the game for a count.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local function chipText(chip)
	return (A.Chip(chip))
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
	local chip = plate.auraChip
	assert(chip and chipText(chip) == nil, "no debuffs, no chip")

	N.Debuffs(env, "nameplate1", 3)
	assert(shownTiles(ns, plate) == 3 and chipText(chip) == nil, "three debuffs fit; no chip")

	N.Debuffs(env, "nameplate1", 5)
	local text, face = A.Chip(chip)
	assert(text == nil and not face, "five debuffs fill the row: no chip and no sliver of its glass")

	N.Debuffs(env, "nameplate1", 8)
	assert(shownTiles(ns, plate) == 5, "five tiles show the five the engine ranks first")
	text, face = A.Chip(chip)
	assert(text == "+3" and face, "the chip counts the three that did not fit, on its own glass, got " .. tostring(text))
	assert(chip.ghost._unit == "nameplate1" and chip.ghost._groups.count.filter == plate.auras._groups[ns.Auras.GROUP].filter,
		"the chip counts the same debuffs the tiles show")
	assert(chip.ghostHost:GetAlpha() == 0, "the counting container draws nothing")
	assert(#N.Calls(env.C_UnitAuras, "GetAuraSlots") == 0, "the module never asks the game for a count")

	-- The chip sits at the end of the row, after the last tile, on the row's own line, hung from the health bar
	-- as the container is (an aura container forbids layout on anything anchored to it).
	local point, relative, relativePoint, x, y = chip.window:GetPoint(1)
	local size, spacing = ns.Auras.Grid(plate)
	assert(relative == plate.health and point == "BOTTOMLEFT" and relativePoint == "TOPLEFT", "the chip hangs from the bar as the container does")
	local _, containerRelative, _, cx, cy = plate.auras:GetPoint(1)
	assert(containerRelative == plate.health and N.Same(x - cx, 5 * size + 5 * spacing) and N.Same(y, cy), "one tile pitch past the fifth tile, level with the row, got " .. tostring(x - cx))
	assert(N.Same(chip.window:GetHeight(), size) and N.Same(chip.window:GetWidth(), size), "a tile's size")

	N.Debuffs(env, "nameplate1", 17)
	assert(chipText(chip) == "+12", "twelve more: +12")
	N.Debuffs(env, "nameplate1", 40)
	assert(chipText(chip) == "+" .. ns.Auras.OVERFLOW_MAX, "the count stops at the cap, got " .. tostring(chipText(chip)))

	N.Debuffs(env, "nameplate1", 5)
	assert(chipText(chip) == nil, "back to five: the chip goes")

	-- A second row takes ten before the chip appears.
	K.Options.Write("Nameplates", "debuffs.rows", 2)
	N.Debuffs(env, "nameplate1", 12)
	assert(shownTiles(ns, plate) == 10 and chipText(chip) == "+2", "two rows show ten, the chip the other two, got " .. tostring(chipText(chip)))
	K.Options.Write("Nameplates", "debuffs.rows", 1)

	-- The plate leaves and its base comes back for another unit: the chip counts the new unit.
	local base = env._bases.nameplate1
	N.Remove(env, "nameplate1")
	assert(not chip.window:IsShown(), "a detached plate shows no chip")
	assert(chip.ghost._unit == "none", "and its counting container lets the unit go")
	N.Add(env, "nameplate2", { name = "Clean Mob" }, { base = base })
	assert(ns.Plates.Get("nameplate2") == plate and chip.ghost._unit == "nameplate2", "the reused plate counts its new unit")
	N.Debuffs(env, "nameplate2", 0)
	assert(chipText(chip) == nil, "which has none")
	N.Debuffs(env, "nameplate2", 7)
	assert(chipText(chip) == "+2", "and counts again when that unit gains debuffs")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- In a pull aura data is secret: the chip keeps counting through the engine's layout, and never asks --------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Debuffs(env, "nameplate1", 9)
	assert(chipText(plate.auraChip) == "+4", "+4 while aura data is open")
	env._aurasSecret = true
	env.SetCombat(true)
	N.Debuffs(env, "nameplate1", 12)
	assert(chipText(plate.auraChip) == "+7", "in the pull the chip follows the debuffs: +7, got " .. tostring(chipText(plate.auraChip)))
	N.Debuffs(env, "nameplate1", 4)
	assert(chipText(plate.auraChip) == nil, "and goes when they fit again, with no stale count")
	N.Debuffs(env, "nameplate1", 8)
	assert(chipText(plate.auraChip) == "+3", "and comes back: +3")
	assert(#N.Calls(env.C_UnitAuras, "GetAuraSlots") == 0, "no count was asked for, which would raise while secret")
	env.SetCombat(false)
	env._aurasSecret = false
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

	-- A client without the slot API counts the same way: the chip never needed it.
	local env2, K2, ns2 = N.New({
		setup = function(e)
			e.C_UnitAuras.GetAuraSlots = nil
		end,
	})
	N.Add(env2, "nameplate1")
	N.Debuffs(env2, "nameplate1", 9)
	assert(chipText(ns2.Plates.Get("nameplate1").auraChip) == "+4", "no slot API, the chip still counts")
	assert(#env2._errors == 0 and K2.ErrorCount() == 0, tostring(env2._errors[1]))
end

-- Which debuffs win the tiles: the engine sorts, by the order setting ------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local Sort, Dir = env.AuraContainerSortMethod, env.AuraContainerSortDirection
	local function order()
		local group = plate.auras._groups[ns.Auras.GROUP]
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
