-- Range.lua: how far away the target is, as a band of yards ("30-35", "30+" or "30") in a Layout element, and whether it is out of reach for the crosshair's colour. The band comes from C_Spell.IsSpellInRange on one known spell for each range, read from the spellbook when spells change, harmful spells for an enemy and helpful ones otherwise, with Attack for melee; it is read again on a target change and every POLL seconds while there is a target and a reader is on. A secret or missing answer counts as unknown.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY = "QoL.range", "qol.range"
local POLL, MELEE, ATTACK, WIDTH = 0.2, 5, 6603, 120
local FORMATS = { range = "%d-%d", plus = "%d+", min = "%d" }

local holder, ticker, scanned
local lists = { harm = {}, help = {} }
local low, high
ns.rangeOut = false

local function Scan()
	local book, spell, E = C_SpellBook, C_Spell, Enum
	local bank = E and E.SpellBookSpellBank and E.SpellBookSpellBank.Player
	local seen = { harm = { [MELEE] = ATTACK }, help = {} }
	if book and spell and bank and type(book.GetNumSpellBookSkillLines) == "function" and type(spell.GetSpellInfo) == "function" then
		for line = 1, ns.Number(ns.Ask(book.GetNumSpellBookSkillLines)) or 0 do
			local info = ns.Ask(book.GetSpellBookSkillLineInfo, line)
			local first, count = type(info) == "table" and ns.Number(info.itemIndexOffset), type(info) == "table" and ns.Number(info.numSpellBookItems)
			for slot = (first or 0) + 1, (first or 0) + (count or 0) do
				local item = ns.Ask(book.GetSpellBookItemInfo, slot, bank)
				local id = type(item) == "table" and not item.isPassive and ns.Number(item.spellID)
				local data = id and ns.Ask(spell.GetSpellInfo, id)
				local range = type(data) == "table" and ns.Number(data.maxRange)
				local kind = range and range > 0 and (ns.Ask(spell.IsSpellHarmful, id) == true and "harm" or ns.Ask(spell.IsSpellHelpful, id) == true and "help")
				if kind and not seen[kind][range] then seen[kind][range] = id end
			end
		end
	end
	for kind, ranges in pairs(seen) do
		local list = {}
		for range, id in pairs(ranges) do list[#list + 1] = { range, id } end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		lists[kind] = list
	end
	scanned = true
end

local function Band()
	local inRange = C_Spell and C_Spell.IsSpellInRange
	low, high = nil, nil
	if ns.Ask(UnitExists, "target") ~= true or type(inRange) ~= "function" then return false end
	for _, check in ipairs(ns.Ask(UnitCanAttack, "player", "target") == true and lists.harm or lists.help) do
		local answer = ns.Ask(inRange, check[2], "target")
		if answer == true then
			high = check[1]
			break
		elseif answer == false then
			low = check[1]
		end
	end
	return low ~= nil or high ~= nil
end

function ns.RangeText(near, far)
	local format = ns.Get("rangeFormat")
	if format == "range" and not (near and far) then format = near and "plus" or "range" end
	return string.format(FORMATS[format], near or 0, far or near or 0)
end

function ns.PaintRange(text, box)
	Widgets.ApplyFont(text, (Tokens.Font("display")), ns.Get("rangeSize") * K.Theme.FontScale(), "OUTLINE")
	text:SetTextColor(Tokens.Color("textEmphasis"))
	local align, h = ns.Get("rangeAlign"), Widgets.LineHeight(text)
	text:ClearAllPoints()
	Widgets.Point(text, align, box, align, 0, 0)
	text:SetJustifyH(align)
	Widgets.Size(box, WIDTH * ns.Get("rangeSize") / ns.defaults.rangeSize, h)
end

local function Cutoff()
	if ns.Get("crosshairMelee") then return MELEE end
	local list = ns.Ask(UnitCanAttack, "player", "target") == true and lists.harm or lists.help
	return list[#list] and list[#list][1]
end

local function Wanted()
	return ns.running and (ns.Get("rangeText") or ns.Get("crosshairRange") and ns.Get("crosshair") ~= "none")
end

local function Update()
	local known = Wanted() and Band()
	local value = known and ns.RangeText(low, high) or ""
	if holder and holder:IsShown() and value ~= holder.value then
		holder.value = value
		holder.text:SetText(value)
	end
	local cutoff = known and Cutoff() or nil
	local out = cutoff ~= nil and low ~= nil and low >= cutoff
	if out ~= ns.rangeOut then
		ns.rangeOut = out
		local cross = ns.AidFrames()
		if cross then ns.CrossColor(cross) end
	end
end

local function Target()
	local watch = Wanted() and ns.Ask(UnitExists, "target") == true
	if watch and not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(POLL, Update)
	elseif not watch and ticker then
		ticker:Cancel()
		ticker = nil
	end
	Update()
end

local EVENTS = { PLAYER_TARGET_CHANGED = Target, SPELLS_CHANGED = function() Scan(); Update() end }

local function Sync()
	local on = Wanted()
	for event, fn in pairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
	end
	local shown = ns.running and ns.Get("rangeText")
	if shown and not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetFrameStrata("BACKGROUND")
		holder.text = Widgets.FontString(holder, "OVERLAY")
		holder.Restyle = function(self) ns.PaintRange(self.text, self) end
		Widgets.Track(holder)
		Widgets.Place(holder, KEY, { anchor = "CENTER", x = -90, y = 0 }, { label = L["Target distance"], module = ns.MODULE })
	end
	if holder then
		if K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, shown) end
		holder:SetShown(shown)
		holder.value = nil
		if shown then holder:Restyle() end
	end
	if on and not scanned then Scan() end
	scanned = on and scanned
	Target()
end

function ns.RangeFrame() return holder end

ns.AddPart({
	name = "range",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and (key:find("^range") or key:find("^crosshair")) then Sync() end
	end,
})
