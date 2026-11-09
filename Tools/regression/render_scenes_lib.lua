-- render_scenes_lib.lua: what the test-render-scenes-*.lua tests share. It loads the scene scripts as libraries
-- and checks that a scene built without error, is not empty, sits on the owner's screen and writes as JSON.
rawset(_G, "RENDER_SCENE_LIB", true)

local M = {}

M.Common = dofile("Tools/render/scenes/_common.lua")
M.Hud = dofile("Tools/render/scenes/hud.lua")
M.Classes = dofile("Tools/render/scenes/_classes.lua")

-- The renderer draws every file ID the pack covers from set B, as the client does with the pack installed
-- (docs/icons.md).
M.SET_B = "Tools/icons/setB/Icons/"

function M.setB(icon)
	return M.SET_B .. icon .. ".png"
end

-- check(name, scene) -> scene. Fails on an empty scene, an error line in its log, a screen other than the owner's,
-- or JSON that is not an object or leaks a table address.
function M.check(name, scene)
	assert(type(scene) == "table" and type(scene.items) == "table", name .. ": no scene")
	assert(#scene.items > 0, name .. ": the scene is empty")
	for _, line in ipairs(scene.log) do
		assert(not line:find("error:", 1, true), name .. ": " .. line)
	end
	assert(scene.screen.height == 1080 and math.abs(scene.screen.width - 1080 * 2383 / 1540) < 0.01, name .. ": the owner's screen")
	local json = M.Common.Scene.ToJSON(scene)
	assert(json:sub(1, 1) == "{" and json:sub(-1) == "}", name .. ": JSON is an object")
	assert(not json:find("table:", 1, true), name .. ": JSON leaks a table address")
	return scene
end

-- guard(name, scene) -> scene. Fails when the render guard (Tools/render/guard.lua) finds a text the scene step
-- measures as truncated, or content past its glass card, that Tools/render/guard_allow.tsv does not cover. The
-- page's own truncations need Chrome and are checked by shoot.sh, not here.
M.runs = {}

function M.guard(name, scene)
	local Guard = dofile("Tools/render/guard.lua")
	local findings = Guard.Check(scene)
	M.runs[#M.runs + 1] = { scene = name, findings = findings }
	local fresh = Guard.Sort(findings, Guard.LoadAllow(), name)
	local lines = Guard.Lines(fresh, {}, {}, "default")
	assert(#fresh == 0, name .. " fails the render guard:\n" .. table.concat(lines, "\n"))
	return scene
end

-- globs() -> fails when an allowlist glob line matched a scene this test guarded and covered nothing in any of them
-- (Guard.Stale): a fixed defect leaves the list. Call it after every scene of a test has gone through guard().
function M.globs()
	local Guard = dofile("Tools/render/guard.lua")
	local stale = Guard.Stale(Guard.LoadAllow(), M.runs)
	assert(#stale == 0, "stale allowlist glob lines:\n" .. table.concat(Guard.GlobLines(stale), "\n"))
end

-- collect(scene) -> texts, files: the plain words the scene draws (names carry a thin space between their
-- letters; the check reads the plain word) and the texture files it draws, each as a set.
function M.collect(scene)
	local seenTexts, seenFiles = {}, {}
	for _, item in ipairs(scene.items) do
		if item.kind == "text" then
			seenTexts[(item.text:gsub("\226\128\137", ""))] = true
		elseif item.kind == "texture" and item.file then
			seenFiles[item.file] = true
		end
	end
	return seenTexts, seenFiles
end

function M.near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.002
end

function M.sameColour(v, c)
	return v and M.near(v[1], c[1]) and M.near(v[2], c[2]) and M.near(v[3], c[3])
end

return M
