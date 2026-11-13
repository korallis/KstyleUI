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
	K.Options.Write("Nameplates", "level.show", true)
	assert(#env._plateSizeWrites >= 1, "enabling the module sets the game's nameplate size")
	-- The base's units are UIParent's times the plate's factor; the plate draws in root units. The stub's root
	-- is 0.711 of UIParent, so the footprint is 0.711 of the plate's root units; in the game, at a UI scale of
	-- 768 / 1080, both are the same and the footprint is 209 units wide.
	local ratio = K.Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	local w, h = size(env)
	-- The bar, the level diamond beyond the left bracket and the name's overhang at the right, which is wider than
	-- the raid marker beyond the right bracket (the KSTY-44 bible's plate).
	local width, Plate = ns.state.width, ns.Plate
	local raidRoom = Plate.BRACKET_REACH + 16
	local NAMED = math.ceil((width + Plate.DiamondReach(ns.Preview.samplePlate) + math.max(Plate.NAME_OVERHANG, raidRoom)) * ratio)
	local WIDE = math.ceil((width + Plate.DiamondReach(ns.Preview.samplePlate) + raidRoom) * ratio)
	local BARE = math.ceil((width + Plate.DiamondReach(ns.Preview.samplePlate) + Plate.BRACKET_REACH) * ratio)
	assert(w == NAMED, "the base is as wide as the bar, the level diamond and the name's overhang, got " .. tostring(w))
	local sample = ns.Preview.samplePlate
	local _, above, _, below = ns.Stacking.Extent()
	assert(h == math.ceil((above + ns.state.height + below) * ratio), "and as tall as the plate with one row of debuffs, got " .. tostring(h))
	assert(h > 45 * ratio and h < 120, "a sane height, got " .. tostring(h))

	-- A size change in combat waits.
	local writes = #env._plateSizeWrites
	env.SetCombat(true)
	K.Options.Write("Nameplates", "debuffs.size", 34)
	assert(#env._plateSizeWrites == writes, "no write in combat: the API is restricted then")
	env.SetCombat(false)
	assert(#env._plateSizeWrites == writes + 1, "the write runs when combat ends")
	local auraWidth, taller = size(env)
	assert(auraWidth > NAMED, "a wide aura row and its overflow chip grow the horizontal footprint too")
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
	assert(w == auraWidth and h == taller, "after the driver's own update the whole resized footprint is back")

	-- With the name, the cast bar and the debuffs off, the footprint is still never shorter than the level
	-- diamond, and the raid marker's room beyond the right bracket counts toward the width.
	K.Options.Write("Nameplates", "name.show", false)
	K.Options.Write("Nameplates", "cast.enabled", false)
	K.Options.Write("Nameplates", "debuffs.enabled", false)
	w, h = size(env)
	local _ = sample
	assert(h == math.ceil(Plate.DiamondSize(sample) * ratio), "the footprint covers the level diamond, got " .. tostring(h))
	assert(N.Same(env.Look(sample.level:GetHeight()), Plate.DiamondSize(sample)), "the drawn diamond is that height")
	assert(w == WIDE, "and the raid marker's room, got " .. tostring(w))
	K.Options.Write("Nameplates", "markers.raid", false)
	assert(size(env) == BARE, "raid markers off: the bar, the diamond and the brackets alone, got " .. tostring(size(env)))
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
	assert(size(env) == auraWidth, "Enable applies the resized footprint again")
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

-- The game's plate scale: held at 1 while plates ignore it, never written in combat, and given back -------
-- The engine scales each base by nameplateMinScale to nameplateMaxScale with distance and by
-- nameplateSelectedScale on the target, and stacks by the footprint times that scale. With Shrink distant
-- plates off the plate ignores that scale, so the box and the drawn plate agree only at a scale of 1.

local CoreEnv = dofile("Tools/regression/core_env.lua")

local function scales(env)
	return env._cvars.nameplateMinScale, env._cvars.nameplateMaxScale, env._cvars.nameplateSelectedScale
end

local function held(env)
	local min, max, selected = scales(env)
	return min == "1" and max == "1" and selected == "1"
end

local function wrote(env, from)
	for i = from + 1, #env._cvarWrites do
		local name = env._cvarWrites[i].name
		if name == "nameplateMinScale" or name == "nameplateMaxScale" or name == "nameplateSelectedScale" then
			return name
		end
	end
	return nil
end

local function logged(K, text)
	for _, entry in ipairs(K.Store.Data().devlog) do
		if entry.module == "Nameplates" and entry.message:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function player(env)
	env._cvars.nameplateMaxScale = "1.1"
end

do
	local env, K = N.New({ setup = player })
	assert(held(env), "the defaults hold all three scale CVars at 1, got " .. table.concat({ scales(env) }, ", "))
	local records = K.Store.Account().nameplateScaleCVars[K.Store.CharacterKey()]
	assert(records.nameplateMinScale.original == "0.8" and records.nameplateMaxScale.original == "1.1"
		and records.nameplateSelectedScale.original == "1.2", "the game's own values are kept per character")
	assert(logged(K, "nameplateSelectedScale is held at 1"), "the devlog says which CVar is held and why")

	-- Turning Shrink distant plates on gives the values back, only once combat ends.
	env.SetCombat(true)
	local writes = #env._cvarWrites
	K.Options.Write("Nameplates", "shrinkDistant", true)
	env.RunTimers()
	assert(wrote(env, writes) == nil and held(env), "no scale CVar is written in combat")
	env.SetCombat(false)
	local min, max, selected = scales(env)
	assert(min == "0.8" and max == "1.1" and selected == "1.2", "Shrink distant plates on: the game's own values are back, got " .. table.concat({ min, max, selected }, ", "))
	assert(K.Store.Account().nameplateScaleCVars == nil, "and nothing is left to give back")

	K.Options.Write("Nameplates", "shrinkDistant", false)
	assert(held(env), "off again: held at 1 again")

	-- A target change and a whole fight write nothing.
	N.Add(env, "nameplate1")
	N.Add(env, "nameplate2")
	env.SetCombat(true)
	writes = #env._cvarWrites
	N.Target(env, "nameplate1")
	N.Target(env, "nameplate2")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(wrote(env, writes) == nil and held(env), "a disable in combat waits")
	env.SetCombat(false)
	min, max, selected = scales(env)
	assert(min == "0.8" and max == "1.1" and selected == "1.2", "Disable gives the game its own values back")

	K.Modules.Enable("Nameplates")
	env.RunTimers()
	assert(held(env), "Enable holds them again")

	-- A value the player sets while the module holds it stays the player's.
	env._cvars.nameplateSelectedScale = "1.4"
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(env._cvars.nameplateSelectedScale == "1.4" and env._cvars.nameplateMinScale == "0.8", "Disable leaves the player's own change alone")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Off by default in a profile that shrinks plates: nothing is written.

do
	local env = N.New({ setup = player, enable = false })
	assert(wrote(env, 0) == nil, "with the module off no scale CVar is written")
end

-- A reload keeps what to give back: the CVars come back from the client as 1, the record from the saved data.

do
	local env, K = N.New({ setup = player })
	assert(held(env))
	CoreEnv.Logout(env)
	local saved = CoreEnv.DeepCopy(env.KstyleUIDB)
	local quiet = CoreEnv.DeepCopy(saved)
	quiet.profiles.Default.Nameplates.enabled = false
	local shrunk = CoreEnv.DeepCopy(saved)
	shrunk.profiles.Default.Nameplates.shrinkDistant = true
	local again, K2 = N.New({
		saved = saved,
		setup = function(e)
			e._cvars.nameplateMinScale, e._cvars.nameplateMaxScale, e._cvars.nameplateSelectedScale = "1", "1", "1"
		end,
	})
	assert(held(again) and wrote(again, 0) == nil, "after a reload the held values are not written again")
	K2.Modules.Disable("Nameplates")
	again.RunTimers()
	local min, max, selected = scales(again)
	assert(min == "0.8" and max == "1.1" and selected == "1.2", "and Disable still gives back the values from before the reload")
	assert(K ~= K2)

	-- A login with the module off on this character: the core's sweep gives the values back.
	local off = N.New({
		saved = quiet,
		enable = false,
		setup = function(e)
			e._cvars.nameplateMinScale, e._cvars.nameplateMaxScale, e._cvars.nameplateSelectedScale = "1", "1", "1"
		end,
	})
	off.RunTimers()
	min, max, selected = scales(off)
	assert(min == "0.8" and max == "1.1" and selected == "1.2", "a login with the module off gives the values back, got " .. table.concat({ min, max, selected }, ", "))

	-- Shrink distant plates turned on in combat, then a reload before combat ended: the module is still on, so
	-- the next login gives the values back itself.
	local late = N.New({
		saved = shrunk,
		setup = function(e)
			e._cvars.nameplateMinScale, e._cvars.nameplateMaxScale, e._cvars.nameplateSelectedScale = "1", "1", "1"
		end,
	})
	min, max, selected = scales(late)
	assert(min == "0.8" and max == "1.1" and selected == "1.2", "a login that shrinks plates gives back a queued give-back, got " .. table.concat({ min, max, selected }, ", "))
end

-- The character's CVars can load after the modules start: nothing is read or written before they do.

do
	local env, K = N.New({ setup = player, lateVariables = true })
	assert(wrote(env, 0) == nil and env._cvars.nameplateMaxScale == "1.1", "nothing is held before VARIABLES_LOADED")
	env.FireEvent("VARIABLES_LOADED")
	env.RunTimers()
	assert(held(env), "and all three are held once it fires")
	assert(K.Store.Account().nameplateScaleCVars[K.Store.CharacterKey()].nameplateMaxScale.original == "1.1")
end

-- A client without one of the CVars: the others are held, the devlog names the missing one.

do
	local env, K = N.New({ setup = function(e) e._cvars.nameplateMaxScale = nil end })
	assert(env._cvars.nameplateMinScale == "1" and env._cvars.nameplateSelectedScale == "1", "the CVars the client has are held")
	assert(logged(K, "CVar nameplateMaxScale is missing"), "the devlog names the missing CVar")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(env._cvars.nameplateMinScale == "0.8" and env._cvars.nameplateMaxScale == nil)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- With Manage these settings on, the held scale CVars stay at 1 until Shrink distant plates turns on.

do
	local env, K = N.New()
	K.Options.Write("Nameplates", "cvars.enabled", true)
	K.Options.Write("Nameplates", "cvars.minScale", 0.6)
	assert(held(env), "the managed scale sliders do not undo the hold")
	K.Options.Write("Nameplates", "shrinkDistant", true)
	assert(env._cvars.nameplateMinScale == "0.6" and env._cvars.nameplateSelectedScale == "1.2", "Shrink distant plates on: the managed values apply")
	K.Options.Write("Nameplates", "shrinkDistant", false)
	assert(held(env), "and off again holds them")
	K.Options.Write("Nameplates", "cvars.enabled", false)
	assert(held(env), "turning management off leaves the hold")
	K.Options.Write("Nameplates", "shrinkDistant", true)
	assert(env._cvars.nameplateMinScale == "0.8" and env._cvars.nameplateSelectedScale == "1.2", "then the game's defaults, as management off promises")

	-- A value management wrote is never kept as the player's own.
	K.Options.Write("Nameplates", "cvars.enabled", true)
	assert(env._cvars.nameplateMinScale == "0.6", "management applies its own value with plates shrinking")
	K.Options.Write("Nameplates", "shrinkDistant", false)
	local record = K.Store.Account().nameplateScaleCVars[K.Store.CharacterKey()].nameplateMinScale
	assert(held(env) and record.original == "0.8", "the hold keeps the game's default, not management's 0.6, got " .. tostring(record.original))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- Scale CVars already at 1: nothing to hold or give back, and the managed sliders still apply on leaving the hold.

do
	local env, K = N.New({
		setup = function(e)
			e._cvars.nameplateMinScale, e._cvars.nameplateSelectedScale = "1", "1"
		end,
	})
	assert(held(env) and wrote(env, 0) == nil, "nothing is written when the game already draws at 1")
	K.Options.Write("Nameplates", "cvars.enabled", true)
	K.Options.Write("Nameplates", "cvars.minScale", 0.6)
	assert(held(env), "held while plates ignore the scale")
	K.Options.Write("Nameplates", "shrinkDistant", true)
	assert(env._cvars.nameplateMinScale == "0.6" and env._cvars.nameplateSelectedScale == "1.2", "the managed values apply once the hold ends, got " .. tostring(env._cvars.nameplateMinScale))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- When Blizzard's driver resets the nameplate size in combat, the devlog says so.

do
	local env, K = N.New()
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	assert(not logged(K, "in combat"), "a reset out of combat is not a combat reset")
	env.SetCombat(true)
	env._driverSize = { 238, 95 }
	local guarded = env.C_NamePlate.SetNamePlateSize
	env.C_NamePlate.SetNamePlateSize = function(w, h)
		env._plateSize = { w, h }
	end
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	env.C_NamePlate.SetNamePlateSize = guarded
	assert(logged(K, "Blizzard reset the nameplate size in combat to 238 x 95"), "the devlog records the reset and the size")
	env.SetCombat(false)
	assert(size(env) ~= 238, "the footprint is back when combat ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("nameplates stacking ok")
