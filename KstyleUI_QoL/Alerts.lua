-- Alerts.lua: quiet error text, which hides through UIErrorsFrame's own SetMessageTypeEnabled the cooldown, range and resource errors that Retail's error frame never shows and Forever's override shows again, and shows only those it hid when it stops.
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

ns.AddPart({
	name = "alerts",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or key == "quietErrors" then
			Sync()
		end
	end,
})
