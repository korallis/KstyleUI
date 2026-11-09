-- Slash.lua: the /kstyle command: settings, Layout Mode, setup, hover keybinds, smoke tests and profiles.
local _, ns = ...

local L = ns.L
local format = string.format

local USAGE = {
	"/kstyle - " .. L["open the settings"],
	"/kstyle layout - " .. L["enter or leave Layout Mode"],
	"/kstyle setup - " .. L["run the first-run setup again"],
	"/kstyle bind - " .. L["hover a button and press a key to bind it (Blizzard's Quick Keybind mode)"],
	"/kstyle test - " .. L["run the smoke checks and write the devlog"],
	"/kstyle profile - " .. L["list the profiles"],
	"/kstyle profile use <name> - " .. L["switch this character to a profile, creating it if needed"],
	"/kstyle profile new <name> - " .. L["create a profile with the default settings"],
	"/kstyle profile copy <name> - " .. L["copy a profile into the active one"],
	"/kstyle profile rename <name> - " .. L["rename the active profile"],
	"/kstyle profile delete <name> - " .. L["delete a profile"],
	"/kstyle profile reset - " .. L["reset the active profile to the defaults"],
}

local function usage()
	ns.Print(L["Commands:"])
	for _, line in ipairs(USAGE) do
		print("  " .. line)
	end
end

local function report(done, ok, err)
	if ok then
		ns.Print(done)
	else
		ns.Print(err)
	end
end

local function listProfiles()
	local Store = ns.Store
	ns.Print(format(L["Profiles (this character uses %s):"], tostring(Store.ProfileName())))
	for _, name in ipairs(Store.ListProfiles()) do
		print((name == Store.ProfileName() and "  * " or "    ") .. name)
	end
end

local PROFILE = {
	use = function(name)
		local ok, err = ns.Store.SetProfile(name)
		report(format(L["This character now uses the profile %s."], tostring(ns.Store.ProfileName())), ok, err)
	end,
	new = function(name)
		local ok, result = ns.Store.CreateProfile(name)
		report(format(L["Created the profile %s."], tostring(result)), ok, result)
	end,
	copy = function(name)
		local ok, err = ns.Store.CopyProfile(name, ns.Store.ProfileName())
		report(format(L["Copied %s into the active profile."], name), ok, err)
	end,
	rename = function(name)
		local ok, err = ns.Store.RenameProfile(ns.Store.ProfileName(), name)
		report(format(L["Renamed the active profile to %s."], tostring(ns.Store.ProfileName())), ok, err)
	end,
	delete = function(name)
		local ok, err = ns.Store.DeleteProfile(name)
		report(format(L["Deleted the profile %s."], name), ok, err)
	end,
	reset = function()
		local ok, err = ns.Store.ResetProfile()
		report(L["Reset the active profile to the defaults."], ok, err)
	end,
}

local function profile(rest)
	if not ns.Store.IsLoaded() then
		ns.Print(L["KstyleUI has not loaded its saved settings yet."])
		return
	end
	local action, name = rest:match("^(%S*)%s*(.-)$")
	action = action:lower()
	if action == "" then
		listProfiles()
		return
	end
	local fn = PROFILE[action]
	if fn then
		fn(name)
	else
		usage()
	end
end

local COMMANDS = {
	[""] = function()
		ns.Options.Open()
	end,
	layout = function()
		local Layout = ns.Layout
		if Layout and type(Layout.Toggle) == "function" then
			Layout.Toggle()
		else
			ns.Print(L["Layout Mode is not available yet."])
		end
	end,
	setup = function()
		local Setup = ns.Setup
		if Setup and type(Setup.Open) == "function" then
			Setup.Open()
		else
			ns.Print(L["The first-run setup is not available yet."])
		end
	end,
	bind = function()
		local frame = QuickKeybindFrame
		if type(frame) ~= "table" or type(frame.Show) ~= "function" then
			ns.Print(L["Blizzard's Quick Keybind mode is not available on this client; keybinds are in Options > Keybindings."])
			return
		end
		if InCombatLockdown() then
			ns.Print(L["Keybinds cannot change in combat; try again after the fight."])
			return
		end
		frame:Show()
	end,
	test = function()
		ns.DevTest.Run()
	end,
	profile = profile,
	help = usage,
}

SLASH_KSTYLE1 = "/kstyle"
SlashCmdList.KSTYLE = function(message)
	local command, rest = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local fn = COMMANDS[command:lower()]
	if fn then
		fn(rest)
	else
		usage()
	end
end
