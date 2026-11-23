-- _trackers.lua: RENDER_TRACKERS_FORM sets GetShapeshiftFormID (a warrior's 18 or 19, a rogue's 30) and RENDER_TRACKERS_SPEC the talents a paladin (holy, prot) or rogue (assassination, combat, subtlety) knows; RENDER_TRACKERS draws a warrior's, paladin's or rogue's crest trackers through the game's own feeds (Tools/regression/aura_slots.lua): steel (every piece known, nothing up), lit (every piece up, its timer part spent) or moment, the class's moment RENDER_TRACKERS_T seconds in (Trackers.END when unset): a warrior's target dodges and Overpower lights, it is spent, Bloodrage ignites Enrage round the rim, and Execute lights; a paladin's Judgement comes off cooldown, the old Judgement falls off the target and a new one lands, the Seal draining throughout; a rogue spends five points on Slice and Dice, Rupture runs out, and the off hand carries no poison. RENDER_TRACKERS_OFF=1 turns every tracker switch off first.
-- _trackers.lua: RENDER_TRACKERS_FORM sets GetShapeshiftFormID (a warrior's 18 or 19, a rogue's 30); RENDER_TRACKERS draws a warrior's, paladin's or rogue's crest trackers through the game's own feeds (Tools/regression/aura_slots.lua): steel (every piece known, nothing up), lit (every piece up, its timer part spent) or moment, the class's moment RENDER_TRACKERS_T seconds in (Trackers.END when unset): a warrior's target dodges and Overpower lights, it is spent, Bloodrage ignites Enrage round the rim, and Execute lights; a paladin's Judgement comes off cooldown, the old Judgement falls off the target and a new one lands, the Seal draining throughout; a rogue spends five points on Slice and Dice, Rupture runs out, and the off hand carries no poison. A priest, druid or shaman plays its own story through the same feeds and the addon's own handlers (charge counts, casts, cooldowns, weapon enchants, forms and a queued Maul), steel showing every known piece with nothing up, lit the story at its own time and moment RENDER_TRACKERS_T seconds in; RENDER_TARGET=friend gives the druid a friendly target and RENDER_FORM chooses another crest: cat, bear or moonkin for the druid, shadowform for the priest, enhancement for the shaman. RENDER_TRACKERS_OFF=1 turns every tracker switch off first (and for a healer plays nothing, for a pixel diff).
-- _trackers.lua: RENDER_TRACKERS_FORM sets GetShapeshiftFormID (a warrior's 18 or 19, a rogue's 30); RENDER_TRACKERS draws a warrior's, paladin's or rogue's crest trackers through the game's own feeds (Tools/regression/aura_slots.lua): steel (every piece known, nothing up), lit (every piece up, its timer part spent) or moment, the class's moment RENDER_TRACKERS_T seconds in (Trackers.END when unset): a warrior's target dodges and Overpower lights, it is spent, Bloodrage ignites Enrage round the rim, and Execute lights; a paladin's Judgement comes off cooldown, the old Judgement falls off the target and a new one lands, the Seal draining throughout; a rogue spends five points on Slice and Dice, Rupture runs out, and the off hand carries no poison. A priest, druid or shaman plays its own story through the same feeds and the addon's own handlers (charge counts, casts, cooldowns, weapon enchants, forms and a queued Maul), steel showing every known piece with nothing up, lit the story at its own time and moment RENDER_TRACKERS_T seconds in; RENDER_TARGET=friend gives the druid a friendly target and RENDER_FORM chooses another crest: cat, bear or moonkin for the druid, shadowform for the priest, enhancement for the shaman, and RENDER_TARGET=friend a healer's friendly target for the priest too. RENDER_TRACKERS_OFF=1 turns every tracker switch off first (and for a healer plays nothing, for a pixel diff).
local Slots = dofile("Tools/regression/aura_slots.lua")
local Ranged = dofile("Tools/render/scenes/_ranged.lua")

local Trackers = {}

local KNOWN = {
	WARRIOR = { 25289, 20662, 11585, 25288, 2565, 23894, 1680, 2687, 18499, 12317, 1719, 12328, 871, 12975, 12292, 20230, 21553, 11605,
		11581, 1672, 6554, 11578, 20617, 355 },
	PALADIN = { 20154, 20271, 1020, 5573, 10333, 24239, 10314, 10308 },
	ROGUE = { 6774, 11275, 2842, 11269, 1833, 1857, 13877, 13750, 5277, 11305, 1769, 1329549, 1316709, 1329328, 14148 },
}
local SPECS = { holy = { 20473, 20216, 1328548, 1310911 }, prot = { 20925, 407632, 25780 }, ret = { 20049 }, assassination = { 14177 }, combat = { 14251 }, subtlety = { 16511 } }
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
local HEALER_ICONS = {
	[10952] = 135926, [1316995] = 237545, [10947] = 136224, [401977] = 136199, [15473] = 136200, [10894] = 136207,
	[10060] = 135939, [586] = 135994, [9835] = 136096, [24977] = 136045, [25299] = 136081, [9858] = 136085,
	[9904] = 132122, [9896] = 132152, [9898] = 132121, [9907] = 136033, [9881] = 132136, [17402] = 136018,
	[16870] = 136170, [18562] = 134914, [22812] = 136097, [22842] = 132091, [5229] = 132126, [1850] = 132120,
	[10414] = 136026, [20608] = 136080, [16166] = 136111, [10901] = 135940, [25315] = 135953, [1240827] = 135944, [1240849] = 135944,
	[19280] = 252997, [1309636] = 136149, [15487] = 136164, [6795] = 132270, [1238122] = 132183, [1238070] = 132278, [8983] = 132114,
	[29228] = 135813, [1238215] = 236153, [15286] = 136230, [17364] = 132314, [425336] = 136012,
}
local DRUID = { 9835, 24977, 25299, 9858, 9904, 9896, 9898, 9907, 9881, 24858, 16864, 18562, 22812, 22842, 5229, 1850, 1238215, 6795, 1238122,
	1238070, 8983 }

-- Each story: the spells the character knows, its form (GetShapeshiftFormID and power type), the default time, and
-- its beats in seconds: an aura on a unit ({ unit, spell, charges, seconds, harmful }; seconds nil clears it), a
-- charge count on the player's first aura, the player's cast, a spell's cooldown ({ spell, seconds }), a queued
-- spell (C_Spell.IsCurrentSpell) and a weapon's enchant ({ slot, enchantID, seconds left of an hour }, or { slot }).
local HEALERS = {
	PRIEST_friend = { at = 4, known = { 10952, 1316995, 10947, 401977, 10894, 10060, 10901, 25315, 1240827 }, beats = {
		{ 0.5, cast = 10952, aura = { "player", 10952, 20, 600 } },
		{ 1, aura = { "target", 10901, 0, 30 } },
		{ 1.5, aura = { "target", 25315, 0, 15 } },
		{ 2, aura = { "target", 1240849, 5, 30 }, cooldown = { 1240827, 10 } },
		{ 2.5, cooldown = { 1316995, 12 } },
		{ 3.2, charges = 15 },
	} },
	PRIEST = { at = 4, known = { 10952, 1316995, 10947, 401977, 10894, 10060, 586, 10901 }, beats = {
		{ 0.5, cast = 10952, aura = { "player", 10952, 20, 600 } },
		{ 1.5, aura = { "target", 10894, 0, 18, true } },
		{ 2, aura = { "player", 10060, 0, 15 } },
		{ 2.5, cooldown = { 1316995, 12 } },
		{ 3.2, charges = 15 }, { 4.6, charges = 10 }, { 5.8, charges = 4 },
		{ 6.5, aura = { "player", 586, 0, 10 } },
		{ 7.5, cooldown = { 401977, 300 } },
		{ 9, aura = { "player", 10952 } },
	} },
	DRUID = { at = 4, known = DRUID, beats = {
		{ 0.2, aura = { "target", 9907, 0, 40, true } },
		{ 0.5, aura = { "target", 9835, 0, 12, true } },
		{ 1, aura = { "target", 24977, 0, 12, true } },
		{ 2, aura = { "player", 16870, 1, 15 } },
		{ 2.5, aura = { "player", 22812, 0, 12 } },
		{ 3, cooldown = { 18562, 15 } },
		{ 5.5, aura = { "player", 16870 } },
	} },
	DRUID_friend = { at = 4, known = DRUID, beats = {
		{ 0.5, aura = { "target", 25299, 0, 12 } },
		{ 1, aura = { "target", 9858, 0, 21 } },
		{ 2, aura = { "player", 16870, 1, 15 } },
		{ 3, cooldown = { 18562, 15 } },
	} },
	DRUID_cat = { at = 4, form = 1, power = 3, known = DRUID, beats = {
		{ 0.5, aura = { "target", 9907, 0, 40, true } },
		{ 1, aura = { "target", 9904, 0, 9, true } },
		{ 2, aura = { "target", 9896, 0, 12, true } },
		{ 2.5, aura = { "player", 1850, 0, 15 } },
	} },
	DRUID_bear = { at = 4, form = 8, power = 1, known = DRUID, beats = {
		{ 0.5, aura = { "target", 9898, 0, 30, true } },
		{ 1, aura = { "target", 9907, 0, 40, true } },
		{ 1.5, aura = { "player", 5229, 0, 10 } },
		{ 2, aura = { "player", 22842, 0, 10 } },
		{ 2.5, cooldown = { 6795, 8 } },
		{ 3, queue = 9881 },
	} },
	DRUID_moonkin = { at = 4, form = 31, known = DRUID, beats = {
		{ 0.5, aura = { "target", 9835, 0, 12, true } },
		{ 1, aura = { "target", 24977, 0, 12, true } },
		{ 2, cooldown = { 17402, 60 } },
		{ 2.5, aura = { "player", 16870, 1, 15 } },
	} },
	PRIEST_shadowform = { at = 4, form = 28, known = { 10952, 10947, 15473, 15286, 10894, 401977, 586, 15334, 19280, 1309636, 15487 }, beats = {
		{ 2, aura = { "target", 19280, 0, 24, true } },
		{ 3, cooldown = { 1309636, 18 } },
		{ 0.5, cast = 10952, aura = { "player", 10952, 20, 600 } },
		{ 1, aura = { "target", 15286, 0, 60, true } },
		{ 1.5, aura = { "target", 10894, 0, 18, true } },
		{ 2.5, cooldown = { 10947, 8 } },
		{ 3.2, charges = 15 },
		{ 3.5, aura = { "player", 586, 0, 10 } },
	} },
	SHAMAN_enhancement = { at = 3, known = { 16362, 10414, 20608, 17364, 425336 }, offHand = true, beats = {
		{ 0, enchant = { 16, 1669, 1800 } },
		{ 0, enchant = { 17, 1666, 240 } },
		{ 1, cooldown = { 17364, 8 } },
		{ 2, aura = { "player", 425336, 0, 15 } },
	} },
	SHAMAN = { at = 3, known = { 16362, 10414, 20608, 16166, 29228 }, offHand = true, beats = {
		{ 0.5, aura = { "target", 29228, 0, 12, true } },
		{ 0, enchant = { 16, 1669, 1800 } },
		{ 0, enchant = { 17, 1666, 240 } },
		{ 1, cast = 10414, cooldown = { 10414, 6 } },
		{ 2, aura = { "player", 16166, 0, 15 } },
		{ 8, enchant = { 17 } },
	} },
}

-- Healer(env, K, ns, notes, mode) plays a priest's, druid's or shaman's story: steel shows every known piece with
-- nothing up, lit the story at its own time, moment the story RENDER_TRACKERS_T seconds in (its own time when unset);
-- RENDER_TARGET=friend gives the druid a friendly target and RENDER_FORM another form's or spec's crest.
local function Healer(env, K, ns, notes, mode)
	local class = ns.class
	local variant = os.getenv("RENDER_FORM") or os.getenv("RENDER_TARGET") == "friend" and "friend" or nil
	local story = HEALERS[variant and class .. "_" .. variant] or HEALERS[class]
	local at = mode == "steel" and -1 or mode == "moment" and tonumber(os.getenv("RENDER_TRACKERS_T") or "") or story.at
	if not env._slotContainers then
		Slots.Install(env)
	end
	local known, auras, cooldowns, enchants = {}, { player = {}, target = {} }, {}, {}
	for _, id in ipairs(story.known) do known[id] = true end
	local isKnown = env.C_SpellBook and env.C_SpellBook.IsSpellKnown
	env.C_SpellBook = env.C_SpellBook or {}
	env.C_SpellBook.IsSpellKnown = function(id) return known[id] == true or (isKnown ~= nil and isKnown(id)) end
	local spell = env.C_Spell or {}
	env.C_Spell = spell
	local texture = spell.GetSpellTexture
	spell.GetSpellTexture = function(id) return HEALER_ICONS[id] or texture and texture(id) end
	spell.GetSpellCooldown = function(id)
		local c = cooldowns[id]
		return { isActive = c ~= nil and c.finish > env._time, isOnGCD = false, isEnabled = true }
	end
	spell.GetSpellCooldownDuration = function(id)
		local c = cooldowns[id]
		return c and c.finish > env._time and c or { start = 0, finish = 0 }
	end
	env.C_PaperDollInfo = env.C_PaperDollInfo or {}
	env.C_PaperDollInfo.OffhandHasWeapon = function() return story.offHand == true end
	env.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function(slot)
		local e = enchants[slot]
		return e and { enchantID = e.id, remainingTimeMs = math.max(0, e.finish - env._now) * 1000, chargesRemaining = 0, hasExpirationTime = true } or nil
	end
	env.C_Item = env.C_Item or {}
	env.C_Item.GetItemCount = function() return 1 end
	local queued = {}
	spell.IsCurrentSpell = function(id) return queued[id] == true end
	env.GetShapeshiftFormID = function() return story.form end
	if story.power then
		env.UnitPowerType = function() return story.power, story.power == 3 and "ENERGY" or "RAGE" end
	end
	ns.SlabTrackers.Update()
	local clock = env.GetTime
	env.GetTime = function() return env._now end
	for _, beat in ipairs(story.beats) do
		if beat[1] <= at then
			env._now = env._time - (at - beat[1])
			local a = beat.aura
			if a then
				local list = auras[a[1]]
				for i = #list, 1, -1 do
					if list[i].id == a[2] then table.remove(list, i) end
				end
				if a[4] and env._now + a[4] > env._time then
					list[#list + 1] = { id = a[2], count = a[3], harmful = a[5], icon = HEALER_ICONS[a[2]], start = env._now, duration = a[4] }
				end
				Slots.Set(env, a[1], list)
			end
			if beat.charges then
				auras.player[1].count = beat.charges
				Slots.Set(env, "player", auras.player)
			end
			if beat.cooldown then
				cooldowns[beat.cooldown[1]] = { start = env._now, finish = env._now + beat.cooldown[2] }
				env.FireEvent("SPELL_UPDATE_COOLDOWN")
			end
			if beat.enchant then
				local slot, id, left = beat.enchant[1], beat.enchant[2], beat.enchant[3]
				enchants[slot] = id and { id = id, finish = env._now + left } or nil
				Slots.Enchant(env, slot - 15, id and { start = env._now + left - 3600, duration = 3600 } or nil)
				env.FireEvent("WEAPON_ENCHANT_CHANGED")
			end
			env.FireEvent("UNIT_AURA", "player", {})
			if beat.queue then
				queued[beat.queue] = true
				env.FireEvent("CURRENT_SPELL_CAST_CHANGED")
			end
			if beat.cast then
				env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-trackers", beat.cast)
			end
		end
	end
	env._now = env._time
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.GetTime = clock
	local row = ns.SlabTrackers.state.forms.row
	if row and row.frame:IsVisible() then
		local frame, k = row.frame, row.frame:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
		notes[#notes + 1] = string.format("trackers: the Frames row at %d,%d,%d,%d units (left, top, width, height)", frame:GetLeft() * k,
			env.UIParent:GetHeight() - frame:GetTop() * k, frame:GetWidth() * k, frame:GetHeight() * k)
	end
	notes[#notes + 1] = string.format("trackers: %s, %s, %s s into the story%s", class, mode, at, variant and " (" .. variant .. ")" or "")
end

Trackers.END = 12

function Trackers.Story(class)
	if Ranged.Story(class) then return Ranged.Story(class) end
	local story = os.getenv("RENDER_TRACKERS")
	if not (story and story ~= "" and (KNOWN[class] or HEALERS[class])) then return nil end
	return story, tonumber(os.getenv("RENDER_TRACKERS_T") or "") or Trackers.END
end

-- Install(env, class) gives the stub game the class's spells, their icons, the aura slots and two weapons.
function Trackers.Install(env, class)
	env._slotGroups = true
	if not env._slotContainers then Slots.Install(env) end
	env.AuraContainerSortMethod = env.AuraContainerSortMethod or { Default = 0, AuraInstanceIDOnly = 8 }
	env.AuraContainerSortDirection = env.AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
	if Ranged.Story(class) then return Ranged.Install(env, class) end
	if not KNOWN[class] then return end
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
	if Ranged.Story(ns.class) then return Ranged.Play(env, K, ns, notes) end
	local story, now = Trackers.Story(ns.class)
	if os.getenv("RENDER_TRACKERS_OFF") == "1" then
		K.Options.Write("ActionBars", "crestVengeance", false)
		for _, row in ipairs(ns.SlabTrackers.CLASSES[ns.class]) do K.Options.Write("ActionBars", row.key, false) end
		if HEALERS[ns.class] then
			ns.SlabTrackers.Update()
			notes[#notes + 1] = "trackers: every tracker switch off"
			return
		end
	end
	if HEALERS[ns.class] then
		return Healer(env, K, ns, notes, story)
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
			player[#player + 1] = { id = 20050, count = 3, icon = ICONS[20050], start = at(-4), duration = 30 }
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
		local extra = { WARRIOR = { 12292, 3, 2565, 2 }, PALADIN = { 25780, 0, 20925, 3 }, ROGUE = { 14143, 0, 1310703, 0 } }
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
