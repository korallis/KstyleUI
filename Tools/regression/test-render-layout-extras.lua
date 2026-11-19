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
		local positions, links, plates = 0, 0, {}
		for _, item in ipairs(scene.items) do
			local plate = item.object and item.object.GetParent and item.object
			while plate and not plate.key do plate = plate:GetParent() end
			local r = plate and item.kind == "texture" and item.rect
			if r then
				local u = plates[plate] or { r[1], r[2], r[1] + r[3], r[2] + r[4] }
				plates[plate] = u
				u[1], u[2], u[3], u[4] = math.min(u[1], r[1]), math.min(u[2], r[2]), math.max(u[3], r[1] + r[3]), math.max(u[4], r[2] + r[4])
			end
			if item.kind == "text" then
				if item.text:find("CENTER  0, 0", 1, true) then positions = positions + 1 end
				if item.text:find("BELOW:", 1, true) then links = links + 1 end
			end
		end
		for _, item in ipairs(scene.items) do
			local plate = item.kind == "text" and not item.text:find("BELOW:", 1, true) and item.object
			while plate and not plate.key do plate = plate:GetParent() end
			local u, r = plate and plates[plate], item.rect
			assert(not u or (r[1] >= u[1] - 1 and r[2] >= u[2] - 1 and r[1] + r[3] <= u[3] + 1 and r[2] + r[4] <= u[4] + 1),
				screen[1] .. "x" .. screen[2] .. ": '" .. tostring(item.text) .. "' stays inside its plate")
		end
		assert((positions > 0) == coordinates, "the unselected player's coordinates follow the toggle")
		assert(links == 1, "the selected attached cast mover always describes its link")
	end
end
rawset(_G, "RENDER_SCREEN", nil)
print("layout coordinates renders ok: four screens, default and enabled")
