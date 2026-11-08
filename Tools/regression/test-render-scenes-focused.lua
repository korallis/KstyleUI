-- test-render-scenes-focused.lua: every focused render scene (components, tooltip, tracker, buttons, cooldowns,
-- nameplate, data bars, chat, the design-file unit frames, RestedXP) returns its builder and builds what it shows.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check
local Components = dofile("Tools/render/scenes/components.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")
local RestedXP = dofile("Tools/render/scenes/restedxp.lua")

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

-- The RestedXP windows the fake builds, skinned, laid out by the scene: the step window, the guide window and the
-- v2 window show as glass, with the step plate and footer texts.
local rested = check("restedxp", RestedXP())
local restedTexts = {}
for _, item in ipairs(rested.items) do
	if item.kind == "text" then
		restedTexts[item.text] = true
	end
end
for _, want in ipairs({ "Step 25", "RestedXP Guides v4.11.34", "Durotar 1-6" }) do
	assert(restedTexts[want], "the RestedXP scene shows " .. want)
end

print("ok")
