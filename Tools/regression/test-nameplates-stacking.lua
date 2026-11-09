-- test-nameplates-stacking.lua: the game stacks plates by the size KstyleUI gives it, the plate's own footprint, so eight stacked plates never overlap.
local N = dofile("Tools/regression/nameplates_env.lua")

local function size(env)
	return env._plateSize[1], env._plateSize[2]
end

-- The pure rule: the footprint in the base plate's units -----------------------------------------------

do
	local env, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	local w, h = Logic.Footprint(209, 18, 48, 20, 1)
	assert(w == 209 and h == 86, "the footprint is the plate's whole width and extent, got " .. tostring(w) .. " x " .. tostring(h))
	w, h = Logic.Footprint(209, 18, 48, 20, 1.4)
	assert(w == math.ceil(209 * 1.4) and h == math.ceil(86 * 1.4), "a plate drawn larger than the base's units asks for a larger base")
	local _, tall = Logic.Footprint(209, 18, 48.4, 20, 1)
	assert(tall == 87, "a fraction rounds up, never leaving a sliver to overlap")
	assert(Logic.Footprint(209, 18, 48, 20, env.Secret(1)) == nil, "a secret scale decides nothing")
	assert(Logic.Footprint(209, 18, 48, 20, 0) == nil, "a scale of 0 decides nothing")
end

-- Live: the module sizes the game's plates to its own footprint, out of combat, and gives the size back ----

do
	local env, K, ns = N.New()
	assert(#env._plateSizeWrites >= 1, "enabling the module sets the game's nameplate size")
	-- The base's units are UIParent's times the plate's factor; the plate draws in root units. The stub's root
	-- is 0.711 of UIParent, so the footprint is 0.711 of the plate's root units; in the game, at a UI scale of
	-- 768 / 1080, both are the same and the footprint is 209 units wide.
	local ratio = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local w, h = size(env)
	-- 175 bar + 34 badge + a 16-unit raid marker and its gap.
	local WIDE, BARE = math.ceil((225 + K.Tokens.Size("gapSmall")) * ratio), math.ceil(209 * ratio)
	assert(w == WIDE, "the base is as wide as the bar, the level badge and the raid marker's room, got " .. tostring(w))
	local sample = ns.Preview.samplePlate
	local above, below = ns.Auras.Extent(sample)
	assert(h == math.ceil((above + ns.state.height + below) * ratio), "and as tall as the plate with one row of debuffs, got " .. tostring(h))
	assert(h > 45 * ratio and h < 120, "a sane height, got " .. tostring(h))

	-- A size change in combat waits.
	local writes = #env._plateSizeWrites
	env.SetCombat(true)
	K.Options.Write("Nameplates", "debuffs.size", 34)
	assert(#env._plateSizeWrites == writes, "no write in combat: the API is restricted then")
	env.SetCombat(false)
	assert(#env._plateSizeWrites == writes + 1, "the write runs when combat ends")
	local _, taller = size(env)
	assert(taller > h and taller <= h + math.ceil(8 * ratio), "larger debuffs make a taller footprint, got " .. tostring(taller) .. " from " .. tostring(h))

	-- Every row of debuffs counts, so a second row never runs into the plate above (the owner's rule).
	K.Options.Write("Nameplates", "debuffs.rows", 3)
	local _, rows = size(env)
	assert(rows > taller, "a second and third row grow the footprint, got " .. tostring(rows))
	K.Options.Write("Nameplates", "debuffs.rows", 1)
	assert(select(2, size(env)) == taller, "back to one row")

	-- Blizzard's driver sets the size again when its options change; the module puts its own back.
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	w, h = size(env)
	assert(w == WIDE and h == taller, "after the driver's own update the footprint is back")

	-- With the name, the cast bar and the debuffs off, the footprint is still never shorter than the level
	-- badge and its diamond, and the raid marker's room counts toward the width.
	K.Options.Write("Nameplates", "name.show", false)
	K.Options.Write("Nameplates", "cast.enabled", false)
	K.Options.Write("Nameplates", "debuffs.enabled", false)
	w, h = size(env)
	local badge = sample.level:GetHeight()
	local crown = 12 + K.Tokens.Size("gapTiny")
	assert(h == math.ceil((badge + crown) * ratio), "the footprint covers the badge and the diamond above it, got " .. tostring(h) .. " for a badge of " .. tostring(badge))
	assert(w == WIDE, "and the raid marker's room, got " .. tostring(w))
	K.Options.Write("Nameplates", "markers.raid", false)
	assert(size(env) == BARE, "raid markers off: the bar and the badge alone, got " .. tostring(size(env)))
	K.Options.Write("Nameplates", "markers.raid", true)
	K.Options.Write("Nameplates", "name.show", true)
	K.Options.Write("Nameplates", "cast.enabled", true)
	K.Options.Write("Nameplates", "debuffs.enabled", true)

	-- The player's size setting grows the plate against the base's units: the footprint follows.
	local before = select(2, size(env))
	K.Scale.SetUserScale(1.5)
	env.RunTimers()
	local grown = select(2, size(env))
	assert(grown > before, "a scale change resizes the footprint, got " .. tostring(grown) .. " from " .. tostring(before))
	K.Scale.SetUserScale(1)
	env.RunTimers()
	assert(select(2, size(env)) == before, "and back")

	-- The game's own size on request, and when the module turns off: the size the game last set, not the
	-- one it had when the module started.
	env._driverSize = { 160, 60 }
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	K.Options.Write("Nameplates", "stacking.footprint", "game")
	w, h = size(env)
	assert(w == 160 and h == 60, "the game's latest size is restored, got " .. tostring(w) .. " x " .. tostring(h))
	env._driverSize = { 110, 45 }
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	K.Options.Write("Nameplates", "stacking.footprint", "plate")
	assert(size(env) > 110, "and the footprint applies again")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	w, h = size(env)
	assert(w == 110 and h == 45, "Disable gives the game its size back")
	K.Modules.Enable("Nameplates")
	env.RunTimers()
	assert(size(env) == WIDE, "Enable applies the footprint again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A client without the size API: nothing breaks, and the devlog says why ----------------------------------

do
	local env, K, ns = N.New({
		setup = function(env)
			env.C_NamePlate.SetNamePlateSize = nil
			env.C_NamePlate.GetNamePlateSize = nil
		end,
	})
	N.Add(env, "nameplate1")
	assert(ns.Plates.Get("nameplate1"), "plates still attach")
	assert(#env._plateSizeWrites == 0 and #env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	local found = false
	for _, entry in ipairs(K.Store.Data().devlog) do
		if entry.message:find("SetNamePlateSize", 1, true) then
			found = true
		end
	end
	assert(found, "the devlog names the missing API")
end

print("nameplates stacking ok")
