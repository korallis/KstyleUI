-- Reminder.lua: the reminder card, off by default: out of combat it warns of low mana in a ready check, then names a class buff you know and lack, then a flask you carry when none is on you in a raid, reading each aura only while the game says it is not secret.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Model, Button = ns.Model, ns.Button

local Reminder = {}
ns.Reminder = Reminder

local MODULE, KEY, OWNER = Model.MODULE, "auras.reminder", "Auras.reminder"
local POSITION = { anchor = "TOP", x = 0, y = -180 }
local ICON = 28
local SAMPLE = 1459
local BUFFS = {
	MAGE = { { 1459, 23028 }, { 168, 7302, 6117, 428741 } },
	PRIEST = { { 1243, 21562 }, { 588 } },
	DRUID = { { 1126, 21849 } },
	WARLOCK = { { 687, 706, 403619 } },
	SHAMAN = { { 324, 408510, 408514 } },
	PALADIN = { { 465, 7294, 19746, 19876, 19888, 19891, 20218 } },
	HUNTER = { { 13165, 13163, 5118, 13159, 20043, 13161, 415423, 469145 } },
}
local FLASKS = { { 13510, 17626 }, { 13511, 17627 }, { 13512, 17628 }, { 13513, 17629 }, { 274273, 1293740 }, { 274274, 1293741 }, { 274275, 1293742 }, { 274276, 1293743 } }
local EVENTS = { "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }

local card, known, shown, checking, ends, carried, pending, subscribed, Watch
local on = false

local function Plain(value, kind)
	if type(value) ~= kind or (issecretvalue and issecretvalue(value)) then return nil end
	return value
end

local function Known()
	if known then return known end
	known = {}
	local book, spell = C_SpellBook, C_Spell
	if not (book and type(book.IsSpellKnown) == "function" and spell and type(spell.GetSpellName) == "function" and type(UnitClass) == "function") then
		K.DevTest.Log(MODULE, "C_SpellBook.IsSpellKnown or C_Spell.GetSpellName is missing; no buff reminder shows")
		return known
	end
	local _, class = UnitClass("player")
	for _, ids in ipairs(BUFFS[Plain(class, "string") or ""] or {}) do
		local at
		for i, each in ipairs(ids) do
			local ok, has = pcall(book.IsSpellKnown, each)
			if ok and Plain(has, "boolean") then at = i break end
		end
		local names = {}
		for _, each in ipairs(at and ids or {}) do names[#names + 1] = Plain(spell.GetSpellName(each), "string") end
		if at and #names == #ids then
			known[#known + 1] = { ids = ids, names = names, text = string.format(L["Missing: %s"], names[at]), icon = spell.GetSpellTexture and Plain(spell.GetSpellTexture(ids[at]), "number") }
		end
	end
	return known
end

local function Has(entry)
	local api, secrets = C_UnitAuras, C_Secrets
	if not (api and type(api.GetAuraDataBySpellName) == "function" and secrets and type(secrets.ShouldSpellAuraBeSecret) == "function") then return nil end
	for _, id in ipairs(entry.ids) do
		local ok, secret = pcall(secrets.ShouldSpellAuraBeSecret, id)
		if not ok or Plain(secret, "boolean") ~= false then return nil end
	end
	for _, name in ipairs(entry.names) do
		local ok, aura = pcall(api.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
		if type(aura) == "table" then return true end
	end
	return false
end

local function LowMana()
	local mana = Enum and Enum.PowerType and Enum.PowerType.Mana
	if not (mana and type(UnitPower) == "function" and type(UnitPowerMax) == "function") then return false end
	local most, now = Plain(UnitPowerMax("player", mana), "number"), Plain(UnitPower("player", mana), "number")
	return most ~= nil and now ~= nil and most > 0 and now < most * 0.8
end

local function Carried()
	if carried ~= nil then return carried end
	local item = C_Item
	carried, pending = false, nil
	if not (item and type(item.GetItemCount) == "function" and type(item.GetItemNameByID) == "function") then return carried end
	for _, flask in ipairs(FLASKS) do
		local count = Plain(item.GetItemCount(flask[1]), "number")
		if count and count > 0 then
			local name, icon = Plain(item.GetItemNameByID(flask[1]), "string"), item.GetItemIconByID and Plain(item.GetItemIconByID(flask[1]), "number")
			if not (name and icon) then
				pending = flask[1]
				if type(item.RequestLoadItemDataByID) == "function" then pcall(item.RequestLoadItemDataByID, flask[1]) end
			end
			carried = name and { text = string.format(L["Missing: %s (%d)"], name, count), icon = icon } or false
			return carried
		end
	end
	return carried
end

local function Flask()
	local api, secrets = C_UnitAuras, C_Secrets
	if not (type(IsInInstance) == "function" and Plain(select(2, IsInInstance()), "string") == "raid") then return nil end
	local entry = Carried()
	if not (entry and api and type(api.GetPlayerAuraBySpellID) == "function" and secrets and type(secrets.ShouldSpellAuraBeSecret) == "function") then return nil end
	for _, flask in ipairs(FLASKS) do
		local ok, secret = pcall(secrets.ShouldSpellAuraBeSecret, flask[2])
		if not ok or Plain(secret, "boolean") ~= false then return nil end
		local read, aura = pcall(api.GetPlayerAuraBySpellID, flask[2])
		if not read or (issecretvalue and issecretvalue(aura)) or aura ~= nil then return nil end
	end
	return entry
end

local MANA = { text = L["Low mana"], icon = 132794 }

local function Missing()
	if InCombatLockdown() or Plain(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"), "boolean") ~= false then return nil end
	local s = K.Store.Module(MODULE).reminder
	if checking and (not ends or GetTime() < ends) and LowMana() then return MANA end
	if s.enabled == true then
		for _, entry in ipairs(Known()) do
			local has = Has(entry)
			if has == nil then break end
			if not has then return entry end
		end
	end
	return s.flasks == true and Flask() or nil
end

function Reminder.Card(parent)
	local frame = Widgets.Panel(parent)
	frame.tile = CreateFrame("Frame", nil, frame)
	frame.tile.chrome = Widgets.IconChrome(frame.tile)
	frame.icon = frame.tile:CreateTexture(nil, "ARTWORK")
	frame.text = Widgets.FontString(frame, "OVERLAY")
	return frame
end

function Reminder.Paint(frame, entry)
	local s = K.Store.Module(MODULE).reminder
	local pad, gap, line = Tokens.Size("gapMedium"), Tokens.Size("gapSmall"), Widgets.Border(frame)
	Button.StyleText(frame.text, { font = s.font, size = s.size * Model.TextScale(), outline = s.outline }, "textEmphasis", "body")
	frame.text:SetText(entry.text)
	Widgets.Size(frame.tile, ICON, ICON)
	Widgets.Point(frame.tile, "LEFT", frame, "LEFT", pad, 0)
	if K.HudStyle.Current() == "medallions" and K.Store.Module(MODULE).medallionsIcons then
		frame.tile.chrome:SetRim(Tokens.Color("medSocketRim"))
	else
		frame.tile.chrome:SetRim()
	end
	frame.tile.chrome:Restyle()
	frame.icon:SetTexture(entry.icon)
	local zoom = Model.IconZoom(K.Store.Module(MODULE))
	frame.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	frame.icon:SetPoint("TOPLEFT", frame.tile, "TOPLEFT", 2 * line, -2 * line)
	frame.icon:SetPoint("BOTTOMRIGHT", frame.tile, "BOTTOMRIGHT", -2 * line, 2 * line)
	Widgets.Point(frame.text, "LEFT", frame.tile, "RIGHT", gap, 0)
	local width = pad + ICON + gap + Widgets.TextWidth(frame.text, 0) + pad
	Widgets.Size(frame, width, ICON + 2 * pad)
	return width, ICON + 2 * pad
end

function Reminder.Samples(s)
	local list, spell, item = {}, C_Spell, C_Item
	if s.mana == true then list[#list + 1] = MANA end
	if s.enabled == true then
		local name = spell and type(spell.GetSpellName) == "function" and Plain(spell.GetSpellName(SAMPLE), "string")
		list[#list + 1] = Known()[1] or { text = string.format(L["Missing: %s"], name or L["Arcane Intellect"]), icon = spell and spell.GetSpellTexture and spell.GetSpellTexture(SAMPLE) }
	end
	if s.flasks == true then
		local name = item and type(item.GetItemNameByID) == "function" and Plain(item.GetItemNameByID(FLASKS[1][1]), "string")
		list[#list + 1] = { text = string.format(L["Missing: %s (%d)"], name or L["Flask of the Titans"], 3), icon = 134842 }
	end
	return list
end

local function Refresh(event)
	if not card then return end
	local entry = on and event ~= "PLAYER_REGEN_DISABLED" and Missing() or nil
	local key = entry and entry.text .. "|" .. tostring(entry.icon)
	if key == shown then return end
	shown = key
	if entry then Reminder.Paint(card, entry) end
	card:SetShown(entry ~= nil)
end

local function SpellsChanged()
	known = nil
	Refresh()
end

local function Aura(_, _, info)
	info = Plain(info, "table")
	if info and Plain(info.isFullUpdate, "boolean") == false and type(info.addedAuras) == "nil" and type(info.removedAuraInstanceIDs) == "nil" then return end
	Refresh()
end

local function Bags(event, id)
	if event == "ITEM_DATA_LOAD_RESULT" and (pending == nil or Plain(id, "number") ~= pending) then return end
	carried = nil
	Refresh()
end

local function Power(_, _, kind)
	kind = Plain(kind, "string")
	if kind and kind ~= "MANA" then return end
	if ends and GetTime() >= ends then return Watch("READY_CHECK_FINISHED") end
	Refresh()
end

Watch = function(event)
	if event == "READY_CHECK" or event == "READY_CHECK_FINISHED" then checking, ends = event == "READY_CHECK", nil end
	for _, each in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" }) do
		if checking then K.Events.RegisterUnit(OWNER, each, Power, "player") else K.Events.Unregister(OWNER, each) end
	end
	Refresh(event)
end

local function Subscribe(class, flasks, mana)
	K.Events.UnregisterAll(OWNER)
	known, carried, pending = nil, nil, nil
	if not mana then checking, ends = nil, nil end
	if not on then return end
	for _, event in ipairs(EVENTS) do K.Events.Register(OWNER, event, Refresh) end
	if class or flasks then K.Events.RegisterUnit(OWNER, "UNIT_AURA", Aura, "player") end
	if class then K.Events.Register(OWNER, "SPELLS_CHANGED", SpellsChanged) end
	if flasks then
		K.Events.Register(OWNER, "BAG_UPDATE_DELAYED", Bags)
		K.Events.Register(OWNER, "ITEM_DATA_LOAD_RESULT", Bags)
	end
	if mana then
		K.Events.Register(OWNER, "READY_CHECK", Watch)
		K.Events.Register(OWNER, "READY_CHECK_FINISHED", Watch)
		if checking == nil then
			local left = type(GetReadyCheckTimeLeft) == "function" and type(GetTime) == "function" and Plain(GetReadyCheckTimeLeft(), "number")
			checking = (left and left > 0) == true
			ends = checking and GetTime() + left or nil
		end
	end
end

function Reminder.Sync(running)
	local s = K.Store.Module(MODULE).reminder
	local class, flasks, mana = running and s.enabled == true, running and s.flasks == true, running and s.mana == true
	local want = tostring(class) .. tostring(flasks) .. tostring(mana)
	on = class or flasks or mana
	if want ~= subscribed then
		subscribed = want
		Subscribe(class, flasks, mana)
	end
	if on and not card then
		card = Reminder.Card(K.Scale.Root())
		card:Hide()
		Widgets.Place(card, KEY, POSITION, { label = L["Missing buff reminder"], module = MODULE, scalable = true })
	end
	if card and K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, on) end
	shown = false
	Watch()
end
