-- Movement.lua: the movement alert, a Layout element that counts down the player's movement spells (Forever's classic-era IDs, highest known rank first) while they cool down, as text, an icon or a bar, one row per spell, and plays a sound or speaks the spell's name when one is ready. Whether a spell cools comes from its cooldown's never-secret isActive and isOnGCD fields on SPELL_UPDATE_COOLDOWN, and when switched on, where isOnGCD is not to be trusted, from a readable duration longer than the global cooldown (a secret one waits for the next event; a spell already known to cool keeps cooling while isActive holds); the time comes from its duration object, which the engine draws, so a cooldown the game makes secret in combat still counts down; while one cools, a POLL-second ticker watches for its end.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY = "QoL.movement", "qol.movement"
local POLL, WIDTH, NONE, CROP, GCD, INIT = 0.25, 220, -1, 0.08, 1.5, "init"
ns.MOVE_TOP = 104
local MOVES = {
	{ "moveCharge", "WARRIOR", 11578, 6178, 100 }, { "moveIntercept", "WARRIOR", 20617, 20616, 20252 },
	{ "moveSprint", "ROGUE", 11305, 8696, 2983 }, { "moveBlink", "MAGE", 1953 },
	{ "moveDash", "DRUID", 9821, 1850 }, { "moveFeralCharge", "DRUID", 1238122, 16979 },
}
for _, move in ipairs(MOVES) do ns.defaults[move[1]] = true end

local holder, ticker
local slots, tracked, ids = {}, {}, {}
local fighting = false

local function Spell(name, ...)
	return ns.Ask(C_Spell and C_Spell[name], ...)
end

function ns.MoveName(id)
	local name = Spell("GetSpellName", id)
	return type(name) == "string" and name or tostring(id)
end

function ns.MoveRows(off)
	local rows, class = {}, select(2, UnitClass("player"))
	for _, move in ipairs(MOVES) do
		if move[2] == class then
			rows[#rows + 1] = { type = "toggle", key = move[1], label = ns.MoveName(move[3]), help = L["Count this spell down while it cools."], disableWhen = off }
		end
	end
	if #rows == 0 then rows[1] = { type = "note", label = L["Your class has no movement spells to count down."] } end
	return rows
end

function ns.MoveSample()
	local class, sample = select(2, UnitClass("player")), nil
	for _, move in ipairs(MOVES) do
		if move[2] == class then
			if ns.Get(move[1]) then return move[3], true end
			sample = sample or move[3]
		end
	end
	return sample or MOVES[3][3], false
end

function ns.VoiceOptions()
	local options = { { value = NONE, label = L["None"] } }
	local voices = C_VoiceChat and ns.Ask(C_VoiceChat.GetTtsVoices)
	for _, voice in ipairs(type(voices) == "table" and voices or {}) do
		if type(voice.voiceID) == "number" and type(voice.name) == "string" then options[#options + 1] = { value = voice.voiceID, label = voice.name } end
	end
	return options
end

local function Paint(slot)
	local mode = ns.Get("moveMode")
	local bar, width = mode == "bar", WIDTH * ns.Get("moveSize") / ns.defaults.moveSize
	if mode == "icon" and not slot.icon then
		slot.icon = Widgets.IconButton(slot, { size = ns.Get("moveIconSize") })
		slot.icon:EnableMouse(false)
		Widgets.Point(slot.icon, "TOP", slot, "TOP", 0, 0)
	elseif bar and not slot.bar then
		slot.bar = Widgets.StatusBar(slot, { texture = ns.Get("moveTexture") })
		slot.bar.art = slot.bar:CreateTexture(nil, "OVERLAY")
		slot.bar.art:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		slot.bar.label = Widgets.FontString(slot.bar, "OVERLAY")
		Widgets.Point(slot.bar.label, "CENTER", slot.bar, "CENTER", 0, 0)
	end
	local text = bar and slot.bar.label or slot.text
	Widgets.ApplyFont(text, (Tokens.Font("display")), ns.Get("moveSize") * K.Theme.FontScale(), "OUTLINE")
	if bar then text:SetTextColor(Tokens.Color("textEmphasis")) else text:SetTextColor(ns.NoticeColor("move")) end
	local h = Widgets.LineHeight(text)
	slot.text:SetShown(mode ~= "icon" and not bar)
	Widgets.Point(slot.text, "CENTER", slot, "CENTER", 0, 0)
	if slot.icon then
		slot.icon:SetShown(mode == "icon")
		slot.icon.opts.size = ns.Get("moveIconSize")
		slot.icon:Restyle()
		Widgets.CountdownFormat(slot.icon.cooldown, ns.Get("moveDecimal") and Widgets.Duration.DECIMAL_BELOW or nil)
		h = mode == "icon" and ns.Get("moveIconSize") or h
	end
	if slot.bar then
		local art, icon = slot.bar.art, ns.Get("moveBarIcon")
		slot.bar:SetShown(bar)
		slot.bar:SetBarTexture(ns.Get("moveTexture"))
		slot.bar:SetBarColor(ns.NoticeColor("move"))
		h = bar and h + 2 * Tokens.Size("gapSmall") or h
		Widgets.Size(art, h, h)
		Widgets.Point(art, "RIGHT", slot.bar, "LEFT", 0, 0)
		art:SetShown(icon)
		Widgets.Point(slot.bar, "TOPRIGHT", slot, "TOPRIGHT", 0, 0)
		Widgets.Size(slot.bar, width - (icon and h or 0), h)
	end
	Widgets.Size(slot, mode == "icon" and h or width, h)
	slot.mode, slot.height = mode, h
	return h
end

function ns.BuildMoveSlot(parent)
	local slot = CreateFrame("Frame", nil, parent)
	slot.text = Widgets.FontString(slot, "OVERLAY")
	slot.Paint = Paint
	return slot
end

function ns.MoveFormat(name)
	local mode = ns.Get("moveMode")
	if mode == "time" or mode == "icon" then return "{}" end
	if mode == "bar" and not ns.Get("moveBarText") then return name end
	return mode == "timeFirst" and "{} " .. name or name .. " {}"
end

local function Bind(slot, text, format, duration)
	local util, E = C_DurationUtil, Enum
	local formatter = Widgets.Duration.Formatter(ns.Get("moveDecimal") and "decimal" or "short")
	if not slot.binding and util and type(util.CreateDurationTextBinding) == "function" then slot.binding = util.CreateDurationTextBinding() end
	local binding = slot.binding
	local ok = binding and formatter and E and E.DurationTextBindingProperty and pcall(function()
		if slot.bound ~= text or slot.format ~= format or slot.formatter ~= formatter then
			binding:SetFontString(text)
			binding:SetTextFormat(format, { { property = E.DurationTextBindingProperty.RemainingDuration, formatter = formatter } })
			slot.bound, slot.format, slot.formatter = text, format, formatter
		end
		binding:SetDuration(duration)
		binding:SetEnabled(true)
	end)
	if not ok then ns.LogOnce("move-binding", "C_DurationUtil text bindings are missing or refused the cooldown; the movement alert shows names only") end
	return ok
end

local function Fill(slot, id)
	local duration, mode = Spell("GetSpellCooldownDuration", id, true), slot.mode
	local text = mode == "bar" and slot.bar.label or slot.text
	if mode == "icon" then
		if slot.binding then slot.binding:SetEnabled(false) end
		slot.icon:SetIcon(Spell("GetSpellTexture", id))
		if duration then slot.icon:SetCooldownFromDuration(duration) end
		return
	end
	if mode == "bar" then
		local bar, E = slot.bar, Enum and Enum.StatusBarTimerDirection
		bar.art:SetTexture(Spell("GetSpellTexture", id))
		if not (duration and type(bar.SetTimerDuration) == "function" and pcall(bar.SetTimerDuration, bar, duration, 0, E and E.RemainingTime or 1)) then
			bar:SetBarRange(0, 1)
			bar:SetBarValue(1)
		end
	end
	local name = ns.MoveName(id)
	if not (duration and Bind(slot, text, ns.MoveFormat(name), duration)) then text:SetText(name) end
end

local function Shown()
	return ns.running and ns.Get("moveAlert") and (not ns.Get("moveCombat") or fighting)
end

local function Draw()
	local n, h, gap = 0, 0, Tokens.Size("gapSmall")
	if Shown() then
		for _, spell in ipairs(tracked) do
			if spell.cooling then
				n = n + 1
				local slot = slots[n] or ns.BuildMoveSlot(holder)
				slots[n] = slot
				h = slot.height or slot:Paint()
				slot:ClearAllPoints()
				Widgets.Point(slot, "TOP", holder, "TOP", 0, -(n - 1) * (h + gap))
				Fill(slot, spell.id)
				slot:Show()
			end
		end
	end
	for i = n + 1, #slots do
		if slots[i].binding then slots[i].binding:SetEnabled(false) end
		slots[i]:Hide()
	end
	if n > 0 then Widgets.Size(holder, slots[1]:GetWidth(), n * (h + gap) - gap) end
end

local function Ready(spell)
	if not Shown() then return end
	local voice, chat = ns.Get("moveVoice"), C_VoiceChat
	if voice ~= NONE and chat and type(chat.SpeakText) == "function" then
		pcall(chat.SpeakText, voice, ns.MoveName(spell.id), 0, ns.Get("moveVolume"), false)
	else
		ns.AlertSound(ns.Get("moveSound"))
	end
end

local function Refresh(event)
	local any, changed = false, event == INIT
	for _, spell in ipairs(tracked) do
		local now = spell.cooling
		if event or now then
			local info = Spell("GetSpellCooldown", spell.id)
			now = type(info) == "table" and info.isActive == true and not (event == true and info.isOnGCD == true)
				and (event ~= INIT or spell.cooling or (ns.Number(info.duration) or 0) > GCD)
		end
		if now ~= spell.cooling then
			changed, spell.cooling = true, now
			if not now then Ready(spell) end
		end
		any = any or now
	end
	if any and not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
		ticker = C_Timer.NewTicker(POLL, function() Refresh(false) end)
	elseif not any and ticker then
		ticker:Cancel()
		ticker = nil
	end
	if changed and holder then Draw() end
end

local function Cooldown(_, id, base)
	if id == nil or ids[id] or ids[base] then Refresh(true) end
end

local function Fight(event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Draw()
end

local function Track()
	local class = select(2, UnitClass("player"))
	local known, was = C_SpellBook and C_SpellBook.IsSpellKnown, {}
	for _, spell in ipairs(tracked) do was[spell.id] = spell.cooling end
	tracked = {}
	for _, move in ipairs(MOVES) do
		local on = move[2] == class and ns.Get(move[1])
		for i = 3, #move do
			ids[move[i]] = true
			if on and ns.Ask(known, move[i]) == true then
				on = false
				tracked[#tracked + 1] = { id = move[i], cooling = was[move[i]] or false }
			end
		end
	end
	Refresh(INIT)
end

local EVENTS = { SPELL_UPDATE_COOLDOWN = Cooldown, SPELLS_CHANGED = Track, PLAYER_REGEN_DISABLED = Fight, PLAYER_REGEN_ENABLED = Fight }

local function Spot()
	local _, h = K.Layout.RootSize()
	return { anchor = "TOP", x = 0, y = ns.MOVE_TOP - h / 2 }
end

local function Sync()
	local on = ns.running and ns.Get("moveAlert")
	for event, fn in pairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
	end
	if on and not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetFrameStrata("BACKGROUND")
		holder.Restyle = function()
			for _, slot in ipairs(slots) do slot.height = nil end
			Draw()
		end
		Widgets.Size(holder, WIDTH, Tokens.Size("lootText"))
		Widgets.Track(holder)
		Widgets.Place(holder, KEY, Spot(), { label = L["Movement alert"], module = ns.MODULE, scalable = true, defaultPosition = Spot })
	end
	if not holder then return end
	if K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, on) end
	holder:SetShown(on)
	fighting = ns.Ask(InCombatLockdown) == true
	if on then Track() else tracked = {}; Refresh(false) end
	holder:Restyle()
end

function ns.MoveFrame() return holder, slots end

ns.AddPart({
	name = "movement",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and key:find("^move") then Sync() end
	end,
})
