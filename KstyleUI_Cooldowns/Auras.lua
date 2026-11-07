-- Auras.lua: finds the aura a tracked buff follows and hands its duration object to KstyleUI icons and bars, never reading secret aura data.
local _, ns = ...

local Auras = {}
ns.Auras = Auras

local HARMFUL = "HARMFUL|PLAYER"
local MIN_STACKS = 2

local function Secret()
	local api = C_Secrets
	if not (api and api.ShouldAurasBeSecret) then
		return false
	end
	local ok, secret = pcall(api.ShouldAurasBeSecret)
	if not ok or issecretvalue(secret) then
		return true
	end
	return secret == true
end
Auras.Secret = Secret

local function PlayerAura(spell)
	local api = C_UnitAuras
	if not (spell and api and api.GetPlayerAuraBySpellID) then
		return nil
	end
	local ok, aura = pcall(api.GetPlayerAuraBySpellID, spell)
	if not ok then
		return nil
	end
	if issecretvalue(aura) then
		return nil
	end
	if type(aura) ~= "table" then
		return nil
	end
	local id = aura.auraInstanceID
	if issecretvalue(id) then
		return nil
	end
	if type(id) == "number" then
		return id
	end
	return nil
end

local function TargetAura(spell)
	local api = C_UnitAuras
	if not (spell and api and api.GetAuraDataBySpellName and C_Spell and C_Spell.GetSpellName and UnitExists and UnitExists("target")) then
		return nil
	end
	local okName, name = pcall(C_Spell.GetSpellName, spell)
	if not okName or ns.IsSecret(name) or type(name) ~= "string" then
		return nil
	end
	local ok, aura = pcall(api.GetAuraDataBySpellName, "target", name, HARMFUL)
	if not ok then
		return nil
	end
	if issecretvalue(aura) then
		return nil
	end
	if type(aura) ~= "table" then
		return nil
	end
	local id = aura.auraInstanceID
	if issecretvalue(id) then
		return nil
	end
	if type(id) == "number" then
		return id
	end
	return nil
end

local function Search(entry, find)
	local spell = entry.spell
	local id = find(spell)
	if id then
		return id
	end
	if entry.spellID ~= spell then
		id = find(entry.spellID)
		if id then
			return id
		end
	end
	local linked = entry.linked
	if linked then
		for _, linkedSpell in ipairs(linked) do
			if ns.Plain(linkedSpell) then
				id = find(linkedSpell)
				if id then
					return id
				end
			end
		end
	end
	return nil
end

function Auras.Find(entry)
	if not entry then
		return nil
	end
	local id = Search(entry, PlayerAura)
	if id then
		return "player", id
	end
	id = Search(entry, TargetAura)
	if id then
		return "target", id
	end
	return nil
end

function Auras.Duration(unit, id)
	local api = C_UnitAuras
	if not (api and api.GetAuraDuration) then
		return nil
	end
	local ok, duration = pcall(api.GetAuraDuration, unit, id)
	if ok then
		return duration
	end
	return nil, tostring(duration)
end

function Auras.Permanent(unit, id)
	local api = C_UnitAuras
	if not (api and api.DoesAuraHaveExpirationTime) then
		return false
	end
	local ok, expires = pcall(api.DoesAuraHaveExpirationTime, unit, id)
	if not ok then
		return false
	end
	if issecretvalue(expires) then
		return false
	end
	return expires == false
end

function Auras.Stacks(unit, id)
	local api = C_UnitAuras
	if not (api and api.GetAuraApplicationDisplayCount) then
		return nil
	end
	local ok, text = pcall(api.GetAuraApplicationDisplayCount, unit, id, MIN_STACKS)
	if ok then
		return text
	end
	return nil
end
