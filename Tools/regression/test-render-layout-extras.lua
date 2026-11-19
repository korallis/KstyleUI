-- test-render-layout-extras.lua: coordinate details on real player and cast movers clear their labels on four screens.
rawset(_G, "RENDER_SCENE_LIB", true)
local build = dofile("Tools/render/scenes/layout_links.lua")
local Guard = dofile("Tools/render/guard.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
	for _, coordinates in ipairs({ false, true }) do
		local scene = build({ mode = true, coordinates = coordinates })
		assert(#scene.items > 0 and scene.screen.physical.width == screen[1] and scene.screen.physical.height == screen[2])
		local findings = Guard.Check(scene)
		assert(#findings == 0, table.concat(Guard.Lines(findings, {}, {}, "default"), "\n"))
		local positions, links = 0, 0
		for _, item in ipairs(scene.items) do
			if item.kind == "text" then
				if item.text:find("CENTER  0, 0", 1, true) then positions = positions + 1 end
				if item.text:find("BELOW:", 1, true) then links = links + 1 end
			end
		end
		assert((positions > 0) == coordinates, "the unselected player's coordinates follow the toggle")
		assert(links == 1, "the selected attached cast mover always describes its link")
	end
end
rawset(_G, "RENDER_SCREEN", nil)
print("layout coordinates renders ok: four screens, default and enabled")
