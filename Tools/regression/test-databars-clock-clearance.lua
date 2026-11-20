-- test-databars-clock-clearance.lua: the top clock clears the forged gem and both trim edges on every owner screen.
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs" }) do
		local env, K, ns = D.New({ width = screen[1], height = screen[2], size = "auto" })
		K.Options.Write("HudStyle", "style", style)
		local view = ns.Strip.view
		for _, height in ipairs({ 14, 20 }) do
			K.Options.Write("DataBars", "strip.height", height)
			local _, by, _, bh = Scene.Rect(env, view.frame)
			local text
			for _, item in ipairs(Scene.Build(env).items) do
				if item.object == view.items.time.value then text = item.rect end
			end
			assert(text, "the regression must measure the visible clock text")
			local tx, ty, tw, th = unpack(text)
			local border = K.Widgets.Border(view.frame) * bh / view.frame:GetHeight()
			local case = style .. " " .. screen[1] .. "x" .. screen[2] .. " height " .. height
			for i = 1, 2 do
				local gx, gy, gw, gh = Scene.Rect(env, view.art[i])
				assert(tx + tw <= gx or gx + gw <= tx or ty + th <= gy or gy + gh <= ty,
					case .. ": hang the centre gem below the bar so the clock text clears it")
			end
			assert(ty > by + border and ty + th < by + bh - border,
				case .. ": fit the clock text between the top and bottom trim with clear space")
			assert(math.abs((ty + th / 2) - (by + bh / 2)) <= 1080 / screen[2],
				case .. ": keep the clock vertically centred in the bar")
			print(case .. ": clock clears gem and trim")
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end
print("databars clock clearance ok")
