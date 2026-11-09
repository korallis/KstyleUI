-- Data.lua: the cooldowns each group shows, read from C_CooldownViewer and, when it is clean, the player's Blizzard layout.
local _, ns = ...

local Data = {}
ns.Data = Data

local GROUP_CATEGORY = { essential = "Essential", utility = "Utility", buffs = "TrackedBuff", bars = "TrackedBar" }
local COMBAT_POTION, HEALTH_POTION, HEALTHSTONE = 4, 30, 1711

Data.CATEGORY_ICONS = {
	[COMBAT_POTION] = "Interface/ICONS/INV_POTION_114",
	[HEALTH_POTION] = "Interface/ICONS/INV_POTION_54",
	[HEALTHSTONE] = "Interface/ICONS/Warlock_ Healthstone",
}
Data.UNKNOWN_ICON = 134400
local HIDE_BY_DEFAULT = 2

local entries = {}
local byBase = {}

local function Category(group)
	local enum = Enum and Enum.CooldownViewerCategory
	local name = GROUP_CATEGORY[group]
	if type(enum) ~= "table" or not name then
		return nil
	end
	return ns.Plain(enum[name])
end

local function HasFlag(flags, mask)
	if type(flags) ~= "number" or ns.IsSecret(flags) then
		return false
	end
	return flags % (mask * 2) >= mask
end

local function HideMask()
	local flags = Enum and Enum.CooldownSetSpellFlags
	local mask = type(flags) == "table" and ns.Plain(flags.HideByDefault)
	if type(mask) == "number" and mask > 0 then
		return mask
	end
	return HIDE_BY_DEFAULT
end

local function Clear(list)
	for i = #list, 1, -1 do
		list[i] = nil
	end
	return list
end

local function Number(value)
	if type(value) == "number" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Entry(id, info)
	local entry = entries[id]
	if not entry then
		entry = { cooldownID = id }
		entries[id] = entry
	end
	local base = Number(info.spellID)
	entry.spellID = base
	entry.overrideSpellID = Number(info.overrideSpellID)
	entry.tooltipSpellID = Number(info.overrideTooltipSpellID)
	entry.spell = entry.overrideSpellID or base
	entry.iconSpell = entry.tooltipSpellID or base
	entry.charges = info.charges == true
	entry.selfAura = info.selfAura == true
	entry.hasAura = info.hasAura == true
	entry.equipSlot = Number(info.equipSlot)
	entry.categoryID = Number(info.spellCategoryID)
	local linked = info.linkedSpellIDs
	entry.linked = (type(linked) == "table" and not ns.IsSecret(linked)) and linked or nil
	if base then
		byBase[base] = entry
	end
	return entry
end

local function Visible(info, category)
	if type(info) ~= "table" or ns.IsSecret(info) then
		return false
	end
	if info.category ~= category or info.isKnown ~= true then
		return false
	end
	if CDM_HIDE_INVISIBLE_ITEMS == true and info.isInvisible == true then
		return false
	end
	return true
end

function Data.Available()
	local api = C_CooldownViewer
	if type(api) ~= "table" then
		return false, "C_CooldownViewer is missing"
	end
	if type(api.GetCooldownViewerCategorySet) ~= "function" or type(api.GetCooldownViewerCooldownInfo) ~= "function" then
		return false, "C_CooldownViewer lacks the category functions"
	end
	if type(Enum) ~= "table" or type(Enum.CooldownViewerCategory) ~= "table" then
		return false, "Enum.CooldownViewerCategory is missing"
	end
	return true
end

function Data.Provider()
	local settings = CooldownViewerSettings
	if type(settings) ~= "table" or type(settings.GetDataProvider) ~= "function" then
		return nil
	end
	local ok, provider = pcall(settings.GetDataProvider, settings)
	if not ok or type(provider) ~= "table" or type(provider.IsDirty) ~= "function" or type(provider.GetDisplayData) ~= "function" then
		return nil
	end
	local okDirty, dirty = pcall(provider.IsDirty, provider)
	if not okDirty or ns.IsSecret(dirty) or dirty then
		return nil, "dirty"
	end
	local okData, data = pcall(provider.GetDisplayData, provider)
	if not okData or type(data) ~= "table" or type(data.orderedCooldownIDs) ~= "table" or type(data.cooldownInfoByID) ~= "table" then
		return nil, "dirty"
	end
	return data
end

local function FromLayout(data, category, out)
	local infoByID = data.cooldownInfoByID
	for _, id in ipairs(data.orderedCooldownIDs) do
		local info = Number(id) and infoByID[id]
		if Visible(info, category) then
			out[#out + 1] = Entry(id, info)
		end
	end
	return out
end

local function FromDefaults(category, out)
	local api = C_CooldownViewer
	local ok, ids = pcall(api.GetCooldownViewerCategorySet, category, false)
	if not ok then
		ns.LogOnce("set-error-" .. category, "GetCooldownViewerCategorySet failed: " .. tostring(ids))
		return out, "none"
	end
	if ns.IsSecret(ids) then
		ns.LogOnce("set-secret-" .. category, "the cooldown category set is secret; nothing is shown")
		return out, "secret"
	end
	if type(ids) ~= "table" then
		return out, "none"
	end
	local mask = HideMask()
	for _, id in ipairs(ids) do
		if Number(id) then
			local okInfo, info = pcall(api.GetCooldownViewerCooldownInfo, id)
			if okInfo and type(info) == "table" and not ns.IsSecret(info) and not HasFlag(info.flags, mask) and info.isKnown ~= false then
				if not (CDM_HIDE_INVISIBLE_ITEMS == true and info.isInvisible == true) then
					out[#out + 1] = Entry(id, info)
				end
			end
		end
	end
	return out
end

function Data.Collect(group, out)
	Clear(out)
	if not Data.Available() then
		return out, "none"
	end
	local category = Category(group)
	if category == nil then
		return out, "none"
	end
	local data, why = Data.Provider()
	if data then
		return FromLayout(data, category, out), "layout"
	end
	local _, failed = FromDefaults(category, out)
	if failed then
		return out, failed
	end
	return out, why or "defaults"
end

function Data.Count(group)
	local list, source = Data.Collect(group, {})
	if source == "none" or source == "secret" then
		return nil
	end
	return #list
end

function Data.SetOverride(baseSpellID, overrideSpellID)
	local base = Number(baseSpellID)
	local entry = base and byBase[base]
	if not entry then
		return nil
	end
	entry.overrideSpellID = Number(overrideSpellID)
	entry.spell = entry.overrideSpellID or base
	return entry
end
