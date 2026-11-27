-- anim_pose.lua: what one pass of an animation group's Translation, Rotation and Scale animations applies at a time, by the client's rule:
-- Pose.Passes(group) -> its timed animations and the times worth sampling; Pose.At(timed, time) -> offset x, y, turn in degrees and scale.
-- ranged_reach.lua sweeps the crest's pieces through it, and the crest's motion and rail tests check each Scale chain's path with it.
local Pose = {}

-- How the client composes a group's Scale animations once each has started: true multiplies each onto the ones before it, a finished
-- one holding its end until the group ends; false lets the latest started one replace the others. Offsets and turns always add.
Pose.MULTIPLY = false

-- Eased(each, at) -> how far the timed animation has run at time at of its group's pass, 0 to 1, through its smoothing.
local function Eased(each, at)
	local p = math.max(0, math.min(1, (at - each.from) / math.max(each.run, 1e-6)))
	local smoothing = each.anim._state.Smoothing and each.anim._state.Smoothing[1] or "NONE"
	if smoothing == "OUT" then return 1 - (1 - p) ^ 2 end
	if smoothing == "IN" then return p * p end
	if smoothing == "IN_OUT" then return p < 0.5 and 2 * p * p or 1 - 2 * (1 - p) ^ 2 end
	return p
end

-- Passes(group) -> its Translation, Rotation and Scale animations, each with the time it starts and runs for in one pass, the pass's
-- times worth sampling (each start, end and the instant before each end, where a later animation taking over would hide its peak, and
-- 48 steps between) and the pass's length.
function Pose.Passes(group)
	local orders, timed, times, start = {}, {}, { 0 }, 0
	for _, anim in ipairs(group._anims or {}) do
		local order = anim._state.Order and anim._state.Order[1] or 1
		orders[order] = orders[order] or {}
		table.insert(orders[order], anim)
	end
	for order = 1, 64 do
		local longest = 0
		for _, anim in ipairs(orders[order] or {}) do
			local delay, run = anim._state.StartDelay and anim._state.StartDelay[1] or 0, anim._state.Duration and anim._state.Duration[1] or 0
			longest = math.max(longest, delay + run)
			if anim._type == "Translation" or anim._type == "Rotation" or anim._type == "Scale" then
				timed[#timed + 1] = { anim = anim, from = start + delay, run = run }
				times[#times + 1], times[#times + 2], times[#times + 3] = start + delay, start + delay + run, start + delay + run * 0.999
			end
		end
		start = start + longest
	end
	for i = 1, 48 do times[#times + 1] = start * i / 48 end
	return timed, times, start
end

-- At(timed, time) -> x, y, turn, scale: the pose the timed animations of one pass apply at time; a Scale counts from its start.
function Pose.At(timed, time)
	local x, y, turn, scale, latest = 0, 0, 0, 1, -1
	for _, each in ipairs(timed) do
		local p, state = Eased(each, time), each.anim._state
		if each.anim._type == "Translation" then
			local ox, oy = unpack(state.Offset or { 0, 0 })
			x, y = x + (ox or 0) * p, y + (oy or 0) * p
		elseif each.anim._type == "Rotation" then
			turn = turn + (state.Degrees and state.Degrees[1] or 0) * p
		elseif time >= each.from and (Pose.MULTIPLY or each.from >= latest) then
			local from, to = (state.ScaleFrom or { 1 })[1] or 1, (state.ScaleTo or { 1 })[1] or 1
			local now = from + (to - from) * p
			scale, latest = Pose.MULTIPLY and scale * now or now, each.from
		end
	end
	return x, y, turn, scale
end

return Pose
