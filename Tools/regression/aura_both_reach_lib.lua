-- aura_both_reach_lib.lua: the full HUD reach check at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 with the target's auras on Debuffs and buffs, both groups full and stacked as the engine's flow layout does (a forced new line groupLineSpacing below the last), so the buff rows and their timers must clear every HUD element.
local Reach = dofile("Tools/regression/hud_reach_lib.lua")
local A = dofile("Tools/regression/auras_env.lua")

local New, Populate = Reach.New, Reach.Populate
Reach.New = function(...)
	local env, K = New(...)
	K.Options.Write("UnitFrames", "target.auraFilter", "both")
	return env, K
end
Reach.Populate = function(env)
	Populate(env)
	local c = env._addons.KstyleUI_UnitFrames.Frames.Get("target").views[1].auras.container
	local flow = c._flow
	local corner, dx, dy = flow.anchor, flow.horizontal, flow.vertical
	local offset, wide = 0, 0
	for _, key in ipairs(c._order) do
		local group = c._groups[key]
		assert(group.enabled, "Debuffs and buffs shows the " .. key .. " group")
		local n, l = A.Assign(env, c, key, group.maxFrameCount), group.layout
		local w, h, gap, line = l.elementWidth, l.elementHeight, l.elementSpacing, l.lineSpacing
		local columns = math.max(1, math.floor((flow.lineSize + gap + 0.01) / (w + gap)))
		if offset > 0 then offset = offset + (l.groupLineSpacing or 0) end
		for i, button in ipairs(group.active) do
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			button:ClearAllPoints()
			button:SetSize(w, h)
			button:SetPoint(corner, c, corner, dx * col * (w + gap), dy * (offset + row * (h + line)))
			button._aura.icon:SetTexture(env.Secret(key == "buffs" and 136207 or 135813))
			button._aura.timer:SetText("30s")
		end
		local rows = math.ceil(n / columns)
		offset = offset + rows * h + (rows - 1) * line
		wide = math.max(wide, math.min(n, columns) * (w + gap) - gap)
	end
	c:SetSize(math.max(1, wide), math.max(1, offset))
end

return function(style)
	Reach.Run(style, "DPS", { 1, 4 })
end
