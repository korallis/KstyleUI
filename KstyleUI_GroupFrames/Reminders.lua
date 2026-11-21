-- Reminders.lua: the missing buff on each group frame: the first buff you know that a member lacks, read by spell name only while aura data is not secret.
local _, ns = ...

local K = KstyleUI
local Widgets = K.Widgets
local Settings, Style, Unit, Frames, Auras = ns.Settings, ns.Style, ns.Unit, ns.Frames, ns.Auras

local Reminders = {}
ns.Reminders = Reminders

local BUFFS = {
	{ key = "fortitude", spells = { 1243, 21562 } },
	{ key = "wild", spells = { 1126, 21849 } },
	{ key = "intellect", spells = { 1459, 23028 }, mana = true },
	{ key = "spirit", spells = { 14752, 27681 }, mana = true },
	{ key = "thorns", spells = { 467 }, tanks = true },
	{ key = "salvation", spells = { 1038, 25895 }, notTanks = true },
}
Reminders.BUFFS = BUFFS
local FILTER = "HELPFUL"
local MANA = 0

local issecretvalue = issecretvalue or function()
	return false
end

local known
local hasTank = false

local function Plain(value, kind)
	if issecretvalue(value) or type(value) ~= kind then return nil end
	return value
end

local function Known()
	if known then return known end
	known = {}
	local book, spell = C_SpellBook, C_Spell
	if not (book and type(book.IsSpellKnown) == "function" and spell and type(spell.GetSpellName) == "function") then
		Style.LogOnce("reminders", "C_SpellBook.IsSpellKnown or C_Spell.GetSpellName is missing; no missing buff shows")
		return known
	end
	for _, buff in ipairs(BUFFS) do
		local ok, has = pcall(book.IsSpellKnown, buff.spells[1])
		if ok and Plain(has, "boolean") then
			local names = {}
			for _, id in ipairs(buff.spells) do
				names[#names + 1] = Plain(spell.GetSpellName(id), "string")
			end
			known[#known + 1] = { buff = buff, names = names, icon = spell.GetSpellTexture and spell.GetSpellTexture(buff.spells[1]) }
		end
	end
	return known
end

local function Has(unit, names)
	local api = C_UnitAuras
	if not (api and type(api.GetAuraDataBySpellName) == "function") then return nil end
	for _, name in ipairs(names) do
		local ok, aura = pcall(api.GetAuraDataBySpellName, unit, name, FILTER)
		if not ok or issecretvalue(aura) then return nil end
		if type(aura) == "table" then return true end
	end
	return false
end

local function Role(unit)
	return Plain(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit), "string")
end

local function Wanted(buff, unit, role, cfg)
	if buff.notTanks and role == "TANK" then
		return false
	elseif buff.tanks and cfg.thornsTank then
		return role == "TANK" or not hasTank and Plain(UnitIsUnit(unit, "player"), "boolean") == true
	elseif buff.mana then
		return Plain(UnitPowerType(unit), "number") == MANA
	end
	return true
end

local function Show(f)
	local tile = f.reminder
	if not tile then return end
	tile:Hide()
	local cfg = Settings.current.reminders
	if cfg.place == "NONE" or f.sample or not f.unit or f.status or Auras.AurasSecret() then return end
	local role = Role(f.unit)
	for _, entry in ipairs(Known()) do
		if cfg[entry.buff.key] and Wanted(entry.buff, f.unit, role, cfg) then
			local has = Has(f.unit, entry.names)
			if has == nil then return end
			if not has then
				tile.tile.icon:SetTexture(entry.icon)
				tile:Show()
				return
			end
		end
	end
end
Unit.extra[#Unit.extra + 1] = Show
Unit.HANDLERS.UNIT_AURA = function(f, _, info)
	if not Auras.AurasSecret() and type(info) == "table" and info.isFullUpdate == false and not info.addedAuras and not info.removedAuraInstanceIDs then return end
	Show(f)
end

local function Listen(f, on)
	if on and f.unit and Unit.running and not f.sample then
		f:RegisterUnitEvent("UNIT_AURA", f.unit)
	elseif f.reminder then
		f:UnregisterEvent("UNIT_AURA")
	end
end
Unit.changed[#Unit.changed + 1] = function(f)
	Listen(f, Settings.current.reminders.place ~= "NONE")
end

local function Layout(f)
	local cfg = Settings.current.reminders
	local on = cfg.place ~= "NONE"
	if not on and not f.reminder then return end
	if not f.reminder then
		f.reminder = CreateFrame("Frame", nil, f.text)
		f.reminder.tile = Auras.NewTile(f.reminder)
	end
	local tile = f.reminder.tile
	Listen(f, on)
	if not on then
		f.reminder:Hide()
		return
	end
	Style.Pin(f, f.reminder, cfg.place, Widgets.Snap(f, cfg.size))
	tile.chrome:Restyle()
	tile.chrome:SetRimAccent(Style.Accent())
	Auras.PlaceIcon(tile)
	local zoom = Settings.current.auras.zoom
	tile.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	Show(f)
end
Style.appliers[#Style.appliers + 1] = Layout

local function PaintSample(f, sample)
	local tile = f.reminder
	if not tile then return end
	local cfg, buff = Settings.current.reminders, nil
	for _, each in ipairs(BUFFS) do
		buff = buff or cfg[each.key] and each or nil
	end
	local icon = buff and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(buff.spells[1])
	tile.tile.icon:SetTexture(icon)
	tile:SetShown(cfg.place ~= "NONE" and sample.role == "HEALER" and icon ~= nil)
end
Style.painters[#Style.painters + 1] = PaintSample

local function All()
	if Settings.current.reminders.place == "NONE" then return end
	hasTank = false
	Unit.ForEach(function(f)
		hasTank = hasTank or f.unit ~= nil and Role(f.unit) == "TANK"
	end)
	Unit.ForEach(Show)
end
Reminders.All = All

local events = Frames.events
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ROLES_ASSIGNED" }) do
	events[#events + 1] = { event = event, fn = All }
end
events[#events + 1] = { event = "SPELLS_CHANGED", fn = function()
	known = nil
	All()
end }
local rosterChanged = Unit.RosterChanged
function Unit.RosterChanged(...)
	rosterChanged(...)
	All()
end
