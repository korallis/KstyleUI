-- Layouts.lua: the element keys modules register with Layout, and the Lumen DPS, Tank and Healer layouts the first-run setup writes: positions, footprints, the bars and meters each switches on, and the story slot on the right rail under the map, which the RestedXP guide card and the quest card share as two elements of their own, and each layout class's own places.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

local BUTTON, SMALL_BUTTON, PITCH = 38, 30, 3
local CENTRE_BUTTON, CENTRE_GAP, COLUMN = 36.7, 4.6, 491
local RAIL_BUTTON, RAIL_PITCH = CENTRE_BUTTON, CENTRE_GAP
local MOCK_PX = 1 / ns.Scale.DEFAULT_USER_SCALE
local TRAY_BUTTON, TRAY_GAP, TRAY_PAD, TRAY_BOTTOM = 38 * MOCK_PX, 3 * MOCK_PX, 9 * MOCK_PX, 40 * MOCK_PX
local TRAY_WIDTH = 12 * TRAY_BUTTON + 11 * TRAY_GAP + 2 * TRAY_PAD
local TRAY_BAR1_Y = TRAY_BOTTOM + TRAY_PAD
local TRAY_BAR2_Y = TRAY_BAR1_Y + TRAY_BUTTON + TRAY_GAP
local TRAY_TOP = TRAY_BAR2_Y + TRAY_BUTTON + TRAY_PAD
local TRAY_STRIP_GAP = 9 * MOCK_PX
local XP_H = 5
local LIFT = math.ceil(TRAY_TOP - 132)
local PLAYER_CAST_Y = 385.5 + LIFT
local COMBAT_TEXT_H = 180
local GRIDS = {
	["actionbars.bar1"] = { buttons = 12, rows = 1, size = TRAY_BUTTON, spacing = TRAY_GAP },
	["actionbars.bar2"] = { buttons = 12, rows = 1, size = TRAY_BUTTON, spacing = TRAY_GAP },
	["actionbars.bar3"] = { buttons = 12, rows = 1, size = BUTTON },
	["actionbars.bar4"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH },
	["actionbars.bar5"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH },
	["actionbars.bar6"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH },
	["actionbars.pet"] = { buttons = 10, rows = 3, size = SMALL_BUTTON },
	["actionbars.stance"] = { buttons = 10, rows = 3, size = SMALL_BUTTON, growth = "RIGHTUP" },
}

local function GridSize(key)
	local grid = GRIDS[key]
	local columns = math.ceil(grid.buttons / grid.rows)
	local gap = grid.spacing or PITCH
	return columns * grid.size + (columns - 1) * gap, grid.rows * grid.size + (grid.rows - 1) * gap
end

local function Row(icons)
	return icons * BUTTON + (icons - 1) * PITCH
end
local ESSENTIAL, UTILITY, TRACKED = Row(6), Row(4), Row(6)

local EDGE = ns.Tokens.Size("screenMargin")
local RAIL_EDGE = EDGE + 1.4
local MAP, MAP_HEADING, MAP_CAPTION = 188, 22, 14
local AURA_ICON, AURA_GAP, AURA_COLUMNS, AURA_TIMER, AURA_ROW_GAP, AURA_MAP_GAP = 27.5, 3.5, 10, 14, 8, 10.9
local AURA_W, AURA_H = AURA_COLUMNS * AURA_ICON + (AURA_COLUMNS - 1) * AURA_GAP, AURA_ICON + AURA_TIMER
local STORY_W = 278
local DAMAGE_W, DAMAGE_H = 269, 158
local THREAT_W, THREAT_H = 200, 112
local READOUT_H, READOUT_GAP, RAIL_BARS_GAP = 12, 6, 10

local FEED_LINES, FEED_PAD = 4, ns.Tokens.Size("radius") + ns.Tokens.Size("gapSmall")
local FEED_ROW, FEED_GAP = ns.Tokens.Size("lootTile"), ns.Tokens.Size("gapSmall")

local ELEMENTS = {
	{ key = "unitframes.player", module = "UnitFrames", label = L["Player frame"], short = L["Player"], width = COLUMN, height = 77.5, reserve = { 586.5, 77.5, -47.75 } },
	{ key = "unitframes.target", module = "UnitFrames", label = L["Target frame"], short = L["Target"], width = COLUMN, height = 102.5, reserve = { 737.4, 102.5, 123.2 } },
	{ key = "unitframes.targettarget", module = "UnitFrames", label = L["Target of target"], width = 120, height = 22 },
	{ key = "unitframes.focus", module = "UnitFrames", label = L["Focus frame"], short = L["Focus"], width = 200, height = 90, reserve = { 200, 112 } },
	{ key = "unitframes.focustarget", module = "UnitFrames", label = L["Focus target"], width = 120, height = 22 },
	{ key = "unitframes.pet", module = "UnitFrames", label = L["Pet frame"], width = 120, height = 22 },
	{ key = "unitframes.boss", module = "UnitFrames", label = L["Boss frames"], short = L["Boss"], width = 222, height = 334, reserve = { 318, 334 } },
	{ key = "unitframes.castbar.player", module = "UnitFrames", label = L["Player cast bar"], width = 347, height = 30 },
	{ key = "unitframes.castbar.target", module = "UnitFrames", label = L["Target cast bar"], width = 220, height = 32 },
	{ key = "unitframes.resource", module = "UnitFrames", label = L["Class resource"], width = 120, height = 14 },
	{ key = "groupframes.party", module = "GroupFrames", label = L["Party frames"], short = L["Party"], width = 318, height = 324 },
	{ key = "groupframes.raid", module = "GroupFrames", label = L["Raid frames"], short = L["Raid"], width = 543, height = 401 },
	{ key = "actionbars.bar1", module = "ActionBars", label = L["Action bar 1"], short = L["Bar 1"], grid = true },
	{ key = "actionbars.bar2", module = "ActionBars", label = L["Action bar 2"], short = L["Bar 2"], grid = true },
	{ key = "actionbars.bar3", module = "ActionBars", label = L["Action bar 3"], grid = true },
	{ key = "actionbars.bar4", module = "ActionBars", label = L["Action bar 4"], grid = true },
	{ key = "actionbars.bar5", module = "ActionBars", label = L["Action bar 5"], grid = true },
	{ key = "actionbars.bar6", module = "ActionBars", label = L["Action bar 6"], grid = true },
	{ key = "actionbars.pet", module = "ActionBars", label = L["Pet bar"], grid = true },
	{ key = "actionbars.stance", module = "ActionBars", label = L["Stance bar"], grid = true },
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], short = L["Cooldowns"], width = 6 * CENTRE_BUTTON + 5 * CENTRE_GAP, height = CENTRE_BUTTON },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = UTILITY, height = BUTTON },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = 182.6, height = 41.6 },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = TRACKED, height = 43 },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], short = L["Auras"], width = AURA_W, height = AURA_H },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = AURA_W, height = AURA_H },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], short = L["Map"], width = MAP, height = MAP, reserve = { MAP, MAP + MAP_CAPTION } },
	{ key = "chat.main", module = "Chat", label = L["Chat"], short = L["Chat"], width = 393, height = 186 },
	{ key = "qol.lootfeed", module = "QoL", label = L["Loot feed"], short = L["Loot"], width = ns.Tokens.Size("railWidth"), height = FEED_LINES * FEED_ROW + (FEED_LINES - 1) * FEED_GAP + 2 * FEED_PAD },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = COLUMN, height = XP_H },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 162, height = 5 },
	{ key = "databars.honor", module = "DataBars", label = L["Honour bar"], width = 162, height = 5 },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], short = L["Readout"], width = STORY_W, height = READOUT_H },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 318, height = 44 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 212, height = 32 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], short = L["Damage"], width = DAMAGE_W, height = DAMAGE_H },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], short = L["Threat"], width = THREAT_W, height = THREAT_H },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], short = L["Combat text"], width = 160, height = COMBAT_TEXT_H - LIFT },
	{ key = "tooltips.anchor", module = "Tooltips", label = L["Tooltip anchor"], width = 180, height = 24 },
}

for _, element in ipairs(ELEMENTS) do
	if element.grid then
		element.width, element.height = GridSize(element.key)
		element.grid = nil
	end
end

local HEIGHT = 1080 / ns.Scale.DEFAULT_USER_SCALE
local MARGIN, RAIL, GAP, TIGHT = ns.Tokens.Size("screenMargin"), 318, 16, 4
local NEAR = ns.Tokens.Size("gapLarge")
local ENDS = TRAY_WIDTH / 2 + NEAR + GridSize("actionbars.pet") / 2
local STRIP_ENDS = (12 * BUTTON + 11 * PITCH) / 2 + NEAR + (5 * SMALL_BUTTON + 4 * PITCH) / 2
local BAR = BUTTON + PITCH
local BAR1_Y = 68 + LIFT
local SPARE_TOP = BAR1_Y + 3 * BAR - PITCH
local VITALS_Y = SPARE_TOP + 12
local VITALS_TOP = VITALS_Y + 80
local RESOURCE_Y = VITALS_TOP + 6
local COOLDOWN_Y = RESOURCE_Y + 14 + 8
local TRACKED_Y = COOLDOWN_Y + BUTTON + 8
local HANDS_TOP = TRACKED_Y + 43
local CLUSTER_TOP = HANDS_TOP + 7 + 136
local UTILITY_X = ESSENTIAL / 2 + GAP + UTILITY / 2
local SIDE = 490 / 2 + NEAR
local FOCUS_X = -(SIDE + 200 / 2)
local TOT_X = SIDE + 120 / 2
local SIGIL_CLEAR = GAP
local STACK = CLUSTER_TOP + SIGIL_CLEAR
local CAST_HALF = 272 / 2
local HEALER_X, HEALER_Y = -(CAST_HALF + GAP + RAIL / 2), CLUSTER_TOP + GAP
local TEXT_TOP = CLUSTER_TOP - LIFT + GAP + COMBAT_TEXT_H
local BOSS_X = -(EDGE + 2 * STORY_W + 2 * GAP)
local function ElementSize(key)
	for _, element in ipairs(ELEMENTS) do
		if element.key == key then
			return element.width, element.height
		end
	end
end
local _, CHAT_H = ElementSize("chat.main")
local AURAS_X = EDGE + MAP + AURA_MAP_GAP
local DEBUFFS_Y = RAIL_EDGE + AURA_H + AURA_ROW_GAP
local STORY_TOP = math.max(EDGE + MAP_HEADING + MAP + MAP_CAPTION, DEBUFFS_Y + AURA_H) + GAP - 1
local READOUT_Y = EDGE + DAMAGE_H + READOUT_GAP
local RAIL_BARS_Y = READOUT_Y + READOUT_H + RAIL_BARS_GAP
local RAIL_COLUMN = RAIL_BUTTON + RAIL_PITCH
local _, RAIL_BARS_H = GridSize("actionbars.bar4")
local STORY_BOTTOM = RAIL_BARS_Y + RAIL_BARS_H + NEAR
local QUESTS_BOTTOM, STORY_FLOOR = TEXT_TOP + GAP, 72
local STORY_KEYS = { guide = "skins.guide", quests = "skins.quests" }
local SPARE_X = RAIL_EDGE + 3 * RAIL_COLUMN - RAIL_PITCH + GAP
local _, MICRO_H = ElementSize("databars.micro")
local _, BAGS_H = ElementSize("databars.bags")
local TIP_Y = RAIL_BARS_Y + MICRO_H + BAGS_H + GAP

local DPS = {
	["groupframes.party"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN },
	["qol.lootfeed"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN + CHAT_H + GAP },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -(EDGE - 1), y = -(EDGE - 1 + MAP_HEADING) },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -RAIL_EDGE },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -DEBUFFS_Y },
	["meters.damage"] = { anchor = "BOTTOMRIGHT", x = -EDGE, y = EDGE },
	["meters.threat"] = { anchor = "BOTTOM", x = SIDE + THREAT_W / 2, y = CLUSTER_TOP - 22 - TIGHT - THREAT_H },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -EDGE, y = READOUT_Y },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = RAIL_BARS_Y },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = RAIL_BARS_Y + MICRO_H },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = TRAY_BOTTOM - TRAY_STRIP_GAP - XP_H },
	["databars.rep"] = { anchor = "BOTTOM", x = -STRIP_ENDS, y = TRAY_BOTTOM - TRAY_STRIP_GAP - 15 },
	["databars.honor"] = { anchor = "BOTTOM", x = STRIP_ENDS, y = TRAY_BOTTOM - TRAY_STRIP_GAP - 15 },
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = TRAY_BAR1_Y },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = TRAY_BAR2_Y },
	["actionbars.bar3"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = math.max(MARGIN + CHAT_H + select(2, ElementSize("qol.lootfeed")) + 2 * GAP, PLAYER_CAST_Y + select(2, ElementSize("unitframes.castbar.player")) + GAP) },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -ENDS, y = TRAY_BOTTOM },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ENDS, y = TRAY_BOTTOM },
	["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 138 + LIFT },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -317, y = VITALS_TOP - 22 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = 421 + LIFT },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 335.3 + LIFT },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = UTILITY_X, y = 335.3 + LIFT },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = -442.8, y = 155.9 + LIFT },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -480, y = 340 + LIFT },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 376.5 + LIFT },
	["unitframes.target"] = { anchor = "BOTTOM", x = 0, y = 217.5 + LIFT },
	["unitframes.focus"] = { anchor = "BOTTOM", x = FOCUS_X, y = CLUSTER_TOP - 112 },
	["unitframes.focustarget"] = { anchor = "BOTTOM", x = FOCUS_X - (200 - 120) / 2, y = CLUSTER_TOP - 112 - TIGHT - 22 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = TOT_X, y = CLUSTER_TOP - 22 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = PLAYER_CAST_Y },
	["unitframes.castbar.target"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 + 30 },
	["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = BOSS_X, y = TEXT_TOP + GAP },
	["combattext.player"] = { anchor = "BOTTOM", x = 376, y = CLUSTER_TOP + GAP },
	["actionbars.bar4"] = { anchor = "BOTTOMRIGHT", x = -RAIL_EDGE, y = RAIL_BARS_Y },
	["actionbars.bar5"] = { anchor = "BOTTOMRIGHT", x = -(RAIL_EDGE + RAIL_COLUMN), y = RAIL_BARS_Y },
	["actionbars.bar6"] = { anchor = "BOTTOMRIGHT", x = -(RAIL_EDGE + 2 * RAIL_COLUMN), y = RAIL_BARS_Y },
	["tooltips.anchor"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = TIP_Y },
}

local CHANGES = {
	DPS = {},
	Tank = {},
	Healer = {},
}

local SIZES = {
	DPS = {
		["meters.damage"] = { DAMAGE_W, DAMAGE_H },
		["meters.threat"] = { THREAT_W, THREAT_H },
	},
	Tank = {
		["meters.damage"] = { DAMAGE_W, DAMAGE_H },
		["meters.threat"] = { THREAT_W, THREAT_H },
	},
	Healer = {
		["groupframes.party"] = { RAIL, 354 },
		["groupframes.raid"] = { 623, 401 },
		["meters.damage"] = { DAMAGE_W, DAMAGE_H },
		["meters.threat"] = { THREAT_W, THREAT_H },
		["chat.main"] = { RAIL, 186 },
	},
}
local APPLIED = { ["meters.damage"] = true, ["meters.threat"] = true, ["chat.main"] = true }

local DOCKS = {
	["databars.micro"] = "databars.strip",
	["databars.bags"] = "databars.strip",
}

local SWITCHES = {
	{ key = "actionbars.bar1", module = "ActionBars", setting = "bar1.enabled" },
	{ key = "actionbars.bar2", module = "ActionBars", setting = "bar2.enabled" },
	{ key = "actionbars.bar3", module = "ActionBars", setting = "bar3.enabled" },
	{ key = "actionbars.bar4", module = "ActionBars", setting = "bar4.enabled" },
	{ key = "actionbars.bar5", module = "ActionBars", setting = "bar5.enabled" },
	{ key = "actionbars.bar6", module = "ActionBars", setting = "bar6.enabled" },
	{ key = "actionbars.pet", module = "ActionBars", setting = "pet.enabled" },
	{ key = "actionbars.stance", module = "ActionBars", setting = "stance.enabled" },
	{ key = "meters.threat", module = "Meters", setting = "threat.shown" },
}

local BARS_OFF = {
	"actionbars.bar3", "actionbars.bar6",
	"unitframes.castbar.target",
}
local OFF = {
	DPS = { "meters.threat" },
	Tank = {},
	Healer = { "meters.threat" },
}

local SHARED_SETTINGS = {
	{ module = "ActionBars", key = "bar1.showEmpty", value = true },
	{ module = "ActionBars", key = "bar2.showEmpty", value = true },
	{ module = "ActionBars", key = "bar3.showEmpty", value = false },
	{ module = "ActionBars", key = "bar4.showEmpty", value = false },
	{ module = "ActionBars", key = "bar5.showEmpty", value = false },
	{ module = "ActionBars", key = "bar6.showEmpty", value = false },
	{ module = "DataBars", key = "strip.menus", value = false },
	{ module = "GroupFrames", key = "raid.groupsPerRow", value = 4 },
}
local GRID_ORDER = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "pet", "stance" }
for i = #GRID_ORDER, 1, -1 do
	local bar = GRID_ORDER[i]
	local grid = GRIDS["actionbars." .. bar]
	if grid.growth then
		table.insert(SHARED_SETTINGS, 1, { module = "ActionBars", key = bar .. ".growth", value = grid.growth })
	end
	table.insert(SHARED_SETTINGS, 1, { module = "ActionBars", key = bar .. ".rows", value = grid.rows })
end

local BOSS_LEFT = {
	{ module = "UnitFrames", key = "boss.auraPosition", value = "LEFT" },
	{ module = "UnitFrames", key = "boss.auraGrowth", value = "LEFT_DOWN" },
	{ module = "UnitFrames", key = "boss.growth", value = "UP" },
}
local EXTRA = {
	DPS = BOSS_LEFT,
	Tank = BOSS_LEFT,
	Healer = {
		{ module = "GroupFrames", key = "party.auraDispelCount", value = 2 },
		{ module = "GroupFrames", key = "raid.auraDispelCount", value = 2 },
		{ module = "UnitFrames", key = "boss.auraPosition", value = "LEFT" },
		{ module = "UnitFrames", key = "boss.auraGrowth", value = "LEFT_DOWN" },
		{ module = "UnitFrames", key = "boss.growth", value = "UP" },
	},
}
local ROWS = {
	DPS = { party = 39, raid = 36 },
	Tank = { party = 39, raid = 36 },
	Healer = { party = 43, raid = 36 },
}


local NAMES = { "DPS", "Tank", "Healer" }
local LABELS = { DPS = L["DPS"], Tank = L["Tank"], Healer = L["Healer"] }
local NOTES = {
	DPS = L["Lumen Rails: party and chat on the left rail; the map, buffs, quests and damage meter on the right; your target, its target and your focus sit right over your hands."],
	Tank = L["The DPS layout with the threat meter in the combat cluster, under the target of target, where you read who holds aggro without looking away."],
	Healer = L["The DPS layout with taller party rows and raid rows wide enough for three of your heals, dispellable debuffs first."],
}

local OFFSETS = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local byKey = {}
for _, element in ipairs(ELEMENTS) do
	byKey[element.key] = element
end

local function copy(position)
	return { anchor = position.anchor, x = position.x, y = position.y }
end

local layouts, shown, settings, slots = {}, {}, {}, {}
for _, name in ipairs(NAMES) do
	local layout = {}
	for key, position in pairs(DPS) do
		layout[key] = copy(CHANGES[name][key] or position)
	end
	layouts[name] = layout
	local off = {}
	for _, key in ipairs(BARS_OFF) do
		off[key] = true
	end
	for _, key in ipairs(OFF[name]) do
		off[key] = true
	end
	shown[name] = off
	local list = {}
	for _, switch in ipairs(SWITCHES) do
		list[#list + 1] = { module = switch.module, key = switch.setting, value = not off[switch.key] }
	end
	for _, entry in ipairs(SHARED_SETTINGS) do
		list[#list + 1] = { module = entry.module, key = entry.key, value = entry.value }
	end
	list[#list + 1] = { module = "GroupFrames", key = "party.height", value = ROWS[name].party }
	list[#list + 1] = { module = "GroupFrames", key = "raid.height", value = ROWS[name].raid }
	for _, entry in ipairs(EXTRA[name]) do
		list[#list + 1] = { module = entry.module, key = entry.key, value = entry.value }
	end
	settings[name] = list
	slots[name] = {
		key = "story",
		anchor = "TOPRIGHT", x = -EDGE, y = -STORY_TOP,
		width = STORY_W, height = HEIGHT - STORY_TOP - STORY_BOTTOM,
		label = L["Story rail"],
		hint = L["Apply places the quest tracker here through Edit Mode; Window skins put the RestedXP guide above it."],
	}
end

local ART = {
	hole = { 641, 320, 2023, 460 }, arm = { 556, 185, 736, 545 }, crest = { 1152, 146, 1512, 326 },
	rail = { 262, 326 }, railBottom = { 452, 516 }, ring = { 332, 334, 608 },
	fit = 1359, bottom = 668, floor = 21, bar2 = { 243.5, 79.5, 349.8 }, cast = 87, xp = 519.6,
	level = { 174.6, 101.1, 34.4 },
}
local ART_X, ART_Y = (ART.hole[1] + ART.hole[3]) / 2, (ART.hole[2] + ART.hole[4]) / 2
local ORBS_PARTY_Y, ORBS_TARGET_Y, ORBS_AURA_ICONS = 465, 40, 5
local ORBS_BAR1_W, ORBS_BAR1_H = GridSize("actionbars.bar1")
local ORBS_SOURCE = ORBS_BAR1_W / ART.fit
local ORBS_CENTRE = (ART.bottom - ART_Y + ART.floor) * ORBS_SOURCE
local ORBS_RING = ART.ring[3] * ORBS_SOURCE
local ORBS_X = (ART_X - ART.ring[1]) * ORBS_SOURCE
local ORBS_REACH = ORBS_X - ORBS_BAR1_W / 2
local ORBS_LIFT = (ART_Y - ART.ring[2]) * ORBS_SOURCE
local ORBS_OUTER = ORBS_X + ORBS_RING / 2
local ORBS_TOP = ORBS_CENTRE + ORBS_LIFT + ORBS_RING / 2
local ORBS_BAR2_SCALE = ART.bar2[2] * ORBS_SOURCE / GRIDS["actionbars.bar2"].size
local ORBS_SPLIT = ART.bar2[3] * ORBS_SOURCE / ORBS_BAR2_SCALE
local ORBS_BAR2_Y = ORBS_CENTRE + (ART_Y - ART.bar2[1]) * ORBS_SOURCE
local ORBS_CAST_Y = ORBS_CENTRE + (ART_Y - ART.cast) * ORBS_SOURCE
local ORBS_XP_Y = ORBS_CENTRE - (ART.xp - ART_Y) * ORBS_SOURCE - select(2, ElementSize("databars.xp"))
local ORBS_ESSENTIAL_Y = ORBS_CAST_Y + select(2, ElementSize("unitframes.castbar.player")) + GAP
local ORBS_UTILITY_Y = ORBS_ESSENTIAL_Y + CENTRE_BUTTON + 8
local ORBS_RESOURCE_Y = ORBS_UTILITY_Y + BUTTON + 6
local ORBS_SWING_Y = ORBS_RESOURCE_Y + 14 + 8
local ORBS_AURA_Y = ORBS_TOP + NEAR
local ORBS_AURA_SHIFT = (ORBS_AURA_ICONS * AURA_ICON + (ORBS_AURA_ICONS - 1) * AURA_GAP) / 2 - AURA_W / 2
local ORBS_TRACKED_Y = ORBS_AURA_Y + AURA_H + 8
local ORBS_PET_W, ORBS_PET_H = GridSize("actionbars.pet")
local ORBS_STANCE_W = GridSize("actionbars.stance")
local ORBS_REP_W = ElementSize("databars.rep")
local ORBS_PET_FRAME_W = ElementSize("unitframes.pet")
local ORBS_GLOW = 30
local ORBS_TARGET_W, ORBS_TARGET_H = 520 * MOCK_PX, 120
local ORBS_TOT_W = ElementSize("unitframes.targettarget")

local ORBS = {
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = ORBS_CENTRE - ORBS_BAR1_H / 2 },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = ORBS_XP_Y },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = ORBS_BAR2_Y, scale = ORBS_BAR2_SCALE },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = ORBS_CAST_Y },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = ORBS_ESSENTIAL_Y },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = 0, y = ORBS_UTILITY_Y },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = ORBS_RESOURCE_Y },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = ORBS_SWING_Y },
	["auras.buffs"] = { anchor = "BOTTOM", x = ORBS_AURA_SHIFT - ORBS_X, y = ORBS_AURA_Y },
	["auras.debuffs"] = { anchor = "BOTTOM", x = ORBS_AURA_SHIFT + ORBS_X, y = ORBS_AURA_Y },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = -ORBS_X, y = ORBS_TRACKED_Y },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = ORBS_X, y = ORBS_TRACKED_Y },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -(ORBS_OUTER + NEAR + ORBS_PET_W / 2), y = BAR1_Y },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ORBS_OUTER + NEAR + ORBS_STANCE_W / 2, y = BAR1_Y },
	["databars.rep"] = { anchor = "BOTTOM", x = -(ORBS_OUTER + NEAR + ORBS_REP_W / 2), y = 52 },
	["databars.honor"] = { anchor = "BOTTOM", x = ORBS_OUTER + NEAR + ORBS_REP_W / 2, y = 52 },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -(ORBS_OUTER + NEAR + ORBS_GLOW + ORBS_PET_FRAME_W / 2), y = BAR1_Y + ORBS_PET_H + GAP },
	["unitframes.target"] = { anchor = "TOP", x = 0, y = -ORBS_TARGET_Y, width = ORBS_TARGET_W, height = ORBS_TARGET_H },
	["unitframes.castbar.target"] = { anchor = "TOP", x = 0, y = -(ORBS_TARGET_Y + ORBS_TARGET_H + GAP) },
	["unitframes.targettarget"] = { anchor = "TOP", x = ORBS_TARGET_W / 2 + NEAR + ORBS_TOT_W / 2, y = -ORBS_TARGET_Y },
	["groupframes.party"] = { anchor = "TOPLEFT", x = MARGIN, y = -ORBS_PARTY_Y },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = MARGIN, y = -ORBS_PARTY_Y },
}
local REPLACED = { orbs = { ["unitframes.player"] = true } }
local ORBS_KEEP = {
	Healer = { ["groupframes.party"] = true, ["groupframes.raid"] = true },
}
local STYLES = { orbs = {} }
for _, name in ipairs({ "DPS", "Tank", "Healer" }) do
	local style = {}
	for key, position in pairs(ORBS) do
		if not (ORBS_KEEP[name] and ORBS_KEEP[name][key]) then
			style[key] = position
		end
	end
	STYLES.orbs[name] = style
end

Layouts.ELEMENTS = ELEMENTS
Layouts.FEED_LINES = FEED_LINES
Layouts.FEED_PAD = FEED_PAD
Layouts.SIGIL_CLEAR = SIGIL_CLEAR
Layouts.BUTTON = BUTTON
Layouts.TRAY_TOP = TRAY_TOP
Layouts.TRAY_BOTTOM = TRAY_BOTTOM
Layouts.TRAY_WIDTH = TRAY_WIDTH
Layouts.TRAY_PAD = TRAY_PAD
Layouts.TRAY_GAP = TRAY_GAP
Layouts.TRAY_LIFT = LIFT
Layouts.HEIGHT = HEIGHT
Layouts.STORY_KEYS = STORY_KEYS
Layouts.STORY_FLOOR = STORY_FLOOR

function Layouts.Names()
	local out = {}
	for i, name in ipairs(NAMES) do
		out[i] = name
	end
	return out
end

function Layouts.Label(name)
	return LABELS[name]
end

function Layouts.Note(name)
	return NOTES[name]
end

function Layouts.Element(key)
	return byKey[key]
end

function Layouts.Grid(key)
	local grid = GRIDS[key]
	if not grid then
		return nil
	end
	return { buttons = grid.buttons, rows = grid.rows, growth = grid.growth, size = grid.size, spacing = grid.spacing }
end

local function Lift(rootHeight)
	if type(rootHeight) == "number" and rootHeight > 0 then
		return HEIGHT - rootHeight
	end
	return 0
end

function Layouts.Get(name)
	local layout = layouts[name]
	if not layout then
		return nil
	end
	local out = {}
	for key, position in pairs(layout) do
		out[key] = { anchor = position.anchor, x = position.x, y = position.y }
	end
	return out
end

function Layouts.Footprint(name, key)
	local element = byKey[key]
	if not element or not layouts[name] then
		return nil
	end
	local size = SIZES[name][key] or element.reserve
	if size then
		return size[1], size[2], size[3]
	end
	return element.width, element.height
end

function Layouts.Sizes(name)
	if not layouts[name] then
		return nil
	end
	local out = {}
	for key, size in pairs(SIZES[name]) do
		if APPLIED[key] then
			out[key] = { width = size[1], height = size[2] }
		end
	end
	return out
end

function Layouts.Dock(key)
	return DOCKS[key]
end

function Layouts.Reserves()
	local out = {}
	for _, element in ipairs(ELEMENTS) do
		local reserve = element.reserve
		if reserve then
			out[#out + 1] = { key = element.key, width = reserve[1], height = reserve[2], offsetX = reserve[3] }
		end
	end
	return out
end

function Layouts.Shown(name, key)
	local off = shown[name]
	if not off or not byKey[key] then
		return nil
	end
	return not off[key]
end

function Layouts.Settings(name)
	local list = settings[name]
	if not list then
		return nil
	end
	local out = {}
	for i, entry in ipairs(list) do
		out[i] = { module = entry.module, key = entry.key, value = entry.value }
	end
	return out
end

function Layouts.Slot(name, rootHeight)
	local slot = slots[name]
	if not slot then
		return nil
	end
	local out = {}
	for k, v in pairs(slot) do
		out[k] = v
	end
	out.height = slot.height - Lift(rootHeight)
	return out
end

function Layouts.Story(name, rootHeight, guide)
	local slot = Layouts.Slot(name, rootHeight)
	if not slot then
		return nil
	end
	local function Card(key, x, height)
		return { key = key, anchor = slot.anchor, x = x, y = slot.y, width = slot.width, height = height }
	end
	if not guide then
		return { quests = Card(STORY_KEYS.quests, slot.x, slot.height) }
	end
	local column = slot.height - (QUESTS_BOTTOM - STORY_BOTTOM)
	return { guide = Card(STORY_KEYS.guide, slot.x, slot.height), quests = Card(STORY_KEYS.quests, slot.x - slot.width - GAP, column) }
end

local LIFTED = {
	"unitframes.player", "unitframes.pet", "unitframes.target", "unitframes.focus", "unitframes.focustarget",
	"unitframes.targettarget", "unitframes.castbar.player", "cooldowns.essential", "cooldowns.utility",
	"cooldowns.buffs", "cooldowns.bars", "meters.swing", "meters.threat", "combattext.player", "actionbars.bar3",
}
local LIFTED_IN = {
	DPS = {},
	Tank = {},
	Healer = { "groupframes.party", "groupframes.raid" },
}
local OLD_ENDS = STRIP_ENDS
local TRAY_OLD = {
	["actionbars.bar1"] = { "BOTTOM", 0, 54 },
	["actionbars.bar2"] = { "BOTTOM", 0, 95.3 },
	["actionbars.pet"] = { "BOTTOM", -OLD_ENDS, 68 },
	["actionbars.stance"] = { "BOTTOM", OLD_ENDS, 68 },
	["databars.xp"] = { "BOTTOM", 0, 36.5 },
	["databars.rep"] = { "BOTTOM", -OLD_ENDS, 52 },
	["databars.honor"] = { "BOTTOM", OLD_ENDS, 52 },
	["unitframes.resource"] = { "BOTTOM", 0, 420 },
	["unitframes.castbar.target"] = { "BOTTOM", 0, STACK + 38 + 8 + 30 + 8 - LIFT },
}

local CAST_OLD = {
	["unitframes.resource"] = { "BOTTOM", 0, 420 + LIFT },
	["unitframes.castbar.target"] = { "BOTTOM", 0, STACK + 38 + 8 + 30 + 8 },
}

function Layouts.CastMoves()
	local out = {}
	for key, place in pairs(CAST_OLD) do
		out[key] = { place[1], place[2], place[3] }
	end
	return out
end

local HEALER_OLD = {
	["groupframes.party"] = { "BOTTOM", HEALER_X, HEALER_Y },
	["groupframes.raid"] = { "BOTTOM", HEALER_X, HEALER_Y },
	["unitframes.boss"] = { "TOPLEFT", MARGIN, -MARGIN },
	["combattext.player"] = { "BOTTOM", CAST_HALF + GAP + 160 / 2, CLUSTER_TOP + GAP },
}

function Layouts.HealerMoves()
	local out = {}
	for key, place in pairs(HEALER_OLD) do
		out[key] = { place[1], place[2], place[3] }
	end
	return out
end

function Layouts.TrayMoves(name)
	local layout = layouts[name]
	if not layout then
		return nil
	end
	local out = {}
	for key, place in pairs(TRAY_OLD) do
		out[key] = { place[1], place[2], place[3] }
	end
	local function lift(key)
		local now = layout[key]
		if now then
			out[key] = { now.anchor, now.x, now.y - LIFT }
		end
	end
	for _, key in ipairs(LIFTED) do
		lift(key)
	end
	for _, key in ipairs(LIFTED_IN[name] or {}) do
		lift(key)
	end
	return out
end

function Layouts.Default(key)
	local position = layouts.DPS[key]
	if not position then
		error("KstyleUI.Setup.Layouts.Default: unknown element key " .. tostring(key), 2)
	end
	return copy(position)
end

Layouts.ORBS_RING = ORBS_RING
Layouts.ORBS_REACH = ORBS_REACH
Layouts.ORBS_LIFT = ORBS_LIFT
Layouts.SPLIT_GAP = ORBS_SPLIT

function Layouts.OrbsTray(width)
	local s = width / ART.fit
	local function Box(l, top, r, bottom)
		return { left = (l - ART_X) * s, right = (r - ART_X) * s, top = (ART_Y - top) * s, bottom = (ART_Y - bottom) * s }
	end
	local hole, arm, crest = ART.hole, ART.arm, ART.crest
	local inner = 2 * ART_X - arm[3]
	local level = ART.level
	local half = level[2] / 2
	return {
		hole = Box(hole[1], hole[2], hole[3], hole[4]),
		arm = Box(arm[1], arm[2], arm[3], arm[4]),
		crest = Box(crest[1], crest[2], crest[3], crest[4]),
		rail = Box(arm[3], ART.rail[1], inner, ART.rail[2]),
		railBottom = Box(arm[3], ART.railBottom[1], inner, ART.railBottom[2]),
		ring = ART.ring[3] * s,
		ringX = (ART_X - ART.ring[1]) * s,
		lift = (ART_Y - ART.ring[2]) * s,
		level = Box(ART_X - half, level[1] - half, ART_X + half, level[1] + half),
		levelText = level[3] * s,
	}
end
Layouts.STYLES = { "orbs" }

function Layouts.Style(style, name, key)
	local set = STYLES[style] and STYLES[style][name]
	local position = set and set[key]
	if position then
		return { anchor = position.anchor, x = position.x, y = position.y, scale = position.scale, width = position.width, height = position.height }
	end
end

local ASPECTS = ns.Scale.ASPECTS
local PLACES = {}
for _, class in ipairs(ASPECTS) do
	PLACES[class] = { frames = {}, orbs = {} }
end
Layouts.ASPECTS, Layouts.PLACES = ASPECTS, PLACES

function Layouts.Aspect(class, style, name, key)
	local styled = style ~= "frames" and Layouts.Style(style, name, key) ~= nil
	local set = PLACES[class] and PLACES[class][styled and style or "frames"]
	local position = set and set[key]
	if position and position.anchor and position.x and position.y then
		return copy(position)
	end
end

function Layouts.Place(name, style, class, key)
	local base = layouts[name] and layouts[name][key]
	if not base then
		return nil
	end
	local place = Layouts.Aspect(class, style, name, key) or Layouts.Style(style, name, key) or base
	return { anchor = place.anchor, x = place.x, y = place.y }
end

function Layouts.Positions(name, style, class)
	local out = Layouts.Get(name)
	for key, position in pairs(out or {}) do
		local place = Layouts.Place(name, style, class, key)
		position.anchor, position.x, position.y = place.anchor, place.x, place.y
	end
	return out
end

function Layouts.StyleKeys(style, name)
	local out = {}
	for key in pairs(STYLES[style] and STYLES[style][name] or {}) do
		out[#out + 1] = key
	end
	table.sort(out)
	return out
end

local LEGACY = {
	DPS = {
		["unitframes.player"] = { "BOTTOM", 0, 118 },
		["unitframes.pet"] = { "BOTTOM", -317, 176 },
		["unitframes.resource"] = { "BOTTOM", 0, 204 },
		["cooldowns.essential"] = { "BOTTOM", 0, 226 },
		["cooldowns.utility"] = { "BOTTOM", 248, 226 },
		["cooldowns.buffs"] = { "BOTTOM", -260.5, 226 },
		["cooldowns.bars"] = { "BOTTOM", -260.5, 264 },
		["meters.swing"] = { "BOTTOM", 0, 276 },
		["unitframes.target"] = { "TOP", 0, -630 },
		["unitframes.focus"] = { "BOTTOM", -357, 338 },
		["unitframes.focustarget"] = { "BOTTOM", -397, 312 },
		["unitframes.targettarget"] = { "BOTTOM", 317, 428 },
		["unitframes.castbar.player"] = { "BOTTOM", 0, 512 },
		["unitframes.castbar.target"] = { "BOTTOM", 0, 550 },
		["unitframes.boss"] = { "BOTTOMRIGHT", -362, 662 },
		["combattext.player"] = { "BOTTOM", 376, 466 },
		["actionbars.bar2"] = { "TOPLEFT", 362, -28 },
		["actionbars.bar5"] = { "TOPLEFT", 403, -28 },
		["actionbars.bar6"] = { "TOPLEFT", 444, -28 },
		["actionbars.bar3"] = { "TOPLEFT", 485, -28 },
		["actionbars.bar4"] = { "TOPLEFT", 526, -28 },
	},
	Tank = {
		["meters.threat"] = { "BOTTOM", 357, 312 },
	},
	Healer = {
		["groupframes.party"] = { "BOTTOM", -311, 466 },
		["groupframes.raid"] = { "BOTTOM", -311, 466 },
		["combattext.player"] = { "BOTTOM", 232, 466 },
		["unitframes.boss"] = { "TOPLEFT", 28, -28 },
		["actionbars.bar2"] = { "TOPRIGHT", -362, -533 },
		["actionbars.bar3"] = { "TOPRIGHT", -362, -28 },
		["actionbars.bar4"] = { "TOPRIGHT", -403, -28 },
		["actionbars.bar5"] = { "TOPRIGHT", -444, -28 },
		["actionbars.bar6"] = { "TOPRIGHT", -485, -28 },
	},
}

local function Legacy(name, key)
	return LEGACY[name][key] or LEGACY.DPS[key]
end

local function At(entry, place)
	return entry.anchor == place[1] and type(entry.x) == "number" and type(entry.y) == "number"
		and math.abs(entry.x - place[2]) < 0.01 and math.abs(entry.y - place[3]) < 0.01
end

local function Whole(key, entry)
	local old = LEGACY.DPS[key]
	if not old then
		local now = layouts.DPS[key]
		old = { now.anchor, now.x, now.y }
	end
	local x, y = entry.x, entry.y
	if x == nil then
		x = old[2]
	end
	if y == nil then
		y = old[3]
	end
	return { anchor = entry.anchor or old[1], x = x, y = y }
end

function Layouts.Upgrade(saved, preset, rootHeight)
	if type(saved) ~= "table" then
		return 0
	end
	local order = { "DPS", "Tank", "Healer" }
	if layouts[preset] then
		table.insert(order, 1, preset)
	end
	local moved = 0
	for key, entry in pairs(saved) do
		if type(entry) == "table" and layouts.DPS[key] then
			local whole = Whole(key, entry)
			for _, name in ipairs(order) do
				local place = Legacy(name, key)
				if place and At(whole, place) then
					local now = Layouts.Get(name, rootHeight)[key]
					entry.anchor, entry.x, entry.y = now.anchor, now.x, now.y
					moved = moved + 1
					break
				end
			end
		end
	end
	return moved
end

local CENTRE_V9 = {
	["unitframes.player"] = { "BOTTOM", 0, 200, 490, 80 },
	["unitframes.target"] = { "TOP", 0, -742.5, 490, 84 },
	["unitframes.resource"] = { "BOTTOM", 0, 286, 120, 14 },
	["unitframes.castbar.player"] = { "BOTTOM", 0, 602, 272, 30 },
	["cooldowns.essential"] = { "BOTTOM", 0, 308, 243, 38 },
	["cooldowns.utility"] = { "BOTTOM", 218, 308, 161, 38 },
	["cooldowns.buffs"] = { "BOTTOM", -259, 308, 243, 38 },
	["cooldowns.bars"] = { "BOTTOM", -259, 354, 243, 43 },
	["meters.swing"] = { "BOTTOM", 0, 352, 260, 8 },
	["actionbars.bar1"] = { "BOTTOM", 0, 68, 489, 38 },
	["actionbars.bar2"] = { "BOTTOM", 0, 109, 489, 38 },
	["actionbars.bar3"] = { "BOTTOM", 0, 150, 489, 38 },
	["databars.xp"] = { "BOTTOM", 0, 52, 489, 4 },
}

function Layouts.UpgradeCentre(saved, rootHeight)
	if type(saved) ~= "table" then
		return
	end
	for key, old in pairs(CENTRE_V9) do
		local entry = saved[key]
		if type(entry) == "table" then
			local y = old[3] + (key == "unitframes.target" and Lift(rootHeight) or 0)
			local anchor = entry.anchor or old[1]
			local x = entry.x == nil and old[2] or entry.x
			local ey = entry.y == nil and y or entry.y
			if anchor == old[1] and type(x) == "number" and type(ey) == "number"
				and math.abs(x - old[2]) < 0.01 and math.abs(ey - y) < 0.01 then
				local now = layouts.DPS[key]
				entry.anchor, entry.x, entry.y = now.anchor, now.x, now.y
			elseif entry.anchor ~= nil or entry.x ~= nil or entry.y ~= nil then
				entry.anchor, entry.x, entry.y = anchor, x, ey
			end
			if entry.width == old[4] then
				entry.width = nil
			end
			if entry.height == old[5] then
				entry.height = nil
			end
		end
	end
end

function Layouts.Rect(element, position, rootWidth, rootHeight)
	local point = OFFSETS[position.anchor] or OFFSETS.CENTER
	local fx, fy = point[1], point[2]
	local left = rootWidth * fx + position.x - element.width * fx + (element.offsetX or 0)
	local bottom = rootHeight * fy + position.y - element.height * fy
	return left, bottom, left + element.width, bottom + element.height
end

local function Positive(value)
	if issecretvalue and issecretvalue(value) then
		return false
	end
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

function Layouts.Enabled(name, profile)
	local enabled = {}
	for _, element in ipairs(ELEMENTS) do
		local key = element.key
		local on = Layouts.Shown(name, key) ~= false
		local section = profile and profile[element.module]
		if profile then
			on = type(section) == "table" and section.enabled == true
			if on then
				local id = key:match("^[^.]+%.(.+)$")
				local cast = id:match("^castbar%.(.+)$")
				local entry = section[cast or id]
				if cast then
					on = type(entry) == "table" and entry.castbar ~= false
					if on and entry.enabled ~= false then
						on = entry.style == "plate" or (cast == "player" and entry.style == "column")
					end
				elseif type(entry) == "table" then
					on = entry.enabled ~= false and entry.shown ~= false
				elseif key == "qol.lootfeed" then
					on = section.lootFeed ~= false
				else
					on = Layouts.Shown(name, key) ~= false
				end
			end
		end
		enabled[key] = on
	end
	return enabled
end

local function Apart(a, b)
	if (a == "groupframes.party" and b == "groupframes.raid") or (b == "groupframes.party" and a == "groupframes.raid") then
		return false
	end
	if DOCKS[a] == b or DOCKS[b] == a then
		return false
	end
	return true
end

function Layouts.Fits(name, physicalWidth, physicalHeight, user, enabled, positions, style)
	if not Positive(physicalWidth) or not Positive(physicalHeight) or not Positive(user) then
		return false
	end
	local floor, max, min = math.floor, math.max, math.min
	local rootHeight = 1080 / user
	local layout = positions or Layouts.Get(name, rootHeight)
	if not layout then
		return false
	end
	local pixelScale = physicalHeight / rootHeight
	enabled = enabled or Layouts.Enabled(name)
	local rects = {}
	local story = Layouts.Story(name, rootHeight, true)
	local cards = { story.guide, story.quests }
	for i = 1, #ELEMENTS + #cards do
		local key, width, height, position, offsetX
		if i <= #ELEMENTS then
			key = ELEMENTS[i].key
			width, height, offsetX = Layouts.Footprint(name, key)
			local styled = style and Layouts.Style(style, name, key)
			if styled and styled.width then
				width, height, offsetX = styled.width, styled.height, nil
			end
			position = layout[key]
		else
			position = cards[i - #ELEMENTS]
			key, width, height = position.key, position.width, position.height
		end
		if enabled[key] ~= false and not (REPLACED[style] and REPLACED[style][key]) then
			if width <= 0 or height < STORY_FLOOR and position.key or height <= 0 then
				return false
			end
			local w = max(1, floor(width * pixelScale + 0.5))
			local h = max(1, floor(height * pixelScale + 0.5))
			local point = OFFSETS[position.anchor] or OFFSETS.CENTER
			local left = floor(physicalWidth * point[1] + (position.x + (offsetX or 0)) * pixelScale - w * point[1] + 0.5)
			local bottom = floor(physicalHeight * point[2] + position.y * pixelScale - h * point[2] + 0.5)
			local right, top = left + w, bottom + h
			if left < 0 or bottom < 0 or right > physicalWidth or top > physicalHeight or right <= left or top <= bottom then
				return false
			end
			for index = 1, #rects do
				local rect = rects[index]
				if left < rect[3] and rect[1] < right and bottom < rect[4] and rect[2] < top and Apart(key, rect.key) then
					local dockBoundary = (key == "databars.micro" and rect.key == "databars.bags") or (key == "databars.bags" and rect.key == "databars.micro")
					if not dockBoundary or min(top, rect[4]) - max(bottom, rect[2]) > 1 then
						return false
					end
				end
			end
			rects[#rects + 1] = { left, bottom, right, top, key = key }
		end
	end
	return true
end

local limits = {}

function Layouts.ScaleLimit(physicalWidth, physicalHeight, preset, enabled, style)
	local low, high = ns.Scale.MIN_USER_SCALE, ns.Scale.MAX_USER_SCALE
	if not Positive(physicalWidth) or not Positive(physicalHeight) then
		return ns.Scale.DEFAULT_USER_SCALE
	end
	preset = layouts[preset] and preset or "DPS"
	enabled = enabled or Layouts.Enabled(preset)
	local flags = {}
	for i, element in ipairs(ELEMENTS) do
		flags[i] = enabled[element.key] ~= false and "1" or "0"
	end
	style = STYLES[style] and style or "frames"
	local signature = style .. table.concat(flags)
	local cached = limits[preset]
	if cached and cached.width == physicalWidth and cached.height == physicalHeight and cached.signature == signature then
		return cached.scale
	end
	local positions = Layouts.Positions(preset, style, ns.Scale.AspectClass(physicalWidth, physicalHeight))
	if Layouts.Fits(preset, physicalWidth, physicalHeight, high, enabled, positions, style) then
		limits[preset] = { width = physicalWidth, height = physicalHeight, signature = signature, scale = high }
		return high
	end
	local span = HEIGHT
	for _, element in ipairs(ELEMENTS) do
		local width, height = Layouts.Footprint(preset, element.key)
		local position = positions[element.key]
		span = math.max(span, math.abs(position.x) + width, math.abs(position.y) + height)
	end
	local step = 1080 / (physicalHeight * 2 * span)
	while high > low do
		local candidate = math.max(low, high - step)
		if candidate == high then
			break
		end
		if Layouts.Fits(preset, physicalWidth, physicalHeight, candidate, enabled, positions, style) then
			low = candidate
			break
		end
		high = candidate
	end
	for _ = 1, 32 do
		local candidate = (low + high) / 2
		if Layouts.Fits(preset, physicalWidth, physicalHeight, candidate, enabled, positions, style) then
			low = candidate
		else
			high = candidate
		end
	end
	limits[preset] = { width = physicalWidth, height = physicalHeight, signature = signature, scale = low }
	return low
end
