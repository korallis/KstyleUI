-- Units.lua: unit tooltips: class and reaction colours, the guild and target lines, the unit edge and the health bar's colour.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, L = K.Tokens, K.Widgets, K.Theme, K.L
local Logic, Settings, Style, Health = ns.Logic, ns.Settings, ns.Style, ns.Health

local Units = {}
ns.Units = Units

local GUILD_SEARCH = 4

local function Plain(v)
	return not Logic.IsSecret(v) and v ~= nil
end

local function Text(v)
	return Plain(v) and type(v) == "string" and v ~= ""
end

local function Yes(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local v = fn(...)
	return Plain(v) and v == true
end

function Units.Token(data)
	local guid = data.guid
	if not Plain(guid) or type(UnitTokenFromGUID) ~= "function" then
		return nil
	end
	local unit = UnitTokenFromGUID(guid)
	if Text(unit) then
		return unit
	end
	return nil
end

local function Class(unit)
	if type(UnitClass) ~= "function" then
		return nil
	end
	local _, file = UnitClass(unit)
	if Text(file) then
		return file
	end
	return nil
end

function Units.ReactionColor(unit)
	if type(UnitReaction) ~= "function" then
		return nil
	end
	local reaction = UnitReaction(unit, "player")
	if Logic.IsNumber(reaction) then
		return Theme.ReactionColor(reaction)
	end
	return nil
end

function Units.NameColor(unit)
	if Yes(UnitIsPlayer, unit) then
		local class = Class(unit)
		if class then
			return Theme.ClassColor(class)
		end
	end
	return Units.ReactionColor(unit)
end

function Units.BarColor(unit)
	local source = Settings.Get("bar.color")
	if source == "custom" then
		local c = Settings.Get("bar.custom")
		return c.r, c.g, c.b
	end
	local r, g, b
	if unit and source == "reaction" then
		r, g, b = Units.ReactionColor(unit)
	elseif unit then
		r, g, b = Units.NameColor(unit)
	end
	if r then
		return r, g, b
	end
	return Settings.Accent()
end

local function Guild(tooltip, unit)
	if not Yes(UnitIsPlayer, unit) or type(GetGuildInfo) ~= "function" then
		return
	end
	local guild, rank = GetGuildInfo(unit)
	if not Text(guild) then
		return
	end
	local bracketed = Logic.GuildText(guild)
	for i = 2, math.min(GUILD_SEARCH, Style.NumLines(tooltip)) do
		local line = Style.Line(tooltip, "left", i)
		local text = line and line:GetText()
		if Plain(text) and (text == guild or text == bracketed) then
			local shown = Settings.Get("guildRank") and Text(rank) and rank or nil
			line:SetText(Logic.GuildText(guild, shown))
			Widgets.TextColor(line, Yes(UnitIsInMyGuild, unit) and "friendly" or "textEmphasis")
			return
		end
	end
	Settings.LogOnce("guild", "no tooltip line matched GetGuildInfo; the guild line keeps Blizzard's text")
end

local function Target(tooltip, unit)
	local target = unit .. "target"
	if not Yes(UnitExists, target) or type(UnitName) ~= "function" then
		return
	end
	local name = UnitName(target)
	if not Text(name) then
		Settings.LogOnce("target", "a target's name was secret or empty; the tooltip shows no target line")
		return
	end
	local r, g, b
	if Yes(UnitIsUnit, target, "player") then
		name = L["You"]
		r, g, b = Settings.Accent()
	else
		r, g, b = Units.NameColor(target)
		if not r then
			r, g, b = Tokens.Color("textEmphasis")
		end
	end
	local lr, lg, lb = Tokens.Color("text")
	tooltip:AddDoubleLine(L["Target"], name, lr, lg, lb, r, g, b)
end

function Units.Decorate(tooltip, data)
	local unit = Units.Token(data)
	if tooltip == GameTooltip then
		Health.SetColor(Units.BarColor(unit))
	end
	if not unit then
		Settings.LogOnce("unit", "a unit tooltip had no readable unit; it keeps Blizzard's lines")
		return
	end
	local r, g, b = Units.NameColor(unit)
	if r and Settings.Get("classNames") then
		local name = Style.Line(tooltip, "left", 1)
		if name then
			name:SetTextColor(r, g, b)
		end
	end
	if Settings.Get("guildLine") then
		Guild(tooltip, unit)
	end
	if Settings.Get("targetLine") then
		Target(tooltip, unit)
	end
	if r and Settings.Get("unitEdge") then
		Style.SetEdge(tooltip, r, g, b)
	end
end
