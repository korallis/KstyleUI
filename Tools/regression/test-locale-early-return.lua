-- test-locale-early-return.lua: unrelated locale chunks, and every one on a client with no GetLocale (run_all.py --affected relies on it), return before touching the addon namespace, while Spanish remains shared with esMX.
local locales = { "deDE", "frFR", "esES", "zhCN" }
for _, code in ipairs(locales) do
	local chunk = assert(loadfile("Core/Locales/" .. code .. ".lua"))
	setfenv(chunk, { GetLocale = function() return "enUS" end })
	chunk("KstyleUI", nil)
	chunk = assert(loadfile("Core/Locales/" .. code .. ".lua"))
	setfenv(chunk, {})
	chunk("KstyleUI", nil)
end
for _, client in ipairs({ "deDE", "frFR", "esES", "esMX", "zhCN" }) do
	local loaded = {}
	for _, code in ipairs(locales) do
		local chunk = assert(loadfile("Core/Locales/" .. code .. ".lua"))
		setfenv(chunk, { GetLocale = function() return client end })
		chunk("KstyleUI", { Locale = { Add = function(strings)
			assert(strings.Party, "the matched locale must construct its translations")
			loaded[#loaded + 1] = code
		end } })
	end
	assert(#loaded == 1 and loaded[1] == (client == "esMX" and "esES" or client), "load exactly the matching locale, including the Spanish alias")
end
print("locale early return ok")
