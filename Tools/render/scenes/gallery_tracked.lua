-- gallery_tracked.lua: the tracked buff viewers at the high load (16 icons, 6 bars) where Layout > Apply places them
-- in Edit Mode for the DPS layout, drawn with the hands, the cluster and the bars around them, so the frame shows
-- that the row stays a row. Blizzard's buff icon viewer has no icon limit or wrap in Edit Mode
-- (EditModeSystemTemplates.lua: IconLimit is off for BuffIcon), so KstyleUI_Cooldowns/Cap.lua stops the restyled row
-- at the module's grid and a "+N" chip in the next slot counts the rest (round 6, Grok #1).
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local LOAD = { buffs = 16, bars = 6 }

local function grow(rect, other)
	if not other then
		return rect
	end
	if not rect then
		return other
	end
	local x0, y0 = math.min(rect.x, other.x), math.min(rect.y, other.y)
	local x1, y1 = math.max(rect.x + rect.w, other.x + other.w), math.max(rect.y + rect.h, other.y + other.h)
	return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local opts = { layout = "DPS", tracked = LOAD }
	local scenes, rect, told, chipText = {}, nil, "", nil
	for _, name in ipairs({ "unitframes", "actionbars", "cooldowns" }) do
		local scene, ns = Hud.Module(name, opts)
		local env = Hud.envs[scene]
		scenes[#scenes + 1] = scene
		if name == "cooldowns" then
			-- The crop holds what the player sees: the items the row keeps (a slot past the grid fades to alpha 0),
			-- the chip and the bars, not the faded slots' empty run.
			local parts = {}
			for _, name2 in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
				local viewer = env._viewers[name2]
				for _, item in ipairs(viewer._items or {}) do
					if item:IsShown() and item:GetAlpha() > 0 then
						parts[#parts + 1] = item
					end
				end
			end
			local chip = ns.Cap.Chip()
			if chip and chip:IsShown() then
				parts[#parts + 1] = chip
			end
			rect = grow(rect, Gallery.Union(env, parts))
			chipText = chip and chip:IsShown() and chip.text:GetText() or nil
			for _, line in ipairs(scene.log) do
				told = line:match("Apply said: (.*)$") or told
			end
		elseif name == "actionbars" then
			rect = grow(rect, Gallery.Union(env, { ns.bars.bar1.holder }))
		elseif name == "unitframes" then
			local list = {}
			for _, kind in ipairs({ "player", "target", "focus" }) do
				local uf = ns.Frames.Get(kind)
				list[#list + 1] = uf and uf.views[1] and uf.views[1].button
			end
			rect = grow(rect, Gallery.Union(env, list))
		end
	end
	local scene = Scene.Merge(scenes)
	frames:Add(nil, nil, {
		name = "auracounts_buffs_high", title = "Tracked buffs, 24",
		grade = "button", reference = "bufficons",
		caption = string.format("%d tracked buffs and %d tracked bars on Forever's automatic path, in place: Blizzard's own viewers, restyled, where Layout > Apply put them in Edit Mode for the DPS layout, with the hands, the sigil and the focus around them. Edit Mode's buff icon viewer has no icon limit, so KstyleUI stops the restyled row at its six-socket grid: the slots past it fade out and stop taking the mouse, and a %s chip in the seventh slot counts the shown ones and lists them on hover. The Cooldown Manager keeps the full list. %s", LOAD.buffs, LOAD.bars,
			chipText or "+N", told ~= "" and ("Apply told the player: " .. told) or "The bars stand beside the target, every bar whole."),
		match = "The row stays one row of six beside the hands with a +N chip; no column runs down the screen, and every item is clear of the cluster, the bars and the rails.",
		rect = rect,
		pad = 16,
	})
	return frames:Finish(scene, Hud.envs[scenes[#scenes]], nil, "gallery tracked")
end)
