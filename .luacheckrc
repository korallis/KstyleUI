-- .luacheckrc: luacheck settings for KstyleUI.
-- Addon code sees Lua 5.1 and the globals Forever gives addons, minus the deny list below. The
-- list is generated from Blizzard's UI source by Tools/build/gen_globals.py into
-- Tools/data/forever_globals.lua. Code under Tools/ runs outside the game and sees Lua 5.1 only.

std = "lua51+forever"
max_line_length = false
ignore = { "212" } -- unused argument: handlers receive arguments they often do not need
exclude_files = { "Libs/", ".release/", "Tools/regression/fixtures/", "Tools/spikes/" }

local forever = require("Tools.data.forever_globals")

-- Names that fail any use, even when Blizzard code still has them. Each reason names the fix.
local DENY = {
	CombatLogGetCurrentEventInfo = "the combat log is closed to addons on Forever",
	GetSpellInfo = "removed from Forever: use C_Spell.GetSpellInfo",
	IsPlayerSpell = "a deprecated shim Forever does not load: use C_SpellBook.IsSpellKnown",
	ReloadUI = "blocked for addon code: use a secure macro button that runs /reload",
}
for _, name in ipairs(forever.deprecated) do
	DENY[name] = DENY[name] or "a deprecated shim Forever does not load"
end

-- Blizzard tables a module may add its own keys to. The taint scan checks the keys.
local SHARED_TABLES = { SlashCmdList = true, StaticPopupDialogs = true }

local blizzard = {}
local read = { "KstyleUI" }
for _, name in ipairs(forever.read) do
	blizzard[name] = true
	if not DENY[name] then
		read[#read + 1] = name
	end
end
stds.forever = { read_globals = read }

files["Tools/"] = { std = "lua51" }

local folders, owner = {}, {}
local function module_globals(folder, names)
	local function fail(message)
		error(folder .. ": " .. message, 3) -- level 3 reports the module's line in this file
	end
	if folder ~= "Core" and not folder:match("^KstyleUI_%w+$") then
		fail("a module folder is Core or KstyleUI_<Module>")
	end
	if folders[folder] then
		fail("this folder already has a line; keep one line per module")
	end
	folders[folder] = true
	for _, name in ipairs(names) do
		if type(name) ~= "string" or not name:match("^[%a_][%w_]*$") then
			fail(tostring(name) .. " is not a Lua name")
		elseif DENY[name] then
			fail(name .. " is denied: " .. DENY[name])
		elseif blizzard[name] and not SHARED_TABLES[name] then
			fail(name .. " is a Blizzard global; read it without listing it, and never set it")
		elseif owner[name] then
			fail(name .. " is already claimed by " .. owner[name] .. "; use a name with your module's prefix")
		elseif not SHARED_TABLES[name] then
			owner[name] = folder -- any module may add its own keys to a shared table
		end
	end
	files[folder .. "/"] = { globals = names }
end

-- Module globals -------------------------------------------------------------------------------
-- Each line names the globals one module creates or sets: named frames (CreateFrame's second
-- argument, or name= in its XML), BINDING_HEADER_* and BINDING_NAME_* strings for Bindings.xml,
-- SLASH_* commands, and engine-read globals such as DAMAGE_TEXT_FONT. Code in that folder may read
-- and set them. Other folders may not, because modules talk only through KstyleUI. Edit only your
-- module's line. A new module adds its line at the end. Keep the blank line between lines, so
-- parallel branches that edit neighbouring lines merge without a conflict.
-- BEGIN MODULE GLOBALS

module_globals("Core", { "KstyleUI", "KstyleUIDB", "SlashCmdList", "SLASH_KSTYLE1" })

module_globals("KstyleUI_Options", {})

module_globals("KstyleUI_UnitFrames", {})

module_globals("KstyleUI_GroupFrames", {})

module_globals("KstyleUI_ActionBars", {})

module_globals("KstyleUI_Cooldowns", {})

module_globals("KstyleUI_Auras", {})

module_globals("KstyleUI_Nameplates", {})

module_globals("KstyleUI_CombatText", {})

module_globals("KstyleUI_Minimap", {})

module_globals("KstyleUI_Chat", {})

module_globals("KstyleUI_Bags", {})

module_globals("KstyleUI_Tooltips", {})

module_globals("KstyleUI_DataBars", {})

module_globals("KstyleUI_Meters", {})

module_globals("KstyleUI_Skins", {})

module_globals("KstyleUI_Icons", {})

module_globals("KstyleUI_IconsColour", {})

-- END MODULE GLOBALS
