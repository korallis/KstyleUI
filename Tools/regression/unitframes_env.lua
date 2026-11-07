-- unitframes_env.lua: load the core and KstyleUI_UnitFrames into a stub environment with fake units.
--
--   local U = dofile("Tools/regression/unitframes_env.lua")
--   local env, K, ns = U.New()             -- core booted, the module loaded, PLAYER_LOGIN fired
--   U.SetUnit(env, "target", { name = "Wolf", health = 50, healthMax = 200 })
--   env.SetTarget(true)
--
-- Units live in env._units[unit]. UnitHealth and UnitHealthPercent always return secrets, as on Forever;
-- UnitPower and UnitHealthMax return secrets while env._restricted is true. Fields a unit takes:
--   name, class (file name such as "MAGE"), level, health, healthMax, power, powerMax, powerType,
--   powerToken, isPlayer, reaction, dead, ghost, offline, tapDenied, classification, incoming, absorb
-- U.Shown(fontString) gives the text a font string shows, with secrets revealed, so a test can check
-- what SetText or SetFormattedText drew without the module ever reading a secret.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local U = { W = W }

local moduleFiles
function U.Files()
	if not moduleFiles then
		moduleFiles = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:match("^KstyleUI_UnitFrames/") then
				moduleFiles[#moduleFiles + 1] = path
			end
		end
		assert(#moduleFiles > 0, "no KstyleUI_UnitFrames files found")
	end
	return moduleFiles
end

local POWER_TYPES = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBO_POINTS = 4 }

-- Curves evaluate linearly between their points, as Enum.LuaCurveType.Linear does.
local function NewCurve()
	local curve = { points = {} }
	function curve:SetType(kind)
		self.kind = kind
	end
	function curve:AddPoint(x, y)
		self.points[#self.points + 1] = { x, y }
		table.sort(self.points, function(a, b)
			return a[1] < b[1]
		end)
	end
	function curve:Evaluate(x)
		local p = self.points
		if x <= p[1][1] then
			return p[1][2]
		end
		for i = 2, #p do
			if x <= p[i][1] then
				local a, b = p[i - 1], p[i]
				return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
			end
		end
		return p[#p][2]
	end
	return curve
end

-- Install(env) adds the unit API fakes to an environment before the core loads.
function U.Install(env)
	env._units = {
		player = {
			name = "Tester", class = "HUNTER", level = 60, health = 3120, healthMax = 3980,
			power = 2000, powerMax = 4000, powerType = 0, powerToken = "MANA", isPlayer = true, reaction = 5,
		},
	}
	env._restricted = false
	env._watched = {}
	env._portraits = {}

	local function unitOf(token)
		return env._units[token]
	end

	local function secretWhen(restricted, value)
		if restricted and value ~= nil then
			return env.Secret(value)
		end
		return value
	end

	function env.UnitExists(token)
		return unitOf(token) ~= nil
	end
	function env.UnitName(token)
		local u = unitOf(token)
		if u then
			return secretWhen(u.secretName, u.name), nil
		end
	end
	function env.UnitClass(token)
		local u = unitOf(token)
		if u and u.class then
			local file = u.class
			return secretWhen(u.secretClass, file:sub(1, 1) .. file:sub(2):lower()), secretWhen(u.secretClass, file), 1
		end
	end
	function env.UnitLevel(token)
		local u = unitOf(token)
		return u and u.level or 0
	end
	function env.UnitEffectiveLevel(token)
		return env.UnitLevel(token)
	end
	function env.UnitClassification(token)
		local u = unitOf(token)
		return u and u.classification or "normal"
	end
	function env.UnitIsPlayer(token)
		local u = unitOf(token)
		return u ~= nil and u.isPlayer == true
	end
	function env.UnitReaction(token)
		local u = unitOf(token)
		return u and u.reaction
	end
	function env.UnitIsDeadOrGhost(token)
		local u = unitOf(token)
		return u ~= nil and (u.dead == true or u.ghost == true)
	end
	function env.UnitIsGhost(token)
		local u = unitOf(token)
		return u ~= nil and u.ghost == true
	end
	function env.UnitIsConnected(token)
		local u = unitOf(token)
		return u ~= nil and u.offline ~= true
	end
	function env.UnitIsTapDenied(token)
		local u = unitOf(token)
		return u ~= nil and u.tapDenied == true
	end
	function env.UnitHealth(token)
		local u = unitOf(token)
		return env.Secret(u and u.health or 0)
	end
	function env.UnitHealthMax(token)
		local u = unitOf(token)
		return secretWhen(env._restricted, u and u.healthMax or 0)
	end
	function env.UnitHealthPercent(token, _, curve)
		local u = unitOf(token)
		local share = 0
		if u and u.healthMax and u.healthMax > 0 then
			share = u.health / u.healthMax
		end
		return env.Secret(curve and curve:Evaluate(share) or share)
	end
	function env.UnitPowerType(token)
		local u = unitOf(token)
		if u then
			return u.powerType or 0, u.powerToken or "MANA"
		end
	end
	function env.UnitPower(token, powerType)
		local u = unitOf(token)
		local value = u and u.power or 0
		if powerType and u and u.powers and u.powers[powerType] then
			value = u.powers[powerType]
		end
		return secretWhen(env._restricted, value)
	end
	function env.UnitPowerMax(token, powerType)
		local u = unitOf(token)
		local value = u and u.powerMax or 0
		if powerType and u and u.powerMaxes and u.powerMaxes[powerType] then
			value = u.powerMaxes[powerType]
		end
		return secretWhen(env._restricted, value)
	end
	function env.UnitPowerPercent(token, powerType, _, curve)
		local u = unitOf(token)
		local share = 0
		if u and u.powerMax and u.powerMax > 0 then
			share = u.power / u.powerMax
		end
		return secretWhen(env._restricted, curve and curve:Evaluate(share) or share)
	end
	function env.AbbreviateNumbers(value)
		if env.issecretvalue(value) then
			return env.Secret(tostring(env.Reveal(value)))
		end
		return tostring(value)
	end
	-- Unit watches show a frame while its unit exists, as SecureStateDriverManager does, and run the
	-- frame's OnShow and OnHide scripts on a change. They rescan with the state drivers.
	local function setVisible(frame, shown)
		local was = frame:IsShown()
		if shown then
			frame:Show()
		else
			frame:Hide()
		end
		local script = frame:GetScript(shown and "OnShow" or "OnHide")
		if was ~= shown and script then
			script(frame)
		end
	end
	function env.RunUnitWatches()
		for frame in pairs(env._watched) do
			setVisible(frame, env.UnitExists(frame:GetAttribute("unit")))
		end
	end
	function env.RegisterUnitWatch(frame)
		env._watched[frame] = true
		setVisible(frame, env.UnitExists(frame:GetAttribute("unit")))
	end
	function env.UnregisterUnitWatch(frame)
		env._watched[frame] = nil
	end
	function env.SetPortraitTexture(texture, token)
		env._portraits[texture] = token
	end
	function env.GetClassAtlas(class)
		return "classicon-" .. tostring(class)
	end
	env.CLASS_ICON_TCOORDS = { HUNTER = { 0, 0.25, 0.25, 0.5 }, MAGE = { 0.25, 0.5, 0, 0.25 } }
	env.PowerBarColor = {
		MANA = { r = 0, g = 0, b = 1 },
		RAGE = { r = 1, g = 0, b = 0 },
		ENERGY = { r = 1, g = 1, b = 0 },
		FOCUS = { r = 1, g = 0.5, b = 0.25 },
	}
	env.Enum = env.Enum or {}
	env.Enum.LuaCurveType = { Linear = 0, Step = 1 }
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
	env.Enum.PowerType = POWER_TYPES
	env.C_CurveUtil = { CreateCurve = NewCurve }
	env.C_Secrets = {
		ShouldAurasBeSecret = function()
			return env._restricted == true
		end,
	}
	function env.CreateUnitHealPredictionCalculator()
		local calc = { incoming = 0, absorb = 0 }
		function calc:GetIncomingHeals()
			return env.Secret(self.incoming), env.Secret(0), env.Secret(0), false
		end
		function calc:GetDamageAbsorbs()
			return env.Secret(self.absorb), false
		end
		function calc:SetIncomingHealClampMode(mode)
			self.clamp = mode
		end
		return calc
	end
	function env.UnitGetDetailedHealPrediction(token, _, calc)
		local u = unitOf(token)
		calc.incoming = u and u.incoming or 0
		calc.absorb = u and u.absorb or 0
	end
	function env.UnitIsGroupLeader(token)
		local u = unitOf(token)
		return u ~= nil and u.leader or false
	end
	function env.UnitGroupRolesAssigned(token)
		local u = unitOf(token)
		return u and u.role or "NONE"
	end
	function env.UnitIsPVP(token)
		local u = unitOf(token)
		return u ~= nil and u.pvp or false
	end
	function env.UnitIsPVPFreeForAll(token)
		local u = unitOf(token)
		return u ~= nil and u.ffa == true
	end
	function env.UnitFactionGroup(token)
		local u = unitOf(token)
		return u and u.faction, u and u.faction
	end
	function env.UnitAffectingCombat(token)
		local u = unitOf(token)
		return u ~= nil and u.combat or false
	end
	function env.UnitCanAttack(_, token)
		local u = unitOf(token)
		return u ~= nil and u.canAttack == true
	end
	env._resting = false
	function env.IsResting()
		return env._resting
	end
	-- Threat: a unit's own status in u.threat, and the player's status on a unit in u.threatOn.
	function env.UnitThreatSituation(token, mob)
		if mob then
			local u = unitOf(mob)
			return u and u.threatOn
		end
		local u = unitOf(token)
		return u and u.threat
	end
	env.THREAT_COLORS = { [1] = { 1, 1, 0.47 }, [2] = { 1, 0.6, 0 }, [3] = { 1, 0, 0 } }
	function env.GetThreatStatusColor(status)
		local c = env.THREAT_COLORS[status] or { 0.69, 0.69, 0.69 }
		return c[1], c[2], c[3]
	end
	-- GetRaidTargetIndex is always secret, even its nil for an unmarked unit.
	function env.GetRaidTargetIndex(token)
		local u = unitOf(token)
		return env.Secret(u and u.marker)
	end
	env._comboPoints = 0
	function env.GetComboPoints(unit, target)
		assert(unit == "player" and target == "target", "GetComboPoints reads the player's points on the target")
		return secretWhen(env._restricted, env._comboPoints)
	end
	-- Casts: u.cast and u.channel = { name, text, texture, start, finish (ms), notInterruptible, spellID }.
	-- u.secretCast makes every cast value secret but isTradeSkill, which Forever never makes secret.
	env._time = 1
	function env.GetTime()
		return env._time
	end
	local function castValues(u, info)
		local function wrap(value)
			if u.secretCast and value ~= nil then
				return env.Secret(value)
			end
			return value
		end
		return wrap(info.name), wrap(info.text or info.name), wrap(info.texture), wrap(info.start), wrap(info.finish), wrap(info.notInterruptible or false), wrap(info.spellID)
	end
	function env.UnitCastingInfo(token)
		local u = unitOf(token)
		if not (u and u.cast) then
			return
		end
		local name, text, texture, start, finish, locked, spell = castValues(u, u.cast)
		return name, text, texture, start, finish, false, "Cast-1", locked, spell, u.cast.barID or 1, 0
	end
	function env.UnitChannelInfo(token)
		local u = unitOf(token)
		if not (u and u.channel) then
			return
		end
		local name, text, texture, start, finish, locked, spell = castValues(u, u.channel)
		return name, text, texture, start, finish, false, locked, spell, false, 0, u.channel.barID or 1
	end
	local function duration(u, info)
		local d = { start = info.start / 1000, finish = info.finish / 1000 }
		function d:GetRemainingDuration()
			local left = math.max(0, self.finish - env._time)
			if u.secretCast then
				return env.Secret(left)
			end
			return left
		end
		if u.secretDuration then
			return env.Secret(d)
		end
		return d
	end
	function env.UnitCastingDuration(token)
		local u = unitOf(token)
		if u and u.nilDuration then
			return env.Secret(nil)
		end
		if u and u.cast then
			return duration(u, u.cast)
		end
	end
	function env.UnitChannelDuration(token)
		local u = unitOf(token)
		if u and u.channel then
			return duration(u, u.channel)
		end
	end
	env.Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
	function env.CreateColor(r, g, b, a)
		return { r = r, g = g, b = b, a = a or 1 }
	end
	function env.UnitFrame_OnEnter(frame)
		env._tooltip = frame.unit
	end
	function env.UnitFrame_OnLeave()
		env._tooltip = nil
	end

	-- Blizzard's frames that the module hides. Each is a stub frame on UIParent.
	for _, name in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer", "PlayerCastingBarFrame" }) do
		env.CreateFrame("Button", name, env.UIParent)
	end
	for i = 1, 5 do
		env.CreateFrame("Button", "Boss" .. i .. "TargetFrame", env.BossTargetFrameContainer)
	end
	U.Hook(env)
end

-- SetUnit(env, token, fields) creates or replaces a unit. nil removes it. Unit watches rescan.
function U.SetUnit(env, token, fields)
	env._units[token] = fields
	env.RunUnitWatches()
end

-- Hook(env) makes the stub's state-driver rescans, which SetTarget and SetCombat run, rescan unit watches too.
function U.Hook(env)
	local run = env.RunStateDrivers
	env.RunStateDrivers = function()
		run()
		env.RunUnitWatches()
	end
end

-- SizeEvents(env) makes SetSize run a frame's OnSizeChanged script, as the engine does when the size changes.
function U.SizeEvents(env)
	local create = env.CreateFrame
	env.CreateFrame = function(...)
		local frame = create(...)
		local setSize = frame.SetSize
		frame.SetSize = function(self, w, h)
			local ow, oh = self:GetSize()
			setSize(self, w, h)
			local script = self:GetScript("OnSizeChanged")
			if script and (ow ~= w or oh ~= h) then
				script(self, w, h)
			end
		end
		return frame
	end
end

-- New(opts) -> env, KstyleUI, ns. opts: the widget_env options, plus
--   enabled  false to leave the module switched off (default: on)
--   before   function(env, K) that runs after the saved data loads and before the module loads
--   login    false to stop before PLAYER_LOGIN
function U.New(opts)
	opts = opts or {}
	local setup = opts.setup
	opts.setup = function(env)
		U.Install(env)
		if setup then
			setup(env)
		end
	end
	if opts.enabled ~= false then
		opts.saved = opts.saved or {
			version = 2,
			profiles = { Default = { UnitFrames = { enabled = true } } },
			characters = {},
		}
	end
	opts.boot = false
	local env, K = W.New(opts)
	W.CoreEnv.LoadSaved(env)
	if opts.before then
		opts.before(env, K)
	end
	Load(U.Files(), env)
	if opts.login ~= false then
		W.CoreEnv.Login(env)
		env.RunTimers()
	end
	return env, K, env._addons.KstyleUI_UnitFrames
end

local function reveal(env, value)
	if env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end

-- Shown(env, fontString) -> the text the font string shows now, secrets revealed.
function U.Shown(env, text)
	for i = #text._calls, 1, -1 do
		local call = text._calls[i]
		if call.method == "SetText" then
			local value = reveal(env, call.args[1])
			return value == nil and "" or tostring(value)
		elseif call.method == "SetFormattedText" then
			local args = {}
			for j = 2, call.args.n do
				args[j - 1] = reveal(env, call.args[j])
			end
			return string.format(call.args[1], unpack(args, 1, call.args.n - 1))
		end
	end
	return ""
end

-- Value(env, bar) -> the value and range a status bar was given last, secrets revealed.
function U.Bar(env, bar)
	local value = W.LastCall(bar, "SetValue")
	local range = W.LastCall(bar, "SetMinMaxValues")
	return value and reveal(env, value[1]), range and reveal(env, range[1]), range and reveal(env, range[2])
end

return U
