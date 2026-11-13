-- _lumen.lua: the Lumen Rails HUD in the two states the mockup boards draw (handoff/arena2/parent: hud-questing.png
-- and hud-combat.png), on top of hud.lua. Every module renders where the Lumen layout puts it, with the module
-- settings Layout > Apply writes for the layout (Setup.Layouts.Settings): bar 1 alone, the pet and stance sockets in
-- two rows, the threat card in Tank only. The story slot (Setup.Layouts.Slot) holds the RestedXP guide's card where
-- the skin's story rail puts it, and the quests stand in their own column beside it, the tracker at the anchor Apply
-- writes into the "KstyleUI <layout>" Edit Mode layout (Hud.StoryTracker), with RestedXP loaded.
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

-- The mockup's questing board: the seven quests the player tracks, of which the quest card shows three and scrolls
-- to the rest, with Forever's level on each title; and the party around the player.
Lumen.QUESTS = {
	{ title = "Threat from Below", level = 7, objectives = { "Ready for turn-in" }, complete = true, questID = 201, superTracked = true },
	{ title = "Break a Few Eggs", level = 8, objectives = { "Taillasher Egg 0/3" }, questID = 202 },
	{ title = "Encroachment", level = 9, objectives = { "Bloodtalon Scythemaw 0/16" }, questID = 203 },
	{ title = "The Admiral's Orders", level = 8, objectives = { "Speak to Admiral Proudmoore 0/1" }, questID = 204 },
	{ title = "Dark Storms", level = 9, objectives = { "Burning Blade Medallion 0/1" }, questID = 205 },
	{ title = "Thazz'ril's Pick", level = 7, objectives = { "Thazz'ril's Pick 0/1" }, questID = 206 },
	{ title = "Carry Your Weight", level = 9, objectives = { "Canvas Scraps 2/8", "Kul Tiras Sailor slain 3/10" }, questID = 207 },
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
	-- The boss's plate stands left of the boss column, which moved 75 units in beside the quest card (KSTY-33).
	plateX = 900,
}

-- Preset(layout) -> the layout's module settings as saved sections ({ [module] = { nested } }), its story slot and the
-- quest card's column beside the guide's card
-- in screen units ({ left, top, width, height }, y down from the top), from the addon's own Setup.Layouts. The scenes
-- render at the Interface size KstyleUI ships, where the root is Layouts.HEIGHT units tall on the screen's 1080.
function Lumen.Preset(layout)
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	local settings = Hud.PresetSettings(layout)
	local rootHeight = Layouts.HEIGHT
	local slot = Layouts.Slot(layout, rootHeight)
	local k = HEIGHT / rootHeight
	local width = K.Scale.CanvasWidth(Common.SCREEN.width, Common.SCREEN.height)
	local origin = (Common.SCREEN.width - width) / 2 / Common.SCREEN.height * HEIGHT
	local function Screen(spec)
		local l, _, r, t = Layouts.Rect(spec, spec, rootHeight * width / Common.SCREEN.height, rootHeight)
		return { left = origin + l * k, top = (rootHeight - t) * k, width = (r - l) * k, height = spec.height * k }
	end
	return settings, Screen(slot), slot, Layouts.Sizes(layout), Screen(Layouts.Story(layout, rootHeight, true).quests)
end

-- Rail(built, R) -> the glass of every rail card, top to bottom: { name, left, top, width, height } in screen units,
-- from the frames each module drew (the party card and chat on the left rail; RestedXP's steps, head and footer and the
-- quests in the right rail's story slot), so a test can hold each rail to one edge and one width.
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
	if group then
		add("party", Hud.envs[group.scene], cards and cards.party and cards.party.frame)
	end
	local f = R.rxp.RXPFrame
	local parts = R.K.Skin.Parts(f)
	add("guide", R.env, parts and parts.backdrop)
	local env = Hud.envs[tracker.scene]
	if tracker.ns.Quests.Active() then
		add("quests", env, tracker.ns.Quests.Parts().glass)
	else
		parts = env.KstyleUI.Skin.Parts(tracker.extra)
		add("quests", env, parts and parts.backdrop)
	end
	add("chat", Hud.envs[chat.scene], chat.ns.Panel.Glass())
	table.sort(out, function(a, b)
		return a.top < b.top
	end)
	return out
end

-- Elements(built) -> every Layout element a running module placed, by key: { module, left, bottom, width, height } in
-- root units from the root's bottom left, as Layout.Rect gives them, for scenes/_reference.lua's measurements.
function Lumen.Elements(built)
	local out = {}
	for name, b in pairs(built) do
		local env = b.scene and Hud.envs[b.scene]
		local K = env and env.KstyleUI
		if K and K.Layout and K.Layout.Elements then
			for _, e in ipairs(K.Layout.Elements()) do
				if e.live and not out[e.key] then
					local left, bottom, width, height = K.Layout.Rect(e.key)
					if left then
						out[e.key] = { module = name, left = left, bottom = bottom, width = width, height = height }
					end
				end
			end
		end
	end
	return out
end

function Lumen.Build(state, opts)
	opts = opts or {}
	local layout = opts.layout or "DPS"
	local settings, slot, _, sizes, column = Lumen.Preset(layout)
	local _, spec = Hud.Class(opts)
	local damage = {}
	for i, row in ipairs(Lumen.DAMAGE[state]) do
		damage[i] = { row[1] or spec.name, row[2], row[3] }
	end
	local base = {
		class = opts.class,
		layout = layout,
		settings = not opts.applyPreset and settings or nil,
		applyPreset = opts.applyPreset,
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
	-- opts.state overlays the board's state field by field (scenes/_reference.lua: the owner's picture).
	for k, v in pairs(opts.state or {}) do
		base[k] = v
	end
	base.sizes = {}
	if not opts.applyPreset then
		for key, size in pairs(sizes) do
			base.sizes[key] = { size.width, size.height }
		end
	end
	local scenes, log = {}, {}
	base.trackerAnchor = Hud.StoryTracker(layout, true)
	-- RestedXP is loaded, so the guide's card holds the story slot and the quests stand in their own column beside
	-- it (KSTY-33): the two cards render in separate environments and need nothing from each other.
	base.withGuide = true
	local names = { "chat", "minimap", "auras", "databars", "tracker", "groupframes", "meters", "unitframes", "actionbars", "cooldowns" }
	if state == "combat" then
		table.insert(names, 1, "nameplates")
	else
		names[#names + 1] = "lootfeed"
	end
	names = opts.modules or names
	local built, at = {}, {}
	for _, name in ipairs(names) do
		local scene, ns, extra = Hud.Module(name, base)
		scenes[#scenes + 1] = scene
		built[name] = { scene = scene, ns = ns, extra = extra }
		at[name] = #scenes
	end
	-- The minimap's corners and the data bars keep clear of the Layout elements beside them, which the game finds in
	-- its one Layout registry; each module builds in its own environment here, so a module is drawn again with every
	-- module's elements in reach when they change its pieces.
	Hud.layoutElements = {}
	for _, name in ipairs(names) do
		local env = Hud.envs[built[name].scene]
		local Layout = env and env.KstyleUI and env.KstyleUI.Layout
		if Layout then
			for _, element in ipairs(env.KstyleUI.Setup.Layouts.ELEMENTS) do
				local el = Layout.Element(element.key)
				if el and el.frame and not Hud.layoutElements[element.key] then
					Hud.layoutElements[element.key] = { el = el, live = Layout.Live(element.key) }
				end
			end
		end
	end
	for _, name in ipairs(names) do
		local env = Hud.envs[built[name].scene]
		local handles = env and env._ornamentHandles or {}
		local function placed()
			local out = {}
			for _, handle in ipairs(handles) do
				if handle.neighbours then
					handle:Restyle()
					for i = 1, handle.used do
						local t = handle.textures[i]
						out[#out + 1] = table.concat({ tostring(t:GetTexture()), tostring(t:GetLeft()), tostring(t:GetTop()), tostring(t:GetWidth()) }, " ")
					end
				end
			end
			return table.concat(out, "\n")
		end
		local before = placed()
		if before ~= "" then
			Hud.ShareLayout(env)
			if placed() ~= before then
				local scene, ns, extra = Hud.Module(name, base)
				scenes[at[name]] = scene
				built[name] = { scene = scene, ns = ns, extra = extra }
				log[#log + 1] = "ornaments: " .. name .. " is drawn again with every module's Layout elements in reach, as the game's one Layout registry holds them"
			end
		end
	end
	Hud.layoutElements = nil
	local guide, R = Hud.Module("restedxp", base)
	table.insert(scenes, 1, guide)
	if state == "combat" then
		scenes[#scenes + 1] = (Encounter.Build(Hud, { layout = layout, guide = true, saved = Hud.Saved(base, "Skins") }))
	end
	local merged = Scene.Merge(scenes)
	if built.chat and built.tracker then
		merged.rail = Lumen.Rail(built, R)
	end
	if opts.elements then
		merged.elements = Lumen.Elements(built)
	end
	merged.slot = slot
	merged.column = column
	merged.state = state
	merged.layout = layout
	merged.log[#merged.log + 1] = "lumen: the " .. layout .. " layout " .. (state == "combat" and "in combat, the combat calm on" or "out of combat")
		.. "; the story slot (" .. math.floor(slot.left) .. ", " .. math.floor(slot.top) .. ", " .. math.floor(slot.width) .. " by "
		.. math.floor(slot.height) .. ") holds the guide's card where the skin's rail puts it, and the quests stand in their own column beside it"
	for _, line in ipairs(log) do
		merged.log[#merged.log + 1] = line
	end
	return merged
end

return Lumen
