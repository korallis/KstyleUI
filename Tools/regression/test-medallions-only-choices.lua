-- test-medallions-only-choices.lua: Options offers only choices that draw something different under Medallions: no Orbs split, one docked data bar position beside the rail, a slab or a plate per unit frame, and no ornament or card material picker.
local AB = dofile("Tools/regression/actionbars_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")

local function Values(K, module, key)
	local row = assert(K.Options.Row(module, key), module .. " has a " .. key .. " row")
	local out = {}
	for _, option in ipairs(row.options) do out[#out + 1] = option.value end
	return table.concat(out, ",")
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	for _, bar in ipairs({ "bar1", "bar2", "bar3" }) do
		assert(Values(K, "ActionBars", bar .. ".split") == "on,off", bar .. ": Split in two offers Always and Never, got " .. Values(K, "ActionBars", bar .. ".split"))
		assert(ns.defaults[bar].split == "off", bar .. " starts unsplit")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = D.New()
	assert(Values(K, "DataBars", "strip.placement") == "dock,rail", "the data bar docks under the action bars or keeps the right rail, got " .. Values(K, "DataBars", "strip.placement"))
	assert(ns.defaults.strip.placement == "dock", "the data bar starts docked")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = U.New()
	for _, kind in ipairs({ "player", "target", "focus", "targettarget", "pet", "boss" }) do
		local default = ns.Settings.defaults[kind].style
		assert(Values(K, "UnitFrames", kind .. ".style") == default .. ",plate", kind .. ": Style offers the slab and the plate, got " .. Values(K, "UnitFrames", kind .. ".style"))
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	assert(K.Options.Row("Widgets", "ornaments") == nil, "General offers no ornament level: Medallions draws no ornaments")
	assert(K.Options.Row("Widgets", "cardMaterial") == nil, "General offers no card material: Medallions cards are steel")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("medallions only choices ok")
