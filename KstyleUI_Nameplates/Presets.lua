-- Presets.lua: the nameplate presets one dropdown applies, each a set of this module's settings, and the rule that a hand-changed setting turns the preset to Custom.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Settings = ns.Settings
local MODULE = Settings.MODULE

local Presets = { applying = false }
ns.Presets = Presets

Presets.LIST = {
	{ value = "lumen", label = L["Lumen: the defaults"] },
	{ value = "compact", label = L["Compact: a dense pull"] },
	{ value = "tank", label = L["Tank: threat on the bar"] },
	{ value = "healer", label = L["Healer: friendly bars with health"] },
	{ value = "custom", label = L["Custom"] },
}

Presets.VALUES = {
	lumen = {},
	compact = {
		["name.size"] = 12, ["level.size"] = 14, ["healthText.show"] = false,
		["cast.height"] = 10, ["cast.textSize"] = 9,
		["debuffs.size"] = 22, ["debuffs.textSize"] = 11,
		["target.dimOthers"] = 0.7, shrinkDistant = true, ["friendly.nameOnly"] = true,
	},
	tank = {
		["threat.display"] = "health", ["threat.role"] = "tank", ["threat.groupOnly"] = false,
		["types.caster"] = true, ["healthText.show"] = true, ["healthText.format"] = "percent",
		["target.dimOthers"] = 0.85,
	},
	healer = {
		["friendly.nameOnly"] = false, ["friendly.colorSource"] = "class", ["healthText.show"] = true,
		["healthText.format"] = "percent", ["cast.height"] = 14, ["threat.display"] = "glow",
		["threat.role"] = "other", ["target.dimOthers"] = 0.8,
	},
}

local function lookup(root, key)
	local node = root
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local touched = {}
for name, values in pairs(Presets.VALUES) do
	if name ~= "lumen" then
		for key in pairs(values) do
			touched[key] = true
		end
	end
end

local function Write(key, value)
	if type(value) == "table" then
		value = { r = value.r, g = value.g, b = value.b }
	end
	K.Options.Write(MODULE, key, value)
end

function Presets.Apply(name)
	local values = Presets.VALUES[name]
	if not values or Presets.applying then
		return false
	end
	Presets.applying = true
	for key in pairs(touched) do
		local value = values[key]
		if value == nil then
			value = lookup(Settings.defaults, key)
		end
		Write(key, value)
	end
	if name == "lumen" then
		for key in pairs(Settings.rows) do
			if key ~= "preset" and not touched[key] and not key:find("^cvars%.") then
				Write(key, lookup(Settings.defaults, key))
			end
		end
	end
	Presets.applying = false
	K.DevTest.Log(MODULE, "applied the " .. name .. " preset")
	return true
end

function Presets.OnSetting(_, module, key)
	if module ~= MODULE or Presets.applying or type(key) ~= "string" then
		return
	end
	Settings.Invalidate()
	if key == "preset" then
		local name = Settings.Get("preset")
		if name ~= "custom" then
			Presets.Apply(name)
		end
	elseif key ~= "enabled" and not key:find("^cvars%.") and Settings.Get("preset") ~= "custom" then
		K.Options.Write(MODULE, "preset", "custom")
	end
	Settings.Invalidate()
end

K.Callbacks.Register("SettingChanged", MODULE .. "Presets", Presets.OnSetting)
