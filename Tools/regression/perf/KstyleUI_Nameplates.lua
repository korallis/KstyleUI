-- KstyleUI_Nameplates.lua: the nameplates' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local N = dofile("Tools/regression/nameplates_env.lua")

local function Plate()
	local env = N.New()
	N.Add(env, "nameplate1")
	return env
end

local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
local ELITE = { name = "Bloodtalon Matriarch", level = 40, classification = "elite", reaction = 2, canAttack = true }
local NORMAL = { name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true }

-- Forty() is forty positioned plates at Full that fire OnShow and OnHide as the game does, every fourth casting;
-- it fails when a plate places no ornament piece or shows the wrong set, so an empty fixture cannot time an empty path.
local function Forty()
	local env = N.New()
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	local scale = 768 / 1080
	for i = 1, 40 do
		local base = N.Base(env)
		base:ClearAllPoints()
		base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", (120 + ((i - 1) % 8) * 230) * scale, (1080 - (120 + math.floor((i - 1) / 8) * 180)) * scale)
		N.Add(env, "nameplate" .. i, i % 5 == 0 and ELITE or NORMAL, { base = base })
		N.Debuffs(env, "nameplate" .. i, 8)
	end
	N.Target(env, "nameplate40")
	env.RunTimers()
	for _, frame in ipairs(env._frames) do
		for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
			local original = frame[method]
			frame[method] = function(self, ...)
				local was = self:IsVisible()
				original(self, ...)
				local now = self:IsVisible()
				local script = self._scripts and self._scripts[now and "OnShow" or "OnHide"]
				if was ~= now and script then script(self) end
			end
		end
	end
	for i = 4, 40, 4 do
		env._units["nameplate" .. i].cast = CAST
		env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
	end
	env.RunTimers()
	local ns = env._addons.KstyleUI_Nameplates
	for i = 1, 40 do
		local handle = ns.Plates.Get("nameplate" .. i).ornament
		local shown = 0
		for j = 1, handle.used do
			if handle.textures[j]:IsShown() then shown = shown + 1 end
		end
		assert(shown > 0, "plate " .. i .. " of the cost fixture places no ornament piece at Full")
		assert(handle.key == (i % 4 == 0), "plate " .. i .. " of the cost fixture shows its " .. (i % 4 == 0 and "casting" or "idle") .. " set")
	end
	return env, ns
end

local function CastCycle(env, ns, token)
	local start, stop = Perf.Event(env, "UNIT_SPELLCAST_START", token), Perf.Event(env, "UNIT_SPELLCAST_STOP", token)
	local unit, cast = env._units[token], ns.Plates.Get(token).cast
	return function()
		unit.cast = CAST
		start()
		unit.cast = nil
		stop()
		cast:Hide()
	end
end

return {
	{
		name = "Nameplates UNIT_HEALTH",
		budget = 15,
		setup = function()
			local env = Plate()
			return env, Perf.Event(env, "UNIT_HEALTH", "nameplate1")
		end,
	},
	{
		name = "Nameplates UNIT_SPELLCAST_START",
		budget = 50,
		setup = function()
			local env = Plate()
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			return env, Perf.Event(env, "UNIT_SPELLCAST_START", "nameplate1")
		end,
	},
	{
		name = "Nameplates SPELL_UPDATE_COOLDOWN while casting",
		budget = 20,
		setup = function()
			local env = N.New({ playerClass = "WARRIOR", known = { [6552] = true } })
			N.Add(env, "nameplate1")
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			env.FireEvent("UNIT_SPELLCAST_START", "nameplate1")
			return env, Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
		end,
	},
	{
		-- Three bars recolour (one fill call each) plus one cooldown read: 6.5 us here; the CI runner measured
		-- 5.3 times this path's local time, so 80 is the README's 15x calibration with room for that runner.
		name = "Nameplates interrupt readiness flipping under three casts",
		budget = 80,
		setup = function()
			local env = N.New({ playerClass = "WARRIOR", known = { [6552] = true } })
			local cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			for i = 1, 3 do
				N.Add(env, "nameplate" .. i)
				env._units["nameplate" .. i].cast = cast
				env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
			end
			local busy, idle = { isActive = true, isOnGCD = false }, { isActive = false, isOnGCD = false }
			local fire = Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
			local flip = false
			return env, function()
				flip = not flip
				env._cooldowns[6552] = flip and busy or idle
				fire()
			end
		end,
	},
	{
		-- The plates do no work on UNIT_AURA: the debuff rows and their "+N" chip are the engine's. A target swap
		-- re-highlights every plate and decides, per plate, whether its cast stands down for the target sigil.
		name = "Nameplates PLAYER_TARGET_CHANGED over three casting plates",
		budget = 200,
		setup = function()
			local env = N.New()
			local cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			for i = 1, 3 do
				N.Add(env, "nameplate" .. i)
				N.Debuffs(env, "nameplate" .. i, 8)
				env._units["nameplate" .. i].cast = cast
				env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
			end
			N.Target(env, "nameplate1")
			return env, Perf.Event(env, "PLAYER_TARGET_CHANGED")
		end,
	},
	{
		-- Forty plates, each with its debuff container and the overflow chip's hidden counting container (round 5:
		-- Fable #4). The engine's own layout pass sizes those containers and moves the chips by anchors with no addon
		-- Lua, so the stub cannot time it; this times what does run across the forty: a target swap's fan-out. Lua 5.1
		-- takes 144 us here; 2000 is 14 times that, room for the CI runner's 4 times. A hundred calls a round keep
		-- the file inside its time and memory budget.
		name = "Nameplates PLAYER_TARGET_CHANGED over forty plates with their overflow ghosts",
		budget = 2000,
		calls = 100,
		setup = function()
			local env = N.New()
			local cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			for i = 1, 40 do
				N.Add(env, "nameplate" .. i)
				N.Debuffs(env, "nameplate" .. i, 8)
				if i % 4 == 0 then
					env._units["nameplate" .. i].cast = cast
					env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
				end
			end
			N.Target(env, "nameplate40")
			local fire = Perf.Event(env, "PLAYER_TARGET_CHANGED")
			local flip = false
			return env, function()
				flip = not flip
				env._targetUnit = flip and "nameplate1" or "nameplate40"
				fire()
			end
		end,
	},
	{
		-- A pull recycles plates: the game hands a base with its containers to a new unit, and the plate binds its
		-- debuff container and the chip's counting container to it, among forty plates. Lua 5.1 takes 27 us here.
		name = "Nameplates NAME_PLATE_UNIT_ADDED recycling a plate among forty",
		budget = 400,
		calls = 200,
		setup = function()
			local env = N.New()
			for i = 1, 40 do
				N.Add(env, "nameplate" .. i)
				N.Debuffs(env, "nameplate" .. i, 8)
			end
			local add, remove = Perf.Event(env, "NAME_PLATE_UNIT_ADDED", "nameplate40"), Perf.Event(env, "NAME_PLATE_UNIT_REMOVED", "nameplate40")
			return env, function()
				remove()
				add()
			end
		end,
	},
	{
		-- A later cast on a plate at Full: the cast bar shows and hides, and the plate swaps between its kept idle and
		-- casting ornament sets with region Show and Hide. Lua 5.1 takes 11 us here; re-placing the set on every cast
		-- took 140 us, so this budget fails if the swap is lost.
		name = "Nameplates cast start and stop on one plate at Full, later casts",
		budget = 110,
		calls = 200,
		setup = function()
			local env, ns = Forty()
			local cycle = CastCycle(env, ns, "nameplate2")
			cycle()
			return env, cycle
		end,
	},
	{
		-- The first cast after a change: a raid mark moves onto the plate, which re-places its idle set and drops the
		-- casting set, then the cast places the casting set once. Lua 5.1 takes 133 us here.
		name = "Nameplates raid mark onto a plate at Full, then its first cast",
		budget = 1300,
		calls = 50,
		setup = function()
			local env, ns = Forty()
			local cycle = CastCycle(env, ns, "nameplate2")
			local mark = Perf.Event(env, "RAID_TARGET_UPDATE")
			local unit, flip = env._units.nameplate2, false
			return env, function()
				flip = not flip
				unit.raid = flip and 8 or nil
				mark()
				cycle()
			end
		end,
	},
	{
		-- A pull at Full: forty plates leave and forty arrive, sixteen of them changing rank. Lua 5.1 takes 2350 us
		-- here (1310 at Off).
		name = "Nameplates forty-plate pull at Full",
		budget = 23000,
		calls = 4,
		setup = function()
			local env = Forty()
			local adds, removes, units, tokens, flip = {}, {}, {}, {}, false
			for i = 1, 40 do
				tokens[i] = "nameplate" .. i
				adds[i], removes[i] = Perf.Event(env, "NAME_PLATE_UNIT_ADDED", tokens[i]), Perf.Event(env, "NAME_PLATE_UNIT_REMOVED", tokens[i])
				units[i] = { env._units[tokens[i]], {} }
				for k, v in pairs(units[i][1]) do units[i][2][k] = v end
				units[i][2].classification = (i + 1) % 5 == 0 and "elite" or nil
			end
			return env, function()
				flip = not flip
				for i = 1, 40 do removes[i]() end
				for i = 1, 40 do
					env._units[tokens[i]] = units[i][flip and 2 or 1]
					adds[i]()
				end
			end
		end,
	},
	{
		name = "Nameplates QUEST_LOG_UPDATE with a plate",
		budget = 20,
		setup = function()
			local env = Plate()
			return env, Perf.Event(env, "QUEST_LOG_UPDATE")
		end,
	},
	{
		name = "Nameplates UNIT_FLAGS while casting",
		budget = 30,
		setup = function()
			local env = Plate()
			env._units.nameplate1.cast = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
			env.FireEvent("UNIT_SPELLCAST_START", "nameplate1")
			return env, Perf.Event(env, "UNIT_FLAGS", "nameplate1")
		end,
	},
}
