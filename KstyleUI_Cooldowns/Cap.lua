-- Cap.lua: Blizzard's restyled tracked buff icon row stopped at the module's grid: items in slots past it fade to alpha 0 and stop taking the mouse, and a "+N" chip in the next slot counts the shown ones, from IsShown only when it is not secret ("+" alone when it is).
local _, ns = ...

local K = KstyleUI
local Grid, Settings, Style, Viewers = ns.Grid, ns.Settings, ns.Style, ns.Viewers

local Cap = {}
ns.Cap = Cap

local GROUP = "buffs"

local active, queued, chip = false, false, nil

local function Side(item)
	local side = K.Safe.Side(item)
	local state = side.cap
	if not state then
		state = {}
		side.cap = state
	end
	return state
end

local function Index(item)
	local index = item.layoutIndex
	if type(index) == "number" and not ns.IsSecret(index) then
		return index
	end
	return nil
end

local function Items(viewer)
	local list = {}
	for _, child in ipairs({ viewer:GetChildren() }) do
		if type(child) == "table" and type(child.GetCooldownID) == "function" and Index(child) then
			list[#list + 1] = child
		end
	end
	table.sort(list, function(a, b)
		return Index(a) < Index(b)
	end)
	return list
end

local function Mouse(viewer)
	return viewer.tooltipsShown ~= false and not Viewers.IsFaded(GROUP)
end

local function Release(item, viewer)
	local state = Side(item)
	if state.capped then
		state.capped = false
		item:SetAlpha(1)
		item:SetMouseMotionEnabled(Mouse(viewer))
	end
end

local function Fold(item)
	local state = Side(item)
	state.capped = true
	item:SetAlpha(0)
	item:SetMouseMotionEnabled(false)
end

local function Shown(item)
	local ok, shown = pcall(item.IsShown, item)
	if not ok or ns.IsSecret(shown) then
		return nil
	end
	return shown == true
end

local function SpellName(item)
	if type(item.GetSpellID) ~= "function" then
		return nil
	end
	local ok, spell = pcall(item.GetSpellID, item)
	if not ok or ns.IsSecret(spell) or type(spell) ~= "number" then
		return nil
	end
	return Style.EntryName({ spell = spell })
end

local function Tips(viewer)
	return Settings.current.tooltips == true and viewer ~= nil and viewer.tooltipsShown ~= false
end

local function ShowTooltip(self)
	local tip = GameTooltip
	if not (Tips(Viewers.Frame(GROUP)) and tip) then
		return
	end
	tip:SetOwner(self, "ANCHOR_TOP")
	if self.count then
		tip:AddLine(K.L["%d more tracked buffs"]:format(self.count))
		for _, item in ipairs(self.folded or {}) do
			local name = SpellName(item)
			if name then
				tip:AddLine(name)
			end
		end
	else
		tip:AddLine(K.L["Cooldown Manager"])
	end
	tip:Show()
end

local function Chip(viewer)
	if not chip then
		chip = Style.Chip(viewer, true)
		chip:HookScript("OnEnter", ShowTooltip)
		chip:HookScript("OnLeave", Style.HideTooltip)
	end
	return chip
end

local function Place(viewer, slot, count, folded)
	local c = Chip(viewer)
	local cfg = Settings.current.buffs
	local scale = slot:GetScale()
	if type(scale) ~= "number" or ns.IsSecret(scale) or scale <= 0 then
		scale = 1
	end
	local w, h = slot:GetSize()
	w = (type(w) == "number" and not ns.IsSecret(w)) and w * scale or cfg.size
	h = (type(h) == "number" and not ns.IsSecret(h)) and h * scale or cfg.size
	Style.ShowChip(c, viewer, "LEFT", 0, w, h, count and ("+" .. count) or "+", cfg.countSize + Style.CHIP_TEXT)
	c:ClearAllPoints()
	c:SetAllPoints(slot)
	c:SetFrameLevel(slot:GetFrameLevel() + Style.CHIP_LEVEL)
	Style.Mouse(c, Tips(viewer))
	c.count, c.folded = count, folded
end

function Cap.Size()
	return Grid.Capacity(Settings.current.buffs)
end

function Cap.Chip()
	return chip
end

function Cap.Refresh()
	queued = false
	local viewer = Viewers.Frame(GROUP)
	if not viewer then
		return
	end
	local items = Items(viewer)
	if not active then
		for _, item in ipairs(items) do
			Release(item, viewer)
		end
		if chip then
			chip:Hide()
		end
		return
	end
	local size = Cap.Size()
	local count, known, slot, folded = 0, true, nil, {}
	for _, item in ipairs(items) do
		local index = Index(item)
		if index <= size then
			Release(item, viewer)
		else
			Fold(item)
			if index == size + 1 then
				slot = item
			end
			local shown = Shown(item)
			if shown == nil then
				known = false
			elseif shown then
				count = count + 1
				folded[#folded + 1] = item
			end
		end
	end
	if slot and (not known or count > 0) then
		Place(viewer, slot, known and count or nil, folded)
	elseif chip then
		chip:Hide()
	end
end

function Cap.Queue()
	if queued then
		return
	end
	queued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Cap.Refresh)
	else
		Cap.Refresh()
	end
end

function Cap.Watch(item)
	local state = Side(item)
	if state.hooked or type(item.UpdateShownState) ~= "function" then
		return
	end
	state.hooked = true
	hooksecurefunc(item, "UpdateShownState", Cap.Queue)
end

function Cap.Start()
	local viewer = Viewers.Frame(GROUP)
	if not viewer then
		return false
	end
	local side = K.Safe.Side(viewer)
	if not side.capHooked then
		side.capHooked = true
		for _, method in ipairs({ "Layout", "SetTooltipsShown" }) do
			if type(viewer[method]) == "function" then
				hooksecurefunc(viewer, method, Cap.Queue)
			end
		end
	end
	active = true
	ns.Log("the restyled tracked buff row stops at " .. Cap.Size() .. " sockets; a chip counts the rest")
	Cap.Queue()
	return true
end

function Cap.Stop()
	active = false
	Cap.Refresh()
end

function Cap.Slots(count)
	if type(count) ~= "number" then
		return count
	end
	local size = Cap.Size()
	if count > size then
		return size + 1
	end
	return count
end
