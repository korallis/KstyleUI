-- Units.lua: unit tooltips: class and reaction colours, the away tag, the guild, target, mount and item level lines, the level line's colours and compact form, the faction colour, the buff icons, the unit edge and the health bar's colour.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets, Theme, L = K.Tokens, K.Widgets, K.Theme, K.L
local Logic, Settings, Style, Health = ns.Logic, ns.Settings, ns.Style, ns.Health

local Units = {}
ns.Units = Units

local GUILD_SEARCH = 4
local MAX_AURAS = 40
local INSPECT_GAP, INSPECT_AGE = 1.5, 300
local INSPECT, BUFFS = "TooltipsInspect", "TooltipsBuffs"
local levels, pending, hover = {}, nil, nil
local icons, showing, stamp, buffUnit, hooked, host = {}, 0, 0, nil, false, nil

local function Plain(v)
	return not Logic.IsSecret(v) and v ~= nil
end

local function Text(v)
	return Plain(v) and type(v) == "string" and v ~= ""
end

local Yes = Logic.Yes

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

function Units.Pair(tooltip, label, text)
	if Text(text) then
		local lr, lg, lb = Tokens.Color("text")
		local rr, rg, rb = Tokens.Color("textEmphasis")
		tooltip:AddDoubleLine(label, text, lr, lg, lb, rr, rg, rb)
	end
end

local function Off(fn)
	local v = type(fn) == "function" and fn()
	return Plain(v) and v == false
end

local function AurasReadable()
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		return ok and Plain(secret) and secret == false
	end
	return Off(InCombatLockdown)
end

local function Mount(tooltip, unit)
	local auras, journal = C_UnitAuras, C_MountJournal
	if not (auras and journal and type(auras.GetAuraDataByIndex) == "function" and type(journal.GetMountFromSpell) == "function" and type(journal.GetMountInfoByID) == "function") or not AurasReadable() then
		return
	end
	for i = 1, MAX_AURAS do
		local ok, aura = pcall(auras.GetAuraDataByIndex, unit, i, "HELPFUL")
		if not ok or not Plain(aura) or type(aura) ~= "table" or not Plain(aura.spellId) then
			return
		end
		local mount = journal.GetMountFromSpell(aura.spellId)
		if Plain(mount) then
			Units.Pair(tooltip, L["Mount"], journal.GetMountInfoByID(mount))
			return
		end
	end
end

local function AddLevel(tooltip, level)
	Units.Pair(tooltip, L["Item level"], Logic.IDText(math.floor(level)))
end

local function Ready(_, guid)
	local ask = pending
	if not ask or not Plain(guid) or guid ~= ask.guid then
		return
	end
	pending = nil
	K.Events.Unregister(INSPECT, "INSPECT_READY")
	local now = type(UnitGUID) == "function" and UnitGUID(ask.unit)
	local get = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
	if not Plain(now) or now ~= guid or type(get) ~= "function" then
		return
	end
	local ok, level = pcall(get, ask.unit)
	if not ok or not Logic.IsNumber(level) or level <= 0 then
		return
	end
	levels[guid] = { level = level, time = GetTime() }
	if hover and hover.guid == guid and not hover.level and Settings.Get("itemLevel") then
		hover.level = true
		AddLevel(GameTooltip, level)
		GameTooltip:Show()
	end
end

local function Inspect(unit, guid)
	local now = GetTime()
	local frame = InspectFrame
	local open = type(frame) == "table" and frame:IsShown()
	if (pending and now - pending.time < INSPECT_GAP) or not Off(InCombatLockdown) or not Plain(open) or open
		or type(NotifyInspect) ~= "function" or not Yes(CanInspect, unit) then
		return
	end
	pending = { guid = guid, unit = unit, time = now }
	K.Events.Register(INSPECT, "INSPECT_READY", Ready)
	NotifyInspect(unit)
end

local function ItemLevel(tooltip, unit, guid)
	local level
	if Yes(UnitIsUnit, unit, "player") then
		if type(GetAverageItemLevel) == "function" then
			level = select(2, GetAverageItemLevel())
		end
	else
		local known = levels[guid]
		level = known and known.level
		if not known or GetTime() - known.time > INSPECT_AGE then
			Inspect(unit, guid)
		end
	end
	if Logic.IsNumber(level) and level > 0 then
		AddLevel(tooltip, level)
		return true
	end
	return false
end

local function LevelLine(tooltip, unit)
	local compact, byLevel, byClass = Settings.Get("compactLevel"), Settings.Get("levelColor"), Settings.Get("classLine")
	local prefix = (compact or byLevel or byClass) and Logic.LevelPrefix(TOOLTIP_UNIT_LEVEL)
	if not prefix then
		return
	end
	local levelColor, className, classColor
	local level = byLevel and type(UnitLevel) == "function" and UnitLevel(unit)
	if Logic.IsNumber(level) and level > 0 and type(GetCreatureDifficultyColor) == "function" then
		local c = GetCreatureDifficultyColor(level)
		levelColor = type(c) == "table" and Logic.IsNumber(c.r) and Logic.IsNumber(c.g) and Logic.IsNumber(c.b) and c or nil
	end
	if byClass and Yes(UnitIsPlayer, unit) and type(UnitClass) == "function" then
		local name, file = UnitClass(unit)
		local r, g, b
		if Text(name) and Text(file) then
			r, g, b = Theme.ClassColor(file)
		end
		className, classColor = name, r and { r = r, g = g, b = b }
	end
	local suffix = type(PLAYER) == "string" and " (" .. PLAYER .. ")" or nil
	for i = 2, Style.NumLines(tooltip) do
		local line = Style.Line(tooltip, "left", i)
		local text = line and Logic.LevelLine(line:GetText(), prefix, compact, suffix, levelColor, className, classColor)
		if text then
			line:SetText(text)
			return
		end
	end
end

local function Faction(tooltip, unit)
	if type(UnitFactionGroup) ~= "function" or type(GetFactionColor) ~= "function" then
		return
	end
	local tag, name = UnitFactionGroup(unit)
	local color = Text(tag) and Text(name) and GetFactionColor(tag)
	if type(color) ~= "table" or type(color.GetRGB) ~= "function" then
		return
	end
	for i = 2, Style.NumLines(tooltip) do
		local line = Style.Line(tooltip, "left", i)
		local text = line and line:GetText()
		if Plain(text) and text == name then
			line:SetTextColor(color:GetRGB())
			return
		end
	end
end

local function Buffs(unit)
	local glass, count = Style.Glass(GameTooltip), 0
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if glass and unit and Settings.Get("buffs.shown") and type(get) == "function" and AurasReadable() then
		if not host then
			host = CreateFrame("Frame", nil, UIParent)
			host:SetFrameStrata("TOOLTIP")
		end
		if host.stamp ~= stamp then
			host.stamp = stamp
			local scale = GameTooltip:GetScale()
			host:SetScale(Logic.IsNumber(scale) and scale > 0 and scale or 1)
		end
		for i = 1, MAX_AURAS do
			local ok, aura = pcall(get, unit, i, "HELPFUL")
			if not ok or not Plain(aura) or type(aura) ~= "table" or not Plain(aura.icon) then
				break
			end
			count = i
			local icon = icons[i] or Style.IconTile(host)
			icons[i] = icon
			if icon.stamp ~= stamp then
				icon.stamp = stamp
				Style.PlaceBuff(icon, glass, i)
				Style.PaintIcon(icon)
			end
			icon.texture:SetTexture(aura.icon)
			icon:Show()
		end
	end
	for i = count + 1, showing do
		icons[i]:Hide()
	end
	showing = count
end

local function OnAura(_, unit)
	if buffUnit and (unit == buffUnit or Yes(UnitIsUnit, unit, buffUnit)) then
		Buffs(buffUnit)
	end
end

local function OnCombat()
	Buffs(buffUnit)
end

local function Follow(unit)
	if unit and not buffUnit then
		K.Events.Register(BUFFS, "UNIT_AURA", OnAura)
		K.Events.Register(BUFFS, "PLAYER_REGEN_DISABLED", OnCombat)
		K.Events.Register(BUFFS, "PLAYER_REGEN_ENABLED", OnCombat)
	elseif not unit and buffUnit then
		K.Events.UnregisterAll(BUFFS)
	end
	buffUnit = unit
	Buffs(unit)
end

local function Clear()
	hover = nil
	if buffUnit then
		Follow(nil)
	end
end

local function Hook()
	if not hooked then
		hooked = true
		GameTooltip:HookScript("OnTooltipCleared", Clear)
		GameTooltip:HookScript("OnHide", Clear)
	end
end

function Units.Restyle()
	stamp = stamp + 1
	if buffUnit then
		Follow(ns.active and Settings.Get("buffs.shown") and buffUnit or nil)
	end
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
	if not Settings.Get("playerTitles") and Yes(UnitIsPlayer, unit) and type(UnitName) == "function" then
		local name, line = UnitName(unit), Style.Line(tooltip, "left", 1)
		if line and Text(name) then line:SetText(name) end
	end
	if Settings.Get("awayTag") and Yes(UnitIsPlayer, unit) then
		local tag = Yes(UnitIsAFK, unit) and CHAT_FLAG_AFK or Yes(UnitIsDND, unit) and CHAT_FLAG_DND
		local line = Style.Line(tooltip, "left", 1)
		local text = line and line:GetText()
		if Text(tag) and Text(text) then line:SetText(text .. " " .. tag) end
	end
	local r, g, b = Units.NameColor(unit)
	if Settings.Get("qualityColors") and type(UnitReaction) == "function" then
		local reaction = UnitReaction(unit, "player")
		if Logic.IsNumber(reaction) then
			r, g, b = Tokens.Color(reaction <= 3 and "nameHostile" or reaction == 4 and "neutral" or "friendly")
		end
	end
	if r and Settings.Get("classNames") then
		local name = Style.Line(tooltip, "left", 1)
		if name then
			name:SetTextColor(r, g, b)
		end
	end
	Style.Title(tooltip)
	if Settings.Get("guildLine") then
		Guild(tooltip, unit)
	end
	if Settings.Get("targetLine") then
		Target(tooltip, unit)
	end
	if Settings.Get("mountLine") and Yes(UnitIsPlayer, unit) then
		Mount(tooltip, unit)
	end
	if tooltip == GameTooltip and Settings.Get("itemLevel") and Yes(UnitIsPlayer, unit) then
		Hook()
		hover = { guid = data.guid }
		hover.level = ItemLevel(tooltip, unit, data.guid)
	end
	LevelLine(tooltip, unit)
	if Settings.Get("factionColor") then
		Faction(tooltip, unit)
	end
	if tooltip == GameTooltip and Settings.Get("buffs.shown") then
		Hook()
		Follow(unit)
	end
	if r and Settings.Get("unitEdge") then
		Style.SetEdge(tooltip, r, g, b)
	end
end
