-- Meters.lua: the meters spike records which power types can be secret and whether Damage Meter values go secret in combat.
local _, ns = ...

local WINDOW = 900
local FIRST_SAMPLE = 3
local AFTER_COMBAT = 2
local INTERVAL = 5
local MAX_SAMPLES = 60
local SESSION_FIELDS = { "totalAmount", "maxAmount", "durationSeconds" }
local SOURCE_FIELDS = { "name", "totalAmount", "amountPerSecond", "classFilename", "isLocalPlayer", "sourceGUID" }

local function Kind(value)
	if ns.IsSecret(value) then
		return "secret"
	elseif value == nil then
		return "nil"
	end
	return "plain"
end

local function Field(tbl, key)
	local ok, value = pcall(function() return tbl[key] end)
	return ok and Kind(value) or "error"
end

local function PowerTypes()
	local types, secrets = {}, C_Secrets
	if not (Enum and type(Enum.PowerType) == "table") then
		return "unavailable"
	end
	for name, value in pairs(Enum.PowerType) do
		local entry = {}
		if secrets and type(secrets.GetPowerTypeSecrecy) == "function" then
			local level = ns.Try(secrets.GetPowerTypeSecrecy, value)
			entry.secrecy = ns.EnumName(Enum.SecrecyLevel, level) or level
		end
		if secrets and type(secrets.ShouldUnitPowerBeSecret) == "function" then
			entry.playerSecretAtStart = ns.Try(secrets.ShouldUnitPowerBeSecret, "player", value)
		end
		types[name] = entry
	end
	return types
end

local function Session()
	local meter = C_DamageMeter
	local sessionTypes, meterTypes = Enum and Enum.DamageMeterSessionType, Enum and Enum.DamageMeterType
	if not (meter and type(meter.GetCombatSessionFromType) == "function" and sessionTypes and meterTypes) then
		return { session = "unavailable" }
	end
	local ok, session = pcall(meter.GetCombatSessionFromType, sessionTypes.Current, meterTypes.DamageDone)
	if not ok then
		return { session = "error: " .. tostring(session) }
	elseif ns.IsSecret(session) then
		return { session = "secret" }
	elseif type(session) ~= "table" then
		return { session = type(session) }
	end
	local result = { session = "table", fields = {} }
	if type(issecrettable) == "function" then
		result.secretTable = ns.Try(issecrettable, session)
	end
	for _, key in ipairs(SESSION_FIELDS) do
		result.fields[key] = Field(session, key)
	end
	local okSources, sources = pcall(function() return session.combatSources end)
	if okSources and type(sources) == "table" and not ns.IsSecret(sources) then
		local okFirst, first = pcall(function() return sources[1] end)
		if okFirst and type(first) == "table" and not ns.IsSecret(first) then
			result.source = {}
			for _, key in ipairs(SOURCE_FIELDS) do
				result.source[key] = Field(first, key)
			end
		end
	end
	return result
end

ns.Register("meters", {
	group = "pull",
	summary = "records power type secrecy and whether Damage Meter session values go secret in combat, for 15 minutes.",
	Run = function(run)
		local live = true
		run:Set("windowSeconds", WINDOW)
		run:Set("powerTypes", PowerTypes())
		if C_DamageMeter and type(C_DamageMeter.IsDamageMeterAvailable) == "function" then
			local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
			run:Set("available", ok and ns.Describe(available) or "error")
			run:Set("failureReason", ok and ns.Describe(reason) or nil)
		else
			run:Set("available", "unavailable")
		end

		local samples = 0
		local function Sample()
			if not live or samples >= MAX_SAMPLES then
				return
			end
			samples = samples + 1
			local entry = Session()
			entry.t = run:Since()
			entry.inCombat = ns.InCombat()
			local secrets = C_Secrets
			if secrets and type(secrets.ShouldUnitPowerBeSecret) == "function" and Enum and Enum.PowerType then
				entry.comboSecret = ns.Try(secrets.ShouldUnitPowerBeSecret, "player", Enum.PowerType.ComboPoints)
			end
			run:Add("samples", entry)
		end

		Sample()
		local ticker = ns.Ticker(INTERVAL, function()
			if ns.InCombat() then
				Sample()
			end
		end)
		local listener = ns.Listen({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }, function(event)
			ns.After(event == "PLAYER_REGEN_DISABLED" and FIRST_SAMPLE or AFTER_COMBAT, Sample)
		end)
		ns.After(WINDOW, function() ns.Stop("meters", "timeout", run) end)
		return function()
			live = false
			if ticker then
				ticker:Cancel()
			end
			ns.Unlisten(listener)
		end
	end,
})
