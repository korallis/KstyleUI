-- test-minimap-plaque-clearance.lua: the round map's zone plaque stays under the screen margin and its lower plaque clears the ring.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 }, { 3456, 2234 } }) do
	local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], saved = {
		version = 12, profiles = { Default = { HudStyle = { style = "medallions" }, Minimap = { enabled = true } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {},
	} })
	M.Settle(env)
	local root, face = K.Scale.Root(), ns.Map.face
	local function Rect(frame) return assert(G.ScaledRect(frame, env.UIParent, root)) end
	local zone, row, ring = Rect(face.plaques[1]), Rect(face.plaques[2]), Rect(face.ring)
	assert(root:GetHeight() - zone.top >= 17 - K.Scale.Pixel(1), "keep the minimap zone plaque at least 17 units below the screen top")
	assert(row.top <= ring.bottom - K.Scale.Pixel(1), "reserve the round minimap ring's south overhang above the coordinate plaque")
	K.Options.Write("Minimap", "clearPlaques", false)
	M.Settle(env)
	local previousRow = Rect(face.plaques[2])
	assert(previousRow.top > row.top + K.Scale.Pixel(1), "turning plaque clearance off restores the previous coordinate-row position")
	K.Options.Write("Minimap", "clearPlaques", true)
	M.Settle(env)
	assert(math.abs(Rect(face.plaques[2]).top - row.top) <= K.Scale.Pixel(1), "plaque clearance can be enabled again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("minimap plaque clearance ok")
