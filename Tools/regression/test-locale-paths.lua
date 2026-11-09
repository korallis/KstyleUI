-- test-locale-paths.lua: messages that tell the player where a Blizzard setting lives build the path from the client's own menu names, so every language reads the menus it shows.
local W = dofile("Tools/regression/widget_env.lua")

local GERMAN = {
	GAMEMENU_OPTIONS = "Optionen",
	SETTING_GROUP_GAMEPLAY = "Gameplay",
	ADVANCED_OPTIONS_LABEL = "Erweiterte Optionen",
	SETTINGS_KEYBINDINGS_LABEL = "Tastaturbelegung",
	CLICK_BIND_MODE = "Klickzauber",
}

local function Boot(globals)
	return W.New({
		setup = function(env)
			env.GetLocale = function()
				return "deDE"
			end
			for name, text in pairs(globals) do
				env[name] = text
			end
		end,
	})
end

do
	local env, K = Boot(GERMAN)
	local path = K.Locale.Path(env.GAMEMENU_OPTIONS, "Options", env.SETTING_GROUP_GAMEPLAY, "Gameplay", env.ADVANCED_OPTIONS_LABEL, "Advanced Options")
	assert(path == "Optionen > Gameplay > Erweiterte Optionen", "the German path reads the client's menu names, got " .. tostring(path))
end

do
	local env, K = Boot({ GAMEMENU_OPTIONS = "Optionen", SETTING_GROUP_GAMEPLAY = "" })
	local path = K.Locale.Path(env.GAMEMENU_OPTIONS, "Options", env.SETTING_GROUP_GAMEPLAY, "Gameplay", env.ADVANCED_OPTIONS_LABEL, "Advanced Options")
	assert(path == "Optionen > Gameplay > Advanced Options", "a missing or empty menu name falls back to English, got " .. tostring(path))
end

do
	local _, K = Boot(GERMAN)
	local text = K.L["Turn on the Cooldown Manager in %s to see the restyled cooldowns."]
	assert(text:find("%s", 1, true), "the German Cooldown Manager hint keeps its path slot")
	assert(not text:find("Kampf", 1, true), "the German hint no longer names the Combat page")
end

local SITES = {
	"KstyleUI_Cooldowns/Reskin.lua",
	"Core/Slash.lua",
	"KstyleUI_GroupFrames/Button.lua",
}
for _, file in ipairs(SITES) do
	local handle = assert(io.open(file, "rb"))
	local source = handle:read("*a")
	handle:close()
	assert(source:find("Locale.Path(GAMEMENU_OPTIONS", 1, true), file .. " builds its options path from Blizzard's menu names")
end

for _, code in ipairs({ "enUS", "deDE", "frFR", "esES", "zhCN" }) do
	local handle = assert(io.open("Tools/locale/" .. code .. ".json", "rb"))
	local source = handle:read("*a")
	handle:close()
	for _, stale in ipairs({ "Options > Gameplay > Combat", "Options > Keybindings.", "Options, Keybindings, Click Casting" }) do
		assert(not source:find(stale, 1, true), code .. " still carries a hard-coded options path: " .. stale)
	end
end

print("test-locale-paths: options paths come from the client's menu names")
