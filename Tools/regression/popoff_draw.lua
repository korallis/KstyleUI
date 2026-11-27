-- popoff_draw.lua: Check(classes) boots the saved suite once per class, lights every one of the class's signature pop-offs at once
-- (KstyleUI_ActionBars/SlabPopoffs.lua; the priest's on the priest, target, focus and a group member, once in a party and once in a raid)
-- and counts every shown region through the rise, the running aura, the ring's amber and red warnings and the fold, against the crest
-- plan's 1,732 ceiling; the druid's limit is its measured 1,773, because the druid's crest draws about a hundred more regions than the
-- others before any pop-off lights. The crest is kept awake, as it is in combat or with a target, so the auras' ends fold at Full; the
-- count is the literal one, the awake crest's own art included. The auras reach the late warnings the way the client delivers them, a
-- UNIT_AURA per unit read back through C_UnitAuras, and each warning's amber and red swipes are checked drawing at their samples. Once
-- the auras and folds are gone the count is back where it was before they lit, so nothing a pop-off showed stays drawn.
local Suite = dofile("Tools/regression/suite_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local Draw = { CEILING = 1732, LIMIT = { DRUID = 1773 } }
local LENGTH = 30
local GROUP = { party = "party2", raid = "raid23" }

local function Frame(env)
	env._now = env._now + 1 / 60
	local busy = false
	for _, f in ipairs(env._frames) do
		local update = f._scripts.OnUpdate
		if update and f:IsVisible() then
			busy = true
			update(f, 1 / 60)
		end
	end
	env.RunTimers()
	return busy
end

local function Settle(env)
	for _ = 1, 600 do
		if not (Frame(env) or W.FinishGroups(env)) then return end
	end
end

local function Count(env)
	local n = 0
	for _, f in ipairs(env._frames) do
		for _, r in ipairs(f:IsVisible() and f._regions or {}) do
			if r._shown ~= false and r._type ~= "MaskTexture" then n = n + 1 end
		end
	end
	return n
end

-- The alpha a delayed fade leaves its frame at now: the frame's own until the start delay has run, the fade's end after it.
local function Level(env, frame, group)
	local fade = group.fade
	local t = group._playedAt and env._now - group._playedAt - fade._state.StartDelay[1]
	if not t or t < 0 then
		return frame:GetAlpha()
	end
	local from, to, length = fade._state.FromAlpha[1], fade._state.ToAlpha[1], fade._state.Duration[1]
	return t >= length and to or from + (to - from) * t / length
end

-- How strongly each lit pop-off slot's amber and red swipes draw now, by its unit.
local function Warnings(env, ns)
	local out = {}
	for _, e in ipairs(ns.SlabRings.state.watched) do
		local top = e.piece.top or e.piece
		if e.late and top.spec and top.spec.key == "crestPopoffs" and e.piece:IsVisible() and e.late.start then
			local cap = Level(env, e.late, e.late.show)
			out[top.spec.art .. ":" .. e.unit] = { cap * Level(env, e.late.amber, e.late.leave), cap * Level(env, e.late.red, e.late.turn) }
		end
	end
	return out
end

local function Run(class, group)
	local label = class .. (group and " in a " .. group or "")
	local function Class(e)
		e.UnitClass = function(unit) if unit == "player" then return class, class, 1 end end
	end
	local first, K0 = Suite.New(nil, 1920, 1080, Class)
	assert(K0.Setup.Apply(K0.Setup.NewChoice()), label .. ": Setup.Apply refused the choice")
	first.RunTimers()
	first.FireEvent("PLAYER_LOGOUT")
	local env, K = Suite.New(first.KstyleUIDB, 1920, 1080, Class)
	env.FireEvent("PLAYER_ENTERING_WORLD", false, true)
	env.RunTimers()
	Settle(env)
	Slots.Install(env)
	local ns = env._addons.KstyleUI_ActionBars
	local rows
	for _, entry in ipairs(ns.SlabPopoffs.CLASSES) do
		if entry[1] == class then rows = entry[2] end
	end
	local known, auras, timed = {}, {}, 0
	local function Give(unit, aura)
		auras[unit] = auras[unit] or {}
		aura.start, aura.duration = env._now, aura.duration or LENGTH
		table.insert(auras[unit], aura)
	end
	local member = group and GROUP[group]
	for _, row in ipairs(rows) do
		for _, id in ipairs(row.known or row.spells) do known[id] = true end
		Give(row.unit or "player", { id = row.spells[1], duration = row.art == "Veil" and 0 or nil })
		for _, unit in ipairs(row.allies and { "target", "focus", member } or {}) do
			Give(unit, { id = row.spells[1], mine = true })
		end
		if row.after then Give("player", { id = row.after.spell, duration = 60, harmful = true }) end
	end
	local exists, here = env.UnitExists, { focus = true }
	if member then
		here[member] = true
		env.IsInGroup = function() return true end
		env.IsInRaid = function() return group == "raid" end
		env.UnitIsUnit = function(a, b) return a == b end
	end
	env.UnitExists = function(unit) return here[unit] or exists(unit) end
	env.GetTime = env.GetTime or function() return env._now end
	local ids, serial = {}, 0
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
		for _, a in ipairs(env._slotAuras[unit] or {}) do
			if a.id == id and not a.harmful then
				if not ids[a] then serial = serial + 1 ids[a] = serial end
				return { auraInstanceID = ids[a], spellId = id, sourceUnit = "player", expirationTime = a.duration > 0 and a.start + a.duration or 0, duration = a.duration }
			end
		end
	end
	env.C_SpellBook = env.C_SpellBook or {}
	local before = env.C_SpellBook.IsSpellKnown or function() return false end
	env.C_SpellBook.IsSpellKnown = function(id, bank) return known[id] == true or before(id, bank) end
	env.FireEvent("SPELLS_CHANGED")
	env.FireEvent("GROUP_ROSTER_UPDATE")
	-- A resting crest does not fold; turning Calm crest at rest off keeps it awake, as combat or a target would, so the auras' ends fold at Full.
	K.Store.Module("Medallions").restingCrest = false
	env.FireEvent("PLAYER_TARGET_CHANGED")
	Settle(env)
	local limit = Draw.LIMIT[class] or Draw.CEILING
	local base, start = Count(env), env._now
	local peak, moments = base, {}
	local function Sample(what, frames)
		for _ = 1, frames do
			Frame(env)
			local n = Count(env)
			assert(n <= limit, string.format("%s: %d shown regions %s, limit %d; a pop-off draws its art only while its aura or its fold shows", label, n, what, limit))
			peak = math.max(peak, n)
		end
		moments[#moments + 1] = what
	end
	for unit, list in pairs(auras) do
		Slots.Set(env, unit, list)
		local added = {}
		for i, a in ipairs(list) do
			local read = env.C_UnitAuras.GetUnitAuraBySpellID(unit, a.id)
			added[i] = { spellId = a.id, auraInstanceID = read and read.auraInstanceID or 0 }
			timed = timed + (read and a.duration > 0 and 1 or 0)
		end
		env.FireEvent("UNIT_AURA", unit, { isFullUpdate = false, addedAuras = added })
	end
	Sample("as the pop-offs rise", 40)
	local lit = 0
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if p.spec.key == "crestPopoffs" and p:IsShown() and p.lits[1]:IsShown() then
			lit = lit + 1
			for _, l in ipairs(member and p.spec.allies and p.lits or {}) do
				if l.container._unit == member then
					assert(l:IsVisible(), label .. ": Power Infusion on " .. member .. ", not selected, lights")
					member = nil
				end
			end
		end
	end
	assert(lit == #rows, string.format("%s: every pop-off lights at once (%d of %d)", label, lit, #rows))
	assert(member == nil, label .. ": the pop-off shown watches " .. tostring(member))
	Sample("with the auras running", 2)
	local function Phase(what, amber, red)
		local n = 0
		for key, w in pairs(Warnings(env, ns)) do
			assert((w[1] > 0) == amber and (w[2] > 0) == red, string.format("%s: %s's ring is %s amber and %s red %s", label, key, w[1] > 0 and "" or "not", w[2] > 0 and "" or "not", what))
			n = n + 1
		end
		assert(n == timed, string.format("%s: %d of %d timed auras arm a late warning %s", label, n, timed, what))
	end
	Phase("while the aura is young", false, false)
	env._now = start + LENGTH * 0.8 + 0.5
	Sample("in the ring's amber warning", 4)
	Phase("in its last fifth", true, false)
	env._now = start + LENGTH * 11 / 12 + 0.5
	Sample("in the ring's red warning", 4)
	Phase("in its last twelfth", false, true)
	for unit in pairs(auras) do
		Slots.Set(env, unit, nil)
		env.FireEvent("UNIT_AURA", unit, { isFullUpdate = true })
	end
	Frame(env)
	local folding = 0
	for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
		if p.spec.key == "crestPopoffs" and p.fold and p.fold.play:IsPlaying() then folding = folding + 1 end
	end
	assert(folding == #rows, string.format("%s: every pop-off folds as its aura ends (%d of %d)", label, folding, #rows))
	Sample("as the pop-offs fold", 40)
	Settle(env)
	local after = Count(env)
	assert(after == base, string.format("%s: %d shown regions once the auras and folds are gone, %d before they lit; what a pop-off showed stays drawn", label, after, base))
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
	print(string.format("pop-off draw ok: %s peaks at %d shown regions (limit %d), %d before the pop-offs lit and after they folded, %d late warnings through amber and red, sampled %s", label, peak, limit, base, timed, table.concat(moments, ", ")))
end

function Draw.Check(classes)
	for _, class in ipairs(classes) do
		if class == "PRIEST" then
			Run(class, "party")
			Run(class, "raid")
		else
			Run(class)
		end
	end
end

return Draw
