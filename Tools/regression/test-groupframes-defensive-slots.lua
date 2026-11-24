-- test-groupframes-defensive-slots.lua: Baine's v0.3.4 party frames showed Find Minerals, and a zone buff, in both default defensive indicators (slots 1 and 3). On a client that cannot classify defensives the two slots show nothing while a slot of another category still shows its aura; a client that classifies them shows its defensives there.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local FIND_MINERALS = { id = 2580, icon = 136025 }
local ZONE = { id = 1, icon = 136106 }
local PROTECTION = { id = 1022, icon = 135964, classes = { EXTERNAL_DEFENSIVE = true } }
local SHIELD_WALL = { id = 871, icon = 132362, classes = { BIG_DEFENSIVE = true } }

for _, forever in ipairs({ true, false }) do
	local what = forever and "no defensive classification" or "a client that classifies defensives"
	local env, K, ns = G.New({ setup = function(e)
		e.SetQuiet(true)
		e.InterfaceOverrides = { HasExternalDefensives = function() return not forever end }
		e.C_UnitAuras = e.C_UnitAuras or {}
		e.C_UnitAuras.AuraIsBigDefensive = function(id) return not forever and id == SHIELD_WALL.id end
		e._classifies = not forever and { EXTERNAL_DEFENSIVE = true, BIG_DEFENSIVE = true } or nil
	end })
	G.SetRoster(env, "party", { { name = "Xso", class = "PALADIN" }, { name = "Ninja", class = "PRIEST" } })
	assert(K.Modules.Enable("GroupFrames"))
	K.Options.Write("GroupFrames", "indicator2.category", "SPELLS")
	K.Options.Write("GroupFrames", "indicator2.spells", "2580")
	env.RunTimers()
	local f
	ns.Unit.ForEach(function(each)
		if each.unit == "party1" then f = each end
	end)
	assert(f and f.indicators, what .. ": the party member has indicator slots")
	G.Auras(env, "party1", forever and { FIND_MINERALS, ZONE } or { FIND_MINERALS, ZONE, PROTECTION, SHIELD_WALL })
	local want = forever and { false, FIND_MINERALS.icon, false } or { PROTECTION.icon, FIND_MINERALS.icon, SHIELD_WALL.icon }
	for i, icon in ipairs(want) do
		local button = f.indicators._slots["indicator" .. i].frame
		eq(button:IsShown() and button._aura.icon:GetTexture(), icon, what .. ": indicator " .. i .. " (" .. ns.Settings.current["indicator" .. i].category .. ") shows")
	end
	local notes = {}
	for _, row in ipairs(ns.Settings.Schema()) do
		if row.type == "note" and row.label:find("not available on this client", 1, true) and row.showWhen(ns.Settings.current) then
			notes[#notes + 1] = row.label
		end
	end
	eq(table.concat(notes, " "), forever and "External defensives are not available on this client. Big defensives are not available on this client." or "", what .. ": the options name what is not available")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("test-groupframes-defensive-slots: ok")
