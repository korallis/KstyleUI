-- test-groupframes-defensive-slots.lua: Baine's v0.3.4 party frames showed a member's Find Minerals, and another's zone buff, twice on the bar: the two default defensive indicators. Forever has no external or big defensive classification (Camelot/InterfaceOverrides.lua: HasExternalDefensives() returns false) and in game the HELPFUL|EXTERNAL_DEFENSIVE and HELPFUL|BIG_DEFENSIVE slot filters pass any buff, so both slots took the member's top buff. On such a client the two slots stay off; a client that classifies them keeps them.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

-- A slot filter as Forever applies it in game: HELPFUL, HARMFUL and PLAYER narrow, the defensive tokens do not.
local function Passes(filter, aura)
	for part in filter:gmatch("[^|]+") do
		if part == "HELPFUL" and aura.harmful or part == "HARMFUL" and not aura.harmful or part == "PLAYER" and not aura.mine then
			return false
		end
	end
	return true
end

local AURAS = {
	{ name = "Find Minerals", id = 2580 },
	{ name = "a zone buff", id = 1 },
}

for _, forever in ipairs({ true, false }) do
	local what = forever and "Forever" or "a client that classifies defensives"
	local env, K, ns = G.New({ setup = function(e)
		e.SetQuiet(true)
		e.InterfaceOverrides = { HasExternalDefensives = function() return not forever end }
	end })
	G.SetRoster(env, "party", { { name = "Xso", class = "PALADIN" }, { name = "Ninja", class = "PRIEST" } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f
	ns.Unit.ForEach(function(each)
		if each.unit == "party1" then f = each end
	end)
	assert(f and f.indicators, what .. ": the party member has indicator slots")
	for _, aura in ipairs(AURAS) do
		local shown = {}
		for i = 1, 6 do
			local slot = f.indicators._slots["indicator" .. i]
			if slot.enabled and Passes(slot.filter, aura) then
				shown[#shown + 1] = ns.Settings.current["indicator" .. i].category
			end
		end
		eq(#shown, forever and 0 or 2, what .. ": slots that show " .. aura.name .. " (" .. table.concat(shown, ", ") .. ")")
	end
	eq(f.indicators._slots.indicator2.enabled, true, what .. ": the crowd control indicator stays on")
	eq(ns.Slots.Plan({ category = "EXTERNAL", spells = "" }) == nil, forever, what .. ": external defensives have no plan")
	eq(ns.Slots.Plan({ category = "BIG_DEFENSIVE", spells = "" }) == nil, forever, what .. ": big defensives have no plan")
	local notes = {}
	for _, row in ipairs(ns.Settings.Schema()) do
		if row.type == "note" and row.label:find("not available on this client", 1, true) and row.showWhen(ns.Settings.current) then
			notes[#notes + 1] = row.label
		end
	end
	eq(table.concat(notes, "; "), forever and "Indicator 1 is not available on this client.; Indicator 3 is not available on this client." or "", what .. ": the options say which indicators are not available")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("test-groupframes-defensive-slots: ok")
