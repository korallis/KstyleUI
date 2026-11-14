-- test-nameplates-head.lua: the engine places the base and Blizzard's own health bar rides in it, so a KstyleUI plate's bar sits in the base no lower than Blizzard's would, measured from the bottom, the centre and the top, in and out of combat, and the game stacks plates by the plate's whole footprint.
local N = dofile("Tools/regression/nameplates_env.lua")

-- Where a plate's bar bottom sits in its base, in the base's units: the plate's anchor offset from the base's
-- bottom times the plate's scale over the base's. The plate frame is the bar, so its bottom is the bar's.
local function barBottom(plate, base)
	local point, relative, relativePoint, _, y = plate:GetPoint(1)
	assert(point == "BOTTOM" and relative == base and relativePoint == "BOTTOM", "the plate hangs from its base's bottom")
	return y * plate:GetEffectiveScale() / base:GetEffectiveScale()
end

-- The three places the engine's base can stand against the unit: its bottom on the head anchor (Blizzard lays its
-- plate out from the bottom up, so this is the default), its centre on it, and its top held under the screen's
-- top inset when nameplateShowOffscreen keeps a unit in combat on screen. In each the head is put where Blizzard's
-- own bar bottom lands, the lowest head its bar still clears, and the KstyleUI bar must clear it too, to within the
-- physical pixel the plate snaps to.
local function check(label, plate, base, env, blizzard)
	local height = env._plateSize[2]
	local ours = barBottom(plate, base)
	local TOLERANCE = plate:Pixel() * plate:GetEffectiveScale() / base:GetEffectiveScale() + 1e-6
	local cases = {
		{ "bottom on the head", ours, blizzard.rise },
		{ "centre on the head", ours - height / 2, blizzard.rise - blizzard.height / 2 },
		{ "top at the screen's inset", ours - height, blizzard.rise - blizzard.height },
	}
	for _, case in ipairs(cases) do
		local name, bar, head = case[1], case[2], case[3]
		assert(bar >= head - TOLERANCE, label .. ", base " .. name .. ": the bar's bottom is " .. string.format("%.2f", head - bar)
			.. " units under the head (base " .. env._plateSize[1] .. " x " .. height .. ", bar " .. string.format("%.2f", ours)
			.. " up; Blizzard's box " .. blizzard.width .. " x " .. blizzard.height .. ", its bar " .. blizzard.rise .. " up)")
	end
end

-- Blizzard's driver is secure, so its size write goes through in combat, where the module's own would raise.
local function driverSetsSize(env)
	local guarded = env.C_NamePlate.SetNamePlateSize
	env.C_NamePlate.SetNamePlateSize = function(w, h)
		env._plateSize = { w, h }
		for _, base in ipairs(env._allBases) do
			base:SetSize(w, h)
		end
	end
	env.NamePlateDriverFrame:UpdateNamePlateSize()
	env.C_NamePlate.SetNamePlateSize = guarded
end

local SCREENS = { { 1920, 1080 }, { 3456, 2234 }, { 5120, 1440 } }

for _, screen in ipairs(SCREENS) do
	for size = 1, 5 do
		local blizzard = N.Blizzard(size)
		local env, K, ns = N.New({ stackingBounds = true, nameplateSize = size, width = screen[1], height = screen[2] })
		local base = N.Add(env, "nameplate1", {}, { scale = env.UIParent:GetEffectiveScale() })
		local plate = ns.Plates.Get("nameplate1")
		local label = screen[1] .. "x" .. screen[2] .. " nameplateSize " .. size
		for _, scale in ipairs({ 0.8, 16 / 19, 1, 1.25 }) do
			K.Scale.SetUserScale(scale)
			env.RunTimers()
			local at = label .. " HUD " .. scale
			check(at, plate, base, env, blizzard)
			K.Options.Write("Nameplates", "cast.enabled", false)
			check(at .. " without cast bars", plate, base, env, blizzard)
			K.Options.Write("Nameplates", "cast.enabled", true)
			K.Options.Write("Nameplates", "debuffs.rows", 3)
			check(at .. " with three debuff rows", plate, base, env, blizzard)
			K.Options.Write("Nameplates", "debuffs.rows", 1)

			-- In combat Blizzard's driver may set its size again (a CVar or display change); the engine then
			-- stacks every base at that size until combat ends. The bar must still clear the head.
			env.SetCombat(true)
			local moves = #N.Calls(plate, "SetPoint")
			driverSetsSize(env)
			check(at .. " in combat after Blizzard's driver sets its size", plate, base, env, blizzard)
			assert(#N.Calls(plate, "SetPoint") == moves, at .. ": nothing moves the plate in combat")
			env.SetCombat(false)
			env.RunTimers()
			check(at .. " after combat", plate, base, env, blizzard)
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end

-- The game stacks plates by the plate's whole footprint, every debuff row included (the owner's rule), and keeps
-- its own nameplate size, so its box and Blizzard's bar stay where Blizzard put them.
do
	local blizzard = N.Blizzard(3)
	local env, K, ns = N.New({ stackingBounds = true, width = 2560, height = 1440 })
	local base = N.Add(env, "nameplate1", {}, { scale = env.UIParent:GetEffectiveScale() })
	local plate = ns.Plates.Get("nameplate1")
	local bounds = plate.stackBounds
	local calls = N.Calls(base, "SetStackingBoundsFrame")
	assert(#calls == 1 and calls[1][1] == bounds, "the plate's footprint is the base's stacking bounds, set once")
	assert(bounds:GetParent() == base, "the bounds belong to the base, so they stay when a plate hides")
	assert(#env._plateSizeWrites == 0, "the game keeps its own nameplate size, got " .. #env._plateSizeWrites .. " writes")
	assert(env._plateSize[1] == blizzard.width and env._plateSize[2] == blizzard.height, "Blizzard's own box")

	local function footprint()
		local width, above, height, below = ns.Stacking.Extent(plate)
		local rise = select(5, plate:GetPoint(1))
		below = math.max(below, rise)
		return width, above + height + below, below
	end
	-- The engine reads the bounds frame on screen. The frame lives in the base's units and the footprint in the
	-- plate's, so the frame must cover the footprint in screen units, from the plate's bottom down to the base's.
	local function onScreen(label)
		local width, tall, below = footprint()
		local ps, bs = plate:GetEffectiveScale(), bounds:GetEffectiveScale()
		local point, relative, relativePoint, x, y = bounds:GetPoint(1)
		assert(point == "BOTTOM" and relative == plate and relativePoint == "BOTTOM" and x == 0, label .. ": the bounds hang from the plate")
		assert(N.Same(y * bs, -below * ps), label .. ": the bounds reach the base's bottom, got " .. y * bs .. " for " .. -below * ps)
		assert(N.Same(bounds:GetWidth() * bs, width * ps) and N.Same(bounds:GetHeight() * bs, tall * ps),
			label .. ": the bounds are the whole footprint on screen, got " .. bounds:GetHeight() * bs .. " for " .. tall * ps)
		local rise = select(5, plate:GetPoint(1)) * ps
		assert(N.Same(below * ps, math.max(rise, below * ps)), label .. ": the bounds' bottom is no higher than the base's")
		return tall * ps
	end
	local tall
	for _, scale in ipairs({ 16 / 19, 1, 1.25 }) do
		K.Scale.SetUserScale(scale)
		env.RunTimers()
		tall = onScreen("HUD " .. scale)
	end
	assert(not N.Same(plate:GetEffectiveScale(), bounds:GetEffectiveScale()), "the case covers a plate and a base at different scales")
	K.Options.Write("Nameplates", "debuffs.rows", 3)
	assert(onScreen("three debuff rows") > tall, "every debuff row counts")
	K.Options.Write("Nameplates", "debuffs.rows", 1)
	assert(#N.Calls(base, "SetStackingBoundsFrame") == 1, "resizing the bounds frame needs no new call")

	-- A plate built in combat registers its bounds there too; a refusal waits for combat to end.
	env.SetCombat(true)
	local second = N.Add(env, "nameplate2", {})
	assert(#N.Calls(second, "SetStackingBoundsFrame") == 1, "a plate built in combat is bounded at once")
	env.SetCombat(false)

	-- The game's own size on request: the bounds go back to the base's own box and the plate to its own room.
	K.Options.Write("Nameplates", "stacking.footprint", "game")
	env.RunTimers()
	assert(#N.Calls(bounds, "SetAllPoints") >= 1 and N.Last(bounds, "SetAllPoints")[1] == base, "the bounds are the base again")
	assert(#env._plateSizeWrites == 0, "and the game's size was never touched")
	K.Options.Write("Nameplates", "stacking.footprint", "plate")
	env.RunTimers()
	assert(#env._plateSizeWrites == 0, "back to the plate's footprint, still through the bounds")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A client without stacking bounds keeps giving the game the footprint as its nameplate size.
do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1", {})
	assert(#env._plateSizeWrites >= 1, "the footprint is the game's nameplate size")
	assert(#N.Calls(env._bases.nameplate1, "SetStackingBoundsFrame") == 0, "no stacking bounds call")
	assert(ns.Stacking.BarRise() == nil, "and the bar keeps its own room")
end

print("test-nameplates-head: ok")
