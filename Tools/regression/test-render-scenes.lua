-- test-render-scenes.lua: every render scene builds a non-empty scene with no error, and the JSON it writes parses.
rawset(_G, "RENDER_SCENE_LIB", true)

local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Components = dofile("Tools/render/scenes/components.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")

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
for _, want in ipairs({ "VALERIN", "Slam", "RIVERGLADE CROCOLISK", "82%", "Battle Shout", "Enrage" }) do
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

-- The centre cluster's countdowns read with their unit, as the mockup's "4s" and "2m".
assert(texts["4s"] and texts["2m"], "the cooldown rows show 4s and 2m")

-- The quest tracker is the shared stand-in with the skin's one caption header and numbered discs.
assert(texts["QUESTS"] and texts["1"] and texts["2"] and not texts["Quests"], "the HUD's tracker shows the QUESTS caption and the numbered discs")

-- The chat's tabs sit on Blizzard's dock as FCFDock_UpdateTabs lays them, with the plus glyph at the right end.
local hudPlus = 0
for _, item in ipairs(hud.items) do
	if item.kind == "texture" and item.file and item.file:find("GlyphClose", 1, true) and item.rotation and math.abs(item.rotation - math.pi / 4) < 1e-3 then
		hudPlus = hudPlus + 1
	end
end
assert(hudPlus == 1, "the HUD's chat draws the plus glyph once, got " .. hudPlus)

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

-- The tooltip's title keeps a blank second line for the rarity caption, so the caption sits under the name
-- and the next line under both, as the game lays GameTooltip's lines out.
local function textItem(scene, prefix)
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and (item.text:gsub("\226\128\137", "")):sub(1, #prefix) == prefix then
			return item
		end
	end
	error("no text " .. prefix)
end
for _, triple in ipairs({ { scenes[#scenes], "VANQUISHER", "Item Level" }, { Tooltip.Build(), "RANGER", "Level 38" } }) do
	local scene, name = triple[1], triple[2]
	local title, caption, second = textItem(scene, name), textItem(scene, "UNCOMMON"), textItem(scene, triple[3])
	local line = title.font.size * 1.2
	assert(math.abs(second.rect[2] - (title.rect[2] + title.rect[4] + 0.5)) < 0.01, name .. ": the next line follows the title at the skin's half-unit spacing")
	assert(title.rect[4] >= 2 * line - 0.01, name .. ": the title is two lines tall")
	assert(caption.rect[2] >= title.rect[2] + line - 0.01, name .. ": the caption sits on the title's second line")
	assert(second.rect[2] >= title.rect[2] + title.rect[4] - 0.01, name .. ": the next line sits under the title's second line")
end

-- The scene scripts themselves return their builders when loaded as libraries.
for _, script in ipairs({ "hud_dps_mac", "components_mac", "tooltip_design", "smoke", "buttons_mac", "buttons_toned", "nameplate", "databars", "tracker", "chat", "unitframes_design" }) do
	local build = dofile("Tools/render/scenes/" .. script .. ".lua")
	assert(type(build) == "function", script .. ".lua returns its builder")
end

-- The tracker scene builds Blizzard's tracker the way Forever does and shows the skin's one caption header,
-- its numbered discs and the quest titles, with no Blizzard header text left visible.
do
	local tracker = check("tracker", dofile("Tools/render/scenes/tracker.lua")())
	local shown = {}
	for _, item in ipairs(tracker.items) do
		if item.kind == "text" then
			shown[(item.text:gsub("\226\128\137", ""))] = true
		end
	end
	for _, want in ipairs({ "QUESTS", "1", "2", "Riverglade Crocolisks", "The Lost Patrol", "RIVERGLADES" }) do
		assert(shown[want], "the tracker scene shows " .. want)
	end
	assert(not shown["All Objectives"] and not shown["Quests"], "Blizzard's two header shown are hushed")
end
check("components", Components.Build())
check("tooltip", Tooltip.Build())

-- The button scene: the six states twice, bag slots, aura tiles, and the micro menu and bag bar; a toned
-- rim changes only the secondary buttons' hairlines.
local Buttons = dofile("Tools/render/scenes/buttons.lua")
local full = check("buttons", Buttons.Build({ rim = 1 }))
local toned = check("buttons toned", Buttons.Build({ rim = 0.5 }))
assert(#full.items == #toned.items, "the toned scene draws the same drawables")
local fullTexts, buttonSwipes = {}, 0
for _, item in ipairs(full.items) do
	if item.kind == "text" then
		fullTexts[item.text] = true
	elseif item.kind == "swipe" then
		buttonSwipes = buttonSwipes + 1
	end
end
for _, want in ipairs({ "NORMAL", "HOVER", "PRESSED", "COOLDOWN", "PROC", "DISABLED", "3" }) do
	assert(fullTexts[want], "the button scene shows " .. want)
end
assert(buttonSwipes >= 2, "both cooldown buttons draw their swipe")
-- The cooldowns scene: the mirror's buff bars draw their countdowns right-aligned through the Cooldown's
-- own font string, and Blizzard's restyled viewer items draw with the dark button body.
local cooldowns = check("cooldowns", dofile("Tools/render/scenes/cooldowns.lua")())
local rightAligned, fills = {}, 0
for _, item in ipairs(cooldowns.items) do
	if item.kind == "text" and item.justifyH == "RIGHT" then
		rightAligned[item.text] = true
	elseif item.kind == "texture" and item.bar then
		fills = fills + 1
	end
end
assert(rightAligned["24s"] and rightAligned["12s"], "the buff bars' countdowns draw right-aligned, with their unit")
assert(fills >= 2, "the buff bars draw their fills")

-- The focused scenes. The nameplate scene puts the plate on a base the game scaled to 0.58, as the owner's Mac
-- does, and the plate still draws its 175 by 18 bar in root units.
local plate = check("nameplate", dofile("Tools/render/scenes/nameplate.lua")())
local fill
for _, item in ipairs(plate.items) do
	if item.kind == "texture" and item.fraction and math.abs(item.fraction - 864 / 1540) < 0.001 then
		fill = item
	end
end
assert(fill, "the plate's health fill is drawn")
assert(math.abs(fill.rect[3] - 175 * 864 / 1540) < 1 and math.abs(fill.rect[4] - 18) < 1, "the bar is 175 by 18 screen units on a 0.58 base, got " .. fill.rect[3] .. " x " .. fill.rect[4])
local databars = check("databars", dofile("Tools/render/scenes/databars.lua")())
local seen = {}
for _, item in ipairs(databars.items) do
	if item.kind == "text" then
		seen[item.text] = true
	end
end
for _, want in ipairs({ "XP 32%", "FPS:", "144", "34 ms", "143g 82s 17c", "Durability:", "96%", "14:32" }) do
	assert(seen[want], "the data bars scene shows " .. want)
end

-- The chat scene shows the mockup's four tabs on Blizzard's dock, the plus glyph and five lines.
local chat = check("chat", (dofile("Tools/render/scenes/chat.lua"))())
local chatTexts, plus, lines = {}, 0, 0
for _, item in ipairs(chat.items) do
	if item.kind == "text" then
		chatTexts[item.text] = true
		if item.text:find("[14:3", 1, true) then
			lines = lines + 1
		end
	elseif item.kind == "texture" and item.file and item.file:find("GlyphClose", 1, true) and item.rotation and math.abs(item.rotation - math.pi / 4) < 1e-3 then
		plus = plus + 1
	end
end
for _, want in ipairs({ "GENERAL", "COMBAT", "LOOT", "TRADE" }) do
	assert(chatTexts[want], "the chat scene shows the " .. want .. " tab")
end
assert(plus == 1, "the plus glyph is drawn once, got " .. plus)
assert(lines == 5, "five timestamped lines, got " .. lines)

-- The unit frames with the design file's octagon portraits, at the design's sections.
local design = check("unitframes_design", dofile("Tools/render/scenes/unitframes_design.lua")())
local designTexts = {}
for _, item in ipairs(design.items) do
	if item.kind == "text" then
		designTexts[(item.text:gsub("\226\128\137", ""))] = true
	end
end
for _, want in ipairs({ "VALERIN", "FROST HOWLER", "78%", "56%", "FROST BITE", "42", "40" }) do
	assert(designTexts[want], "the design scene shows " .. want)
end

print("ok")
