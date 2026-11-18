-- audit_status.lua: the target range cue and the tank's alarm driven by unit and threat events.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
return Common.Run(function()
	local scenes = {}
	for _, module in ipairs({ "unitframes", "meters" }) do
		local scene = Hud.Module(module, { layout = "Tank", applyPreset = true, damage = { { "Valerin", "WARRIOR", 1000000 }, { "Brannoc", "MAGE", 910000 } } })
		local env = Hud.envs[scene]
		if module == "unitframes" then
			env.UnitInRange = function() return false, true end
			env.FireEvent("UNIT_IN_RANGE_UPDATE", "target")
		else
			env._threat.player = { true, 3, 100, 100, 1000000 }
			env._threat.party1 = { false, 2, 91, 91, 910000 }
			env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
		end
		dofile("Tools/render/scenes/_audit.lua").Apply(env.KstyleUI)
		env.RunTimers()
		Hud.Tick(env, 0.5)
		assert(not Common.Errors(env, env.KstyleUI), tostring(Common.Errors(env, env.KstyleUI)))
		scenes[#scenes + 1] = Common.Scene.Build(env, { iconDirs = Common.IconDirs() })
	end
	return Common.Scene.Merge(scenes)
end)
