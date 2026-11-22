-- test-consumables-layout.lua: the consumables maximum grid clears every sibling at the four owner screen sizes.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New({ fit = true })
CoreEnv.Boot(env)
local L = K.Setup.Layouts
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, name in ipairs(L.Names()) do
		local enabled = L.Enabled(name)
		assert(enabled["consumables.bar"], "the default bar participates even when inventory is empty")
		local label = string.format("%dx%d %s", screen[1], screen[2], name)
		local settings = K.Store.Module("ActionBars")
		local saved = settings.consumables
		settings.consumables = { size = 38, spacing = -1 }
		local previous = L.Positions(name, "medallions", K.Scale.AspectClass(screen[1], screen[2]))
		settings.consumables = saved
		local current = L.Positions(name, "medallions", K.Scale.AspectClass(screen[1], screen[2]))
		for key, position in pairs(previous) do
			if key ~= "consumables.bar" then
				assert(CoreEnv.DeepEqual(position, current[key]), label .. ": shrinking consumables must not move " .. key)
			end
		end
		local cap, fits = L.ScaleLimit(screen[1], screen[2], name, enabled)
		local auto = K.Scale.Auto(screen[2], cap, fits)
		assert(fits(auto), label .. ": the default bar fits at the automatic pixel step")
		local places = L.PrepareFits(name, screen[1], screen[2], enabled, nil).layout
		local baseline = {}
		for key, value in pairs(enabled) do baseline[key] = value end
		baseline["consumables.bar"] = false
		if L.Fits(name, screen[1], screen[2], K.Scale.DEFAULT_USER_SCALE, baseline, nil) then
			assert(L.Fits(name, screen[1], screen[2], K.Scale.DEFAULT_USER_SCALE, enabled, nil), label .. ": adding the default footprint keeps the whole HUD clear")
		end
		for _, element in ipairs(L.ELEMENTS) do
			if element.key ~= "consumables.bar" and enabled[element.key] ~= false then
				local pair = {}
				for _, other in ipairs(L.ELEMENTS) do pair[other.key] = false end
				pair["consumables.bar"], pair[element.key] = true, true
				assert(L.Fits(name, screen[1], screen[2], K.Scale.DEFAULT_USER_SCALE, pair, places), label .. ": the maximum footprint must clear " .. element.key)
			end
		end
	end
end
local signature = L.ActionBarSignature()
for _, rows in ipairs({ 1, 2, 3 }) do
	K.Store.Module("ActionBars").consumables = { rows = rows, size = 38, spacing = -1, attached = true }
	assert(L.ActionBarSignature() == signature, "consumables geometry never invalidates the HUD fit caches")
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local enabled = L.Enabled("DPS")
		local free = {}
		for key, value in pairs(enabled) do free[key] = value end
		free["consumables.bar"] = false
		local maximum = L.ScaleLimit(screen[1], screen[2], "DPS", enabled)
		assert(maximum == L.ScaleLimit(screen[1], screen[2], "DPS", free), "consumables never limit the HUD scale")
	end
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("consumables layout ok: four owner sizes x three presets, maximum 2x6 grid")
