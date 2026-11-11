-- test-statusbar-glow.lua: a bordered bar's fill glow draws only while the fill is at least as wide as the glow's two corners, so an empty or nearly empty fill (the reputation track at 0) draws no stray corner square (LEE-157), a smooth bar follows its drawn value while it eases, and SetGlowShown turns it off for good.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local Widgets = K.Widgets
local bar = Widgets.StatusBar(K.Scale.Root(), { border = true })
bar:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 100, -100)
bar:SetSize(160, 5)
bar:SetMinMaxValues(0, 100)

local function shown()
	local n = 0
	for i = 1, #bar.glow do
		if bar.glow[i]:IsShown() then n = n + 1 end
	end
	return n
end

bar:SetValue(0)
assert(shown() == 0, "an empty fill draws no glow, not " .. shown() .. " of its 9 slices")
bar:SetValue(50)
assert(shown() == 9, "a fill 80 units wide draws its whole glow")
bar:SetValue(5)
assert(shown() == 0, "a fill 8 units wide, narrower than the glow's two 8-unit corners, draws no glow")
bar:SetMinMaxValues(0, 10)
assert(shown() == 9, "a new range that widens the fill to 80 units brings the glow back")
bar:SetSize(10, 5)
local onSize = bar:GetScript("OnSizeChanged")
if onSize then onSize(bar, 10, 5) end
assert(shown() == 0, "a bar narrowed to 10 units hides the glow of its 5-unit fill")
bar:SetSize(160, 5)
if onSize then onSize(bar, 160, 5) end
bar:SetGlowShown(false)
assert(shown() == 0, "SetGlowShown(false) hides the glow")
bar:SetValue(10)
assert(shown() == 0, "a hidden glow stays hidden when the fill grows")
bar:SetGlowShown(true)
assert(shown() == 9, "SetGlowShown(true) shows it again over a wide fill")
local easing, drawn = true, 0.5
bar.IsInterpolating = function() return easing end
bar.GetInterpolatedValue = function() return drawn end
bar:SetValue(0)
bar:SetValue(10)
assert(shown() == 0 and bar.glowWatch and bar.glowWatch:GetScript("OnUpdate"), "while a smooth bar eases up from empty its drawn fill is narrow, so the glow waits and a watcher follows the ease")
drawn = 9
bar.glowWatch:GetScript("OnUpdate")(bar.glowWatch, 0.016)
assert(shown() == 9, "the glow shows once the drawn fill is wider than its corners")
easing, drawn = false, 10
bar.glowWatch:GetScript("OnUpdate")(bar.glowWatch, 0.016)
assert(shown() == 9 and not bar.glowWatch:GetScript("OnUpdate"), "the watcher stops when the ease ends")
bar.IsInterpolating, bar.GetInterpolatedValue = nil, nil
bar:SetOrientation("VERTICAL")
assert(shown() == 0, "a vertical bar has no pill and no glow")
assert(#env._errors == 0, tostring(env._errors[1]))
print("ok status bar glow")
