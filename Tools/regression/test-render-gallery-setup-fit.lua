-- test-render-gallery-setup-fit.lua: the setup gallery keeps each of its four windows whole on a 1080-unit screen and clear of the others, in both HUD styles at 1920x1080 and in Frames, whose windows draw larger, at 2560x1440 and 3840x2160.
rawset(_G, "RENDER_SCENE_LIB", true)
for _, case in ipairs({ { "Frames", 1920, 1080 }, { "Medallions", 1920, 1080 }, { "Frames", 2560, 1440 }, { "Frames", 3840, 2160 } }) do
	local style, width, height = unpack(case)
	local label = style .. " " .. width .. "x" .. height
	rawset(_G, "RENDER_SCREEN", { width = width, height = height, uiScale = 768 / 1080, size = "auto" })
	rawset(_G, "RENDER_HUD_STYLE", style)
	local scene = dofile("Tools/render/scenes/gallery_setup.lua")()
	for i, frame in ipairs(scene.frames) do
		local r = frame.rect
		assert(r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= scene.screen.width and r[2] + r[4] <= scene.screen.height, label .. ": " .. frame.name .. " sits whole on the screen, its bottom at " .. r[2] + r[4] .. " of " .. scene.screen.height)
		for j = i + 1, #scene.frames do
			local o = scene.frames[j].rect
			assert(r[1] + r[3] <= o[1] or o[1] + o[3] <= r[1] or r[2] + r[4] <= o[2] or o[2] + o[4] <= r[2], label .. ": " .. frame.name .. " stays clear of " .. scene.frames[j].name)
		end
	end
	collectgarbage("collect")
end
print("gallery setup fit ok")
