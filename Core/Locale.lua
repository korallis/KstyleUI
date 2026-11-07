-- Locale.lua: the locale table KstyleUI.L, which returns the key for a string with no entry.
local _, ns = ...

ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
