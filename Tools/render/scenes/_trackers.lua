-- _trackers.lua: RENDER_TRACKERS_FORM sets GetShapeshiftFormID (a warrior's 18 or 19, a rogue's 30) and RENDER_TRACKERS_SPEC the talents a paladin (holy, prot) or rogue (assassination, combat, subtlety) knows; RENDER_TRACKERS draws a warrior's, paladin's or rogue's crest trackers through the game's own feeds (Tools/regression/aura_slots.lua): steel (every piece known, nothing up), lit (every piece up, its timer part spent) or moment, the class's moment RENDER_TRACKERS_T seconds in (Trackers.END when unset): a warrior's target dodges and Overpower lights, it is spent, Bloodrage ignites Enrage round the rim, and Execute lights; a paladin's Judgement comes off cooldown, the old Judgement falls off the target and a new one lands, the Seal draining throughout; a rogue spends five points on Slice and Dice, Rupture runs out, and the off hand carries no poison. RENDER_TRACKERS_OFF=1 turns every tracker switch off first.
local Slots = dofile("Tools/regression/aura_slots.lua")

local Trackers = {}

local KNOWN = {
	WARRIOR = { 25289, 20662, 11585, 25288, 2565, 23894, 1680, 2687, 18499, 12317, 1719, 12328, 871, 12975, 12292, 20230, 21553, 11605,
		11581, 1672, 6554, 11578, 20617, 355 },
	PALADIN = { 20154, 20271, 1020, 5573, 10333, 24239, 10314, 10308 },
	ROGUE = { 6774, 11275, 2842, 11269, 1833, 1857, 13877, 13750, 5277, 11305, 14177, 1769, 1329549, 1316709, 1329328, 14148 },
}
local SPECS = { holy = { 20473, 20216 }, prot = { 20925, 407632, 25780 }, ret = { 20049 }, assassination = { 14177 }, combat = { 14251 }, subtlety = { 16511 } }
local COOLDOWNS = { WARRIOR = { 1719, 871 }, PALADIN = { 407788, 20216 }, ROGUE = { 13877, 13750, 5277 } }
local OPENINGS = { [18] = 25288, [19] = 23894, [30] = 11269 }
local ICONS = {
	[25289] = 132333, [20662] = 135358, [11585] = 132223, [25288] = 132353, [2687] = 132277, [29131] = 132277, [18499] = 136009,
	[20154] = 132325, [20271] = 135959, [20185] = 135917, [6774] = 132306, [11275] = 132302, [2842] = 136242,
	[1719] = 132109, [871] = 132362, [407788] = 135875, [20216] = 135915, [13877] = 132350, [13750] = 136206, [5277] = 136205,
	[23894] = 136012, [2565] = 132110, [1680] = 132369, [11269] = 132282, [1833] = 132092, [1857] = 132331,
	[21553] = 132355, [12292] = 132306, [1672] = 132357, [6554] = 132938, [11578] = 132337, [20617] = 132307, [355] = 136080,
	[10333] = 135891, [24239] = 132326, [10308] = 135963, [20473] = 135972, [407632] = 135891, [25780] = 135962, [20050] = 132275,
	[1769] = 132219, [1316709] = 136168, [1310703] = 132290, [14143] = 132151, [14251] = 132336, [20925] = 135880,
}
Trackers.END = 12

function Trackers.Story(class)
	local story = os.getenv("RENDER_TRACKERS")
	if not (story and story ~= "" and KNOWN[class]) then return nil end
	return story, tonumber(os.getenv("RENDER_TRACKERS_T") or "") or Trackers.END
end

-- Install(env, class) gives the stub game the class's spells, their icons, the aura slots and two weapons.
function Trackers.Install(env, class)
	env._slotGroups = true
	if not env._slotContainers then Slots.Install(env) end
	env.AuraContainerSortMethod = env.AuraContainerSortMethod or { Default = 0, AuraInstanceIDOnly = 8 }
	env.AuraContainerSortDirection = env.AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
	local known = {}
	for _, id in ipairs(KNOWN[class]) do known[id] = true end
	local spec = os.getenv("RENDER_TRACKERS_SPEC")
	for _, id in ipairs(SPECS[spec and spec ~= "" and spec or class == "PALADIN" and "ret" or ""] or {}) do known[id] = true end
	env.C_SpellBook = env.C_SpellBook or {}
	local before = env.C_SpellBook.IsSpellKnown
	env.C_SpellBook.IsSpellKnown = function(id, bank) return known[id] == true or before ~= nil and before(id, bank) end
	local spell = env.C_Spell or {}
	env.C_Spell = spell
	local texture = spell.GetSpellTexture
	spell.GetSpellTexture = function(id) return ICONS[id] or texture and texture(id) end
	env._usable, env._cooldowns = {}, {}
	spell.IsSpellUsable = function(id) return env._usable[id] == true, false end
	spell.GetSpellCooldown = function(id) return { isActive = env._cooldowns[id] ~= nil, isOnGCD = false } end
	spell.GetSpellCooldownDuration = function(id) return env._cooldowns[id] or { start = 0, finish = 0 } end
	env.GetInventoryItemID = function(_, slot) return (slot == 16 or slot == 17) and 2092 or nil end
	env.GetShapeshiftFormID = function() return tonumber(os.getenv("RENDER_TRACKERS_FORM") or "") end
	env.UnitDetailedThreatSituation = function() if env._threat then return true, 3, env._threat, 100, 1000 end end
	env.C_Item = env.C_Item or {}
	env.C_Item.GetItemCount = function(id) return (id == 13444 or id == 9421) and 1 or 0 end
	env.C_Item.GetItemCooldown = function() return (env._time or 0) - 30, 120, true end
	env.C_Item.GetItemIconByID = function(id) return id == 13444 and 134762 or 135230 end
	spell.GetSpellPowerCost = function() return { { type = 0, cost = 100 } } end
end

local function Sample(group, at, now, env)
	if group and group._playedAt and now >= at then group._playedAt = env._time - (now - at) end
end

local function Piece(ns, key)
	local form = ns.SlabTrackers.state.form
	for i, p in ipairs(ns.SlabTrackers.CLASSES[ns.class]) do
		for k, piece in pairs(p.key == key and form and form.pieces or {}) do
			if k:match("^" .. i .. ":") and piece:IsShown() then return piece, i end
		end
	end
end

-- Play(env, K, ns, notes) puts the trackers in the story's state.
function Trackers.Play(env, K, ns, notes)
	local story, now = Trackers.Story(ns.class)
	if os.getenv("RENDER_TRACKERS_OFF") == "1" then
		K.Options.Write("ActionBars", "crestVengeance", false)
		for _, row in ipairs(ns.SlabTrackers.CLASSES[ns.class]) do K.Options.Write("ActionBars", row.key, false) end
	end
	env.RunTimers()
	local class, t0 = ns.class, story == "moment" and now or 6
	local function at(s) return env._time - (t0 - s) end
	local player, target = {}, {}
	if story ~= "steel" then
		if class == "WARRIOR" then
			player[#player + 1] = { id = 25289, count = 0, icon = ICONS[25289], start = at(-60), duration = 120 }
			if story == "lit" or now >= 3 and now < 15 then player[#player + 1] = { id = 29131, count = 0, icon = ICONS[29131], start = at(3), duration = 12 } end
			env._usable[11585] = story == "lit" or now >= 0.5 and now < 2.5
			env._usable[20662] = story == "moment" and now >= 9
		elseif class == "PALADIN" then
			player[#player + 1] = { id = 20154, count = 0, icon = ICONS[20154], start = at(-6), duration = 30 }
			player[#player + 1] = { id = 20050, count = 3 }
			local judged = story == "lit" and 2 or now >= 4 and 4 or -8
			if story == "lit" or now < 2 or now >= 4 then target[#target + 1] = { id = 20185, count = 0, icon = ICONS[20185], harmful = true, start = at(judged), duration = 10 } end
			if story == "lit" or now < 1 or now >= 4 then env._cooldowns[20271] = { start = at(judged - 1), finish = at(judged + 9) } end
		elseif class == "ROGUE" then
			if story == "lit" or now >= 1 then player[#player + 1] = { id = 6774, count = 0, icon = ICONS[6774], start = at(1), duration = 21 } end
			if story == "lit" or now < 6 then target[#target + 1] = { id = 11275, count = 0, icon = ICONS[11275], harmful = true, start = at(story == "lit" and 0 or -10), duration = 16 } end
			Slots.Enchant(env, 1, { start = at(-600), duration = 1800 })
			if story == "lit" then Slots.Enchant(env, 2, { start = at(-1200), duration = 1800 }) end
			env._pips = story == "moment" and now < 1 and 5 or story == "lit" and 3 or 0
			env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
		end
	end
	if story == "lit" then
		for i, id in ipairs(COOLDOWNS[class]) do
			player[#player + 1] = { id = id, count = 0, icon = ICONS[id], start = at(-2 * i), duration = 20 }
		end
		local opening = OPENINGS[tonumber(os.getenv("RENDER_TRACKERS_FORM") or "")]
		if opening then env._usable[opening] = true end
		env._threat = 85
		for _, id in ipairs({ 21553, 23894, 10333, 407632, 20473, 1769, 1672, 6554, 10308, 355 }) do
			env._cooldowns[id] = { start = at(2), finish = at(8) }
		end
		env._usable[24239], env._usable[14251] = true, true
		local extra = { WARRIOR = { 12292, 3, 2565, 2 }, PALADIN = { 20050, 3, 25780, 0, 20925, 3 }, ROGUE = { 14143, 0, 1310703, 0 } }
		for i = 1, #extra[class], 2 do
			player[#player + 1] = { id = extra[class][i], count = extra[class][i + 1], icon = ICONS[extra[class][i]], start = at(-4), duration = 30 }
		end
		if class == "ROGUE" then
			target[#target + 1] = { id = 1316709, count = 0, icon = ICONS[1316709], harmful = true, start = at(2), duration = 10 }
			target[#target + 1] = { id = 2818, count = 4, icon = 132290, harmful = true, start = at(0), duration = 12 }
		end
	end
	local crown = env._slotAuras.target or {}
	for _, a in ipairs(crown) do target[#target + 1] = a end
	Slots.Set(env, "player", player)
	Slots.Set(env, "target", target)
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
	if story == "lit" then
		local clock = env._now
		env._now = env._time - 2
		env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-mana", 20271)
		env._now = clock
	end
	env.FireEvent("SPELL_UPDATE_USABLE")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	if story == "moment" then
		local beats = {
			WARRIOR = { { "crestOpening", 0.5 }, { "crestEnrage", 3 }, { "crestOpening", 9 } },
			PALADIN = { { "crestJudgement", 1 }, { "crestJudged", 4 } },
			ROGUE = { { "crestSlice", 1 } },
		}
		for _, beat in ipairs(beats[class]) do
			local piece = Piece(ns, beat[1])
			if piece and now >= beat[2] then
				if not piece.flare.play._playedAt then ns.SlabMedals.Fire(piece) end
				Sample(piece.flare.play, beat[2], now, env)
				Sample(piece.lit.loop, beat[2], now, env)
			end
		end
	end
	notes[#notes + 1] = string.format("trackers: %s, %s%s", class, story, story == "moment" and string.format(", %.2f s in", now) or "")
end

return Trackers
