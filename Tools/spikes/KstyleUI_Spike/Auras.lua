-- Auras.lua: the auras spike times C_Secrets.ShouldAurasBeSecret() flips against ENCOUNTER_START and combat, and samples combo point secrecy.
local _, ns = ...

local WINDOW = 900
local SAMPLE = 0.1
local EVENTS = { "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }

local function AurasSecret()
	local secrets = C_Secrets
	if not secrets or type(secrets.ShouldAurasBeSecret) ~= "function" then
		return "unavailable"
	end
	return ns.Try(secrets.ShouldAurasBeSecret)
end

local function Restrictions()
	local api, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
	if not api or type(api.GetAddOnRestrictionState) ~= "function" or type(types) ~= "table" then
		return "unavailable"
	end
	local states = {}
	for name, value in pairs(types) do
		local state = ns.Try(api.GetAddOnRestrictionState, value)
		states[name] = ns.EnumName(Enum.AddOnRestrictionState, state) or state
	end
	return states
end

ns.Register("auras", {
	group = "pull",
	summary = "times ShouldAurasBeSecret() against ENCOUNTER_START and combat, and samples combo point secrecy, for 15 minutes.",
	Run = function(run)
		local comboType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints
		local combo = { inCombat = { secret = 0, plain = 0 }, outOfCombat = { secret = 0, plain = 0 } }
		local last = AurasSecret()
		local encounter = false
		run:Set("comboPoints", combo)
		run:Set("windowSeconds", WINDOW)
		run:Set("initial", { aurasSecret = last, inCombat = ns.InCombat(), restrictions = Restrictions() })

		local function SampleCombo()
			if comboType == nil or type(UnitPower) ~= "function" then
				return
			end
			local ok, value = pcall(UnitPower, "player", comboType)
			if ok then
				local bucket = ns.InCombat() and combo.inCombat or combo.outOfCombat
				if ns.IsSecret(value) then
					bucket.secret = bucket.secret + 1
				else
					bucket.plain = bucket.plain + 1
				end
			end
		end

		local ticker = ns.Ticker(SAMPLE, function()
			local now = AurasSecret()
			if now ~= last then
				last = now
				run:Add("flips", { t = run:Since(), aurasSecret = now, inCombat = ns.InCombat(), encounter = encounter })
			end
			SampleCombo()
		end)
		local listener, failed = ns.Listen(EVENTS, function(event, a, b)
			if event == "ENCOUNTER_START" then
				encounter = true
			elseif event == "ENCOUNTER_END" then
				encounter = false
			end
			local entry = { t = run:Since(), event = event, aurasSecret = AurasSecret(), inCombat = ns.InCombat() }
			if event == "ADDON_RESTRICTION_STATE_CHANGED" then
				entry.type = ns.EnumName(Enum and Enum.AddOnRestrictionType, a) or ns.Describe(a)
				entry.state = ns.EnumName(Enum and Enum.AddOnRestrictionState, b) or ns.Describe(b)
			elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
				entry.encounterID = ns.Describe(a)
				entry.encounterName = ns.Describe(b)
			end
			run:Add("events", entry)
			SampleCombo()
		end)
		if #failed > 0 then
			run:Set("unregisteredEvents", failed)
		end
		ns.After(WINDOW, function() ns.Stop("auras", "timeout", run) end)
		return function()
			if ticker then
				ticker:Cancel()
			end
			ns.Unlisten(listener)
		end
	end,
})
