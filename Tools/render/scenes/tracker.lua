-- tracker.lua: the objective tracker under the minimap on the owner's Mac, wearing the Skins tracker skin, built by
-- the shared stand-in in _tracker.lua the way Forever's Blizzard_ObjectiveTracker builds it.
--
--   Tools/render/shoot.sh tracker                      -- Tools/render/out/tracker.png at 1.426 px/unit
--   local build = dofile("Tools/render/scenes/tracker.lua")   -- with RENDER_SCENE_LIB set: the builder
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene
local Tracker = dofile("Tools/render/scenes/_tracker.lua")

-- Build(opts) -> the scene: the tracker in its own Skins environment, merged with the HUD's minimap for context.
-- opts.skinned false leaves the Skins module off, for the before render.
function Tracker.Build(opts)
	opts = opts or {}
	local S = dofile("Tools/regression/skins_env.lua")
	local env, K = S.New({
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = Tracker.Saved(),
		setup = function(env)
			Tracker.Shared(env)
		end,
		before = function(env)
			Tracker.StandIn(env, S.Blizzard(env), Tracker.QUESTS)
		end,
	})
	if opts.skinned ~= false then
		if not K.Modules.IsRunning("Skins") then
			K.Modules.Enable("Skins")
		end
		S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	end
	env.RunTimers()
	S.W.Settle(env)
	local scene = Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "tracker error: " .. err
	end
	scene.log[#scene.log + 1] = "tracker: Blizzard's header art, POI art and the game's fonts have no local files; the skin hushes the art"
	for i, line in ipairs(scene.log) do
		if not line:find("^tracker") then
			scene.log[i] = "tracker: " .. line
		end
	end
	if opts.minimap ~= false then
		rawset(_G, "RENDER_SCENE_LIB", true)
		local Hud = dofile("Tools/render/scenes/hud.lua")
		local minimap = Hud.Module("minimap")
		scene = Scene.Merge({ minimap, scene })
	end
	return scene
end

return Common.Run(function()
	return Tracker.Build()
end)
