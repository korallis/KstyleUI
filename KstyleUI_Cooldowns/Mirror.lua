-- Mirror.lua: the essential and utility cooldowns as KstyleUI icons, each Cooldown widget driven by the API's duration objects.
local _, ns = ...

local K = KstyleUI
local Settings, Data, Path, Row, Style, Viewers = ns.Settings, ns.Data, ns.Path, ns.Row, ns.Style, ns.Viewers

local Mirror = {}
ns.Mirror = Mirror

local MODULE = ns.MODULE
local GROUPS = Settings.ICON_GROUPS
local DATA_EVENT = "CooldownViewerSettings.OnDataChanged"
local RETRY_SECONDS = 1
local MAX_RETRIES = 10
local KEYS = { essential = "cooldowns.essential", utility = "cooldowns.utility" }

local rows = {}
local lists, scratch, sources = {}, {}, {}
local running = false
local pending = false
local retries = 0

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
	end
end

local function SpellCooling(spell)
	local api = C_Spell
	if not (api and api.GetSpellCooldown) then
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

local function Present(value)
	return ns.IsSecret(value) or value ~= nil
end

local function Cooldown(row, icon)
	local entry = icon.entry
	local spell = CooldownSpell(entry)
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
	if not ns.IsSecret(duration) and duration == nil then
		cooldown:Clear()
	else
		local set = cooldown.SetCooldownFromDurationObject
		if type(set) ~= "function" then
			Fail(row.group, "Cooldown:SetCooldownFromDurationObject is missing")
			return
		end
		local okSet, err = pcall(set, cooldown, duration)
		if not okSet then
			Fail(row.group, "SetCooldownFromDurationObject failed: " .. tostring(err))
			return
		end
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
	if okDuration and (ns.IsSecret(duration) or duration ~= nil) then
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

local function Texture(icon)
	local entry = icon.entry
	if not entry then
		return
	end
	local fileID
	if entry.categoryID and not entry.spellID then
		fileID = Data.CATEGORY_ICONS[entry.categoryID] or Data.UNKNOWN_ICON
	elseif entry.equipSlot and GetInventoryItemTexture then
		local ok, texture = pcall(GetInventoryItemTexture, "player", entry.equipSlot)
		fileID = ok and texture or nil
	elseif entry.iconSpell and C_Spell and C_Spell.GetSpellTexture then
		local ok, texture = pcall(C_Spell.GetSpellTexture, entry.iconSpell)
		fileID = ok and texture or nil
	end
	K.Icons.Apply(icon.icon, fileID)
end

local function Refresh(row, icon)
	Texture(icon)
	Usable(row, icon)
	Charges(icon)
	Proc(row, icon)
	Cooldown(row, icon)
end

local function EachIcon(fn)
	for _, group in ipairs(GROUPS) do
		if Live(group) then
			local row = rows[group]
			for i = 1, row.count do
				fn(row, row.icons[i])
			end
		end
	end
end

local function OnCooldownDone(cooldown)
	local icon = cooldown:GetParent()
	local row = icon and icon.cooldownsRow
	if row and icon.entry and Live(row.group) then
		SetCooldownState(row, icon, CooldownSpell(icon.entry))
	end
end

local function Assign(row, list)
	local count = row:SetCount(#list)
	for i = 1, count do
		local icon = row.icons[i]
		if not icon.cooldownsRow then
			icon.cooldownsRow = row
			icon.cooldown:HookScript("OnCooldownDone", OnCooldownDone)
		end
		icon.entry = list[i]
		Refresh(row, icon)
	end
end

local function Rebuild(group)
	local row = rows[group]
	if not row or not Live(group) then
		return
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
		ns.Log(group .. ": " .. #list .. " cooldowns from the " .. source)
	end
	Assign(row, list)
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
				Assign(row, lists[group])
			end
		end
	end
end
Mirror.ApplySettings = ApplySettings

local function Build(group)
	local row = rows[group]
	if row then
		return row
	end
	row = Row.New(K.Scale.Root(), group, Settings.current[group])
	rows[group] = row
	lists[group], scratch[group] = {}, {}
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
	Texture(icon)
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
		Refresh(row, icon)
	end
end

local EVENTS = {
	SPELL_UPDATE_COOLDOWN = function()
		EachIcon(CooldownIcon)
	end,
	SPELL_UPDATE_CHARGES = function()
		EachIcon(ChargeIcon)
	end,
	SPELL_UPDATE_USABLE = function()
		EachIcon(Usable)
	end,
	SPELL_UPDATE_ICON = function()
		EachIcon(TextureIcon)
	end,
	SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(_, spell)
		eventSpell, eventShow = spell, true
		EachIcon(ProcIcon)
		eventSpell = nil
	end,
	SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(_, spell)
		eventSpell, eventShow = spell, false
		EachIcon(ProcIcon)
		eventSpell = nil
	end,
	COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(_, base, override)
		eventEntry = Data.SetOverride(base, override)
		if eventEntry then
			EachIcon(OverrideIcon)
		end
		eventEntry = nil
	end,
	SPELLS_CHANGED = Mirror.Schedule,
	PLAYER_ENTERING_WORLD = Mirror.Schedule,
	COOLDOWN_VIEWER_DATA_LOADED = Mirror.Schedule,
	COOLDOWN_VIEWER_TABLE_HOTFIXED = Mirror.Schedule,
}

local function OnSetting(_, module)
	if module == MODULE and running then
		ApplySettings()
	end
end

local function OnTheme()
	if running then
		ApplySettings()
	end
end

local function OnLayout(_, key)
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		if row and KEYS[group] == key then
			for _, icon in ipairs(row.icons) do
				icon:Restyle()
			end
			row:Place()
		end
	end
end

local function OnIcons()
	EachIcon(TextureIcon)
end

function Mirror.Start()
	Settings.Read()
	running = true
	retries = 0
	local any = false
	for _, group in ipairs(GROUPS) do
		if Path.Choose(group) == "mirror" then
			any = true
			local row = Build(group)
			row:Apply(Settings.current[group])
			row.holder:Show()
			row.content:Show()
			Viewers.Fade(group)
		end
	end
	if not any then
		return false
	end
	for event, fn in pairs(EVENTS) do
		K.Events.Register(MODULE, event, fn)
	end
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, OnTheme)
	K.Callbacks.Register("ThemeChanged", MODULE, OnTheme)
	K.Callbacks.Register("ScaleChanged", MODULE, OnTheme)
	K.Callbacks.Register("IconsChanged", MODULE, OnIcons)
	K.Callbacks.Register("LayoutChanged", MODULE, OnLayout)
	if EventRegistry and EventRegistry.RegisterCallback then
		EventRegistry:RegisterCallback(DATA_EVENT, OnDataChanged, Mirror)
	end
	RebuildAll()
	return true
end

function Mirror.Stop()
	running = false
	pending = false
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
	Path.Reset()
end

function Mirror.Report()
	local parts = {}
	for _, group in ipairs(GROUPS) do
		local row = rows[group]
		parts[#parts + 1] = group .. "=" .. tostring(Path.Get(group) or "off") .. "(" .. (row and row.count or 0) .. ")"
	end
	return table.concat(parts, " ")
end
