-- Layouts.lua: the element keys modules register with Layout, and the Lumen DPS, Tank and Healer layouts the first-run setup writes: positions, footprints, the bars and meters each switches on, and the story slot on the right rail under the map.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

local BUTTON, SMALL_BUTTON, PITCH = 38, 30, 3
local CENTRE_BUTTON, CENTRE_GAP, COLUMN = 36.7, 4.6, 491
local PLAYER_CAST_Y = 385.5
local GRIDS = {
	["actionbars.bar1"] = { buttons = 12, rows = 1, size = CENTRE_BUTTON, spacing = CENTRE_GAP },
	["actionbars.bar2"] = { buttons = 12, rows = 1, size = CENTRE_BUTTON, spacing = CENTRE_GAP },
	["actionbars.bar3"] = { buttons = 12, rows = 1, size = BUTTON },
	["actionbars.bar4"] = { buttons = 12, rows = 12, size = BUTTON },
	["actionbars.bar5"] = { buttons = 12, rows = 12, size = BUTTON },
	["actionbars.bar6"] = { buttons = 12, rows = 12, size = BUTTON },
	["actionbars.pet"] = { buttons = 10, rows = 2, size = SMALL_BUTTON },
	["actionbars.stance"] = { buttons = 10, rows = 2, size = SMALL_BUTTON, growth = "RIGHTUP" },
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
	{ key = "unitframes.castbar.target", module = "UnitFrames", label = L["Target cast bar"], width = 220, height = 24 },
	{ key = "unitframes.resource", module = "UnitFrames", label = L["Class resource"], width = 120, height = 14 },
	{ key = "groupframes.party", module = "GroupFrames", label = L["Party frames"], short = L["Party"], width = 318, height = 324 },
	{ key = "groupframes.raid", module = "GroupFrames", label = L["Raid frames"], short = L["Raid"], width = 318, height = 427 },
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
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], short = L["Auras"], width = 282, height = 88 },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = 282, height = 88 },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], short = L["Map"], width = 160, height = 160 },
	{ key = "chat.main", module = "Chat", label = L["Chat"], short = L["Chat"], width = 393, height = 200 },
	{ key = "qol.lootfeed", module = "QoL", label = L["Loot feed"], width = ns.Tokens.Size("railWidth"), height = FEED_LINES * FEED_ROW + (FEED_LINES - 1) * FEED_GAP + 2 * FEED_PAD },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = COLUMN, height = 8 },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 162, height = 5 },
	{ key = "databars.honor", module = "DataBars", label = L["Honour bar"], width = 162, height = 5 },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], short = L["Readout"], width = 318, height = 42, reserve = { 318, 118 } },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 318, height = 44 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 212, height = 32 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], short = L["Damage"], width = 318, height = 190 },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], short = L["Threat"], width = 318, height = 144 },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], short = L["Combat text"], width = 160, height = 180 },
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
local BAND = MARGIN + RAIL + GAP
local ENDS = (12 * BUTTON + 11 * PITCH) / 2 + NEAR + GridSize("actionbars.pet") / 2
local BAR = BUTTON + PITCH
local BAR1_Y = 68
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
local TEXT_TOP = CLUSTER_TOP + GAP + 180
local SIDE_BARS = 3 * BAR - PITCH
local BOSS_X = -(BAND + SIDE_BARS + GAP)
local function ElementSize(key)
	for _, element in ipairs(ELEMENTS) do
		if element.key == key then
			return element.width, element.height
		end
	end
end
local MAP_W, MAP_H = ElementSize("minimap.main")
local _, CHAT_H = ElementSize("chat.main")
local _, AURA_ROW = ElementSize("auras.buffs")
local AURAS_X = MARGIN + MAP_W + GAP
local AURAS_BOTTOM = MARGIN + 2 * AURA_ROW + GAP
local STORY_TOP = math.max(MARGIN + MAP_H, AURAS_BOTTOM) + GAP
local _, METER_H = ElementSize("meters.damage")
local _, TIP_H = ElementSize("tooltips.anchor")
local METER_Y = MARGIN + 118 + GAP
local TIP_Y = METER_Y + METER_H + 8
local STORY_BOTTOM = TIP_Y + TIP_H + GAP

local DPS = {
	["groupframes.party"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN },
	["qol.lootfeed"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN + CHAT_H + GAP },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -MARGIN },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -MARGIN },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -AURAS_X, y = -(MARGIN + AURA_ROW + GAP) },
	["meters.damage"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = METER_Y },
	["meters.threat"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = METER_Y },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN + 44 },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = 36.5 },
	["databars.rep"] = { anchor = "BOTTOM", x = -ENDS, y = 52 },
	["databars.honor"] = { anchor = "BOTTOM", x = ENDS, y = 52 },
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 54 },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = 95.3 },
	["actionbars.bar3"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = math.max(MARGIN + CHAT_H + select(2, ElementSize("qol.lootfeed")) + 2 * GAP, PLAYER_CAST_Y + select(2, ElementSize("unitframes.castbar.player")) + GAP) },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -ENDS, y = BAR1_Y },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ENDS, y = BAR1_Y },
	["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 138 },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -317, y = VITALS_TOP - 22 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = 420 },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 335.3 },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = UTILITY_X, y = 335.3 },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = -442.8, y = 155.9 },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -480, y = 340 },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 376.5 },
	["unitframes.target"] = { anchor = "BOTTOM", x = 0, y = 217.5 },
	["unitframes.focus"] = { anchor = "BOTTOM", x = FOCUS_X, y = CLUSTER_TOP - 112 },
	["unitframes.focustarget"] = { anchor = "BOTTOM", x = FOCUS_X - (200 - 120) / 2, y = CLUSTER_TOP - 112 - TIGHT - 22 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = TOT_X, y = CLUSTER_TOP - 22 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = PLAYER_CAST_Y },
	["unitframes.castbar.target"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 + 30 + 8 },
	["unitframes.boss"] = { anchor = "BOTTOMRIGHT", x = BOSS_X, y = TEXT_TOP + GAP },
	["combattext.player"] = { anchor = "BOTTOM", x = 376, y = CLUSTER_TOP + GAP },
	["actionbars.bar4"] = { anchor = "RIGHT", x = -BAND, y = 0 },
	["actionbars.bar5"] = { anchor = "RIGHT", x = -(BAND + BAR), y = 0 },
	["actionbars.bar6"] = { anchor = "RIGHT", x = -(BAND + 2 * BAR), y = 0 },
	["tooltips.anchor"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = TIP_Y },
}

local CHANGES = {
	DPS = {},
	Tank = {
		["meters.threat"] = { anchor = "BOTTOM", x = SIDE + 200 / 2, y = CLUSTER_TOP - 22 - TIGHT - 112 },
	},
	Healer = {
		["groupframes.party"] = { anchor = "BOTTOM", x = HEALER_X, y = HEALER_Y },
		["groupframes.raid"] = { anchor = "BOTTOM", x = HEALER_X, y = HEALER_Y },
		["unitframes.boss"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
		["combattext.player"] = { anchor = "BOTTOM", x = CAST_HALF + GAP + 160 / 2, y = CLUSTER_TOP + GAP },
	},
}

local SIZES = {
	DPS = {
		["meters.damage"] = { RAIL, 190 },
		["meters.threat"] = { RAIL, 144 },
	},
	Tank = {
		["meters.damage"] = { RAIL, 190 },
		["meters.threat"] = { 200, 112 },
	},
	Healer = {
		["groupframes.party"] = { RAIL, 354 },
		["groupframes.raid"] = { RAIL, 487 },
		["meters.damage"] = { RAIL, 190 },
		["meters.threat"] = { RAIL, 144 },
		["chat.main"] = { RAIL, 200 },
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
	"actionbars.bar3", "actionbars.bar4", "actionbars.bar5", "actionbars.bar6",
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
	{ module = "DataBars", key = "strip.menus", value = true },
	{ module = "GroupFrames", key = "party.spacing", value = 8 },
	{ module = "GroupFrames", key = "raid.groupsPerRow", value = 4 },
	{ module = "GroupFrames", key = "raid.width", value = 77 },
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
		{ module = "UnitFrames", key = "boss.auraPosition", value = "RIGHT" },
		{ module = "UnitFrames", key = "boss.auraGrowth", value = "RIGHT_DOWN" },
		{ module = "UnitFrames", key = "boss.growth", value = "DOWN" },
	},
}
local ROWS = {
	DPS = { party = 40, raid = 40 },
	Tank = { party = 40, raid = 40 },
	Healer = { party = 46, raid = 46 },
}


local NAMES = { "DPS", "Tank", "Healer" }
local LABELS = { DPS = L["DPS"], Tank = L["Tank"], Healer = L["Healer"] }
local NOTES = {
	DPS = L["Lumen Rails: party and chat on the left rail; the map, buffs, quests and damage meter on the right; your target, its target and your focus sit right over your hands."],
	Tank = L["The DPS layout with the threat meter in the combat cluster, under the target of target, where you read who holds aggro without looking away."],
	Healer = L["Larger party and raid frames beside the combat cluster, dispellable debuffs first; the boss cards head the left rail, the quests and the damage meter stand under your buffs."],
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
		anchor = "TOPRIGHT", x = -MARGIN, y = -STORY_TOP,
		width = RAIL, height = HEIGHT - STORY_TOP - STORY_BOTTOM,
		label = L["Story rail"],
		hint = L["Apply places the quest tracker here through Edit Mode; Window skins put the RestedXP guide above it."],
	}
end

Layouts.ELEMENTS = ELEMENTS
Layouts.FEED_LINES = FEED_LINES
Layouts.FEED_PAD = FEED_PAD
Layouts.SIGIL_CLEAR = SIGIL_CLEAR
Layouts.BUTTON = BUTTON
Layouts.HEIGHT = HEIGHT

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
		out[key] = copy(position)
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

function Layouts.Default(key)
	local position = layouts.DPS[key]
	if not position then
		error("KstyleUI.Setup.Layouts.Default: unknown element key " .. tostring(key), 2)
	end
	return copy(position)
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

local function Apart(name, a, b)
	if (a == "groupframes.party" and b == "groupframes.raid") or (b == "groupframes.party" and a == "groupframes.raid") then
		return false
	end
	if DOCKS[a] == b or DOCKS[b] == a then
		return false
	end
	if (a == "meters.damage" and b == "meters.threat") or (b == "meters.damage" and a == "meters.threat") then
		return Layouts.Shown(name, "meters.threat") ~= false
	end
	return true
end

function Layouts.Fits(name, physicalWidth, physicalHeight, user)
	if not Positive(physicalWidth) or not Positive(physicalHeight) or not Positive(user) then
		return false
	end
	local rootHeight = 1080 / user
	local layout = Layouts.Get(name, rootHeight)
	if not layout then
		return false
	end
	local pixelScale = physicalHeight / rootHeight
	local rects = {}
	for i = 1, #ELEMENTS + 1 do
		local key, width, height, position, offsetX
		if i <= #ELEMENTS then
			key = ELEMENTS[i].key
			width, height, offsetX = Layouts.Footprint(name, key)
			position = layout[key]
		else
			position = Layouts.Slot(name, rootHeight)
			key, width, height = "story", position.width, position.height
		end
		if width <= 0 or height <= 0 then
			return false
		end
		local w = math.max(1, math.floor(width * pixelScale + 0.5))
		local h = math.max(1, math.floor(height * pixelScale + 0.5))
		local point = OFFSETS[position.anchor] or OFFSETS.CENTER
		local left = math.floor(physicalWidth * point[1] + (position.x + (offsetX or 0)) * pixelScale - w * point[1] + 0.5)
		local bottom = math.floor(physicalHeight * point[2] + position.y * pixelScale - h * point[2] + 0.5)
		local right, top = left + w, bottom + h
		if left < 0 or bottom < 0 or right > physicalWidth or top > physicalHeight or right <= left or top <= bottom then
			return false
		end
		for _, rect in ipairs(rects) do
			if Apart(name, key, rect.key) and left < rect[3] and rect[1] < right and bottom < rect[4] and rect[2] < top then
				local dockBoundary = (key == "databars.micro" and rect.key == "databars.bags") or (key == "databars.bags" and rect.key == "databars.micro")
				if not dockBoundary or math.min(top, rect[4]) - math.max(bottom, rect[2]) > 1 then
					return false
				end
			end
		end
		rects[#rects + 1] = { left, bottom, right, top, key = key }
	end
	return true
end

local limits = {}

function Layouts.ScaleLimit(physicalWidth, physicalHeight, preset)
	local low, high = ns.Scale.DEFAULT_USER_SCALE, ns.Scale.MAX_USER_SCALE
	if not Positive(physicalWidth) or not Positive(physicalHeight) then
		return low
	end
	preset = layouts[preset] and preset or "DPS"
	local cached = limits[preset]
	if cached and cached.width == physicalWidth and cached.height == physicalHeight then
		return cached.scale
	end
	if Layouts.Fits(preset, physicalWidth, physicalHeight, high) then
		limits[preset] = { width = physicalWidth, height = physicalHeight, scale = high }
		return high
	end
	local span = HEIGHT
	for _, element in ipairs(ELEMENTS) do
		local width, height = Layouts.Footprint(preset, element.key)
		local position = layouts[preset][element.key]
		span = math.max(span, math.abs(position.x) + width, math.abs(position.y) + height)
	end
	local step = 1080 / (physicalHeight * 2 * span)
	while high > low do
		local candidate = math.max(low, high - step)
		if candidate == high then
			break
		end
		if Layouts.Fits(preset, physicalWidth, physicalHeight, candidate) then
			low = candidate
			break
		end
		high = candidate
	end
	for _ = 1, 32 do
		local candidate = (low + high) / 2
		if Layouts.Fits(preset, physicalWidth, physicalHeight, candidate) then
			low = candidate
		else
			high = candidate
		end
	end
	limits[preset] = { width = physicalWidth, height = physicalHeight, scale = low }
	return low
end
