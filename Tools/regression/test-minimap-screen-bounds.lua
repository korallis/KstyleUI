-- test-minimap-screen-bounds.lua: the complete round minimap stays inside the HUD margin, with aligned plaques clear of the ring.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2383, 1540 }, { 2560, 1080 }, { 2560, 1440 },
	{ 2560, 1600 }, { 3440, 1440 }, { 3456, 2234 }, { 3840, 1080 }, { 3840, 2160 }, { 5120, 1440 },
}
for _, screen in ipairs(screens) do
	for _, arrangement in ipairs({ "centred", "spread" }) do
		local env, K, ns = M.New({ width = screen[1], height = screen[2], saved = {
			version = 38, profiles = { Default = {
				HudStyle = { style = "medallions" }, Layout = { arrangement = arrangement }, Minimap = { enabled = true },
			} }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
		} })
		M.Settle(env)
		local root, face = K.Scale.Root(), ns.Map.face
		local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, root)) end
		local bounds, margin, pixel = Rect(root), K.Tokens.Size("screenMargin"), K.Scale.Pixel(1)
		local ring, zone, row = Rect(face.ring), Rect(face.plaques[1]), Rect(face.plaques[2])
		local context = screen[1] .. "x" .. screen[2] .. " " .. arrangement .. ": "
		for _, box in ipairs({ ring, zone, row, Rect(env.Minimap) }) do
			assert(box.left >= bounds.left + margin - pixel and box.right <= bounds.right - margin + pixel
				and box.top <= bounds.top - margin + pixel and box.bottom >= bounds.bottom + margin - pixel,
				context .. "inset the whole minimap group by screenMargin, including the ring and plaques")
		end
		assert(zone.bottom >= ring.top + pixel, context .. "place the zone plaque above the ring")
		assert(row.top <= ring.bottom - pixel, context .. "place the coordinate plaque below the ring")
		assert(math.abs(zone.left - row.left) <= pixel and math.abs(zone.right - row.right) <= pixel,
			context .. "align both plaques")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("minimap screen bounds ok: " .. #screens .. " screens, both arrangements")
