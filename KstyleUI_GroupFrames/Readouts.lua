-- Readouts.lua: two movable displays made only once switched on: your group's healers with their mana, and your raid group's number on a kit plate, both placed in Layout Mode.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Style, Unit, Frames = ns.Settings, ns.Style, ns.Unit, ns.Frames
local Plain, IsSecret = Unit.Plain, Unit.IsSecret

local Readouts = {}
ns.Readouts = Readouts

local MANA = 0
local MANA_KEY, LABEL_KEY = "groupframes.mana", "groupframes.label"
local MANA_AT = { anchor = "TOP", x = 0, y = -140 }
local LABEL_AT = { anchor = "TOP", x = 0, y = -96 }
local MANA_EM = 9
local LINE = 1.2
local EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE" }
local SAMPLE = { { "Sylaen", "DRUID", "80%" }, { "Vexen", "PRIEST", "90%" } }

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

local function Named(class, name, mana)
	local r, g, b = Unit.NameColor(class)
	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) .. name .. "|r " .. mana
end

local function PaintRow(row)
	local text, unit = row.text, row.unit
	local mana = Percent(unit)
	if not (Settings.current.mana.names and InRaid()) then
		text:SetText(mana)
		return
	end
	local name = UnitName(unit)
	if not IsSecret(name) and type(name) ~= "string" then name = "" end
	text:SetText(Named(Plain(select(2, UnitClass(unit)), "string"), name, mana))
end

local mana, label

local function Row(holder, i)
	local row = holder.rows[i]
	if not row then
		row = CreateFrame("Frame", nil, holder)
		row.text = Widgets.FontString(row, "OVERLAY")
		row.text:SetAllPoints(row)
		row:SetScript("OnEvent", PaintRow)
		holder.rows[i] = row
	end
	return row
end

local function Rows(holder, count)
	local cfg = Settings.current.mana
	local size, spacing = cfg.size, cfg.spacing
	local width, step = size * MANA_EM, size * LINE + spacing
	local height = math.max(1, count) * step - spacing
	local anchor, sign = "TOP", -1
	if cfg.growth == "UP" then anchor, sign = "BOTTOM", 1 end
	holder:SetSize(width, height)
	for i, row in ipairs(holder.rows) do
		row:ClearAllPoints()
		row:SetSize(width, size * LINE)
		row:SetPoint(anchor, holder, anchor, 0, sign * (i - 1) * step)
		Style.SetFont(row.text, Settings.current.text.healthFont, size, "OUTLINE")
		row.text:SetJustifyH(cfg.align)
		row.text:SetTextColor(ManaColor())
		row:SetShown(i <= count)
	end
	return height
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
		local row = Row(mana, i)
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

local function Plate(holder)
	local cfg = Settings.current.label
	if not holder.text then
		holder.chrome = Widgets.Chrome(holder, { shape = "panel" })
		holder.text = Widgets.FontString(holder, "OVERLAY")
		holder.text:SetPoint("CENTER", holder, "CENTER", 0, 0)
	end
	Style.SetFont(holder.text, Settings.current.text.healthFont, cfg.size, "NONE")
	holder.text:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
	local sample = cfg.format == "FULL" and GROUP_NUMBER and GROUP_NUMBER:format(8) or "8"
	local height = Widgets.Snap(holder, cfg.size * LINE + 2 * cfg.padding)
	holder:SetSize(Widgets.Snap(holder, ns.Names.Width(holder.text, sample, cfg.size) + 2 * cfg.padding), height)
	holder.chrome:Restyle()
	return height
end

local function Label()
	local cfg = Settings.current.label
	local on = cfg.enabled and Frames.Active()
	if not on and not label then return end
	label = label or Holder(LABEL_KEY, LABEL_AT, L["Your group label"])
	Plate(label)
	local group = on and Group()
	local known = IsSecret(group) or type(group) == "number"
	if known and cfg.format == "FULL" and GROUP_NUMBER then
		label.text:SetFormattedText(GROUP_NUMBER, group)
	elseif known then
		label.text:SetText(group)
	end
	Live(LABEL_KEY, label, on and known)
end

function Readouts.Refresh()
	Mana()
	Label()
end

function Readouts.Sample(list, plate)
	local cfg = Settings.current
	local listed, labelled = cfg.mana.mode ~= "NONE", cfg.label.enabled
	list:SetShown(listed)
	plate:SetShown(labelled)
	if listed then
		list.rows = list.rows or {}
		local names = cfg.mana.names and cfg.mana.mode ~= "PARTY"
		for i, healer in ipairs(SAMPLE) do
			Row(list, i).text:SetText(names and Named(healer[2], healer[1], healer[3]) or healer[3])
		end
	end
	local height = labelled and Plate(plate) or 0
	if labelled then plate.text:SetText(cfg.label.format == "FULL" and GROUP_NUMBER and GROUP_NUMBER:format(1) or "1") end
	return listed and Rows(list, #SAMPLE) or 0, height
end

for _, name in ipairs({ "Enable", "Disable", "Apply", "OnTransition" }) do
	local fn = Frames[name]
	Frames[name] = function(...)
		fn(...)
		Readouts.Refresh()
	end
end
Frames.events[#Frames.events + 1] = { event = "PLAYER_ROLES_ASSIGNED", fn = Readouts.Refresh }
local flushRoster = Unit.FlushRoster
function Unit.FlushRoster()
	local count = flushRoster()
	Readouts.Refresh()
	return count
end
