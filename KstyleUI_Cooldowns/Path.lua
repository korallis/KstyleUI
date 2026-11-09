-- Path.lua: which path each group takes (KstyleUI's mirror, Blizzard's viewer restyled in place, or off) and the switch when the mirror fails.
local _, ns = ...

local Path = {}
ns.Path = Path

local AURA_GROUPS = { buffs = true, bars = true }

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

function Path.ProbeAuras()
	local ok, why = Path.Probe()
	if not ok then
		return false, why
	end
	local api = C_UnitAuras
	if not (api and type(api.GetPlayerAuraBySpellID) == "function" and type(api.GetAuraDuration) == "function") then
		return false, "C_UnitAuras lacks GetPlayerAuraBySpellID or GetAuraDuration"
	end
	return true
end

function Path.AurasCanTurnSecret()
	return C_Secrets ~= nil and type(C_Secrets.ShouldAurasBeSecret) == "function"
end

local function Set(group, path, why)
	state[group], reasons[group] = path, why
	if path == "mirror" then
		ns.Log(group .. ": mirror path, KstyleUI frames driven by duration objects")
	elseif path == "reskin" then
		ns.Log(group .. ": reskin path, Blizzard's viewer restyled in place (" .. tostring(why) .. ")")
	else
		ns.Log(group .. ": off (" .. tostring(why) .. ")")
	end
	return path
end

local function Reskin(group, why)
	if ns.Viewers.Frame(group) then
		return Set(group, "reskin", why)
	end
	return Set(group, "off", tostring(why) .. "; " .. ns.Viewers.NAMES[group] .. " is missing too")
end

function Path.Choose(group, setting)
	if setting == "reskin" then
		return Reskin(group, "chosen in the settings")
	end
	local aura = AURA_GROUPS[group] == true
	local ok, why
	if aura then
		ok, why = Path.ProbeAuras()
	else
		ok, why = Path.Probe()
	end
	if not ok then
		return Reskin(group, why)
	end
	if setting ~= "mirror" and aura and Path.AurasCanTurnSecret() then
		return Reskin(group, "aura data can turn secret in combat, so KstyleUI cannot follow tracked buffs there")
	end
	return Set(group, "mirror")
end

function Path.Restyles(group, setting)
	if setting == "reskin" then
		return true
	end
	local aura = AURA_GROUPS[group] == true
	local ok
	if aura then
		ok = Path.ProbeAuras()
	else
		ok = Path.Probe()
	end
	if not ok then
		return true
	end
	return setting ~= "mirror" and aura and Path.AurasCanTurnSecret()
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
	ns.Log(group .. ": the mirror failed (" .. tostring(why) .. ")")
	Reskin(group, "the mirror failed")
	return true
end

function Path.Reset()
	for group in pairs(state) do
		state[group], reasons[group] = nil, nil
	end
end
