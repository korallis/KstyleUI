-- Layouts.lua: the element keys modules register with Layout, and the Lumen DPS, Tank and Healer layouts the first-run setup writes: positions, footprints, the bars and meters each switches on, and the story slot.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

local BUTTON, SMALL_BUTTON, PITCH = 38, 30, 3
local GRIDS = {
	["actionbars.bar1"] = { buttons = 12, rows = 1, size = BUTTON },
	["actionbars.bar2"] = { buttons = 12, rows = 1, size = BUTTON },
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
	return columns * grid.size + (columns - 1) * PITCH, grid.rows * grid.size + (grid.rows - 1) * PITCH
end

local function Row(icons)
	return icons * BUTTON + (icons - 1) * PITCH
end
local ESSENTIAL, UTILITY, TRACKED = Row(6), Row(4), Row(6)

local ELEMENTS = {
	{ key = "unitframes.player", module = "UnitFrames", label = L["Player frame"], short = L["Player"], width = 490, height = 80 },
	{ key = "unitframes.target", module = "UnitFrames", label = L["Target frame"], short = L["Target"], width = 490, height = 84, reserve = { 490, 136 } },
	{ key = "unitframes.targettarget", module = "UnitFrames", label = L["Target of target"], width = 120, height = 22 },
	{ key = "unitframes.focus", module = "UnitFrames", label = L["Focus frame"], short = L["Focus"], width = 200, height = 90, reserve = { 200, 112 } },
	{ key = "unitframes.focustarget", module = "UnitFrames", label = L["Focus target"], width = 120, height = 22 },
	{ key = "unitframes.pet", module = "UnitFrames", label = L["Pet frame"], width = 120, height = 22 },
	{ key = "unitframes.boss", module = "UnitFrames", label = L["Boss frames"], short = L["Boss"], width = 222, height = 334, reserve = { 318, 334 } },
	{ key = "unitframes.castbar.player", module = "UnitFrames", label = L["Player cast bar"], width = 272, height = 30 },
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
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], short = L["Cooldowns"], width = ESSENTIAL, height = BUTTON },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = UTILITY, height = BUTTON },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = TRACKED, height = BUTTON },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = TRACKED, height = 43 },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], short = L["Blessings"], width = 318, height = 177, reserve = { 318, 230 } },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = 318, height = 63 },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], short = L["Map"], width = 160, height = 160 },
	{ key = "chat.main", module = "Chat", label = L["Chat"], short = L["Chat"], width = 318, height = 260 },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = 489, height = 4 },
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
local MARGIN, RAIL, GAP, TIGHT = 28, 318, 16, 4
local NEAR = ns.Tokens.Size("gapLarge")
local BAND = MARGIN + RAIL + GAP
local ENDS = GridSize("actionbars.bar1") / 2 + NEAR + GridSize("actionbars.pet") / 2
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
local TRACKED_X = -(ESSENTIAL / 2 + GAP + TRACKED / 2)
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
local TIP_Y = MARGIN + 118 + 8
local BLESSINGS_TOP, BLESSINGS = MARGIN + 160 + GAP, 230
local METER_TOP = BLESSINGS_TOP + BLESSINGS + GAP

local DPS = {
	["groupframes.party"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = MARGIN, y = -MARGIN },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = MARGIN, y = MARGIN },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -MARGIN },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -BLESSINGS_TOP },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -(BLESSINGS_TOP + 177 - 63) },
	["meters.damage"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -METER_TOP },
	["meters.threat"] = { anchor = "TOPRIGHT", x = -MARGIN, y = -METER_TOP },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -MARGIN, y = MARGIN + 44 },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = 52 },
	["databars.rep"] = { anchor = "BOTTOM", x = -ENDS, y = 52 },
	["databars.honor"] = { anchor = "BOTTOM", x = ENDS, y = 52 },
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = BAR1_Y },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = BAR1_Y + BAR },
	["actionbars.bar3"] = { anchor = "BOTTOM", x = 0, y = BAR1_Y + 2 * BAR },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -ENDS, y = BAR1_Y },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ENDS, y = BAR1_Y },
	["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = VITALS_Y },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -317, y = VITALS_TOP - 22 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = RESOURCE_Y },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = COOLDOWN_Y },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = UTILITY_X, y = COOLDOWN_Y },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = TRACKED_X, y = COOLDOWN_Y },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = TRACKED_X, y = TRACKED_Y },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = COOLDOWN_Y + BUTTON + 6 },
	["unitframes.target"] = { anchor = "TOP", x = 0, y = -(HEIGHT - CLUSTER_TOP) },
	["unitframes.focus"] = { anchor = "BOTTOM", x = FOCUS_X, y = CLUSTER_TOP - 112 },
	["unitframes.focustarget"] = { anchor = "BOTTOM", x = FOCUS_X - (200 - 120) / 2, y = CLUSTER_TOP - 112 - TIGHT - 22 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = TOT_X, y = CLUSTER_TOP - 22 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 },
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
	},
}
local APPLIED = { ["meters.damage"] = true, ["meters.threat"] = true }

local DOCKS = {
	["auras.debuffs"] = "auras.buffs",
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
	"actionbars.bar2", "actionbars.bar3", "actionbars.bar4", "actionbars.bar5", "actionbars.bar6",
	"unitframes.castbar.player", "unitframes.castbar.target",
}
local OFF = {
	DPS = { "meters.threat" },
	Tank = {},
	Healer = { "meters.threat" },
}

local SHARED_SETTINGS = {
	{ module = "ActionBars", key = "bar1.showEmpty", value = true },
	{ module = "ActionBars", key = "bar2.showEmpty", value = false },
	{ module = "ActionBars", key = "bar3.showEmpty", value = false },
	{ module = "ActionBars", key = "bar4.showEmpty", value = false },
	{ module = "ActionBars", key = "bar5.showEmpty", value = false },
	{ module = "ActionBars", key = "bar6.showEmpty", value = false },
	{ module = "Auras", key = "buffs.rows", value = 1 },
	{ module = "Auras", key = "card.docked", value = true },
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

local STORY_BOTTOM = MARGIN + 260 + GAP
local HEAD = { DPS = "groupframes.party", Tank = "groupframes.party", Healer = "unitframes.boss" }

local NAMES = { "DPS", "Tank", "Healer" }
local LABELS = { DPS = L["DPS"], Tank = L["Tank"], Healer = L["Healer"] }
local NOTES = {
	DPS = L["Lumen Rails: party and chat on the left rail, the map, buffs and damage meter on the right; your target, its target and your focus sit right over your hands."],
	Tank = L["The DPS layout with the threat meter in the combat cluster, under the target of target, where you read who holds aggro without looking away."],
	Healer = L["Larger party and raid frames beside the combat cluster, dispellable debuffs first; the boss cards head the left rail, the damage meter sits under your buffs."],
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
	local function Height(key)
		local size = SIZES[name][key]
		return size and size[2] or byKey[key].height
	end
	local head = HEAD[name]
	local headBottom = HEIGHT + layout[head].y - Height(head)
	local raid = head == "groupframes.party" and Height("groupframes.raid") - Height("groupframes.party") or 0
	slots[name] = {
		key = "story",
		anchor = "BOTTOMLEFT", x = MARGIN, y = STORY_BOTTOM,
		width = RAIL, height = headBottom - GAP - STORY_BOTTOM,
		raid = raid,
		label = L["Story rail"],
		hint = L["Apply places the quest tracker here through Edit Mode; Window skins put the RestedXP guide above it."],
		raidHint = raid > 0 and L["In a raid, the raid frames cover the slot down to the line above."] or nil,
	}
end

Layouts.ELEMENTS = ELEMENTS
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
	return { buttons = grid.buttons, rows = grid.rows, growth = grid.growth, size = grid.size }
end

local FROM_BOTTOM = { ["unitframes.target"] = true }

local function Lift(rootHeight)
	if type(rootHeight) == "number" and rootHeight > 0 then
		return HEIGHT - rootHeight
	end
	return 0
end

function Layouts.Get(name, rootHeight)
	local layout = layouts[name]
	if not layout then
		return nil
	end
	local lift = Lift(rootHeight)
	local out = {}
	for key, position in pairs(layout) do
		out[key] = copy(position)
		if FROM_BOTTOM[key] then
			out[key].y = position.y + lift
		end
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
		return size[1], size[2]
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
			out[#out + 1] = { key = element.key, width = reserve[1], height = reserve[2] }
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
	local out = copy(position)
	local layout = ns.Layout
	if FROM_BOTTOM[key] and layout and type(layout.RootSize) == "function" then
		local _, rootHeight = layout.RootSize()
		out.y = position.y + Lift(rootHeight)
	end
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
		["unitframes.boss"] = { "TOPLEFT", MARGIN, -MARGIN },
		["actionbars.bar2"] = { "TOPRIGHT", -BAND, -533 },
		["actionbars.bar3"] = { "TOPRIGHT", -BAND, -MARGIN },
		["actionbars.bar4"] = { "TOPRIGHT", -403, -MARGIN },
		["actionbars.bar5"] = { "TOPRIGHT", -444, -MARGIN },
		["actionbars.bar6"] = { "TOPRIGHT", -485, -MARGIN },
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

function Layouts.Rect(element, position, rootWidth, rootHeight)
	local point = OFFSETS[position.anchor] or OFFSETS.CENTER
	local fx, fy = point[1], point[2]
	local left = rootWidth * fx + position.x - element.width * fx
	local bottom = rootHeight * fy + position.y - element.height * fy
	return left, bottom, left + element.width, bottom + element.height
end
