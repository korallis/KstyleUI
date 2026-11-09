-- Layouts.lua: the element keys modules register with Layout, and the Lumen DPS, Tank and Healer layouts the first-run setup writes: positions, footprints, the bars and meters each switches on, and the story slot.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

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
	{ key = "actionbars.bar1", module = "ActionBars", label = L["Action bar 1"], short = L["Bar 1"], width = 489, height = 38 },
	{ key = "actionbars.bar2", module = "ActionBars", label = L["Action bar 2"], short = L["Bar 2"], width = 489, height = 38 },
	{ key = "actionbars.bar3", module = "ActionBars", label = L["Action bar 3"], width = 38, height = 489 },
	{ key = "actionbars.bar4", module = "ActionBars", label = L["Action bar 4"], width = 38, height = 489 },
	{ key = "actionbars.bar5", module = "ActionBars", label = L["Action bar 5"], width = 38, height = 489 },
	{ key = "actionbars.bar6", module = "ActionBars", label = L["Action bar 6"], width = 38, height = 489 },
	{ key = "actionbars.pet", module = "ActionBars", label = L["Pet bar"], width = 162, height = 63 },
	{ key = "actionbars.stance", module = "ActionBars", label = L["Stance bar"], width = 162, height = 63 },
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], short = L["Cooldowns"], width = 294, height = 44 },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = 170, height = 38 },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = 195, height = 30 },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = 195, height = 43 },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], short = L["Buffs"], width = 318, height = 177, reserve = { 318, 230 } },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = 318, height = 63 },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], short = L["Map"], width = 318, height = 346 },
	{ key = "chat.main", module = "Chat", label = L["Chat"], short = L["Chat"], width = 318, height = 260 },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = 489, height = 4 },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 162, height = 5 },
	{ key = "databars.honor", module = "DataBars", label = L["Honour bar"], width = 162, height = 5 },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], short = L["Readout"], width = 318, height = 118 },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 318, height = 44 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 212, height = 32 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], short = L["Damage"], width = 318, height = 190 },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], short = L["Threat"], width = 318, height = 144 },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], short = L["Text"], width = 160, height = 180 },
	{ key = "tooltips.anchor", module = "Tooltips", label = L["Tooltip anchor"], width = 180, height = 24 },
}

local HEIGHT = 1080
local MARGIN, RAIL, GAP, NEAR, TIGHT = 28, 318, 16, 12, 4
local BAND = MARGIN + RAIL + GAP
local ENDS = 489 / 2 + NEAR + 162 / 2
local BAR = 38 + 3
local HANDS_TOP = 264 + 43
local CLUSTER_TOP = HANDS_TOP + 7 + 136
local SIDE = 490 / 2 + NEAR
local FOCUS_X = -(SIDE + 200 / 2)
local TOT_X = SIDE + 120 / 2
local SIGIL_CLEAR = GAP
local STACK = CLUSTER_TOP + SIGIL_CLEAR
local CAST_HALF = 272 / 2
local HEALER_X, HEALER_Y = -(CAST_HALF + GAP + RAIL / 2), CLUSTER_TOP + GAP
local TIP_Y = MARGIN + 118 + 8
local BLESSINGS_TOP, BLESSINGS = MARGIN + 346 + GAP, 230
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
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 68 },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -ENDS, y = 68 },
	["actionbars.stance"] = { anchor = "BOTTOM", x = ENDS, y = 68 },
	["unitframes.player"] = { anchor = "BOTTOM", x = 0, y = 118 },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -317, y = 176 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = 204 },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 226 },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = 248, y = 226 },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = -260.5, y = 226 },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -260.5, y = 264 },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 276 },
	["unitframes.target"] = { anchor = "TOP", x = 0, y = -(HEIGHT - CLUSTER_TOP) },
	["unitframes.focus"] = { anchor = "BOTTOM", x = FOCUS_X, y = CLUSTER_TOP - 112 },
	["unitframes.focustarget"] = { anchor = "BOTTOM", x = FOCUS_X - (200 - 120) / 2, y = CLUSTER_TOP - 112 - TIGHT - 22 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = TOT_X, y = CLUSTER_TOP - 22 },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = STACK },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 },
	["unitframes.castbar.target"] = { anchor = "BOTTOM", x = 0, y = STACK + 38 + 8 + 30 + 8 },
	["unitframes.boss"] = { anchor = "TOPRIGHT", x = -BAND, y = -MARGIN },
	["combattext.player"] = { anchor = "BOTTOM", x = 376, y = CLUSTER_TOP + GAP },
	["actionbars.bar5"] = { anchor = "TOPLEFT", x = BAND, y = -MARGIN },
	["actionbars.bar6"] = { anchor = "TOPLEFT", x = BAND + BAR, y = -MARGIN },
	["actionbars.bar3"] = { anchor = "TOPLEFT", x = BAND + 2 * BAR, y = -MARGIN },
	["actionbars.bar4"] = { anchor = "TOPLEFT", x = BAND + 3 * BAR, y = -MARGIN },
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
		["actionbars.bar2"] = { anchor = "TOP", x = 0, y = -MARGIN },
		["actionbars.bar3"] = { anchor = "TOPRIGHT", x = -BAND, y = -MARGIN },
		["actionbars.bar4"] = { anchor = "TOPRIGHT", x = -(BAND + BAR), y = -MARGIN },
		["actionbars.bar5"] = { anchor = "TOPRIGHT", x = -(BAND + 2 * BAR), y = -MARGIN },
		["actionbars.bar6"] = { anchor = "TOPRIGHT", x = -(BAND + 3 * BAR), y = -MARGIN },
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
	{ module = "ActionBars", key = "bar1.rows", value = 1 },
	{ module = "ActionBars", key = "pet.rows", value = 2 },
	{ module = "ActionBars", key = "stance.rows", value = 2 },
	{ module = "ActionBars", key = "stance.growth", value = "RIGHTUP" },
	{ module = "ActionBars", key = "bar1.showEmpty", value = false },
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
local BOSS_LEFT = {
	{ module = "UnitFrames", key = "boss.auraPosition", value = "LEFT" },
	{ module = "UnitFrames", key = "boss.auraGrowth", value = "LEFT_DOWN" },
}
local EXTRA = {
	DPS = BOSS_LEFT,
	Tank = BOSS_LEFT,
	Healer = {
		{ module = "GroupFrames", key = "party.auraDispelCount", value = 2 },
		{ module = "GroupFrames", key = "raid.auraDispelCount", value = 2 },
		{ module = "UnitFrames", key = "boss.auraPosition", value = "RIGHT" },
		{ module = "UnitFrames", key = "boss.auraGrowth", value = "RIGHT_DOWN" },
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
	local headBottom = 1080 + layout[head].y - Height(head)
	local raid = head == "groupframes.party" and Height("groupframes.raid") - Height("groupframes.party") or 0
	slots[name] = {
		key = "story",
		anchor = "BOTTOMLEFT", x = MARGIN, y = STORY_BOTTOM,
		width = RAIL, height = headBottom - GAP - STORY_BOTTOM,
		raid = raid,
		label = L["Story rail"],
		hint = L["Apply places the quest tracker here through Edit Mode. Drag the RestedXP guide here."],
		raidHint = raid > 0 and L["In a raid, the raid frames cover the slot down to the line above."] or nil,
	}
end

Layouts.ELEMENTS = ELEMENTS
Layouts.SIGIL_CLEAR = SIGIL_CLEAR

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

function Layouts.Slot(name)
	local slot = slots[name]
	if not slot then
		return nil
	end
	local out = {}
	for k, v in pairs(slot) do
		out[k] = v
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

function Layouts.Rect(element, position, rootWidth, rootHeight)
	local point = OFFSETS[position.anchor] or OFFSETS.CENTER
	local fx, fy = point[1], point[2]
	local left = rootWidth * fx + position.x - element.width * fx
	local bottom = rootHeight * fy + position.y - element.height * fy
	return left, bottom, left + element.width, bottom + element.height
end
