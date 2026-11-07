-- Module.lua: registers KstyleUI_Skins with the core: one switch per window, each skin's own settings, the shared look and the preview.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Skins, Style = ns.Skins, ns.Style

local MODULE = "Skins"

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Copy(v)
	end
	return out
end

local function WindowOn(key)
	return function(settings)
		local section = settings[key]
		return type(section) == "table" and section.enabled == true
	end
end

local function Scoped(key, condition, whenOff)
	if condition == nil then
		return nil
	end
	return function(settings)
		local section = settings[key]
		if type(section) ~= "table" then
			return whenOff
		end
		return condition(section)
	end
end

local function SkinRow(def, row)
	local copy = {}
	for field, value in pairs(row) do
		copy[field] = value
	end
	if row.type ~= "header" then
		copy.key = def.key .. "." .. tostring(row.key)
	end
	local on = WindowOn(def.key)
	local shown = Scoped(def.key, row.showWhen, false)
	copy.showWhen = function(settings)
		return on(settings) and (shown == nil or shown(settings))
	end
	copy.disableWhen = Scoped(def.key, row.disableWhen, true)
	return copy
end

local defaults = { enabled = false }
for group, values in pairs(Style.defaults) do
	defaults[group] = Copy(values)
end

local schema = { { type = "header", label = L["Windows"] } }
for _, def in ipairs(Skins.List()) do
	local section = Copy(def.defaults or {})
	section.enabled = true
	defaults[def.key] = section
	schema[#schema + 1] = { type = "toggle", key = def.key .. ".enabled", label = def.label, help = def.help }
end
for _, def in ipairs(Skins.List()) do
	if def.rows then
		schema[#schema + 1] = { type = "header", label = def.label, showWhen = WindowOn(def.key) }
		for _, row in ipairs(def.rows) do
			schema[#schema + 1] = SkinRow(def, row)
		end
	end
end
for _, row in ipairs(Style.rows) do
	schema[#schema + 1] = row
end
schema.preview = ns.Preview.Build

Skins.Close()

K.Modules.Register({
	name = MODULE,
	defaults = defaults,
	reskin = true,
	Enable = function()
		Skins.Start()
	end,
	Disable = function()
		Skins.Stop()
	end,
})
K.Options.Register(MODULE, schema)
