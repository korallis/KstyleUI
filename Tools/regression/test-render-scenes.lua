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

-- The chat tabs are laid out as Blizzard's dock lays them, skinned upper case by KstyleUI_Chat.
for _, want in ipairs({ "GENERAL", "COMBAT", "LOOT", "TRADE" }) do
	assert(texts[want], "the chat shows the " .. want .. " tab")
end

-- The centre cluster: six essential and four utility cooldown icons, each with its own warrior icon.
for _, key in ipairs({ "mortalStrike", "whirlwind", "overpower", "execute", "retaliation", "sweepingStrikes", "intercept", "hamstring", "pummel", "berserkerRage" }) do
	assert(files["KstyleUI_IconsColour/Icons/" .. Hud.ICONS[key] .. ".png"], "the cooldown rows show " .. key)
end

-- The buff row under the minimap: five icons with their time left, from the Auras module.
assert(texts["24s"] and texts["8m"], "the buff row shows its timers")
assert(files["KstyleUI_IconsColour/Icons/" .. Hud.ICONS.battleShout .. ".png"], "the buff row shows Battle Shout")

-- Combat text: the crit on the crocolisk and the heal on the player.
assert(texts["142"] and texts["+168"], "the combat numbers 142 and +168 are drawn")

-- Set A: the light art tinted by the class colour, under the white additive copy at the highlight
-- strength that brings the bright parts back.
local setA = Hud.Module("actionbars", { icons = "A" })
local lightArt, tinted, additive = false, false, false
for _, item in ipairs(setA.items) do
	if item.kind == "texture" and item.file and item.file:find("KstyleUI_Icons/Icons/", 1, true) then
		lightArt = true
		local v = item.vertex or {}
		if item.blend == "ADD" then
			additive = additive or (v[1] == 1 and v[2] == 1 and v[3] == 1 and v[4] == 0.25)
		elseif math.abs((v[1] or 0) - 0.78) < 0.02 and math.abs((v[2] or 0) - 0.61) < 0.02 and math.abs((v[3] or 0) - 0.43) < 0.02 then
			tinted = true
		end
	end
	assert(not (item.file and item.file:find("KstyleUI_IconsColour/", 1, true)), "a set A render draws nothing from set B")
end
assert(lightArt and tinted and additive, "set A icons are tinted by the warrior colour with a white additive copy at 0.25")

-- Text widths: a kit font measures by its real glyph advances (gen_glyphs.py), another face by the
-- class averages, and a Blizzard face the page draws as Source Sans measures as Source Sans.
local Scene = Common.Scene
local sample = "[14:32] [1. General] [Riverglades]: Anyone for"
local semibold = Scene.TextWidth(sample, 100, "Media\\Fonts\\SourceSans3-Semibold.ttf")
assert(math.abs(semibold - 1914.4) < 10, "the kit font's advances give " .. semibold .. " for 100 em of the sample")
assert(math.abs(Scene.TextWidth(sample, 100, "Fonts\\FRIZQT__.TTF") - semibold) < 0.01, "Friz Quadrata measures as the semibold it draws as")
assert(math.abs(Scene.TextWidth(sample, 100) - semibold) > 20, "an unknown face falls back to the class averages")

-- The scene scripts themselves return their builders when loaded as libraries.
for _, script in ipairs({ "hud_dps_mac", "components_mac", "smoke" }) do
	local build = dofile("Tools/render/scenes/" .. script .. ".lua")
	assert(type(build) == "function", script .. ".lua returns its builder")
end
check("components", Components.Build())

print("ok")
