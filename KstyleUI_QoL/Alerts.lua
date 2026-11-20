-- Alerts.lua: quiet error text, which hides through UIErrorsFrame's own SetMessageTypeEnabled the cooldown, range and resource errors that Retail's error frame never shows and Forever's override shows again, and shows only those it hid when it stops; cinematic skips, the delete word and resurrection offers.
local _, ns = ...

local TYPES = {
	"LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_SPELL_COOLDOWN", "LE_GAME_ERR_OUT_OF_RANGE",
	"LE_GAME_ERR_OUT_OF_POWER_DISPLAY", "LE_GAME_ERR_OUT_OF_MANA", "LE_GAME_ERR_OUT_OF_RAGE",
	"LE_GAME_ERR_OUT_OF_ENERGY", "LE_GAME_ERR_OUT_OF_FOCUS", "LE_GAME_ERR_OUT_OF_RUNIC_POWER",
	"LE_GAME_ERR_OUT_OF_COMBO_POINTS", "LE_GAME_ERR_OUT_OF_HOLY_POWER", "LE_GAME_ERR_OUT_OF_SOUL_SHARDS",
	"LE_GAME_ERR_OUT_OF_CHI", "LE_GAME_ERR_OUT_OF_PAIN", "LE_GAME_ERR_OUT_OF_HEALTH",
	"LE_GAME_ERR_OUT_OF_ARCANE_CHARGES", "LE_GAME_ERR_OUT_OF_LUNAR_POWER", "LE_GAME_ERR_OUT_OF_INSANITY",
	"LE_GAME_ERR_OUT_OF_RUNES", "LE_GAME_ERR_OUT_OF_FURY", "LE_GAME_ERR_OUT_OF_MAELSTROM",
	"LE_GAME_ERR_OUT_OF_ESSENCE",
}

local hidden = {}

local function Switch()
	local frame = UIErrorsFrame
	local fn = frame and frame.SetMessageTypeEnabled
	if type(fn) ~= "function" then
		ns.LogOnce("alerts-switch", "UIErrorsFrame:SetMessageTypeEnabled is missing; error text stays as the game shows it")
		return nil
	end
	return frame, fn
end

local function AlreadyHidden(id)
	local list = BLACK_LISTED_MESSAGE_TYPES
	return type(list) == "table" and list[id] == true
end

local function Hide()
	local frame, fn = Switch()
	if not frame then
		return
	end
	for _, name in ipairs(TYPES) do
		local id = _G[name]
		if type(id) == "number" and not hidden[id] and not AlreadyHidden(id) then
			fn(frame, id, false)
			hidden[id] = true
		end
	end
end

local function Show()
	local frame, fn = Switch()
	for id in pairs(hidden) do
		if frame then
			fn(frame, id, true)
		end
		hidden[id] = nil
	end
end

local function Sync()
	if ns.running and ns.Get("quietErrors") then
		Hide()
	elseif next(hidden) then
		Show()
	end
end

local cinematicToken = 0

local function SkipCinematic(_, cancellable)
	cinematicToken = cinematicToken + 1
	if not ns.Get("skipCinematics") or not ns.True(cancellable) or type(StopCinematic) ~= "function" or type(IsShiftKeyDown) ~= "function" then return end
	local held = IsShiftKeyDown()
	if ns.IsSecret(held) or held ~= false then return end
	local delay, token = ns.Get("skipDelay"), cinematicToken
	if delay == 0 then StopCinematic(); return end
	if not C_Timer or type(C_Timer.After) ~= "function" or type(InCinematic) ~= "function" then return end
	C_Timer.After(delay, function()
		if ns.running and token == cinematicToken and ns.Get("skipCinematics") and ns.True(InCinematic()) then
			local shift = IsShiftKeyDown()
			if not ns.IsSecret(shift) and shift == false then StopCinematic() end
		end
	end)
end

local DELETE_POPUPS = { "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }

local function FillDelete()
	if not (ns.running and ns.Get("autoDelete")) or type(StaticPopup_FindVisible) ~= "function" or type(DELETE_ITEM_CONFIRM_STRING) ~= "string" then return end
	for _, which in ipairs(DELETE_POPUPS) do
		local dialog = StaticPopup_FindVisible(which)
		local box = dialog and type(dialog.GetEditBox) == "function" and dialog:GetEditBox()
		if box then box:SetText(DELETE_ITEM_CONFIRM_STRING) end
	end
end

local function Resurrect(_, inviter)
	if not ns.Get("autoResurrect") or type(AcceptResurrect) ~= "function" then return end
	if not ns.Get("combatResurrect") then
		local ok, fighting = pcall(UnitAffectingCombat, inviter)
		if not ok or ns.IsSecret(fighting) or fighting then return end
	end
	local wait = type(GetCorpseRecoveryDelay) == "function" and ns.Number(GetCorpseRecoveryDelay())
	if wait == 0 then AcceptResurrect() end
end

local OPTIONAL = {
	DELETE_ITEM_CONFIRM = { "autoDelete", function() if C_Timer then C_Timer.After(0, FillDelete) else FillDelete() end end },
	RESURRECT_REQUEST = { "autoResurrect", Resurrect },
}

local function Listen()
	for event, entry in pairs(OPTIONAL) do
		if ns.running and ns.Get(entry[1]) then
			ns.K.Events.Register(ns.MODULE, event, entry[2])
		else
			ns.K.Events.Unregister(ns.MODULE, event)
		end
	end
end

ns.AddPart({
	name = "alerts",
	events = { CINEMATIC_START = SkipCinematic },
	Start = function() Sync(); Listen() end,
	Stop = function() cinematicToken = cinematicToken + 1; Sync(); Listen() end,
	Setting = function(key)
		if key == nil or key == "skipCinematics" or key == "skipDelay" then cinematicToken = cinematicToken + 1 end
		if key == nil or key == "autoDelete" or key == "autoResurrect" then Listen() end
		if key == nil or key == "quietErrors" then
			Sync()
		end
	end,
})
