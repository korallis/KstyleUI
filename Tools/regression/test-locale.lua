-- test-locale.lua: KstyleUI.L returns a stored string, and the key itself for a string with no entry.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end
local L = Load(core, Stubs.NewEnv()).KstyleUI.L
assert(type(L) == "table", "KstyleUI.L is missing")

-- A missing string falls back to its key, so English needs no entries and a missing translation shows English.
assert(L["Unit Frames"] == "Unit Frames", "a missing string must return its key, got " .. tostring(L["Unit Frames"]))
assert(rawget(L, "Unit Frames") == nil, "reading a missing string must not store it")

-- A module's Locale.lua stores translations, and a stored string wins over the key.
L["Unit Frames"] = "Einheitenfenster"
assert(L["Unit Frames"] == "Einheitenfenster", "a stored string must win, got " .. tostring(L["Unit Frames"]))
assert(L["Action Bars"] == "Action Bars", "other keys still fall back")

-- Two environments do not share one table.
local other = Load(core, Stubs.NewEnv()).KstyleUI.L
assert(other ~= L and other["Unit Frames"] == "Unit Frames", "each load gets its own locale table")

print("locale ok")
