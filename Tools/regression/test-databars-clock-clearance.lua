-- test-databars-clock-clearance.lua: every readout on the Medallions data strip reads at the text floor or above, on every owner screen.
local D = dofile("Tools/regression/databars_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto" })
	local view = ns.Strip.view
	local case = screen[1] .. "x" .. screen[2]
	assert(view.items.time.button:IsShown(), case .. ": the regression must measure the visible clock")
	for id, item in pairs(view.items) do
		if item.button:IsShown() then
			for _, fs in ipairs({ item.value, item.label }) do
				local _, size = fs:GetFont()
				assert(size * K.Widgets.ScaleFactor(fs) / K.Scale.Pixel(1) >= K.Scale.TextFloor() - 0.01,
					case .. ": keep the " .. id .. " readout at the text floor: size it to the largest whole-pixel font whose line fits the strip")
			end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("databars clock clearance ok")
