-- Looks.lua: one-click Looks, each a named set of existing settings; Forged is the shipped look and the way back, and the current Look is read from those settings, never saved.
local _, ns = ...

local L = ns.L
local Looks = {}
ns.Setup.Looks = Looks

local KEYS = { "Widgets.ornaments", "Widgets.cardMaterial", "Widgets.panelOpacity", "Medallions.motion", "Medallions.ambient", "Appearance.motion", "Appearance.outline" }
Looks.LIST = {
	{ value = "Forged", label = L["Forged"], note = L["The look KstyleUI ships with: forged trim, full motion and the usual text. Pick it to go back."], set = {} },
	{ value = "Clean", label = L["Clean"], note = L["Plain glass without trim, lighter panels, a still hub and calm motion."], set = {
		["Widgets.ornaments"] = "Off", ["Widgets.cardMaterial"] = "Glass", ["Widgets.panelOpacity"] = 0.65,
		["Medallions.motion"] = "calm", ["Medallions.ambient"] = false, ["Appearance.motion"] = "reduced",
	} },
	{ value = "Readable", label = L["Readable"], note = L["Larger text with a soft shadow on solid slate panels and subtle trim."], text = "Readable", set = {
		["Widgets.ornaments"] = "Subtle", ["Widgets.cardMaterial"] = "Slate", ["Widgets.panelOpacity"] = 0.92, ["Appearance.outline"] = "SHADOW",
	} },
}

local function Each(look, fn)
	for _, path in ipairs(KEYS) do
		local module, key = path:match("^(%a+)%.(.+)$")
		if ns.Store.Defaults(module) then
			local value = look.set[path]
			if value == nil then value = ns.Options.Default(module, key) end
			fn(module, key, value)
		end
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
		local match = ns.Store.Module("Readability").preset == (look.text or "Standard")
		Each(look, function(module, key, value)
			match = match and ns.Options.Equal(ns.Options.Read(module, key), value)
		end)
		if match then return look.value end
	end
end

function Looks.Apply(name)
	local look = Looks.Get(name)
	if not look or not ns.Store.IsLoaded() then return false end
	Each(look, function(module, key, value)
		if not ns.Options.Equal(ns.Options.Read(module, key), value) then ns.Options.Write(module, key, value) end
	end)
	if ns.Store.Module("Readability").preset ~= (look.text or "Standard") then ns.Profiles.Readable(look.text or "Standard") end
	ns.DevTest.Log("Setup", "look " .. name)
	return true
end
