-- test-locale.lua: KstyleUI.L reads the client's string table, capitals keep their accents, and KstyleUI's faces give way to the game's font where they lack the client's script.
local W = dofile("Tools/regression/widget_env.lua")

local OWN = "Interface\\AddOns\\KstyleUI\\Media\\Fonts\\"
local THIN = "\226\128\137"

-- Boot(locale) -> env, KstyleUI on a client whose GetLocale returns locale (nil: a client without GetLocale).
local function Boot(locale)
	return W.New({
		setup = function(env)
			env.GetLocale = locale and function()
				return locale
			end or nil
		end,
	})
end

-- A missing string falls back to its key without storing it, a stored string wins, and two loads do not share a table.
do
	local _, K = Boot(nil)
	local L = K.L
	assert(L["Unit Frames"] == "Unit Frames", "a missing string must return its key, got " .. tostring(L["Unit Frames"]))
	assert(rawget(L, "Unit Frames") == nil, "reading a missing string must not store it")
	L["Unit Frames"] = "Einheitenfenster"
	assert(L["Unit Frames"] == "Einheitenfenster", "a stored string must win, got " .. tostring(L["Unit Frames"]))
	assert(L["Action Bars"] == "Action Bars", "other keys still fall back")
	local _, other = Boot(nil)
	assert(other.L ~= L and other.L["Unit Frames"] == "Unit Frames", "each load gets its own locale table")
end

-- An English client reads every key as itself.
do
	local _, K = Boot("enUS")
	assert(K.L["Party"] == "Party" and K.L["Raid"] == "Raid", "English reads the key")
	assert(K.L["a key no table has"] == "a key no table has", "a missing key reads as itself")
	assert(K.Locale.CLIENT == "enUS", "the client locale is recorded")
end

-- A client without GetLocale is English.
do
	local _, K = Boot(nil)
	assert(K.Locale.CLIENT == "enUS" and K.L["Raid"] == "Raid", "no GetLocale reads English")
end

-- Each shipped locale reads its own table, in WoW's own words, and only that table loads.
local WORDS = {
	deDE = { Party = "Gruppe", Raid = "Schlachtzug", ["Layout Mode"] = "Layoutmodus" },
	frFR = { Party = "Groupe", Raid = "Raid", ["Layout Mode"] = "Mode Disposition" },
	esES = { Party = "Grupo", Raid = "Banda", ["Layout Mode"] = "Modo diseño" },
	zhCN = { Party = "小队", Raid = "团队", ["Layout Mode"] = "布局模式" },
}
for code, words in pairs(WORDS) do
	local _, K = Boot(code)
	for key, text in pairs(words) do
		assert(K.L[key] == text, code .. " reads " .. key .. " as " .. text .. ", got " .. tostring(K.L[key]))
	end
	assert(K.L["a key no table has"] == "a key no table has", code .. ": a missing key falls back to English")
	for other, otherWords in pairs(WORDS) do
		if other ~= code and otherWords.Party ~= words.Party then
			assert(K.L["Party"] ~= otherWords.Party, code .. " must not load the " .. other .. " table")
		end
	end
end

-- Every shipped table holds every key of the English base, so no string falls back to English by omission on a
-- shipped client (round 5, Muse #4: the tables held 2027 to 2031 of 2042 keys).
local function baseKeys()
	local handle = assert(io.open("Tools/locale/enUS.json", "rb"), "the English base exists")
	local json = handle:read("*a")
	handle:close()
	local keys = {}
	local function utf8(code)
		if code < 0x80 then
			return string.char(code)
		elseif code < 0x800 then
			return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
		end
		return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
	end
	local ESCAPES = { n = "\n", t = "\t", r = "\r", ["\""] = "\"", ["\\"] = "\\", ["/"] = "/" }
	for line in json:gmatch("[^\n]+") do
		local body = line:match('^%s*"(.*)",?%s*$')
		if body then
			body = body:gsub("\\u(%x%x%x%x)", function(hex)
				return utf8(tonumber(hex, 16))
			end):gsub("\\(.)", ESCAPES)
			keys[#keys + 1] = body
		end
	end
	assert(#keys > 1000, "the base lists the keys, got " .. #keys)
	return keys
end
do
	local keys = baseKeys()
	for _, code in ipairs({ "deDE", "frFR", "esES", "zhCN" }) do
		local _, K = Boot(code)
		local missing, count = {}, 0
		for _, key in ipairs(keys) do
			if rawget(K.L, key) == nil then
				missing[#missing + 1] = key
			end
		end
		for _ in pairs(K.L) do
			count = count + 1
		end
		assert(#missing == 0, code .. " lacks " .. #missing .. " of the base's " .. #keys .. " keys, such as " .. tostring(missing[1]))
		assert(count == #keys, code .. " holds " .. count .. " strings against the base's " .. #keys)
	end
end

-- The settings rule that help is one sentence under 100 characters binds the English text; a translation of it may run longer.
do
	local _, K = Boot("deDE")
	local long = "Ein Satz, der in der Übersetzung länger ist als hundert Zeichen, weil Deutsch längere Wörter hat als Englisch."
	assert(#long >= 100, "the sample is over the limit")
	assert(not K.Locale.IsTranslation(long), "a string no table holds is not a translation")
	K.Locale.Add({ ["A short English sentence."] = long })
	assert(K.Locale.IsTranslation(long), "a stored translation is known")
	K.Store.RegisterDefaults("LocaleProbe", { on = true })
	K.Store.RegisterDefaults("LocaleProbe2", { on = true })
	K.Options.Register("LocaleProbe", {
		{ type = "toggle", key = "on", label = "On", help = K.L["A short English sentence."] },
	})
	local ok = pcall(K.Options.Register, "LocaleProbe2", {
		{ type = "toggle", key = "on", label = "On", help = string.rep("h", 100) },
	})
	assert(not ok, "English help of 100 characters is still refused")
end

-- Latin American Spanish reads the Spanish table; a locale KstyleUI does not ship reads English.
do
	local _, K = Boot("esMX")
	assert(K.L["Raid"] == "Banda", "esMX reads esES")
	local _, ko = Boot("koKR")
	assert(ko.L["Raid"] == "Raid", "koKR has no table and reads English")
end

-- The format specifiers survive translation, so every format call still gets its arguments.
do
	local _, K = Boot("deDE")
	assert(K.L["Level %d"]:format(12) == "Stufe 12", "a translated format string still formats: " .. K.L["Level %d"])
end

-- Capitals keep their accents: the uppercase roles upper Latin-1 letters and the ligatures as well as ASCII.
do
	local _, K = Boot("frFR")
	local Upper = K.Locale.Upper
	assert(Upper("réglages") == "RÉGLAGES", "é capitalises, got " .. Upper("réglages"))
	assert(Upper("größe übersicht") == "GRÖßE ÜBERSICHT", "ö and ü capitalise; ß has no single capital and stays")
	assert(Upper("cœur ÿ ñ ç à") == "CŒUR Ÿ Ñ Ç À", "œ, ÿ, ñ, ç and à capitalise")
	assert(Upper("÷ ×") == "÷ ×", "the division and multiplication signs are not letters")
	assert(Upper("小队 abc") == "小队 ABC", "Chinese text passes through")
	local root = K.Scale.Root()
	local text = K.Widgets.Text(root, "title", "text")
	K.Widgets.SetText(text, "Barres d’actions élégantes")
	assert(text:GetText() == "BARRES D’ACTIONS ÉLÉGANTES", "a title role capitalises accented letters: " .. tostring(text:GetText()))
	local panel = K.Widgets.Panel(root, { title = "Préférences" })
	assert(panel.titleText:GetText() == "PRÉFÉRENCES", "a panel title capitalises accented letters: " .. tostring(panel.titleText:GetText()))
end

-- Fonts: a locale whose script KstyleUI's faces cover keeps them.
do
	local _, K = Boot("deDE")
	assert(K.Tokens.Font("title") == OWN .. "Cinzel-SemiBold.ttf", "German keeps Cinzel for titles")
	assert(K.Tokens.Font("body") == OWN .. "AlegreyaSansTabular-Regular.ttf", "German keeps Alegreya Sans for body text")
	assert(K.Tokens.FontPath("CinzelSemiBold") == OWN .. "Cinzel-SemiBold.ttf", "and FontPath returns the face")
end

-- Chinese, Taiwanese and Korean clients draw every role in the game's own font, which has their glyphs.
local GAME = { zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\blei00d.TTF", koKR = "Fonts\\2002.TTF" }
for code, path in pairs(GAME) do
	local _, K = Boot(code)
	for _, role in ipairs({ "display", "heading", "body", "title", "caption", "number", "world" }) do
		local got = K.Tokens.Font(role)
		assert(got == path, code .. ": the " .. role .. " role uses " .. path .. ", got " .. tostring(got))
	end
	for _, face in ipairs(K.Tokens.MediaList("font")) do
		assert(K.Tokens.FontPath(face.key) == path, code .. ": FontPath(" .. face.key .. ") gives the game font")
		assert(face.path == path, code .. ": a font picker's " .. face.key .. " stores the game font, so picking it keeps the client's glyphs")
	end
	assert(K.Locale.Font("Interface\\AddOns\\SharedMedia\\Fonts\\Other.ttf") == "Interface\\AddOns\\SharedMedia\\Fonts\\Other.ttf", code .. ": another addon's font is the player's choice and stays")
	local fs = K.Widgets.Text(K.Scale.Root(), "body", "text")
	K.Widgets.StyleText(fs, "title")
	assert(fs:GetFont() == path, code .. ": a styled font string carries the game font")
end

-- Russian keeps Alegreya Sans, which has Cyrillic, and swaps only Cinzel, which does not.
do
	local _, K = Boot("ruRU")
	assert(K.Tokens.Font("title") == "Fonts\\FRIZQT___CYR.TTF", "Russian titles use the game's Cyrillic font")
	assert(K.Tokens.Font("body") == OWN .. "AlegreyaSansTabular-Regular.ttf", "Russian body text keeps Alegreya Sans")
end

-- Tooltip titles and captions are tracked with thin spaces in a KstyleUI face, and left untracked in the game font.
for code, spaced in pairs({ deDE = true, zhCN = false }) do
	local env, K = Boot(code)
	env.CreateColor = function(r, g, b, a)
		return { r = r, g = g, b = b, a = a }
	end
	local tip = K.Widgets.Tooltip()
	tip:SetOwner(env.CreateFrame("Button", nil, K.Scale.Root()), "ANCHOR_RIGHT")
	tip:AddCaption("Épique")
	local got = tip.used[1].left:GetText()
	if spaced then
		assert(got == "É" .. THIN .. "P" .. THIN .. "I" .. THIN .. "Q" .. THIN .. "U" .. THIN .. "E", code .. ": the caption is tracked capitals, got " .. got)
	else
		assert(got == "ÉPIQUE" and not got:find(THIN, 1, true), code .. ": no thin spaces in the game font, got " .. got)
	end
end

print("locale ok")
