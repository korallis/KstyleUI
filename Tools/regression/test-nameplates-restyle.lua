-- test-nameplates-restyle.lua: a restyle is idempotent. However often and by whichever path a plate is restyled (added, re-added on a pooled base, the target changing, a setting, the HUD style, the theme or the HUD size changing and coming back, combat, a reload), it hangs from the same point of its base at the same size, its stacking bounds stay put, and the game keeps Blizzard's own nameplate size (#373).
local N = dofile("Tools/regression/nameplates_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")

local RESTYLES = 12

local function fmt(v)
	return type(v) == "number" and string.format("%.6f", v) or tostring(v)
end

-- Where the plate hangs and how big it is, and the same for its stacking bounds, as text, so two reads compare
-- exactly and a failure prints both.
local function shape(plate)
	local point, relative, relativePoint, x, y = plate:GetPoint(1)
	local parts = {
		"plate " .. tostring(point) .. " " .. (relative == plate.base and "base" or tostring(relative)) .. " " .. tostring(relativePoint),
		"x " .. fmt(x), "y " .. fmt(y), "w " .. fmt(plate:GetWidth()), "h " .. fmt(plate:GetHeight()),
	}
	local bounds = plate.stackBounds
	if bounds and bounds:GetNumPoints() > 0 then
		local bp, brel, brp, bx, by = bounds:GetPoint(1)
		parts[#parts + 1] = "bounds " .. tostring(bp) .. " " .. (brel == plate and "plate" or brel == plate.base and "base" or tostring(brel))
			.. " " .. tostring(brp) .. " " .. fmt(bx) .. " " .. fmt(by) .. " " .. fmt(bounds:GetWidth()) .. " x " .. fmt(bounds:GetHeight())
	end
	return table.concat(parts, ", ")
end

local function blizzardKept(env, label, blizzard)
	if not blizzard then
		return
	end
	assert(#env._plateSizeWrites == 0, label .. ": the game keeps its own nameplate size, got " .. #env._plateSizeWrites .. " writes")
	assert(env._plateSize[1] == blizzard.width and env._plateSize[2] == blizzard.height, label .. ": Blizzard's own box")
end

local function boot(case, saved)
	local env, K, ns = N.New({
		saved = saved,
		stackingBounds = case.bounds,
		nameplateSize = case.size,
		width = case.screen[1],
		height = case.screen[2],
	})
	if case.scale ~= 1 then
		K.Scale.SetUserScale(case.scale)
		env.RunTimers()
	end
	for key, value in pairs(case.settings or {}) do
		K.Options.Write("Nameplates", key, value)
	end
	env.RunTimers()
	return env, K, ns
end

local function run(case)
	local label = (case.bounds and "stacking bounds" or "nameplate size") .. ", " .. case.screen[1] .. "x" .. case.screen[2]
		.. ", HUD " .. case.scale .. ", nameplateSize " .. case.size .. (case.tag and (", " .. case.tag) or "")
	local blizzard = case.bounds and N.Blizzard(case.size) or nil
	local env, K, ns = boot(case)
	local scale = env.UIParent:GetEffectiveScale()
	N.Add(env, "nameplate1", case.unit, { scale = scale })
	local plate = ns.Plates.Get("nameplate1")
	local want = shape(plate)

	local function same(what)
		local got = shape(plate)
		assert(got == want, label .. ", " .. what .. ": the plate moved\n  was " .. want .. "\n  now " .. got)
		blizzardKept(env, label .. ", " .. what, blizzard)
	end

	env.RunTimers()
	same("after the plate was added")

	for i = 1, RESTYLES do
		ns.Plates.RestyleAll()
		same("restyle " .. i)
	end
	env.RunTimers()
	same("after the restyles settled")

	for i = 1, 6 do
		N.Target(env, i % 2 == 1 and "nameplate1" or nil)
		N.Settle(env)
		same("target change " .. i)
	end

	for i = 1, 2 do
		K.Options.Write("Nameplates", "cast.enabled", false)
		K.Options.Write("Nameplates", "cast.enabled", true)
		env.RunTimers()
		same("cast bars off and on " .. i)
		K.Options.Write("Nameplates", "debuffs.rows", 3)
		K.Options.Write("Nameplates", "debuffs.rows", 1)
		env.RunTimers()
		same("debuff rows 3 and back " .. i)
	end

	for _, style in ipairs({ "orbs", "medallions", "frames" }) do
		K.Options.Write("HudStyle", "style", style)
		env.RunTimers()
		same("HUD style " .. style)
	end

	for i = 1, 3 do
		K.Callbacks.Fire("ThemeChanged")
		same("theme change " .. i)
	end

	for _, other in ipairs({ 16 / 19 }) do
		if other ~= case.scale then
			K.Scale.SetUserScale(other)
			env.RunTimers()
			K.Scale.SetUserScale(case.scale)
			env.RunTimers()
			same("HUD size " .. other .. " and back")
		end
	end

	N.Remove(env, "nameplate1")
	N.Add(env, "nameplate1", case.unit, { base = plate.base })
	assert(ns.Plates.Get("nameplate1") == plate, label .. ": a re-added unit reuses its base's plate")
	same("re-added on its pooled base")

	N.Add(env, "nameplate2", case.unit, { scale = scale })
	local second = ns.Plates.Get("nameplate2")
	assert(shape(second) == want, label .. ": a second plate hangs where the first does\n  first  " .. want .. "\n  second " .. shape(second))

	env.SetCombat(true)
	N.Add(env, "nameplate3", case.unit, { scale = scale })
	local third = ns.Plates.Get("nameplate3")
	assert(shape(third) == want, label .. ": a plate built in combat hangs where the others do\n  others " .. want .. "\n  combat " .. shape(third))
	for i = 1, 4 do
		N.Target(env, i % 2 == 1 and "nameplate3" or "nameplate1")
		N.Settle(env)
		assert(shape(third) == want and shape(second) == want, label .. ": nothing moves in combat on target change " .. i)
	end
	env.SetCombat(false)
	env.RunTimers()
	same("after combat")
	assert(shape(second) == want and shape(third) == want, label .. ": every plate keeps its place after combat")
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": " .. tostring(env._errors[1]))

	CoreEnv.Logout(env)
	local again, K2, ns2 = boot(case, CoreEnv.DeepCopy(env.KstyleUIDB))
	N.Add(again, "nameplate1", case.unit, { scale = again.UIParent:GetEffectiveScale() })
	local reloaded = ns2.Plates.Get("nameplate1")
	again.RunTimers()
	assert(shape(reloaded) == want, label .. ": after a reload the plate hangs where it did\n  before " .. want .. "\n  after  " .. shape(reloaded))
	ns2.Plates.RestyleAll()
	assert(shape(reloaded) == want, label .. ": and a restyle after the reload leaves it there\n  before " .. want .. "\n  after  " .. shape(reloaded))
	blizzardKept(again, label .. " after a reload", blizzard)
	assert(#again._errors == 0 and K2.ErrorCount() == 0, label .. " after a reload: " .. tostring(again._errors[1]))
end

-- The game's nameplate size path (a client without stacking bounds) at Lee's screens and HUD sizes, then the stacking
-- bounds path, where Blizzard's cast block usually sets the bar's height, and where the plate's own cast room is taller
-- than that block and sets it instead.
run({ bounds = false, screen = { 1920, 1080 }, scale = 1, size = 2 })
run({ bounds = false, screen = { 5120, 1440 }, scale = 0.8, size = 2 })
run({ bounds = false, screen = { 2383, 1540 }, scale = 1.25, size = 2 })
run({ bounds = true, screen = { 1920, 1080 }, scale = 1, size = 2 })
run({ bounds = true, screen = { 1920, 1080 }, scale = 1, size = 1, settings = { ["cast.height"] = 20 }, tag = "a tall cast bar" })
run({ bounds = true, screen = { 5120, 1440 }, scale = 1.25, size = 1, settings = { ["cast.height"] = 20 }, tag = "a tall cast bar" })
-- A friendly shown by its name only stacks by a smaller footprint, from its first placement on.
local FRIEND = { canAttack = false, reaction = 5, name = "Guard Thelman" }
run({ bounds = true, screen = { 1920, 1080 }, scale = 1, size = 2, unit = FRIEND, settings = { ["friendly.nameOnly"] = true }, tag = "a name-only friendly" })

-- A pooled base handed from an enemy to a name-only friendly, and back, stacks by the footprint of the unit it now
-- shows, the same as a plate built for that unit.
do
	local case = { bounds = true, screen = { 1920, 1080 }, scale = 1, size = 2, settings = { ["friendly.nameOnly"] = true } }
	local env, K, ns = boot(case)
	local scale = env.UIParent:GetEffectiveScale()
	N.Add(env, "nameplate1", {}, { scale = scale })
	N.Add(env, "nameplate2", FRIEND, { scale = scale })
	local enemy, friend = shape(ns.Plates.Get("nameplate1")), shape(ns.Plates.Get("nameplate2"))
	assert(enemy ~= friend, "the case covers two footprints")
	local base = env._bases.nameplate1
	local plate = ns.Plates.Get("nameplate1")
	N.Remove(env, "nameplate1")
	N.Add(env, "nameplate3", FRIEND, { base = base })
	assert(ns.Plates.Get("nameplate3") == plate, "the friendly reuses the enemy's plate")
	assert(shape(plate) == friend, "a pooled plate takes the friendly's footprint\n  fresh  " .. friend .. "\n  pooled " .. shape(plate))
	N.Remove(env, "nameplate3")
	N.Add(env, "nameplate4", {}, { base = base })
	assert(shape(plate) == enemy, "and the enemy's again\n  fresh  " .. enemy .. "\n  pooled " .. shape(plate))
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("test-nameplates-restyle: ok")
