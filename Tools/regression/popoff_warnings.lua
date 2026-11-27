-- popoff_warnings.lua: Warnings(env, ns, now) -> how strongly each lit signature pop-off slot's late warning draws its amber and its red
-- swipe at the clock time now (env._now when nil), keyed "<art>:<unit>", read from the delayed fades SlabRings arms
-- (KstyleUI_ActionBars/SlabRings.lua, Light) the way the renderer plays them; popoff_draw.lua and the RENDER_FX=popoffs story
-- (Tools/render/scenes/_effects.lua) both read the warnings through it.
local Warnings = {}

-- The alpha a delayed fade leaves its frame at: the frame's own until the start delay has run, the fade's end after it.
local function Level(now, frame, group)
	local fade = group.fade
	local t = group._playedAt and now - group._playedAt - fade._state.StartDelay[1]
	if not t or t < 0 then
		return frame:GetAlpha()
	end
	local from, to, length = fade._state.FromAlpha[1], fade._state.ToAlpha[1], fade._state.Duration[1]
	return t >= length and to or from + (to - from) * t / length
end

function Warnings.Read(env, ns, now)
	now = now or env._now
	local out = {}
	for _, e in ipairs(ns.SlabRings.state.watched) do
		local top = e.piece.top or e.piece
		if e.late and top.spec and top.spec.key == "crestPopoffs" and e.piece:IsVisible() and e.late.start then
			local cap = Level(now, e.late, e.late.show)
			out[top.spec.art .. ":" .. e.unit] = { cap * Level(now, e.late.amber, e.late.leave), cap * Level(now, e.late.red, e.late.turn) }
		end
	end
	return out
end

return Warnings
