-- test-medallions-only-choices.lua: Options offers no Orbs choice: no Orbs split, the data bar starts docked (Top is Frames' top bar and docks in Medallions), a slab or a plate per Medallions unit frame.
local AB = dofile("Tools/regression/actionbars_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

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
	assert(Values(K, "DataBars", "strip.placement") == "top,dock,rail", "the data bar sits on top in Frames, docks under the action bars or keeps the right rail, got " .. Values(K, "DataBars", "strip.placement"))
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

print("medallions only choices ok")
