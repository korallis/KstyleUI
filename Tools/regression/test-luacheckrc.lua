-- test-luacheckrc.lua: luacheck's settings deny removed APIs and keep each module's globals in its folder.
local RC = ".luacheckrc"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Run a config the way luacheck does: globals fall back to _G, and files autovivifies. generated
-- replaces Tools/data/forever_globals.lua when given.
local function run(source, generated)
	local files = setmetatable({}, {
		__index = function(t, key)
			local value = {}
			rawset(t, key, value)
			return value
		end,
	})
	local env = setmetatable({ files = files, stds = {} }, { __index = _G })
	if generated then
		env.require = function()
			return generated
		end
	end
	local chunk = assert(loadstring(source, "=" .. RC))
	setfenv(chunk, env)
	local ok, err = pcall(chunk)
	if not ok then
		return nil, tostring(err)
	end
	return env
end

local function set(list)
	local result = {}
	for _, name in ipairs(list) do
		result[name] = true
	end
	return result
end

local source = read(RC)
local forever = dofile("Tools/data/forever_globals.lua")
local env = assert(run(source))

-- Addon code sees Lua 5.1 plus Forever's globals; Tools code sees Lua 5.1 only.
assert(env.std == "lua51+forever", "addon std is " .. tostring(env.std))
assert(env.files["Tools/"].std == "lua51", "Tools/ must not see game globals")
for _, path in ipairs({ "Libs/", "Tools/regression/fixtures/", "Tools/spikes/" }) do
	assert(set(env.exclude_files)[path], "exclude_files lacks " .. path)
end

-- The deny list wins over the generated list, and every deprecated shim is denied.
local readable = set(env.stds.forever.read_globals)
for _, name in ipairs({ "IsPlayerSpell", "GetSpellInfo", "ReloadUI", "CombatLogGetCurrentEventInfo" }) do
	assert(not readable[name], name .. " must not be in read_globals")
end
assert(#forever.deprecated > 0, "the generated list has no deprecated names")
for _, name in ipairs(forever.deprecated) do
	assert(not readable[name], "deprecated " .. name .. " must not be in read_globals")
end
for _, name in ipairs({
	"C_Secrets", "C_SwingTimer", "C_SpellBook", "UnitHealthPercent", "WOW_PROJECT_CAMELOT",
	"CreateFrame", "UIParent", "PlayerFrame", "InCombatLockdown", "hooksecurefunc", "KstyleUI",
}) do
	assert(readable[name], name .. " must be in read_globals")
end

-- The deny list holds even when a regenerated list offers its names.
local fake = run(source, {
	read = { "CreateFrame", "GetSpellInfo", "IsPlayerSpell", "ReloadUI", "OldShim" },
	deprecated = { "OldShim" },
})
assert(fake, "the config must load with a fake generated list")
local fake_readable = set(fake.stds.forever.read_globals)
assert(fake_readable.CreateFrame, "the fake list's CreateFrame must stay readable")
for _, name in ipairs({ "GetSpellInfo", "IsPlayerSpell", "ReloadUI", "OldShim" }) do
	assert(not fake_readable[name], name .. " must be denied even when the generated list has it")
end

-- The generated list is sorted, has no duplicates, and keeps read and deprecated apart.
for _, key in ipairs({ "read", "deprecated" }) do
	local list = forever[key]
	for i = 2, #list do
		assert(list[i - 1] < list[i], key .. " is not sorted and unique at " .. list[i])
	end
end
local generated = set(forever.read)
for _, name in ipairs(forever.deprecated) do
	assert(not generated[name], name .. " is in both read and deprecated")
end

-- The module section holds one call per line, with a blank line between lines, and a line for
-- each module the spec names.
local section = source:match("\n%-%- BEGIN MODULE GLOBALS\n(.-)%-%- END MODULE GLOBALS")
assert(section, "the module section markers are missing")
local blank_before = false
local folders = {}
for line in section:gmatch("([^\n]*)\n") do
	if line == "" then
		blank_before = true
	else
		assert(blank_before, "the module section needs a blank line before: " .. line)
		local folder = line:match('^module_globals%("([%w_]+)", {.*}%)$')
		assert(folder, "the module section takes one module_globals call per line: " .. line)
		folders[folder] = true
		blank_before = false
	end
end
assert(blank_before, "the module section needs a blank line before its END marker")
for _, folder in ipairs({
	"Core", "KstyleUI_Options", "KstyleUI_UnitFrames", "KstyleUI_GroupFrames", "KstyleUI_ActionBars",
	"KstyleUI_Cooldowns", "KstyleUI_Auras", "KstyleUI_Nameplates", "KstyleUI_CombatText",
	"KstyleUI_Minimap", "KstyleUI_Chat", "KstyleUI_Bags", "KstyleUI_Tooltips", "KstyleUI_DataBars",
	"KstyleUI_Meters", "KstyleUI_Skins",
}) do
	assert(folders[folder], "the module section has no line for " .. folder)
end

-- A module's names become globals in its own folder only.
local function with_lines(...)
	local lines = table.concat({ ... }, "\n\n")
	return (source:gsub("%-%- END MODULE GLOBALS", function()
		return lines .. "\n\n-- END MODULE GLOBALS"
	end))
end
local ok = assert(run(with_lines(
	'module_globals("KstyleUI_TestA", { "KstyleUI_TestFrame", "BINDING_HEADER_KSTYLEUI_TEST", "SlashCmdList" })',
	'module_globals("KstyleUI_TestB", { "StaticPopupDialogs", "SlashCmdList" })'
)))
local owned = set(ok.files["KstyleUI_TestA/"].globals)
assert(owned.KstyleUI_TestFrame and owned.BINDING_HEADER_KSTYLEUI_TEST and owned.SlashCmdList)
assert(not set(ok.files["KstyleUI_TestB/"].globals).KstyleUI_TestFrame)
assert(set(ok.files["Core/"].globals).KstyleUIDB, "Core owns KstyleUIDB")

-- A bad module line stops luacheck with a message that names the line and the fix.
local function rejects(message, ...)
	local result, err = run(with_lines(...))
	assert(not result, "expected the config to reject: " .. message)
	assert(err:find(RC .. ":%d+:"), "the error must name the config line: " .. err)
	assert(err:find(message, 1, true), "wrong error: " .. err)
end
rejects("IsPlayerSpell is denied", 'module_globals("KstyleUI_TestA", { "IsPlayerSpell" })')
rejects(forever.deprecated[1] .. " is denied", 'module_globals("KstyleUI_TestA", { "' .. forever.deprecated[1] .. '" })')
rejects("PlayerFrame is a Blizzard global", 'module_globals("KstyleUI_TestA", { "PlayerFrame" })')
rejects(
	"KstyleUI_TestFrame is already claimed by KstyleUI_TestA",
	'module_globals("KstyleUI_TestA", { "KstyleUI_TestFrame" })',
	'module_globals("KstyleUI_TestB", { "KstyleUI_TestFrame" })'
)
rejects("already has a line", 'module_globals("Core", {})')
rejects("Core or KstyleUI_<Module>", 'module_globals("Bags", {})')
rejects("is not a Lua name", 'module_globals("KstyleUI_TestA", { "bad-name" })')

print("luacheckrc ok: " .. #env.stds.forever.read_globals .. " read globals")
