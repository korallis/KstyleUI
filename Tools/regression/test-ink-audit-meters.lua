local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New()
assert(ns.Logic.FormatRate(100.9, "dps") == "100.9 dps", "retain the owner's existing rate formatting")
for _, section in ipairs({ "damage", "threat" }) do
	K.Options.Write("Meters", section .. ".colorSource", "custom")
	K.Options.Write("Meters", section .. ".color", { r = 1, g = 1, b = 1 })
	local r, g, b = ns.BarColor(section)
	assert(r == 1 and g == 1 and b == 1, "preserve full source colours without a luminance clamp")
	local list = ns.BarList.New(K.Scale.Root(), section, { width = 269, height = 158, block = section == "damage",
		columns = function() return { value = true, percent = true } end })
	list:SetRow(1, "Pale class", "PRIEST", nil, 100, 100, "100", "100%")
	for _, text in ipairs({ list.rows[1].name, list.rows[1].value, list.rows[1].percent }) do
		local _, _, _, alpha = text:GetShadowColor()
		local x, y = text:GetShadowOffset()
		local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(text)
		assert(alpha == 0.8 and x == pixel and y == -pixel, "row ink uses an 80% one-pixel shadow without changing its bar")
	end
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("meter ink audit passed")
