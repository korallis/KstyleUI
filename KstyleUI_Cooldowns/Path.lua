-- Path.lua: which path each group takes, the mirror or nothing, and the switch away from the mirror when it fails.
local _, ns = ...

local Path = {}
ns.Path = Path

local state = {}
local reasons = {}

function Path.Probe()
	local ok, why = ns.Data.Available()
	if not ok then
		return false, why
	end
	if not (C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function") then
		return false, "C_Spell.GetSpellCooldownDuration is missing"
	end
	return true
end

function Path.Choose(group)
	local ok, why = Path.Probe()
	if ok then
		state[group], reasons[group] = "mirror", nil
		ns.Log(group .. ": mirror path, KstyleUI icons driven by duration objects")
	else
		state[group], reasons[group] = "off", why
		ns.Log(group .. ": the mirror cannot run (" .. tostring(why) .. "); Blizzard's viewer stays as it is")
	end
	return state[group]
end

function Path.Get(group)
	return state[group]
end

function Path.Reason(group)
	return reasons[group]
end

function Path.Fail(group, why)
	if state[group] ~= "mirror" then
		return false
	end
	state[group], reasons[group] = "failed", why
	ns.Log(group .. ": the mirror failed (" .. tostring(why) .. "); Blizzard's viewer shows again")
	return true
end

function Path.Reset()
	for group in pairs(state) do
		state[group], reasons[group] = nil, nil
	end
end
