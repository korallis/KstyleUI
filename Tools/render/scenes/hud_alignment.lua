-- hud_alignment.lua: chat and the cast/action/cooldown/swing strip on a game backdrop; RENDER_COOLDOWN_COUNT=1/3/6/12 and RENDER_SWING=idle/main/dual.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

return Common.Run(function()
	local opts = { class = "DRUID", layout = "DPS", applyPreset = true, settings = { Layout = { calm = false } } }
	for key, value in pairs(Reference.STATE) do opts[key] = value end
	opts.spec = {}
	for key, value in pairs(Reference.STATE.spec) do opts.spec[key] = value end
	opts.spec.cast = { "Wrath", 136006, 5176, 2.5 }
	opts.spec.bars = { { "Rejuvenation", 136081, {12,8} }, { "Regrowth", 136085, {21,15} } }
	opts.target = {}
	for key, value in pairs(Reference.STATE.target) do opts.target[key] = value end
	opts.target.name = "Boar"
	local count = tonumber(os.getenv("RENDER_COOLDOWN_COUNT")) or 1
	assert(count == 1 or count == 3 or count == 6 or count == 12, "RENDER_COOLDOWN_COUNT must be 1, 3, 6 or 12")
	opts.spec.essential, opts.spec.utility = {}, {}
	for i = 1, count do
		local spell = Reference.STATE.spec.essential[(i - 1) % 6 + 1]
		opts.spec.essential[i] = { spell[1] .. " " .. i, spell[2], spell[3] }
		opts.spec.utility[i] = { "Utility " .. i, spell[2] }
	end
	local scenes = {}
	for _, name in ipairs({ "chat", "unitframes", "actionbars", "cooldowns", "meters" }) do
		local scene = Hud.Module(name, opts)
		if name == "meters" and os.getenv("RENDER_SWING") ~= "idle" then
			local env = Hud.envs[scene]
			local kind = env.Enum.PlayerSwingType
			env.FireEvent("PLAYER_SWING", 2.6, kind.MainHand)
			if os.getenv("RENDER_SWING") == "dual" then
				env._speeds[2] = 2.4
				env.FireEvent("PLAYER_SWING", 2.4, kind.OffHand)
			end
			env.SetTime(env.GetTime() + 1.1)
			dofile("Tools/regression/meters_env.lua").Tick(env)
			scene = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
		end
		scenes[#scenes + 1] = scene
	end
	return Common.Scene.Merge(scenes)
end)
