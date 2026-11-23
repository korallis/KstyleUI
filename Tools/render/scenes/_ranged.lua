-- _ranged.lua: the hunter's, mage's and warlock's crest tracker stories (KstyleUI_ActionBars/SlabRanged.lua), which
-- _trackers.lua plays for those classes under RENDER_TRACKERS: steel (every piece known, nothing up, no pet, empty
-- bags), lit (the story at its LIT time, every piece up) or moment, the story RENDER_TRACKERS_T seconds in (6 when
-- unset). Blizzard's aura slots (Tools/regression/aura_slots.lua) and the addon's own bag and pet handlers take every
-- change at its own time, so a run of RENDER_TRACKERS_T frames is the story as a clip. RENDER_TRACKERS_BUILD picks
-- another build or level band, whose fields replace the class's: a hunter's melee or level 8 build, a mage's arcane,
-- fire, frost or level 10 build, a warlock's nodemon or level 8 build. RENDER_TRACKERS_OFF=1 turns the class's
-- tracker switches off first, for a pixel diff against a build without them.
local Slots = dofile("Tools/regression/aura_slots.lua")

local Ranged = {}

local STORIES = {
	HUNTER = {
		lit = 6.5,
		known = { 13165, 883, 1130, 1978, 19552, 3045, 19263, 19574, 2643, 1495, 75 },
		usable = { [2643] = 3 },
		swings = { 0.5, 3.3, 6.1 },
		icons = { [13165] = 136076, [13163] = 132159, [883] = 132161, [1130] = 132212, [1978] = 132204, [3045] = 132208, [19263] = 132369,
			[19574] = 132127, [19306] = 132336, [2973] = 132223, [3044] = 132218, [2643] = 132330, [1495] = 132215, [75] = 135489 },
		pet = { portrait = 132161, missing = 0.35, mood = 2 },
		auras = {
			{ unit = "player", id = 13165, icon = 136076, at = 0.5 },
			{ unit = "target", id = 1130, icon = 132212, at = 1, duration = 120, harmful = true },
			{ unit = "target", id = 1978, icon = 132204, at = 2, duration = 15, harmful = true },
			{ unit = "player", id = 6150, icon = 132347, at = 4, duration = 12 },
			{ unit = "player", id = 3045, icon = 132208, at = 4.5, duration = 15 },
			{ unit = "pet", id = 136, icon = 132179, at = 6, duration = 15 },
			{ unit = "pet", id = 19574, icon = 132127, at = 6.2, duration = 18 },
		},
		builds = {
			melee = { known = { 13163, 883, 1130, 1978, 19306, 1495, 19263, 75 }, usable = { [19306] = 3 },
				auras = { { unit = "player", id = 13163, icon = 132159, at = 0.5 }, { unit = "target", id = 1978, icon = 132204, at = 2, duration = 15, harmful = true },
					{ unit = "player", id = 19263, icon = 132369, at = 4, duration = 10 } } },
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
			fire = { known = { 7302, 759, 11426, 11095, 118, 116, 11129, 2139, 122, 11119 },
				auras = { { unit = "player", id = 7302, icon = 135843, at = 0.5, duration = 1800 }, { unit = "target", id = 22959, icon = 135818, at = 1, duration = 30, harmful = true },
					{ unit = "target", id = 412538, icon = 135818, at = 2, duration = 4, harmful = true }, { unit = "target", id = 122, icon = 135848, at = 3.5, duration = 8, harmful = true },
					{ unit = "player", id = 11129, icon = 135824, at = 4, duration = 15 } } },
			frost = { known = { 7302, 759, 11426, 11180, 118, 116, 11958, 2139, 122 },
				auras = { { unit = "player", id = 7302, icon = 135843, at = 0.5, duration = 1800 }, { unit = "target", id = 12579, icon = 135836, at = 1, duration = 15, harmful = true },
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
		pet = { portrait = 136218, missing = 0.3 },
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

local function Of(class)
	local s = STORIES[class]
	local build = s and s.builds[os.getenv("RENDER_TRACKERS_BUILD") or ""]
	return build and setmetatable(build, { __index = s }) or s
end

function Ranged.Story(class)
	local story = os.getenv("RENDER_TRACKERS")
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
	local before = env.C_SpellBook.IsSpellKnown
	env.C_SpellBook.IsSpellKnown = function(id, bank) return known[id] == true or before ~= nil and before(id, bank) end
	local spell = env.C_Spell or {}
	env.C_Spell = spell
	local texture = spell.GetSpellTexture
	spell.GetSpellTexture = function(id) return s.icons[id] or texture and texture(id) end
	spell.IsSpellUsable = function(id) local at = (s.usable or {})[id]; return at ~= nil and env._story >= at, false end
	spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
	spell.GetSpellCooldownDuration = function(id)
		local c = (s.cooling or {})[id]
		local start = c and (env._now or 0) - (env._story - c[1])
		return c and { start = start, finish = start + c[2] } or { start = 0, finish = 0 }
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
	local pet = s.pet
	local exists = env.UnitExists
	env.UnitExists = function(unit) if unit == "pet" then return pet and env._story >= 0 or false end return exists(unit) end
	if pet then
		env.UnitIsDead = function() return false end
		env.UnitHealthMax = function() return 100 end
		env.UnitHealthMissing = function() return 100 * pet.missing end
		env.C_PetInfo = { GetPetHappiness = function() return pet.mood end }
		env.SetPortraitTexture = function(t) t:SetTexture(pet.portrait) end
	end
end

-- Play(env, K, ns, notes) runs the story up to its time, each change at its own time on the clock.
function Ranged.Play(env, K, ns, notes)
	local story, at = Ranged.Story(ns.class)
	if os.getenv("RENDER_TRACKERS_OFF") == "1" then
		for _, row in ipairs(ns.SlabTrackers.CLASSES[ns.class] or {}) do K.Options.Write("ActionBars", row.key, false) end
	end
	local s = Of(ns.class)
	local times = { -1, at }
	for _, a in ipairs(s.auras) do times[#times + 1], times[#times + 2] = a.at, a.at + (a.duration or at) end
	for _, item in pairs(s.items or {}) do
		for _, step in ipairs(item.steps) do times[#times + 1] = step[1] end
		times[#times + 1] = item.used
	end
	for _, when in pairs(s.usable or {}) do times[#times + 1] = when end
	for _, when in ipairs(s.swings or {}) do times[#times + 1] = when end
	if s.enchant then
		Slots.Enchant(env, 1, { start = env._time - at - 600, duration = s.enchant })
	end
	table.sort(times)
	local clock, now = env.GetTime, env._now
	env.GetTime = function() return env._now end
	for _, when in ipairs(times) do
		if when <= at then
			env._story, env._now = when, env._time - (at - when)
			local units = { player = {}, target = {}, pet = {} }
			for _, a in ipairs(s.auras) do
				if a.at <= when and (not a.duration or when < a.at + a.duration) then
					a.start = env._time - (at - a.at)
					table.insert(units[a.unit], a)
				end
			end
			for unit, list in pairs(units) do Slots.Set(env, unit, list) end
			env.FireEvent("UNIT_PET", "player")
			env.FireEvent("BAG_UPDATE_DELAYED")
			env.FireEvent("BAG_UPDATE_COOLDOWN")
			env.FireEvent("SPELL_UPDATE_USABLE")
			env.FireEvent("SPELL_UPDATE_COOLDOWN")
			for _, swing in ipairs(s.swings or {}) do
				if swing == when then env.FireEvent("PLAYER_SWING", 2.8, 2) end
			end
		end
	end
	env.GetTime, env._now = clock, now
	local build = os.getenv("RENDER_TRACKERS_BUILD")
	notes[#notes + 1] = string.format("trackers: %s%s, %s%s", ns.class, build and build ~= "" and " " .. build or "", story, story == "moment" and string.format(", %.2f s in", at) or "")
end

return Ranged
