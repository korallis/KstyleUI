-- Locale.lua: the locale table KstyleUI.L, which reads the client's string table and returns the key for a string with no entry, plus capitals that keep their accents and the game font that stands in where KstyleUI's faces lack the client's script.
local _, ns = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L

local Locale = {}
ns.Locale = Locale

local CLIENT = type(GetLocale) == "function" and GetLocale() or "enUS"
if type(CLIENT) ~= "string" then
	CLIENT = "enUS"
end
local SHARED_TABLE = { esMX = "esES" }
local GAME_FONTS = {
	zhCN = { path = "Fonts\\ARKai_T.ttf", every = true },
	zhTW = { path = "Fonts\\blei00d.TTF", every = true },
	koKR = { path = "Fonts\\2002.TTF", every = true },
	ruRU = { path = "Fonts\\FRIZQT___CYR.TTF" },
}
local LATIN_ONLY = { ["Cinzel-SemiBold.ttf"] = true }
local OWN_FONTS = "\\KstyleUI\\Media\\Fonts\\"
local CAPITALS = { ["\197\147"] = "\197\146", ["\195\191"] = "\197\184" }

local fallback = GAME_FONTS[CLIENT]

Locale.CLIENT = CLIENT
Locale.SPACED = not (fallback and fallback.every)

function Locale.Uses(code)
	return code == CLIENT or code == SHARED_TABLE[CLIENT]
end

local translations = {}

function Locale.Add(strings)
	for key, text in pairs(strings) do
		rawset(L, key, text)
		translations[text] = true
	end
end

function Locale.IsTranslation(text)
	return translations[text] == true
end

function Locale.Font(path)
	if not fallback or type(path) ~= "string" then
		return path
	end
	local at = path:find(OWN_FONTS, 1, true)
	if not at then
		return path
	end
	if fallback.every or LATIN_ONLY[path:sub(at + #OWN_FONTS)] then
		return fallback.path
	end
	return path
end

local function Capital(lead, trail)
	local byte = trail:byte()
	if lead == "\195" and byte >= 160 and byte <= 190 and byte ~= 183 then
		return lead .. string.char(byte - 32)
	end
	return CAPITALS[lead .. trail]
end

function Locale.Upper(text)
	return (text:upper():gsub("([\195\197])([\128-\191])", Capital))
end
