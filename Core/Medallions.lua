-- Medallions.lua: the secret-safe portrait and crest resolver; plain race, class and sex strings pick the painted art in MedallionAssets, and anything secret or missing falls back to the engine portrait.
local _, ns = ...

local Medallions = {}
ns.Medallions = Medallions

local CUTS = { bust = true, badge = true }

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Restricted(unit)
	local secrets = C_Secrets
	if not (secrets and secrets.ShouldUnitIdentityBeSecret) then
		return false
	end
	local restricted = secrets.ShouldUnitIdentityBeSecret(unit)
	return IsSecret(restricted) or restricted ~= false
end

function Medallions.Identity(unit)
	if type(unit) ~= "string" or not (UnitRace and UnitClass and UnitSex) or Restricted(unit) then
		return nil
	end
	local _, race = UnitRace(unit)
	local _, class = UnitClass(unit)
	local sex = UnitSex(unit)
	if not (Plain(race, "string") and Plain(class, "string") and Plain(sex, "number")) then
		return nil
	end
	return race, class, sex
end

local function Assets(kind)
	local assets = ns.MedallionAssets
	return type(assets) == "table" and type(assets[kind]) == "table" and assets[kind] or nil
end

local function Field(t, key)
	local value = type(t) == "table" and t[key] or nil
	return type(value) == "table" and value or nil
end

function Medallions.PortraitPath(unit, cut)
	local race, class, sex = Medallions.Identity(unit)
	if not race then
		return nil
	end
	local art = Field(Field(Field(Assets("portraits"), race), class), sex)
	local path = art and art[CUTS[cut] and cut or "bust"]
	return type(path) == "string" and path or nil
end

function Medallions.Portrait(texture, unit, cut)
	texture:SetTexCoord(0, 1, 0, 1)
	local path = Medallions.PortraitPath(unit, cut)
	if path then
		texture:SetTexture(path)
		return true
	end
	if SetPortraitTexture then
		SetPortraitTexture(texture, unit)
	end
	return false
end

function Medallions.Crest(unit)
	local race, class = Medallions.Identity(unit)
	if not race then
		return nil
	end
	local art = Field(Field(Assets("crests"), race), class)
	if not (art and type(art.crest) == "string") then
		return nil
	end
	return art.crest, art.glow, art.metal
end
