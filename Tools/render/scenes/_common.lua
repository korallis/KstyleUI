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

-- Stand-ins Tools/render/standins.py cuts out of the owner's mockup: the portraits, the minimap's
-- terrain and the backdrop. A scene uses one when its file exists and falls back to a flat colour.
Common.STANDINS = "Tools/render/out/standins"

local function fileExists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

-- StandIn(name) -> the stand-in's repository-relative path, or nil when standins.py has not made it.
function Common.StandIn(name)
	local path = Common.STANDINS .. "/" .. name
	if fileExists(path) then
		return path
	end
	return nil
end

-- Icons: which custom icon set a scene renders with. RENDER_ICONS=A, B or off; B when unset, the
-- set the owner chose as the default. A scene's opts.icons overrides it.
local ICON_ADDONS = { A = "KstyleUI_Icons", B = "KstyleUI_IconsColour" }
local BLIZZARD_ICONS = (os.getenv("HOME") or "") .. "/.local/share/wow-dev/icons/blizzard"

function Common.IconSet(opts)
	local set = opts and opts.icons or os.getenv("RENDER_ICONS") or "B"
	set = tostring(set):upper()
	if set == "OFF" or set == "NONE" or set == "0" then
		return nil
	end
	if not ICON_ADDONS[set] then
		error("RENDER_ICONS must be A, B or off, not " .. set)
	end
	return set
end

-- IconDirs(set) -> where a numeric icon file ID resolves. With a set on, an ID the set lacks is one
-- the game draws with Blizzard's own art, so only the Blizzard folder stands in; with the sets off,
-- set B then set A stand in for Blizzard's icons the folder lacks, as the first renders did.
function Common.IconDirs(set)
	if set then
		return { BLIZZARD_ICONS }
	end
	return { "KstyleUI_IconsColour/Icons", "KstyleUI_Icons/Icons", BLIZZARD_ICONS }
end

-- IconsSection(set) -> the Icons module's saved section for a profile: on with that set, or off.
function Common.IconsSection(set)
	if set then
		return { enabled = true, set = set, tint = "class" }
	end
	return { enabled = false }
end

-- InstallAddOns(env) gives an environment C_AddOns, so the Icons service can load a data addon on
-- demand: LoadAddOn runs the addon's TOC-listed files once, which set KstyleUIIconData as in the game.
function Common.InstallAddOns(env)
	local TocFiles = dofile("Tools/regression/toc_files.lua")
	local Load = dofile("Tools/regression/load_files.lua")
	local names = {}
	for _, addon in pairs(ICON_ADDONS) do
		names[addon] = true
	end
	local loaded = {}
	local existing = env.C_AddOns
	env.C_AddOns = {
		DoesAddOnExist = function(name)
			return names[name] == true
		end,
		LoadAddOn = function(name)
			if not names[name] then
				if existing and existing.LoadAddOn then
					return existing.LoadAddOn(name)
				end
				return false, "MISSING"
			end
			if not loaded[name] then
				loaded[name] = true
				local files = {}
				for _, path in ipairs(TocFiles("%.lua$")) do
					if path:match("^" .. name .. "/") then
						files[#files + 1] = path
					end
				end
				Load(files, env)
			end
			return true
		end,
		IsAddOnLoaded = function(name)
			return loaded[name] == true, loaded[name] == true
		end,
	}
end

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
