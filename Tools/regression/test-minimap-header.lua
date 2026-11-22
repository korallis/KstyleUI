-- test-minimap-header.lua: the zone in capitals keeps clear of the Medallions north badge and the N stays inside its badge (KSTY-77, the owner's live Shen'dar Highlands at 3456x2234), at every screen, zone length, zone size and font scale.
local M = dofile("Tools/regression/minimap_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local SCREENS = {
	{ 1920, 1080, 1 }, { 3456, 2234, 768 / 1080 }, { 2383, 1540, 768 / 1080 }, { 5120, 1440, 1 }, { 1280, 720, 1 }, { 3840, 2160, 1 }, { 3440, 1440, 1 }, { 3840, 1080, 1 },
}
local ZONES = { "Shen'dar Highlands", "Ironforge", "The Forbidding Sea of Endless Highland Storms" }
local EPS = 0.05

local function Measure(text, path, size)
	return Scene.TextWidth(Scene.PlainText(text), size, path)
end

local function Rects(env, face)
	local scene = Scene.Build(env, {})
	local found = {}
	for _, item in ipairs(scene.items) do
		if item.object == face.zone or item.object == face.north or item.object == face.gem or item.object == face.plaques[1].chrome.fill[5] then
			local x, y, w, h = unpack(item.rect)
			found[item.object] = { left = x, right = x + w, top = y, bottom = y + h }
		end
	end
	return found
end

local function Overlap(a, b)
	return a.left < b.right - EPS and b.left < a.right - EPS and a.top < b.bottom - EPS and b.top < a.bottom - EPS
end

local cases = 0
for _, screen in ipairs(SCREENS) do
	local env, K, ns = M.New({
		enabled = true,
		zone = ZONES[1],
		width = screen[1], height = screen[2], uiScale = screen[3], size = "default",
		setup = function(e)
			e._textWidth = Measure
		end,
	})
	M.Settle(env)
	local face = ns.Map.face
	for _, scale in ipairs({ 1, 0.95, 1.3 }) do
		K.Options.Write("Appearance", "fontScale", scale)
		for _, size in ipairs({ 12, 16, 24 }) do
			K.Options.Write("Minimap", "zone.size", size)
			for _, zone in ipairs(ZONES) do
				env._zone.text = zone
				env.FireEvent("ZONE_CHANGED_NEW_AREA")
				M.Settle(env)
				local what = string.format("%dx%d, font scale %.2f, zone size %d, %q", screen[1], screen[2], scale, size, zone)
				local r = Rects(env, face)
				local zoneRect, north, badge, plaque = r[face.zone], r[face.north], r[face.gem], r[face.plaques[1].chrome.fill[5]]
				assert(zoneRect and north and badge and plaque, what .. ": the zone, the N, the badge and the zone plaque all draw")
				assert(north.left >= badge.left - EPS and north.right <= badge.right + EPS and north.top >= badge.top - EPS and north.bottom <= badge.bottom + EPS,
					string.format("%s: the N stays inside its badge, N %.1f..%.1f against %.1f..%.1f", what, north.top, north.bottom, badge.top, badge.bottom))
				assert(not Overlap(zoneRect, badge) and not Overlap(zoneRect, north),
					string.format("%s: the zone (bottom %.1f) keeps clear of the north badge (top %.1f) and its N (top %.1f)", what, zoneRect.bottom, badge.top, north.top))
				assert(zoneRect.left >= plaque.left - 1 and zoneRect.right - zoneRect.left <= plaque.right - plaque.left + 1, string.format("%s: the zone stays over its plaque, truncating a long name, zone %.1f..%.1f plaque %.1f..%.1f", what, zoneRect.left, zoneRect.right, plaque.left, plaque.right))
				cases = cases + 1
			end
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

print("test-minimap-header: " .. cases .. " cases passed")
