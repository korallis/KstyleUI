-- _lumen.lua: the Lumen Rails HUD in the two states the mockup boards draw (handoff/arena2/parent: hud-questing.png
-- and hud-combat.png), on top of hud.lua. Every module renders where the Lumen layout puts it, with the module
-- settings Layout > Apply writes for the layout (Setup.Layouts.Settings): bar 1 alone, the pet and stance sockets in
-- two rows, the threat card in Tank only. The story slot (Setup.Layouts.Slot) holds what Apply places there: the
-- RestedXP guide where the skin's story rail puts it, and the quest tracker at the anchor Apply writes into the
-- "KstyleUI <layout>" Edit Mode layout (Hud.StoryTracker), with RestedXP loaded, so the tracker takes the lower half.
--
--   local Lumen = dofile("Tools/render/scenes/_lumen.lua")
--   local scene = Lumen.Build("questing")     -- or "combat"; Lumen.Build(state, { layout = "Tank" })
--
-- questing: out of combat with no target, three quests and the guide in the story slot, a party of three, the last
-- fight's meter. The guide's step list is folded on the rail, by RestedXP's own rule, so the rail reads path, quests.
-- combat: in combat with a party of five, the boss card, and the boss as the target, casting; the combat calm has
-- faded the slow cards (chat, the lens, the readout and menu, the XP line, the guide and the tracker) to 30%; the boss
-- emote that announces the cast shows on the encounter warnings lane above the target (_encounter.lua).
-- questing: the pointer rests on the player's meter row, so the card shows the last fight's top three spells.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Encounter = dofile("Tools/render/scenes/_encounter.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Scene = Common.Scene

local Lumen = {}

local HEIGHT = 1080

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
-- The player's spells in the last fight, which the questing board's meter hover lists (its top three): a warrior's
-- 18,000 damage, as Lumen.DAMAGE.questing gives the player.
Lumen.SPELLS = {
	{ 12294, "Mortal Strike", 132355, 7900 },
	{ 1464, "Slam", 132340, 5200 },
	{ 1680, "Whirlwind", 132369, 3100 },
	{ 772, "Rend", 132155, 1800 },
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
	local settings = Hud.PresetSettings(layout)
	local slot = Layouts.Slot(layout)
	local width = HEIGHT * Common.SCREEN.width / Common.SCREEN.height
	local l, _, r, t = Layouts.Rect(slot, slot, width, HEIGHT)
	return settings, { left = l, top = HEIGHT - t, width = r - l, height = slot.height }, slot, Layouts.Sizes(layout)
end

-- Rail(built, R) -> the glass of every card on the left rail, top to bottom: { name, left, top, width, height } in
-- screen units, from the frames each module drew (the party card, RestedXP's steps, head and footer, the quests,
-- chat), so a test can hold them to one left edge and one width.
function Lumen.Rail(built, R)
	local out = {}
	local function add(name, env, frame)
		if env and frame and frame:IsShown() then
			local x, y, w, h = Scene.Rect(env, frame)
			if x then
				out[#out + 1] = { name = name, left = x, top = y, width = w, height = h }
			end
		end
	end
	local group, chat, tracker = built.groupframes, built.chat, built.tracker
	local cards = group and group.ns.Headers and group.ns.Headers.cards
	add("party", Hud.envs[group.scene], cards and cards.party and cards.party.frame)
	local f = R.rxp.RXPFrame
	local parts = R.K.Skin.Parts(f)
	add("guide", R.env, parts and parts.backdrop)
	local env = Hud.envs[tracker.scene]
	parts = env.KstyleUI.Skin.Parts(tracker.extra)
	add("quests", env, parts and parts.backdrop)
	add("chat", Hud.envs[chat.scene], chat.ns.Panel.Glass())
	table.sort(out, function(a, b)
		return a.top < b.top
	end)
	return out
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
		base.meterHover = Lumen.SPELLS
		base.playerCast = false
	end
	base.menus = true
	base.sizes = {}
	for key, size in pairs(sizes) do
		base.sizes[key] = { size.width, size.height }
	end
	local scenes, log = {}, {}
	base.trackerAnchor = Hud.StoryTracker(layout, true)
	-- Apply placed the tracker under the guide, so the skin docks the quests into the guide's card: the guide's
	-- glass runs down to the quests' foot, its footer hugs the quests' cap and the tracker's own glass yields
	-- (Rail.Place does this in the game from the tracker's Edit Mode anchor; the two modules render in separate
	-- environments, so the restedxp module docks to a stand-in for the tracker skin's fit frame).
	base.trackerDocked = base.trackerAnchor ~= nil
	local names = { "chat", "minimap", "auras", "databars", "tracker", "groupframes", "meters", "unitframes", "actionbars", "cooldowns" }
	if state == "combat" then
		table.insert(names, 1, "nameplates")
	end
	local built = {}
	for _, name in ipairs(names) do
		local scene, ns, extra = Hud.Module(name, base)
		scenes[#scenes + 1] = scene
		built[name] = { scene = scene, ns = ns, extra = extra }
	end
	if base.trackerDocked then
		local tracker = built.tracker
		local env = Hud.envs[tracker.scene]
		local fit = tracker.ns.Tracker.Fit()
		local _, top, _, height = Scene.Rect(env, fit)
		base.dockBottom = top and (HEIGHT - (top + height)) or nil
		base.dockTop = top and (HEIGHT - top) or nil
	end
	local guide, R = Hud.Module("restedxp", base)
	table.insert(scenes, 1, guide)
	if state == "combat" then
		scenes[#scenes + 1] = (Encounter.Build(Hud, { layout = layout, guide = true, saved = Hud.Saved(base, "Skins") }))
	end
	local merged = Scene.Merge(scenes)
	merged.rail = Lumen.Rail(built, R)
	merged.slot = slot
	merged.state = state
	merged.layout = layout
	merged.log[#merged.log + 1] = "lumen: the " .. layout .. " layout " .. (state == "combat" and "in combat, the combat calm on" or "out of combat")
		.. "; the story slot (" .. math.floor(slot.left) .. ", " .. math.floor(slot.top) .. ", " .. math.floor(slot.width) .. " by "
		.. math.floor(slot.height) .. ") holds the guide where the skin's rail puts it and the tracker at Apply's Edit Mode anchor"
	for _, line in ipairs(log) do
		merged.log[#merged.log + 1] = line
	end
	return merged
end

return Lumen
