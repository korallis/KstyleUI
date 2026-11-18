-- slab_finish.lua: long engine countdowns, stack counts and inset keys at the requested socket size.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local scene, ns = Hud.Module("actionbars", { class = "WARLOCK", layout = "DPS", applyPreset = true })
	local env = Hud.envs[scene]
	local size = tonumber(os.getenv("RENDER_SLOT_SIZE"))
	if size then
		for _, key in ipairs({ "bar1", "bar2" }) do
			local bar = ns.bars[key]
			env.KstyleUI.Options.Write("ActionBars", key .. ".size", ns.Config(key).size * size / bar.buttons[1].opts.size)
		end
	end
	local gcd, long = ns.bars.bar1.buttons[4], ns.bars.bar1.buttons[5]
	gcd:SetCooldown(9.5, 1.5, true)
	gcd.cooldown:Show()
	gcd.cooldown:GetScript("OnShow")(gcd.cooldown)
	long:SetCooldown(10, tonumber(os.getenv("RENDER_DURATION")) or 6000, false)
	long:SetCount("3")
	long.cooldown:Show()
	long.cooldown:GetScript("OnShow")(long.cooldown)
	local before = env._now
	env._now = env._time - 0.125
	env.SetCombat(true)
	env._now = before
	return Common.Scene.Build(env, { time = env._time, iconDirs = Common.IconDirs() })
end)
