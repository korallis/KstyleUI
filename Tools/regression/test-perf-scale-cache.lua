-- test-perf-scale-cache.lua: persisted scale answers survive reload, match cold results exactly, and invalidate on every fitting input.
local C = dofile("Tools/regression/core_env.lua")
local function New(saved, version, screen)
	screen = screen or { 5120, 1440 }
	local env, K = C.New({ width = screen[1], height = screen[2], fit = true, size = "auto", saved = saved })
	local calls, original = 0, K.Setup.Layouts.Fits
	K.VERSION = version or "cache-test-v1"
	K.Setup.Layouts.Fits = function(...)
		calls = calls + 1
		return original(...)
	end
	C.Boot(env)
	return env, K, function() return calls end
end
local env, K, calls = New()
assert(calls() > 0, "a cold login must really run the scale search")
do
	local oldEnv, current = New()
	local expected = string.format("%.17g", current.Scale.AppliedUserScale())
	for _, entry in ipairs(oldEnv.KstyleUIDB.scaleCache.entries) do
		entry.key = entry.key:gsub("scaled%-text%-v2", "scaled-text")
		entry.maximum = "0.6"
	end
	local _, upgraded, misses = New(oldEnv.KstyleUIDB)
	assert(misses() > 0 and string.format("%.17g", upgraded.Scale.AppliedUserScale()) == expected, "discard saved answers from the superseded text-floor policy")
end
local profile = K.Store.Profile()
for _, element in ipairs(K.Setup.Layouts.ELEMENTS) do
	profile[element.module] = profile[element.module] or {}
	profile[element.module].enabled = true
end
K.Callbacks.Fire("ModuleChanged")
local cold = string.format("%.17g", K.Scale.AppliedUserScale())
local warm, W, hits = New(env.KstyleUIDB)
assert(hits() == 0, "P1: persist the scale answer so a warm login makes no Fits calls")
assert(string.format("%.17g", W.Scale.AppliedUserScale()) == cold, "P1: preserve every bit of the cold scale answer")
local before = hits()
warm.FireEvent("DISPLAY_SIZE_CHANGED")
warm.RunTimers()
assert(hits() == before, "P1: no-op and late display rechecks must skip Limit")
W.Options.Write("Appearance", "textFloor", false)
assert(hits() > before, "C1: a changed text floor must never reuse the old scale cache key")
local legacyFloor = string.format("%.17g", W.Scale.AppliedUserScale())
local _, legacy, legacyHits = New(warm.KstyleUIDB)
assert(string.format("%.17g", legacy.Scale.AppliedUserScale()) == legacyFloor, "C1: reload keeps the exact scale for the selected floor")
assert(legacyHits() == 0, "C1: after Appearance restores the floor, reuse only its matching cache entry")
W.Options.Write("Appearance", "textFloor", true)
before = hits()
local width, height = 3456, 2234
warm.GetPhysicalScreenSize = function() return width, height end
warm.FireEvent("DISPLAY_SIZE_CHANGED")
warm.RunTimers()
assert(hits() > before, "P1: include physical width and height in the cache key")
width, height = 5120, 1440
warm.FireEvent("DISPLAY_SIZE_CHANGED")
warm.RunTimers()
before = hits()
W.Options.Write("HudStyle", "style", "orbs")
assert(hits() > before, "P1: a HUD style change must invalidate the scale answer")
for _, setting in ipairs({ { "preset", "Tank" }, { "canvas", "16:9" }, { "arrangement", "spread" } }) do
	local n = hits()
	W.Options.Write("Layout", setting[1], setting[2])
	assert(hits() > n, "P1: include " .. setting[1] .. " in the persistent cache key")
end
local n = hits()
W.Store.Profile().UnitFrames.enabled = false
W.Callbacks.Fire("ModuleChanged")
assert(hits() > n, "P1: include the enabled-element signature in the cache key")
W.Options.Write("Appearance", "uiScaleAuto", false)
W.Options.Write("Appearance", "uiScale", 0.7)
local manual = string.format("%.17g", W.Scale.AppliedUserScale())
local _, reloaded, manualHits = New(warm.KstyleUIDB)
assert(manualHits() == 0, "P1: retain both manual answers needed while Appearance restores a profile")
assert(string.format("%.17g", reloaded.Scale.AppliedUserScale()) == manual, "P1: preserve manual-size answers as well as Auto")
for _, preset in ipairs({ "DPS", "Healer", "Tank" }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		W.Options.Write("Layout", "preset", preset)
		W.Options.Write("HudStyle", "style", style)
	end
end
assert(#warm.KstyleUIDB.scaleCache.entries <= 6, "P1: keep only the six most recently used scale keys")
env.KstyleUIDB.scaleCache.version = "obsolete"
local _, _, stale = New(env.KstyleUIDB)
assert(stale() > 0, "P1: discard persisted answers from a different addon version")
assert(#env._errors == 0 and #warm._errors == 0, "scale caching must leave no addon errors")

local function SavedRoundTrip(value)
	if type(value) == "number" then
		return tonumber(string.format("%.6g", value))
	end
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = SavedRoundTrip(child)
	end
	return copy
end
local exactScreen = { 3456, 2234 }
local exactEnv, exact = New(nil, nil, exactScreen)
for _, element in ipairs(exact.Setup.Layouts.ELEMENTS) do
	local section = exact.Store.Profile()[element.module] or {}
	exact.Store.Profile()[element.module], section.enabled = section, true
end
exact.Callbacks.Fire("ModuleChanged")
local exactText, maxText = string.format("%.17g", exact.Scale.AppliedUserScale()), string.format("%.17g", exact.Scale.MaxUserScale())
assert(tonumber(string.format("%.6g", exact.Scale.MaxUserScale())) ~= exact.Scale.MaxUserScale(), "the fixture must contain a maximum that lossy numeric serialization would change")
local saved = SavedRoundTrip(exactEnv.KstyleUIDB)
local _, restored, restoredHits = New(saved, nil, exactScreen)
assert(restoredHits() == 0 and string.format("%.17g", restored.Scale.AppliedUserScale()) == exactText
	and string.format("%.17g", restored.Scale.MaxUserScale()) == maxText, "store scale cache values exactly even when SavedVariables rounds numeric fields")
local dev, _, devCold = New(saved, "@project-version@", exactScreen)
assert(devCold() > 0, "dev checkouts must run the cold scale search")
local _, _, devWarm = New(dev.KstyleUIDB, "@project-version@", exactScreen)
assert(devWarm() > 0, "disable persisted scale-cache reads and writes for unreplaced development versions")
local development = New(nil, "@project-version@")
assert(development.KstyleUIDB.scaleCache == nil, "dev checkouts must not create a persisted scale cache")
local serialized = SavedRoundTrip(warm.KstyleUIDB)
local _, manualReloaded, exactManualHits = New(serialized)
assert(exactManualHits() == 0 and string.format("%.17g", manualReloaded.Scale.AppliedUserScale()) == string.format("%.17g", W.Scale.AppliedUserScale()), "manual cached scales must also survive rounded SavedVariables fields exactly")
print("perf scale cache ok")
