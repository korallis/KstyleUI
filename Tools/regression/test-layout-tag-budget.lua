-- test-layout-tag-budget.lua: selecting sixty movers stays near the pre-tag CPU and allocation cost.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New({ width = 1920, height = 1080 })
for i = 1, 60 do
	local f = env.CreateFrame("Frame", nil, K.Scale.Root())
	f:SetSize(120, (i % 5 == 0) and 3 or 40)
	K.Layout.Register(f, "B.e" .. i, { anchor = "BOTTOMLEFT", x = (i % 10) * 180, y = math.floor(i / 10) * 150 + 40 }, { label = "Element number " .. i, scalable = true })
end
assert(K.Layout.Enter())
local Mode = K.Layout.Mode
collectgarbage(); collectgarbage("stop")
local m0, t0 = collectgarbage("count"), os.clock()
for i = 1, 200 do Mode.Select("B.e" .. (i % 60 + 1)) end
local elapsed, garbage = os.clock() - t0, collectgarbage("count") - m0
collectgarbage("restart")
print(string.format("Select x200: %.3f s, %.0f KB garbage", elapsed, garbage))
assert(garbage < 4096, "reserve tag space on layout changes; selecting movers must allocate less than 4 MB")
assert(elapsed < 0.1, "place only affected tags on selection; 200 selections must take less than 0.1 CPU seconds")
local p = Mode.Plate("B.e5")
assert(p:GetHeight() == 16, "thin movers must retain the 16-unit grab area used by wheel and coverage hit tests")
