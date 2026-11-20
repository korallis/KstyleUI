-- test-layout-tag-budget.lua: selecting sixty movers stays within addon instruction and allocation budgets.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New({ width = 1920, height = 1080 })
for i = 1, 60 do
	local f = env.CreateFrame("Frame", nil, K.Scale.Root())
	f:SetSize(120, (i % 5 == 0) and 3 or 40)
	K.Layout.Register(f, "B.e" .. i, { anchor = "BOTTOMLEFT", x = (i % 10) * 180, y = math.floor(i / 10) * 150 + 40 }, { label = "Element number " .. i, scalable = true })
end
assert(K.Layout.Enter())
assert(#env._errors == 0, tostring(env._errors[1]))
local Mode = K.Layout.Mode
collectgarbage(); collectgarbage("stop")
local m0 = collectgarbage("count")
for i = 1, 200 do Mode.Select("B.e" .. (i % 60 + 1)) end
local garbage = collectgarbage("count") - m0
collectgarbage("restart")
print(string.format("Select x200: %.0f KB garbage", garbage))
assert(garbage < 4096, "cache mover rectangles on layout changes; selecting movers must allocate less than 4 MB")
local instructions = dofile("Tools/regression/instruction_budget.lua")(function()
	for i = 1, 200 do Mode.Select("B.e" .. (i % 60 + 1)) end
end, 1100000, "place only affected tags on selection")
print("Select x200: " .. instructions .. " addon instructions")
local p = Mode.Plate("B.e5")
assert(p:GetHeight() == 16, "thin movers must retain the 16-unit grab area used by wheel and coverage hit tests")

K.Options.Write("Layout", "showCoordinates", false)
Mode.Select("B.e5")
assert(p.info:GetText():find("100%%"), "selected thin plates retain scale details when coordinates are off")
local scale = K.Scale.Root():GetEffectiveScale()
env._cursor = { 100 * scale, 100 * scale }
p:GetScript("OnDragStart")(p, "LeftButton")
local scans, original = 0, K.Layout.Elements
K.Layout.Elements = function() scans = scans + 1; return original() end
env._cursor = { 110 * scale, 110 * scale }
Mode.Overlay():GetScript("OnUpdate")()
assert(scans == 0, "place tags after drag release, never on a drag OnUpdate frame")
p:GetScript("OnDragStop")(p)
assert(scans == 1, "batch tag placement once when a drag ends, got " .. scans)
scans = 0
p:Restyle()
assert(scans == 0, "batch tag placement on refresh instead of once per restyled plate")
scans = 0
K.Callbacks.Fire("ThemeChanged")
assert(scans == 2, "restyle plates, then enumerate movers and pack tags once for the whole theme refresh")
K.Layout.Elements = original
assert(#env._errors == 0, tostring(env._errors[1]))
