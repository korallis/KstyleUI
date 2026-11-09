-- test-render-scenes-classes.lua: the HUD's class-driven modules build for each of the nine classes, from the
-- addon's own code paths, and _classes.lua picks and spells the class.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Hud, Classes, check, collect = L.Hud, L.Classes, L.check, L.collect
local near, sameColour, setB = L.near, L.sameColour, L.setB

-- Every class: the player's health fill wears the class colour, the power fill reads the class's power at its
-- fraction, the cast bar names the class's cast (none for the rogue), the bars, the cluster, the buff bars and
-- the buff row show that class's spells from set B, the warrior and the druid get a stance bar, the hunter and
-- the warlock a pet frame and a pet bar, the rogue combo points.
assert(#Classes.ORDER == 9, "nine classes")
for _, class in ipairs(Classes.ORDER) do
	local spec = Classes[class]
	local tag = "hud." .. class
	local uf = check(tag .. ".unitframes", (Hud.Module("unitframes", { class = class })))
	-- The player frame paints its power bar in the power type's colour (the owner's ruling of 2026-11-08: mana
	-- blue, rage red, energy yellow, PowerBarColor lifted by Theme.Brighten, so every channel is at least the
	-- game's and the brightest channel stays the brightest), never the class colour; the power type shows as the
	-- fill's fraction. The compact pet frame draws its health only, in the reaction colour, at the pet's fraction.
	local powerColour = assert(Classes.POWER_COLORS[spec.power.token], tag .. ": _classes.lua knows the " .. spec.power.token .. " colour")
	local function brightened(vertex, base)
		if type(vertex) ~= "table" then
			return false
		end
		local maxBase, maxVertex = 1, 1
		for c = 1, 3 do
			if (vertex[c] or 0) < base[c] - 1e-3 then
				return false
			end
			if base[c] > base[maxBase] then
				maxBase = c
			end
			if (vertex[c] or 0) > (vertex[maxVertex] or 0) then
				maxVertex = c
			end
		end
		return maxBase == maxVertex
	end
	local health, power, petHealth = false, false, false
	for _, item in ipairs(uf.items) do
		if item.kind == "texture" and item.bar then
			if near(item.fraction, 2750 / 3350) and sameColour(item.vertex, spec.colour) then
				health = true
			end
			if near(item.fraction, spec.power.value / spec.power.max) and item.rect[4] < 10 and brightened(item.vertex, powerColour) and not sameColour(item.vertex, spec.colour) then
				power = true
			end
			if spec.pet and near(item.fraction, spec.pet.health / spec.pet.healthMax) and not sameColour(item.vertex, spec.colour) then
				petHealth = true
			end
		end
	end
	assert(health, tag .. ": the player's health fill wears the class colour")
	assert(power, tag .. ": the power fill reads " .. spec.power.token .. " at " .. spec.power.value .. "/" .. spec.power.max .. " in the power type's colour")
	local ufTexts = collect(uf)
	assert(ufTexts[spec.name:upper()], tag .. ": the player's name reads " .. spec.name:upper())
	if spec.cast then
		assert(ufTexts[spec.cast[1]], tag .. ": the cast bar reads " .. spec.cast[1])
	else
		assert(not ufTexts["Slam"] and not ufTexts["0.8"], tag .. ": no player cast bar")
	end
	if spec.pet then
		-- A pet name too wide in capitals drops to the body face in mixed case before it truncates (round 4: Opus #6).
		assert(ufTexts[spec.pet.name:upper()] or ufTexts[spec.pet.name], tag .. ": the pet frame reads " .. spec.pet.name .. " whole")
		assert(petHealth, tag .. ": the pet frame fills its health at " .. spec.pet.health .. "/" .. spec.pet.healthMax .. " in the reaction colour")
	end
	if spec.combo then
		local pips = 0
		for _, item in ipairs(uf.items) do
			if item.kind == "texture" and item.bar and near(item.fraction, 1) and item.rect[3] < 40 and item.rect[4] < 16 then
				pips = pips + 1
			end
		end
		assert(pips == spec.combo, tag .. ": " .. spec.combo .. " combo points lit, got " .. pips)
	end

	local ab = check(tag .. ".actionbars", (Hud.Module("actionbars", { class = class })))
	local _, abFiles = collect(ab)
	for _, slot in ipairs({ spec.bar1[1], spec.bar1[#spec.bar1], spec.bar2[1], spec.bar2[#spec.bar2] }) do
		assert(abFiles[setB(slot[2])], tag .. ": the bars show " .. slot[1])
	end
	for _, form in ipairs(spec.forms or {}) do
		assert(abFiles[setB(form[2])], tag .. ": the stance bar shows " .. form[1])
	end
	if not spec.forms then
		assert(not abFiles[setB(132349)], tag .. ": no stance bar")
	end
	for _, action in ipairs(spec.pet and spec.pet.actions or {}) do
		assert(abFiles[setB(action[2])], tag .. ": the pet bar shows " .. action[1])
	end
	assert(not abFiles[setB(132282)] or class == "WARRIOR" or class == "ROGUE", tag .. ": no warrior leftovers on the bars")

	local cd = check(tag .. ".cooldowns", (Hud.Module("cooldowns", { class = class })))
	local cdTexts, cdFiles = collect(cd)
	for _, group in ipairs({ "essential", "utility", "buffs" }) do
		for _, entry in ipairs(spec[group]) do
			assert(cdFiles[setB(entry[2])], tag .. ": the cluster shows " .. entry[1])
		end
	end
	for _, bar in ipairs(spec.bars) do
		assert(cdTexts[bar[1]], tag .. ": the buff bars read " .. bar[1])
	end
	if class ~= "WARRIOR" then
		assert(not cdTexts["Battle Shout"] and not cdTexts["Enrage"], tag .. ": no warrior buff bars")
	end

	-- The aura engine paints the buff tiles' icons itself (the module hands it the texture); with the pack
	-- installed the client shows set B's file for the ID, and so does the render.
	local auras = check(tag .. ".auras", (Hud.Module("auras", { class = class })))
	local auraTexts, auraFiles = collect(auras)
	for _, buff in ipairs(spec.buffRow) do
		assert(auraFiles[setB(buff[2])], tag .. ": the buff row shows " .. buff[1] .. " from set B")
		if buff[3] ~= "" then
			assert(auraTexts[buff[3]], tag .. ": the buff row reads " .. buff[3])
		end
	end
end
-- RENDER_CLASS picks the class when a scene names none, and an unknown class is an error that lists the nine.
assert(select(1, Classes.Get(nil)) == "WARRIOR", "the default class is the warrior")
assert(select(1, Classes.Get("mage")) == "MAGE", "Get upper-cases the class")
assert(not pcall(Classes.Get, "MONK"), "an unknown class is an error")
assert(Classes.Hex(Classes.WARRIOR.colour) == "C79C6E" and Classes.Hex(Classes.PRIEST.colour) == "FFFFFF", "Hex spells the colour")

-- One HUD scene per class (hud_<class>_mac.lua), each returning its builder.
for _, class in ipairs(Classes.ORDER) do
	local build = dofile("Tools/render/scenes/hud_" .. class:lower() .. "_mac.lua")
	assert(type(build) == "function", "hud_" .. class:lower() .. "_mac.lua returns its builder")
end

print("ok")
