-- test-databars-clock-clearance-frames.lua: under the Frames HUD style, the top clock clears the forged gem and both trim edges, and every readout reads at the text floor or above, on every owner screen.
local D = dofile("Tools/regression/frames_lib.lua")(dofile("Tools/regression/databars_env.lua"))
local Scene = dofile("Tools/render/scene.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto" })
	local view = ns.Strip.view
	for _, height in ipairs({ 14, 20 }) do
		K.Options.Write("DataBars", "strip.height", height)
		local _, by, _, bh = Scene.Rect(env, view.frame)
		local text
		for _, item in ipairs(Scene.Build(env).items) do
			if item.object == view.items.time.value then text = item end
		end
		assert(text, "the regression must measure the visible clock text")
		local tx, ty, tw, th = unpack(text.rect)
		local em = th / (text.lineEm or 1.2)
		local border = K.Widgets.Border(view.frame) * bh / view.frame:GetHeight()
		local case = screen[1] .. "x" .. screen[2] .. " height " .. height
		for i = 1, 2 do
			local gx, gy, gw, gh = Scene.Rect(env, view.art[i])
			assert(tx + tw <= gx or gx + gw <= tx or ty + th <= gy or gy + gh <= ty,
				case .. ": hang the centre gem below the bar so the clock text clears it")
		end
		assert(ty + (th - em) / 2 > by + border and ty + (th + em) / 2 < by + bh - border,
			case .. ": fit the clock glyphs (one em; the page's line box adds leading that draws nothing) between the top and bottom trim with clear space")
		assert(math.abs((ty + th / 2) - (by + bh / 2)) <= 1080 / screen[2],
			case .. ": keep the clock vertically centred in the bar")
		for id, item in pairs(view.items) do
			if item.button:IsShown() then
				for _, fs in ipairs({ item.value, item.label }) do
					local _, size = fs:GetFont()
					assert(size * K.Widgets.ScaleFactor(fs) / K.Scale.Pixel(1) >= K.Scale.TextFloor() - 0.01,
						case .. ": keep the " .. id .. " readout at the text floor: size it to the largest whole-pixel font whose line fits the bar")
				end
			end
		end
		print(case .. ": clock clears gem and trim")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("databars clock clearance ok")
