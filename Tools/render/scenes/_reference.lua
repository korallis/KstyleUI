-- _reference.lua: the state of the owner's reference picture of 2026-11-09 (handoffs/reference/owner-reference-2026-11-09.png
-- in the Captain's drive): his level 11 shaman Korallis questing in Windfield Orchard on his full 3456 by 2234 screen,
-- a Shadowgale Poacher targeted and casting Shadow Bolt, Lightning Bolt 1.2 s into its 2.5 s cast, ten buffs and two
-- debuffs, the RestedXP guide on step 134 over four of seven quests, the chat lines and loot of his 20:22 session, the
-- damage meter on his own spells, three nameplates. Every value is read off the picture; the picture is a mockup, so
-- what it shows that no code draws is listed in handoffs/reference-diff/DIFF.md, not faked here.
--
--   local Reference = dofile("Tools/render/scenes/_reference.lua")
--   local scene = Reference.Build({ layout = "Tank" }) -- DPS by default; Tank and Healer also apply their presets
local Common = dofile("Tools/render/scenes/_common.lua")
local Lumen = dofile("Tools/render/scenes/_lumen.lua")

local Reference = {}

-- The owner's screen: the MacBook Pro's full panel at 3456 by 2234 pixels. Blizzard's UI scale is the one every Mac
-- scene uses (UIParent 1080 units tall); KstyleUI's root does not depend on it, only Blizzard-owned text does.
Reference.SCREEN = { width = 3456, height = 2234, uiScale = 768 / 1080 }
local selectedScreen = os.getenv("RENDER_SCREEN")
if selectedScreen and selectedScreen ~= "" then
	Reference.SCREEN = Common.DEFAULT_SCREEN
end

local SYSTEM = { 1, 1, 0 }
local LOOT = { 0, 0.67, 0 }

Reference.STATE = {
	spec = {
		name = "Korallis",
		cast = { "Lightning Bolt", 136048, 403, 2.5 },
		bar1 = {
			{ "Flame Shock", 135813 }, { "Earth Shock", 136026 }, { "Lightning Bolt", 136048 }, { "Rockbiter Weapon", 136086 },
			{ "Searing Totem", 135825 }, { "Lightning Shield", 132315 }, { "Healing Wave", 136052 },
		},
		bar2 = {
			{ "Earthbind Totem", 136102 }, { "Healing Stream Totem", 135127 }, { "Ghost Wolf", 136095 }, { "Skinning Knife", 135637 },
			{ "Purge", 136075 }, { "Strength of Earth Totem", 136023 }, { "Lesser Healing Wave", 136043 }, { "Windfury Totem", 136114 },
		},
		essential = {
			{ "Earth Shock", 136026, { 6, 4 } }, { "Flame Shock", 135813, "proc" }, { "Searing Totem", 135825 },
			{ "Stoneclaw Totem", 136097, { 30, 12 } }, { "Water Shield", 132315 }, { "Chain Lightning", 136015 },
		},
		utility = {},
		buffs = { { "Nature's Swiftness", 136076, { 10, 8 } }, { "Elemental Mastery", 136115, { 30, 14 } } },
		bars = {},
	},
	player = { level = 11, health = 203, healthMax = 237, power = 214, powerMax = 335 },
	playerCast = true,
	castLeft = 1.3,
	target = {
		name = "Shadowgale Poacher", level = 12, health = 118, healthMax = 236, power = 240, powerMax = 345, powerType = 0,
		powerToken = "MANA", reaction = 2, canAttack = true, classification = "normal", creature = "Humanoid",
		cast = { name = "Shadow Bolt", texture = 136197, start = 8800, finish = 10800, spellID = 686 },
	},
	targetAuras = { { 135813, "9s" }, { 136026, "3s" } },
	buffRow = {
		{ "Healing Stream Totem", 135127, "45s" }, { "Arcane Intellect", 135932, "2m" }, { "Strength of Earth Totem", 136023, "4m" },
		{ "Rockbiter Weapon", 136086, "6m" }, { "Mark of the Wild", 136078, "9m" }, { "Windfury Weapon", 136018, "14m" },
		{ "Power Word: Fortitude", 135987, "28m" }, { "Water Shield", 132315, "58m" }, { "Lightning Shield", 136048, "10m" },
		{ "Flametongue Weapon", 135814, "23m" },
	},
	debuffRow = { { "Poison", 136016, "7s" }, { "Shadow Word: Pain", 136207, "18s" } },
	zone = "Windfield Orchard",
	position = { 0.462, 0.618 },
	clock = { hour = 21, minute = 20, realmHour = 21, realmMinute = 20 },
	cvars = { timeMgrUseMilitaryTime = false },
	-- RENDER_XP fills the experience bar and RENDER_FACTION=1 watches Stormwind, for the ornament strips; the picture
	-- has 0 experience and no watched faction.
	game = {
		level = 11, xp = tonumber(os.getenv("RENDER_XP") or "") or 0, xpMax = 8800, rested = 440, fps = 162, latencyHome = 15, latencyWorld = 15, money = 2616,
		faction = os.getenv("RENDER_FACTION") == "1" and { factionID = 72, name = "Stormwind", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 } or nil,
	},
	quests = {
		{ title = "Unnerving Silence", level = 11, objectives = { "Find and speak with Elegael Thornpaw in the northeastern part of Shadowgale Forest." }, questID = 301, superTracked = true },
		{ title = "Crab Season", level = 9, objectives = { "Windsong Crawler Meat 0/6" }, questID = 302 },
		{ title = "Aid For The Refugees", level = 11, objectives = { "Abandoned Belongings 0/8" }, questID = 303 },
		{ title = "A Grand Adventure", level = 12, objectives = { "Listen to Ayessa 0/1" }, questID = 304 },
		{ title = "Shadowgale Scouting", level = 10, objectives = { "Scout the poacher camp 0/1" }, questID = 305 },
		{ title = "Windsong Hides", level = 10, objectives = { "Windsong Hide 0/5" }, questID = 306 },
		{ title = "Orchard Pests", level = 9, objectives = { "Orchard Pest slain 0/10" }, questID = 307 },
	},
	-- The first step line is the owner's live guide line as RestedXP's guide file writes it (an inline icon, a
	-- colour token, the npc id), so the render shows what the skin makes of RestedXP's markup.
	guide = {
		title = "1-9 Skyborne",
		steps = { { title = "Step 134", elements = { "|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Aarnor Galestrike::254082|r", "Train your class spells" } } },
	},
	chatClock = { year = 2026, month = 11, day = 9, hour = 20, min = 21, sec = 0 },
	chatTabs = { "General", "Combat Log" },
	chatLines = {
		{ "CHAT_MSG_SYSTEM", "Congratulations, you have reached |cffff4e00|Hlevelup:11|h[Level 11]|h|r!", SYSTEM },
		{ "CHAT_MSG_SYSTEM", "You have gained 17 hit points and 30 mana.", SYSTEM },
		{ "CHAT_MSG_SYSTEM", "You have gained 1 talent point.", SYSTEM },
		{ "CHAT_MSG_LOOT", "You receive loot: |cff9d9d9d|Hitem:7101::::::::11:::::|h[Bug Eye]|h|r", LOOT },
		{ "CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:1425::::::::11:::::|h[Worn Leather Vest]|h|r", LOOT },
		{ "CHAT_MSG_SYSTEM", "|cffff80ff|Htransmogappearance:156306|h[Worn Leather Vest]|h|r has been added to your appearance collection.", SYSTEM },
	},
	damage = { { "Korallis", "SHAMAN", 895 } },
	meterHover = false,
	meterSolo = true,
	meterSpells = {
		{ 403, "Lightning Bolt", 136048, 412 }, { 8050, "Flame Shock", 135813, 188 }, { 8042, "Earth Shock", 136026, 134 },
		{ 6603, "Melee", 132147, 107 }, { 3599, "Searing Totem", 135825, 54 },
	},
	plates = {
		{ unit = { name = "Shadowgale Poacher", level = 12, health = 236, maxHealth = 236, reaction = 2, canAttack = true }, x = 585, y = 440 },
		{ unit = { name = "Shadowgale Poacher", level = 12, health = 118, maxHealth = 236, reaction = 2, canAttack = true }, x = 1116, y = 476, target = true, cast = { name = "Shadow Bolt", texture = 136197, share = 0.6 } },
		{ unit = { name = "Poacher Lookout", level = 11, health = 168, maxHealth = 224, reaction = 2, canAttack = true }, x = 1276, y = 576 },
	},
	keys2 = { "Q", "E", "R", "F", "Z", "X", "C", "V", "", "", "", "" },
	slots = { [11] = 136075, [12] = 136018, [25] = 135988, [26] = 135637, [27] = 132315, [37] = 135847, [38] = 135641 },
	barStates = false,
}

-- The healer party card's glass, measured on the nine reference screens: it starts 395 scene units left of
-- centre and is 266 wide. A fixture plate whose name spills past that glass is seated to its left, one
-- name clear of it. A plate that sits wholly on the glass stays, so the owner's 3456 by 2234 picture
-- keeps the occlusion acceptance pass 5 recorded.
local PARTY_FROM_CENTRE, PARTY_GLASS_W = 395, 266
local PLATE_NAME_HALF, PLATE_GAP = 90, 16

-- LIVE is the story rail of the owner's first live session (2026-11-12, 5120x1440): RestedXP's step 57 with three
-- active steps of wrapped lines, and nine tracked quests, the first with four objectives. Reference.Build({ live =
-- true }), or RENDER_STORY=live, draws it in place of the picture's short guide and seven quests.
Reference.LIVE = {
	guide = {
		title = "9-12 Skyborne",
		steps = {
			{ title = "Step 57", elements = { "Kill |cRXP_ENEMY_Bandit Highwayman|r. Loot them for the |cff00bcd4[Blood-Stained Bandit Masks]|r.", "|cfffcdc00Watch for stealthed enemies in the apple orchard.|r", "0/7 Blood-Stained Bandit Mask" } },
			{ title = "Step 58", elements = { "Make your way up the mountain", "|cfffcdc00If you see a Tornado, use it for faster travel|r" } },
			{ title = "Step 59", elements = { "Click on the |cRXP_PICK_Construct Parts|r", "Obtain Air Construct Core from the Bandit Camp 0/1" } },
		},
	},
	quests = {
		{ title = "The Broken Construct", level = 9, objectives = { "Listen to what Riaani Nightwind has to say 1/1", "Obtain Crystallized Lightning from the Sparkling Cave 1/1", "Obtain Enchanted Gyrozephyr from Windsong Lake 0/1", "Obtain Air Construct Core from the Bandit Camp 0/1" }, questID = 311, superTracked = true },
		{ title = "Bandit Highwaymen", level = 10, objectives = { "Blood-Stained Bandit Mask 0/7" }, questID = 312 },
		{ title = "Crab Season", level = 9, objectives = { "Windsong Crawler Meat 0/6" }, questID = 302 },
		{ title = "Aid For The Refugees", level = 11, objectives = { "Abandoned Belongings 0/8" }, questID = 303 },
		{ title = "A Grand Adventure", level = 12, objectives = { "Listen to Ayessa 0/1" }, questID = 304 },
		{ title = "Shadowgale Scouting", level = 10, objectives = { "Scout the poacher camp 0/1" }, questID = 305 },
		{ title = "Windsong Hides", level = 10, objectives = { "Windsong Hide 0/5" }, questID = 306 },
		{ title = "Orchard Pests", level = 9, objectives = { "Orchard Pest slain 0/10" }, questID = 307 },
		{ title = "Unnerving Silence", level = 11, objectives = { "Find and speak with Elegael Thornpaw in the northeastern part of Shadowgale Forest." }, questID = 301 },
	},
}

local function sceneWidth()
	local screen = Reference.SCREEN
	return screen.width * 1080 / screen.height
end

function Reference.SeatPlates(plates, width)
	local glassLeft = width / 2 - PARTY_FROM_CENTRE
	local glassRight = glassLeft + PARTY_GLASS_W
	local seated = {}
	for i, plate in ipairs(plates) do
		local copy = {}
		for key, value in pairs(plate) do
			copy[key] = value
		end
		local left, right = plate.x - PLATE_NAME_HALF, plate.x + PLATE_NAME_HALF
		local overlaps = right > glassLeft and left < glassRight
		local inside = left >= glassLeft and right <= glassRight
		if overlaps and not inside then
			local x = glassLeft - PLATE_GAP - PLATE_NAME_HALF
			for _, other in ipairs(seated) do
				if x - PLATE_NAME_HALF < other.x + PLATE_NAME_HALF + PLATE_GAP then
					x = glassRight + PLATE_GAP + PLATE_NAME_HALF
				end
			end
			copy.x = x
		end
		seated[i] = copy
	end
	return seated
end

-- Build(opts) -> the merged scene on the owner's screen after Setup.Apply; opts.layout is DPS, Tank or Healer,
-- opts.modules, when given, names the only modules drawn, and opts.live draws the live session's story rail (LIVE).
Reference.GROUP_DAMAGE = {
	party = {
		{ "Korallis", "SHAMAN", 1284 }, { "Leduc", "PALADIN", 1102 }, { "Brannoc", "ROGUE", 968 }, { "Ilyra", "MAGE", 655 },
		{ "Trolly", "PRIEST", 109 },
	},
	raid = {},
}
do
	local names = {
		{ "Vexxa", "WARLOCK" }, { "Thargor", "WARRIOR" }, { "Ilyra", "MAGE" }, { "Brannoc", "ROGUE" }, { "Sylaen", "HUNTER" },
		{ "Morwen", "DRUID" }, { "Kael", "MAGE" }, { "Dorn", "WARRIOR" }, { "Ashka", "SHAMAN" }, { "Feyl", "ROGUE" },
		{ "Orin", "PALADIN" }, { "Raskal", "HUNTER" }, { "Nym", "WARLOCK" }, { "Korallis", "SHAMAN" }, { "Leduc", "PALADIN" },
		{ "Brisa", "DRUID" }, { "Holt", "WARRIOR" }, { "Quill", "PRIEST" }, { "Trolly", "PRIEST" }, { "Sable", "PRIEST" },
	}
	for i, who in ipairs(names) do
		Reference.GROUP_DAMAGE.raid[i] = { who[1], who[2], 48200 - i * 2150 }
	end
end

function Reference.Build(opts)
	opts = opts or {}
	local layout = opts.layout or "DPS"
	assert(layout == "DPS" or layout == "Tank" or layout == "Healer", "reference layout must be DPS, Tank or Healer")
	local previous = rawget(_G, "RENDER_SCREEN")
	rawset(_G, "RENDER_SCREEN", Reference.SCREEN)
	local ok, scene = pcall(function()
		local state = {}
		for k, v in pairs(Reference.STATE) do
			state[k] = v
		end
		state.meterSecret = opts.meterSecret == true
		state.plates = {}
		for i, plate in ipairs(Reference.STATE.plates) do
			state.plates[i] = plate
		end
		if layout == "Healer" then
			state.plates = Reference.SeatPlates(state.plates, sceneWidth())
		end
		if opts.live or os.getenv("RENDER_STORY") == "live" then
			state.guide, state.quests = Reference.LIVE.guide, Reference.LIVE.quests
		end
		local modules = { "nameplates", "chat", "minimap", "auras", "databars", "tracker", "meters", "unitframes", "actionbars", "cooldowns", "lootfeed" }
		if layout ~= "DPS" then
			modules[#modules + 1] = "groupframes"
			state.party = Lumen.PARTY.questing
			state.role = layout == "Tank" and "TANK" or "HEALER"
		end
		if layout == "Tank" then
			state.meterSolo = false
			state.damage = { Reference.STATE.damage[1], { "Leduc", "PALADIN", 442 }, { "Trolly", "PRIEST", 201 } }
		end
		-- opts.meterGroup (RENDER_METER_GROUP): the damage card in a party of five or a raid of twenty, the player
		-- fourteenth in the raid, so the card keeps their row pinned under the top four.
		if opts.meterGroup == "party" or opts.meterGroup == "raid" then
			state.meterSolo = false
			state.meterSpells = nil
			state.damage = Reference.GROUP_DAMAGE[opts.meterGroup]
			state.meterMe = opts.meterGroup == "raid" and 14 or 1
		end
		return Lumen.Build("questing", {
			class = "SHAMAN",
			layout = layout,
			applyPreset = true,
			state = state,
			elements = true,
			modules = opts.modules or modules,
		})
	end)
	rawset(_G, "RENDER_SCREEN", previous)
	if not ok then
		error(scene, 0)
	end
	scene.log[#scene.log + 1] = "reference: the owner's picture of 2026-11-09 on his " .. Reference.SCREEN.width .. " by " .. Reference.SCREEN.height .. " screen"
		.. ", the " .. layout .. " preset through Setup.Apply"
	return scene
end

Reference.Common = Common

return Reference
