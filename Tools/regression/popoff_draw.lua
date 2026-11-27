-- popoff_draw.lua: Check(classes) boots the saved suite once per class, lights every one of the class's signature pop-offs at once
-- (KstyleUI_ActionBars/SlabPopoffs.lua; the priest's on the priest, target, focus and a party member) and counts the shown regions through
-- the rise, the running aura, the ring's amber and red warnings and the fold, against the crest plan's 1,732 ceiling; the druid's limit is
-- its measured 1,773, because the druid's crest draws about a hundred more regions than the others before any
-- pop-off lights. Both were measured on the resting crest; the awake crest the fold needs draws a few regions of its own, which are taken
-- out of each count. Once the auras and folds are gone the count is back where it was before they lit, so nothing a pop-off showed stays drawn.
local Suite = dofile("Tools/regression/suite_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local Draw = { CEILING = 1732, LIMIT = { DRUID = 1773 } }
local LENGTH = 30

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

function Draw.Check(classes)
	for _, class in ipairs(classes) do
		local function Class(e)
			e.UnitClass = function(unit) if unit == "player" then return class, class, 1 end end
		end
		local first, K0 = Suite.New(nil, 1920, 1080, Class)
		assert(K0.Setup.Apply(K0.Setup.NewChoice()), class .. ": Setup.Apply refused the choice")
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
		local known, auras = {}, {}
		local function Give(unit, aura)
			auras[unit] = auras[unit] or {}
			aura.start, aura.duration = env._now, aura.duration or LENGTH
			table.insert(auras[unit], aura)
		end
		-- The priest is in a party, so Power Infusion watches the party too: on the priest, the target, the focus and a party member at once.
		local party = false
		for _, row in ipairs(rows) do
			for _, id in ipairs(row.known or row.spells) do known[id] = true end
			Give(row.unit or "player", { id = row.spells[1] })
			for _, unit in ipairs(row.allies and { "target", "focus", "party2" } or {}) do
				Give(unit, { id = row.spells[1], mine = true })
				party = true
			end
			if row.after then Give("player", { id = row.after.spell, duration = 60, harmful = true }) end
		end
		local exists, here = env.UnitExists, {}
		if party then
			here.party2, here.focus = true, true
			env.IsInGroup = function() return true end
			env.UnitIsUnit = function(a, b) return a == b end
		end
		env.UnitExists = function(unit) return here[unit] or exists(unit) end
		env.GetTime = env.GetTime or function() return env._now end
		env.C_SpellBook = env.C_SpellBook or {}
		local before = env.C_SpellBook.IsSpellKnown or function() return false end
		env.C_SpellBook.IsSpellKnown = function(id, bank) return known[id] == true or before(id, bank) end
		env.FireEvent("SPELLS_CHANGED")
		env.FireEvent("GROUP_ROSTER_UPDATE")
		Settle(env)
		-- The ceiling and the druid's limit were measured on the resting crest, out of combat with no target, but a resting crest does not fold;
		-- turning Calm crest at rest off keeps it awake so the auras' ends fold at Full, and the awake crest's own extra art is not the pop-offs'.
		local resting = Count(env)
		K.Store.Module("Medallions").restingCrest = false
		env.FireEvent("PLAYER_TARGET_CHANGED")
		Settle(env)
		local limit = Draw.LIMIT[class] or Draw.CEILING
		local base, start = Count(env), env._now
		local wake = base - resting
		local peak, moments = resting, {}
		local function Sample(what, frames)
			for _ = 1, frames do
				Frame(env)
				local n = Count(env) - wake
				assert(n <= limit, string.format("%s: %d shown regions %s on the resting crest's count, limit %d; a pop-off draws its art only while its aura or its fold shows", class, n, what, limit))
				peak = math.max(peak, n)
			end
			moments[#moments + 1] = what
		end
		for unit, list in pairs(auras) do Slots.Set(env, unit, list) end
		Sample("as the pop-offs rise", 40)
		Settle(env)
		local lit = 0
		for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			if p.spec.key == "crestPopoffs" and p:IsShown() and p.lits[1]:IsShown() then lit = lit + 1 end
		end
		assert(lit == #rows, string.format("%s: every pop-off lights at once (%d of %d)", class, lit, #rows))
		Sample("with the auras running", 2)
		env._now = start + LENGTH * 0.8 + 0.5
		Sample("in the ring's amber warning", 4)
		env._now = start + LENGTH * 11 / 12 + 0.5
		Sample("in the ring's red warning", 4)
		for unit in pairs(auras) do Slots.Set(env, unit, nil) end
		Frame(env)
		local folding = 0
		for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			if p.spec.key == "crestPopoffs" and p.fold and p.fold.play:IsPlaying() then folding = folding + 1 end
		end
		assert(folding == #rows, string.format("%s: every pop-off folds as its aura ends (%d of %d)", class, folding, #rows))
		Sample("as the pop-offs fold", 40)
		Settle(env)
		local after = Count(env)
		assert(after == base, string.format("%s: %d shown regions once the auras and folds are gone, %d before they lit; what a pop-off showed stays drawn", class, after, base))
		assert(#env._errors == 0, class .. ": " .. tostring(env._errors[1]))
		print(string.format("pop-off draw ok: %s peaks at %d shown regions on the resting crest's count (limit %d), %d before the pop-offs lit and after they folded, the awake crest drawing %d of its own, sampled %s", class, peak, limit, resting, wake, table.concat(moments, ", ")))
	end
end

return Draw
