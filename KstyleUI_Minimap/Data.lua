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
	local hour, minute = tonumber((date("%H"))), tonumber((date("%M")))
	if not hour or not minute then
		return nil
	end
	return hour, minute
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

function Data.RuleActive(name)
	local rules, enum = C_GameRules, Enum and Enum.GameRule
	local rule = enum and enum[name]
	if not (rules and type(rules.IsGameRuleActive) == "function" and rule ~= nil) then
		return false
	end
	local active = rules.IsGameRuleActive(rule)
	return not IsSecret(active) and active == true
end

function Data.HasMail()
	local mail = Call(HasNewMail)
	return not IsSecret(mail) and mail == true
end

function Data.MailSenders()
	local out = {}
	if type(GetLatestThreeSenders) ~= "function" then
		return out
	end
	local senders = { GetLatestThreeSenders() }
	for i = 1, 3 do
		local sender = senders[i]
		if Data.IsText(sender) then
			out[#out + 1] = sender
		end
	end
	return out
end

function Data.PendingInvites()
	local calendar = C_Calendar
	local count = calendar and Call(calendar.GetNumPendingInvites)
	if IsSecret(count) or type(count) ~= "number" then
		return 0
	end
	return count
end

function Data.Queued()
	local button = QueueStatusButton
	if not button then
		return false
	end
	local shown = button:IsShown()
	return not IsSecret(shown) and shown == true
end

local function Filters()
	local constants = MinimapConstants
	if type(constants) ~= "table" then
		return {}, {}, {}
	end
	return constants.ALWAYS_ON_FILTERS or {}, constants.CONDITIONAL_FILTERS or {}, constants.OPTIONAL_FILTERS or {}
end

local function Tracking()
	local minimap = C_Minimap
	if not minimap or type(minimap.GetNumTrackingTypes) ~= "function" or type(minimap.GetTrackingInfo) ~= "function"
		or type(minimap.GetTrackingFilter) ~= "function" or type(minimap.SetTracking) ~= "function" then
		return nil
	end
	return minimap
end

function Data.HasTracking()
	return Tracking() ~= nil
end

function Data.TrackingEntries()
	local minimap = Tracking()
	local out = {}
	if not minimap then
		return out
	end
	local _, _, optional = Filters()
	local showAll = CVarOn("minimapTrackingShowAll") == true
	for index = 1, minimap.GetNumTrackingTypes() do
		local info, filter = minimap.GetTrackingInfo(index), minimap.GetTrackingFilter(index)
		if type(info) == "table" and type(filter) == "table" and Data.IsText(info.name) then
			if showAll or optional[filter.filterID] or filter.spellID then
				out[#out + 1] = { index = index, name = info.name }
			end
		end
	end
	return out
end

function Data.TrackingActive(index)
	local minimap = Tracking()
	local info = minimap and minimap.GetTrackingInfo(index)
	return type(info) == "table" and not IsSecret(info.active) and info.active == true
end

function Data.SetTracking(index, on)
	local minimap = Tracking()
	if minimap then
		minimap.SetTracking(index, on == true)
	end
end

function Data.ClearTracking()
	local minimap = Tracking()
	if not minimap or type(minimap.ClearAllTracking) ~= "function" then
		return
	end
	minimap.ClearAllTracking()
	local always, conditional = Filters()
	for index = 1, minimap.GetNumTrackingTypes() do
		local filter = minimap.GetTrackingFilter(index)
		if type(filter) == "table" and (always[filter.filterID] or conditional[filter.filterID]) then
			minimap.SetTracking(index, true)
		end
	end
end
