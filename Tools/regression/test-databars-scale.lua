-- test-databars-scale.lua: the 14-unit default keeps the v0.2.6 Frames Auto step and top-anchored rectangles.
local Suite = dofile("Tools/regression/suite_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local _, env = Suite.Prepare("frames", screen[1], screen[2])
	local K = env.KstyleUI
	assert(K.Store.Module("DataBars").strip.height == 14 and K.Setup.Layouts.TopInset() == 0,
		"Use a 14-unit default data bar with zero inset to keep the v0.2.6 top band")
	local rw, rh = K.Layout.RootSize()
	if screen[1] == 2560 then
		assert(math.abs(rw - 1950.4761904762) < 0.001,
			"Fit the 14-unit data bar against the live screen-margin clamp; keep the v0.2.6 Frames Auto width of 1950.5")
	end
	local before = {}
	for _, slot in pairs(K.Setup.Layouts.Story("DPS", rh, true, "frames", rw)) do
		if type(slot) == "table" and slot.key and not K.Layout.Get(slot.key) then
			local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
			frame:SetSize(slot.width, slot.height)
			K.Layout.Register(frame, slot.key, slot)
		end
	end
	for _, key in ipairs({ "minimap.main", "auras.buffs", "auras.debuffs", "skins.guide", "skins.quests" }) do
		before[key] = { K.Layout.Rect(key) }
		assert(before[key][1], "The top-band regression must exercise " .. key)
	end
	K.Options.Write("DataBars", "strip.enabled", false)
	env.RunTimers()
	local w, h = K.Layout.RootSize()
	assert(rw == w and rh == h, "The default top bar must keep the same Frames Auto size as no top bar on every owner screen")
	for key, rect in pairs(before) do
		local after = { K.Layout.Rect(key) }
		for i, v in ipairs(rect) do
			assert(v == after[i], "The 14-unit default must leave the top-anchored rectangle unchanged: " .. key)
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("databars scale ok: v0.2.6 Frames Auto step and unchanged top rectangles on all owner screens")
