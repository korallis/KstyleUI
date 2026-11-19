-- test-minimap-screen-bounds.lua: saved, dragged and resized minimaps keep their complete group inside the HUD margin.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2383, 1540 }, { 2560, 1080 }, { 2560, 1440 },
	{ 2560, 1600 }, { 3440, 1440 }, { 3456, 2234 }, { 3840, 1080 }, { 3840, 2160 }, { 5120, 1440 },
}
local function Bounds(env, K, ns, context, preview)
	local root, face = K.Scale.Root(), ns.Map.face
	local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, root)) end
	local bounds, margin, pixel = Rect(root), K.Tokens.Size("screenMargin"), K.Scale.Pixel(1)
	local ring, zone, row = Rect(face.ring), Rect(face.plaques[1]), Rect(face.plaques[2])
	for _, box in ipairs({ ring, zone, row, Rect(env.Minimap) }) do
		assert(box.left >= bounds.left - K.Scale.Origin() + margin - pixel and box.right <= bounds.right + K.Scale.Origin() - margin + pixel
			and box.top <= bounds.top - margin + pixel and box.bottom >= bounds.bottom + margin - pixel,
			context .. ": inset the whole minimap group by screenMargin, including the ring and plaques")
	end
	assert(zone.bottom + 1e-6 >= ring.top + pixel, context .. ": place the zone plaque above the ring")
	if ns.Face.Frame() == "medallion" then
		assert(math.abs((row.top + row.bottom) / 2 - ring.bottom) <= pixel, context .. string.format(": seat the coordinate plaque on the rim: %.4f vs %.4f, pixel %.4f", (row.top + row.bottom) / 2, ring.bottom, pixel))
		assert(row.right - row.left < zone.right - zone.left, context .. ": shorten the medallion coordinate plaque")
	else
		assert(row.top <= ring.bottom - pixel + 1e-6, context .. ": place the coordinate plaque below the ring")
		assert(math.abs(zone.left - row.left) <= pixel + 1e-6 and math.abs(zone.right - row.right) <= pixel + 1e-6,
			context .. ": align both classic plaques")
	end
	if not preview then
		local left, bottom = K.Layout.Rect("minimap.main")
		local map = Rect(ns.Map.holder)
		assert(math.abs(left + bounds.left - map.left) <= pixel + 1e-6 and math.abs(bottom + bounds.bottom - map.bottom) <= pixel + 1e-6,
			context .. ": Layout Mode reads the displayed, clamped position: " .. left .. "," .. bottom .. " vs " .. map.left .. "," .. map.bottom)
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
local function Drag(env, K, ns, frame, dx, dy, context)
	local scale = K.Scale.Root():GetEffectiveScale()
	env._cursor = { 200 * scale, 200 * scale }
	frame:GetScript("OnDragStart")(frame, "LeftButton")
	env._cursor = { (200 + dx) * scale, (200 + dy) * scale }
	local overlay = K.Layout.Mode.Overlay()
	overlay:GetScript("OnUpdate")(overlay, 0.016)
	Bounds(env, K, ns, context .. " preview", true)
	frame:GetScript("OnDragStop")(frame)
	Bounds(env, K, ns, context .. " committed")
end
for _, frame in ipairs({ "classic", "ring", "medallion" }) do
for _, screen in ipairs(screens) do
	for _, arrangement in ipairs({ "centred", "spread" }) do
		for _, position in ipairs({ false, { anchor = "TOPRIGHT", x = -0.00008, y = -6.4 } }) do
			local env, K, ns = M.New({ width = screen[1], height = screen[2], saved = {
				version = 37, profiles = { Default = {
					HudStyle = { style = "medallions" }, Layout = { arrangement = arrangement }, Minimap = { enabled = true, frame = frame },
				} }, characters = {}, layouts = { Default = { ["minimap.main"] = position or nil } }, account = { setupSeen = true }, devlog = {},
			} })
			M.Settle(env)
			local context = frame .. " " .. screen[1] .. "x" .. screen[2] .. " " .. arrangement .. (position and " owner" or " default")
			Bounds(env, K, ns, context)
			if position then
				local saved = env.KstyleUIDB.layouts.Default["minimap.main"]
				assert(saved.x == -0.00008 and saved.y == -6.4, "retain the owner's saved position while constraining its display")
				if screen[1] == 1920 or screen[1] == 2560 and screen[2] == 1440 or screen[1] == 5120 or screen[2] == 2160 then
					assert(K.Layout.Update("minimap.main", { anchor = "CENTER", x = 100, y = 50 }))
					local left, bottom, w, h = K.Layout.Rect("minimap.main")
					local rw, rh = K.Layout.RootSize()
					assert(math.abs(left + w / 2 - rw / 2 - 100) <= K.Scale.Pixel(1)
						and math.abs(bottom + h / 2 - rh / 2 - 50) <= K.Scale.Pixel(1), "keep an in-bounds custom position unchanged")
					assert(K.Layout.Enter())
					local mode = K.Layout.Mode
					local plate = mode.Plate("minimap.main")
					M.W.Down(plate)
					for _, delta in ipairs({ { -10000, 10000 }, { 10000, 10000 }, { -10000, -10000 }, { 10000, -10000 } }) do
						Drag(env, K, ns, plate, delta[1], delta[2], context .. " drag")
					end
					Drag(env, K, ns, mode.Handle("RIGHT"), 500, 0, context .. " resize")
					for _, key in ipairs({ "RIGHT", "DOWN" }) do mode.Overlay():GetScript("OnKeyDown")(mode.Overlay(), key) end
					Bounds(env, K, ns, context .. " nudged")
					K.Layout.Exit(true)
				end
			end
		end
	end
end
end
do
	local _, K = M.New()
	for _, entry in ipairs({ {}, { anchor = "TOPRIGHT", x = -20, y = -38 }, { width = 260, height = 260 },
		{ x = -80 }, { anchor = "CENTER", x = 100, y = 50 } }) do
		local custom = entry.x == -80 or entry.anchor == "CENTER"
		local data = { layouts = { Default = { ["minimap.main"] = entry } } }
		K.Store.migrations[39](data)
		if custom then
			assert(entry.x == -80 and entry.y == -38 and entry.anchor == "TOPRIGHT"
				or entry.x == 100 and entry.y == 50 and entry.anchor == "CENTER", "preserve complete and partial custom minimap positions")
			local medal = data.layouts.Default["medallions:minimap.main"]
			assert(medal and medal.anchor == entry.anchor and medal.x == entry.x and medal.y == entry.y,
				"carry the previously shared custom position into the new Medallions placement")
		else
			assert(entry.anchor == nil and entry.x == nil and entry.y == nil, "release only the previous default minimap position")
		end
		if entry.width then assert(entry.width == 260 and entry.height == 260, "preserve custom minimap size") end
	end
end
print("minimap screen bounds ok: " .. #screens .. " screens, both arrangements, defaults and owner positions; four-size drag/resize/nudge checks")
