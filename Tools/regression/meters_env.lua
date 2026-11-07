-- meters_env.lua: load the core and KstyleUI_Meters into a stub environment with stand-ins for the game's swing, threat and Damage Meter APIs.
--
--   local M = dofile("Tools/regression/meters_env.lua")
--   local env, K, ns = M.New()        -- core booted, KstyleUI_Meters loaded, module still off
--   M.Enable(env, K)                  -- switches the module on
--   env.SetTime(12.5); M.Tick(env)    -- moves the clock and steps every OnUpdate once
--
-- The stand-ins read env tables a test fills in:
--   env._units[unit] = { name, class, hostile, exists }   UnitExists, UnitName, UnitClass, UnitCanAttack
--   env._threat[unit] = { tanking, status, scaled, raw, threat }   UnitDetailedThreatSituation(unit, mob)
--   env._group = { raid = false, size = 0 }               IsInRaid, IsInGroup, GetNumGroupMembers
--   env._speeds = { main, off, ranged }                   UnitAttackSpeed("player")
--   env._inRange[swingType]                               C_SwingTimer.IsTargetWithinSwingRange
--   env._session                                          C_DamageMeter.GetCombatSessionFromType
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local M = { W = W, CoreEnv = W.CoreEnv }

local files
function M.Files()
	if not files then
		files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Meters/") then
				files[#files + 1] = path
			end
		end
		assert(#files > 0, "no KstyleUI_Meters files found")
	end
	return files
end

M.SWING = { MainHand = 0, OffHand = 1, Ranged = 2 }
M.METER = {
	DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
	DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10,
}
M.SESSION = { Overall = 0, Current = 1, Expired = 2 }

-- A stand-in Blizzard frame made outside the addon, so it never counts as a frame the module made.
local function Blizzard(env, name, parent)
	local frame = env.CreateFrame("Frame", name, parent or env.UIParent)
	frame._blizzard = true
	return frame
end
M.Blizzard = Blizzard

-- Game(env, opts) installs the stand-ins. opts.noSwing, opts.noMeter and opts.noThreat leave an API out.
function M.Game(env, opts)
	opts = opts or {}
	env._time = 100
	env.GetTime = function()
		return env._time
	end
	function env.SetTime(t)
		env._time = t
	end
	env.Enum = env.Enum or {}
	env.Enum.PlayerSwingType = M.SWING
	env.Enum.DamageMeterType = M.METER
	env.Enum.DamageMeterSessionType = M.SESSION
	env.Enum.DamageMeterSourceDisplayType = { None = 0, Ally = 1, Enemy = 2 }

	env._units = { player = { name = "Tester", class = "HUNTER" } }
	env._threat = {}
	env._group = { raid = false, size = 0 }
	env._speeds = { 2.6, nil, nil }
	env._inRange = {}
	env._rangeChecks = {}
	env._combatFlag = false
	env._session = { combatSources = {}, maxAmount = 0, totalAmount = 0 }

	env.UnitExists = function(unit)
		local u = env._units[unit]
		return u ~= nil and u.exists ~= false
	end
	env.UnitName = function(unit)
		local u = env._units[unit]
		return u and u.name
	end
	env.UnitClass = function(unit)
		local u = env._units[unit]
		if u and u.class then
			return u.class, u.class, 1
		end
	end
	env.UnitCanAttack = function(_, unit)
		local u = env._units[unit]
		return u ~= nil and u.hostile == true
	end
	env.UnitIsUnit = function(a, b)
		local ua, ub = env._units[a], env._units[b]
		return ua ~= nil and ua == ub
	end
	env.UnitAffectingCombat = function()
		return env._combatFlag
	end
	env.IsInRaid = function()
		return env._group.raid == true
	end
	env.IsInGroup = function()
		return env._group.size > 0
	end
	env.GetNumGroupMembers = function()
		return env._group.size
	end
	if not opts.noThreat then
		env.UnitDetailedThreatSituation = function(unit)
			local t = env._threat[unit]
			if t then
				return t[1], t[2], t[3], t[4], t[5]
			end
		end
	end
	env.UnitAttackSpeed = function()
		return env._speeds[1], env._speeds[2], env._speeds[3]
	end
	if not opts.noSwing then
		env.C_SwingTimer = {
			IsTargetWithinSwingRange = function(swingType)
				return env._inRange[swingType]
			end,
			EnableRangeCheck = function(swingType, on)
				env._rangeChecks[#env._rangeChecks + 1] = { swingType, on }
			end,
		}
	end
	if not opts.noMeter then
		env.C_DamageMeter = {
			IsDamageMeterAvailable = function()
				return true, ""
			end,
			GetCombatSessionFromType = function(sessionType, meterType)
				env._lastSession = { sessionType, meterType }
				return env._session
			end,
		}
	end
	env._locked = setmetatable({}, { __mode = "k" })
	env.canaccesstable = function(t)
		return not env._locked[t]
	end
	env.AbbreviateNumbers = function(n)
		if env.issecretvalue(n) then
			return env.Secret("~" .. tostring(env.Reveal(n)))
		end
		return "~" .. tostring(n)
	end
	env.RAID_CLASS_COLORS = nil
	env.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest", ROGUE = "Rogue", HUNTER = "Hunter" }

	if not opts.noBlizzard then
		env.SwingTimerMainHandFrame = Blizzard(env, "SwingTimerMainHandFrame")
		env.SwingTimerOffHandFrame = Blizzard(env, "SwingTimerOffHandFrame")
		env.SwingTimerRangedFrame = Blizzard(env, "SwingTimerRangedFrame")
		env.DamageMeter = Blizzard(env, "DamageMeter")
	end
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts: the widget_env options, plus the Game
-- options and opts.game(env), which runs after the stand-ins are installed.
function M.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local env, K = W.New({
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		setup = function(env)
			M.Game(env, opts)
			if opts.game then
				opts.game(env)
			end
			if setup then
				setup(env)
			end
		end,
	})
	env._moduleFrames = #env._frames
	Load(M.Files(), env)
	return env, K, env._addons.KstyleUI_Meters
end

function M.Enable(env, K)
	K.Modules.Enable("Meters")
	env.RunTimers()
end

function M.Disable(env, K)
	K.Modules.Disable("Meters")
	env.RunTimers()
end

-- Tick(env, dt) steps every frame's OnUpdate once.
function M.Tick(env, dt)
	W.Tick(env, dt or 0.016)
end

function M.Write(env, K, key, value)
	K.Options.Write("Meters", key, value)
	env.RunTimers()
end

-- Logged(env, text) -> the first devlog message of the Meters module that holds text, or nil.
function M.Logged(env, text)
	for _, entry in ipairs(env.KstyleUIDB.devlog or {}) do
		if entry.module == "Meters" and tostring(entry.message):find(text, 1, true) then
			return entry.message
		end
	end
end

-- Calls(frame, method) -> how many times the stub recorded a call of method on frame.
function M.Calls(frame, method)
	local n = 0
	for _, call in ipairs(frame._calls) do
		if call.method == method then
			n = n + 1
		end
	end
	return n
end

-- Last(frame, method) -> the arguments of the last call of method on frame, or nil.
function M.Last(frame, method)
	for i = #frame._calls, 1, -1 do
		local call = frame._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

return M
