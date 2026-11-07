-- Options.lua: the settings schemas modules declare, which the settings window builds its pages from.
local _, ns = ...

local Options = {}
ns.Options = Options

local L = ns.L
local format = string.format
local MAX_HELP = 100
local OPTIONS_ADDON = "KstyleUI_Options"

local VALUE_TYPES = {
	toggle = "boolean",
	slider = "number",
	dropdown = "choice",
	color = "colour",
	font = "string",
	texture = "string",
	text = "string",
}
local HEADER_FIELDS = { type = true, label = true, showWhen = true, disableWhen = true }
local COMMON_FIELDS = { type = true, key = true, label = true, help = true, showWhen = true, disableWhen = true }
local EXTRA_FIELDS = {
	slider = { min = true, max = true, step = true },
	dropdown = { options = true },
	color = { hasAlpha = true },
	text = { maxLetters = true },
}

local schemas, index, order = {}, {}, {}
local window

local function splitKey(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local parts = {}
	for part in (key .. "."):gmatch("([^%.]*)%.") do
		if not part:match("^[%a_][%w_]*$") then
			return nil
		end
		parts[#parts + 1] = part
	end
	return parts
end

local function lookup(root, parts)
	local node = root
	for i = 1, #parts do
		if type(node) ~= "table" then
			return nil
		end
		node = node[parts[i]]
	end
	return node
end

local function checkDropdown(row, default)
	local options = row.options
	if type(options) == "function" then
		return nil
	end
	if type(options) ~= "table" or #options == 0 then
		return "a dropdown needs options: a list of { value, label }, or a function that returns one"
	end
	local found = false
	for i, option in ipairs(options) do
		if type(option) ~= "table" or (type(option.value) ~= "string" and type(option.value) ~= "number") then
			return "option " .. i .. " needs a string or number value"
		end
		if type(option.label) ~= "string" or option.label == "" then
			return "option " .. i .. " needs a label"
		end
		found = found or option.value == default
	end
	if not found then
		return "the default " .. tostring(default) .. " is not one of the options"
	end
end

local function checkValueType(row, default)
	local kind = VALUE_TYPES[row.type]
	if kind == "colour" then
		if type(default) ~= "table" or type(default.r) ~= "number" or type(default.g) ~= "number" or type(default.b) ~= "number" then
			return "a color row needs a colour table default with r, g and b, but " .. row.key .. " defaults to a " .. type(default)
		end
	elseif kind == "choice" then
		if type(default) ~= "string" and type(default) ~= "number" then
			return "a dropdown needs a string or number default, but " .. row.key .. " defaults to a " .. type(default)
		end
	elseif type(default) ~= kind then
		return "a " .. row.type .. " row needs a " .. kind .. " default, but " .. row.key .. " defaults to a " .. type(default)
	end
end

local function checkRow(module, row, defaults)
	if type(row) ~= "table" then
		return "is not a table"
	end
	local rowType = row.type
	if rowType ~= "header" and not VALUE_TYPES[rowType] then
		return "unknown type " .. tostring(rowType)
	end
	for field in pairs(row) do
		if rowType == "header" then
			if field == "key" then
				return "a header row takes no key"
			elseif not HEADER_FIELDS[field] then
				return "unknown field " .. tostring(field)
			end
		elseif not COMMON_FIELDS[field] and not (EXTRA_FIELDS[rowType] and EXTRA_FIELDS[rowType][field]) then
			return "unknown field " .. tostring(field)
		end
	end
	if type(row.label) ~= "string" or row.label == "" then
		return "needs a label"
	end
	for _, field in ipairs({ "showWhen", "disableWhen" }) do
		if row[field] ~= nil and type(row[field]) ~= "function" then
			return field .. " must be a function(settings) that returns true or false"
		end
	end
	if rowType == "header" then
		return nil
	end
	local parts = splitKey(row.key)
	if not parts then
		return "needs a key: a setting name, with dots for nested settings"
	end
	if type(row.help) ~= "string" or row.help == "" then
		return "needs help: one short sentence"
	end
	if #row.help >= MAX_HELP then
		return "help must be under 100 characters"
	end
	local default = lookup(defaults, parts)
	if default == nil then
		return "key " .. row.key .. " has no default in " .. module .. "'s defaults"
	end
	local problem = checkValueType(row, default)
	if problem then
		return problem
	end
	if rowType == "slider" then
		if type(row.min) ~= "number" or type(row.max) ~= "number" then
			return "a slider needs numeric min and max"
		end
		if row.min >= row.max then
			return "a slider's min must be below its max"
		end
		if type(row.step) ~= "number" or row.step <= 0 then
			return "a slider needs a step above 0"
		end
		if default < row.min or default > row.max then
			return "the default " .. default .. " is outside the slider's range"
		end
	elseif rowType == "dropdown" then
		return checkDropdown(row, default)
	elseif rowType == "color" then
		if row.hasAlpha ~= nil and type(row.hasAlpha) ~= "boolean" then
			return "hasAlpha must be true or false"
		end
	elseif rowType == "text" then
		local max = row.maxLetters
		if max ~= nil and (type(max) ~= "number" or max < 1 or max ~= math.floor(max)) then
			return "maxLetters must be a whole number above 0"
		end
	end
end

function Options.Register(module, schema)
	if type(module) ~= "string" or module == "" then
		error("KstyleUI.Options.Register: module must be a name, got " .. tostring(module), 2)
	end
	if schemas[module] then
		error("KstyleUI.Options.Register: " .. module .. " is already registered", 2)
	end
	local defaults = ns.Store.Defaults(module)
	if not defaults then
		error("KstyleUI.Options.Register: register " .. module .. "'s defaults first, with Modules.Register or Store.RegisterDefaults", 2)
	end
	if type(schema) ~= "table" then
		error("KstyleUI.Options.Register(" .. module .. "): the schema must be a list of rows", 2)
	end
	local count = 0
	for _ in pairs(schema) do
		count = count + 1
	end
	if count ~= #schema then
		error("KstyleUI.Options.Register(" .. module .. "): the schema must be a list of rows with no gaps", 2)
	end
	local byKey = {}
	for i, row in ipairs(schema) do
		local problem = checkRow(module, row, defaults)
		if not problem and row.type ~= "header" then
			if byKey[row.key] then
				problem = "the key " .. row.key .. " appears twice"
			else
				byKey[row.key] = row
			end
		end
		if problem then
			local key = type(row) == "table" and type(row.key) == "string" and (" (" .. row.key .. ")") or ""
			error(format("KstyleUI.Options.Register(%s): row %d%s: %s", module, i, key, problem), 2)
		end
	end
	schemas[module] = schema
	index[module] = byKey
	order[#order + 1] = module
end

function Options.Get(module)
	return schemas[module]
end

function Options.Row(module, key)
	local rows = index[module]
	return rows and rows[key]
end

function Options.List()
	local names = {}
	for i, name in ipairs(order) do
		names[i] = name
	end
	return names
end

local function locate(fnName, module, key)
	local parts = splitKey(key)
	local defaults = ns.Store.Defaults(module)
	local default = parts and defaults and lookup(defaults, parts)
	if default == nil then
		error("KstyleUI.Options." .. fnName .. ": " .. tostring(module) .. " has no default for " .. tostring(key), 3)
	end
	return parts, default
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = copy(v)
	end
	return out
end

function Options.Read(module, key)
	local parts = locate("Read", module, key)
	return lookup(ns.Store.Module(module), parts)
end

function Options.Write(module, key, value)
	local parts, default = locate("Write", module, key)
	if type(value) ~= type(default) then
		error("KstyleUI.Options.Write: " .. module .. "." .. key .. " must be a " .. type(default) .. ", got " .. type(value), 2)
	end
	if key == "enabled" and ns.Features.modules[module] ~= nil then
		if value then
			ns.Modules.Enable(module)
		else
			ns.Modules.Disable(module)
		end
	else
		local node = ns.Store.Module(module)
		for i = 1, #parts - 1 do
			local child = node[parts[i]]
			if type(child) ~= "table" then
				child = {}
				node[parts[i]] = child
			end
			node = child
		end
		node[parts[#parts]] = copy(value)
	end
	ns.Callbacks.Fire("SettingChanged", module, key, value)
end

function Options.SetWindow(show)
	if type(show) ~= "function" then
		error("KstyleUI.Options.SetWindow: show must be a function(page), got " .. type(show), 2)
	end
	window = show
end

function Options.Open(page)
	if not window then
		local AddOns = C_AddOns
		if not (AddOns and AddOns.LoadAddOn) then
			ns.Print(L["The settings window is not available on this client."])
			ns.DevTest.Log("Options", "Open: C_AddOns.LoadAddOn is missing")
			return false
		end
		local ok, loaded, reason = pcall(AddOns.LoadAddOn, OPTIONS_ADDON)
		if not ok or not loaded then
			local why = tostring(ok and reason or loaded)
			ns.Print(format(L["The settings window could not load: %s."], why))
			ns.DevTest.Log("Options", "Open: LoadAddOn(" .. OPTIONS_ADDON .. ") failed: " .. why)
			return false
		end
	end
	if not window then
		ns.Print(L["The settings window is not available yet."])
		ns.DevTest.Log("Options", "Open: " .. OPTIONS_ADDON .. " loaded but did not call Options.SetWindow")
		return false
	end
	ns.Call(window, page)
	return true
end
