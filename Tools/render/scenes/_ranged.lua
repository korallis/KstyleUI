-- _ranged.lua: the hunter's, mage's and warlock's crest tracker stories (KstyleUI_ActionBars/SlabRanged.lua), which
-- _trackers.lua plays for those classes under RENDER_TRACKERS: steel (every piece known, nothing up, no pet, empty
-- bags), lit (the story at its LIT time, every piece up) or moment, the story RENDER_TRACKERS_T seconds in (6 when
-- unset). Blizzard's aura slots (Tools/regression/aura_slots.lua) and the addon's own bag and pet handlers take every
-- change at its own time, so a run of RENDER_TRACKERS_T frames is the story as a clip. RENDER_TRACKERS_BUILD picks
-- another build or level band, whose fields replace the class's: a hunter's rail (the five-seat cooldown rail: Intimidation
-- cast at 1 s, a fire trap at 2 s (ready again at 17 s), Rapid Fire at 4 s (its buff to 19 s), the trinket used at 7 s and Bestial Wrath at
-- 9 s (the pet's buff to 27 s), each cooling only from its cast), melee or level 8 build, a mage's arcane,
-- fire (Fire Vulnerability at three stacks), frost (Winter's Chill embers) or level 10 build, a warlock's felhunter (Spell Lock
-- cooling), imp, voidwalker or succubus (that demon out, chosen through the pet's spellbook as the felhunter's Spell Lock
-- chooses it), curses (each of the five curses on the target in turn, one at a time as
-- the game allows: RENDER_TRACKERS=moment at RENDER_TRACKERS_T 1.5, 3.5, 5.5, 7.5 and 9.5), sacrifice (Demonic Sacrifice of the Imp, Death Coil cooling;
-- every summon known, so RENDER_TRACKERS_SWAP=18789:18790, 18789:18791 or 18789:18792 sacrifices the Voidwalker, Succubus or Felhunter instead), nodemon or level 8 build, each caster's sigils build (every
-- cooldown sigil of the class up at once: the mage's Arcane Power, Presence of Mind, Combustion, Evocation and Ice Block, the warlock's
-- Amplify Curse, Fel Domination, Shadow Ward and the Voidwalker's Sacrifice), the hunter's bite (Mongoose Bite ready) or raptor
-- (no Aspect yet; Raptor Strike's cooldown ends at 6 s, so RENDER_TRACKERS=moment RENDER_TRACKERS_T=6.05 catches its flash), or each class's breakout story (and the mage's
-- breakout_fire), timed as the break-out design's clips: an aura's warn time puts it in its pandemic window, a usable
-- spell's window and the pet's health steps and leaving time play out on the clock. RENDER_TRACKERS_OFF=1 turns the class's
-- tracker switches off first, for a pixel diff against a build without them. RENDER_TRACKERS_SWAP=from:to[,from:to] plays the
-- story with other aura spell IDs, so one seat shows each of its choices: 13165:13163 perches Aspect of the Monkey for
-- the Hawk, 1978:3034 burns Viper Sting for Serpent Sting. RENDER_PET_MOOD=1|2|3 sets the hunter pet's happiness (Unhappy,
-- Content, Happy) in place of the story's own, so the haunch shows or goes; RENDER_PET_DEAD=1 lays the pet dead, so its perch shows the red
-- hound. The hunter's story also carries Trueshot Aura from 3 s and Track Beasts from 0.2 s on a beast target, for Improved Tracking's compass. RENDER_CAST_ON_FRAME=off gives the action bars the
-- centred cast bars' layout elements the unit frames register in the game, so the hunter's rail takes its own flat row.
-- RENDER_TRACKERS_MOTION=calm|off sets Medallions motion before the story, so Calm and Off show what each keeps of it. The hunter's
-- default story keeps the cooldown rail on, so Rapid Fire at 4 s feeds the rail and the crest's gust waits for Quick Shots at 5 s:
-- a gust still or clip starts after 5 s and reads the strip across the ring's inner band, not the rail. A mage's crest
-- is drawn as players asked for it, with Blizzard's Cooldown Manager switched off: render every mage story and build (low, arcane,
-- fire, frost, sigils, breakout) with RENDER_COOLDOWN_VIEWER=off (hud.lua).
local Slots = dofile("Tools/regression/aura_slots.lua")

local Ranged = {}

local STORIES = {
	HUNTER = {
		lit = 6.5,
		known = { 13165, 883, 1130, 1978, 19552, 3045, 19263, 19574, 2643, 1495, 75, 19506, 24293 },
		usable = { [2643] = 3 },
		tracking = { 1494, at = 0.2 },
		creature = "Beast",
		swings = { 0.5, 3.3, 6.1 },
		icons = { [13165] = 136076, [13163] = 132159, [883] = 132161, [1130] = 132212, [1978] = 132204, [3045] = 132208, [19263] = 132369,
			[19574] = 132127, [19306] = 132336, [2973] = 132223, [3044] = 132218, [2643] = 132330, [1495] = 132215, [75] = 135489,
			[19506] = 132329 },
		pet = { missing = 0.35, mood = 2 },
		auras = {
			{ unit = "player", id = 13165, icon = 136076, at = 0.5 },
			{ unit = "target", id = 1130, icon = 132212, at = 1, duration = 120, harmful = true },
			{ unit = "target", id = 1978, icon = 132204, at = 2, duration = 15, harmful = true },
			{ unit = "player", id = 20906, icon = 132329, at = 3 },
			{ unit = "player", id = 3045, icon = 132208, at = 4, duration = 15 },
			{ unit = "player", id = 6150, icon = 132347, at = 5, duration = 12 },
			{ unit = "pet", id = 136, icon = 132179, at = 6, duration = 15 },
			{ unit = "pet", id = 19574, icon = 132127, at = 6.2, duration = 18 },
		},
		builds = {
			rail = { known = { 13165, 883, 1130, 1978, 3045, 19574, 19577, 14305, 2643, 75 }, cooling = { [19577] = { 1, 60 }, [14305] = { 2, 15 }, [3045] = { 4, 300 }, [19574] = { 9, 120 } },
				casts = { { 1, 19577 }, { 2, 14305 }, { 4, 3045 }, { 7, 9002 }, { 9, 19574 } }, trinket = { item = 5002, spell = 9002, used = 7, cooldown = 120 },
				auras = { { unit = "player", id = 13165, icon = 136076, at = 0.5 }, { unit = "player", id = 3045, icon = 132208, at = 4, duration = 15 },
					{ unit = "pet", id = 19574, icon = 132127, at = 9, duration = 18 } } },
			melee = { known = { 13163, 883, 1130, 1978, 19306, 1495, 19263, 75 }, usable = { [19306] = 3 },
				auras = { { unit = "player", id = 13163, icon = 132159, at = 0.5 }, { unit = "target", id = 1978, icon = 132204, at = 2, duration = 15, harmful = true },
					{ unit = "player", id = 19263, icon = 132369, at = 4, duration = 10 } } },
			breakout = { known = { 13165, 883, 1130, 1978, 19306, 2643, 75 }, usable = { [2643] = { 4.8, 6.1 }, [19306] = { 8.3, 9.6 } }, swings = { 1.2, 4, 6.8, 9.6 },
				pet = { mood = 3, steps = { { 0, 0.1 }, { 6.6, 0.5 }, { 7.6, 0.4 }, { 8.2, 0.25 }, { 8.8, 0.1 } } },
				auras = { { unit = "player", id = 13165, icon = 136076, at = 1.5 },
					{ unit = "target", id = 1130, icon = 132212, at = 2.5, duration = 8.4, warn = 10, harmful = true },
					{ unit = "target", id = 1978, icon = 132204, at = 3.5, duration = 6.1, warn = 8.1, harmful = true },
					{ unit = "pet", id = 136, icon = 132179, at = 7.3, duration = 2.1 } } },
			bite = { usable = { [1495] = 3 } },
			raptor = { known = { 1130, 1978, 2973, 75 }, pet = false, cooling = { [2973] = { 5, 1 } }, usable = {},
				auras = { { unit = "target", id = 1130, icon = 132212, at = 1, duration = 120, harmful = true } } },
			low = { known = { 13163, 1130, 1978, 2973, 3044, 75 }, pet = false, cooling = { [3044] = { 5, 6 } }, usable = {},
				auras = { { unit = "player", id = 13163, icon = 132159, at = 0.5 }, { unit = "target", id = 1130, icon = 132212, at = 1, duration = 120, harmful = true },
					{ unit = "target", id = 1978, icon = 132204, at = 2, duration = 15, harmful = true } } },
		},
	},
	MAGE = {
		lit = 5,
		known = { 7302, 759, 11426, 11213, 118, 116, 12042, 11958, 2139, 122, 1326079, 2136 },
		cooling = { [1326079] = { 4.5, 6 } },
		icons = { [7302] = 135843, [168] = 135843, [1459] = 135932, [118] = 136071, [116] = 135846, [12042] = 136048, [11958] = 135841,
			[2139] = 135856, [122] = 135848, [1326079] = 136096, [2136] = 135807, [11095] = 135827, [11180] = 135836 },
		items = { [5514] = { icon = 134104, steps = { { 0, 1 } }, used = 6, cooldown = 120 } },
		auras = {
			{ unit = "player", id = 7302, icon = 135843, at = 0.5, duration = 1800 },
			{ unit = "target", id = 116, icon = 135846, at = 1, duration = 9, harmful = true },
			{ unit = "player", id = 11426, icon = 135988, at = 2, duration = 60 },
			{ unit = "target", id = 118, icon = 136071, at = 3, duration = 50, harmful = true },
			{ unit = "target", id = 122, icon = 135848, at = 3.5, duration = 8, harmful = true },
			{ unit = "player", id = 12536, icon = 136170, at = 4, duration = 15 },
			{ unit = "player", id = 12042, icon = 136048, at = 4.5, duration = 15 },
		},
		builds = {
			arcane = {},
			sigils = { known = { 7302, 759, 118, 116, 12042, 12043, 11129, 12051, 11958 }, cooling = {},
				auras = { { unit = "player", id = 12042, icon = 136048, at = 1, duration = 15 }, { unit = "player", id = 12043, icon = 136031, at = 1.5, duration = 30 },
					{ unit = "player", id = 11129, icon = 135824, at = 2, duration = 15 }, { unit = "player", id = 12051, icon = 136075, at = 2.5, duration = 8 },
					{ unit = "player", id = 11958, icon = 135865, at = 3, duration = 10 } } },
			breakout = { known = { 7302, 759, 118, 116, 2139, 122, 1326079 }, cooling = { [1326079] = { 4.6, 4 }, [2139] = { 5.6, 5.6 } },
				items = { [5514] = { icon = 134104, steps = { { 0, 1 } }, used = 7.4, cooldown = 120 } },
				auras = { { unit = "player", id = 7302, icon = 135843, at = 1.4, duration = 9.5, warn = 10 },
					{ unit = "target", id = 118, icon = 136071, at = 2.4, duration = 7, warn = 8.6, harmful = true },
					{ unit = "target", id = 122, icon = 135848, at = 3.6, duration = 3.4, warn = 6, harmful = true } } },
			breakout_fire = { known = { 7302, 759, 11095, 118, 116, 2139, 122, 11119 }, cooling = {},
				auras = { { unit = "target", id = 133, icon = 135812, at = 1.6, duration = 8.5, warn = 9.2, harmful = true },
					{ unit = "target", id = 133, icon = 135812, at = 6.2, duration = 3.9, warn = 9.2, harmful = true },
					{ unit = "target", id = 22959, icon = 135818, at = 2.4, duration = 0.8, harmful = true, count = 1 },
					{ unit = "target", id = 22959, icon = 135818, at = 3.2, duration = 0.8, harmful = true, count = 2 },
					{ unit = "target", id = 22959, icon = 135818, at = 4, duration = 0.8, harmful = true, count = 3 },
					{ unit = "target", id = 22959, icon = 135818, at = 4.8, duration = 0.8, harmful = true, count = 4 },
					{ unit = "target", id = 22959, icon = 135818, at = 5.6, duration = 3.4, warn = 8.2, harmful = true, count = 5 } } },
			fire = { known = { 7302, 759, 11426, 11095, 118, 116, 11129, 2139, 122, 11119 },
				auras = { { unit = "player", id = 7302, icon = 135843, at = 0.5, duration = 1800 }, { unit = "target", id = 22959, icon = 135818, at = 1, duration = 30, harmful = true, count = 3 },
					{ unit = "target", id = 412538, icon = 135818, at = 2, duration = 4, harmful = true }, { unit = "target", id = 122, icon = 135848, at = 3.5, duration = 8, harmful = true },
					{ unit = "player", id = 11129, icon = 135824, at = 4, duration = 15 } } },
			frost = { known = { 7302, 759, 11426, 11180, 118, 116, 11958, 2139, 122 },
				auras = { { unit = "player", id = 7302, icon = 135843, at = 0.5, duration = 1800 }, { unit = "target", id = 12579, icon = 135836, at = 1, duration = 15, harmful = true, count = 3 },
					{ unit = "player", id = 11426, icon = 135988, at = 2, duration = 60 }, { unit = "target", id = 116, icon = 135846, at = 3, duration = 9, harmful = true },
					{ unit = "target", id = 12494, icon = 135842, at = 3.5, duration = 5, harmful = true } } },
			low = { known = { 168, 1459, 116, 118, 2136, 122 }, items = {}, cooling = { [2136] = { 4, 8 } },
				auras = { { unit = "player", id = 168, icon = 135843, at = 0.5, duration = 1800 }, { unit = "player", id = 1459, icon = 135932, at = 0.5, duration = 1800 },
					{ unit = "target", id = 116, icon = 135846, at = 1, duration = 9, harmful = true }, { unit = "target", id = 118, icon = 136071, at = 3, duration = 50, harmful = true } } },
		},
	},
	WARLOCK = {
		lit = 5.5,
		known = { 172, 980, 348, 18265, 688, 6201, 18094, 1120, 18288, 706, 702, 1293817, 6366 },
		cooling = { [1293817] = { 4, 10 } },
		enchant = 1800,
		icons = { [172] = 136118, [980] = 136139, [348] = 135817, [18265] = 136188, [688] = 136218, [18288] = 136132, [706] = 136185, [687] = 136185,
			[702] = 136138, [1293817] = 135807, [6366] = 132386 },
		pet = { missing = 0.3 },
		items = { [5512] = { icon = 135230, steps = { { 0, 1 } } }, [6265] = { steps = { { 0, 2 }, { 3.5, 3 }, { 6, 2 } } } },
		auras = {
			{ unit = "target", id = 348, icon = 135817, at = 1, duration = 15, harmful = true },
			{ unit = "target", id = 702, icon = 136138, at = 1.5, duration = 120, harmful = true },
			{ unit = "target", id = 172, icon = 136118, at = 2, duration = 18, harmful = true },
			{ unit = "target", id = 980, icon = 136139, at = 3, duration = 24, harmful = true },
			{ unit = "target", id = 18265, icon = 136188, at = 4, duration = 30, harmful = true },
			{ unit = "player", id = 18288, icon = 136132, at = 4.5, duration = 30 },
			{ unit = "player", id = 17941, icon = 136200, at = 5, duration = 10 },
		},
		builds = {
			felhunter = { known = { 172, 980, 348, 18265, 691, 19244, 6201, 1120, 702, 1293817 }, cooling = { [19244] = { 4, 24 } } },
			breakout = { known = { 172, 980, 348, 18265, 691, 19244, 18788, 6201, 1120, 702, 1293817, 6789 }, cooling = { [19244] = { 4.8, 24 }, [6789] = { 0, 10.4 } },
				pet = { gone = 7.4, steps = { { 0, 0 }, { 5, 0.45 } } },
				items = { [5512] = { icon = 135230, steps = { { 0, 1 } }, used = 6.6, cooldown = 120 }, [6265] = { steps = { { 0, 3 } } } },
				auras = { { unit = "target", id = 348, icon = 135817, at = 1.5, duration = 7.9, warn = 8.6, harmful = true },
					{ unit = "target", id = 702, icon = 136138, at = 2.3, duration = 8.5, warn = 10, harmful = true },
					{ unit = "target", id = 172, icon = 136118, at = 3, duration = 8.2, harmful = true },
					{ unit = "target", id = 980, icon = 136139, at = 3.6, duration = 7.6, harmful = true },
					{ unit = "target", id = 18265, icon = 136188, at = 4.2, duration = 7, harmful = true },
					{ unit = "player", id = 18792, icon = 136218, at = 7.4, duration = 1800 } } },
			sacrifice = { known = { 172, 980, 348, 18265, 688, 697, 712, 691, 18788, 6201, 1120, 702, 6789 }, pet = false, cooling = { [6789] = { 4, 15 } }, auras = {
				{ unit = "player", id = 18789, icon = 136218, at = 0.5, duration = 1800 }, { unit = "target", id = 348, icon = 135817, at = 1, duration = 15, harmful = true },
				{ unit = "target", id = 702, icon = 136138, at = 1.5, duration = 120, harmful = true }, { unit = "target", id = 172, icon = 136118, at = 2, duration = 18, harmful = true } } },
			sigils = { known = { 172, 702, 697, 18288, 18708, 6229, 706 }, pet = false, cooling = {},
				auras = { { unit = "player", id = 18288, icon = 136132, at = 1, duration = 30 }, { unit = "player", id = 18708, icon = 237564, at = 1.5, duration = 15 },
					{ unit = "player", id = 6229, icon = 136121, at = 2, duration = 30 }, { unit = "player", id = 7812, icon = 136190, at = 2.5, duration = 30 } } },
			imp = { known = { 172, 980, 348, 688, 702 }, petSpells = { 3110 } },
			voidwalker = { known = { 172, 980, 348, 697, 702 }, petSpells = { 3716 } },
			succubus = { known = { 172, 980, 348, 712, 702 }, petSpells = { 7814 } },
			curses = { lit = 1.5, known = { 172, 348, 688, 702, 704, 1714, 440892, 18223 }, petSpells = { 3110 }, cooling = {},
				auras = { { unit = "target", id = 702, icon = 136138, at = 1, duration = 2, harmful = true }, { unit = "target", id = 704, icon = 136225, at = 3, duration = 2, harmful = true },
					{ unit = "target", id = 1714, icon = 136140, at = 5, duration = 2, harmful = true }, { unit = "target", id = 440892, icon = 136130, at = 7, duration = 2, harmful = true },
					{ unit = "target", id = 18223, icon = 136162, at = 9, duration = 2, harmful = true } } },
			nodemon = { pet = false, auras = {
				{ unit = "player", id = 706, icon = 136185, at = 0.5, duration = 1800 }, { unit = "target", id = 348, icon = 135817, at = 1, duration = 15, harmful = true },
				{ unit = "target", id = 172, icon = 136118, at = 2, duration = 18, harmful = true }, { unit = "player", id = 17941, icon = 136200, at = 5, duration = 10 } } },
			low = { known = { 172, 980, 348, 688, 687, 702 }, items = {}, cooling = {}, enchant = false,
				auras = { { unit = "player", id = 687, icon = 136185, at = 0.5, duration = 1800 }, { unit = "target", id = 348, icon = 135817, at = 1, duration = 15, harmful = true },
					{ unit = "target", id = 172, icon = 136118, at = 2, duration = 18, harmful = true }, { unit = "target", id = 980, icon = 136139, at = 3, duration = 24, harmful = true },
					{ unit = "target", id = 702, icon = 136138, at = 1.5, duration = 120, harmful = true } } },
		},
	},
}

local SWAP = {}
for from, to in (os.getenv("RENDER_TRACKERS_SWAP") or ""):gmatch("(%d+):(%d+)") do
	SWAP[tonumber(from)] = tonumber(to)
end

local function Of(class)
	local s = STORIES[class]
	local build = s and s.builds[os.getenv("RENDER_TRACKERS_BUILD") or ""]
	local story = build and setmetatable(build, { __index = s }) or s
	if story and next(SWAP) and not rawget(story, "swapped") then
		local auras = {}
		for i, a in ipairs(story.auras) do
			auras[i] = setmetatable({ id = SWAP[a.id] or a.id }, { __index = a })
		end
		story.auras, story.swapped = auras, true
	end
	return story
end

function Ranged.Story(class)
	local story = rawget(_G, "RENDER_TRACKERS") or os.getenv("RENDER_TRACKERS")
	if not (story and story ~= "" and STORIES[class]) then return nil end
	return story, story == "steel" and -1 or story == "lit" and Of(class).lit or tonumber(os.getenv("RENDER_TRACKERS_T") or "") or 6
end

-- Install(env, class) gives the stub game the build's spells, their icons, the aura slots, the bags and the pet; the
-- story's clock (env._story) moves them.
function Ranged.Install(env, class)
	local s = Of(class)
	if not env._slotContainers then Slots.Install(env) end
	env._story = -1
	local known = {}
	for _, id in ipairs(s.known) do known[id] = true end
	env.C_SpellBook = env.C_SpellBook or {}
	env.Enum.SpellBookSpellBank = env.Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
	local before = env.C_SpellBook.IsSpellKnown
	local pets = {}
	for _, id in ipairs(s.petSpells or {}) do pets[id] = true end
	env.C_SpellBook.IsSpellKnown = function(id, bank)
		if bank == env.Enum.SpellBookSpellBank.Pet and pets[id] then return true end
		return known[id] == true or before ~= nil and before(id, bank)
	end
	local spell = env.C_Spell or {}
	env.C_Spell = spell
	local texture = spell.GetSpellTexture
	spell.GetSpellTexture = function(id) return s.icons[id] or texture and texture(id) end
	spell.IsSpellUsable = function(id)
		local at = (s.usable or {})[id]
		local from, to = type(at) == "table" and at[1] or at, type(at) == "table" and at[2] or math.huge
		return at ~= nil and env._story >= from and env._story < to, false
	end
	spell.GetSpellCooldown = function(id)
		local c = (s.cooling or {})[id]
		return { isActive = c ~= nil and env._story >= c[1] and env._story < c[1] + c[2], isOnGCD = false }
	end
	spell.GetSpellCooldownDuration = function(id)
		local c = (s.cooling or {})[id]
		local start = c and env._story >= c[1] and env._story < c[1] + c[2] and (env._now or 0) - (env._story - c[1])
		return start and { start = start, finish = start + c[2] } or { start = 0, finish = 0 }
	end
	local trinket = s.trinket
	if trinket then
		env.GetInventoryItemID = function(_, slot) return slot == 13 and trinket.item or nil end
		env.C_Item = env.C_Item or {}
		env.C_Item.GetItemSpell = function(id) if id == trinket.item then return "Use", trinket.spell end end
		env.GetInventoryItemCooldown = function(_, slot)
			if slot == 13 and env._story >= trinket.used and env._story < trinket.used + trinket.cooldown then
				return env._now - (env._story - trinket.used), trinket.cooldown, 1, false
			end
			return 0, 0, 1, false
		end
	end
	local items = s.items or {}
	env.C_Item = env.C_Item or {}
	env.C_Item.GetItemCount = function(id)
		local n = 0
		for _, step in ipairs(items[id] and items[id].steps or {}) do
			if step[1] <= env._story then n = step[2] end
		end
		return n
	end
	env.C_Item.GetItemIconByID = function(id) return items[id] and items[id].icon or 134104 end
	env.C_Item.GetItemCooldown = function(id)
		local item = items[id]
		if item and item.used and item.used <= env._story then
			return env._now - (env._story - item.used), item.cooldown, true
		end
		return 0, 0, true
	end
	local tracking = s.tracking
	if tracking then
		local types = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid" }
		env.C_Minimap = env.C_Minimap or {}
		env.C_Minimap.GetNumTrackingTypes = function() return 1 end
		env.C_Minimap.GetTrackingInfo = function() return { name = "Tracking", spellID = tracking[1], active = env._story >= tracking.at } end
		env.UnitCreatureType = function(unit) if unit == "target" then return s.creature end end
		env.C_CreatureInfo = { GetCreatureTypeInfo = function(id) return types[id] and { name = types[id] } end }
	end
	local pet = s.pet
	local exists = env.UnitExists
	env.UnitExists = function(unit) if unit == "pet" then return pet and env._story >= 0 and env._story < (pet.gone or math.huge) or false end return exists(unit) end
	if pet then
		local dead = os.getenv("RENDER_PET_DEAD") == "1"
		env.UnitIsDead = function(unit) return unit == "pet" and dead end
		local health, most = env.UnitHealth, env.UnitHealthMax
		env.UnitHealth = function(unit, ...)
			if unit ~= "pet" then return health and health(unit, ...) end
			local missing = pet.missing or 0
			for _, step in ipairs(pet.steps or {}) do
				if step[1] <= env._story then missing = step[2] end
			end
			return 100 * (1 - missing)
		end
		env.UnitHealthMax = function(unit, ...) if unit == "pet" then return 100 end return most and most(unit, ...) end
		local mood = tonumber(os.getenv("RENDER_PET_MOOD") or "")
		env.C_PetInfo = { GetPetHappiness = function() return mood or pet.mood end }
	end
end

-- Play(env, K, ns, notes) runs the story up to its time, each change at its own time on the clock.
function Ranged.Play(env, K, ns, notes)
	local story, at = Ranged.Story(ns.class)
	if os.getenv("RENDER_TRACKERS_OFF") == "1" then
		for _, row in ipairs(ns.SlabTrackers.CLASSES[ns.class] or {}) do K.Options.Write("ActionBars", row.key, false) end
	end
	if (rawget(_G, "RENDER_CAST_ON_FRAME") or os.getenv("RENDER_CAST_ON_FRAME")) == "off" and not K.Layout.Live("unitframes.castbar.player") then
		for _, key in ipairs({ "unitframes.castbar.player", "unitframes.castbar.target" }) do
			K.Layout.Register(env.CreateFrame("Frame"), key, K.Setup.Layouts.Default(key))
		end
		ns.SlabTrackers.Update()
	end
	local motion = os.getenv("RENDER_TRACKERS_MOTION")
	if motion and motion ~= "" then
		K.Options.Write("Medallions", "motion", motion)
	end
	local s = Of(ns.class)
	local times = { -1, at }
	for _, a in ipairs(s.auras) do times[#times + 1], times[#times + 2], times[#times + 3] = a.at, a.at + (a.duration or at), a.warn end
	for _, step in ipairs(s.pet and s.pet.steps or {}) do times[#times + 1] = step[1] end
	times[#times + 1] = s.pet and s.pet.gone or nil
	for _, item in pairs(s.items or {}) do
		for _, step in ipairs(item.steps) do times[#times + 1] = step[1] end
		times[#times + 1] = item.used
	end
	for _, when in pairs(s.usable or {}) do
		times[#times + 1] = type(when) == "table" and when[1] or when
		times[#times + 1] = type(when) == "table" and when[2] or nil
	end
	for _, when in ipairs(s.swings or {}) do times[#times + 1] = when end
	for _, cast in ipairs(s.casts or {}) do times[#times + 1] = cast[1] end
	times[#times + 1] = s.trinket and s.trinket.used + s.trinket.cooldown or nil
	local ends = {}
	for _, c in pairs(s.cooling or {}) do
		times[#times + 1], ends[c[1] + c[2]] = c[1] + c[2], true
	end
	if s.enchant then
		Slots.Enchant(env, 1, { start = env._time - at - 600, duration = s.enchant })
	end
	table.sort(times)
	for i = #times, 2, -1 do
		if times[i] == times[i - 1] then table.remove(times, i) end
	end
	local clock, now = env.GetTime, env._now
	env.GetTime = function() return env._now end
	-- The ring-edge ember arms from the aura's own times, which the game answers out of combat.
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
		for _, a in ipairs(env._slotAuras[unit] or {}) do
			if a.id == id and a.duration then
				return { auraInstanceID = a.id, expirationTime = a.start + a.duration, duration = a.duration, sourceUnit = "player" }
			end
		end
	end
	for _, when in ipairs(times) do
		if when <= at and when > (env._clip and env._clipFrom or -math.huge) then
			env._story, env._now = when, env._time - (at - when)
			local units = { player = {}, target = {}, pet = {} }
			for _, a in ipairs(s.auras) do
				if a.at <= when and (not a.duration or when < a.at + a.duration) then
					a.start = env._time - (at - a.at)
					a.pandemic = a.warn ~= nil and when >= a.warn or nil
					table.insert(units[a.unit], a)
				end
			end
			for unit, list in pairs(units) do
				Slots.Set(env, unit, list)
				env.FireEvent("UNIT_AURA", unit)
			end
			env.FireEvent("UNIT_PET", "player")
			env.FireEvent("UNIT_HEALTH", "pet")
			env.FireEvent("MINIMAP_UPDATE_TRACKING")
			env.FireEvent("BAG_UPDATE_DELAYED")
			env.FireEvent("BAG_UPDATE_COOLDOWN")
			env.FireEvent("SPELL_UPDATE_USABLE")
			env.FireEvent("SPELL_UPDATE_COOLDOWN")
			-- A clip's engine ends each cooldown itself (Tools/render/clip.lua); a still ends here only the shown timers, nested ones included, whose own
			-- duration object runs out at this moment.
			local form = ends[when] and not env._clip and ns.SlabTrackers.state.form
			ends[when] = nil
			local function Expire(frame)
				local fed = frame._type == "Cooldown" and frame:IsVisible() and (frame._state.CooldownFromDurationObject or {})[1]
				local done = type(fed) == "table" and fed.finish and math.abs(fed.finish - env._now) < 1e-6 and frame:GetScript("OnCooldownDone")
				if done then done(frame) end
				for _, kid in ipairs(frame._kids or {}) do Expire(kid) end
			end
			for _, p in pairs(form and form.pieces or {}) do Expire(p) end
			for _, swing in ipairs(s.swings or {}) do
				if swing == when then env.FireEvent("PLAYER_SWING", 2.8, 2) end
			end
			for _, cast in ipairs(s.casts or {}) do
				if cast[1] == when then env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "story", cast[2]) end
			end
		end
	end
	env.GetTime, env._now = clock, now
	local build = os.getenv("RENDER_TRACKERS_BUILD")
	notes[#notes + 1] = string.format("trackers: %s%s, %s%s", ns.class, build and build ~= "" and " " .. build or "", story, story == "moment" and string.format(", %.2f s in", at) or "")
end

return Ranged
