-- Ranks.lua: when the player learns a higher rank of a spell on the bars, asks (or not, per the setting) and puts the new rank in every slot that held a lower one.
local _, ns = ...

local K = KstyleUI
local L = K.L

ns.Ranks = {}

local BATCH_DELAY, CURSOR_WAIT, MAX_LOADING = 0.5, 1, 20

local pending, offer, approved, loading = {}, {}, {}, {}
local scheduled, handle, loadingCount = false, nil, 0
local Flush

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
	if next(approved) == nil or ns.Config("ranks") == "off" then
		approved = {}
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
end

local function Ask()
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
	if handle then
		handle:Close()
	end
	handle = K.Widgets.Popup({
		key = "ActionBars.Ranks", title = L["New spell rank"], text = text, onCancel = Drop,
		buttons = { { label = L["Not now"], onClick = Drop }, { label = L["Update bars"], primary = true, onClick = Update } },
	})
end

function Flush()
	scheduled = false
	local mode, learned, found, batch = ns.Config("ranks"), {}, false, pending
	pending = {}
	if not ns.running or mode == "off" then
		return
	end
	for id, fresh in pairs(batch) do
		local name, rank, sub = NameRank(id)
		if name then
			local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
			icon = Plain(icon) and type(icon) == "number" and ("|T%d:0|t "):format(icon) or ""
			learned[#learned + 1] = { spell = id, name = name, rank = rank, label = icon .. K.Locale.Upper(name) .. " (" .. K.Locale.Upper(sub) .. ")" }
		elseif fresh == true then
			Request(id)
		end
	end
	for slot = 1, #learned > 0 and ns.MAX_SLOT or 0 do
		local id = SpellIn(slot)
		local name, rank = NameRank(id)
		for _, new in ipairs(learned) do
			local o = offer[slot]
			if name == new.name and rank < new.rank and not (o and o.to.rank >= new.rank) then
				offer[slot], found = { from = id, to = new }, true
			end
		end
	end
	if found and mode == "auto" then
		Update()
	elseif found then
		Ask()
	end
end

function ns.Ranks.Learned(spellID)
	if Plain(spellID) and type(spellID) == "number" then
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
	end
end

function ns.Ranks.Stop()
	if handle then
		handle:Close()
	end
	pending, offer, approved, loading, handle, loadingCount = {}, {}, {}, {}, nil, 0
end
