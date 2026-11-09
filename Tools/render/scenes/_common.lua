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

-- ImageAspect(path) -> width / height of a PNG, read from its IHDR chunk, or nil when the file is not a PNG.
function Common.ImageAspect(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local head = file:read(24)
	file:close()
	if type(head) ~= "string" or #head < 24 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" then
		return nil
	end
	local function u32(at)
		local a, b, c, d = head:byte(at, at + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	local width, height = u32(17), u32(21)
	if width <= 0 or height <= 0 then
		return nil
	end
	return width / height
end

-- Icons: one rule for every scene. A numeric icon file ID draws set B's repaint when the pack has it
-- (Tools/icons/setB/Icons, what a player with the pack installed sees for every icon, the aura tiles
-- included), else Blizzard's own icon from the extract cache; CI has neither folder and draws a flat box.
local BLIZZARD_ICONS = (os.getenv("HOME") or "") .. "/.local/share/wow-dev/icons/blizzard"

function Common.IconDirs()
	return { "Tools/icons/setB/Icons", BLIZZARD_ICONS }
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
	-- RENDER_LOCALE (deDE, frFR, esES, zhCN, ...) renders the scene as a client of that locale sees it; a test
	-- that builds several locales in one process sets the global RENDER_LOCALE instead, as it sets RENDER_SCENE_LIB.
	local locale = rawget(_G, "RENDER_LOCALE") or os.getenv("RENDER_LOCALE")
	if locale and locale ~= "" then
		env.GetLocale = function()
			return locale
		end
	end
	-- Font strings measure their text as the page draws it (the kit fonts' glyph advances, escapes such as
	-- colour codes and links skipped, as the game skips them), so a module that sizes to GetUnboundedStringWidth
	-- lays out in the render as it does in the game.
	env._textWidth = function(text, fontPath, size)
		return Common.Scene.TextWidth(Common.Scene.PlainText(text), size, fontPath)
	end
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
	local path = arg and arg[1]
	if path then
		local Guard = dofile("Tools/render/guard.lua")
		Guard.WriteRaw(Guard.Check(scene), (path:gsub("%.json$", "")) .. ".guard.tsv")
	end
	Common.Write(scene, path)
	for _, line in ipairs(scene.log or {}) do
		io.stderr:write("log: " .. line .. "\n")
	end
	return scene
end

return Common
