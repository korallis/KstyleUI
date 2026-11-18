-- audit_shapes.lua: all three colour-vision palettes with threat ticks, triangles, squares and a secret cast shield.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
return Common.Run(function()
	local scenes = {}
	for column, mode in ipairs({ "standard", "redGreen", "blueYellow" }) do
		local env, K = N.New(Common.ScreenOpts({ saved = Gallery.Saved({ "Nameplates" }), setup = Common.ForceScreen }))
		env.WorldFrame:SetPoint("TOPLEFT")
		env.WorldFrame:SetPoint("BOTTOMRIGHT")
		if K.ColorVision then K.Options.Write("ColorVision", "mode", mode) end
		K.Options.Write("Nameplates", "threat.groupOnly", false)
		K.Options.Write("Nameplates", "threat.role", "tank")
		for row, status in ipairs({ 0, 1, 3 }) do
			local token = "nameplate" .. row
			local base = N.Add(env, token, { name = mode .. " " .. row, health = 70, maxHealth = 100, reaction = 2, canAttack = true, threat = status })
			base:ClearAllPoints()
			base:SetPoint("CENTER", env.WorldFrame, "CENTER", (column - 2) * 350 * 768 / 1080, (2 - row) * 180 * 768 / 1080)
			N.Cast(env, token, { name = "Shadow Bolt", text = "Shadow Bolt", texture = 136197, notInterruptible = env.Secret(row == 3) })
		end
		dofile("Tools/render/scenes/_audit.lua").Apply(K)
		for _ = 1, 20 do N.Tick(env, 0.05) end
		env.RunTimers()
		assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
		scenes[#scenes + 1] = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
	end
	return Common.Scene.Merge(scenes)
end)
