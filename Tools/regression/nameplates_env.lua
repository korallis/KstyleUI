-- nameplates_env.lua: load the core and KstyleUI_Nameplates into a stub environment with fake nameplates, units and CVars.
--
--   local N = dofile("Tools/regression/nameplates_env.lua")
--   local env, K, ns = N.New()                         -- core booted, module loaded, logged in, switched on
--   local base = N.Add(env, "nameplate1", { name = "Kobold", health = 40 })
--   local plate = ns.Plates.Get("nameplate1")
--   N.Remove(env, "nameplate1")
--
-- Units are tables in env._units, keyed by unit token. N.UNIT lists the fields and their defaults.
-- The unit APIs read them: UnitHealth and UnitHealthPercent always return secrets, UnitName returns a
-- secret when the unit has secretName, and GetRaidTargetIndex returns a secret index or nil, as on
-- Forever. A nameplate's base frame is a stub frame with a UnitFrame child, as Blizzard's driver
-- gives it. C_CVar keeps CVars in env._cvars and records each write in env._cvarWrites; a write in
-- combat raises an error, as the game blocks nameplate CVars then.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Engine = dofile("Tools/regression/auras_env.lua").Engine

local N = { CoreEnv = CoreEnv }

N.UNIT = {
	name = "Kobold Miner",
	health = 40,
	maxHealth = 100,
	level = 10,
	classification = "normal",
	reaction = 2,
	canAttack = true,
	isPlayer = false,
	class = "WARRIOR",
	threat = nil,
	raid = nil,
	tapped = false,
	widgetsOnly = false,
	secretName = false,
	secretClass = false,
}

-- Blizzard's class colours for the classes the tests use.
N.CLASS = {
	HUNTER = { 0.67, 0.83, 0.45 },
	WARRIOR = { 0.78, 0.61, 0.43 },
	MAGE = { 0.25, 0.78, 0.92 },
}

N.CVAR_DEFAULTS = {
	nameplateMaxDistance = "60",
	nameplateMaxVerticalDistance = "0",
	nameplateSelectedScale = "1.2",
	nameplateMinScale = "0.8",
	nameplateSize = "2",
}

local moduleFiles
function N.Files()
	if not moduleFiles then
		moduleFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_Nameplates/") then
				moduleFiles[#moduleFiles + 1] = path
			end
		end
		assert(#moduleFiles > 0, "no KstyleUI_Nameplates files found")
	end
	return moduleFiles
end

local function colorObject(c)
	return {
		r = c[1], g = c[2], b = c[3],
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
	}
end

-- Install(env, opts) adds the fake game APIs, starting with the fake AuraContainer engine from
-- auras_env.lua. opts.noBitfield leaves out nameplateStackingTypes, opts.motion adds the older
-- nameplateMotion CVar, and opts.noAuraContainer makes the engine refuse to build a container.
function N.Install(env, opts)
	opts = opts or {}
	Engine(env, { noContainer = opts.noAuraContainer })
	env._units = {}
	env._bases = {}
	env._targetUnit, env._focusUnit = nil, nil
	env._role = "DAMAGER"
	env.WorldFrame = env.CreateFrame("Frame", nil, nil)

	local function unit(token)
		if token == "target" then
			token = env._targetUnit
		elseif token == "focus" then
			token = env._focusUnit
		end
		return token and env._units[token], token
	end
	N.ResolveUnit = unit

	function env.UnitClass(token)
		if token == "player" then
			return "Hunter", "HUNTER", 3
		end
		local u = unit(token)
		if u then
			if u.secretClass then
				return env.Secret(u.class), env.Secret(u.class), 1
			end
			return u.class, u.class, 1
		end
	end
	env.C_ClassColor = {
		GetClassColor = function(name)
			if env.issecretvalue(name) then
				local c = N.CLASS[env.Reveal(name)]
				return c and colorObject({ env.Secret(c[1]), env.Secret(c[2]), env.Secret(c[3]) }) or nil
			end
			local c = N.CLASS[name]
			return c and colorObject(c) or nil
		end,
	}

	function env.UnitExists(token)
		if token == "player" then
			return true
		end
		return unit(token) ~= nil
	end
	function env.UnitName(token)
		if token == "player" then
			return "Tester"
		end
		local u = unit(token)
		if u then
			return u.secretName and env.Secret(u.name) or u.name
		end
	end
	function env.UnitHealth(token)
		local u = unit(token)
		return env.Secret(u and u.health or 0)
	end
	function env.UnitHealthMax(token)
		local u = unit(token)
		return u and u.maxHealth or 1
	end
	function env.UnitHealthPercent(token, usePredicted, curve)
		local u = unit(token)
		local pct = u and u.health / u.maxHealth or 0
		if curve then
			pct = pct * 100
		end
		return env.Secret(pct)
	end
	env.CurveConstants = { ScaleTo100 = { curve = "ScaleTo100" } }
	function env.AbbreviateNumbers(value)
		return env.Secret("abbr:" .. tostring(env.issecretvalue(value) and env.Reveal(value) or value))
	end
	function env.UnitLevel(token)
		local u = unit(token)
		return u and u.level or 0
	end
	env.UnitEffectiveLevel = env.UnitLevel
	function env.UnitClassification(token)
		local u = unit(token)
		return u and u.classification or "normal"
	end
	function env.UnitReaction(a, b)
		local u = unit(a) or unit(b)
		return u and u.reaction
	end
	function env.UnitCanAttack(a, b)
		local u = unit(b) or unit(a)
		return u and u.canAttack or false
	end
	function env.UnitIsFriend(a, b)
		local u = unit(b) or unit(a)
		return u ~= nil and not u.canAttack
	end
	function env.UnitIsPlayer(token)
		if token == "player" then
			return true
		end
		local u = unit(token)
		return u and u.isPlayer or false
	end
	function env.UnitIsTapDenied(token)
		local u = unit(token)
		return u and u.tapped or false
	end
	function env.UnitNameplateShowsWidgetsOnly(token)
		local u = unit(token)
		return u and u.widgetsOnly or false
	end
	function env.UnitThreatSituation(a, b)
		local u = unit(b)
		return u and u.threat
	end
	env._inGroup = false
	function env.IsInGroup()
		return env._inGroup
	end
	function env.UnitGroupRolesAssigned(token)
		return token == "player" and env._role or "NONE"
	end
	function env.GetRaidTargetIndex(token)
		local u = unit(token)
		if u and u.raid then
			return env.Secret(u.raid)
		end
		return nil
	end
	function env.SetRaidTargetIconTexture(texture, index)
		texture:SetSpriteSheetCell(index, 4, 4)
	end
	function env.UnitIsUnit(a, b)
		local _, ta = unit(a)
		local _, tb = unit(b)
		return ta ~= nil and ta == tb
	end
	function env.GetQuestDifficultyColor(level)
		return { r = 1, g = 0.82, b = 0, font = "QuestDifficulty_Difficult" }
	end

	env.Enum = env.Enum or {}
	env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
	function env.CreateColor(r, g, b, a)
		return {
			r = r, g = g, b = b, a = a,
			GetRGBA = function(self)
				return self.r, self.g, self.b, self.a
			end,
		}
	end
	env._time = 1.5
	function env.GetTime()
		return env._time
	end

	-- A cast is unit.cast = { name, text, texture, notInterruptible, channel, secret, secretDuration }. It runs from
	-- 1000 to 3000 ms; its duration object reports 1.5 s remaining as a secret.
	local function castInfo(token, channel)
		local u = unit(token)
		local c = u and u.cast
		if not c or (c.channel and true or false) ~= channel then
			return nil
		end
		local function wrap(v)
			return c.secret and env.Secret(v) or v
		end
		return wrap(c.name), wrap(c.text), wrap(c.texture), wrap(1000), wrap(3000), c.notInterruptible ~= nil and wrap(c.notInterruptible) or nil
	end
	function env.UnitCastingInfo(token)
		local name, text, texture, startMs, endMs, flag = castInfo(token, false)
		if name == nil then
			return
		end
		return name, text, texture, startMs, endMs, false, "cast-guid", flag, 133
	end
	function env.UnitChannelInfo(token)
		local name, text, texture, startMs, endMs, flag = castInfo(token, true)
		if name == nil then
			return
		end
		return name, text, texture, startMs, endMs, false, flag, 689
	end
	local function duration(token, channel)
		local u = unit(token)
		if not (u and u.cast and (u.cast.channel and true or false) == channel) then
			return nil
		end
		if not u.castDuration then
			u.castDuration = {
				GetRemainingDuration = function()
					return env.Secret(1.5)
				end,
			}
			if u.cast.secretDuration then
				u.castDuration = env.Secret(u.castDuration)
			end
		end
		return u.castDuration
	end
	function env.UnitCastingDuration(token)
		return duration(token, false)
	end
	function env.UnitChannelDuration(token)
		return duration(token, true)
	end

	env.C_NamePlate = {
		GetNamePlateForUnit = function(token)
			if opts.strictTokens and not token:match("^nameplate%d+$") then
				error("GetNamePlateForUnit: bad unit token " .. token)
			end
			local _, resolved = unit(token)
			if token == "player" then
				resolved = env._playerPlate
			end
			return resolved and env._bases[resolved] or nil
		end,
		GetNamePlates = function()
			local out = {}
			for _, base in pairs(env._bases) do
				out[#out + 1] = base
			end
			return out
		end,
	}

	env._cvars, env._cvarWrites, env._cvarDefaults = {}, {}, {}
	for name, value in pairs(N.CVAR_DEFAULTS) do
		env._cvars[name], env._cvarDefaults[name] = value, value
	end
	local bits = {}
	if not opts.noBitfield then
		env._cvars.nameplateStackingTypes = "bitfield"
		env._cvarDefaults.nameplateStackingTypes = "bitfield"
		env._stacking = bits
	end
	if opts.motion then
		env._cvars.nameplateMotion, env._cvarDefaults.nameplateMotion = "0", "0"
	end
	local function write(name, value)
		assert(not env._combat, "C_CVar write in combat: " .. tostring(name))
		env._cvarWrites[#env._cvarWrites + 1] = { name = name, value = value }
	end
	env.C_CVar = {
		GetCVar = function(name)
			return env._cvars[name]
		end,
		GetCVarDefault = function(name)
			return env._cvarDefaults[name]
		end,
		SetCVar = function(name, value)
			if env._cvars[name] == nil then
				return false
			end
			write(name, value)
			env._cvars[name] = tostring(value)
			if name == "nameplateStackingTypes" and value == env._cvarDefaults[name] then
				for index in pairs(bits) do
					bits[index] = false
				end
			end
			return true
		end,
		GetCVarBitfield = function(name, index)
			return env._cvars[name] ~= nil and bits[index] == true or nil
		end,
		SetCVarBitfield = function(name, index, value)
			if env._cvars[name] == nil then
				return false
			end
			write(name .. "[" .. index .. "]", value)
			bits[index] = value and true or false
			return true
		end,
	}
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts: saved, setup(env), noBitfield, motion,
-- login (false: stop before PLAYER_LOGIN), enable (false: leave the module off), width and height
-- (the physical screen, default 1920x1080).
function N.New(opts)
	opts = opts or {}
	local env, K = CoreEnv.New({
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		setup = function(env)
			N.Install(env, opts)
			if opts.setup then
				opts.setup(env)
			end
		end,
	})
	CoreEnv.LoadSaved(env)
	Load(N.Files(), env)
	env.FireEvent("ADDON_LOADED", "KstyleUI_Nameplates", false)
	if opts.login ~= false then
		CoreEnv.Login(env)
		env.RunTimers()
		if opts.enable ~= false then
			K.Modules.Enable("Nameplates")
			env.RunTimers()
		end
	end
	return env, K, env._addons.KstyleUI_Nameplates
end

-- Base(env) -> a nameplate base frame as the game creates it, with Blizzard's UnitFrame, its
-- selectionHighlight and its SoftTargetFrame, which holds the soft-target icon.
function N.Base(env)
	local base = env.CreateFrame("Frame", nil, env.WorldFrame)
	base:SetSize(110, 45)
	base.UnitFrame = env.CreateFrame("Button", nil, base)
	base.UnitFrame.selectionHighlight = base.UnitFrame:CreateTexture(nil, "OVERLAY")
	base.UnitFrame.selectionHighlight:SetAlpha(0.25)
	local soft = env.CreateFrame("Frame", nil, base.UnitFrame)
	soft.Icon = soft:CreateTexture(nil, "ARTWORK")
	base.UnitFrame.SoftTargetFrame = soft
	base._calls = {}
	return base
end

-- Add(env, token, data, opts) -> base. Registers the unit, gives it a base frame (opts.base reuses
-- one) and fires NAME_PLATE_UNIT_ADDED. opts.lateUnitFrame attaches Blizzard's UnitFrame only after
-- the event, as when KstyleUI's handler runs before Blizzard's driver.
function N.Add(env, token, data, opts)
	opts = opts or {}
	local u = {}
	for k, v in pairs(N.UNIT) do
		u[k] = v
	end
	for k, v in pairs(data or {}) do
		u[k] = v
	end
	env._units[token] = u
	local base = opts.base or N.Base(env)
	local unitFrame = base.UnitFrame or env.CreateFrame("Button", nil, base)
	if opts.lateUnitFrame then
		base.UnitFrame = nil
	else
		base.UnitFrame = unitFrame
	end
	env._bases[token] = base
	env.FireEvent("NAME_PLATE_UNIT_ADDED", token)
	if opts.lateUnitFrame then
		base.UnitFrame = unitFrame
	end
	return base
end

function N.Remove(env, token)
	env.FireEvent("NAME_PLATE_UNIT_REMOVED", token)
	local base = env._bases[token]
	env._bases[token] = nil
	env._units[token] = nil
	if base then
		base._released = base.UnitFrame
		base.UnitFrame = nil
	end
	return base
end

-- Cast(env, token, cast) starts a cast or channel on a unit and fires its start event.
function N.Cast(env, token, cast)
	local copy = {}
	for k, v in pairs(cast) do
		copy[k] = v
	end
	env._units[token].cast = copy
	env._units[token].castDuration = nil
	env.FireEvent(copy.channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", token)
end

local function updating(env)
	local out = {}
	for _, frame in ipairs(env._frames) do
		if frame:GetScript("OnUpdate") then
			out[#out + 1] = frame
		end
	end
	return out
end

-- Tick(env, dt) runs every OnUpdate once; Settle(env) runs them in 16 ms steps until none is left.
function N.Tick(env, dt)
	for _, frame in ipairs(updating(env)) do
		frame:GetScript("OnUpdate")(frame, dt or 0.016)
	end
end

function N.Settle(env)
	for _ = 1, 1000 do
		if #updating(env) == 0 then
			return
		end
		N.Tick(env, 0.016)
	end
	error("Settle: an OnUpdate kept running for 1000 frames")
end

function N.Target(env, token)
	env._targetUnit = token
	env._target = token ~= nil
	env.FireEvent("PLAYER_TARGET_CHANGED")
end

function N.Focus(env, token)
	env._focusUnit = token
	env.FireEvent("PLAYER_FOCUS_CHANGED")
end

-- Calls(frame, method) -> the recorded calls of one method on a stub frame, oldest first.
function N.Calls(frame, method)
	local out = {}
	for _, call in ipairs(frame._calls) do
		if call.method == method then
			out[#out + 1] = call.args
		end
	end
	return out
end

function N.Last(frame, method)
	local calls = N.Calls(frame, method)
	return calls[#calls]
end

-- Color(name) -> r, g, b of a token, through the loaded core.
function N.Same(a, b)
	return math.abs(a - b) < 1e-6
end

function N.SameColor(r1, g1, b1, r2, g2, b2)
	return N.Same(r1, r2) and N.Same(g1, g2) and N.Same(b1, b2)
end

return N
