-- Looks.lua: one-click Looks, each a named set of existing settings (Readable also raises every text size below its readable size and lowers none); Forged is the shipped look and the way back, and the current Look is read from those settings, never saved.
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

local function Each(look, fn)
	for _, path in ipairs(KEYS) do
		local module, key = path:match("^(%a+)%.(.+)$")
		if ns.Store.Defaults(module) then
			local value = look.set[path]
			if value == nil then value = ns.Options.Default(module, key) end
			fn(module, key, value)
		end
	end
	for _, module in ipairs(ns.Modules.List()) do
		local defaults = ns.Store.Defaults(module)
		if defaults then Sizes(module, defaults, "", look.set["Readability.preset"] == "Readable", fn) end
	end
end

function Looks.Get(name)
	for _, look in ipairs(Looks.LIST) do
		if look.value == name then return look end
	end
end

function Looks.Current()
	if not ns.Store.IsLoaded() then return nil end
	for _, look in ipairs(Looks.LIST) do
		local match = true
		Each(look, function(module, key, value)
			match = match and ns.Options.Equal(ns.Options.Read(module, key), value)
		end)
		if match then return look.value end
	end
end

function Looks.Apply(name)
	local look = Looks.Get(name)
	if not look or not ns.Store.IsLoaded() then return false end
	local text = ns.Store.Module("Readability").preset
	Each(look, function(module, key, value)
		if not ns.Options.Equal(ns.Options.Read(module, key), value) then ns.Options.Write(module, key, value) end
	end)
	if ns.Store.Module("Readability").preset ~= text then ns.Callbacks.Fire("ThemeChanged") end
	ns.DevTest.Log("Setup", "look " .. name)
	return true
end
