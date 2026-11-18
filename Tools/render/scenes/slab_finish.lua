-- slab_finish.lua: a warlock's real action slab with a GCD, a real cooldown, a three-digit minute timer, charges and the combat hub peak.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

return Common.Run(function()
	local scene, ns = Hud.Module("actionbars", { class = "WARLOCK", layout = "DPS", applyPreset = true })
	local env = Hud.envs[scene]
	local gcd, long = ns.bars.bar1.buttons[4], ns.bars.bar1.buttons[5]
	gcd:SetCooldown(9.5, 1.5, true)
	gcd.cooldown:Show()
	gcd.cooldown:GetScript("OnShow")(gcd.cooldown)
	long:SetCooldown(10, 6000, false)
	long:SetCount("3")
	long.cooldown:Show()
	long.cooldown:GetScript("OnShow")(long.cooldown)
	local before = env._now
	env._now = env._time - 0.125
	env.SetCombat(true)
	env._now = before
	return Common.Scene.Build(env, { time = env._time, iconDirs = Common.IconDirs() })
end)
