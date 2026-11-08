-- test-render-scenes.lua: every render scene builds a non-empty scene with no error, and the JSON it writes parses.
rawset(_G, "RENDER_SCENE_LIB", true)

local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Components = dofile("Tools/render/scenes/components.lua")

local function check(name, scene)
	assert(type(scene) == "table" and type(scene.items) == "table", name .. ": no scene")
	assert(#scene.items > 0, name .. ": the scene is empty")
	for _, line in ipairs(scene.log) do
		assert(not line:find("error:", 1, true), name .. ": " .. line)
	end
	assert(scene.screen.height == 1080 and math.abs(scene.screen.width - 1080 * 2383 / 1540) < 0.01, name .. ": the owner's screen")
	local json = Common.Scene.ToJSON(scene)
	assert(json:sub(1, 1) == "{" and json:sub(-1) == "}", name .. ": JSON is an object")
	assert(not json:find("table:", 1, true), name .. ": JSON leaks a table address")
	return scene
end

-- Each HUD module in its own environment, then the merge.
local scenes = {}
for _, name in ipairs(Hud.Order()) do
	scenes[#scenes + 1] = check("hud." .. name, (Hud.Module(name)))
end
local hud = check("hud", Common.Scene.Merge(scenes))
local total = 0
for _, scene in ipairs(scenes) do
	total = total + #scene.items
end
assert(#hud.items == total, "the merge keeps every module's drawables")

-- The HUD shows the mockup's state: the player's name, Slam, the target, and warrior icons from set B.
local texts, files = {}, {}
for _, item in ipairs(hud.items) do
	if item.kind == "text" then
		-- Names carry a thin space between their letters; the check reads the plain word.
		texts[(item.text:gsub("\226\128\137", ""))] = true
	elseif item.kind == "texture" and item.file then
		files[item.file] = true
	end
end
for _, want in ipairs({ "VALERIN", "SLAM", "RIVERGLADE CROCOLISK", "82%", "Battle Shout", "Enrage" }) do
	assert(texts[want], "the HUD shows " .. want)
end
assert(files["KstyleUI_IconsColour/Icons/" .. Hud.ICONS.slam .. ".png"], "Slam's icon comes from set B")
local swipes = 0
for _, item in ipairs(hud.items) do
	if item.kind == "swipe" then
		swipes = swipes + 1
	end
end
assert(swipes >= 1, "a cooldown swipe is drawn")

-- The scene scripts themselves return their builders when loaded as libraries.
for _, script in ipairs({ "hud_dps_mac", "components_mac", "smoke" }) do
	local build = dofile("Tools/render/scenes/" .. script .. ".lua")
	assert(type(build) == "function", script .. ".lua returns its builder")
end
check("components", Components.Build())

print("ok")
