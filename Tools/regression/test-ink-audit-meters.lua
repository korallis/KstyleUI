local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New()
assert(ns.Logic.FormatRate(99.9, "dps") == "99.9 dps", "rates below 100 retain tenths")
assert(ns.Logic.FormatRate(100.9, "dps") == "100 dps", "rates from 100 use whole figures")
for _, section in ipairs({ "damage", "threat" }) do
	K.Options.Write("Meters", section .. ".colorSource", "custom")
	K.Options.Write("Meters", section .. ".color", { r = 1, g = 1, b = 1 })
	local r, g, b = ns.BarColor(section)
	assert(math.abs(K.Widgets.InkLuminance(r, g, b) - 0.15) < 1e-6, "clamp every meter colour source to luminance 0.15")
	r, g, b = ns.BarColor(section, nil, nil, nil, nil, true)
	assert(r == 1 and g == 1 and b == 1, "a threat warning may use the full source colour")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("meter ink audit passed")
