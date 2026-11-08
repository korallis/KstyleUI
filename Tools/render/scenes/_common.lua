-- _common.lua: what every scene script shares: the owner's screen, the scene writer and the run-or-return switch.
--
--   local Common = dofile("Tools/render/scenes/_common.lua")
--   return Common.Run(function() ... return scene end)
--
-- Run(build) builds and writes the scene as JSON to arg[1] (or stdout) when the script runs as a program.
-- When a test loads the script with RENDER_SCENE_LIB set, Run returns the builder instead.
local Common = {}

Common.Scene = dofile("Tools/render/scene.lua")

-- The owner's Mac: the game renders 2383 by 1540, so one screen unit is 1540 / 1080 = 1.426 pixels. The UI
-- scale is WoW's default, 768 / 1080, so UIParent is 1080 units tall too and Blizzard's frames share the
-- root's units.
Common.SCREEN = { width = 2383, height = 1540, uiScale = 768 / 1080 }

-- The warrior's class colour, as the game's RAID_CLASS_COLORS gives it.
Common.WARRIOR = { 0.78, 0.61, 0.43 }

function Common.ScreenOpts(extra)
	local opts = { width = Common.SCREEN.width, height = Common.SCREEN.height, uiScale = Common.SCREEN.uiScale }
	for k, v in pairs(extra or {}) do
		opts[k] = v
	end
	return opts
end

-- ForceScreen(env) gives any environment the owner's screen, whatever options its loader passed on. Call it
-- from the loader's setup hook, after Stubs.NewEnv has made UIParent and before the addon loads.
function Common.ForceScreen(env)
	local width, height, uiScale = Common.SCREEN.width, Common.SCREEN.height, Common.SCREEN.uiScale
	env.GetPhysicalScreenSize = function()
		return width, height
	end
	env.UIParent._scale = uiScale
	env.UIParent._width, env.UIParent._height = 768 * width / height / uiScale, 768 / uiScale
end

-- Errors(env, K) -> the first error the stubs or KstyleUI caught, or nil.
function Common.Errors(env, K)
	if env._errors and env._errors[1] then
		return tostring(env._errors[1])
	end
	if K and type(K.ErrorCount) == "function" and K.ErrorCount() > 0 and type(K.Errors) == "function" then
		local list = K.Errors()
		return list and list[1] and tostring(list[1].message or list[1]) or "KstyleUI caught an error"
	end
	return nil
end

function Common.Write(scene, path)
	local json = Common.Scene.ToJSON(scene)
	if path then
		local f = assert(io.open(path, "wb"))
		f:write(json)
		f:close()
	else
		io.write(json)
	end
end

function Common.Run(build)
	if rawget(_G, "RENDER_SCENE_LIB") then
		return build
	end
	local scene = build()
	Common.Write(scene, arg and arg[1])
	for _, line in ipairs(scene.log or {}) do
		io.stderr:write("log: " .. line .. "\n")
	end
	return scene
end

return Common
