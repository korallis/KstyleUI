-- test-minimap-coords-plate.lua: on the round Medallions map the coordinates plate sits centred under the map; with the clock hidden or moved the coordinates read whole and centred in the plate with even padding, even when they first arrive after the plate was laid out, and the hidden clock adds no width; beside the clock they keep the left end.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], size = "auto",
		setup = function(e) e.KstyleUIDB.profiles.Default.HudStyle = { style = "medallions" } end })
	env._textWidth = function(text, _, size) return #text * size * 0.55 end
	M.Settle(env)
	local face = ns.Map.face
	local pixel = K.Scale.Pixel(1)
	local function Set(key, value)
		K.Options.Write("Minimap", key, value)
		M.Settle(env)
	end
	local function Rect(region) return assert(G.ScaledRect(region, env.UIParent, K.Scale.Root())) end
	local function Check(label, alone)
		local row, map = Rect(face.plaques[2]), Rect(face.mapArea)
		local text = face.coords
		local w, h = text._width, text._height
		text._width = w or text:GetStringWidth()
		text._height = h or text:GetStringHeight()
		local coords = Rect(text)
		text._width, text._height = w, h
		local rowMid, mid = (row.left + row.right) / 2, (coords.left + coords.right) / 2
		assert(math.abs(rowMid - (map.left + map.right) / 2) <= pixel, label .. ": centre the plate under the map")
		local width = text:GetStringWidth()
		assert(mid - width / 2 >= row.left + 6 - pixel and mid + width / 2 <= row.right - 6 + pixel, label .. ": keep the coordinates padded inside their plate")
		assert(alone and math.abs(mid - rowMid) <= pixel or not alone and mid < rowMid, label .. ": centre the coordinates without the clock, keep the left end beside it: " .. mid .. " / " .. rowMid)
		return row.right - row.left
	end

	local size = " " .. screen[1] .. "x" .. screen[2]
	Set("clock.shown", false)
	Set("coords.size", 24)
	Set("coords.precision", 2)
	env._position = { 0.467, 0.612 }
	env.FireEvent("PLAYER_STARTED_MOVING")
	M.RunTickers(env)
	Check("cold start" .. size, true)
	for _, frame in ipairs({ "medallion", "ring", "classic" }) do
		Set("frame", frame)
		local widths = {}
		for _, clock in ipairs({ "hidden", "row", "moved" }) do
			Set("clock.shown", clock ~= "hidden")
			Set("clock.position", clock == "moved" and "TOPRIGHT" or "")
			widths[clock] = Check(frame .. " clock " .. clock .. size, clock ~= "row")
		end
		assert(math.abs(widths.hidden - widths.moved) <= pixel, frame .. size .. ": a hidden clock adds no width to the plate")
		assert(frame ~= "medallion" or widths.row > widths.moved, frame .. size .. ": the seated plate makes room for the clock in its row")
		Set("clock.position", "")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
print("minimap coords plate ok: cold start, three frames, clock hidden, in the row and moved, four screens")
