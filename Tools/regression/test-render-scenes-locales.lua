-- test-render-scenes-locales.lua: the settings scenes build in every shipped locale, navigating by string keys
-- rather than English labels, and the render guard finds no truncated, spilled, clipped or overlapping text on
-- the settings window in any of them: the rail, the rows, their controls, the header and the preview caption, at
-- the window's default size and at its minimum size scaled to 0.65, on the Unit Frames, Party and Raid,
-- Nameplates, Profiles and General pages, in deDE, frFR, esES and zhCN (round 5: Astra #3, U1 and V1). A module's
-- sample content inside the preview holder (creature and spell names) belongs to that module's scenes and is
-- listed here as a note, not a failure.
local L = dofile("Tools/regression/render_scenes_lib.lua")

local LOCALES = { "deDE", "frFR", "esES", "zhCN" }
local SCENES = { "gallery_options", "gallery_options_modules" }
local MIN_TRANSLATED = 20

local Guard = dofile("Tools/render/guard.lua")
local allow = Guard.LoadAllow()

-- inPreview(object) -> true for a drawable under the preview pane's holder: a module's own sample content.
local function inPreview(object)
	local node = object
	while node do
		local parent = node._parent
		if parent and parent.holder == node and parent.built then
			return true
		end
		node = parent
	end
	return false
end

-- A scene drawn in a locale shows that locale's words, not the English keys: count texts the locale table knows.
local function translated(scene, code)
	local W = dofile("Tools/regression/widget_env.lua")
	local _, K = W.New({
		setup = function(env)
			env.GetLocale = function()
				return code
			end
		end,
	})
	local n = 0
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and K.Locale.IsTranslation((item.text:gsub("\226\128\137", ""))) then
			n = n + 1
		end
	end
	return n
end

for _, code in ipairs(LOCALES) do
	rawset(_G, "RENDER_LOCALE", code)
	for _, name in ipairs(SCENES) do
		local build = dofile("Tools/render/scenes/" .. name .. ".lua")
		local ok, scene = pcall(build)
		assert(ok, code .. " " .. name .. " builds: " .. tostring(scene))
		L.check(code .. " " .. name, scene)
		local findings = Guard.Check(scene)
		local fresh = Guard.Sort(findings, allow, name)
		local window, notes = {}, {}
		for _, finding in ipairs(fresh) do
			if inPreview(finding.object) then
				notes[#notes + 1] = finding
			else
				window[#window + 1] = finding
			end
		end
		for _, line in ipairs(Guard.Lines(notes, {}, {}, "default")) do
			print("note: " .. code .. " " .. name .. " preview sample: " .. line)
		end
		local lines = Guard.Lines(window, {}, {}, "default")
		assert(#window == 0, code .. " " .. name .. " fails the render guard on the settings window:\n" .. table.concat(lines, "\n"))
		local words = translated(scene, code)
		assert(words >= MIN_TRANSLATED, code .. " " .. name .. " draws the locale's words, found " .. words)
		collectgarbage("collect")
	end
end
rawset(_G, "RENDER_LOCALE", nil)

print("render scenes locales ok")
