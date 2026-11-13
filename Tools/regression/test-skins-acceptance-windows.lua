-- test-skins-acceptance-windows.lua: KSTY-60 items 15, 17, 18 and 26 on the skinned windows' gallery scenes. Every window title is the heading system's cap (bible 3.2: a gilt diamond, the title in caps at the card's left padding, a rule to the right); every dropdown ends in the Options chevron and never Blizzard's arrow button art; the Legacy reward track reads above its bar with slot-edged rewards; the trainer's rank sits beside its bar; reputation fills wear the state colours; the friends list, character stats and talent count wear their roles.
local L = dofile("Tools/regression/render_scenes_lib.lua")

local scenes = {}
local function Scene(name)
	if not scenes[name] then
		local build = assert(dofile("Tools/render/scenes/" .. name .. ".lua"), name .. " returns its builder")
		scenes[name] = L.check(name, build())
	end
	return scenes[name]
end

local function File(item, part)
	return item.kind == "texture" and type(item.file) == "string" and item.file:find(part, 1, true) ~= nil
end

local function Text(scene, words)
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.text == words then
			return item
		end
	end
	error("no text " .. words)
end

local function Middle(rect)
	return rect[2] + rect[4] / 2
end

local function Inside(rect, outer)
	return rect[1] >= outer[1] - 1 and rect[2] >= outer[2] - 1 and rect[1] + rect[3] <= outer[1] + outer[3] + 1 and rect[2] + rect[4] <= outer[2] + outer[4] + 1
end

local function Window(scene, rect)
	local best
	for _, item in ipairs(scene.items) do
		if File(item, "CardShape") and item.rect[3] > 60 and item.rect[4] > 30 and Inside(rect, item.rect) then
			if not best or item.rect[3] * item.rect[4] < best[3] * best[4] then
				best = item.rect
			end
		end
	end
	return assert(best, "a card's glass holds the title")
end

-- Heading(scene, words, rule): the title is drawn in the caps face, a diamond stands just left of it on its middle,
-- it starts at the card's left padding (16) plus the diamond and its gap, and a rule runs on from it.
local function Heading(name, words, rule)
	local scene = Scene(name)
	local title = Text(scene, words)
	local where = name .. " " .. words
	assert(title.font and title.font.file:find("Caps", 1, true), where .. ": the title is in the caps face, got " .. tostring(title.font and title.font.file))
	local gem
	for _, item in ipairs(scene.items) do
		if File(item, "Diamond") then
			local right = item.rect[1] + item.rect[3]
			if right <= title.rect[1] + 1 and title.rect[1] - right < 12 and math.abs(Middle(item.rect) - Middle(title.rect)) < 3 then
				gem = item
			end
		end
	end
	assert(gem, where .. ": a gilt diamond stands before the title")
	local glass = Window(scene, title.rect)
	local indent = title.rect[1] - glass[1]
	assert(indent > 20 and indent < 40, where .. ": the title starts at the card's left padding, " .. indent .. " in")
	if rule then
		local found = false
		for _, item in ipairs(scene.items) do
			if File(item, "Rule") and item.rect[1] > title.rect[1] and math.abs(Middle(item.rect) - Middle(title.rect)) < 3 and item.rect[3] > 10 then
				found = found or item.rect[1] + item.rect[3] <= glass[1] + glass[3] + 1
			end
		end
		assert(found, where .. ": a rule runs on from the title inside the card")
	end
end


local failures = {}
local function Check(fn)
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = tostring(err)
	end
end

Check(function() Heading("gallery_skins_gamemenu", "Game Menu", true) end)
Check(function() Heading("gallery_skins_readycheck", "Ready Check", true) end)
Check(function() Heading("gallery_skins_worldmap", "Map & Quest Log", true) end)
Check(function() Heading("gallery_skins_legacy", "Legacy", true) end)
Check(function() Heading("gallery_skins_addonlist", "AddOns", true) end)
Check(function()
for _, words in ipairs({ "RESTEDXP LEVELING REPORT", "PURGE", "REMOVE", "GUIDE CONFIGURATOR", "RESTEDXP FEEDBACK FORM", "RESTEDXP: GUIDE EXPORT", "LEVEL SPLITS", "TIP" }) do
	Heading("gallery_restedxp", words, true)
end
end)
Check(function() Heading("gallery_restedxp", "ACTIVE TARGETS", false) end)
Check(function() Heading("gallery_restedxp", "ACTIVE ITEMS", false) end)

-- Dropdowns: Blizzard's arrow button (Blizzard_Menu/Mainline/MenuTemplates.xml, common-dropdown-a-button) never
-- shows; the Options chevron does, inside the dropdown's right end.
Check(function()
for _, name in ipairs({ "gallery_skins_addonlist", "gallery_skins_friends", "gallery_skins_trainer", "gallery_skins_reputation" }) do
	local scene = Scene(name)
	local chevrons = 0
	for _, item in ipairs(scene.items) do
		assert(not (item.atlas and item.atlas:find("dropdown", 1, true) and item.atlas:find("button", 1, true)), name .. ": Blizzard's dropdown arrow button is hidden, got " .. tostring(item.atlas))
		if File(item, "GlyphChevron") then
			chevrons = chevrons + 1
		end
	end
	assert(chevrons >= 1, name .. ": the dropdown ends in the Options chevron")
end
end)

-- The search field's magnifier sits inside the field's padding, clear of the instructions.
Check(function()
	local scene = Scene("gallery_skins_addonlist")
	local words = Text(scene, "Search")
	local glass
	for _, item in ipairs(scene.items) do
		if item.atlas == "common-search-magnifyingglass" then
			glass = item
		end
	end
	assert(glass and glass.rect[1] + glass.rect[3] <= words.rect[1], "the magnifier stands clear of the search instructions")
	assert(words.color[1] < 0.6, "the instructions are the Options placeholder's faint grey")
end)

-- Legacy (item 15): the reward track's bar fills with the accent, not Blizzard's white fill art; each reward has a
-- level diamond above it and its name centred under it.
Check(function()
	local scene = Scene("gallery_skins_legacy")
	local fill
	for _, item in ipairs(scene.items) do
		if File(item, "BarGlass") and item.rect[3] > 300 then
			fill = item
		end
	end
	assert(fill, "the reward track's bar draws its fill")
	assert(not (fill.vertex[1] > 0.99 and fill.vertex[2] > 0.99 and fill.vertex[3] > 0.99), "the fill is the accent, not Blizzard's white fill art")
	local gems = {}
	for _, item in ipairs(scene.items) do
		if File(item, "Diamond.png") and not File(item, "Forged") then
			gems[#gems + 1] = item
		end
	end
	assert(#gems == 4, "each reward card has its level diamond, got " .. #gems)
	local name = Text(scene, "Tabard of the Legacy")
	assert(math.abs((name.rect[1] + name.rect[3] / 2) - (gems[1].rect[1] + gems[1].rect[3] / 2)) < 1, "the reward's name is centred under its card")
end)

-- Trainer (item 26): the rank reads beside the skill bar, so no digit sits on the bar's fill edge.
Check(function()
	local scene = Scene("gallery_skins_trainer")
	local rank, label = Text(scene, "186/300"), Text(scene, "Polearms")
	local track
	for _, item in ipairs(scene.items) do
		if File(item, "RingLine3") and math.abs(Middle(item.rect) - Middle(label.rect)) < 3 then
			track = item
		end
	end
	assert(track and rank.rect[1] >= track.rect[1] + track.rect[3], "the rank stands to the right of the skill bar")
end)

-- Reputation (item 26): fills wear the bible's state colours, not Blizzard's pure faction colours.
Check(function()
	local scene = Scene("gallery_skins_reputation")
	local wanted = {}
	for _, hex in ipairs({ "62d58d", "f6d27a", "e2524f" }) do
		wanted[#wanted + 1] = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
	end
	local fills, toned = 0, 0
	for _, item in ipairs(scene.items) do
		if File(item, "BarGlass") then
			fills = fills + 1
			for _, c in ipairs(wanted) do
				if math.abs(item.vertex[1] - c[1]) < 0.01 and math.abs(item.vertex[2] - c[2]) < 0.01 and math.abs(item.vertex[3] - c[3]) < 0.01 then
					toned = toned + 1
				end
			end
		end
	end
	assert(fills > 0 and toned == fills, "every standing fill wears friend, quest or hostile, got " .. toned .. " of " .. fills)
end)

-- Friends, character, talents (item 26).
Check(function()
	local friends = Scene("gallery_skins_friends")
	local name, info = Text(friends, "Thargor"), Text(friends, "Level 40 Orc Warrior, The Barrens")
	assert(info.font.size < name.font.size, "a friend's info line is the caption under the name")
	assert(info.rect[2] - (name.rect[2] + name.rect[4]) >= 2, "with a clear gap under the name")
	for _, item in ipairs(friends.items) do
		assert(not (item.kind == "texture" and item.color and item.color[3] > 0.5 and item.color[1] < 0.2 and (item.alpha or 1) > 0.1), "no steel-blue row fill")
	end
	assert(Text(Scene("gallery_skins_character"), "Attributes").font.file:find("Caps", 1, true), "the character sheet's section headers are caps headings")
	assert(Text(Scene("gallery_skins_talents"), "3").font.file:find("PTSerif-Bold", 1, true), "the unspent count is in the number face, whose figures sit on the line")
end)

assert(#failures == 0, #failures .. " acceptance checks fail:\n" .. table.concat(failures, "\n"))
print("skins acceptance windows ok")
