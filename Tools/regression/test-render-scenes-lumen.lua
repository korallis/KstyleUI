-- test-render-scenes-lumen.lua: the Lumen Rails HUD scenes build both states of the mockup boards: out of combat the
-- guide and the tracker fit the right rail's story slot as one card, where Apply puts them, the party card and chat share the left rail's edge, and every card is lit; in combat the idle cards rest at 30%, the cards you
-- read (chat, map, tracker, guide) dim only to 75%, and the focus cards stay lit.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

for _, script in ipairs({ "hud_lumen_questing", "hud_lumen_combat" }) do
	assert(type(dofile("Tools/render/scenes/" .. script .. ".lua")) == "function", script .. ".lua returns its builder")
end

local function plain(text)
	return (text:gsub("\226\128\137", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- find(scene, text) -> the first text item that reads text (case kept), or nil.
local function find(scene, text)
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.text and plain(item.text) == text then
			return item
		end
	end
end

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.02
end

local questing = L.guard("hud_lumen_questing", check("hud_lumen_questing", Lumen.Build("questing")))
local combat = L.guard("hud_lumen_combat", check("hud_lumen_combat", Lumen.Build("combat")))
L.globs()
local slot = questing.slot

-- The story slot holds the RestedXP guide's card and the quests stand in their own column a rail gap to its left, at
-- the same top (KSTY-33), on the right rail under the map and the aura rows and over the damage meter (owner,
-- 2026-11-09: "The quest tracker can go back to the right side").
local column = questing.column
local function within(item, box, what)
	local r = item.rect
	assert(r[1] >= box.left - 0.5 and r[1] + r[3] <= box.left + box.width + 0.5 and r[2] >= box.top - 0.5 and r[2] + r[4] <= box.top + box.height + 0.5,
		what .. " sits in its card's place, got " .. table.concat(r, ", "))
end
do
	within(assert(find(questing, "QUESTS"), "the quests' caption draws"), column, "the quests' caption")
	within(assert(find(questing, "[8] Break a Few Eggs"), "the second quest draws, with Forever's level"), column, "the second quest")
	assert(not find(questing, "RestedXP Guides v4.11.35") and not find(questing, "Speedrun Guide 1-22"), "the guide's version footer and its group line, which repeat the head, are hushed")
	within(assert(find(questing, "2/10 Kul Tiras Sailor slain"), "the guide's active step draws"), slot, "the guide's active step")
	assert(find(questing, "DAMAGE  HEALING").rect[2] >= slot.top + slot.height, "the damage meter's cap sits under the slot")
	assert(math.abs(column.top - slot.top) < 0.01 and math.abs(slot.left - (column.left + column.width) - 16 * 16 / 19) < 0.02, "the quests' column stands a rail gap left of the slot, at its top")
end

-- Two rails. The left holds the party card and chat on one left edge, the party card 318 wide, chat 393, the party over
-- chat. On the right the guide's card holds the story slot on the rail's edge and width, and the quest card wears its
-- own glass in its column; neither card's words leave it.
for _, scene in ipairs({ questing, combat }) do
	local seen = {}
	for _, card in ipairs(scene.rail) do
		seen[card.name] = card
	end
	local party, chat, guide, quests = seen.party, seen.chat, seen.guide, seen.quests
	assert(party and chat and guide and quests, scene.state .. ": the rails show the party, chat, the guide and the quests")
	assert(math.abs(party.left - chat.left) <= 0.5, scene.state .. ": the party card and chat share the left edge, got " .. party.left .. " and " .. chat.left)
	assert(party.left < slot.left / 2, scene.state .. ": on the left rail")
	assert(math.abs(chat.width - party.width * 393 / 318) <= 1, scene.state .. ": chat is 393 wide against the party's 318, got " .. chat.width .. " for " .. party.width)
	assert(chat.top >= party.top + party.height - 0.5, scene.state .. ": chat starts under the party card")
	assert(math.abs(guide.left - slot.left) <= 0.5 and math.abs(guide.width - slot.width) <= 1, scene.state .. ": the guide's card is on the right rail's edge and width, got " .. guide.left .. " by " .. guide.width)
	assert(guide.top >= slot.top - 0.5 and guide.top + guide.height <= slot.top + slot.height + 0.5, scene.state .. ": the guide's card stays inside the story slot")
	assert(math.abs(quests.left - column.left) <= 0.75 and quests.top >= column.top - 0.75 and quests.top + quests.height <= column.top + column.height + 0.75, scene.state .. ": the quest card stays in its column, got " .. quests.left .. ", " .. quests.top .. ", " .. quests.height .. " for " .. column.left .. ", " .. column.top .. ", " .. column.height)
	for _, text in ipairs({ "QUESTS", "Bloodtalon Scythemaw" }) do
		local item = assert(find(scene, text), scene.state .. ": " .. text .. " draws")
		within(item, quests, scene.state .. ": '" .. text .. "'")
	end
	for _, text in ipairs({ "6-10 DUROTAR", "Step 34" }) do
		local item = assert(find(scene, text), scene.state .. ": " .. text .. " draws")
		within(item, guide, scene.state .. ": '" .. text .. "'")
	end
end

-- The rails keep the screen margin (Tokens screenMargin): nothing on either rail draws past the screen's bottom margin (the readout
-- card's docked menu rows fall under the card when it is a hair short of their height). The scenes render at the
-- shipped Interface size, so a root unit is 16 / 19 of a screen unit.
local SIZE = 16 / 19
local _, K = dofile("Tools/regression/core_env.lua").New()
local MARGIN = K.Tokens.Size("screenMargin")
local RAIL_EDGE = MARGIN + 318
for _, scene in ipairs({ questing, combat }) do
	local width = scene.screen.width
	for _, item in ipairs(scene.items) do
		local r = item.rect
		local shadow = item.file and item.file:find("Shadow", 1, true)
		if r and not shadow and (item.alpha or 1) > 0 and (r[1] >= width - RAIL_EDGE * SIZE or r[1] + r[3] <= RAIL_EDGE * SIZE) then
			assert(r[2] + r[4] <= 1080 - MARGIN * SIZE + 0.5, scene.state .. ": a " .. item.kind .. " on a rail reaches past the bottom margin: " .. table.concat(r, ", "))
		end
	end
end

-- Out of combat: no target, a party of three, the last fight's three rows, every card at full alpha.
do
	assert(not find(questing, "BLOODTALON MATRIARCH") and not find(questing, "RIVERGLADE CROCOLISK"), "no target out of combat")
	for _, name in ipairs({ "Leduc", "Trolly" }) do
		assert(find(questing, name), "the party shows " .. name)
	end
	assert(not find(questing, "Khont"), "a party of three")
	for _, text in ipairs({ "GENERAL", "QUESTS", "RIVERGLADES", "DAMAGE  HEALING" }) do
		assert(near(find(questing, text).alpha, 1), text .. " is lit out of combat")
	end
end

-- In combat: the boss card and the boss as the target with its cast; the idle cards calm, the read cards dim a little,
-- the focus cards stay lit.
do
	for _, name in ipairs({ "Leduc", "Trolly", "Khont", "Mira" }) do
		assert(find(combat, name), "the party of five shows " .. name)
	end
	assert(find(combat, "BLOODTALON MATRIARCH"), "the boss is the target")
	assert(find(combat, "TERRIFYING SCREECH"), "and its cast shows in capitals")
	local map = assert(find(combat, "RIVERGLADES"), "RIVERGLADES draws in combat")
	assert(near(map.alpha, 0.75), "the map is read mid-pull and dims only to 75% in combat, got " .. tostring(map.alpha))
	local tab = assert(find(combat, "GENERAL"), "GENERAL draws in combat")
	assert(near(tab.alpha, 1), "the chat card keeps its material solid in combat (KSTY-50), got " .. tostring(tab.alpha))
	-- Round 5 (Muse 6e): the story card, objective lines over bright scenery, rests at 90%, above the chat card.
	for _, text in ipairs({ "QUESTS", "6-10 DUROTAR" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 0.9), text .. " is on the story card and dims only to 90% in combat, got " .. tostring(item.alpha))
	end
	-- Round 3 (Muse #3): the readout keeps a legible 65% floor in combat instead of ghosting at 30%.
	for _, text in ipairs({ "fps", "ms" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 0.65), text .. " is on the readout and rests at a legible 65% in combat, got " .. tostring(item.alpha))
	end
	for _, text in ipairs({ "Leduc", "DAMAGE  HEALING", "BLOODTALON MATRIARCH", "VALERIN" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 1), text .. " stays lit in combat, got " .. tostring(item.alpha))
	end
end

-- Chat lines never overprint (round 3, Muse D1): in both states every line drawn on the chat's glass, wrapped loot
-- lines included, sits on its own row; a row's box may touch the next, never cover it.
for _, scene in ipairs({ questing, combat }) do
	local glass
	for _, card in ipairs(scene.rail) do
		if card.name == "chat" then
			glass = card
		end
	end
	assert(glass, scene.state .. ": the rail has the chat card")
	local rows = {}
	for _, item in ipairs(scene.items) do
		local r = item.rect
		if item.kind == "text" and r[2] >= glass.top + 30 and r[2] + r[4] <= glass.top + glass.height + 0.5
			and r[1] >= glass.left and r[1] < glass.left + glass.width then
			rows[#rows + 1] = item
		end
	end
	assert(#rows >= 5, scene.state .. ": the chat draws its lines, got " .. #rows)
	for i = 1, #rows do
		local a = rows[i].rect
		assert(a[4] >= rows[i].font.size * (rows[i].lineEm or 1.2) - 0.5, scene.state .. ": a chat row is shorter than its line, so its glyphs reach the next: '" .. rows[i].text .. "'")
		for j = i + 1, #rows do
			local b = rows[j].rect
			local across = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
			local down = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
			assert(across <= 0 or down <= 0.5, scene.state .. ": chat lines overprint: '" .. rows[i].text .. "' and '" .. rows[j].text .. "'")
		end
	end
end

print("render scenes lumen ok")
