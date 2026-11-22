-- test-groupframes-parity-r8-screens.lua: round 8 on the four test screens: party heal icons outside the frame never cross a neighbour's icons or their own frame, timers included, side by side and stacked; names under the bar move the Medallions raid tile's name and lanes too.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local A = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local write, frame, noErrors = H.write, H.frame, H.noErrors

local function heals(env, f, count)
	A.Assign(env, f.buffs, "buffs", count)
	local group = f.buffs._groups.buffs
	Hud.PlaceAuras(f.buffs, group, group.active, count)
	return group.active
end

local Scene = dofile("Tools/render/scene.lua")
local function box(env, region, clip)
	local x, y, w, h = Scene.Rect(env, region)
	local out = { x, y, x + w, y + h }
	if clip then
		local c = box(env, clip)
		out = { math.max(out[1], c[1]), math.max(out[2], c[2]), math.min(out[3], c[3]), math.min(out[4], c[4]) }
	end
	return out
end

-- apart(env, a, b, what, clipA, clipB): what each region shows, inside its clip when given, does not cross the other.
local function apart(env, a, b, what, clipA, clipB)
	local r, q = box(env, a, clipA), box(env, b, clipB)
	local dx, dy = math.min(r[3], q[3]) - math.max(r[1], q[1]), math.min(r[4], q[4]) - math.max(r[2], q[2])
	assert(dx <= 1e-3 or dy <= 1e-3 or r[3] <= r[1] or q[3] <= q[1], what .. " overlap by " .. dx .. " x " .. dy)
end

for _, size in ipairs(H.SCREENS) do
	local at = size[1] .. "x" .. size[2] .. ": "
	local env, K, ns = H.boot(H.screen(size))
	write(env, K, "party.buffAnchor", "RIGHT")
	write(env, K, "party.growth", "RIGHT")
	write(env, K, "party.width", 80)
	write(env, K, "party.buffCount", 6)
	write(env, K, "party.buffSize", 24)
	local f, nextFrame = frame(ns, "party1"), frame(ns, "party2")
	local mine, theirs = heals(env, f, 6), heals(env, nextFrame, 6)
	for i, a in ipairs(mine) do
		apart(env, a, nextFrame, at .. "heal " .. i .. " and the next frame", f.buffClip)
		for j, b in ipairs(theirs) do
			apart(env, a, b, at .. "heal " .. i .. " and the next member's heal " .. j, f.buffClip, nextFrame.buffClip)
		end
	end
	write(env, K, "party.width", 260)
	write(env, K, "auras.timers", true)
	mine = heals(env, f, 3)
	A.Remaining(env, mine[1], 12)
	apart(env, mine[1]._aura.timer, f, at .. "a heal's time left above the frame and the frame")
	apart(env, f.buffClip, f, at .. "the heal row with its timers and the frame")
	write(env, K, "party.growth", "DOWN")
	write(env, K, "party.height", 30)
	mine = heals(env, f, 3)
	heals(env, nextFrame, 3)
	A.Remaining(env, mine[1], 12)
	apart(env, mine[1]._aura.timer, nextFrame, at .. "a heal's time left beside a stacked frame and the next frame")
	apart(env, f.buffClip, nextFrame.buffClip, at .. "stacked heal rows with their timers")
	G.SetRoster(env, "raid", G.Members(20))
	env.RunTimers()
	write(env, K, "raid.buffCount", 2)
	local r = frame(ns, "raid1")
	assert(r.parts.tile and r.parts.tile.stacked, at .. "the Medallions raid row is a stacked tile")
	local name0, percent0 = H.point(r.name), H.point(r.healthText)
	write(env, K, "names.bottom", true)
	assert(r.parts.tile.below and H.point(r.name) ~= name0 and H.point(r.healthText) ~= percent0, at .. "names under the bar move the tile's name and percent")
	assert(select(2, Scene.Rect(env, r.name)) > select(2, Scene.Rect(env, r.healthText)), at .. "the tile's name sits under its percent")
	apart(env, r.name, r.healthText, at .. "tile name and percent")
	assert(r.parts.healRow and r.parts.healRow.top < r.parts.health.top + r.parts.health.height / 2, at .. "the tile's heal lane moves to the top")
	apart(env, r.name, r.buffClip, at .. "tile name and heal lane")
	write(env, K, "names.bottom", false)
	assert(H.point(r.name) == name0 and H.point(r.healthText) == percent0 and not r.parts.tile.below, at .. "off restores the tile")
	noErrors(env, K)
	collectgarbage()
end

print("groupframes parity round 8 screens ok: heal icons and timers clear of neighbours and frames, tile names under the bar, on four screens")
