-- Layouts.lua: the element keys modules register with Layout, and the DPS, Tank and Healer layouts the first-run setup writes.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

local ELEMENTS = {
	{ key = "unitframes.player", module = "UnitFrames", label = L["Player frame"], width = 266, height = 46 },
	{ key = "unitframes.target", module = "UnitFrames", label = L["Target frame"], width = 266, height = 46 },
	{ key = "unitframes.targettarget", module = "UnitFrames", label = L["Target of target"], width = 120, height = 24 },
	{ key = "unitframes.focus", module = "UnitFrames", label = L["Focus frame"], width = 266, height = 70 },
	{ key = "unitframes.pet", module = "UnitFrames", label = L["Pet frame"], width = 120, height = 24 },
	{ key = "unitframes.boss", module = "UnitFrames", label = L["Boss frames"], width = 266, height = 330 },
	{ key = "unitframes.castbar.player", module = "UnitFrames", label = L["Player cast bar"], width = 260, height = 20 },
	{ key = "groupframes.party", module = "GroupFrames", label = L["Party frames"], width = 230, height = 270 },
	{ key = "groupframes.raid", module = "GroupFrames", label = L["Raid frames"], width = 597, height = 212 },
	{ key = "actionbars.bar1", module = "ActionBars", label = L["Action bar 1"], width = 441, height = 34 },
	{ key = "actionbars.bar2", module = "ActionBars", label = L["Action bar 2"], width = 441, height = 34 },
	{ key = "actionbars.bar3", module = "ActionBars", label = L["Action bar 3"], width = 34, height = 441 },
	{ key = "actionbars.bar4", module = "ActionBars", label = L["Action bar 4"], width = 34, height = 441 },
	{ key = "actionbars.bar5", module = "ActionBars", label = L["Action bar 5"], width = 34, height = 441 },
	{ key = "actionbars.bar6", module = "ActionBars", label = L["Action bar 6"], width = 34, height = 441 },
	{ key = "actionbars.pet", module = "ActionBars", label = L["Pet bar"], width = 327, height = 30 },
	{ key = "actionbars.stance", module = "ActionBars", label = L["Stance bar"], width = 327, height = 30 },
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], width = 255, height = 40 },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = 195, height = 30 },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = 195, height = 30 },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = 180, height = 60 },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], width = 420, height = 76 },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = 420, height = 38 },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], width = 226, height = 196 },
	{ key = "chat.main", module = "Chat", label = L["Chat"], width = 390, height = 190 },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = 441, height = 5 },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 441, height = 5 },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], width = 430, height = 36 },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 270, height = 28 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 180, height = 30 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], width = 260, height = 174 },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], width = 260, height = 130 },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], width = 160, height = 180 },
}

local DPS = {
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 61 },
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = 24 },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = 14 },
	["databars.rep"] = { anchor = "BOTTOM", x = 0, y = 6 },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = 0, y = 105 },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 141 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = 193 },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 219 },
	["unitframes.player"] = { anchor = "BOTTOM", x = -279, y = 113 },
	["unitframes.target"] = { anchor = "BOTTOM", x = 279, y = 113 },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -352, y = 83 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = 352, y = 83 },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -236, y = 167 },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = 244, y = 167 },
	["unitframes.focus"] = { anchor = "LEFT", x = 300, y = 60 },
	["unitframes.boss"] = { anchor = "TOP", x = 0, y = -24 },
	["groupframes.party"] = { anchor = "TOPLEFT", x = 16, y = -48 },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = 16, y = -48 },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = 16, y = 16 },
	["actionbars.pet"] = { anchor = "BOTTOMLEFT", x = 16, y = 214 },
	["actionbars.stance"] = { anchor = "BOTTOMLEFT", x = 16, y = 250 },
	["actionbars.bar5"] = { anchor = "LEFT", x = 16, y = -15 },
	["actionbars.bar6"] = { anchor = "LEFT", x = 53, y = -15 },
	["actionbars.bar3"] = { anchor = "RIGHT", x = -16, y = -40 },
	["actionbars.bar4"] = { anchor = "RIGHT", x = -53, y = -40 },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -16, y = -16 },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -16, y = -222 },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -16, y = -306 },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -16, y = 16 },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -16, y = 60 },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -16, y = 96 },
	["meters.damage"] = { anchor = "BOTTOMRIGHT", x = -95, y = 134 },
	["meters.threat"] = { anchor = "BOTTOMRIGHT", x = -95, y = 316 },
	["combattext.player"] = { anchor = "BOTTOM", x = 0, y = 470 },
}

local CHANGES = {
	DPS = {},
	Tank = {
		["meters.threat"] = { anchor = "BOTTOM", x = 279, y = 205 },
	},
	Healer = {
		["groupframes.party"] = { anchor = "BOTTOM", x = -330, y = 245 },
		["groupframes.raid"] = { anchor = "BOTTOM", x = 0, y = 245 },
	},
}

local NAMES = { "DPS", "Tank", "Healer" }
local LABELS = { DPS = L["DPS"], Tank = L["Tank"], Healer = L["Healer"] }
local NOTES = {
	DPS = L["The compact HUD band, with party frames and meters at the edges."],
	Tank = L["The DPS layout with the threat meter beside your target frame."],
	Healer = L["The DPS layout with party and raid frames above your HUD band."],
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

local layouts = {}
for _, name in ipairs(NAMES) do
	local layout = {}
	for key, position in pairs(DPS) do
		layout[key] = copy(CHANGES[name][key] or position)
	end
	layouts[name] = layout
end

Layouts.ELEMENTS = ELEMENTS

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
