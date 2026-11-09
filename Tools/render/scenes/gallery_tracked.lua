-- gallery_tracked.lua: the tracked buff viewers at the high load (16 icons, 6 bars) where Layout > Apply places them
-- in Edit Mode for the DPS layout, drawn with the hands, the cluster and the bars around them, so the frame shows
-- that the column stands clear beside the cluster rather than floating on its own. Blizzard's buff icon viewer has
-- no icon limit or wrap in Edit Mode (EditModeSystemTemplates.lua: IconLimit is off for BuffIcon), so a high load
-- is one column; past what fits anywhere, Apply leaves the viewers where they were and the setup summary offers
-- Try again and the Cooldown Manager (gallery_setup's summary_tracked frame).
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
	local scenes, rect, told = {}, nil, ""
	for _, name in ipairs({ "unitframes", "actionbars", "cooldowns" }) do
		local scene, ns = Hud.Module(name, opts)
		local env = Hud.envs[scene]
		scenes[#scenes + 1] = scene
		if name == "cooldowns" then
			local parts = {}
			for _, name2 in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
				local viewer = env._viewers[name2]
				parts[#parts + 1] = viewer
				for _, item in ipairs(viewer._items or {}) do
					if item:IsShown() then
						parts[#parts + 1] = item
					end
				end
			end
			rect = grow(rect, Gallery.Union(env, parts))
			for _, line in ipairs(scene.log) do
				told = line:match("Apply said: (.*)$") or told
			end
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
		caption = string.format("%d tracked buffs and %d tracked bars on Forever's automatic path, in place: Blizzard's own viewers, restyled, where Layout > Apply put them in Edit Mode for the DPS layout, with the hands, the sigil and the focus around them. Edit Mode's buff icon viewer has no icon limit, so past the row beside the hands the icons stand in one column beside the cluster and the bars over the focus, every item whole and clear of every frame. %s", LOAD.buffs, LOAD.bars,
			told ~= "" and ("Apply told the player: " .. told) or "Past what fits anywhere on screen, Apply leaves the viewers where they were and the setup summary names the counts, with Try again and the Cooldown Manager."),
		match = "Every tracked item shows whole, clear of the cluster, the bars and the rails; nothing floats over the play field.",
		rect = rect,
		pad = 16,
	})
	return frames:Finish(scene, Hud.envs[scenes[#scenes]], nil, "gallery tracked")
end)
