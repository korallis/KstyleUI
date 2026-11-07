-- Fonts.lua: asks the game for every font KstyleUI may use while it is loading, since this client loads a font file only when first asked for during a loading screen.
local addonName, ns = ...

local Tokens, Theme, Store, L = ns.Tokens, ns.Theme, ns.Store, ns.L

local Fonts = {}
ns.Fonts = Fonts

local SECTION = "Fonts"
local PROBE_SIZE = 12
local MAX_DEPTH = 8

local holders = {}
local loaded = {}
local reported = {}
local made = 0

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

function Fonts.Request(path)
	if not Theme.IsFontPath(path) then
		return false
	end
	if loaded[path] then
		return true
	end
	if type(CreateFont) ~= "function" then
		return false
	end
	local holder = holders[path]
	if not holder then
		made = made + 1
		holder = CreateFont("KstyleUIFont" .. made)
		holders[path] = holder
	end
	loaded[path] = holder:SetFont(path, PROBE_SIZE, "") ~= false
	return loaded[path]
end

function Fonts.IsLoaded(path)
	return loaded[path] == true
end

local function Collect(value, out, depth, seen)
	if type(value) == "string" then
		if Theme.IsFontPath(value) then
			out[#out + 1] = value
		end
	elseif type(value) == "table" and depth < MAX_DEPTH and not seen[value] then
		seen[value] = true
		for _, child in pairs(value) do
			Collect(child, out, depth + 1, seen)
		end
	end
end

local function Wanted()
	local out = {}
	for _, item in ipairs(Tokens.MediaList("font")) do
		out[#out + 1] = item.path
	end
	if Store.IsLoaded() then
		Collect(Store.Profile(), out, 0, {})
	end
	return out
end

local function RequestAll(paths, atRuntime)
	for _, path in ipairs(paths) do
		if not Fonts.Request(path) and not reported[path] then
			reported[path] = true
			if atRuntime then
				ns.Print(string.format(L["the font %s shows after you type /reload."], path:match("([^\\/]+)$") or path))
			else
				Log("the font " .. path .. " did not load while the game was loading")
			end
		end
	end
end

RequestAll(Wanted(), false)

ns.Events.Register(SECTION, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(SECTION, "ADDON_LOADED")
		RequestAll(Wanted(), false)
	end
end)
ns.Events.Register(SECTION, "PLAYER_LOGIN", function()
	ns.Events.Unregister(SECTION, "PLAYER_LOGIN")
	RequestAll(Wanted(), false)
end)
ns.Callbacks.Register("SettingChanged", SECTION, function(_, _, _, value)
	local paths = {}
	Collect(value, paths, 0, {})
	RequestAll(paths, true)
end)
ns.Callbacks.Register("ProfileChanged", SECTION, function()
	RequestAll(Wanted(), true)
end)
