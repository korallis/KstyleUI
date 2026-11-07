-- Data.lua: what the minimap reads from the game: zone, clock, coordinates and rotation, each guarded for missing APIs and secrets.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Format = ns.Format

local Data = {}
ns.Data = Data

local PVP_LABELS = {
	sanctuary = L["Sanctuary"],
	friendly = L["Friendly territory"],
	hostile = L["Hostile territory"],
	contested = L["Contested territory"],
	arena = L["Free-for-all territory"],
	combat = L["Combat zone"],
}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	return fn(...)
end

local function CVarOn(name)
	if type(GetCVarBool) ~= "function" then
		return nil
	end
	local value = GetCVarBool(name)
	if IsSecret(value) then
		return nil
	end
	return value == true
end

function Data.Zone()
	local text = Call(GetMinimapZoneText)
	local pvpType
	local pvp = C_PvP
	if pvp then
		pvpType = Call(pvp.GetZonePVPInfo)
	end
	return text, pvpType
end

function Data.PvPLabel(pvpType)
	if IsSecret(pvpType) or type(pvpType) ~= "string" then
		return nil
	end
	return PVP_LABELS[pvpType]
end

function Data.LocalTime()
	if type(date) ~= "function" then
		return nil
	end
	local now = date("*t")
	if type(now) ~= "table" then
		return nil
	end
	return now.hour, now.min
end

function Data.RealmTime()
	return Call(GetGameTime)
end

function Data.IsText(value)
	return not IsSecret(value) and type(value) == "string" and value ~= ""
end

function Data.Uses24(mode)
	if mode == "local12" or mode == "realm12" then
		return false
	elseif mode == "local24" or mode == "realm24" then
		return true
	end
	return CVarOn("timeMgrUseMilitaryTime") ~= false
end

function Data.Clock(mode)
	if mode == "game" or mode == nil then
		local realm = CVarOn("timeMgrUseLocalTime") == false
		mode = (realm and "realm" or "local") .. (Data.Uses24("game") and "24" or "12")
	end
	local hour, minute
	if mode == "realm24" or mode == "realm12" then
		hour, minute = Data.RealmTime()
	else
		hour, minute = Data.LocalTime()
	end
	return Format.Time(hour, minute, mode == "local24" or mode == "realm24")
end

function Data.Coords(precision)
	local map = C_Map
	if not map or type(map.GetBestMapForUnit) ~= "function" or type(map.GetPlayerMapPosition) ~= "function" then
		return nil
	end
	local mapID = map.GetBestMapForUnit("player")
	if IsSecret(mapID) or type(mapID) ~= "number" then
		return nil
	end
	local position = map.GetPlayerMapPosition(mapID, "player")
	if IsSecret(position) or type(position) ~= "table" or type(position.GetXY) ~= "function" then
		return nil
	end
	local x, y = position:GetXY()
	return Format.Coords(x, y, precision)
end

function Data.Rotating()
	local on = CVarOn("rotateMinimap")
	if on == nil then
		return type(GetCVarBool) == "function"
	end
	return on
end
