-- Mirror.lua: runs each group on its path: KstyleUI rows driven by duration objects and the spell rules, or Blizzard's viewer restyled in place when the mirror cannot work, with Setup asked to place Blizzard's essential and utility viewers on KstyleUI's rows.
local _, ns = ...

local K = KstyleUI
local Settings, Data, Path, Row, BarRow, Style, Viewers, Auras, Reskin, Rules, Grid = ns.Settings, ns.Data, ns.Path, ns.Row, ns.BarRow, ns.Style, ns.Viewers, ns.Auras, ns.Reskin, ns.Rules, ns.Grid

local Mirror = {}
ns.Mirror = Mirror

local MODULE = ns.MODULE
local GROUPS = Settings.GROUPS
local COOLDOWN_GROUPS = Settings.COOLDOWN_GROUPS
local DATA_EVENT = "CooldownViewerSettings.OnDataChanged"
local ASSIST_EVENTS = { "AssistedCombatManager.OnAssistedHighlightSpellChange", "AssistedCombatManager.OnSetUseAssistedHighlight" }
local RETRY_SECONDS = 1
local MAX_RETRIES = 10
local KEYS = { essential = "cooldowns.essential", utility = "cooldowns.utility", buffs = "cooldowns.buffs", bars = "cooldowns.bars" }
local OTHER = { essential = "utility", utility = "essential" }
local EMPTY = Rules.EMPTY

local rows = {}
local lists, scratch, shown, sources = {}, {}, {}, {}
local running = false
local pending = false
local retries = 0
local auraQueued, auraOwed = false, false
local auraUnits
local trackedSpells, foundAuras = {}, { player = {}, target = {} }
local merged = { essential = {}, utility = {} }
local fighting = false

local pcall = pcall

function Mirror.Row(group)
	return rows[group]
end

local function Live(group)
	return running and Path.Get(group) == "mirror" and rows[group] ~= nil
end

local function Native(group)
	Reskin.Start(group)
	local editMode = K.Setup and K.Setup.EditMode
	if COOLDOWN_GROUPS[group] and editMode and editMode.PlaceRows then
		editMode.PlaceRows()
	end
end

local function Fail(group, why)
	if Path.Fail(group, why) then
		local row = rows[group]
		if row then
			row.content:Hide()
		end
		Viewers.Unfade(group)
		if Path.Get(group) == "reskin" then
			Native(group)
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
	if entry.categoryID then
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

local function SpellCooling(spell, cooldownEvent)
	local api = C_Spell
	if not (Present(spell) and api and api.GetSpellCooldown) then
		return nil
	end
	local ok, info = pcall(api.GetSpellCooldown, spell)
	if not ok or type(info) ~= "table" or ns.IsSecret(info) then
		return nil
	end
	local active = info.isActive
	if ns.IsSecret(active) then
		return nil
	end
	if active ~= true then
		return false
	end
	if cooldownEvent then
		local gcd = info.isOnGCD
		if ns.IsSecret(gcd) then
			return nil
		end
		return gcd ~= true
	end
	return true
end

local function Glows()
	return fighting or not Settings.current.glowsInCombat
end

local function Ready(row, icon)
	local ready = icon.entry ~= nil and row.cfg.readyGlow and not icon.onCooldown and icon.usable ~= false and Glows()
	Style.SetReady(icon, ready)
end

local function Cooling(row, icon, cooling, trusted)
	if cooling then
		if icon.coolingEntry ~= icon.entry or not icon.onCooldown then
			icon.coolingEntry, icon.coolingTrusted = icon.entry, false
		end
		icon.coolingTrusted = icon.coolingTrusted or trusted == true
	end
	if icon.onCooldown ~= cooling then
		if not cooling and icon.onCooldown and icon.coolingTrusted and icon.coolingEntry == icon.entry and icon.FlashReady then
			icon:FlashReady()
		end
		if not cooling then
			icon.coolingEntry, icon.coolingTrusted = nil, false
		end
		icon.onCooldown = cooling
		icon:Paint()
		row:Visible(icon)
	end
	Ready(row, icon)
end

local function SetCooldownState(row, icon, spell, cooldownEvent)
	local cooling = SpellCooling(spell, cooldownEvent)
	if cooling == nil then
		cooling = icon.cooling == true
	end
	Cooling(row, icon, cooling, cooldownEvent)
end

local function CategorySpell(entry)
	local api = C_Spell
	if not (entry.categoryID and api and api.GetLastCategoryCooldownSource) then
		return nil, nil, false
	end
	local ok, spell, item = pcall(api.GetLastCategoryCooldownSource, entry.categoryID)
	return spell, item, ok
end

local function CooldownSpell(entry)
	if not entry then
		return nil, nil, true
	end
	if entry.categoryID then
		return CategorySpell(entry)
	end
	return entry.spell, nil, true
end

local function Finite(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function ItemTimer(row, icon, start, duration, rate, enabled, active, gcd, cooldownEvent)
	if not (Finite(start) and Finite(duration) and Finite(rate)) or start < 0 or duration < 0 or rate <= 0 then
		Fail(row.group, "item cooldown timing is secret or invalid")
		return
	end
	if ns.IsSecret(enabled) or type(enabled) ~= "boolean" or ns.IsSecret(active) or type(active) ~= "boolean" then
		Fail(row.group, "item cooldown flags cannot be read")
		return
	end
	local onGCD = false
	if cooldownEvent then
		if ns.IsSecret(gcd) or (gcd ~= nil and type(gcd) ~= "boolean") then
			Fail(row.group, "item cooldown GCD flag cannot be read")
			return
		end
		onGCD = gcd == true
	end
	if not enabled and duration > 0 then
		Fail(row.group, "an item cooldown on hold needs the native viewer")
		return
	end
	local ok, now = false, nil
	if type(GetTime) == "function" then
		ok, now = pcall(GetTime)
	end
	local finish = start + duration
	if not ok or not Finite(now) or not Finite(finish) then
		Fail(row.group, "item cooldown expiration cannot be read")
		return
	end
	active = enabled and active and start > 0 and duration > 0 and finish > now
	if active and (row.cfg.gcd and not (icon.rule or EMPTY).noGcd or not onGCD) then
		local set = icon.cooldown.SetCooldown
		if type(set) ~= "function" then
			Fail(row.group, "Cooldown:SetCooldown is missing")
			return
		end
		local applied = pcall(set, icon.cooldown, start, duration, rate)
		if not applied then
			Fail(row.group, "SetCooldown failed for an item")
			return
		end
	else
		icon.cooldown:Clear()
	end
	Cooling(row, icon, active and not onGCD, cooldownEvent)
end

local function EquippedCooldown(row, icon, cooldownEvent)
	if type(GetInventoryItemCooldown) ~= "function" then
		Fail(row.group, "GetInventoryItemCooldown is missing")
		return
	end
	local ok, start, duration, enable, gcd = pcall(GetInventoryItemCooldown, "player", icon.entry.equipSlot)
	if not ok or not Finite(enable) or (enable ~= 0 and enable ~= 1) then
		Fail(row.group, "equipped item cooldown cannot be read")
		return
	end
	ItemTimer(row, icon, start, duration, 1, enable == 1, true, gcd, cooldownEvent)
end

local function Cooldown(row, icon, cooldownEvent)
	local entry = icon.entry
	if entry and entry.equipSlot then
		EquippedCooldown(row, icon, cooldownEvent)
		return
	end
	local spell, item, resolved = CooldownSpell(entry)
	if not resolved then
		Fail(row.group, "the category cooldown source cannot be read")
		return
	end
	if Present(item) then
		local get = C_Spell and C_Spell.GetItemCooldown
		if type(get) ~= "function" then
			Fail(row.group, "C_Spell.GetItemCooldown is missing")
			return
		end
		local ok, info = pcall(get, item)
		if not ok or ns.IsSecret(info) or (info ~= nil and type(info) ~= "table") then
			Fail(row.group, "the category item cooldown cannot be read")
			return
		end
		if info then
			ItemTimer(row, icon, info.startTime, info.duration, info.modRate, info.isEnabled, info.isActive, info.isOnGCD, cooldownEvent)
			return
		end
	end
	local cooldown = icon.cooldown
	local getter = C_Spell and C_Spell.GetSpellCooldownDuration
	if not Present(spell) then
		cooldown:Clear()
		Cooling(row, icon, false)
		return
	end
	if type(getter) ~= "function" then
		Fail(row.group, "GetSpellCooldownDuration is missing")
		return
	end
	local ok, duration = pcall(getter, spell, not row.cfg.gcd or (icon.rule or EMPTY).noGcd ~= nil)
	if not ok then
		Fail(row.group, "GetSpellCooldownDuration failed: " .. tostring(duration))
		return
	end
	if not Present(duration) then
		cooldown:Clear()
		Cooling(row, icon, false)
		return
	elseif not SetDuration(row.group, cooldown, duration) then
		return
	end
	SetCooldownState(row, icon, spell, cooldownEvent)
end

local function Recharge(icon, on)
	if icon.recharging ~= on then
		icon.recharging = on
		icon.cooldownsRow:Visible(icon)
	end
end

local function ChargeText(icon, count)
	local format = icon.cooldownsRow.cfg.hideZero and C_StringUtil and C_StringUtil.TruncateWhenZero
	if type(format) == "function" then
		local ok, text = pcall(format, count)
		if ok and (ns.IsSecret(text) or type(text) == "string") then
			return text
		end
	end
	return count
end

local function Charges(icon)
	local entry = icon.entry
	local api = C_Spell
	local spell = entry and entry.spell
	if entry and entry.charges and Present(spell) and api and api.GetSpellCharges then
		local ok, info = pcall(api.GetSpellCharges, spell)
		if ok and not ns.IsSecret(info) and type(info) == "table" then
			local maxCharges = info.maxCharges
			if Finite(maxCharges) and maxCharges > 1 then
				icon:SetCount(ChargeText(icon, info.currentCharges))
				if not ns.IsSecret(info.isActive) then Recharge(icon, info.isActive == true) end
				local getter = api.GetSpellChargeDuration
				if getter then
					local okDuration, duration = pcall(getter, spell)
					if okDuration and Present(duration) then
						pcall(icon.SetChargeCooldownFromDuration, icon, duration)
					else
						icon:ClearChargeCooldown()
					end
				end
				return
			end
		end
	end
	icon:ClearChargeCooldown()
	Recharge(icon, false)
	local countSpell, _, resolved = CooldownSpell(entry)
	if not resolved then
		icon:SetCount(nil)
		return
	end
	if Present(countSpell) and api and type(api.GetSpellCastCount) == "function" then
		local ok, count = pcall(api.GetSpellCastCount, countSpell)
		if ok and ns.IsSecret(count) then
			local format = C_StringUtil and C_StringUtil.TruncateWhenZero
			if type(format) == "function" then
				local formatted, text = pcall(format, count)
				if formatted and (ns.IsSecret(text) or type(text) == "string") then
					icon:SetCount(text)
					return
				end
			end
			Fail(icon.cooldownsRow.group, "secret cast count cannot be formatted")
			return
		elseif ok and Finite(count) and count > 0 then
			icon:SetCount(count)
			return
		end
	end
	icon:SetCount(nil)
end

local function Usable(row, icon)
	local entry, rule = icon.entry, icon.rule or EMPTY
	local usable, castable = true, true
	local api = C_Spell
	if (row.cfg.usable or rule.hideUnusable or rule.form) and entry and entry.spell and api and api.IsSpellUsable then
		local ok, isUsable, noMana = pcall(api.IsSpellUsable, entry.spell)
		if ok and not ns.IsSecret(isUsable) then
			local short = not ns.IsSecret(noMana) and noMana == true
			usable, castable = isUsable == true or short and rule.noCost ~= nil, isUsable == true or short
		else
			usable, castable = icon.usable ~= false, icon.castable ~= false
		end
	end
	usable = usable or not row.cfg.usable
	if icon.usable ~= usable then
		icon:SetUsable(usable)
	end
	if icon.castable ~= castable then
		icon.castable = castable
		row:Visible(icon)
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
	local on = row.cfg.procGlow and Glows() and entry ~= nil and (Overlayed(entry.spell) or (entry.spellID ~= entry.spell and Overlayed(entry.spellID)))
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
		if icon.entry.equipSlot or icon.entry.categoryID then
			Cooldown(row, icon)
		else
			SetCooldownState(row, icon, CooldownSpell(icon.entry))
		end
		row:Settle()
	end
end

local function Tint(icon, out, again)
	if out == (icon.outOfRange == true) and not again then return end
	if out then
		local current = Settings.current
		icon:SetTint(current.rangeR, current.rangeG, current.rangeB)
	elseif icon.outOfRange then
		icon:SetTint(1)
	end
	icon.outOfRange = out
end

local function Range(icon)
	local spell, api = icon.entry and icon.entry.spell, C_Spell
	local out = false
	if (icon.rule or EMPTY).range and spell and api and type(api.IsSpellInRange) == "function" then
		local ok, inRange = pcall(api.IsSpellInRange, spell)
		out = ok and not ns.IsSecret(inRange) and inRange == false
	end
	Tint(icon, out, true)
end

local function Rule(row, icon, entry)
	local rule = Rules.For(entry)
	if icon.rule ~= rule then
		icon.rule = rule
		row:Look(icon)
	end
end

local function NextSpell()
	local manager = AssistedCombatManager
	local spell = type(manager) == "table" and manager.lastNextCastSpellID or nil
	return not ns.IsSecret(spell) and type(spell) == "number" and spell or nil
end

local function Assist(_, icon)
	local entry, spell = icon.entry, Settings.current.assist and NextSpell()
	Style.SetAssist(icon, spell and entry ~= nil and (entry.spell == spell or entry.spellID == spell))
end

local function Match(row, icon)
	Rule(row, icon, icon.entry)
	RefreshCooldownIcon(row, icon)
	Range(icon)
	Assist(row, icon)
	row:Visible(icon)
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
		Match(row, icon)
	end
	row:Settle()
end

local function Merged(group)
	local list, other = lists[group], OTHER[group]
	local extra, cfg = lists[other], Settings.current[other]
	local cap = Grid.Capacity(cfg)
	if not (cfg.overflow and extra and #extra > cap and Live(other)) then return list end
	local out = merged[group]
	for i = #out, 1, -1 do
		out[i] = nil
	end
	for i = 1, #list do
		out[i] = list[i]
	end
	for i = cap + 1, #extra do
		out[#out + 1] = extra[i]
	end
	return out
end

local function ShowAuraIcon(row, icon, entry)
	icon.entry = entry
	Rule(row, icon, entry)
	local blank = row.blank[entry] or false
	if (icon.blank or false) ~= blank then
		icon.blank = blank
		icon:SetAlpha(blank and 0 or 1)
		Style.Mouse(icon, Settings.current.tooltips and not blank)
	end
	Style.SetReady(icon, entry.auraID and icon.rule.activeGlow)
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
	local rule, cfg = Rules.For(entry), row.cfg
	K.Widgets.SetText(bar.name, type(rule.names) == "string" and rule.names or SpellName(entry))
	bar.count:SetAlpha((cfg.showCount or rule.count) and not rule.noCount and 1 or 0)
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
		local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation[cfg.smooth and "ExponentialEaseOut" or "Immediate"]
		local direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection[cfg.fillUp and "ElapsedTime" or "RemainingTime"]
		local ok, timerErr = pcall(status.SetTimerDuration, status, duration, interpolation or 0, direction or (cfg.fillUp and 0 or 1))
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

local function Empty(set)
	for key in pairs(set) do
		set[key] = nil
	end
end

local function Shows(cfg, entry)
	local rule, active = Rules.For(entry), entry.auraID ~= nil
	if rule.hide then return false, not rule.shift end
	if rule.missing then return not active, false end
	return active or cfg.inactive, true
end

local function AssignAuras(row, list)
	local out, blank, cfg = shown[row.group], row.blank, row.cfg
	for i = #out, 1, -1 do
		out[i] = nil
	end
	Empty(blank)
	for pass = 1, cfg.keepPlace and 1 or 2 do
		for _, entry in ipairs(list) do
			local show, slot = Shows(cfg, entry)
			if cfg.keepPlace and (show or slot) then
				out[#out + 1], blank[entry] = entry, not show or nil
			elseif show and (entry.auraID ~= nil) == (pass == 1) then
				out[#out + 1] = entry
			end
		end
	end
	while blank[out[#out]] do
		blank[out[#out]], out[#out] = nil, nil
	end
	row.entries = out
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
		AssignCooldowns(rows[group], Merged(group))
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

local function Refill()
	if Settings.current.utility.overflow and Live("essential") and Live("utility") then
		Assign("essential")
	end
end

local function RebuildAll()
	local dirty = false
	for _, group in ipairs(GROUPS) do
		dirty = Rebuild(group) or dirty
	end
	Refill()
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
	row.blank = {}
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
			row:Settle()
		end
	end
end

local function CooldownIcon(row, icon)
	Cooldown(row, icon, true)
	Charges(icon)
end

local function ChargeIcon(_, icon)
	Charges(icon)
end

local function TextureIcon(_, icon)
	Texture(icon.icon, icon.entry)
end

local function ItemIcon(row, icon)
	local entry = icon.entry
	if entry and (entry.equipSlot or entry.categoryID) then
		RefreshCooldownIcon(row, icon)
	end
end

local function UsesIcon(row, icon)
	local entry = icon.entry
	if entry and (entry.equipSlot or entry.categoryID) then
		RefreshCooldownIcon(row, icon)
	else
		Charges(icon)
	end
end

local function ProcIcon(row, icon)
	local entry = icon.entry
	if ns.IsSecret(eventSpell) then
		Proc(row, icon)
	elseif entry and (entry.spell == eventSpell or entry.spellID == eventSpell) then
		Style.SetProc(icon, eventShow and row.cfg.procGlow and Glows())
	end
end

local function OverrideIcon(row, icon)
	if icon.entry == eventEntry then
		Match(row, icon)
	end
end

local eventOut

local function RangeIcon(_, icon)
	local entry = icon.entry
	if (icon.rule or EMPTY).range and entry and (entry.spell == eventSpell or entry.spellID == eventSpell) then
		Tint(icon, eventOut)
	end
end

local function GlowIcon(row, icon)
	Ready(row, icon)
	Proc(row, icon)
end

local function OnAssist()
	if Settings.current.assist then EachCooldownIcon(Assist) end
end

local function OnCombat(event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	if Settings.current.glowsInCombat then
		EachCooldownIcon(GlowIcon)
	end
end

local function RetextureAll()
	EachCooldownIcon(TextureIcon)
	RequestAuras()
end

local EVENTS = {
	BAG_UPDATE_COOLDOWN = function()
		EachCooldownIcon(ItemIcon)
	end,
	PLAYER_EQUIPMENT_CHANGED = function()
		EachCooldownIcon(ItemIcon)
	end,
	SPELL_UPDATE_USES = function()
		EachCooldownIcon(UsesIcon)
	end,
	SPELL_UPDATE_COOLDOWN = function()
		EachCooldownIcon(CooldownIcon)
	end,
	SPELL_UPDATE_CHARGES = function()
		EachCooldownIcon(ChargeIcon)
	end,
	SPELL_UPDATE_USABLE = function()
		EachCooldownIcon(Usable)
	end,
	UPDATE_SHAPESHIFT_FORM = function()
		if Settings.current.rules.form ~= "" then EachCooldownIcon(Usable) end
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
	SPELL_RANGE_CHECK_UPDATE = function(_, spell, inRange, checksRange)
		if Settings.current.rules.range == "" or ns.IsSecret(spell) then
			return
		end
		eventSpell = spell
		eventOut = not ns.IsSecret(inRange) and not ns.IsSecret(checksRange) and checksRange == true and inRange == false
		EachCooldownIcon(RangeIcon)
		eventSpell = nil
	end,
	PLAYER_REGEN_DISABLED = OnCombat,
	PLAYER_REGEN_ENABLED = OnCombat,
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

local function OnScale()
	if running then
		for _, group in ipairs(GROUPS) do
			local row = rows[group]
			if row then row:Apply() end
		end
		Reskin.Refresh()
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
			if row.cfg.vertical then row:Resize() end
			row:Restyle()
		end
	end
end

function Mirror.Start()
	Settings.Read()
	running = true
	retries = 0
	fighting = InCombatLockdown and InCombatLockdown() == true or false
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
			Native(group)
		end
	end
	if mirrored then
		for event, fn in pairs(EVENTS) do
			K.Events.Register(MODULE, event, fn)
		end
		if EventRegistry and EventRegistry.RegisterCallback then
			EventRegistry:RegisterCallback(DATA_EVENT, OnDataChanged, Mirror)
			for _, event in ipairs(ASSIST_EVENTS) do EventRegistry:RegisterCallback(event, OnAssist, Mirror) end
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
	K.Callbacks.Register("HudStyleChanged", MODULE, OnTheme)
	K.Callbacks.Register("ScaleChanged", MODULE, OnScale)
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
		for _, event in ipairs(ASSIST_EVENTS) do EventRegistry:UnregisterCallback(event, Mirror) end
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
