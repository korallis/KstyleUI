-- test-render-scenes-lumen.lua: the Lumen Rails HUD scenes build both states of the mockup boards: out of combat the
-- guide and the tracker fit the story slot, where Apply puts them, on one left rail with the other cards, and every card is lit; in combat the idle cards rest at 30%, the cards you
-- read (chat, map, tracker, guide) dim only to 75%, and the focus cards stay lit.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

for _, script in ipairs({ "hud_lumen_questing", "hud_lumen_combat" }) do
	assert(type(dofile("Tools/render/scenes/" .. script .. ".lua")) == "function", script .. ".lua returns its builder")
end

local function plain(text)
	return (text:gsub("\226\128\137", ""))
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

local questing = check("hud_lumen_questing", Lumen.Build("questing"))
local combat = check("hud_lumen_combat", Lumen.Build("combat"))
local slot = questing.slot

-- The story slot holds the guide and the tracker, as the player places them; chat sits under it.
do
	local function inside(item, what)
		local r = item.rect
		assert(r[1] >= slot.left and r[1] + r[3] <= slot.left + slot.width and r[2] >= slot.top and r[2] + r[4] <= slot.top + slot.height,
			what .. " sits in the story slot, got " .. table.concat(r, ", "))
	end
	inside(assert(find(questing, "QUESTS"), "the tracker's caption draws"), "the tracker's caption")
	inside(assert(find(questing, "Encroachment"), "the third quest draws"), "the third quest")
	inside(assert(find(questing, "RestedXP Guides v4.11.35"), "the guide's footer draws"), "the guide's footer")
	assert(find(questing, "GENERAL").rect[2] >= slot.top + slot.height, "the chat's tabs sit under the slot")
end

-- One left rail (round 2, Fable): the party card, RestedXP's steps, head and footer, the quests and chat share one
-- left edge and one width, the layout's 318-unit rail on the 28-unit margin; no card overlaps the next; the guide's
-- footer sits one rail gap above the quests.
for _, scene in ipairs({ questing, combat }) do
	local rail = scene.rail
	local seen = {}
	for i, card in ipairs(rail) do
		seen[card.name] = card
		assert(math.abs(card.left - slot.left) <= 0.5, scene.state .. ": " .. card.name .. "'s glass starts on the rail's left edge, got " .. card.left)
		assert(math.abs(card.width - slot.width) <= 1, scene.state .. ": " .. card.name .. "'s glass is the rail's width, got " .. card.width)
		local below = rail[i + 1]
		if below then
			assert(below.top >= card.top + card.height - 0.5, scene.state .. ": " .. below.name .. " starts under " .. card.name .. ", got " .. below.top .. " for " .. (card.top + card.height))
		end
	end
	for _, name in ipairs({ "party", "step 1", "path", "footer", "quests", "chat" }) do
		assert(seen[name], scene.state .. ": the rail shows " .. name)
	end
	local gap = seen.quests.top - (seen.footer.top + seen.footer.height)
	assert(math.abs(gap - 16) <= 1, scene.state .. ": the guide ends one rail gap above the quests, got " .. gap)
	assert(seen["step 1"].top >= slot.top - 0.5, scene.state .. ": the guide starts inside the story slot")
end

-- The rails keep their 28-unit margin: nothing on either rail draws past the screen's bottom margin (the readout
-- card's docked menu rows fall under the card when it is a hair short of their height).
for _, scene in ipairs({ questing, combat }) do
	local width = scene.screen.width
	for _, item in ipairs(scene.items) do
		local r = item.rect
		local shadow = item.file and item.file:find("Shadow", 1, true)
		if r and not shadow and (item.alpha or 1) > 0 and (r[1] >= width - 346 or r[1] + r[3] <= 346) then
			assert(r[2] + r[4] <= 1080 - 28 + 0.5, scene.state .. ": a " .. item.kind .. " on a rail reaches past the bottom margin: " .. table.concat(r, ", "))
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
	for _, text in ipairs({ "GENERAL", "QUESTS", "RIVERGLADES", "DAMAGE DONE" }) do
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
	assert(find(combat, "Terrifying Screech"), "and its cast shows")
	for _, text in ipairs({ "GENERAL", "QUESTS", "RIVERGLADES", "RestedXP Guides v4.11.35" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 0.75), text .. " is read mid-pull and dims only to 75% in combat, got " .. tostring(item.alpha))
	end
	-- Round 3 (Muse #3): the readout keeps a legible 65% floor in combat instead of ghosting at 30%.
	for _, text in ipairs({ "fps", "armour" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 0.65), text .. " is on the readout and rests at a legible 65% in combat, got " .. tostring(item.alpha))
	end
	for _, text in ipairs({ "Leduc", "DAMAGE DONE", "BLOODTALON MATRIARCH", "VALERIN" }) do
		local item = assert(find(combat, text), text .. " draws in combat")
		assert(near(item.alpha, 1), text .. " stays lit in combat, got " .. tostring(item.alpha))
	end
end

print("render scenes lumen ok")
