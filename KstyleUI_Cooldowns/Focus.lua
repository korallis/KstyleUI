-- Focus.lua: the focus interrupt: your interrupt's icon, styled as a utility cooldown, on a side of your focus's (or target's) enemy nameplate; a sound when that unit starts a cast while the interrupt is ready, or on any cast without one; and, in dungeons while you have no focus, a reminder under enemy casters' nameplates. Each part listens to its events only while a setting asks for it.
local _, ns = ...

local K = KstyleUI
local Widgets, L = K.Widgets, K.L
local Settings = ns.Settings

local Focus = {}
ns.Focus = Focus

local OWNER = ns.MODULE .. "Focus"
local SIDES = { LEFT = { "RIGHT", "LEFT", -1, 0 }, RIGHT = { "LEFT", "RIGHT", 1, 0 }, TOP = { "BOTTOM", "TOP", 0, 1 }, BOTTOM = { "TOP", "BOTTOM", 0, -1 } }
local MANA = 0
local style = setmetatable({ group = "utility" }, ns.Row)
local icon, spell, dungeon
local plates, notes = {}, {}
Focus.notes = notes

local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then return value end
end

local function Unit()
	return Settings.current.focusTarget and "target" or "focus"
end

local function Enemy(unit)
	return Ask(UnitExists, unit) == true and Ask(UnitIsUnit, unit, "player") ~= true and Ask(UnitCanAttack, "player", unit) ~= false
end

local function Plate(unit)
	local plate = C_NamePlate and Ask(C_NamePlate.GetNamePlateForUnit, unit)
	return type(plate) == "table" and plate or nil
end

local function Ready()
	local info = Ask(C_Spell and C_Spell.GetSpellCooldown, spell)
	return not (type(info) == "table" and not ns.IsSecret(info.isActive) and info.isActive == true)
end

local function Refresh()
	if not (icon and icon:IsShown()) then return end
	local get = C_Spell and C_Spell.GetSpellCooldownDuration
	local ok, duration = false, nil
	if type(get) == "function" then ok, duration = pcall(get, spell, true) end
	if ok and (ns.IsSecret(duration) or duration ~= nil) then
		icon:SetCooldownFromDuration(duration)
	else
		icon:ClearCooldown()
	end
end

local function Place()
	local unit = Unit()
	local plate = spell and Enemy(unit) and Plate(unit)
	if not plate then
		if icon then icon:Hide() end
		return
	end
	if not icon then
		icon = ns.Style.Decorate(Widgets.Slot(K.Scale.Root(), { size = Settings.current.utility.size }), "utility")
		style:StyleIcon(icon)
		icon:EnableMouse(false)
		icon:Hide()
		Focus.icon = icon
	end
	if icon.spell ~= spell then
		icon.spell, icon.entry = spell, { spell = spell }
		icon:SetIcon(Ask(C_Spell and C_Spell.GetSpellTexture, spell))
	end
	local side = Settings.current.focusSide
	if icon.plate ~= plate or icon.side ~= side then
		icon.plate, icon.side = plate, side
		local place, gap = SIDES[side], K.Tokens.Size("actionGap")
		icon:ClearAllPoints()
		Widgets.Point(icon, place[1], plate, place[2], place[3] * gap, place[4] * gap)
	end
	if not icon:IsShown() then
		icon:Show()
		Refresh()
	end
end

local function Note(unit)
	local current, text = Settings.current, notes[unit]
	local plate = current.focusReminder and dungeon and Ask(UnitExists, "focus") ~= true and Enemy(unit) and Ask(UnitPowerType, unit) == MANA and Plate(unit)
	if not plate then
		if text then text:Hide() end
		return
	end
	if not text then
		text = Widgets.Text(K.Scale.Root(), "caps", "hostile")
		Widgets.SetText(text, L["Focus"])
		notes[unit] = text
	end
	if text.plate ~= plate then
		text.plate = plate
		text:ClearAllPoints()
		Widgets.Point(text, "TOP", plate, "BOTTOM", 0, -K.Tokens.Size("actionGap"))
	end
	text:Show()
end

local function Notes()
	for unit in pairs(notes) do
		if not plates[unit] then notes[unit]:Hide() end
	end
	for unit in pairs(plates) do Note(unit) end
end

local function OnAdded(_, unit)
	if ns.IsSecret(unit) then return end
	plates[unit] = true
	Note(unit)
	Place()
end

local function OnRemoved(_, unit)
	if ns.IsSecret(unit) then return end
	plates[unit] = nil
	if notes[unit] then notes[unit]:Hide() end
	Place()
end

local function OnUnit()
	Place()
	Notes()
end

local function OnWorld()
	local _, kind = IsInInstance()
	dungeon = not ns.IsSecret(kind) and kind == "party"
	Notes()
end

local function OnCast(_, unit)
	local kit = SOUNDKIT and SOUNDKIT[Settings.SOUNDS[Settings.current.focusSound]]
	if kit and not ns.IsSecret(unit) and unit == Unit() and Enemy(unit) and (not spell or Ready()) and type(PlaySound) == "function" then
		pcall(PlaySound, kit, "Master")
	end
end

function Focus.Spell(name)
	return name ~= "" and (tonumber(name) or Ask(C_Spell and C_Spell.GetSpellIDForSpellIdentifier, name)) or nil
end

function Focus.Stop()
	K.Events.UnregisterAll(OWNER)
	spell = nil
	if icon then icon:Hide() end
	for _, text in pairs(notes) do text:Hide() end
end

function Focus.Apply()
	Focus.Stop()
	local current = Settings.current
	spell = Focus.Spell(current.focusSpell)
	style.cfg = current.utility
	if icon then
		style:StyleIcon(icon)
		icon:EnableMouse(false)
		icon.plate, icon.spell = nil, nil
	end
	local reminder = current.focusReminder
	if spell or reminder then
		K.Events.Register(OWNER, "NAME_PLATE_UNIT_ADDED", OnAdded)
		K.Events.Register(OWNER, "NAME_PLATE_UNIT_REMOVED", OnRemoved)
		K.Events.Register(OWNER, "PLAYER_FOCUS_CHANGED", OnUnit)
	end
	if spell then
		K.Events.Register(OWNER, "SPELL_UPDATE_COOLDOWN", Refresh)
		if current.focusTarget then K.Events.Register(OWNER, "PLAYER_TARGET_CHANGED", OnUnit) end
	end
	if reminder then
		K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", OnWorld)
		OnWorld()
	end
	if current.focusSound ~= "" then
		K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_START", OnCast, Unit())
		K.Events.RegisterUnit(OWNER, "UNIT_SPELLCAST_CHANNEL_START", OnCast, Unit())
	end
	Place()
end
