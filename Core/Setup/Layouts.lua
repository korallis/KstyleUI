-- Layouts.lua: the element keys modules register with Layout, and the DPS, Tank and Healer layouts the first-run setup writes.
local _, ns = ...

local Setup = ns.Setup or {}
ns.Setup = Setup

local Layouts = {}
Setup.Layouts = Layouts

local L = ns.L

local ELEMENTS = {
	{ key = "unitframes.player", module = "UnitFrames", label = L["Player frame"], width = 220, height = 70 },
	{ key = "unitframes.target", module = "UnitFrames", label = L["Target frame"], width = 220, height = 70 },
	{ key = "unitframes.targettarget", module = "UnitFrames", label = L["Target of target"], width = 88, height = 22 },
	{ key = "unitframes.focus", module = "UnitFrames", label = L["Focus frame"], width = 200, height = 80 },
	{ key = "unitframes.focustarget", module = "UnitFrames", label = L["Focus target"], width = 96, height = 22 },
	{ key = "unitframes.pet", module = "UnitFrames", label = L["Pet frame"], width = 88, height = 22 },
	{ key = "unitframes.boss", module = "UnitFrames", label = L["Boss frames"], width = 200, height = 400 },
	{ key = "unitframes.castbar.player", module = "UnitFrames", label = L["Player cast bar"], width = 272, height = 30 },
	{ key = "unitframes.castbar.target", module = "UnitFrames", label = L["Target cast bar"], width = 220, height = 24 },
	{ key = "unitframes.resource", module = "UnitFrames", label = L["Class resource"], width = 120, height = 14 },
	{ key = "groupframes.party", module = "GroupFrames", label = L["Party frames"], width = 230, height = 270 },
	{ key = "groupframes.raid", module = "GroupFrames", label = L["Raid frames"], width = 597, height = 212 },
	{ key = "actionbars.bar1", module = "ActionBars", label = L["Action bar 1"], width = 489, height = 38 },
	{ key = "actionbars.bar2", module = "ActionBars", label = L["Action bar 2"], width = 489, height = 38 },
	{ key = "actionbars.bar3", module = "ActionBars", label = L["Action bar 3"], width = 38, height = 489 },
	{ key = "actionbars.bar4", module = "ActionBars", label = L["Action bar 4"], width = 38, height = 489 },
	{ key = "actionbars.bar5", module = "ActionBars", label = L["Action bar 5"], width = 38, height = 489 },
	{ key = "actionbars.bar6", module = "ActionBars", label = L["Action bar 6"], width = 38, height = 489 },
	{ key = "actionbars.pet", module = "ActionBars", label = L["Pet bar"], width = 327, height = 30 },
	{ key = "actionbars.stance", module = "ActionBars", label = L["Stance bar"], width = 327, height = 30 },
	{ key = "cooldowns.essential", module = "Cooldowns", label = L["Essential cooldowns"], width = 294, height = 44 },
	{ key = "cooldowns.utility", module = "Cooldowns", label = L["Utility cooldowns"], width = 170, height = 38 },
	{ key = "cooldowns.buffs", module = "Cooldowns", label = L["Tracked buff icons"], width = 195, height = 30 },
	{ key = "cooldowns.bars", module = "Cooldowns", label = L["Tracked buff bars"], width = 195, height = 43 },
	{ key = "auras.buffs", module = "Auras", label = L["Buffs"], width = 360, height = 102 },
	{ key = "auras.debuffs", module = "Auras", label = L["Debuffs"], width = 360, height = 51 },
	{ key = "minimap.main", module = "Minimap", label = L["Minimap"], width = 259, height = 221 },
	{ key = "chat.main", module = "Chat", label = L["Chat"], width = 424, height = 164 },
	{ key = "databars.xp", module = "DataBars", label = L["Experience bar"], width = 352, height = 4 },
	{ key = "databars.rep", module = "DataBars", label = L["Reputation bar"], width = 440, height = 5 },
	{ key = "databars.honor", module = "DataBars", label = L["Honour bar"], width = 440, height = 5 },
	{ key = "databars.strip", module = "DataBars", label = L["Data strip"], width = 492, height = 43 },
	{ key = "databars.micro", module = "DataBars", label = L["Micro menu"], width = 314, height = 32 },
	{ key = "databars.bags", module = "DataBars", label = L["Bag bar"], width = 212, height = 32 },
	{ key = "meters.damage", module = "Meters", label = L["Damage meter"], width = 208, height = 130 },
	{ key = "meters.threat", module = "Meters", label = L["Threat meter"], width = 208, height = 104 },
	{ key = "meters.swing", module = "Meters", label = L["Swing timer"], width = 260, height = 8 },
	{ key = "combattext.player", module = "CombatText", label = L["Your combat text"], width = 160, height = 180 },
	{ key = "tooltips.anchor", module = "Tooltips", label = L["Tooltip anchor"], width = 180, height = 24 },
}

local DPS = {
	["actionbars.bar2"] = { anchor = "BOTTOM", x = 0, y = 59 },
	["actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 107 },
	["databars.xp"] = { anchor = "BOTTOM", x = 0, y = 162 },
	["databars.rep"] = { anchor = "BOTTOM", x = 0, y = 50 },
	["databars.honor"] = { anchor = "BOTTOM", x = 0, y = 43 },
	["cooldowns.utility"] = { anchor = "BOTTOM", x = 0, y = 206 },
	["cooldowns.essential"] = { anchor = "BOTTOM", x = 0, y = 257 },
	["unitframes.castbar.player"] = { anchor = "BOTTOM", x = 0, y = 318 },
	["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 352 },
	["unitframes.player"] = { anchor = "BOTTOM", x = -290, y = 240 },
	["unitframes.target"] = { anchor = "BOTTOM", x = 290, y = 240 },
	["unitframes.pet"] = { anchor = "BOTTOM", x = -450, y = 240 },
	["unitframes.resource"] = { anchor = "BOTTOM", x = -290, y = 314 },
	["unitframes.targettarget"] = { anchor = "BOTTOM", x = 450, y = 240 },
	["unitframes.castbar.target"] = { anchor = "BOTTOM", x = 290, y = 148 },
	["cooldowns.bars"] = { anchor = "BOTTOM", x = -278, y = 184 },
	["cooldowns.buffs"] = { anchor = "BOTTOM", x = 302, y = 180 },
	["unitframes.focus"] = { anchor = "LEFT", x = 300, y = 80 },
	["unitframes.focustarget"] = { anchor = "LEFT", x = 420, y = 10 },
	["unitframes.boss"] = { anchor = "TOP", x = 0, y = -24 },
	["groupframes.party"] = { anchor = "TOPLEFT", x = 16, y = -48 },
	["groupframes.raid"] = { anchor = "TOPLEFT", x = 16, y = -48 },
	["chat.main"] = { anchor = "BOTTOMLEFT", x = 16, y = 16 },
	["actionbars.pet"] = { anchor = "BOTTOM", x = -368, y = 349 },
	["actionbars.stance"] = { anchor = "BOTTOM", x = -368, y = 383 },
	["actionbars.bar5"] = { anchor = "LEFT", x = 16, y = -40 },
	["actionbars.bar6"] = { anchor = "LEFT", x = 57, y = -40 },
	["actionbars.bar3"] = { anchor = "RIGHT", x = -16, y = -110 },
	["actionbars.bar4"] = { anchor = "RIGHT", x = -57, y = -110 },
	["minimap.main"] = { anchor = "TOPRIGHT", x = -16, y = -16 },
	["auras.buffs"] = { anchor = "TOPRIGHT", x = -287, y = -16 },
	["auras.debuffs"] = { anchor = "TOPRIGHT", x = -287, y = -126 },
	["databars.strip"] = { anchor = "BOTTOMRIGHT", x = -16, y = 16 },
	["databars.micro"] = { anchor = "BOTTOMRIGHT", x = -16, y = 67 },
	["databars.bags"] = { anchor = "BOTTOMRIGHT", x = -16, y = 103 },
	["meters.damage"] = { anchor = "BOTTOMRIGHT", x = -99, y = 363 },
	["meters.threat"] = { anchor = "BOTTOMRIGHT", x = -99, y = 545 },
	["combattext.player"] = { anchor = "BOTTOM", x = 0, y = 470 },
	["tooltips.anchor"] = { anchor = "BOTTOMRIGHT", x = -99, y = 331 },
}

local CHANGES = {
	DPS = {},
	Tank = {
		["meters.threat"] = { anchor = "BOTTOM", x = 340, y = 336 },
	},
	Healer = {
		["groupframes.party"] = { anchor = "BOTTOM", x = -368, y = 416 },
		["groupframes.raid"] = { anchor = "BOTTOM", x = 0, y = 420 },
		["combattext.player"] = { anchor = "BOTTOM", x = 0, y = 640 },
		["unitframes.boss"] = { anchor = "TOPLEFT", x = 110, y = -24 },
		["unitframes.focus"] = { anchor = "LEFT", x = 320, y = 222 },
		["unitframes.focustarget"] = { anchor = "LEFT", x = 420, y = 160 },
	},
}

local NAMES = { "DPS", "Tank", "Healer" }
local LABELS = { DPS = L["DPS"], Tank = L["Tank"], Healer = L["Healer"] }
local NOTES = {
	DPS = L["The compact HUD band, with party frames and meters at the edges."],
	Tank = L["The DPS layout with the threat meter beside your target frame."],
	Healer = L["The DPS layout with party and raid frames above your HUD band, and the boss frames at the top left."],
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
