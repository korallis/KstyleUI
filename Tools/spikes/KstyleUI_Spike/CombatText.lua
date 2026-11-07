-- CombatText.lua: the combat spike records which units fire UNIT_COMBAT and which of its arguments are secret, in and out of combat.
local _, ns = ...

local WINDOW = 900
local ARGS = 5
local NAMEPLATE = "^nameplate%d+$"

local function Bucket()
	return { count = 0, secret = { 0, 0, 0, 0, 0 } }
end

ns.Register("combat", {
	group = "pull",
	summary = "records UNIT_COMBAT per unit token and which arguments are secret, for 15 minutes.",
	Run = function(run)
		local units, kinds = {}, {}
		run:Set("units", units)
		run:Set("kinds", kinds)
		run:Set("nameplateFired", false)
		run:Set("nameplateTokens", 0)
		run:Set("windowSeconds", WINDOW)
		run:Set("instanceType", ns.Describe(IsInInstance and select(2, IsInInstance()) or nil))
		local listener, failed = ns.Listen({ "UNIT_COMBAT" }, function(_, unit, ...)
			local key
			if ns.IsSecret(unit) then
				key = "<secret>"
			elseif type(unit) == "string" then
				key = unit
			else
				key = "<" .. type(unit) .. ">"
			end
			local entry = units[key]
			if not entry then
				entry = { inCombat = Bucket(), outOfCombat = Bucket(), first = run:Since() }
				units[key] = entry
				if key:match(NAMEPLATE) then
					run:Set("nameplateFired", true)
					run:Count("nameplateTokens")
				end
			end
			local bucket = ns.InCombat() and entry.inCombat or entry.outOfCombat
			bucket.count = bucket.count + 1
			for i = 1, ARGS do
				if ns.IsSecret((select(i, unit, ...))) then
					bucket.secret[i] = bucket.secret[i] + 1
				end
			end
			local kind = ...
			if not ns.IsSecret(kind) and type(kind) == "string" then
				kinds[kind] = (kinds[kind] or 0) + 1
			end
		end)
		if #failed > 0 then
			run:Set("unregisteredEvents", failed)
		end
		ns.After(WINDOW, function() ns.Stop("combat", "timeout", run) end)
		return function()
			ns.Unlisten(listener)
		end
	end,
})
