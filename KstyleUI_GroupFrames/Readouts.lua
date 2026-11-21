-- Readouts.lua: two movable displays made only once switched on: your group's healers with their mana, and your raid group's number on a kit plate, both placed in Layout Mode.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Style, Unit, Frames = ns.Settings, ns.Style, ns.Unit, ns.Frames

local Readouts = {}
ns.Readouts = Readouts

local MANA = 0
local MANA_KEY, LABEL_KEY = "groupframes.mana", "groupframes.label"
local MANA_AT = { anchor = "TOP", x = 0, y = -140 }
local LABEL_AT = { anchor = "TOP", x = 0, y = -96 }
local MANA_EM = 9
local LINE = 1.2
local EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE" }

local issecretvalue = issecretvalue or function()
	return false
end

local function Plain(value, kind)
	if issecretvalue(value) or type(value) ~= kind then return nil end
	return value
end

local function Holder(key, position, label)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(1, 1)
	Widgets.Place(holder, key, position, { label = label, module = Settings.MODULE })
	return holder
end

local function Live(key, holder, on)
	holder:SetShown(on)
	if K.Layout and K.Layout.SetLive then K.Layout.SetLive(key, on) end
end

local function InRaid()
	return Plain(IsInRaid and IsInRaid(), "boolean") == true
end

local function Wanted(mode)
	local raid = InRaid()
	local party = not raid and Plain(IsInGroup and IsInGroup(), "boolean") == true
	return mode == "BOTH" and (raid or party) or mode == "RAID" and raid or mode == "PARTY" and party
end

local function Members()
	local count = Plain(GetNumGroupMembers and GetNumGroupMembers(), "number") or 0
	local out = {}
	if InRaid() then
		for i = 1, count do out[i] = "raid" .. i end
	else
		out[1] = "player"
		for i = 1, count - 1 do out[#out + 1] = "party" .. i end
	end
	return out
end

local function ManaColor()
	local cfg = Settings.current.mana
	if cfg.colorSource == "custom" then
		return cfg.color.r, cfg.color.g, cfg.color.b
	end
	local c = K.Theme.Palette("MANA") or type(PowerBarColor) == "table" and PowerBarColor.MANA
	if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
	return Tokens.Color("rare")
end

local function Percent(unit)
	local curve = Unit.Curves()
	if not (curve and UnitPowerPercent) then return "" end
	return Widgets.ShortNumber(Widgets.WholePercent(UnitPowerPercent(unit, MANA, false, curve))) .. "%"
end

local function Hex(r, g, b)
	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function PaintRow(row)
	local text, unit = row.text, row.unit
	local mana = Percent(unit)
	if not (Settings.current.mana.names and InRaid()) then
		text:SetText(mana)
		return
	end
	local name = UnitName(unit)
	if not issecretvalue(name) and type(name) ~= "string" then name = "" end
	text:SetText(Hex(Unit.NameColor(Plain(select(2, UnitClass(unit)), "string"))) .. name .. "|r " .. mana)
end

local mana, label

local function Rows(holder, count)
	local cfg = Settings.current.mana
	local size, spacing = cfg.size, cfg.spacing
	local width, step = size * MANA_EM, size * LINE + spacing
	holder:SetSize(width, math.max(1, count) * step - spacing)
	for i, row in ipairs(holder.rows) do
		row:ClearAllPoints()
		row:SetSize(width, size * LINE)
		local y = (i - 1) * step
		if cfg.growth == "UP" then
			row:SetPoint("BOTTOM", holder, "BOTTOM", 0, y)
		else
			row:SetPoint("TOP", holder, "TOP", 0, -y)
		end
		Style.SetFont(row.text, Settings.current.text.healthFont, size, "OUTLINE")
		row.text:SetJustifyH(cfg.align)
		row.text:SetTextColor(ManaColor())
		row:SetShown(i <= count)
	end
end

local function Mana()
	local cfg = Settings.current.mana
	local on = cfg.mode ~= "NONE" and Frames.Active() and Wanted(cfg.mode)
	if not on and not mana then return end
	mana = mana or Holder(MANA_KEY, MANA_AT, L["Healer mana"])
	mana.rows = mana.rows or {}
	local healers = {}
	for _, unit in ipairs(on and Members() or {}) do
		if Plain(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit), "string") == "HEALER" then healers[#healers + 1] = unit end
	end
	for i, unit in ipairs(healers) do
		local row = mana.rows[i]
		if not row then
			row = CreateFrame("Frame", nil, mana)
			row.text = Widgets.FontString(row, "OVERLAY")
			row.text:SetAllPoints(row)
			row:SetScript("OnEvent", PaintRow)
			mana.rows[i] = row
		end
		row.unit = unit
		for _, event in ipairs(EVENTS) do row:RegisterUnitEvent(event, unit) end
		PaintRow(row)
	end
	for i = #healers + 1, #mana.rows do mana.rows[i]:UnregisterAllEvents() end
	Rows(mana, #healers)
	Live(MANA_KEY, mana, on)
end

local function Group()
	local index = Plain(UnitInRaid and UnitInRaid("player"), "number")
	if not index or not GetRaidRosterInfo then return nil end
	local _, _, group = GetRaidRosterInfo(index)
	return group
end

local function LabelText(text, group, format)
	if format == "FULL" and GROUP_NUMBER then
		text:SetFormattedText(GROUP_NUMBER, group)
	else
		text:SetText(group)
	end
end

local function Label()
	local cfg = Settings.current.label
	local on = cfg.enabled and Frames.Active()
	if not on and not label then return end
	if not label then
		label = Holder(LABEL_KEY, LABEL_AT, L["Your group label"])
		label.chrome = Widgets.Chrome(label, { shape = "panel" })
		label.text = Widgets.FontString(label, "OVERLAY")
		label.text:SetPoint("CENTER", label, "CENTER", 0, 0)
	end
	local group = on and Group()
	Style.SetFont(label.text, Settings.current.text.healthFont, cfg.size, "NONE")
	label.text:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
	local sample = cfg.format == "FULL" and GROUP_NUMBER and GROUP_NUMBER:format(8) or "8"
	label:SetSize(Widgets.Snap(label, ns.Names.Width(label.text, sample, cfg.size) + 2 * cfg.padding), Widgets.Snap(label, cfg.size * LINE + 2 * cfg.padding))
	label.chrome:Restyle()
	local known = issecretvalue(group) or type(group) == "number"
	if known then LabelText(label.text, group, cfg.format) end
	Live(LABEL_KEY, label, on and known)
end

function Readouts.Refresh()
	Mana()
	Label()
end

function Readouts.Sample()
	local parts, cfg = {}, Settings.current
	if cfg.mana.mode ~= "NONE" then
		local r, g, b = ManaColor()
		parts[#parts + 1] = Hex(r, g, b) .. (cfg.mana.names and "Sylaen " or "") .. "87%|r"
	end
	if cfg.label.enabled then
		parts[#parts + 1] = cfg.label.format == "FULL" and GROUP_NUMBER and GROUP_NUMBER:format(1) or "1"
	end
	return #parts > 0 and table.concat(parts, "   ") or nil
end

for _, name in ipairs({ "Enable", "Disable", "Apply" }) do
	local fn = Frames[name]
	Frames[name] = function(...)
		fn(...)
		Readouts.Refresh()
	end
end
Frames.events[#Frames.events + 1] = { event = "PLAYER_ROLES_ASSIGNED", fn = Readouts.Refresh }
local rosterChanged = Unit.RosterChanged
function Unit.RosterChanged(...)
	rosterChanged(...)
	Readouts.Refresh()
end
