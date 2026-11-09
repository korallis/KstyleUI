-- test-nameplates-overflow.lua: a plate with more of the player's debuffs than its tiles shows the ones the engine ranks first and a "+N" chip, counted only while aura data is open, and hidden while it is secret.
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
	local chip = plate.auraChip
	assert(chip and not chip:IsShown(), "no debuffs, no chip")

	N.Debuffs(env, "nameplate1", 3)
	assert(shownTiles(ns, plate) == 3 and not chip:IsShown(), "three debuffs fit; no chip")

	N.Debuffs(env, "nameplate1", 8)
	assert(shownTiles(ns, plate) == 5, "five tiles show the five the engine ranks first")
	assert(chip:IsShown() and chipText(chip) == "+3", "the chip counts the three that did not fit, got " .. tostring(chipText(chip)))
	local slots = N.Last(env.C_UnitAuras, "GetAuraSlots")
	assert(slots and slots[1] == "nameplate1" and slots[2] == plate.auras._groups[ns.Auras.GROUP].filter, "the count asks the game for the same debuffs the tiles show")
	assert(slots[3] == 5 + ns.Auras.OVERFLOW_MAX, "and asks for no more slots than the tiles plus the cap")

	-- The chip sits at the end of the row, after the last tile, on the row's own line, hung from the health bar
	-- (an aura container forbids layout on anything anchored to it).
	local point, relative, relativePoint, x = chip:GetPoint(1)
	local size, spacing = ns.Auras.Grid(plate)
	assert(relative == plate.health and point == "BOTTOMLEFT" and relativePoint == "TOPLEFT", "the chip hangs from the bar as the container does")
	local _, containerRelative, _, cx, cy = plate.auras:GetPoint(1)
	local _, _, _, _, y = chip:GetPoint(1)
	assert(containerRelative == plate.health and N.Same(x - cx, 5 * size + 5 * spacing) and N.Same(y, cy), "one tile pitch past the fifth tile, level with the row, got " .. tostring(x - cx))
	assert(N.Same(chip:GetHeight(), size), "as tall as a tile")

	N.Debuffs(env, "nameplate1", 17)
	assert(chipText(chip) == "+12", "twelve more: +12")
	N.Debuffs(env, "nameplate1", 40)
	assert(chipText(chip) == "+" .. ns.Auras.OVERFLOW_MAX, "the count stops at the cap")

	N.Debuffs(env, "nameplate1", 5)
	assert(not chip:IsShown(), "back to five: the chip hides")

	-- A second row takes ten before the chip appears.
	K.Options.Write("Nameplates", "debuffs.rows", 2)
	N.Debuffs(env, "nameplate1", 12)
	assert(shownTiles(ns, plate) == 10 and chipText(chip) == "+2", "two rows show ten, the chip the other two")
	K.Options.Write("Nameplates", "debuffs.rows", 1)

	-- The plate leaves and its base comes back for a unit with no debuffs: no stale count.
	local base = env._bases.nameplate1
	N.Remove(env, "nameplate1")
	assert(not chip:IsShown(), "a detached plate shows no chip")
	N.Add(env, "nameplate2", { name = "Clean Mob" }, { base = base })
	assert(ns.Plates.Get("nameplate2") == plate and not chip:IsShown(), "the reused plate counts its new unit, which has none")
	N.Debuffs(env, "nameplate2", 7)
	assert(chipText(chip) == "+2", "and counts again when that unit gains debuffs")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- While auras are secret the game refuses the count: the chip hides rather than guess, and nothing errors -------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	N.Debuffs(env, "nameplate1", 9)
	assert(plate.auraChip:IsShown(), "+4 while aura data is open")
	env._aurasSecret = true
	local calls = #N.Calls(env.C_UnitAuras, "GetAuraSlots")
	env.FireEvent("UNIT_AURA", "nameplate1")
	assert(not plate.auraChip:IsShown(), "the chip hides while auras are secret")
	assert(#N.Calls(env.C_UnitAuras, "GetAuraSlots") == calls, "and the module never asks the game, which would raise")
	env._aurasSecret = false
	env.FireEvent("UNIT_AURA", "nameplate1")
	assert(plate.auraChip:IsShown() and chipText(plate.auraChip) == "+4", "open again: the chip is back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

	-- A client without the slot API: no chip, no error, one devlog line.
	local env2, K2, ns2 = N.New({
		setup = function(e)
			e.C_UnitAuras.GetAuraSlots = nil
		end,
	})
	N.Add(env2, "nameplate1")
	N.Debuffs(env2, "nameplate1", 9)
	assert(not ns2.Plates.Get("nameplate1").auraChip:IsShown(), "no slot API, no chip")
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
