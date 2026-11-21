-- Reminder.lua: the missing buff reminder, off by default: out of combat, a card names the first of your own class buffs you know and lack, read by spell name only while the game says that aura is not secret.
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
	MAGE = { { 1459, 23028 }, { 168, 7302, 6117 } },
	PRIEST = { { 1243, 21562 }, { 588 } },
	DRUID = { { 1126, 21849 } },
	WARLOCK = { { 687, 706, 403619 } },
	SHAMAN = { { 324, 408510 } },
	PALADIN = { { 465, 7294, 19746, 19876, 19888, 19891 } },
	HUNTER = { { 13165, 13163, 5118, 13159, 20043, 13161, 415423 } },
}
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }

local card, known
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
		local id
		for _, each in ipairs(ids) do
			local ok, has = pcall(book.IsSpellKnown, each)
			if not id and ok and Plain(has, "boolean") then id = each end
		end
		local name = id and Plain(spell.GetSpellName(id), "string")
		if name then
			local names = {}
			for _, each in ipairs(ids) do names[#names + 1] = Plain(spell.GetSpellName(each), "string") end
			known[#known + 1] = { ids = ids, names = names, name = name, icon = spell.GetSpellTexture and spell.GetSpellTexture(id) }
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
	for _, name in pairs(entry.names) do
		local ok, aura = pcall(api.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
		if type(aura) == "table" then return true end
	end
	return false
end

local function Missing()
	if InCombatLockdown() or Plain(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"), "boolean") ~= false then return nil end
	for _, entry in ipairs(Known()) do
		local has = Has(entry)
		if has == nil then return nil end
		if not has then return entry end
	end
end

function Reminder.Card(parent)
	local frame = Widgets.Panel(parent, {})
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
	frame.text:SetText(string.format(L["Missing: %s"], entry.name))
	Widgets.Size(frame.tile, ICON, ICON)
	Widgets.Point(frame.tile, "LEFT", frame, "LEFT", pad, 0)
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

function Reminder.Sample()
	local entry = Known()[1]
	if entry then return entry end
	local spell = C_Spell
	local name = spell and type(spell.GetSpellName) == "function" and Plain(spell.GetSpellName(SAMPLE), "string")
	return { name = name or L["Arcane Intellect"], icon = spell and spell.GetSpellTexture and spell.GetSpellTexture(SAMPLE) }
end

local function Refresh(event)
	if not card then return end
	local entry = on and event ~= "PLAYER_REGEN_DISABLED" and Missing() or nil
	if entry then Reminder.Paint(card, entry) end
	card:SetShown(entry ~= nil)
end

local function SpellsChanged()
	known = nil
	Refresh()
end

function Reminder.Sync(running)
	local want = running and K.Store.Module(MODULE).reminder.enabled == true
	if want ~= on then
		on = want
		for _, event in ipairs(EVENTS) do
			if on then K.Events.Register(OWNER, event, Refresh) else K.Events.Unregister(OWNER, event) end
		end
		if on then
			K.Events.Register(OWNER, "SPELLS_CHANGED", SpellsChanged)
			K.Events.RegisterUnit(OWNER, "UNIT_AURA", Refresh, "player")
		else
			K.Events.Unregister(OWNER, "SPELLS_CHANGED")
			K.Events.Unregister(OWNER, "UNIT_AURA")
		end
	end
	if on and not card then
		card = Reminder.Card(K.Scale.Root())
		card:Hide()
		Widgets.Place(card, KEY, POSITION, { label = L["Missing buff reminder"], module = MODULE, scalable = true })
	end
	if card and K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, on) end
	Refresh()
end
