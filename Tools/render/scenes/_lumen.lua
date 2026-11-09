-- _lumen.lua: the Lumen Rails HUD in the two states the mockup boards draw (handoff/arena2/parent: hud-questing.png
-- and hud-combat.png), on top of hud.lua. Every module renders where the Lumen layout puts it, with the module
-- settings Layout > Apply writes for the layout (Setup.Layouts.Settings): bar 1 alone, the pet and stance sockets in
-- two rows, the threat card in Tank only. The player's own placements stand in for what KstyleUI cannot move: the
-- RestedXP guide and the quest tracker sit in the layout's story slot (Setup.Layouts.Slot), as the setup asks.
--
--   local Lumen = dofile("Tools/render/scenes/_lumen.lua")
--   local scene = Lumen.Build("questing")     -- or "combat"; Lumen.Build(state, { layout = "Tank" })
--
-- questing: out of combat with no target, three quests and the guide in the story slot, a party of three, the last
-- fight's meter. The guide's list is resized shorter, as a player does with RestedXP's grabber, so both fit the slot.
-- combat: in combat with a party of five, the boss card, and the boss as the target, casting; the combat calm has
-- faded the slow cards (chat, the lens, the readout and menu, the XP line, the guide and the tracker) to 30%.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Scene = Common.Scene

local Lumen = {}

local HEIGHT = 1080
local GUIDE_INSET = 25
local TRACKER_INSET = 36
local TRACKER_HEADER = 34
local SLOT_GAP = 12
local GUIDE_LIST = 84

-- The mockup's questing board: the quests the tracker lists, and the party around the player.
Lumen.QUESTS = {
	{ title = "Threat from Below", objectives = { "Ready for turn-in" }, questID = 201, superTracked = true },
	{ title = "Break a Few Eggs", objectives = { "Taillasher Egg 0/3" }, questID = 202 },
	{ title = "Encroachment", objectives = { "Bloodtalon Scythemaw 0/16" }, questID = 203 },
}
Lumen.PARTY = {
	questing = { { "Leduc", "PALADIN", 92, "HEALER" }, { "Trolly", "PRIEST", 100, "DAMAGER" } },
	combat = {
		{ "Leduc", "PALADIN", 64, "HEALER" }, { "Trolly", "PRIEST", 100, "DAMAGER" },
		{ "Khont", "ROGUE", 38, "DAMAGER" }, { "Mira", "MAGE", 88, "DAMAGER" },
	},
}
Lumen.DAMAGE = {
	questing = { { nil, "WARRIOR", 18000 }, { "Leduc", "PALADIN", 442 }, { "Trolly", "PRIEST", 201 } },
	combat = {
		{ nil, "WARRIOR", 14600 }, { "Khont", "ROGUE", 9800 }, { "Mira", "MAGE", 8700 },
		{ "Trolly", "PRIEST", 2100 }, { "Leduc", "PALADIN", 1300 },
	},
}
Lumen.BOSS = {
	name = "Bloodtalon Matriarch", level = 38, classification = "elite", health = 3720, healthMax = 6000,
	power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, threatOn = 3,
	cast = { name = "Terrifying Screech", texture = 136184, start = 9000, finish = 12500, spellID = 4321 },
}

-- Preset(layout) -> the layout's module settings as saved sections ({ [module] = { nested } }) and its story slot
-- in screen units ({ left, top, width, height }, y down from the top), from the addon's own Setup.Layouts.
function Lumen.Preset(layout)
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	local settings = {}
	for _, entry in ipairs(Layouts.Settings(layout)) do
		local node = settings[entry.module] or {}
		settings[entry.module] = node
		local parts = {}
		for part in entry.key:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = entry.value
	end
	local slot = Layouts.Slot(layout)
	local width = HEIGHT * Common.SCREEN.width / Common.SCREEN.height
	local l, _, r, t = Layouts.Rect(slot, slot, width, HEIGHT)
	return settings, { left = l, top = HEIGHT - t, width = r - l, height = slot.height }, slot, Layouts.Sizes(layout)
end

local function glassBottom(scene)
	local bottom = -math.huge
	for _, item in ipairs(scene.items) do
		local r = item.rect
		local shadow = item.file and item.file:find("Shadow", 1, true)
		if r and not shadow and (item.alpha or 1) > 0 then
			bottom = math.max(bottom, r[2] + r[4])
		end
	end
	return bottom
end

local function bottomOf(env, frame)
	local _, top, _, h = Scene.Rect(env, frame)
	return top and h and top + h
end

function Lumen.Build(state, opts)
	opts = opts or {}
	local layout = opts.layout or "DPS"
	local settings, slot, _, sizes = Lumen.Preset(layout)
	local _, spec = Hud.Class(opts)
	local damage = {}
	for i, row in ipairs(Lumen.DAMAGE[state]) do
		damage[i] = { row[1] or spec.name, row[2], row[3] }
	end
	local base = {
		class = opts.class,
		layout = layout,
		settings = settings,
		combat = state == "combat",
		party = Lumen.PARTY[state],
		damage = damage,
		quests = Lumen.QUESTS,
	}
	if state == "combat" then
		base.boss = Lumen.BOSS
		base.target = Lumen.BOSS
	else
		base.target = false
	end
	base.guideList = GUIDE_LIST
	base.menus = true
	base.sizes = {}
	for key, size in pairs(sizes) do
		base.sizes[key] = { size.width, size.height }
	end
	local scenes, log = {}, {}
	base.guideAt = { slot.left + GUIDE_INSET, slot.top + SLOT_GAP }
	local guide, R = Hud.Module("restedxp", base)
	scenes[#scenes + 1] = guide
	local guideBottom = bottomOf(R.env, R.rxp.RXPFrame) or (slot.top + slot.height / 2)
	base.trackerAt = { slot.left + TRACKER_INSET, guideBottom + SLOT_GAP - TRACKER_HEADER }
	-- A player drops the quest card so its glass ends inside the slot, clear of chat: lift it by what it overruns.
	local tracker = Hud.Module("tracker", base)
	local over = glassBottom(tracker) - (slot.top + slot.height)
	if over > 0 then
		base.trackerAt[2] = base.trackerAt[2] - over
		log[#log + 1] = string.format("lumen: the quest card's glass lifted %.1f units to end in the story slot", over)
	end
	local names = { "chat", "minimap", "auras", "databars", "tracker", "groupframes", "meters", "unitframes", "actionbars", "cooldowns" }
	if state == "combat" then
		table.insert(names, 1, "nameplates")
	end
	for _, name in ipairs(names) do
		scenes[#scenes + 1] = (Hud.Module(name, base))
	end
	local merged = Scene.Merge(scenes)
	merged.slot = slot
	merged.state = state
	merged.layout = layout
	merged.log[#merged.log + 1] = "lumen: the " .. layout .. " layout " .. (state == "combat" and "in combat, the combat calm on" or "out of combat")
		.. "; the guide and the tracker sit in the story slot (" .. math.floor(slot.left) .. ", " .. math.floor(slot.top) .. ", "
		.. math.floor(slot.width) .. " by " .. math.floor(slot.height) .. "), where the setup asks the player to put them"
	for _, line in ipairs(log) do
		merged.log[#merged.log + 1] = line
	end
	return merged
end

return Lumen
