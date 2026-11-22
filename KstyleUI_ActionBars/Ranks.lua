-- Ranks.lua: batches learned spells into one offer to update ranks or fill empty visible action slots, out of combat.
local _, ns = ...

local K = KstyleUI
local L = K.L

ns.Ranks = {}

local BATCH_DELAY, CURSOR_WAIT, MAX_LOADING = 0.5, 1, 20

local pending, offer, approved, loading = {}, {}, {}, {}
local scheduled, handle, loadingCount = false, nil, 0
local Flush, Ask
local newOffer, newApproved = {}, {}
local newPending, rankPending = {}, {}
local watching = false

local function Plain(v)
	return not ns.IsSecret(v) and v ~= nil
end

local function NameRank(id)
	if type(id) ~= "number" or not (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellSubtext) then
		return nil
	end
	local name, sub = C_Spell.GetSpellName(id), C_Spell.GetSpellSubtext(id)
	local rank = Plain(name) and Plain(sub) and type(name) == "string" and type(sub) == "string" and tonumber((sub:match("%d+")))
	if rank then
		return name, rank, sub
	end
end

local function SpellIn(slot)
	local kind, id
	if type(GetActionInfo) == "function" and ns.SlotValid(slot) then
		kind, id = GetActionInfo(slot)
	end
	if Plain(kind) and Plain(id) and kind == "spell" and type(id) == "number" then
		return id
	end
end

local function Drop()
	offer, handle = {}, nil
	newOffer = {}
end

local function Keep(spells, new)
	for id, old in pairs(spells) do
		if old.name == new.name then
			if (old.rank or 0) > (new.rank or 0) then
				return
			end
			spells[id] = nil
		end
	end
	spells[new.spell] = new
end

local function OnBars(id, name)
	for slot = 1, ns.MAX_SLOT do
		local other = SpellIn(slot)
		local otherName = other and C_Spell.GetSpellName and C_Spell.GetSpellName(other)
		if other == id or Plain(otherName) and otherName == name then
			return true
		end
	end
	return false
end

local function Active(id)
	local book = C_SpellBook
	if not (book and book.FindSpellBookSlotForSpell and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType
		and type(GetProfessions) == "function" and type(GetProfessionInfo) == "function") then
		return false
	end
	local index, bank = book.FindSpellBookSlotForSpell(id, false, false, false, false)
	if not Plain(index) or type(index) ~= "number" or not Plain(bank) or bank ~= Enum.SpellBookSpellBank.Player then
		return false
	end
	local info = book.GetSpellBookItemInfo(index, bank)
	if not Plain(info) or type(info) ~= "table" or not Plain(info.itemType) or info.itemType ~= Enum.SpellBookItemType.Spell
		or not Plain(info.isPassive) or info.isPassive ~= false or not Plain(info.isOffSpec) or info.isOffSpec ~= false then
		return false
	end
	for _, profession in pairs({ GetProfessions() }) do
		if not Plain(profession) then
			return false
		end
		local _, _, _, _, count, offset = GetProfessionInfo(profession)
		if not Plain(count) or not Plain(offset) or type(count) ~= "number" or type(offset) ~= "number" then
			return false
		end
		if index > offset and index <= offset + count then
			return false
		end
	end
	return true
end

local function EmptySlot()
	for _, key in ipairs({ "bar1", "bar2" }) do
		local bar = ns.bars[key]
		if bar and bar:Shown() and bar.holder:IsShown() and bar.header:IsShown() then
			local slots = {}
			local cfg = bar:Config()
			local grouped = ns.Slab.Grouped(bar.def)
			for i = 1, bar.count do
				local button = bar.buttons[i]
				local col, row = ns.Cell(i, bar.count, ns.Slab.Rows(bar.def, cfg), grouped and "HORIZONTAL" or cfg.orientation, grouped and "RIGHTDOWN" or cfg.growth)
				slots[#slots + 1] = { slot = button.slot, col = col, row = row }
			end
			table.sort(slots, function(a, b) return a.row == b.row and a.col < b.col or a.row < b.row end)
			for _, cell in ipairs(slots) do
				if ns.SlotValid(cell.slot) then
					local has = C_ActionBar.HasAction(cell.slot)
					if Plain(has) and has == false then
						return cell.slot
					end
				end
			end
		end
	end
end

local function Schedule()
	if not scheduled then
		scheduled = true
		C_Timer.After(BATCH_DELAY, Flush)
	end
end

local function Cached(id)
	if C_Spell and type(C_Spell.IsSpellDataCached) == "function" then
		local cached = C_Spell.IsSpellDataCached(id)
		return Plain(cached) and cached == true
	end
	return false
end

local function Request(id)
	if loading[id] or Cached(id) then
		return
	end
	if not (C_Spell and type(C_Spell.RequestLoadSpellData) == "function") then
		ns.LogOnce("ranksLoad", "C_Spell.RequestLoadSpellData is missing; a rank whose text has not loaded is skipped")
		return
	end
	if loadingCount >= MAX_LOADING then
		ns.LogOnce("ranksLoading", MAX_LOADING .. " spells are already loading; spell " .. id .. " is skipped")
		return
	end
	loading[id], loadingCount = true, loadingCount + 1
	C_Spell.RequestLoadSpellData(id)
end

local function Apply()
	if not ns.running then
		approved, newApproved = {}, {}
		return
	end
	if ns.Config("ranks") == "off" then
		approved = {}
	end
	if ns.Config("newSpells") == "off" then
		newApproved = {}
	end
	if next(approved) == nil and next(newApproved) == nil then
		return
	end
	if InCombatLockdown() then
		K.Combat.Queue(Apply)
		return
	end
	if not (C_Spell and C_Spell.PickupSpell) or type(PlaceAction) ~= "function" or type(ClearCursor) ~= "function" or type(GetCursorInfo) ~= "function" then
		ns.LogOnce("ranksApi", "C_Spell.PickupSpell, PlaceAction, ClearCursor or GetCursorInfo is missing; new ranks stay off the bars")
		return
	end
	if GetCursorInfo() then
		ns.LogOnce("ranksCursor", "the cursor holds something; new ranks wait until it is empty")
		C_Timer.After(CURSOR_WAIT, Apply)
		return
	end
	for slot, o in pairs(approved) do
		if SpellIn(slot) == o.from then
			C_Spell.PickupSpell(o.to.spell)
			PlaceAction(slot)
			ClearCursor()
			if SpellIn(slot) ~= o.to.spell then
				ns.LogOnce("rank" .. slot .. ":" .. o.to.spell, "slot " .. slot .. " did not take spell " .. o.to.spell .. "; it keeps what it had")
			end
		end
	end
	approved = {}
	local additions = {}
	for _, spell in pairs(newApproved) do
		additions[#additions + 1] = spell
	end
	table.sort(additions, function(a, b) return a.spell < b.spell end)
	local noRoom = false
	for _, spell in ipairs(additions) do
		if Active(spell.spell) and not OnBars(spell.spell, spell.name) then
			local slot = EmptySlot()
			if slot then
				C_Spell.PickupSpell(spell.spell)
				local kind, _, _, id = GetCursorInfo()
				if Plain(kind) and Plain(id) and kind == "spell" and id == spell.spell then
					local has = C_ActionBar.HasAction(slot)
					if Plain(has) and has == false then
						PlaceAction(slot)
					end
				end
				ClearCursor()
			else
				noRoom = true
			end
		end
	end
	newApproved = {}
	if noRoom then
		K.Widgets.Popup({ title = L["New spells"], text = L["No free slots on bar 1 or bar 2. Make room, then drag the new spells from your spellbook."] })
	end
	ns.Log("new ranks placed on the bars")
end

local function Update(fromDialog)
	if fromDialog and InCombatLockdown() then
		K.Widgets.Popup({ title = L["New spell rank"], text = L["You are in combat. Your bars update when combat ends."] })
	end
	for slot, o in pairs(offer) do
		approved[slot] = o
	end
	offer = {}
	K.Combat.Queue(Apply)
	if fromDialog and next(newOffer) then
		Ask()
	end
end

local function Add(fromDialog)
	for _, spell in pairs(newOffer) do
		Keep(newApproved, spell)
	end
	newOffer = {}
	K.Combat.Queue(Apply)
	if fromDialog and next(offer) then
		Ask()
	end
end

function Ask()
	if InCombatLockdown() then
		K.Combat.Queue(Ask)
		return
	end
	if not ns.running then
		return
	end
	for id, spell in pairs(newOffer) do
		if ns.Config("newSpells") == "off" or OnBars(id, spell.name) then
			newOffer[id] = nil
		end
	end
	local seen, lines = {}, {}
	for _, o in pairs(offer) do
		if not seen[o.to] then
			seen[o.to] = true
			lines[#lines + 1] = o.to.label
		end
	end
	table.sort(lines)
	local text = #lines == 1 and L["You learned a new rank: %s. Update your action bars?"]:format(lines[1])
		or L["You learned new ranks:"] .. "\n" .. table.concat(lines, "\n") .. "\n" .. L["Update your action bars?"]
	local additions = {}
	for _, spell in pairs(newOffer) do
		additions[#additions + 1] = spell.label
	end
	table.sort(additions)
	if #additions > 0 then
		text = (#lines > 0 and text .. "\n\n" or "") .. L["New spells:"] .. "\n" .. table.concat(additions, "\n")
	elseif #lines == 0 then
		return
	end
	local buttons = { { label = L["Not now"], onClick = Drop } }
	if #lines > 0 then
		buttons[#buttons + 1] = { label = L["Update bars"], primary = true, onClick = Update }
	end
	if #additions > 0 then
		buttons[#buttons + 1] = { label = L["Add new to bars"], primary = #lines == 0, onClick = Add }
	end
	if handle then
		handle:Close()
	end
	handle = K.Widgets.Popup({
		key = "ActionBars.Ranks", title = #additions > 0 and L["New spells"] or L["New spell rank"], text = text, onCancel = Drop,
		buttons = buttons,
	})
end

function Flush()
	scheduled = false
	local mode, learned, found, batch = ns.Config("ranks"), {}, false, pending
	pending = {}
	if not ns.running or mode == "off" and ns.Config("newSpells") == "off" then
		return
	end
	for id, fresh in pairs(batch) do
		local name, rank, sub = NameRank(id)
		if name and rankPending[id] then
			local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
			icon = Plain(icon) and type(icon) == "number" and ("|T%d:0|t "):format(icon) or ""
			learned[#learned + 1] = { spell = id, name = name, rank = rank, label = icon .. K.Locale.Upper(name) .. " (" .. K.Locale.Upper(sub) .. ")" }
		elseif fresh == true and (rankPending[id] or newPending[id]) then
			Request(id)
		end
		local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
		if newPending[id] and ns.Config("newSpells") ~= "off" and Plain(spellName) and type(spellName) == "string" and Active(id) and not OnBars(id, spellName) then
			local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
			icon = Plain(icon) and type(icon) == "number" and ("|T%d:0|t "):format(icon) or ""
			Keep(newOffer, { spell = id, name = spellName, rank = rank, label = icon .. K.Locale.Upper(spellName) })
		end
		if not loading[id] and not pending[id] then newPending[id], rankPending[id] = nil, nil end
	end
	for slot = 1, #learned > 0 and ns.MAX_SLOT or 0 do
		local id = SpellIn(slot)
		local name, rank = NameRank(id)
		for _, new in ipairs(learned) do
			local o = offer[slot]
			if mode ~= "off" and name == new.name and rank < new.rank and not (o and o.to.rank >= new.rank) then
				offer[slot], found = { from = id, to = new }, true
			end
		end
	end
	if found and mode == "auto" then
		Update()
	end
	if next(newOffer) and ns.Config("newSpells") == "auto" then
		Add()
	end
	if next(offer) or next(newOffer) then
		Ask()
	end
end

function ns.Ranks.Learned(spellID)
	if Plain(spellID) and type(spellID) == "number" then
		if not watching then
			watching = true
			K.Callbacks.Register("SettingChanged", "ActionBars.Spells", function(_, module, key)
				if module == "ActionBars" and key == "newSpells" and ns.Config(key) == "off" then
					newOffer, newApproved, newPending = {}, {}, {}
					if handle then
						handle:Close()
						handle = nil
					end
					if next(offer) then Ask() end
				end
			end)
		end
		newPending[spellID] = ns.Config("newSpells") ~= "off" or nil
		rankPending[spellID] = ns.Config("ranks") ~= "off" or nil
		pending[spellID] = true
		Schedule()
	end
end

function ns.Ranks.Loaded(spellID, success)
	if not (Plain(spellID) and type(spellID) == "number" and loading[spellID]) then
		return
	end
	loading[spellID], loadingCount = nil, loadingCount - 1
	if Plain(success) and success == true then
		pending[spellID] = "loaded"
		Schedule()
	else
		newPending[spellID], rankPending[spellID] = nil, nil
	end
end

function ns.Ranks.Stop()
	if handle then
		handle:Close()
	end
	offer, approved, handle, rankPending = {}, {}, nil, {}
	if ns.running then
		if next(newOffer) then Ask() end
		return
	end
	pending, loading, loadingCount, newOffer, newApproved, newPending = {}, {}, 0, {}, {}, {}
	K.Callbacks.Unregister("SettingChanged", "ActionBars.Spells")
	watching = false
end
