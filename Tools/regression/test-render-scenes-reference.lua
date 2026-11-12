-- test-render-scenes-reference.lua: the reference scene (scenes/hud_reference.lua) builds staging's HUD in the state of the owner's picture of 2026-11-09, on his 3456 by 2234 screen, and gives every later scene the Mac screen back.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

assert(type(dofile("Tools/render/scenes/hud_reference.lua")) == "function", "hud_reference.lua returns its builder")

local scene = Reference.Build()
assert(type(scene) == "table" and #scene.items > 0, "the reference scene draws")
for _, line in ipairs(scene.log) do
	assert(not line:find("error:", 1, true), "reference: " .. line)
end
local physical = scene.screen.physical
assert(physical.width == 3456 and physical.height == 2234, "the scene draws the owner's full screen, got " .. physical.width .. " by " .. physical.height)
assert(scene.screen.height == 1080 and math.abs(scene.screen.width - 1080 * 3456 / 2234) < 0.01, "the screen is 1080 units tall at the panel's aspect")
assert(rawget(_G, "RENDER_SCREEN") == nil, "the build gives the global screen back")
assert(L.Common.SCREEN.width == 2383 and L.Common.SCREEN.height == 1540, "later scenes draw the Mac window again")

local texts = L.collect(scene)
local buffX = {}
for _, item in ipairs(scene.items) do
	if item.kind == "text" and (item.text == "8s" or item.text == "14s") then
		buffX[item.text] = item.rect[1]
	end
end
assert(buffX["8s"] and buffX["14s"] and buffX["8s"] < buffX["14s"], "the configured tracked buffs read 8s then 14s from left to right beside the portrait")
for _, text in ipairs({ "Windfield Orchard", "[11] Unnerving Silence", "[9] Crab Season", "Lightning Bolt", "Searing Totem", "203", "Korallis", "Shadowgale Poacher" }) do
	local found = texts[text]
	if not found then
		for seen in pairs(texts) do
			if seen:upper() == text:upper() then
				found = true
			end
		end
	end
	assert(found, "the picture's state draws " .. text)
end
local function chatLine(prefix)
	for seen in pairs(texts) do
		if seen:find(prefix, 1, true) then
			return true
		end
	end
end
assert(chatLine("Congratulations, you have reached"), "the session's chat lines draw")

-- The story card in the picture's state (LEE-67, handoffs/reference-diff/DIFF-acceptance-1.md section 3): the first
-- quest's objective wraps onto three lines that stand a row apart, each quest's disc stands a pixel in from the
-- caption marks, and the glass is as tall as the picture's. The acceptance pass's clean-plate rule reads the glass's
-- 553 pixels as 557, the rim's shadow with it.
do
	local Scene = dofile("Tools/render/scene.lua")
	local ppu = physical.height / scene.screen.height
	local title, objective, row, dot, mark, glass
	local dots, marks = {}, {}
	for _, item in ipairs(scene.items) do
		local file = item.kind == "texture" and tostring(item.file) or ""
		if item.kind == "text" and item.text == "[11] Unnerving Silence" then
			title = item
		elseif item.kind == "text" and title and item.spacing and math.abs(item.rect[1] - title.rect[1]) < 0.01 then
			if not objective then
				objective = item
			elseif not row and Scene.WrappedLines(Scene.PlainText(item.text), item.font.size, item.font.path, item.rect[3]) == 1 then
				row = item
			end
		elseif file:find("Diamond.png", 1, true) then
			marks[#marks + 1] = item
		elseif file:find("Dot.png", 1, true) then
			dots[#dots + 1] = item
		end
	end
	for _, item in ipairs(title and dots or {}) do
		local middle = item.rect[2] + item.rect[4] / 2
		if item.rect[1] < title.rect[1] and title.rect[1] - item.rect[1] < 30 and middle > title.rect[2] and middle < title.rect[2] + title.rect[4] then
			dot = item
		end
	end
	for _, item in ipairs(dot and marks or {}) do
		if math.abs(item.rect[1] - dot.rect[1]) < 3 and item.rect[2] < dot.rect[2] and (not mark or item.rect[2] > mark.rect[2]) then
			mark = item
		end
	end
	assert(title and objective and row and dot and mark, "the story card draws its caption mark, a quest disc, a wrapped objective and a one-line objective")
	for _, item in ipairs(scene.items) do
		local r = item.rect
		if item.kind == "texture" and tostring(item.file):find("CardShape.png", 1, true) and r[1] <= title.rect[1] and r[1] + r[3] >= title.rect[1] and r[2] <= title.rect[2] and r[2] + r[4] >= title.rect[2] then
			glass = glass or { r[2], r[2] + r[4] }
		end
	end
	assert(glass, "the story card's glass is under its first quest")
	for _, item in ipairs(scene.items) do
		local r = item.rect
		if item.kind == "texture" and tostring(item.file):find("CardShape.png", 1, true) and r[1] <= title.rect[1] and r[1] + r[3] >= title.rect[1] then
			if math.abs(r[2] + r[4] - glass[1]) < 0.01 then
				glass[1] = r[2]
			elseif math.abs(r[2] - glass[2]) < 0.01 then
				glass[2] = r[2] + r[4]
			end
		end
	end
	local lines = Scene.WrappedLines(Scene.PlainText(objective.text), objective.font.size, objective.font.path, objective.rect[3])
	assert(lines == 3, "the first objective takes the picture's three lines in the 278-unit card, got " .. lines)
	assert(objective.spacing > 0 and math.abs(objective.rect[4] - 3 * row.rect[4]) < 0.01, "and its lines stand a row apart: three rows high, got " .. objective.rect[4] .. " for a row of " .. row.rect[4])
	local lead = (dot.rect[1] - mark.rect[1]) * ppu
	assert(lead > 1.5 and lead < 2.5, "the disc texture starts two pixels in from the caption mark, drawing the picture's core a pixel farther in, got " .. lead)
	assert(math.abs(dot.rect[3] * ppu - 28) < 0.01, "the disc draws the picture's 28-pixel core, as the acceptance mask measures, got " .. dot.rect[3] * ppu)
	local tall = (glass[2] - glass[1]) * ppu
	-- KSTY-33 split the picture's story card (553 pixels, the guide's head and step over the quests) into two cards: the
	-- quest card's own glass holds the caption and the four quests at the picture's rhythm, 429 pixels.
	assert(math.abs(tall - 429) <= 1.5, "the quest card's own glass is 429 pixels tall, within a pixel, got " .. tall)
end

-- The picture's bars are on: bar 2 over bar 1 and bars 4 and 5 as the right-hand columns; the Layout rects are kept for
-- handoffs/reference-diff/DIFF.md's measurements.
local elements = assert(scene.elements, "the scene keeps the Layout elements' rects")
for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.bar4", "actionbars.bar5", "unitframes.player", "unitframes.target", "minimap.main", "meters.damage", "chat.main", "databars.xp" }) do
	assert(elements[key], "the scene measures " .. key)
end
assert(elements["actionbars.bar2"].bottom > elements["actionbars.bar1"].bottom, "bar 2 stands over bar 1")

dofile("Tools/regression/render_reference_lib.lua")("DPS", scene)
rawset(_G, "RENDER_SCREEN", { width = 1280, height = 720, size = 0.6 })
local nested = dofile("Tools/render/scenes/_common.lua")
local opts = nested.ScreenOpts()
assert(opts.width == 1280 and opts.height == 720 and opts.size == 0.6 and opts.uiScale == 768 / 1080, "screen overrides retain the UI scale default")
rawset(_G, "RENDER_SCREEN", { width = 1920, height = 1080, uiScale = 0.65, size = 1.5 })
assert(nested.SCREEN.width == 1920 and L.Common.SCREEN.width == 1920 and nested.SCREEN.size == 1.5, "already-loaded scenes follow the next screen and requested size")
rawset(_G, "RENDER_SCREEN", nil)
assert(nested.SCREEN.width == 2383 and nested.SCREEN.height == 1540 and nested.SCREEN.size == nil, "a scene loaded during an override does not retain it")
-- The chat lines stand the picture's 32 physical pixels apart (LEE-86): a line of the game's ScrollingMessageFrame is as tall
-- as its font (ScrollingMessageFrame.lua 730-735) and stands on the one below plus GetSpacing (595-602), so the scene gives its
-- lines one em, not 1.2, and the default 4.5-unit spacing makes the picture's pitch on the owner's screen.
do
	local ppu = physical.height / scene.screen.height
	local rows = {}
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.lineEm == 1 then
			rows[#rows + 1] = item
		end
	end
	table.sort(rows, function(a, b) return a.rect[2] < b.rect[2] end)
	assert(#rows >= 6, "the chat draws at least six lines, got " .. #rows)
	for i = 2, #rows do
		local pitch = (rows[i].rect[2] - rows[i - 1].rect[2]) * ppu
		assert(math.abs(pitch - 32) < 1, "chat line " .. i .. " stands " .. pitch .. " px below the one above; the picture's pitch is 32")
	end
end
print("ok test-render-scenes-reference")
