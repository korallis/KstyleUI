-- Layouts.lua: the element keys modules register with Layout, and the Lumen DPS, Tank and Healer layouts the first-run setup writes: positions, footprints, the bars and meters each switches on, the story slot on the right rail under the map, which stays free yet still sets how large the automatic size may grow, with the quest card in the column beside it, the guide card (RestedXP or Zygor) in the top left corner above the party frames, a place it shares with the raid frames, and each layout class's own places.
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
local TRAY_BUTTON, TRAY_GAP, TRAY_PAD, TRAY_BOTTOM = 38 * MOCK_PX, 3 * MOCK_PX, 9 * MOCK_PX, 40 * MOCK_PX + 4
local TRAY_WIDTH = 12 * TRAY_BUTTON + 11 * TRAY_GAP + 2 * TRAY_PAD
local TRAY_BAR1_Y = TRAY_BOTTOM + TRAY_PAD
local TRAY_BAR2_Y = TRAY_BAR1_Y + TRAY_BUTTON + TRAY_GAP
local TRAY_TOP = TRAY_BAR2_Y + TRAY_BUTTON + TRAY_PAD
local TRAY_STRIP_GAP = 9 * MOCK_PX
local XP_H = 7 * MOCK_PX
local LIFT = math.ceil(TRAY_TOP - 132)
local PLAYER_CAST_Y = 385.5 + LIFT
local COMBAT_TEXT_H = 180
local GRIDS = {
	["actionbars.bar1"] = { buttons = 12, rows = 1, size = TRAY_BUTTON, spacing = TRAY_GAP },
	["actionbars.bar2"] = { buttons = 12, rows = 1, size = TRAY_BUTTON, spacing = TRAY_GAP },
	["actionbars.bar3"] = { buttons = 12, rows = 1, size = BUTTON },
	["actionbars.bar4"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH, growth = "RIGHTUP" },
	["actionbars.bar5"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH, growth = "RIGHTUP" },
	["actionbars.bar6"] = { buttons = 12, rows = 12, size = RAIL_BUTTON, spacing = RAIL_PITCH, growth = "RIGHTUP" },
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
local MAP, MAP_HEADING, MAP_CAPTION, MAP_FRAME = 208, 22, 14, 3
local AURA_ICON, AURA_GAP, AURA_COLUMNS, AURA_TIMER, AURA_ROW_GAP, AURA_MAP_GAP = 27.6, 3.5, 10, 14, 12, 11.9
local AURA_W, AURA_H = AURA_COLUMNS * AURA_ICON + (AURA_COLUMNS - 1) * AURA_GAP, AURA_ICON + AURA_TIMER
local STORY_W = 278
local DAMAGE_W, DAMAGE_H = 250, 158
local THREAT_W, THREAT_H = DAMAGE_W, 112
local READOUT_H, READOUT_GAP, RAIL_BARS_GAP = 12, 6, 10

local PARTY = { width = 259, height = 5 * 39 + 4 * 13, healer = 5 * 43 + 4 * 13, top = 465, scale = 1.25 }

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
	{ key = "groupframes.party", module = "GroupFrames", label = L["Party frames"], short = L["Party"], width = PARTY.width, height = PARTY.height },
	{ key = "groupframes.raid", module = "GroupFrames", label = L["Raid frames"], short = L["Raid"], width = 543, height = 401 },
	{ key = "actionbars.bar1", module = "ActionBars", label = L["Action bar 1"], short = L["Bar 1"], grid = true },
	{ key = "actionbars.bar2", module = "ActionBars", label = L["Action bar 2"], short = L["Bar 2"], grid = true },
	{ key = "actionbars.bar3", module = "ActionBars", label = L["Action bar 3"], grid = true },
	{ key = "actionbars.bar4", module = "ActionBars", label = L["Action bar 4"], grid = true },
	{ key = "actionbars.bar5", module = "ActionBars", label = L["Action bar 5"], grid = true },
	{ key = "actionbars.bar6", module = "ActionBars", label = L["Action bar 6"], grid = true },
	{ key = "actionbars.pet", module = "ActionBars", label = L["Pet bar"], grid = true },
	{ key = "actionbars.stance", module = "ActionBars", label = L["Stance bar"], grid = true },
	{ key = "consumables.bar", module = "ActionBars", label = L["Consumables bar"], width = 243, height = 79 },
	{ key = "actionbars.possess", module = "ActionBars", label = L["Possess"], width = 64, height = 30 },
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], short = L["Cooldowns"], width = 6 * CENTRE_BUTTON + 5 * CENTRE_GAP, height = CENTRE_BUTTON },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = UTILITY, height = BUTTON },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = 182.6, height = 41.6 },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = TRACKED, height = 2 * ns.Tokens.Size("barHeight") + PITCH },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], short = L["Auras"], width = AURA_W, height = AURA_H },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = AURA_W, height = AURA_H },
	{ key = "auras.extraBuffs", module = "Auras", label = L["Extra buff row"], width = 6 * 36 + 5 * AURA_GAP, height = 36 + AURA_TIMER },
	{ key = "auras.extraDebuffs", module = "Auras", label = L["Extra debuff row"], width = 6 * 36 + 5 * AURA_GAP, height = 36 + AURA_TIMER },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], short = L["Map"], width = MAP, height = MAP, reserve = { MAP, MAP + MAP_CAPTION } },
	{ key = "chat.main", module = "Chat", label = L["Chat"], short = L["Chat"], width = 442, height = 186 },
	{ key = "qol.lootfeed", module = "QoL", label = L["Loot feed"], short = L["Loot"], width = ns.Tokens.Size("railWidth"), height = FEED_LINES * FEED_ROW + (FEED_LINES - 1) * FEED_GAP + 2 * FEED_PAD },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = COLUMN, height = XP_H, insets = { 0, 0, 24, 0 } },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 162, height = 5, insets = { 0, 0, 24, 0 } },
	{ key = "databars.honor", module = "DataBars", label = L["Honour bar"], width = 162, height = 5, insets = { 0, 0, 24, 0 } },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], short = L["Readout"], width = STORY_W, height = READOUT_H },
	{ key = "databars.strip2", module = "DataBars", label = L["Second data bar"], width = STORY_W, height = READOUT_H },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 318, height = 44 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 212, height = 32 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], short = L["Damage"], width = DAMAGE_W, height = DAMAGE_H },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], short = L["Threat"], width = THREAT_W, height = THREAT_H },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], short = L["Combat text"], width = 160, height = COMBAT_TEXT_H - LIFT + 4 },
	{ key = "tooltips.anchor", module = "Tooltips", label = L["Tooltip anchor"], width = 180, height = 24 },
}

for _, element in ipairs(ELEMENTS) do
	if element.module == "UnitFrames" then element.insets = { 2, 2, 2, 2 } end
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
local TEXT_TOP = CLUSTER_TOP - LIFT + GAP + COMBAT_TEXT_H + 4
local BOSS_X = -(EDGE + 2 * STORY_W + 2 * GAP)
local function ElementSize(key)
	for _, element in ipairs(ELEMENTS) do
		if element.key == key then
			return element.width, element.height
		end
	end
end
local _, CHAT_H = ElementSize("chat.main")
local AURAS_X = EDGE + MAP_FRAME + MAP + AURA_MAP_GAP
local DEBUFFS_Y = RAIL_EDGE + AURA_H + AURA_ROW_GAP
local STORY_TOP = math.max(EDGE + MAP_HEADING + MAP + MAP_CAPTION, DEBUFFS_Y + AURA_H) + GAP + 10
local READOUT_Y = EDGE + DAMAGE_H + READOUT_GAP
local RAIL_BARS_Y = READOUT_Y + READOUT_H + RAIL_BARS_GAP
local RAIL_COLUMN = RAIL_BUTTON + RAIL_PITCH
local _, RAIL_BARS_H = GridSize("actionbars.bar4")
local STORY_BOTTOM = RAIL_BARS_Y + RAIL_BARS_H + NEAR + 1
local STORY_FLOOR = 72
local STORY_KEYS = { guide = "skins.guide", quests = "skins.quests" }
local SPARE_X = RAIL_EDGE + 3 * RAIL_COLUMN - RAIL_PITCH + GAP
local _, MICRO_H = ElementSize("databars.micro")
local _, BAGS_H = ElementSize("databars.bags")
local TIP_Y = RAIL_BARS_Y + MICRO_H + BAGS_H + GAP

local DPS = {
	["groupframes.party"] = { anchor = "LEFT", x = MARGIN, y = HEIGHT / 2 - PARTY.top - PARTY.height / 2 },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN },
	["qol.lootfeed"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN + CHAT_H + GAP },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -(EDGE + MAP_FRAME + 4), y = -(EDGE + 10 + MAP_HEADING) },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -RAIL_EDGE },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -DEBUFFS_Y },
	["auras.extraBuffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -(DEBUFFS_Y + AURA_H + AURA_ROW_GAP) },
	["auras.extraDebuffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -(DEBUFFS_Y + AURA_H + 36 + AURA_TIMER + 2 * AURA_ROW_GAP) },
	["meters.damage"] = { anchor = "BOTTOMRIGHT", x = -EDGE, y = EDGE },
	["meters.threat"] = { anchor = "BOTTOMRIGHT", x = -263, y = 217.5 + LIFT + 102.5 + GAP },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -EDGE, y = READOUT_Y },
	["databars.strip2"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = TIP_Y + select(2, ElementSize("tooltips.anchor")) + GAP },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = RAIL_BARS_Y },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -SPARE_X, y = RAIL_BARS_Y + MICRO_H },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = TRAY_BOTTOM - TRAY_STRIP_GAP - XP_H + 9 },
	["databars.rep"] = { anchor = "BOTTOM", x = -STRIP_ENDS, y = TRAY_BOTTOM - TRAY_STRIP_GAP - 1 },
	["databars.honor"] = { anchor = "BOTTOM", x = STRIP_ENDS, y = TRAY_BOTTOM - TRAY_STRIP_GAP - 1 },
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = TRAY_BAR1_Y },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = TRAY_BAR2_Y },
	["actionbars.bar3"] = { anchor = "BOTTOM", x = -460, y = 640 },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -ENDS, y = TRAY_BOTTOM },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ENDS, y = TRAY_BOTTOM },
	["actionbars.possess"] = { anchor = "TOPLEFT", x = MARGIN + 623 + GAP, y = -MARGIN },
	["consumables.bar"] = { anchor = "BOTTOM", x = -506.5, y = 219 },
	["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 138 + LIFT },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -317, y = VITALS_TOP - 22 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = 421 + LIFT },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 335.3 + LIFT },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = UTILITY_X, y = 335.3 + LIFT },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = -((6 * CENTRE_BUTTON + 5 * CENTRE_GAP) / 2 + GAP + 182.6 / 2), y = 335.3 + LIFT },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -(347 / 2 + GAP + 6 * 28.5 + 5 * 3 + GAP + TRACKED / 2), y = 340 + LIFT },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 421 + 14 + 8 + LIFT },
	["unitframes.target"] = { anchor = "BOTTOM", x = 0, y = 217.5 + LIFT },
	["unitframes.focus"] = { anchor = "BOTTOM", x = FOCUS_X, y = CLUSTER_TOP - 112 },
	["unitframes.focustarget"] = { anchor = "BOTTOM", x = FOCUS_X - (200 - 120) / 2, y = CLUSTER_TOP - 112 - TIGHT - 22 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = TOT_X, y = CLUSTER_TOP - 22 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = PLAYER_CAST_Y },
	["unitframes.castbar.target"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 + 30 - TIGHT },
	["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = BOSS_X, y = TEXT_TOP + GAP },
	["combattext.player"] = { anchor = "BOTTOM", x = SIDE - 80 - GAP, y = 421 + 14 + 8 + LIFT + 8 + GAP },
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
		["groupframes.party"] = { PARTY.width, PARTY.healer },
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
	{ key = "consumables.bar", module = "ActionBars", setting = "consumables.enabled" },
	{ key = "meters.threat", module = "Meters", setting = "threat.shown" },
	{ key = "auras.extraBuffs", module = "Auras", setting = "extraBuffs.enabled" },
	{ key = "auras.extraDebuffs", module = "Auras", setting = "extraDebuffs.enabled" },
	{ key = "databars.strip2", module = "DataBars", setting = "strip.second" },
}

local BARS_OFF = {
	"actionbars.bar3", "actionbars.bar6",
	"unitframes.castbar.target", "auras.extraBuffs", "auras.extraDebuffs", "databars.strip2",
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
	{ module = "DataBars", key = "strip.menus", value = true },
	{ module = "GroupFrames", key = "raid.groupsPerRow", value = 4 },
}
local GRID_ORDER = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "pet", "stance" }
for i = #GRID_ORDER, 1, -1 do
	local bar = GRID_ORDER[i]
	local grid = GRIDS["actionbars." .. bar]
	if grid.growth then
		table.insert(SHARED_SETTINGS, 1, { module = "ActionBars", key = bar .. ".growth", value = grid.growth })
	end
	table.insert(SHARED_SETTINGS, 1, { module = "ActionBars", key = bar .. ".rows", value = (bar == "pet" or bar == "stance") and 0 or grid.rows })
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
	DPS = L["Party and chat on the left rail; the map, buffs, quests and damage meter on the right; your target, its target and your focus sit right over your hands."],
	Tank = L["The DPS layout with the threat meter on the right, under the quest card, where it reads who holds aggro without covering the enemies' nameplates."],
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
		hint = L["Apply places the quest tracker beside this space through Edit Mode."],
	}
end

local STYLES = { medallions = {} }

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
Layouts.STORY_GAP = GAP
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

function Layouts.ActionBarGrid(class, key, cfg, style)
	style = style or ns.HudStyle.Current()
	local grid = GRIDS[key]
	if not grid then return end
	local saved = ns.Store and ns.Store.IsLoaded() and ns.Store.Module("ActionBars") or {}
	cfg = cfg or saved[key:match("%.(.+)$")] or {}
	local side = key == "actionbars.pet" or key == "actionbars.stance"
	local count = cfg.buttons or grid.buttons
	if count ~= grid.buttons then count = math.min(grid.buttons, math.max(1, math.floor(count))) end
	local rows = cfg.rows or (side and 0 or grid.rows)
	local size, gap = cfg.size or grid.size, cfg.spacing or (side and -1 or grid.spacing or PITCH)
	if rows == 0 then rows = style == "medallions" and side and Layouts.MEDALLIONS_SIDE.rows or grid.rows end
	if gap < 0 then gap = style == "medallions" and side and Layouts.MEDALLIONS_SIDE.gap * size / grid.size or PITCH end
	if style == "medallions" and saved.slab ~= false and (key == "actionbars.bar1" or key == "actionbars.bar2") then
		local _, _, _, _, cell, spacing = Layouts.MedallionsGroup(class)
		size = saved.bar1 and saved.bar1.size or size
		rows, gap, size = 1, spacing * size / grid.size, cell * size / grid.size
	end
	return count, rows, size, gap, saved, cfg, grid, side
end

function Layouts.ActionBarFootprint(class, key, style)
	style = style or ns.HudStyle.Current()
	local count, rows, size, gap, saved, cfg, grid, side = Layouts.ActionBarGrid(class, key, nil, style)
	if not count then return end
	local defaultRows, defaultGap = side and 0 or grid.rows, side and -1 or grid.spacing or PITCH
	local defaultSplit = "off"
	if (cfg.buttons == nil or cfg.buttons == grid.buttons) and (cfg.rows == nil or cfg.rows == defaultRows) and (cfg.size == nil or cfg.size == grid.size)
		and (cfg.spacing == nil or cfg.spacing == defaultGap) and (cfg.split == nil or cfg.split == defaultSplit) then
		if style == "medallions" then
			if saved.slab ~= false and (key == "actionbars.bar1" or key == "actionbars.bar2") then
				local _, _, width, height = Layouts.MedallionsGroup(class)
				return width, height
			end
			if side then return select(2, Layouts.MedallionsSide(class, key)) end
		end
		return byKey[key].width, byKey[key].height
	end
	rows = math.min(count, math.max(1, math.floor(rows)))
	local columns = math.ceil(count / rows)
	rows = math.ceil(count / columns)
	local height = rows * size + (rows - 1) * gap
	if style == "frames" and saved.useTray ~= false and saved.trayColumn ~= false and (key == "actionbars.bar1" or key == "actionbars.bar2") then
		size, gap = size * 37.6 / grid.size, gap * 3.6 / grid.spacing
	end
	local width = columns * size + (columns - 1) * gap
	local grouped = style == "medallions" and saved.slab ~= false and (key == "actionbars.bar1" or key == "actionbars.bar2")
	if not grouped and columns > 1 and cfg.split == "on" then width = width + Layouts.SPLIT_GAP end
	return width, height
end

function Layouts.ActionBarSignature(style)
	local saved = ns.Store and ns.Store.IsLoaded() and ns.Store.Module("ActionBars") or {}
	local out = { tostring(saved.slab ~= false), tostring(saved.useTray ~= false), tostring(saved.trayColumn ~= false), saved.extraBarsApplied or "off" }
	local strip = ns.Store and ns.Store.IsLoaded() and ns.Store.Module("DataBars").strip or {}
	out[#out + 1] = strip.placement or "rail"
	local height = Layouts.DataBarHeight(style)
	if height then
		local bar = Layouts.DataBarPosition(style)
		out[#out + 1] = table.concat({ height, bar.anchor, bar.x, bar.y, bar.width or 0, bar.height or 0, bar.shown or "always" }, "/")
	end
	for _, key in ipairs(GRID_ORDER) do
		local grid, cfg = GRIDS["actionbars." .. key], saved[key] or {}
		local side = key == "pet" or key == "stance"
		out[#out + 1] = table.concat({ cfg.buttons or grid.buttons, cfg.rows or (side and 0 or grid.rows), cfg.size or grid.size, cfg.spacing or (side and -1 or grid.spacing or PITCH), cfg.split or (key == "bar2" and "auto" or "off") }, "/")
	end
	return table.concat(out, ":")
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

function Layouts.CooldownGrid(key, style)
	style = style or ns.HudStyle.Current()
	local group = key == "cooldowns.essential" and "essential" or key == "cooldowns.utility" and "utility"
	if not group then return end
	local saved = ns.Store and ns.Store.IsLoaded() and ns.Store.Module("Cooldowns") or {}
	local cfg = type(saved[group]) == "table" and saved[group] or {}
	local attached, essential = saved.attached ~= false, group == "essential"
	local stacked = attached and style ~= "frames"
	local function Number(value, low, high, step, fallback)
		if type(value) ~= "number" or issecretvalue and issecretvalue(value) or value ~= value then return fallback end
		if fallback == 0 and value == 0 then return 0 end
		return math.floor(math.min(high, math.max(low, value)) / step + 0.5) / (1 / step)
	end
	local columns = Number(cfg.columns, 1, 12, 1, 0)
	local rows = Number(cfg.rows, 1, 4, 1, 0)
	if columns == 0 then columns = stacked and 6 or (essential and (attached and 12 or 6) or 4) end
	if rows == 0 then rows = stacked and 2 or (essential and 1 or (attached and 3 or 1)) end
	return Number(cfg.size, 16, 64, 0.1, essential and CENTRE_BUTTON or BUTTON), Number(cfg.spacing, 0, 12, 0.1, essential and CENTRE_GAP or PITCH), columns, rows
end

Layouts.CREST_GROW = MAP * (150 / 118 - 1)

function Layouts.CrestKey()
	return tostring(Layouts.MinimapCrest() and ns.Store.Module("Minimap").frame)
end

function Layouts.MinimapCrest()
	local section = ns.Store.IsLoaded() and ns.Store.Profile().Minimap
	if type(section) ~= "table" or section.enabled ~= true then return false end
	local frame = section.frame
	return not (issecretvalue and issecretvalue(frame)) and (frame == nil or frame == "medallion" or frame == "ring")
end

function Layouts.ConsumableGrid(class, style)
	style = style or ns.HudStyle.Current()
	local cfg = ns.Store.IsLoaded() and ns.Store.Module("ActionBars").consumables or {}
	local size = (cfg.size or 26) * (style == "medallions" and (Layouts.MEDALLIONS_SLOT[class or ns.Scale.Aspect()] or Layouts.MEDALLIONS_SLOT.size) / BUTTON or 1)
	local gap = (cfg.spacing or 0) < 0 and (style == "medallions" and Layouts.MEDALLIONS_SLOT.gap * size / Layouts.MEDALLIONS_SLOT.size or PITCH * size / BUTTON) or cfg.spacing or 0
	return math.min(12, math.max(1, math.floor(cfg.rows or 2))), size, gap
end

function Layouts.ConsumableFootprint(class, style)
	local rows, size, gap = Layouts.ConsumableGrid(class, style)
	local columns = math.ceil(12 / rows)
	rows = math.ceil(12 / columns)
	return columns * (size + gap) - gap, rows * (size + gap) - gap
end

function Layouts.PartyScale(width, height)
	local loaded = ns.Store.IsLoaded()
	local saved = loaded and ns.Store.Profile().GroupFrames
	local readable, party = type(saved) == "table" and saved.readable, type(saved) == "table" and saved.party
	local rows = ROWS[loaded and ns.Store.Module("Layout").preset] or ROWS.DPS
	if type(readable) == "table" and readable.size == false then return 1 end
	if type(party) == "table" and ((party.width or PARTY.width) ~= PARTY.width or (party.height or rows.party) ~= rows.party) then return 1 end
	return (width and height and ns.Scale.AspectClass(width, height) or ns.Scale.Aspect()) ~= "16:9" and PARTY.scale or 1
end

function Layouts.Footprint(name, key, class, style, width, height)
	local element = byKey[key]
	if not element or not layouts[name] then
		return nil
	end
	style = style or (ns.HudStyle and ns.HudStyle.Current() or "frames")
	if style == "medallions" and key == "minimap.main" and Layouts.MinimapCrest() then
		local overhang = Layouts.CREST_GROW / 2
		return MAP + 2 * overhang, MAP + 2 * overhang + 40, overhang, overhang + 20
	end
	if key == "consumables.bar" then return Layouts.ConsumableFootprint(class, style) end
	if GRIDS[key] then return Layouts.ActionBarFootprint(class or ns.Scale.Aspect(), key, style) end
	local size, gap, columns, rows = Layouts.CooldownGrid(key, style)
	if size then return columns * size + (columns - 1) * gap, rows * size + (rows - 1) * gap end
	local place = Layouts.Attached(name, key, ns.Scale.Aspect(), style)
	if place and place.width then return place.width, place.height end
	local reserve = SIZES[name][key] or element.reserve
	if key == "groupframes.party" then
		local scale = Layouts.PartyScale(width, height)
		return (reserve and reserve[1] or element.width) * scale, (reserve and reserve[2] or element.height) * scale
	end
	if reserve then
		return reserve[1], reserve[2], reserve[3], reserve[4]
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
			out[#out + 1] = { key = element.key, width = reserve[1], height = reserve[2], offsetX = reserve[3], offsetY = reserve[4] }
		end
	end
	return out
end

function Layouts.Shown(name, key)
	if key == "actionbars.possess" then return PossessActionBar ~= nil and PossessActionBar:IsShown() end
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
	out.height = slot.height - Lift(rootHeight) - Layouts.TopInset()
	return out
end

do
local function Card(out, key, anchor, x, y, width, height)
	out = out or {}
	out.key, out.anchor, out.x, out.y, out.width, out.height = key, anchor, x, y, width, height
	return out
end

function Layouts.Story(name, rootHeight, guide, rootWidth, out, targetWidth, crest, inset, style)
	local slot = slots[name]
	if not slot then
		return nil
	end
	style = style or ns.HudStyle.Current()
	crest = style == "medallions" and (crest or crest == nil and Layouts.MinimapCrest()) and (ns.Store.Module("Minimap").frame == "ring" and 36 or 26) or 0
	local offset = style == "medallions" and GAP + crest or 0
	inset = offset + (inset or Layouts.TopInset(style))
	local rh, party, size = HEIGHT - Lift(rootHeight), layouts[name]["groupframes.party"], SIZES[name]["groupframes.party"]
	local partyTop = rh / 2 + party.y + (size and size[2] or PARTY.height) * Layouts.PartyScale(rootWidth, rootHeight) / 2
	out = out or {}
	out.guide = guide and Card(out.guide, STORY_KEYS.guide, "TOPLEFT", MARGIN, -MARGIN, STORY_W, rh - MARGIN - GAP - partyTop) or nil
	out.slot = slot.height - Lift(rootHeight) - inset
	if style ~= "medallions" then
		out.quests = Card(out.quests, STORY_KEYS.quests, slot.anchor, slot.x, slot.y, slot.width, out.slot)
		return out
	end
	local x, foot = slot.x - slot.width - GAP, CLUSTER_TOP
	local tot = rootWidth and layouts[name]["unitframes.targettarget"]
	if tot then
		local w = targetWidth or Layouts.Footprint(name, "unitframes.targettarget")
		local point = OFFSETS[tot.anchor] or OFFSETS.CENTER
		local right = rootWidth * point[1] + tot.x - w * point[1] + 0 + w
		if rootWidth + x - slot.width >= right + TIGHT then
			foot = DPS["meters.threat"].y + THREAT_H
		end
	end
	out.quests = Card(out.quests, STORY_KEYS.quests, slot.anchor, x, slot.y - offset, slot.width, math.max(0, rh - STORY_TOP - foot - GAP - inset))
	return out
end
end

local LIFTED = {
	"unitframes.player", "unitframes.pet", "unitframes.target", "unitframes.focus", "unitframes.focustarget",
	"unitframes.targettarget", "unitframes.castbar.player", "cooldowns.essential", "cooldowns.utility",
	"cooldowns.buffs", "cooldowns.bars", "meters.threat", "combattext.player", "actionbars.bar3",
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
	["meters.swing"] = { "BOTTOM", 0, 376.5 },
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

do
local PLACES_V30 = {
	["groupframes.party"] = { "TOPLEFT", MARGIN, -MARGIN },
	["minimap.main"] = { "TOPRIGHT", -(EDGE - 1), -(EDGE - 1 + MAP_HEADING) },
	["auras.buffs"] = { "TOPRIGHT", -(EDGE + 188 + 10.9), -RAIL_EDGE },
	["auras.debuffs"] = { "TOPRIGHT", -(EDGE + 188 + 10.9), -67.9 },
	["databars.xp"] = { "BOTTOM", 0, 40 * MOCK_PX - TRAY_STRIP_GAP - 5, COLUMN, 5 },
}

function Layouts.PlaceMoves()
	local out = {}
	for key, place in pairs(PLACES_V30) do
		out[key] = { place[1], place[2], place[3], place[4], place[5] }
	end
	return out
end
end

do
	local RAILS_V33 = {
		places = {
			["meters.threat"] = { "BOTTOM", 357, 433 },
			["cooldowns.buffs"] = { "BOTTOM", -442.8, 186.9 },
			["combattext.player"] = { "BOTTOM", 376, 587 },
			["cooldowns.bars"] = { "BOTTOM", -480, 371 },
			["auras.buffs"] = { "TOPRIGHT", -219.9, -18.4 },
			["auras.debuffs"] = { "TOPRIGHT", -219.9, -67.9 },
		},
		sizes = {
			["chat.main"] = { { 393, 186 } },
		},
	}

	function Layouts.RailMoves()
		local out = { places = {}, sizes = {} }
		for key, place in pairs(RAILS_V33.places) do
			out.places[key] = { place[1], place[2], place[3] }
		end
		for key, list in pairs(RAILS_V33.sizes) do
			out.sizes[key] = {}
			for i, size in ipairs(list) do
				out.sizes[key][i] = { size[1], size[2] }
			end
		end
		return out
	end
end

function Layouts.HealerMoves()
	local out = {}
	for key, place in pairs(HEALER_OLD) do
		out[key] = { place[1], place[2], place[3] }
	end
	return out
end

function Layouts.SwingMoves()
	return { ["meters.swing"] = { "BOTTOM", 0, 376.5 + LIFT } }
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
	local moved = Layouts.RailMoves().places
	local function lift(key)
		local now = layout[key]
		local was = moved[key]
		if was then
			out[key] = { was[1], was[2], was[3] - math.ceil(TRAY_TOP - TIGHT - 132) }
		elseif now then
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

function Layouts.ThirdBarFinished()
	if not ns.Store or not ns.Store.IsLoaded() then return true end
	local cfg = ns.Store.Module("ActionBars").bar3
	return type(cfg) ~= "table" or cfg.finished ~= false
end

function Layouts.LegacyThirdBar()
	return { anchor = "BOTTOMLEFT", x = 17, y = 462.5 }
end

function Layouts.Default(key)
	if key == "actionbars.bar3" and not Layouts.ThirdBarFinished() then return Layouts.LegacyThirdBar() end
	local position = layouts.DPS[key]
	if not position then
		error("KstyleUI.Setup.Layouts.Default: unknown element key " .. tostring(key), 2)
	end
	return copy(position)
end

Layouts.MAP_FRAME = MAP_FRAME
Layouts.GAP = GAP
Layouts.METER_SLOT = 180
Layouts.BOSS_AURAS = byKey["unitframes.boss"].reserve[1] - byKey["unitframes.boss"].width
Layouts.SPLIT_GAP = 198.55

function Layouts.DataBarBelowDock(name, key, class, style)
	style = style or ns.HudStyle.Current()
	return style == "medallions" and (key == "databars.rep" or key == "databars.honor") and Layouts.DataBarDock(name, class, style)
end

function Layouts.Style(name, key, style)
	style = style or ns.HudStyle.Current()
	if style == "medallions" and (key == "meters.damage" or key == "meters.threat") and ns.Store.IsLoaded() and ns.Store.Layout()["medallions:" .. key] then
		return layouts[name] and layouts[name][key]
	end
	if style == "medallions" and key == "minimap.main" and Layouts.MinimapCrest() then
		local overhang = Layouts.CREST_GROW / 2 + ns.Scale.Pixel(1)
		return { anchor = "TOPRIGHT", x = -(EDGE + overhang), y = -(EDGE + overhang + 20) }
	end
	local extra = style == "medallions" and key ~= "chat.main" and key ~= "qol.lootfeed" and key ~= "unitframes.resource" and Layouts.ExtraBarsPlace(ns.Scale.Aspect(), name, key)
	if extra then return extra end
	if key == "databars.strip" and style == "medallions" then
		local dock = Layouts.DataBarDock(name, ns.Scale.Aspect(), style)
		if dock then return dock end
		local position = layouts[name][key]
		return { anchor = position.anchor, x = position.x, y = position.y, width = STORY_W, height = READOUT_H }
	end
	local bar = (key == "actionbars.bar1" or key == "actionbars.bar2" or key == "databars.xp") and Layouts.ActionBarPlace(ns.Scale.Aspect(), name, key, style)
	if bar then return bar end
	if style == "medallions" and key == "combattext.player" and ns.Store.IsLoaded() and ns.Store.Defaults("CombatText")
		and ns.Store.Module("CombatText").clearLanes == false then
		return
	end
	if key == "actionbars.bar3" and not Layouts.ThirdBarFinished() then return Layouts.LegacyThirdBar() end
	if not STYLES[style] then return nil end
	local attached = Layouts.Attached(name, key, ns.Scale.Aspect(), style)
	if attached then
		return attached
	end
	local set = STYLES[style][name]
	local position = set and set[key]
	if position then
		local drop = Layouts.DataBarBelowDock(name, key, nil, style) and 15 or 0
		return { anchor = position.anchor, x = position.x, y = position.y - drop, scale = position.scale, width = position.width, height = position.height }
	end
end

local ASPECTS = ns.Scale.ASPECTS
local PLACES = {}
for _, class in ipairs(ASPECTS) do
	PLACES[class] = { frames = {}, medallions = {} }
end
Layouts.ASPECTS, Layouts.PLACES = ASPECTS, PLACES

Layouts.MEDALLIONS_RING, Layouts.MEDALLIONS_HUB_GAP = 150, 158
Layouts.MEDALLIONS_SLOT = { size = 42, gap = 5, narrowGap = 3.5, floor = 33, [ASPECTS[1]] = 33.5 }
Layouts.MEDALLIONS_SIDE = { rows = 2, gap = 4, pad = 6, clear = 8 }
Layouts.MEDALLIONS_SLAB = { pad = 9, stripGap = 7, strip = 3, bottom = 3 }
Layouts.MEDALLIONS_UNITS = { frame = { 300, 58 }, mini = { 170, 34 }, cast = { 300, 20 }, lift = 26, reach = 12, medal = 86 + GAP, outboard = 12, stack = 46, castGap = 27, castStack = 9, powerReserve = 22 }
Layouts.MEDALLIONS_MEDALS = { ["unitframes.player"] = { side = -1, d = 86 }, ["unitframes.target"] = { side = 1, d = 86 }, ["unitframes.pet"] = { side = -1, d = 56 } }

function Layouts.MedallionsGroup(class)
	local slot = Layouts.MEDALLIONS_SLOT
	local size = slot[class] or slot.size
	local gap, columns = (slot[class] and slot.narrowGap or slot.gap) * size / slot.size, GRIDS["actionbars.bar1"].buttons
	return columns, 1, columns * size + (columns - 1) * gap, size, size, gap
end

function Layouts.ExtraBarsPreset(kind, class)
	if kind ~= "rows" and kind ~= "beside" then return end
	local _, _, size, gap = Layouts.ActionBarGrid(class, "actionbars.bar1", nil, "medallions")
	if kind == "beside" then size, gap = size * 0.75, gap * 0.75 end
	return { enabled = true, buttons = kind == "rows" and 12 or 8, rows = kind == "rows" and 1 or 2,
		size = size, spacing = gap, orientation = "HORIZONTAL", growth = "RIGHTDOWN", split = "off", showEmpty = true, backing = false }
end

Layouts.EXTRA_BAR_GROUPS = {
	["actionbars.bar4"] = "bars", ["actionbars.bar5"] = "bars",
	["unitframes.player"] = "units", ["unitframes.target"] = "units", ["unitframes.pet"] = "units",
	["unitframes.targettarget"] = "units", ["unitframes.focus"] = "units", ["unitframes.focustarget"] = "units",
	["unitframes.castbar.player"] = "casts", ["unitframes.castbar.target"] = "casts", ["combattext.player"] = "casts", ["unitframes.resource"] = "casts",
	["actionbars.pet"] = "sides", ["actionbars.stance"] = "sides", ["actionbars.bar3"] = "third", ["chat.main"] = "chat", ["qol.lootfeed"] = "chat",
}

function Layouts.ExtraBarsPlace(class, name, key)
	local group = Layouts.EXTRA_BAR_GROUPS[key]
	if not group then return end
	local kind = ns.Store.IsLoaded() and (ns.Store.Profile().ActionBars or {}).extraBarsApplied
	if kind ~= "rows" and kind ~= "beside" then return end
	if group == "third" then
		if kind == "beside" and class == ASPECTS[1] then return { anchor = "BOTTOM", x = -800, y = 470 } end
		return
	end
	local places = PLACES[class] and PLACES[class].medallions or {}
	local function Base(id) return places[id] or STYLES.medallions[name][id] or layouts[name][id] end
	local left, right = Base("actionbars.bar1"), Base("actionbars.bar2")
	local width, height = Layouts.ActionBarFootprint(class, "actionbars.bar1", "medallions")
	local _, _, _, gap = Layouts.ActionBarGrid(class, "actionbars.bar1", nil, "medallions")
	local slab, side = Layouts.MEDALLIONS_SLAB, Layouts.MEDALLIONS_SIDE
	if group == "bars" then
		local parent = key == "actionbars.bar4" and left or right
		local w, h = Layouts.ActionBarFootprint(class, key, "medallions")
		if kind == "rows" then return { anchor = "BOTTOM", x = parent.x, y = parent.y + height + gap } end
		local sign = key == "actionbars.bar4" and -1 or 1
		return { anchor = "BOTTOM", x = parent.x + sign * (width / 2 + 2 * slab.pad + gap + w / 2), y = parent.y + height - h }
	end
	local base = Base(key)
	if kind == "rows" and group == "units" then
		return { anchor = base.anchor, x = base.x, y = base.y + height + gap + 2, width = base.width, height = base.height }
	elseif kind == "rows" and group == "casts" then
		return { anchor = base.anchor, x = base.x, y = base.y + height + gap, width = base.width, height = base.height }
	elseif kind == "beside" and group == "sides" then
		local _, h = Layouts.ActionBarFootprint(class, "actionbars.bar5", "medallions")
		if class == ASPECTS[1] then
			local lift = math.max(h + side.pad, left.y + height + slab.pad + gap - layouts[name]["chat.main"].y)
			return { anchor = base.anchor, x = base.x - 12, y = base.y + lift }
		end
		return { anchor = base.anchor, x = base.x, y = base.y + h + side.pad }
	elseif kind == "beside" and class == ASPECTS[1] and group == "chat" then
		local chat = layouts[name]["chat.main"]
		local lift = math.max(0, left.y + height + slab.pad + gap - chat.y)
		return { anchor = base.anchor, x = base.x, y = base.y + lift }
	end
end

function Layouts.MedallionsSide(_, key)
	local grid, side = GRIDS[key], Layouts.MEDALLIONS_SIDE
	local columns = math.ceil(grid.buttons / side.rows)
	return side.rows, columns * grid.size + (columns - 1) * side.gap, side.rows * grid.size + (side.rows - 1) * side.gap
end

function Layouts.ActionBarPlace(class, name, key, style)
	style = style or ns.HudStyle.Current()
	if style ~= "medallions" or not (key == "actionbars.bar1" or key == "actionbars.bar2" or key == "databars.xp") then return end
	local bars = ns.Store.IsLoaded() and ns.Store.Module("ActionBars") or {}
	if bars.slab == false then return end
	local leftBar, rightBar = bars.bar1 or {}, bars.bar2 or {}
	if (leftBar.buttons or 12) == 12 and (rightBar.buttons or 12) == 12 and (leftBar.size or TRAY_BUTTON) == TRAY_BUTTON then return end
	local place = PLACES[class] and PLACES[class].medallions[key] or STYLES[style][name] and STYLES[style][name][key]
	if not place then return end
	local left = Layouts.ActionBarFootprint(class, "actionbars.bar1", style)
	local right = Layouts.ActionBarFootprint(class, "actionbars.bar2", style)
	local hub = Layouts.MEDALLIONS_HUB_GAP
	local x = key == "actionbars.bar1" and -(hub + left) / 2 or (hub + right) / 2
	if key == "databars.xp" then return { anchor = place.anchor, x = (right - left) / 2, y = place.y, width = left + right + hub, height = place.height } end
	return { anchor = place.anchor, x = x, y = place.y }
end

function Layouts.StyleSize(class, key, style)
	if key == "consumables.bar" then return Layouts.ConsumableFootprint(class, style) end
	if GRIDS[key] then return Layouts.ActionBarFootprint(class, key, style) end
end

function Layouts.BuildMedallions()
	Layouts.MEDALLIONS_UNITS.castGap = ns.Appearance.Readability("readableBars") and 27 or 22
	Layouts.MEDALLIONS_UNITS.castStack = ns.Appearance.Readability("readableBars") and 9 or 6
	local hub, slab = Layouts.MEDALLIONS_HUB_GAP, Layouts.MEDALLIONS_SLAB
	local unit = Layouts.MEDALLIONS_UNITS
	local sets = {}
	for _, class in ipairs(ASPECTS) do
		local _, _, width, height = Layouts.MedallionsGroup(class)
		local baseline = math.max(TRAY_BAR1_Y, EDGE + Layouts.MEDALLIONS_RING / 2 + 6 - height)
		local top, strip = baseline + height, baseline - slab.stripGap - slab.strip
		local side = Layouts.MEDALLIONS_SIDE
		local ends = hub / 2 + width + slab.pad + side.clear + side.pad
		local _, petW, petH = Layouts.MedallionsSide(class, "actionbars.pet")
		local sideY = strip - slab.bottom + side.pad - 2 * TIGHT
		if class == ASPECTS[1] then sideY = DPS["meters.damage"].y + DAMAGE_H + GAP + 3 * side.pad end
		local petBar = { anchor = "BOTTOM", x = -(ends + petW / 2 - (class == ASPECTS[1] and petH - GAP - TIGHT + side.pad + 1 or 0)), y = sideY }
		local stanceBar = { anchor = "BOTTOM", x = petBar.x, y = sideY + petH + 2 * side.pad + side.clear }
		local frame, tot, pet, cast = unit.frame, unit.mini, unit.mini, unit.cast
		local focus, boss = layouts.DPS["unitframes.focus"], layouts.DPS["unitframes.boss"]
		local focusSize = { 220 * MOCK_PX, 64 * MOCK_PX }
		local focusY = math.max(focus.y, layouts.DPS["cooldowns.bars"].y + math.max(select(2, ElementSize("cooldowns.bars")), select(2, ElementSize("cooldowns.buffs"))) + NEAR + 3 * TIGHT + tot[2])
		local row, reach = top + slab.pad + unit.lift, Layouts.MEDALLIONS_RING / 2 + unit.reach
		local castY = top + Layouts.MEDALLIONS_RING / 2 + unit.castGap
		local petX, miniY = reach + frame[1] + unit.medal + unit.outboard + pet[1] / 2, row + (frame[2] - pet[2]) / 2 + 2 * TIGHT
		if class == ASPECTS[1] then
			petX, miniY = reach + frame[1] - pet[1] / 2, row + frame[2] + unit.stack + 96
		end
		petX = math.min(petX, -stanceBar.x - petW / 2 - side.pad - GAP - pet[1] / 2 - Layouts.MEDALLIONS_MEDALS["unitframes.pet"].d / 2)
		local totX = petX
		local function At(anchor, x, y, size)
			return { anchor = anchor, x = x, y = y, width = size[1], height = size[2] }
		end
		sets[class] = {
			["minimap.main"] = { anchor = "TOPRIGHT", x = -(EDGE + 10), y = -(EDGE + 30) },
			["auras.buffs"] = { anchor = "TOPRIGHT", x = -(AURAS_X + 16), y = -RAIL_EDGE },
			["auras.debuffs"] = { anchor = "TOPRIGHT", x = -(AURAS_X + 16), y = -DEBUFFS_Y },
			["auras.extraBuffs"] = { anchor = "TOPRIGHT", x = -(AURAS_X + 16), y = DPS["auras.extraBuffs"].y },
			["auras.extraDebuffs"] = { anchor = "TOPRIGHT", x = -(AURAS_X + 16), y = DPS["auras.extraDebuffs"].y },
			["actionbars.bar3"] = { anchor = "BOTTOM", x = -(0.2 * HEIGHT * (ns.Scale.CANVAS[class] or class:match("%d+") / 9) + GridSize("actionbars.bar3") / 2 + slab.pad + side.clear), y = 378 + side.clear },
			["actionbars.bar1"] = { anchor = "BOTTOM", x = -(hub / 2 + width / 2), y = baseline },
			["actionbars.bar2"] = { anchor = "BOTTOM", x = hub / 2 + width / 2, y = baseline },
			["actionbars.pet"] = petBar,
			["actionbars.stance"] = stanceBar,
			["databars.xp"] = At("BOTTOM", 0, strip, { 2 * width + hub, slab.strip }),
			["databars.rep"] = { anchor = "BOTTOM", x = -220, y = DPS["databars.rep"].y },
			["databars.honor"] = { anchor = "BOTTOM", x = 220, y = DPS["databars.honor"].y },
			["unitframes.player"] = At("BOTTOM", -(reach + frame[1] / 2), row, frame),
			["unitframes.target"] = At("BOTTOM", reach + frame[1] / 2, row, frame),
			["unitframes.targettarget"] = At("BOTTOM", totX, miniY, tot),
			["unitframes.resource"] = At("BOTTOM", 0, castY - 22, { 120, 14 }),
			["unitframes.castbar.player"] = At("BOTTOM", 0, castY, cast),
			["unitframes.castbar.target"] = At("BOTTOM", 0, castY + cast[2] + unit.castStack, cast),
			["combattext.player"] = At("BOTTOM", 0, castY + 410, { 160, 80 }),
			["unitframes.pet"] = At("BOTTOM", -petX, miniY, pet),
			["unitframes.focus"] = At(focus.anchor, focus.x, focusY, focusSize),
			["unitframes.focustarget"] = At(focus.anchor, focus.x - (focusSize[1] - tot[1]) / 2, focusY - TIGHT - tot[2], tot),
			["unitframes.boss"] = At(boss.anchor, boss.x - 2 * GAP, boss.y - 24, { 280 * MOCK_PX, (5 * 60 + 24) * MOCK_PX }),
		}
		for key, medal in pairs(Layouts.MEDALLIONS_MEDALS) do
			local place = sets[class][key]
			place.insets = { medal.side < 0 and medal.d + ns.Tokens.Size("gapMedium") or 2, medal.side > 0 and medal.d + ns.Tokens.Size("gapMedium") or 2, unit.powerReserve, (medal.d - place.height) / 2 + ns.Tokens.Size("gapMedium") }
		end
		sets[class]["unitframes.boss"].insets = { 2, 40, 12, 12 }
	end
	for _, name in ipairs(NAMES) do
		STYLES.medallions[name] = {}
		for key, place in pairs(sets[ASPECTS[1]]) do
			if key ~= "unitframes.resource" then STYLES.medallions[name][key] = place end
		end
	end
	for _, class in ipairs(ASPECTS) do
		for key, place in pairs(sets[class]) do
			if class ~= ASPECTS[1] or key == "unitframes.resource" then PLACES[class].medallions[key] = place end
		end
	end
end
Layouts.BuildMedallions()

function Layouts.DisplayInsets(key, height, anchor)
	local element = byKey[key]
	local style, name, class = ns.HudStyle.Current(), ns.Layout.Setting("preset"), ns.Scale.Aspect()
	local place = PLACES[class] and PLACES[class][style] and PLACES[class][style][key]
	place = place or STYLES[style] and STYLES[style][name] and STYLES[style][name][key]
	local inset = place and place.insets or element.insets
	local l, r, b, t = inset and inset[1] or 0, inset and inset[2] or 0, inset and inset[3] or 0, inset and inset[4] or 0
	if Layouts.DataBarBelowDock(name, key, class, style) then b = math.max(0, b - 15) end
	if place and place.height then t = math.max(0, t + (place.height - height) / 2) end
	local reserve = not (place and place.width) and element.reserve
	if reserve then
		local fx, fy = ns.Layout.Geometry.Fraction(anchor)
		local ew, eh = math.max(0, reserve[1] - element.width), math.max(0, reserve[2] - element.height)
		l, r = math.max(l, ew * fx - (reserve[3] or 0)), math.max(r, ew * (1 - fx) + (reserve[3] or 0))
		b, t = math.max(b, eh * fy - (reserve[4] or 0)), math.max(t, eh * (1 - fy) + (reserve[4] or 0))
	end
	return l, r, b, t
end

function Layouts.RailStack(class, name, key)
	local bars = ns.Store.IsLoaded() and ns.Store.Module("ActionBars")
	local base = layouts[name] and layouts[name]["actionbars.bar4"]
	if not (bars and base) or bars.extraBarsApplied ~= "rows" and bars.extraBarsApplied ~= "beside" then return end
	local w4, h4 = Layouts.ActionBarFootprint(class, "actionbars.bar4", "frames")
	local w5, h5 = Layouts.ActionBarFootprint(class, "actionbars.bar5", "frames")
	if bars.bar4.enabled == false then w4, h4 = 0, -RAIL_PITCH end
	local y = base.y
	if math.max(w4, w5) > 3 * RAIL_COLUMN - RAIL_PITCH then y = math.max(y, y + RAIL_BARS_H - h4 - RAIL_PITCH - h5) end
	if key == "actionbars.bar5" then y = y + h4 + RAIL_PITCH end
	return { anchor = base.anchor, x = base.x, y = y }
end

function Layouts.Aspect(class, style, name, key)
	if key == "unitframes.resource" and (style == "medallions" or style == "frames" and ns.HudStyle.Current() == "medallions") then
		return Layouts.ExtraBarsPlace(class, name, key) or PLACES[class].medallions[key] or STYLES.medallions[name][key]
	end
	if key == STORY_KEYS.quests and (style == "medallions" or style == "frames" and ns.HudStyle and ns.HudStyle.Current() == "medallions") then
		local slot = slots[name]
		return { anchor = slot.anchor, x = slot.x - slot.width - GAP, y = slot.y - GAP - (Layouts.MinimapCrest() and (ns.Store.Module("Minimap").frame == "ring" and 36 or 26) or 0) }
	end
	if (key == "minimap.main" or key:match("^auras%."))
		and (style == "medallions" or style == "frames" and ns.HudStyle and ns.HudStyle.Current() == "medallions") and Layouts.MinimapCrest() then
		if style == "medallions" and key == "minimap.main" then return Layouts.Style(name, key, style) end
		local base = key:match("^auras%.") and layouts[name][key]
		if base then
			return { anchor = base.anchor, x = base.x - math.ceil(Layouts.CREST_GROW - AURA_MAP_GAP), y = base.y }
		end
	end
	local extra = style == "medallions" and Layouts.ExtraBarsPlace(class, name, key)
	if extra then return extra end
	if style == "frames" and (key == "actionbars.bar4" or key == "actionbars.bar5") then
		local stacked = Layouts.RailStack(class, name, key)
		if stacked then return stacked end
	end
	local bar = (key == "actionbars.bar1" or key == "actionbars.bar2" or key == "databars.xp") and Layouts.ActionBarPlace(class, name, key, style)
	if bar then return bar end
	if key == "actionbars.bar3" and not Layouts.ThirdBarFinished() then return Layouts.LegacyThirdBar() end
	local attached = Layouts.Attached(name, key, class, style)
	if attached then
		return attached
	end
	local styled = style ~= "frames" and Layouts.Style(name, key, style) ~= nil
	local set = PLACES[class] and PLACES[class][styled and style or "frames"]
	local position = set and set[key]
	if position and position.anchor and position.x and position.y then
		local place = copy(position)
		place.width, place.height = position.width, position.height
		if Layouts.DataBarBelowDock(name, key, class, style) then place.y = place.y - 15 end
		return place
	end
end

function Layouts.Attached(name, key, class, style)
	style = style or ns.HudStyle.Current()
	if not layouts[name] or not byKey[key] or not (style == "frames" or STYLES[style]) then return nil end
	if key == "consumables.bar" then
		local w, h = Layouts.ConsumableFootprint(class, style)
		local player = Layouts.Aspect(class, style, name, "unitframes.player") or Layouts.Style(name, "unitframes.player", style) or layouts[name]["unitframes.player"]
		local pw, ph = player.width or COLUMN, player.height or 77.5
		local reserve = style == "medallions" and 43 or 131.5
		local x, y = player.x - pw / 2 - reserve - 8 - w / 2, math.max(219, player.y + (ph - h) / 2)
		if style == "medallions" then
			y = player.y + ph + Layouts.MEDALLIONS_UNITS.stack + Layouts.MEDALLIONS_UNITS.mini[2] + (class == "16:9" and 158 or 22) - h
			if class ~= "16:9" then
				if ns.Store.IsLoaded() and ns.Store.Module("ActionBars").extraBarsApplied == "beside" then y = y + 72 end
			else
				local third = ns.Store.IsLoaded() and ns.Store.Module("ActionBars").bar3
				if third and third.enabled then x, y = -480, player.y + 447 end
			end
		end
		return { anchor = "BOTTOM", x = x, y = y, width = w, height = h }
	end
	local cooldown = key:match("^cooldowns%.") ~= nil
	local swing = key == "meters.swing"
	if not (cooldown or swing) then return nil end
	local store = ns.Store
	local on = not (store and store.IsLoaded()) or store.Module(cooldown and "Cooldowns" or "Meters")[cooldown and "attached" or "swing"]
	if not cooldown and type(on) == "table" then on = on.attached end
	if on == false then
		local old = Layouts.Previous(style, name, key, class)
		return { anchor = old.anchor, x = old.x, y = old.y, width = swing and 260 or nil, height = swing and 8 or nil }
	end
	local places = STYLES[style] and STYLES[style][name] or layouts[name]
	local cast = PLACES[class] and PLACES[class][style] and PLACES[class][style]["unitframes.castbar.player"] or places["unitframes.castbar.player"]
	local x, y = 0
	if style == "medallions" then
		local player = Layouts.ExtraBarsPlace(class, name, "unitframes.player") or PLACES[class] and PLACES[class][style]["unitframes.player"] or places["unitframes.player"]
		local base = player.y + player.height + Layouts.MEDALLIONS_UNITS.stack + Layouts.MEDALLIONS_UNITS.mini[2] + 24
		cast = Layouts.ExtraBarsPlace(class, name, "unitframes.castbar.player") or cast
		y = cast.y + 2 * (cast.height or Layouts.MEDALLIONS_UNITS.cast[2]) + Layouts.MEDALLIONS_UNITS.castStack + 8 + (key == "cooldowns.buffs" and 192 or key == "cooldowns.utility" and 96 or 0)
		if key == "cooldowns.bars" then x, y = 300, base + 2 * (CENTRE_BUTTON + CENTRE_GAP) + 8 end
		if swing then
			y = base + 4
			x = -((cast.width or 300) / 2 + 220 / 2 + 8)
		end
	else
		y = cast.y - CENTRE_BUTTON - 12
		if key == "cooldowns.utility" then x = (12 * CENTRE_BUTTON + 11 * CENTRE_GAP + UTILITY) / 2 + 8 end
		if key == "cooldowns.buffs" then x = -(12 * CENTRE_BUTTON + 11 * CENTRE_GAP + 182.6) / 2 - 8 end
		if key == "cooldowns.bars" then x = -(12 * CENTRE_BUTTON + 11 * CENTRE_GAP + TRACKED) / 2 - 182.6 - 64 end
		if swing then
			y = layouts[name]["unitframes.resource"].y + 14 + 8
		end
	end
	local width, height
	if swing then
		width, height = style == "medallions" and 220 or 260, 14
	end
	return { anchor = "BOTTOM", x = x, y = y, width = width, height = height }
end

function Layouts.Previous(style, name, key, class)
	local specific = PLACES[class] and PLACES[class][style] and PLACES[class][style][key]
	local themed = STYLES[style] and STYLES[style][name] and STYLES[style][name][key]
	local place = specific or themed or layouts[name][key]
	return { anchor = place.anchor, x = place.x, y = place.y, width = place.width, height = place.height }
end

ns.Callbacks.Register("SettingChanged", "AttachedHUD", function(_, module, key)
	if not (module == "Cooldowns" and key == "attached" or module == "Meters" and key == "swing.attached" or module == "Minimap" and (key == "frame" or key == "enabled")) then return end
	ns.Combat.Queue(function()
		for _, element in ipairs(ELEMENTS) do
			if element.key:match("^cooldowns%.") or element.key == "meters.swing" then
				local el = ns.Layout.Element(element.key)
				if el then ns.Layout.Register(el.frame, el.key, el.base, el.opts) end
			end
		end
		if module == "Minimap" then
			KstyleUIDB.scaleCache = nil
			for _, affected in ipairs({ "minimap.main", "auras.buffs", "auras.debuffs", "auras.extraBuffs", "auras.extraDebuffs", STORY_KEYS.quests }) do
				local el = ns.Layout.Element(affected)
				if el then ns.Layout.Register(el.frame, el.key, el.base, el.opts) end
			end
			ns.Widgets.RestyleAll()
		end
		local name = ns.Layout.Setting("preset")
		if Setup.EditMode and Setup.EditMode.ActiveName() == name then
			Setup.EditMode.Restyle(name, Setup.Story(name, Setup.GuideLoaded()))
		end
	end)
end)

do
local BANDED = { ["groupframes.party"] = true, ["groupframes.raid"] = true, ["unitframes.boss"] = true, ["actionbars.possess"] = true, [STORY_KEYS.guide] = true }
local SIDES = { TOPLEFT = 1, LEFT = 1, BOTTOMLEFT = 1, TOPRIGHT = -1, RIGHT = -1, BOTTOMRIGHT = -1 }

function Layouts.Band(key, anchor, x, band)
	if not BANDED[key] or type(band) ~= "number" or type(x) ~= "number" then
		return x
	end
	return x + (SIDES[anchor] or 0) * band
end
end

function Layouts.BarLift(class, key, style)
	style = style or ns.HudStyle.Current()
	local above = key ~= "unitframes.boss" and (key:match("^unitframes%.") or key:match("^cooldowns%.") or key == "meters.swing" or key == "combattext.player")
	if not (above or key == "actionbars.bar2" and style ~= "medallions") then return 0 end
	local function Extra(bar)
		local count, rows, size, gap, _, cfg = Layouts.ActionBarGrid(class, bar, nil, style)
		if cfg.enabled == false then return 0 end
		rows = math.ceil(count / math.ceil(count / math.min(count, math.max(1, math.floor(rows)))))
		return (rows - 1) * (size + gap)
	end
	local first, second = Extra("actionbars.bar1"), Extra("actionbars.bar2")
	if style == "medallions" then return math.max(first, second) end
	return above and first + second or first
end

function Layouts.LiftSetting(module, key)
	local field = module == "ActionBars" and key:match("^bar[12]%.(.+)$")
	return module == "ActionBars" and (key == "slab" or field == "rows" or field == "buttons" or field == "size" or field == "spacing" or field == "enabled") or false
end

function Layouts.Place(name, style, class, key, band)
	local base = layouts[name] and layouts[name][key]
	if not base then
		return nil
	end
	local place = Layouts.Aspect(class, style, name, key) or Layouts.Style(name, key, style) or base
	return { anchor = place.anchor, x = Layouts.Band(key, place.anchor, place.x, band), y = place.y + Layouts.BarLift(class, key, style) }
end

function Layouts.Positions(name, style, class, band)
	local out = Layouts.Get(name)
	for key, position in pairs(out or {}) do
		local place = Layouts.Place(name, style, class, key, band)
		position.anchor, position.x, position.y = place.anchor, place.x, place.y
	end
	if out and Layouts.DataBarHeight(style) then out["databars.strip"] = { anchor = "TOP", x = 0, y = 0 } end
	local dock = out and Layouts.DataBarDock(name, class, style)
	if dock then out["databars.strip"] = dock end
	return out
end

function Layouts.StyleKeys(name, style)
	style = style or ns.HudStyle.Current()
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

function Layouts.DataBarDock(name, class, style)
	style = style or (ns.HudStyle and ns.HudStyle.Current() or "frames")
	local strip = ns.Store.IsLoaded() and ns.Store.Module("DataBars").strip
	if not strip or strip.enabled == false then return nil end
	if strip.placement ~= "dock" and not (style == "medallions" and strip.placement == "top") then return nil end
	name = name or ns.Layout.Setting("preset")
	local xp = Layouts.Aspect(class or ns.Scale.Aspect(), style, name, "databars.xp") or Layouts.Style(name, "databars.xp", style) or layouts[name]["databars.xp"]
	return { anchor = xp.anchor, x = xp.x, y = xp.y - 15, width = xp.width or COLUMN, height = 12 }
end

function Layouts.DataBarHeight(style)
	style = style or (ns.HudStyle and ns.HudStyle.Current() or "frames")
	if style == "medallions" then return nil end
	local bars = ns.Store.IsLoaded() and ns.Store.Module("DataBars") or {}
	local strip = bars.strip or {}
	if strip.placement == "rail" or strip.placement == "dock" then return nil end
	local height = strip.height
	if type(height) ~= "number" or height ~= height then height = 14 end
	return math.max(12, math.min(32, height))
end

function Layouts.DataBarPosition(style)
	local saved = ns.Store.IsLoaded() and ns.Store.Layout() or {}
	local entry = saved[(style or (ns.HudStyle and ns.HudStyle.Current() or "frames")) .. ":databars.strip"] or saved["databars.strip"] or {}
	local position = { anchor = entry.anchor or "TOP", x = entry.x or 0, y = entry.y or 0, height = entry.height, width = entry.width, shown = entry.shown }
	if type(position.x) == "number" and math.abs(position.x) < 1e-6 then position.x = 0 end
	if type(position.y) == "number" and math.abs(position.y) < 1e-6 then position.y = 0 end
	return position
end

function Layouts.TopInset(style, enabled, position)
	local height = Layouts.DataBarHeight(style)
	if not height then return 0 end
	local bars = ns.Store.IsLoaded() and ns.Store.Module("DataBars") or {}
	if enabled then
		if enabled["databars.strip"] == false then return 0 end
	elseif bars.enabled ~= true or (bars.strip or {}).enabled == false then
		return 0
	end
	position = position or Layouts.DataBarPosition(style)
	if position.anchor ~= "TOP" or math.abs(position.x) >= 1e-6 or math.abs(position.y) >= 1e-6 or position.shown == "never" then return 0 end
	height = position.height or height
	return height <= 14 and 0 or math.max(0, height + 6 - 16)
end

function Layouts.Rect(element, position, rootWidth, rootHeight, style)
	local point = OFFSETS[position.anchor] or OFFSETS.CENTER
	local fx, fy = point[1], point[2]
	local width, height = element.width, element.height
	if element.key == "databars.strip" then
		local dock = Layouts.DataBarDock(nil, nil, style)
		if dock then width, height = position.width or dock.width, position.height or dock.height end
	end
	if element.key == "databars.strip" and Layouts.DataBarHeight(style) then
		width, height = position.width or rootWidth, position.height or Layouts.DataBarHeight(style)
	end
	local left = rootWidth * fx + position.x - width * fx + (element.offsetX or 0)
	local inset = element.key ~= "databars.strip" and position.anchor:match("^TOP") and Layouts.TopInset(style) or 0
	local bottom = rootHeight * fy + position.y - inset - height * fy + (element.offsetY or 0)
	return left, bottom, left + width, bottom + height
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
				local entry = section[key == "consumables.bar" and "consumables" or cast or id]
				if element.module == "Meters" and (id == "damage" or id == "threat") and section.followRole then
					local role = ns.Specialization.Role()
					local choice = section.roles and section.roles[role] or (role == "TANK" and "threat" or "damage")
					on = choice == "both" or choice == id
				elseif key == "databars.strip2" then
					on = type(section.strip) == "table" and section.strip.second == true
				elseif cast then
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
				if element.module == "Meters" and id == "damage" and type(entry) == "table" and entry.mode == "skin" then on = false end
			end
		end
		enabled[key] = on
	end
	local meters = profile and profile.Meters
	enabled["meters.damage2"] = type(meters) == "table" and type(meters.damage2) == "table" and meters.damage2.shown == true or nil
	return enabled
end

local function Apart(a, b)
	local other = a == "groupframes.raid" and b or b == "groupframes.raid" and a
	if other == "groupframes.party" or other == STORY_KEYS.guide then
		return false
	end
	if DOCKS[a] == b or DOCKS[b] == a then
		return false
	end
	return true
end

do
function Layouts.PrepareFits(name, physicalWidth, physicalHeight, enabled, positions, search, style)
	style = style or ns.HudStyle.Current()
	local class = ns.Scale.AspectClass(physicalWidth, physicalHeight)
	local layout = positions or Layouts.Positions(name, style, class)
	if not positions and layout and Layouts.DataBarHeight(style) then layout["databars.strip"] = Layouts.DataBarPosition(style) end
	if not layout then
		return nil
	end
	local paired = enabled["meters.damage"] ~= false and enabled["meters.threat"] ~= false and not enabled["meters.damage2"]
	if paired then
		local damage = layout["meters.damage"]
		layout["meters.threat"] = { anchor = damage.anchor, x = damage.x - DAMAGE_W - GAP, y = damage.y }
	end
	local state = { layout = layout, sizes = {}, positions = layout, rects = {}, boxes = { {}, {} }, story = { value = { guide = {}, quests = {} } }, span = HEIGHT }
	state.inset = Layouts.TopInset(style, enabled, layout["databars.strip"])
	state.stripHeight = enabled["databars.strip"] ~= false and Layouts.DataBarHeight(style) or nil
	if state.inset ~= 0 then
		state.positions = {}
		for key, position in pairs(layout) do
			state.positions[key] = position
			if key ~= "databars.strip" and position.anchor:match("^TOP") then
				state.positions[key] = { anchor = position.anchor, x = position.x, y = position.y - state.inset }
			end
		end
	end
	state.crest = style == "medallions" and Layouts.MinimapCrest()
	local bars = ns.Store.IsLoaded() and ns.Store.Module("ActionBars") or {}
	for i, element in ipairs(ELEMENTS) do
		local key = element.key
		if state.stripHeight and key == "databars.strip" then state.stripIndex = i end
		local width, height, offsetX, offsetY = Layouts.Footprint(name, key, class, style, physicalWidth, physicalHeight)
		if search and key ~= "consumables.bar" then
			local position = layout[key]
			state.span = math.max(state.span, math.abs(position.x) + width, math.abs(position.y) + height)
		end
		if key == "actionbars.bar1" then
			state.barWidth, state.barHeight = width, height
		elseif key == "unitframes.targettarget" then
			state.targetWidth = width
		end
		local styled = not GRIDS[key] and style and (Layouts.Aspect(class, style, name, key) or Layouts.Style(name, key, style))
		if styled and styled.width then
			width, height, offsetX, offsetY = styled.width + (key == "unitframes.boss" and Layouts.BOSS_AURAS or 0), styled.height, nil, nil
		end
		if key == "databars.strip" then
			local dock = Layouts.DataBarDock(name, class, style)
			if dock then width, height = dock.width, dock.height end
		end
		if style == "medallions" and key == "unitframes.player" then
			height, offsetY = height + Layouts.MEDALLIONS_UNITS.powerReserve, -Layouts.MEDALLIONS_UNITS.powerReserve
		end
		if style == "medallions" and bars.extraBarsApplied == "beside" and (key == "actionbars.bar4" or key == "actionbars.bar5") then
			local pad, point = Layouts.MEDALLIONS_SLAB.pad, OFFSETS[layout[key].anchor]
			width, height, offsetX, offsetY = width + 2 * pad, height + 2 * pad, (2 * point[1] - 1) * pad, (2 * point[2] - 1) * pad
		elseif bars.slab ~= false and (key == "actionbars.pet" or key == "actionbars.stance") then
			width, offsetX = width + 2 * Layouts.MEDALLIONS_SIDE.pad, (2 * OFFSETS[layout[key].anchor][1] - 1) * Layouts.MEDALLIONS_SIDE.pad
		end
		if key == "meters.threat" and paired then width, height = Layouts.METER_SLOT, DAMAGE_H end
		state.sizes[i] = { width, height, offsetX, offsetY, OFFSETS[layout[key].anchor] or OFFSETS.CENTER, key }
	end
	local rectCount = #ELEMENTS + 2
	for _ in pairs(Layouts.MEDALLIONS_MEDALS) do
		rectCount = rectCount + 1
	end
	for i = 1, rectCount do
		state.rects[i] = {}
	end
	local _, groupHeight = Layouts.ActionBarFootprint(class, "actionbars.bar1", "medallions")
	state.hubLift = 0
	if style == "medallions" and bars.extraBarsApplied == "rows" then
		local _, _, _, gap = Layouts.ActionBarGrid(class, "actionbars.bar1", nil, style)
		for _, key in ipairs({ "actionbars.bar4", "actionbars.bar5" }) do
			local base, extra = layout[key == "actionbars.bar4" and "actionbars.bar1" or "actionbars.bar2"], layout[key]
			local w, h = Layouts.ActionBarFootprint(class, key, style)
			local bw = Layouts.ActionBarFootprint(class, key == "actionbars.bar4" and "actionbars.bar1" or "actionbars.bar2", style)
			if enabled[key] ~= false and extra.anchor == "BOTTOM" and base.anchor == "BOTTOM" and math.abs(extra.x - base.x) < 2 and math.abs(w - bw) < 2 and math.abs(extra.y - base.y - groupHeight - gap) < 2 then
				state.hubLift = math.max(state.hubLift, (extra.y + h - base.y) / 2 - groupHeight)
			end
		end
	end
	state.groupHeight = groupHeight + state.hubLift
	state.slab = bars.slab ~= false
	return state
end

function Layouts.FitStory(state, name, physicalWidth, physicalHeight, user, style)
	local rootHeight = 1080 / user
	local rootWidth = physicalWidth / (physicalHeight / rootHeight)
	local memo = state.story
	if memo.rootHeight ~= rootHeight or memo.rootWidth ~= rootWidth then
		memo.value = Layouts.Story(name, rootHeight, true, rootWidth, memo.value, state.targetWidth, state.crest, state.inset, style)
		if state.inset ~= 0 then
			for _, card in pairs(memo.value) do
				if type(card) == "table" and card.anchor:match("^TOP") then card.y = card.y - state.inset end
			end
		end
		memo.rootHeight, memo.rootWidth = rootHeight, rootWidth
	end
	return memo.value
end

function Layouts.Fits(name, physicalWidth, physicalHeight, user, enabled, positions, state, style)
	style = style or ns.HudStyle.Current()
	if not Positive(physicalWidth) or not Positive(physicalHeight) or not Positive(user) then
		return false
	end
	local floor, max, min = math.floor, math.max, math.min
	local rootHeight = 1080 / user
	enabled = enabled or Layouts.Enabled(name)
	state = state or Layouts.PrepareFits(name, physicalWidth, physicalHeight, enabled, positions, nil, style)
	if not state then
		return false
	end
	local layout = state.positions
	local pixelScale = physicalHeight / rootHeight
	if state.stripHeight then
		local size, position = state.sizes[state.stripIndex], layout["databars.strip"]
		size[1], size[2] = position.width or physicalWidth / pixelScale, position.height or state.stripHeight
	end
	local rects, boxes, count = state.rects, state.boxes, 0
	local elements = #ELEMENTS
	local medals = style == "medallions" and Layouts.MEDALLIONS_MEDALS
	local story = Layouts.FitStory(state, name, physicalWidth, physicalHeight, user, style)
	for i = 1, 2 do
		local card = i == 1 and story.guide or story.quests
		if enabled[card.key] ~= false and (card.width <= 0 or card.height < STORY_FLOOR or i == 1 and story.slot < STORY_FLOOR) then
			return false
		end
	end
	for i = 1, elements + 2 do
		local key, width, height, position, offsetX, offsetY, point
		if i <= elements then
			local size = state.sizes[i]
			key = size[6]
			width, height, offsetX, offsetY = size[1], size[2], size[3], size[4]
			point = size[5]
			position = layout[key]
		else
			position = i == elements + 1 and story.guide or story.quests
			key, width, height = position.key, position.width, position.height
			point = OFFSETS[position.anchor] or OFFSETS.CENTER
		end
		if enabled[key] ~= false then
			if width <= 0 or height < STORY_FLOOR and position.key or height <= 0 then
				return false
			end
			local w, h = floor(width * pixelScale + 0.5), floor(height * pixelScale + 0.5)
			if w < 1 then w = 1 end
			if h < 1 then h = 1 end
			local left = floor(physicalWidth * point[1] + position.x * pixelScale - w * point[1] + 0.5) + (offsetX or 0) * pixelScale
			local bottom = floor(physicalHeight * point[2] + position.y * pixelScale - h * point[2] + 0.5) + (offsetY or 0) * pixelScale
			if state.stripHeight and key ~= "databars.strip" and bottom + h <= physicalHeight then
				bottom = min(bottom, floor(physicalHeight - EDGE * pixelScale) - h)
			end
			local box = boxes[1]
			box[1], box[2], box[3], box[4] = left, bottom, left + w, bottom + h
			local medal = medals and medals[key]
			if medal then
				local d = floor(medal.d * pixelScale + 0.5)
				if d <= 0 then return false end
				local cx = medal.side < 0 and left + 2 * pixelScale or left + w - 2 * pixelScale
				local cy = bottom + h / 2 - (offsetY or 0) * pixelScale / 2
				box = boxes[2]
				box[1], box[2], box[3], box[4] = floor(cx - d / 2 + 0.5), floor(cy - d / 2 + 0.5), floor(cx - d / 2 + 0.5) + d, floor(cy - d / 2 + 0.5) + d
			end
			local neighbours = count
			for j = 1, medal and 2 or 1 do
				box = boxes[j]
				local l, b, r, t = box[1], box[2], box[3], box[4]
				if l < 0 or b < 0 or r > physicalWidth or t > physicalHeight then
					return false
				end
				for index = 1, neighbours do
					local rect = rects[index]
					if b < rect[4] and rect[2] < t and l < rect[3] and rect[1] < r and Apart(key, rect.key) then
						local dockBoundary = (key == "databars.micro" and rect.key == "databars.bags") or (key == "databars.bags" and rect.key == "databars.micro")
						if not dockBoundary or min(t, rect[4]) - max(b, rect[2]) > 1 then
							local kept, pair = state.kept, key .. rect.key
							if not kept then return false end
							if kept[1] then kept[pair] = true elseif not kept[pair] then return false end
						end
					end
				end
				count = count + 1
				local rect = rects[count]
				rect[1], rect[2], rect[3], rect[4], rect.key = l, b, r, t, key
			end
		end
	end
	if style == "medallions" and state.slab and layout["actionbars.bar1"] and (enabled["actionbars.bar1"] ~= false or enabled["actionbars.bar2"] ~= false) then
		local bar = layout["actionbars.bar1"]
		local groupHeight = state.groupHeight
		local ring = max(1, floor(Layouts.MEDALLIONS_RING * pixelScale + 0.5))
		local left = floor(physicalWidth / 2 - ring / 2 + 0.5)
		local bottom = floor((bar.y + groupHeight) * pixelScale - ring / 2 + 0.5)
		if left < 0 or bottom < 0 or bottom + ring > physicalHeight then
			return false
		end
		for index = 1, count do
			local rect = rects[index]
			local dock = rect.key == "databars.strip" and Layouts.DataBarDock(name, ns.Scale.AspectClass(physicalWidth, physicalHeight), style)
			local position = layout[rect.key]
			local docked = dock and position.anchor == dock.anchor and position.x == dock.x and position.y == dock.y
			if rect.key ~= "databars.xp" and not docked and left < rect[3] and rect[1] < left + ring and bottom < rect[4] and rect[2] < bottom + ring then
				return false
			end
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
		flags[i] = element.key ~= "consumables.bar" and enabled[element.key] ~= false and "1" or "0"
	end
	style = STYLES[style] and style or style == nil and ns.HudStyle.Current() or "frames"
	local signature = style .. (Layouts.ThirdBarFinished() and "finished" or "legacy") .. table.concat(flags) .. (enabled["meters.damage2"] and "2" or "") .. Layouts.ActionBarSignature(style)
		.. (style == "medallions" and Layouts.CrestKey() or "") .. Layouts.PartyScale(physicalWidth, physicalHeight)
	local cached = limits[preset]
	if cached and cached.width == physicalWidth and cached.height == physicalHeight and cached.signature == signature then
		return cached.scale, cached.fits
	end
	local free = {}
	for key, value in pairs(enabled) do free[key] = value end
	free["consumables.bar"], enabled = false, free
	local positions = Layouts.Positions(preset, style, ns.Scale.AspectClass(physicalWidth, physicalHeight))
	if Layouts.DataBarHeight(style) then positions["databars.strip"] = Layouts.DataBarPosition(style) end
	local state = Layouts.PrepareFits(preset, physicalWidth, physicalHeight, enabled, positions, true, style)
	local function fits(size)
		return Layouts.Fits(preset, physicalWidth, physicalHeight, size, enabled, positions, state, style)
	end
	if fits(high) then
		limits[preset] = { width = physicalWidth, height = physicalHeight, signature = signature, scale = high, fits = fits }
		return high, fits
	end
	if not fits(low) and not fits(low / 2) then
		state.kept = { true }
		fits(low / 2)
		state.kept[1] = false
	end
	if not fits(low) and fits(low / 2) then low = low / 2 end
	local step = 1080 / (physicalHeight * 2 * state.span)
	while high > low do
		local candidate = math.max(low, high - step)
		if candidate == high then
			break
		end
		if fits(candidate) then
			low = candidate
			break
		end
		high = candidate
	end
	for _ = 1, 32 do
		local candidate = (low + high) / 2
		if fits(candidate) then
			low = candidate
		else
			high = candidate
		end
	end
	limits[preset] = { width = physicalWidth, height = physicalHeight, signature = signature, scale = low, fits = fits }
	return low, fits
end
end
