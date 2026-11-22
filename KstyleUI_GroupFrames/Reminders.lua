-- Reminders.lua: the missing buff on each group frame: the first buff you know that a member lacks, read by spell name only while the game says neither aura data nor that buff's aura is secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings, Style, Unit, Frames, Auras = ns.Settings, ns.Style, ns.Unit, ns.Frames, ns.Auras
local Plain, issecretvalue = Unit.Plain, Unit.IsSecret

local BUFFS = {
	{ key = "fortitude", spells = { 1243, 21562 } },
	{ key = "wild", spells = { 1126, 21849 } },
	{ key = "intellect", spells = { 1459, 23028 }, mana = true },
	{ key = "spirit", spells = { 14752, 27681 }, mana = true },
	{ key = "thorns", spells = { 467 }, tanks = true },
	{ key = "salvation", spells = { 1038, 25895 }, notTanks = true },
	{ key = "MIGHT", spells = { 19740, 25782 }, blessing = true },
	{ key = "WISDOM", spells = { 19742, 25894 }, blessing = true },
	{ key = "KINGS", spells = { 20217, 25898 }, blessing = true },
}
local ROLE_BLESSING = { TANK = "tankBlessing", HEALER = "healerBlessing" }
local FILTER = "HELPFUL"
local MANA = 0

local known
local hasTank

local function Known()
	if known then return known end
	known = {}
	local book, spell = C_SpellBook, C_Spell
	if not (book and type(book.IsSpellKnown) == "function" and spell and type(spell.GetSpellName) == "function") then
		Style.LogOnce("reminders", "C_SpellBook.IsSpellKnown or C_Spell.GetSpellName is missing; no missing buff shows")
		return known
	end
	for _, buff in ipairs(BUFFS) do
		local id
		for _, each in ipairs(buff.spells) do
			local ok, has = pcall(book.IsSpellKnown, each)
			if ok and Plain(has, "boolean") then
				id = each
				break
			end
		end
		if id then
			local names = {}
			for _, each in ipairs(buff.spells) do
				names[#names + 1] = Plain(spell.GetSpellName(each), "string")
			end
			known[#known + 1] = { buff = buff, names = #names == #buff.spells and names or nil, icon = spell.GetSpellTexture and spell.GetSpellTexture(id) }
		end
	end
	return known
end

local function Has(unit, entry)
	local api, secrets = C_UnitAuras, C_Secrets
	if not (entry.names and api and type(api.GetAuraDataBySpellName) == "function" and secrets and type(secrets.ShouldSpellAuraBeSecret) == "function") then return nil end
	for _, id in ipairs(entry.buff.spells) do
		local ok, secret = pcall(secrets.ShouldSpellAuraBeSecret, id)
		if not ok or Plain(secret, "boolean") ~= false then return nil end
	end
	for _, name in ipairs(entry.names) do
		local ok, aura = pcall(api.GetAuraDataBySpellName, unit, name, FILTER)
		if not ok or issecretvalue(aura) then return nil end
		if type(aura) == "table" then return true end
	end
	return false
end

local function Role(unit)
	return Plain(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit), "string")
end

local function HasTank()
	if hasTank == nil then
		hasTank = false
		Unit.ForEach(function(f)
			hasTank = hasTank or f.unit ~= nil and Role(f.unit) == "TANK"
		end)
	end
	return hasTank
end

local function Blessing(class, role, cfg)
	local pick = cfg["bless" .. tostring(class)]
	return pick and pick ~= "ROLE" and pick or cfg[ROLE_BLESSING[role] or "damageBlessing"]
end

local function Wanted(buff, unit, role, cfg)
	if buff.blessing then
		return Blessing(Plain(UnitClass and select(2, UnitClass(unit)), "string"), role, cfg) == buff.key
	elseif buff.notTanks and role == "TANK" then
		return false
	elseif buff.tanks and cfg.thornsTank then
		return role == "TANK" or not HasTank() and UnitIsUnit and Plain(UnitIsUnit(unit, "player"), "boolean") == true
	elseif buff.mana then
		return UnitPowerType and Plain(UnitPowerType(unit), "number") == MANA
	end
	return true
end

local function Missing(f)
	local cfg = Settings.current.reminders
	if cfg.place == "NONE" or f.sample or not f.unit or f.status or Auras.AurasSecret() then return nil end
	local role = Role(f.unit)
	for _, entry in ipairs(Known()) do
		if (entry.buff.blessing or cfg[entry.buff.key]) and Wanted(entry.buff, f.unit, role, cfg) then
			local has = Has(f.unit, entry)
			if has == nil then return nil end
			if not has then return entry end
		end
	end
end

local function Show(f)
	local tile = f.reminder
	local entry = tile and Missing(f)
	if tile and tile.entry ~= entry then
		tile.entry = entry
		if entry then tile.tile.icon:SetTexture(entry.icon) end
		tile:SetShown(entry ~= nil)
	end
end
Unit.extra[#Unit.extra + 1] = Show
Unit.OnStatus = Show
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

local function Layout(f, parts)
	local cfg = Settings.current.reminders
	local on = cfg.place ~= "NONE"
	if not on and not f.reminder then return end
	if not f.reminder then
		f.reminder = CreateFrame("Frame", nil, f.text)
		f.reminder:Hide()
		f.reminder.tile = Auras.NewTile(f.reminder)
	end
	Listen(f, on)
	if on then
		local tile, d, bar = f.reminder.tile, Settings.current.dispel, parts.health.height
		local size, shift = Widgets.Snap(f, math.min(cfg.size, bar)), 0
		if d.icon == cfg.place then
			local gap, other = Widgets.Snap(f, Tokens.Size("gapTiny")), Widgets.Snap(f, math.min(d.iconSize, bar))
			shift = cfg.place:find("RIGHT") and -(other + gap) or cfg.place:find("LEFT") and other + gap or Widgets.Snap(f, (other + size) / 2) + gap
		end
		Style.Pin(f, f.reminder, cfg.place, size, shift + cfg.x, cfg.y)
		if cfg.glow and not f.reminder.glow then f.reminder.glow = Widgets.Glow(f.reminder, { kind = "selection", spread = Tokens.Size("gapSmall") }) end
		if f.reminder.glow then f.reminder.glow:SetIntensity(cfg.glow and 1 or 0) end
		tile.chrome:Restyle()
		tile.chrome:SetRimAccent(Style.Accent())
		Auras.PlaceIcon(tile)
		local zoom = Settings.current.auras.zoom
		tile.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	end
	Show(f)
end
Style.appliers[#Style.appliers + 1] = Layout

local function PaintSample(f, sample)
	local tile = f.reminder
	if not tile then return end
	local cfg, buff = Settings.current.reminders, nil
	for _, each in ipairs(BUFFS) do
		if each.blessing and Blessing(sample.class, sample.role, cfg) == each.key or not each.blessing and cfg[each.key] then
			buff = each
			break
		end
	end
	local icon = buff and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(buff.spells[1])
	tile.tile.icon:SetTexture(icon)
	tile:SetShown(cfg.place ~= "NONE" and sample.role == "HEALER" and icon ~= nil)
end
Style.painters[#Style.painters + 1] = PaintSample

local function All()
	hasTank = nil
	if Settings.current.reminders.place == "NONE" then return end
	Unit.ForEach(Show)
end

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
