-- test-groupframes-readable-fit.lua: the larger party's room in the HUD fit: a warm Larger party frames switch refits the automatic size both ways, in the fit cache and the saved scale cache, an entry saved before the party token is recomputed, a saved switch counts before the module loads, and the reserved room matches the party's real scale for the active layout and the player's own sizes.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local C = dofile("Tools/regression/core_env.lua")
local KEY = "groupframes.party"

-- Bars, party and raid on 5120x1440 in Frames: the larger party lowers the automatic size here.
local function Boot(size, version, cache)
	local saved = H.saved({ readable = { size = size } })
	local profile = saved.profiles.Default
	profile.ActionBars, profile.HudStyle = { enabled = true, bar3 = { enabled = true, finished = false } }, { style = "frames" }
	saved.scaleCache = cache
	local env, K = H.G.New(H.screen({ 5120, 1440 }, { fit = true, shipped = true, boot = false, setup = H.setup, saved = saved }))
	env.SetQuiet(true)
	if version then K.VERSION = version end
	C.Boot(env)
	K.Modules.Enable(H.MODULE)
	env.RunTimers()
	return env, K
end

-- Released builds keep a saved scale cache in front of the fit cache: a warm switch misses the first and must miss the second.
local VERSION = "readable-party-fit-test"
local _, cold = Boot(false)
local off = cold.Scale.AppliedUserScale()
do
	local env, K = Boot(true, VERSION)
	local on = K.Scale.AppliedUserScale()
	assert(on < off, "the larger party lowers the automatic size here: on " .. on .. ", off " .. off)
	H.write(env, K, "readable.size", false)
	assert(K.Scale.AppliedUserScale() == off, "switching Larger party frames off refits, got " .. K.Scale.AppliedUserScale() .. " for " .. off .. "; key the fit and scale caches by the party's scale")
	H.write(env, K, "readable.size", true)
	assert(K.Scale.AppliedUserScale() == on, "switching it on again refits, got " .. K.Scale.AppliedUserScale() .. " for " .. on)
	H.noErrors(env, K)
	-- An entry saved before the party token: the key no longer matches, so the size is recomputed, never reused.
	local key = env.KstyleUIDB.scaleCache.entries[1].key:gsub(":[^:]*$", "")
	local oldEnv, old = Boot(true, VERSION, { version = VERSION, entries = { { key = key, maximum = "1.5", auto = "0.6" } } })
	assert(old.Scale.AppliedUserScale() == on, "an old saved entry is recomputed: " .. old.Scale.AppliedUserScale())
	H.noErrors(oldEnv, old)
end
collectgarbage()

-- A saved switch counts before GroupFrames registers its defaults (the native Edit Mode fit runs on the core alone).
do
	local env, K = C.New(H.screen({ 5120, 1440 }, { saved = H.saved({ readable = { size = false } }) }))
	C.Boot(env)
	assert(K.Setup.Layouts.PartyScale(5120, 1440) == 1, "read the saved Larger party frames switch before the module loads")
end

-- The reserved room and the party's real scale agree for the active layout and the player's own sizes.
do
	local env, K = H.G.New(H.screen({ 5120, 1440 }, { shipped = true, setup = H.setup }))
	env.SetQuiet(true)
	H.party(env)
	K.Modules.Enable(H.MODULE)
	env.RunTimers()
	local L, holder = K.Setup.Layouts, K.Layout.Element(KEY).frame
	local function check(label, preset, scale)
		local width = L.Footprint(preset, KEY, nil, nil, 5120, 1440)
		assert(H.near(holder:GetScale(), scale), label .. ": the party is " .. holder:GetScale() .. " times its size, not " .. scale)
		assert(H.near(width, 259 * scale), label .. ": the HUD reserves " .. width .. " for a party " .. 259 * scale .. " wide")
	end
	check("stock", "DPS", 1.25)
	H.write(env, K, "party.width", 280)
	check("own width", "DPS", 1)
	H.write(env, K, "party.width", 259)
	H.write(env, K, "party.height", 43)
	check("own DPS row height 43", "DPS", 1)
	K.Options.Write("Layout", "preset", "Healer")
	H.write(env, K, "party.height", 43)
	check("Healer rows", "Healer", 1.25)
	H.write(env, K, "party.height", 44)
	check("own Healer row height 44", "Healer", 1)
	H.noErrors(env, K)
end

print("groupframes readable fit ok: warm switches refit both caches, old entries recompute, the saved switch counts early, and the reserved room matches the party")
