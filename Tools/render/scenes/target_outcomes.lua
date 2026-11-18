-- target_outcomes.lua: target loss, death and replacement sampled from the addon's real event handlers.
local Common = dofile("Tools/render/scenes/_common.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local scenes = {}
	for row, state in ipairs({ "loss", "death", "change" }) do
		local env, K, ns = U.New(Common.ScreenOpts({ saved = Gallery.Saved({ "UnitFrames" }), setup = Gallery.Setup }))
		K.Options.Write("HudStyle", "style", "medallions")
		if os.getenv("RENDER_CUES") == "previous" and ns.Settings.defaults.target.transitions ~= nil then
			K.Options.Write("UnitFrames", "target.transitions", false)
		end
		for _, kind in ipairs({ "player", "targettarget", "pet", "focus", "focustarget", "boss" }) do
			for _, view in ipairs(ns.Frames.Get(kind).views) do view.button:Hide() end
		end
		K.Layout.Update("unitframes.target", { anchor = "CENTER", x = 0, y = 260 - (row - 1) * 240 })
		U.SetUnit(env, "target", { name = "Galestrider", level = 6, health = 1206, healthMax = 1698, reaction = 2, canAttack = true, creature = "Beast" })
		env.SetTarget(true)
		U.W.Tick(env, 0.3)
		local view = ns.Frames.Get("target").views[1]
		local portrait = Common.StandIn("portrait-target.png")
		if portrait then view.medallion.portrait:SetTexture(portrait) end
		if state == "loss" then
			env._units.target = nil
			env.SetTarget(false)
			U.W.Tick(env, 0.075)
		elseif state == "death" then
			env._units.target.dead = true
			env.FireEvent("UNIT_HEALTH", "target")
			U.W.Tick(env, 0.2)
		else
			env._time = env._time + 0.2
			U.SetUnit(env, "target", { name = "Bandit Highwayman", level = 9, health = 48, healthMax = 100, reaction = 2, canAttack = true })
			env.SetTarget(true)
			if portrait then view.medallion.portrait:SetTexture(portrait) end
			U.W.Tick(env, 0.06)
			U.W.Tick(env, 0.06)
		end
		view.medallion.flip:Stop()
		local label = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
		K.Widgets.StyleText(label, "body")
		label:SetPoint("CENTER", K.Scale.Root(), "CENTER", -320, 260 - (row - 1) * 240)
		label:SetText(state)
		assert(#env._errors == 0, tostring(env._errors[1]))
		scenes[#scenes + 1] = Common.Scene.Build(env)
	end
	return Common.Scene.Merge(scenes)
end)
