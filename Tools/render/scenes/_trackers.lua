-- _trackers.lua: RENDER_TRACKERS draws a warrior's, paladin's or rogue's crest trackers through the game's own feeds (Tools/regression/aura_slots.lua): steel (every piece known, nothing up), lit (every piece up, its timer part spent) or moment, the class's moment RENDER_TRACKERS_T seconds in (Trackers.END when unset): a warrior's target dodges and Overpower lights, it is spent, Bloodrage ignites Enrage round the rim, and Execute lights; a paladin's Judgement comes off cooldown, the old Judgement falls off the target and a new one lands, the Seal draining throughout; a rogue spends five points on Slice and Dice, Rupture runs out, and the off hand carries no poison. RENDER_TRACKERS_OFF=1 turns every tracker switch off first.
local Slots = dofile("Tools/regression/aura_slots.lua")

local Trackers = {}

local KNOWN = {
	WARRIOR = { 25289, 20662, 11585, 25288, 2687, 18499, 12317 },
	PALADIN = { 20154, 20271, 20049 },
	ROGUE = { 6774, 11275, 2842 },
}
local ICONS = {
	[25289] = 132333, [20662] = 135358, [11585] = 132223, [25288] = 132353, [2687] = 132277, [29131] = 132277, [18499] = 136009,
	[20154] = 132325, [20271] = 135959, [20185] = 135917, [6774] = 132306, [11275] = 132302, [2842] = 136242,
}
local KEYS = { "crestShout", "crestOpening", "crestEnrage", "crestSeal", "crestJudgement", "crestJudged", "crestVengeance", "crestSlice", "crestRupture", "crestPoisons" }
Trackers.END = 12

function Trackers.Story(class)
	local story = os.getenv("RENDER_TRACKERS")
	if not (story and story ~= "" and KNOWN[class]) then return nil end
	return story, tonumber(os.getenv("RENDER_TRACKERS_T") or "") or Trackers.END
end

-- Install(env, class) gives the stub game the class's spells, their icons, the aura slots and two weapons.
function Trackers.Install(env, class)
	if not env._slotContainers then Slots.Install(env) end
	local known = {}
	for _, id in ipairs(KNOWN[class]) do known[id] = true end
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
end

local function Sample(group, at, now, env)
	if group and group._playedAt and now >= at then group._playedAt = env._time - (now - at) end
end

local function Piece(ns, key)
	local form = ns.SlabTrackers.state.form
	for i, p in ipairs(ns.SlabTrackers.CLASSES[ns.class]) do
		if p.key == key and form and form.pieces[i] then return form.pieces[i], i end
	end
end

-- Play(env, K, ns, notes) puts the trackers in the story's state.
function Trackers.Play(env, K, ns, notes)
	local story, now = Trackers.Story(ns.class)
	if os.getenv("RENDER_TRACKERS_OFF") == "1" then
		for _, key in ipairs(KEYS) do K.Options.Write("ActionBars", key, false) end
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
	local crown = env._slotAuras.target or {}
	for _, a in ipairs(crown) do target[#target + 1] = a end
	Slots.Set(env, "player", player)
	Slots.Set(env, "target", target)
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
