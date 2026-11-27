-- Looks.lua: one-click Looks, controls and interface size, each a named set of existing settings (Readable also raises every text size below its readable size and lowers none); Forged and Keyboard are the shipped sets and the way back, and the current set is read from those settings, never saved.
local _, ns = ...

local L = ns.L
local Looks = {}
ns.Setup.Looks = Looks

local KEYS = { "Widgets.ornaments", "Widgets.cardMaterial", "Widgets.panelOpacity", "Medallions.motion", "Medallions.ambient", "Appearance.motion", "Appearance.outline", "Readability.preset" }
local ROLE_SIZES = { name = 14, health = 16, power = 16, level = 12, cast = 14, cooldown = 14, hotkey = 12, count = 12 }
local KEY_SIZES = { nameSize = 14, healthTextSize = 16, timerSize = 14, cooldownSize = 14 }
Looks.LIST = {
	{ value = "Forged", label = L["Forged"], note = L["The look KstyleUI ships with: forged trim, full motion and the usual text. Pick it to go back."], set = {} },
	{ value = "Clean", label = L["Clean"], note = L["Plain glass without trim, lighter panels, a still hub and calm motion."], set = {
		["Widgets.ornaments"] = "Off", ["Widgets.cardMaterial"] = "Glass", ["Widgets.panelOpacity"] = 0.65,
		["Medallions.motion"] = "calm", ["Medallions.ambient"] = false, ["Appearance.motion"] = "reduced",
	} },
	{ value = "Readable", label = L["Readable"], note = L["Larger text with a soft shadow on solid slate panels and subtle trim."], set = {
		["Widgets.ornaments"] = "Subtle", ["Widgets.cardMaterial"] = "Slate", ["Widgets.panelOpacity"] = 0.92, ["Appearance.outline"] = "SHADOW", ["Readability.preset"] = "Readable",
	} },
}
Looks.CUSTOM = { Looks.LIST[1], Looks.LIST[2], Looks.LIST[3], { value = "Custom", label = L["Your own"] } }
Looks.STATUS = { Looks.LIST[1], Looks.LIST[2], Looks.LIST[3], { value = "Custom", label = L["Your own"], disabled = true } }
local PAD_KEYS = { "ActionBars.bar1.buttons", "ActionBars.bar2.buttons", "ActionBars.bar1.split", "ActionBars.bar2.split", "ActionBars.useTray" }
Looks.CONTROLS = {
	{ value = "Keyboard", label = L["Keyboard"], note = L["Bars 1 and 2 as KstyleUI ships them: twelve buttons each. Pick it to go back."], set = {} },
	{ value = "Gamepad", label = L["Gamepad"], note = L["Eight buttons on bars 1 and 2, in a left and a right group; Frames drops the tray for bigger buttons."], set = {
		["ActionBars.bar1.buttons"] = 8, ["ActionBars.bar2.buttons"] = 8, ["ActionBars.bar1.split"] = "on", ["ActionBars.bar2.split"] = "on", ["ActionBars.useTray"] = false,
	} },
}
Looks.CONTROLS_CUSTOM = { Looks.CONTROLS[1], Looks.CONTROLS[2], Looks.CUSTOM[4] }
Looks.CONTROLS_STATUS = { Looks.CONTROLS[1], Looks.CONTROLS[2], Looks.STATUS[4] }

local function Sizes(module, defaults, path, readable, fn)
	for key, child in pairs(defaults) do
		if type(child) == "table" then
			Sizes(module, child, path .. key .. ".", readable, fn)
		elseif type(child) == "number" then
			local wanted = key == "size" and ROLE_SIZES[path:match("fonts%.(%w+)%.$") or path:match("text%.(%w+)%.$") or ""] or KEY_SIZES[key]
			if wanted then fn(module, path .. key, readable and math.max(child, wanted) or child) end
		end
	end
end

local function Default(path)
	local module, key = path:match("^(%a+)%.(.+)$")
	local default = ns.Store.Defaults(module)
	for part in key:gmatch("[^%.]+") do default = type(default) == "table" and default[part] or nil end
	return default, module, key
end

local function Each(look, fn, keys)
	for _, path in ipairs(keys or KEYS) do
		local default, module, key = Default(path)
		if default ~= nil then
			local value = look.set[path]
			if value == nil then value = default end
			fn(module, key, value)
		end
	end
	if keys then return end
	for _, module in ipairs(ns.Modules.List()) do
		local defaults = ns.Store.Defaults(module)
		if defaults then Sizes(module, defaults, "", look.set["Readability.preset"] == "Readable", fn) end
	end
end

function Looks.Get(name, list)
	for _, look in ipairs(list or Looks.LIST) do
		if look.value == name then return look end
	end
end

function Looks.Current(list, keys)
	if not ns.Store.IsLoaded() then return nil end
	for _, look in ipairs(list or Looks.LIST) do
		local match = true
		Each(look, function(module, key, value)
			match = match and ns.Options.Equal(ns.Options.Read(module, key), value)
		end, keys)
		if match then return look.value end
	end
end

function Looks.Apply(name, list, keys)
	local look = Looks.Get(name, list)
	if not look or not ns.Store.IsLoaded() then return false end
	local text = ns.Store.Module("Readability").preset
	Each(look, function(module, key, value)
		if not ns.Options.Equal(ns.Options.Read(module, key), value) then ns.Options.Write(module, key, value) end
	end, keys)
	if ns.Store.Module("Readability").preset ~= text then ns.Callbacks.Fire("ThemeChanged") end
	ns.DevTest.Log("Setup", "look " .. name)
	return true
end

function Looks.Controls()
	if Default(PAD_KEYS[1]) ~= nil then return Looks.Current(Looks.CONTROLS, PAD_KEYS) end
end

function Looks.ApplyControls(name)
	return Default(PAD_KEYS[1]) ~= nil and Looks.Apply(name, Looks.CONTROLS, PAD_KEYS)
end

Looks.SIZES = {
	{ value = "Pixel", label = L["Pixel perfect"], note = L["Sharp edges, sized for your screen. Pick it to go back."] },
	{ value = "Game", label = L["Game's UI scale"], note = L["Grows and shrinks with the UI Scale in the game's options, up to the largest size that fits."] },
}
Looks.SIZES_CUSTOM = { Looks.SIZES[1], Looks.SIZES[2], Looks.CUSTOM[4] }
Looks.SIZES_STATUS = { Looks.SIZES[1], Looks.SIZES[2], Looks.STATUS[4] }

function Looks.Size()
	if not ns.Store.IsLoaded() then return nil end
	if ns.Appearance.Get("uiScaleGame") then return "Game" end
	if ns.Appearance.Get("uiScaleAuto") then return "Pixel" end
end

function Looks.ApplySize(name)
	if not (Looks.Get(name, Looks.SIZES) and ns.Store.IsLoaded()) then return false end
	ns.Options.Write("Appearance", "uiScaleGame", name == "Game")
	if name == "Pixel" then ns.Options.Write("Appearance", "uiScaleAuto", true) end
	ns.DevTest.Log("Setup", "interface size " .. name)
	return true
end

function Looks.ControlsShown()
	return ns.Store.Module("Setup").controls and Default(PAD_KEYS[1]) ~= nil
end
