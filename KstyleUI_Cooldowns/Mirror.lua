-- Mirror.lua: runs each group on its path: KstyleUI rows driven by duration objects, or Blizzard's viewer restyled in place when the mirror cannot work.
local _, ns = ...

local K = KstyleUI
local Settings, Data, Path, Row, BarRow, Style, Viewers, Auras, Reskin = ns.Settings, ns.Data, ns.Path, ns.Row, ns.BarRow, ns.Style, ns.Viewers, ns.Auras, ns.Reskin

local Mirror = {}
ns.Mirror = Mirror

local MODULE = ns.MODULE
local GROUPS = Settings.GROUPS
local COOLDOWN_GROUPS = Settings.COOLDOWN_GROUPS
local DATA_EVENT = "CooldownViewerSettings.OnDataChanged"
local RETRY_SECONDS = 1
local MAX_RETRIES = 10
local KEYS = { essential = "cooldowns.essential", utility = "cooldowns.utility", buffs = "cooldowns.buffs", bars = "cooldowns.bars" }
local INTERPOLATION = "Immediate"
local DIRECTION = "RemainingTime"

local rows = {}
local lists, scratch, shown, sources = {}, {}, {}, {}
local running = false
local pending = false
local retries = 0
local auraQueued, auraOwed = false, false
local auraUnits
local trackedSpells, foundAuras = {}, { player = {}, target = {} }

local pcall = pcall

function Mirror.Row(group)
	return rows[group]
end

local function Live(group)
	return running and Path.Get(group) == "mirror" and rows[group] ~= nil
end

local function Fail(group, why)
	if Path.Fail(group, why) then
		local row = rows[group]
		if row then
			row.content:Hide()
		end
		Viewers.Unfade(group)
		if Path.Get(group) == "reskin" then
			Reskin.Start(group)
		end
	end
end

local function Present(value)
	return ns.IsSecret(value) or value ~= nil
end

local function SetDuration(group, cooldown, duration)
	local set = cooldown.SetCooldownFromDurationObject
	if type(set) ~= "function" then
		Fail(group, "Cooldown:SetCooldownFromDurationObject is missing")
		return false
	end
	local ok, err = pcall(set, cooldown, duration)
	if not ok then
		Fail(group, "SetCooldownFromDurationObject failed: " .. tostring(err))
		return false
	end
	return true
end

local function Texture(texture, entry)
	if not entry then
		return
	end
	local fileID
	if entry.categoryID and not entry.spellID then
		fileID = Data.CATEGORY_ICONS[entry.categoryID] or Data.UNKNOWN_ICON
	elseif entry.equipSlot and GetInventoryItemTexture then
		local ok, file = pcall(GetInventoryItemTexture, "player", entry.equipSlot)
		if ok then
			fileID = file
		end
	elseif entry.iconSpell and C_Spell and C_Spell.GetSpellTexture then
		local ok, file = pcall(C_Spell.GetSpellTexture, entry.iconSpell)
		if ok then
			fileID = file
		end
	end
	texture:SetTexture(fileID)
end

local function SpellCooling(spell)
	local api = C_Spell
	if not (Present(spell) and api and api.GetSpellCooldown) then
		return nil
	end
	local ok, info = pcall(api.GetSpellCooldown, spell)
	if not ok or type(info) ~= "table" or ns.IsSecret(info) then
		return nil
	end
	local active, gcd = info.isActive, info.isOnGCD
	if ns.IsSecret(active) or ns.IsSecret(gcd) then
		return nil
	end
	return active == true and gcd ~= true
end

local function Ready(row, icon)
	local ready = icon.entry ~= nil and row.cfg.readyGlow and not icon.onCooldown and icon.usable ~= false
	Style.SetReady(icon, ready)
end

local function SetCooldownState(row, icon, spell)
	local cooling = SpellCooling(spell)
	if cooling == nil then
		cooling = icon.cooling == true
	end
	if icon.onCooldown ~= cooling then
		icon.onCooldown = cooling
		icon:Paint()
	end
	Ready(row, icon)
end

local function CategorySpell(entry)
	local api = C_Spell
	if not (entry.categoryID and api and api.GetLastCategoryCooldownSource) then
		return nil
	end
	local ok, spell = pcall(api.GetLastCategoryCooldownSource, entry.categoryID)
	if ok then
		return spell
	end
	return nil
end

local function CooldownSpell(entry)
	if not entry then
		return nil
	end
	return entry.spell or CategorySpell(entry)
end

local function Cooldown(row, icon)
	local spell = CooldownSpell(icon.entry)
	local cooldown = icon.cooldown
	local getter = C_Spell and C_Spell.GetSpellCooldownDuration
	if not Present(spell) or not getter then
		cooldown:Clear()
		return
	end
	local ok, duration = pcall(getter, spell, not row.cfg.gcd)
	if not ok then
		Fail(row.group, "GetSpellCooldownDuration failed: " .. tostring(duration))
		return
	end
	if not Present(duration) then
		cooldown:Clear()
	elseif not SetDuration(row.group, cooldown, duration) then
		return
	end
	SetCooldownState(row, icon, spell)
end

local function Charges(icon)
	local entry = icon.entry
	local api = C_Spell
	if not (entry and entry.charges and entry.spell and api and api.GetSpellCharges) then
		icon:SetCount(nil)
		icon:ClearChargeCooldown()
		return
	end
	local ok, info = pcall(api.GetSpellCharges, entry.spell)
	local maxCharges = ok and type(info) == "table" and not ns.IsSecret(info) and info.maxCharges
	if type(maxCharges) ~= "number" or ns.IsSecret(maxCharges) or maxCharges <= 1 then
		icon:SetCount(nil)
		icon:ClearChargeCooldown()
		return
	end
	icon:SetCount(info.currentCharges)
	local getter = api.GetSpellChargeDuration
	if not getter then
		return
	end
	local okDuration, duration = pcall(getter, entry.spell)
	if okDuration and Present(duration) then
		pcall(icon.SetChargeCooldownFromDuration, icon, duration)
	else
		icon:ClearChargeCooldown()
	end
end

local function Usable(row, icon)
	local entry = icon.entry
	local usable = true
	local api = C_Spell
	if row.cfg.usable and entry and entry.spell and api and api.IsSpellUsable then
		local ok, isUsable = pcall(api.IsSpellUsable, entry.spell)
		if ok and not ns.IsSecret(isUsable) then
			usable = isUsable == true
		else
			usable = icon.usable ~= false
		end
	end
	if icon.usable ~= usable then
		icon:SetUsable(usable)
	end
	Ready(row, icon)
end

local function Overlayed(spell)
	local api = C_SpellActivationOverlay
	if not (spell and api and api.IsSpellOverlayed) then
		return false
	end
	local ok, on = pcall(api.IsSpellOverlayed, spell)
	return ok and not ns.IsSecret(on) and on == true
end

local function Proc(row, icon)
	local entry = icon.entry
	local on = row.cfg.procGlow and entry ~= nil and (Overlayed(entry.spell) or (entry.spellID ~= entry.spell and Overlayed(entry.spellID)))
	Style.SetProc(icon, on)
end

local function RefreshCooldownIcon(row, icon)
	Texture(icon.icon, icon.entry)
	Usable(row, icon)
	Charges(icon)
	Proc(row, icon)
	Cooldown(row, icon)
end

local function OnCooldownDone(cooldown)
	local icon = cooldown:GetParent()
	local row = icon and icon.cooldownsRow
	if row and icon.entry and COOLDOWN_GROUPS[row.group] and Live(row.group) then
		SetCooldownState(row, icon, CooldownSpell(icon.entry))
	end
end

local function AssignCooldowns(row, list)
	local count = row:SetCount(#list)
	for i = 1, count do
		local icon = row.icons[i]
		if not icon.cooldownsRow then
			icon.cooldownsRow = row
			icon.cooldown:HookScript("OnCooldownDone", OnCooldownDone)
		end
		icon.entry = list[i]
		RefreshCooldownIcon(row, icon)
	end
end

local function ShowAuraIcon(row, icon, entry)
	icon.entry = entry
	Texture(icon.icon, entry)
	local id = entry.auraID
	if id then
		local duration, err = Auras.Duration(entry.auraUnit, id)
		if err then
			Fail(row.group, "GetAuraDuration failed: " .. err)
			return
		end
		if Present(duration) then
			SetDuration(row.group, icon.cooldown, duration)
		else
			icon.cooldown:Clear()
		end
		icon:SetCount(Auras.Stacks(entry.auraUnit, id))
	else
		icon.cooldown:Clear()
		icon:SetCount(nil)
	end
	local active = id ~= nil
	if icon.usable ~= active then
		icon:SetUsable(active)
	end
end

local function SpellName(entry)
	local api = C_Spell
	if not (entry.spell and api and api.GetSpellName) then
		return nil
	end
	local ok, name = pcall(api.GetSpellName, entry.spell)
	if ok then
		return name
	end
	return nil
end

local function ShowBar(row, bar, entry)
	bar.entry = entry
	Texture(bar.icon, entry)
	K.Widgets.SetText(bar.name, SpellName(entry))
	local status, timer = bar.status, bar.timer
	local id = entry.auraID
	local duration, err
	if id then
		duration, err = Auras.Duration(entry.auraUnit, id)
	end
	if err then
		Fail(row.group, "GetAuraDuration failed: " .. err)
		return
	end
	if id and Auras.Permanent(entry.auraUnit, id) then
		status:SetMinMaxValues(0, 1)
		status:SetValue(1)
		timer:Clear()
	elseif Present(duration) and type(status.SetTimerDuration) == "function" then
		local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation[INTERPOLATION]
		local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection[DIRECTION]
		local ok, timerErr = pcall(status.SetTimerDuration, status, duration, interpolation or 0, direction or 1)
		if not ok then
			Fail(row.group, "SetTimerDuration failed: " .. tostring(timerErr))
			return
		end
		SetDuration(row.group, timer, duration)
	else
		status:SetMinMaxValues(0, 1)
		status:SetValue(0)
		timer:Clear()
	end
	local stacks
	if id then
		stacks = Auras.Stacks(entry.auraUnit, id)
	end
	K.Widgets.SetText(bar.count, stacks)
	bar:SetAlpha(id and 1 or ns.INACTIVE_ALPHA)
end

local function AssignAuras(row, list)
	local out = shown[row.group]
	for i = #out, 1, -1 do
		out[i] = nil
	end
	local keepInactive = row.cfg.inactive
	for _, entry in ipairs(list) do
		if entry.auraID or keepInactive then
			out[#out + 1] = entry
		end
	end
	local count = row:SetCount(#out)
	for i = 1, count do
		if not Live(row.group) then
			return
		end
		if row.group == "bars" then
			ShowBar(row, row.bars[i], out[i])
		else
			ShowAuraIcon(row, row.icons[i], out[i])
		end
	end
end

local function FindAuras(list)
	for _, entry in ipairs(list) do
		entry.auraUnit, entry.auraID = Auras.Find(entry)
	end
end

local OnUnitAura

local function ListenAuras(target)
	local units = target and "both" or "player"
	if auraUnits == nil or auraUnits == units then
		return
	end
	auraUnits = units
	K.Events.Unregister(MODULE, "UNIT_AURA")
	if target then
		K.Events.RegisterUnit(MODULE, "UNIT_AURA", OnUnitAura, "player", "target")
	else
		K.Events.RegisterUnit(MODULE, "UNIT_AURA", OnUnitAura, "player")
	end
end

local function Owe()
	auraOwed = true
	ListenAuras(true)
end

local function Empty(set)
	for key in pairs(set) do
		set[key] = nil
	end
end

local function Track(spell)
	if type(spell) == "number" and not ns.IsSecret(spell) then
		trackedSpells[spell] = true
	end
end

local function Index()
	Empty(trackedSpells)
	Empty(foundAuras.player)
	Empty(foundAuras.target)
	local target = auraOwed
	for group in pairs(Settings.AURA_GROUPS) do
		if Live(group) then
			for _, entry in ipairs(lists[group]) do
				Track(entry.spell)
				Track(entry.spellID)
				if entry.linked then
					for _, spell in ipairs(entry.linked) do
						Track(spell)
					end
				end
				local unit, id = entry.auraUnit, entry.auraID
				if foundAuras[unit] and id then
					foundAuras[unit][id] = true
				end
				target = target or unit ~= "player"
			end
		end
	end
	ListenAuras(target)
end

local function RefreshAuras()
	if Auras.Secret() then
		ns.LogOnce("auras-secret", "aura data is secret; the tracked buff mirror keeps its last state until it is readable")
		Owe()
		return
	end
	auraOwed = false
	for group in pairs(Settings.AURA_GROUPS) do
		if Live(group) then
			FindAuras(lists[group])
			AssignAuras(rows[group], lists[group])
		end
	end
	Index()
end

local function RunAuras()
	auraQueued = false
	if running then
		RefreshAuras()
	end
end

local function RequestAuras()
	auraOwed = true
	if auraQueued or not running or auraUnits == nil then
		return
	end
	auraQueued = true
	C_Timer.After(0, RunAuras)
end

local function Unreadable()
	ns.LogOnce("aura-update-unreadable", "a UNIT_AURA update could not be read; the tracked buffs refresh in full")
	return true
end

local function AddsTracked(added)
	if ns.IsSecret(added) then
		return Unreadable()
	end
	if added == nil then
		return false
	end
	if type(added) ~= "table" then
		return Unreadable()
	end
	for _, aura in ipairs(added) do
		if ns.IsSecret(aura) or type(aura) ~= "table" then
			return Unreadable()
		end
		local spell = aura.spellId
		if ns.IsSecret(spell) then
			return Unreadable()
		end
		if spell ~= nil and trackedSpells[spell] then
			return true
		end
	end
	return false
end

local function TouchesFound(found, ids)
	if ns.IsSecret(ids) then
		return Unreadable()
	end
	if ids == nil then
		return false
	end
	if type(ids) ~= "table" then
		return Unreadable()
	end
	for _, id in ipairs(ids) do
		if ns.IsSecret(id) then
			return Unreadable()
		end
		if found[id] then
			return true
		end
	end
	return false
end

local function Touches(unit, info)
	if ns.IsSecret(unit) or ns.IsSecret(info) then
		return Unreadable()
	end
	if info == nil then
		return true
	end
	if type(info) ~= "table" then
		return Unreadable()
	end
	local full = info.isFullUpdate
	if ns.IsSecret(full) then
		return Unreadable()
	end
	if full == true then
		return true
	end
	local found = foundAuras[unit]
	if not found then
		return false
	end
	return AddsTracked(info.addedAuras) or TouchesFound(found, info.removedAuraInstanceIDs) or TouchesFound(found, info.updatedAuraInstanceIDs)
end

function OnUnitAura(_, unit, info)
	if auraQueued then
		return
	end
	if auraOwed or Auras.Secret() or Touches(unit, info) then
		RequestAuras()
	end
end

local function OnTargetChanged()
	if auraOwed or auraUnits ~= "player" then
		RequestAuras()
	end
end

local function Assign(group)
	if COOLDOWN_GROUPS[group] then
		AssignCooldowns(rows[group], lists[group])
	elseif Auras.Secret() then
		Owe()
	else
		FindAuras(lists[group])
		AssignAuras(rows[group], lists[group])
	end
end

local function Rebuild(group)
	if not Live(group) then
		return false
	end
	local list, source = Data.Collect(group, scratch[group])
	if source == "none" or source == "secret" then
		Fail(group, "the cooldown category set could not be read (" .. source .. ")")
		return false
	end
	if source == "dirty" and sources[group] == "layout" then
		return true
	end
	scratch[group], lists[group] = lists[group], list
	if sources[group] ~= source then
		sources[group] = source
		ns.Log(group .. ": " .. #list .. " entries from the " .. source)
	end
	Assign(group)
	return source == "dirty"
end

local function RebuildAll()
	local dirty = false
	for _, group in ipairs(GROUPS) do
		dirty = Rebuild(group) or dirty
	end
	if dirty and retries < MAX_RETRIES then
		retries = retries + 1
		C_Timer.After(RETRY_SECONDS, Mirror.Schedule)
	elseif not dirty then
		retries = 0
	end
	Index()
end

local function RunPending()
	pending = false
	if running then
		RebuildAll()
	end
end

function Mirror.Schedule()
	if pending or not running then
		return
	end
	pending = true
	C_Timer.After(0, RunPending)
end

local function OnDataChanged()
	retries = 0
	Mirror.Schedule()
end

local function ApplySettings()
	Settings.Read()
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		if row then
			row:Apply(Settings.current[group])
			if K.Layout and K.Layout.Restore then
				K.Layout.Restore(KEYS[group])
			end
			if Live(group) then
				Assign(group)
			end
		end
	end
	Index()
	Reskin.Refresh()
end
Mirror.ApplySettings = ApplySettings

local function Build(group)
	local row = rows[group]
	if row then
		return row
	end
	if group == "bars" then
		row = BarRow.New(K.Scale.Root(), Settings.current.bars)
	else
		row = Row.New(K.Scale.Root(), group, Settings.current[group])
	end
	rows[group] = row
	lists[group], scratch[group], shown[group] = {}, {}, {}
	local key = KEYS[group]
	local element = K.Setup.Layouts.Element(key)
	K.Layout.Register(row.holder, key, K.Setup.Layouts.Default(key), {
		label = element and element.label or key,
		module = MODULE,
		scalable = true,
	})
	return row
end

local eventSpell, eventShow, eventEntry

local function EachCooldownIcon(fn)
	for group in pairs(COOLDOWN_GROUPS) do
		if Live(group) then
			local row = rows[group]
			for i = 1, row.count do
				fn(row, row.icons[i])
			end
		end
	end
end

local function CooldownIcon(row, icon)
	Cooldown(row, icon)
	if icon.entry and icon.entry.charges then
		Charges(icon)
	end
end

local function ChargeIcon(_, icon)
	Charges(icon)
end

local function TextureIcon(_, icon)
	Texture(icon.icon, icon.entry)
end

local function ProcIcon(row, icon)
	local entry = icon.entry
	if ns.IsSecret(eventSpell) then
		Proc(row, icon)
	elseif entry and (entry.spell == eventSpell or entry.spellID == eventSpell) then
		Style.SetProc(icon, eventShow and row.cfg.procGlow)
	end
end

local function OverrideIcon(row, icon)
	if icon.entry == eventEntry then
		RefreshCooldownIcon(row, icon)
	end
end

local function RetextureAll()
	EachCooldownIcon(TextureIcon)
	RequestAuras()
end

local EVENTS = {
	SPELL_UPDATE_COOLDOWN = function()
		EachCooldownIcon(CooldownIcon)
	end,
	SPELL_UPDATE_CHARGES = function()
		EachCooldownIcon(ChargeIcon)
	end,
	SPELL_UPDATE_USABLE = function()
		EachCooldownIcon(Usable)
	end,
	SPELL_UPDATE_ICON = RetextureAll,
	SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(_, spell)
		eventSpell, eventShow = spell, true
		EachCooldownIcon(ProcIcon)
		eventSpell = nil
	end,
	SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(_, spell)
		eventSpell, eventShow = spell, false
		EachCooldownIcon(ProcIcon)
		eventSpell = nil
	end,
	COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(_, base, override)
		eventEntry = Data.SetOverride(base, override)
		if eventEntry then
			EachCooldownIcon(OverrideIcon)
			RequestAuras()
		end
		eventEntry = nil
	end,
	SPELLS_CHANGED = Mirror.Schedule,
	PLAYER_ENTERING_WORLD = Mirror.Schedule,
	COOLDOWN_VIEWER_DATA_LOADED = Mirror.Schedule,
	COOLDOWN_VIEWER_TABLE_HOTFIXED = Mirror.Schedule,
}

local function OnSetting(_, module, key)
	if module ~= MODULE or not running then
		return
	end
	if key == "path" then
		Mirror.Stop()
		Mirror.Start()
	else
		ApplySettings()
	end
end

local function OnTheme()
	if running then
		ApplySettings()
	end
end

local function OnProfile()
	if running then
		Mirror.Stop()
		Mirror.Start()
	end
end

local function OnLayout(_, key)
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		if row and KEYS[group] == key then
			row:Restyle()
		end
	end
end

function Mirror.Start()
	Settings.Read()
	running = true
	retries = 0
	auraOwed = false
	local mirrored, aurasMirrored = false, false
	for _, group in ipairs(GROUPS) do
		local path = Path.Choose(group, Settings.current.path)
		if path == "mirror" then
			mirrored = true
			aurasMirrored = aurasMirrored or Settings.AURA_GROUPS[group] == true
			local row = Build(group)
			row:Apply(Settings.current[group])
			row.holder:Show()
			row.content:Show()
			Viewers.Fade(group)
		elseif path == "reskin" then
			Reskin.Start(group)
		end
	end
	if mirrored then
		for event, fn in pairs(EVENTS) do
			K.Events.Register(MODULE, event, fn)
		end
		if EventRegistry and EventRegistry.RegisterCallback then
			EventRegistry:RegisterCallback(DATA_EVENT, OnDataChanged, Mirror)
		end
	end
	if aurasMirrored then
		auraUnits = "both"
		K.Events.RegisterUnit(MODULE, "UNIT_AURA", OnUnitAura, "player", "target")
		K.Events.Register(MODULE, "PLAYER_TARGET_CHANGED", OnTargetChanged)
	end
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, OnProfile)
	K.Callbacks.Register("ThemeChanged", MODULE, OnTheme)
	K.Callbacks.Register("ScaleChanged", MODULE, OnTheme)
	K.Callbacks.Register("LayoutChanged", MODULE, OnLayout)
	RebuildAll()
	return true
end

function Mirror.Stop()
	running = false
	pending = false
	auraUnits = nil
	K.Events.UnregisterAll(MODULE)
	if EventRegistry and EventRegistry.UnregisterCallback then
		EventRegistry:UnregisterCallback(DATA_EVENT, Mirror)
	end
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		if row then
			row:SetCount(0)
			row.holder:Hide()
		end
		Viewers.Unfade(group)
		sources[group] = nil
	end
	Reskin.Stop()
	Path.Reset()
end

function Mirror.Report()
	local parts = {}
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		local count = Path.Get(group) == "mirror" and row and row.count or 0
		parts[#parts + 1] = group .. "=" .. tostring(Path.Get(group) or "off") .. "(" .. count .. ")"
	end
	return table.concat(parts, " ")
end
