-- test-worldmap-pin-size.lua: the world map skin leaves Blizzard's canvas pins at their native size and zoom scale.
local Windows = dofile("Tools/regression/skins_windows.lua")
local S = Windows.S

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local map, pin, scale
	local env, K = S.New({ width = screen[1], height = screen[2], size = 0.6, before = function(e)
		map = Windows.Build("worldmap", e, S.Blizzard(e))
		pin = e.CreateFrame("Button", nil, map.ScrollContainer)
		pin:SetSize(32, 32)
		pin:SetScale(1.25)
		pin:SetPoint("CENTER", map.ScrollContainer, "CENTER")
		scale = pin:GetEffectiveScale()
	end })
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_WorldMap")
	S.Show(map)
	env.RunTimers()
	S.W.Settle(env)
	assert(pin:GetWidth() == 32 and pin:GetHeight() == 32 and pin:GetEffectiveScale() == scale, "world map pins retain their native size and zoom scale after skinning")
	K.Options.Write("Appearance", "uiScale", 1.5)
	S.W.Settle(env)
	assert(pin:GetEffectiveScale() == scale, "interface size must not shrink world map pins")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("world map pin size ok (1080p, 1440p, ultrawide, 4K)")
