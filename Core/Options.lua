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
	segmented = "choice",
	color = "colour",
	font = "string",
	texture = "string",
	text = "string",
	pictures = "choice",
	order = "table",
}
local HEADER_FIELDS = { type = true, label = true, showWhen = true, disableWhen = true, scope = true }
local COMMON_FIELDS = { type = true, key = true, label = true, help = true, showWhen = true, disableWhen = true, scope = true }
local SCOPE_FIELDS = { key = true, value = true }
local EXTRA_FIELDS = {
	slider = { min = true, max = true, step = true, shown = true },
	dropdown = { options = true },
	segmented = { options = true },
	font = { options = true },
	color = { hasAlpha = true },
	text = { maxLetters = true },
	pictures = { options = true },
	order = { options = true },
}

local schemas, index, order = {}, {}, {}
local window

function Options.AuraFilterRows(schema, key, opts)
	opts = opts or {}
	local function add(row)
		row.key = key .. "." .. row.key
		row.disableWhen = opts.disableWhen
		schema[#schema + 1] = row
	end
	add({ type = "toggle", key = "onlyMine", label = L["Only yours"], help = L["Shows only auras you cast."] })
	add({ type = "toggle", key = "dispellable", label = L["Dispellable by you"], help = L["Shows only debuffs you can dispel; for buffs, only ones you can apply."] })
	add({ type = "text", key = "allowSpells", label = L["Allow spell IDs"], maxLetters = 240,
		help = L["Only these spell IDs, separated by commas or spaces. Blank allows any spell."] })
	add({ type = "text", key = "blockSpells", label = L["Block spell IDs"], maxLetters = 240,
		help = L["Hides these spell IDs, separated by commas or spaces. Blocking wins over allowing."] })
	add({ type = "dropdown", key = opts.sortKey or "sort", label = L["Sort by"], options = opts.sortOptions or {
		{ value = "", label = L["Current style"] }, { value = "time", label = L["Time left"] },
		{ value = "name", label = L["Name"] }, { value = "applied", label = L["Order applied"] },
	}, help = L["The order the icons are shown in."] })
end

function Options.AuraFilterString(settings, filter)
	if settings.onlyMine == true then filter = filter .. "|PLAYER" end
	if settings.dispellable == true and not ("|" .. filter .. "|"):find("|RAID|", 1, true) then
		filter = filter .. "|RAID"
	end
	return filter
end

local spellLists = {}
local function SpellList(value)
	if ns.Widgets.IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
	if spellLists[value] then return spellLists[value] end
	local ids = {}
	for token in value:gmatch("[^,%s]+") do
		if token:match("^%d+$") then
			local id = tonumber(token)
			if id and id > 0 and id < math.huge then ids[id] = true end
		end
	end
	spellLists[value] = ids
	return ids
end

function Options.AuraCandidates(settings, base)
	local allow, block = SpellList(settings.allowSpells), SpellList(settings.blockSpells)
	if not allow and not block then return base end
	local candidates = {}
	for key, value in pairs(base or {}) do candidates[key] = value end
	if allow then candidates.includeSpellIDs = allow end
	if block then
		local exclude = {}
		for id in pairs(candidates.excludeSpellIDs or {}) do exclude[id] = true end
		for id in pairs(block) do exclude[id] = true end
		candidates.excludeSpellIDs = exclude
	end
	return candidates
end

local AURA_SORT = { time = "ExpirationOnly", name = "NameOnly", applied = "AuraInstanceIDOnly" }
function Options.AuraSort(sort, method, direction)
	local enums = AuraContainerSortMethod
	return enums and enums[AURA_SORT[sort]] or method, direction
end

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

local function checkScope(module, scope, defaults)
	if type(scope) ~= "table" or scope.key == nil or scope.value == nil then
		return "scope must be { key = a top-level setting, value = the value that picks this row }"
	end
	for field in pairs(scope) do
		if not SCOPE_FIELDS[field] then
			return "scope must be { key = a top-level setting, value = the value that picks this row }, not " .. tostring(field)
		end
	end
	local parts = splitKey(scope.key)
	local default
	if parts and #parts == 1 then
		default = defaults[parts[1]]
	end
	if default == nil then
		return "scope.key must be a top-level setting with a default in " .. module .. "'s defaults, got " .. tostring(scope.key)
	end
	if type(default) == "table" or type(scope.value) ~= type(default) then
		return "scope.value must be a " .. type(default) .. " like the default of " .. scope.key .. ", got a " .. type(scope.value)
	end
end

local function checkOrder(row, value)
	if type(row.options) ~= "table" or #row.options == 0 then
		return "an order row needs options: a list of { value, label, rows }"
	end
	local ids = {}
	for _, option in ipairs(row.options) do
		if type(option) ~= "table" or type(option.value) ~= "string" or option.value == "" or ids[option.value]
			or type(option.label) ~= "string" or option.label == "" then
			return "order options need unique string values and labels"
		end
		ids[option.value] = true
		if option.rows ~= nil and type(option.rows) ~= "table" then return "order option rows must be a list of rows" end
	end
	if type(value) ~= "table" then return "an order value must be a list of { id, shown, zone }" end
	local count = 0
	for _ in pairs(value) do count = count + 1 end
	if count ~= #row.options then return "an order value must include every option once" end
	for _, entry in ipairs(value) do
		if type(entry) ~= "table" or not ids[entry.id] or type(entry.shown) ~= "boolean"
			or (entry.zone ~= "left" and entry.zone ~= "centre" and entry.zone ~= "right") then
			return "order entries need a unique option id, boolean shown and zone left, centre or right"
		end
		ids[entry.id] = nil
	end
	if next(ids) then return "an order value must be a list with no gaps" end
end

local function checkRow(module, row, defaults)
	if type(row) ~= "table" then
		return "is not a table"
	end
	local rowType = row.type
	local plain = rowType == "header" or rowType == "note"
	if not plain and not VALUE_TYPES[rowType] then
		return "unknown type " .. tostring(rowType)
	end
	for field in pairs(row) do
		if plain then
			if field == "key" then
				return "a " .. rowType .. " row takes no key"
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
	if row.scope ~= nil then
		local problem = checkScope(module, row.scope, defaults)
		if problem then
			return problem
		end
	end
	if plain then
		return nil
	end
	local parts = splitKey(row.key)
	if not parts then
		return "needs a key: a setting name, with dots for nested settings"
	end
	if type(row.help) ~= "string" or row.help == "" then
		return "needs help: one short sentence"
	end
	if #row.help >= MAX_HELP and not ns.Locale.IsTranslation(row.help) then
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
		local painted = default
		if row.shown ~= nil then
			if type(row.shown) ~= "function" then
				return "shown must be a function that returns the value the slider paints for a stored value"
			end
			local ok, value = pcall(row.shown, default)
			if not ok or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
				return "shown(default) must return a finite number"
			end
			painted = value
		end
		if painted < row.min or painted > row.max then
			return (row.shown and "the painted default " or "the default ") .. painted .. " is outside the slider's range"
		end
	elseif rowType == "order" then
		return checkOrder(row, default)
	elseif rowType == "dropdown" then
		return checkDropdown(row, default)
	elseif rowType == "segmented" then
		if type(row.options) ~= "table" then
			return "a segmented row needs options: a list of { value, label }"
		end
		return checkDropdown(row, default)
	elseif rowType == "pictures" then
		if type(row.options) ~= "table" then
			return "a pictures row needs options: a list of { value, label, picture }"
		end
		for i, option in ipairs(row.options) do
			if type(option) == "table" and (type(option.picture) ~= "string" or option.picture == "") then
				return "option " .. i .. " needs a picture: a texture path"
			end
		end
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

local function checkSchema(module, schema, defaults)
	if type(schema) ~= "table" then
		error("KstyleUI.Options.Register(" .. module .. "): the schema must be a list of rows", 2)
	end
	local preview = schema.preview
	if preview ~= nil and type(preview) ~= "function" then
		error("KstyleUI.Options.Register(" .. module .. "): preview must be a function(parent) that builds the module's live preview", 2)
	end
	local count = 0
	for key in pairs(schema) do
		if key ~= "preview" then
			count = count + 1
		end
	end
	if count ~= #schema then
		error("KstyleUI.Options.Register(" .. module .. "): the schema must be a list of rows with no gaps", 2)
	end
	local byKey = {}
	local function registerRow(row, i)
		local problem = checkRow(module, row, defaults)
		if not problem and row.type ~= "header" and row.type ~= "note" then
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
		if row.type == "order" then
			for _, option in ipairs(row.options) do
				for _, child in ipairs(option.rows or {}) do registerRow(child, i) end
			end
		end
	end
	for i, row in ipairs(schema) do registerRow(row, i) end
	return byKey
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
	if type(schema) ~= "function" then
		index[module] = checkSchema(module, schema, defaults)
	end
	schemas[module] = schema
	order[#order + 1] = module
end

function Options.Get(module)
	local schema = schemas[module]
	if type(schema) == "function" then
		schema = schema()
		index[module] = checkSchema(module, schema, ns.Store.Defaults(module))
		schemas[module] = schema
	end
	return schema
end

function Options.Preview(module)
	local schema = Options.Get(module)
	return schema and schema.preview
end

function Options.Row(module, key)
	Options.Get(module)
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

function Options.Default(module, key)
	local _, default = locate("Default", module, key)
	return copy(default)
end

local function Equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

Options.Copy, Options.Equal = copy, Equal

function Options.IsChanged(module, key)
	return not Equal(Options.Read(module, key), Options.Default(module, key))
end

function Options.BindKeys()
	local fn = SlashCmdList and SlashCmdList.KSTYLEKB
	if type(fn) == "function" then return fn() end
	ns.Print(L["Enable KstyleUI action bars with keyboard controls to use /kb."])
	return false
end

function Options.Write(module, key, value)
	local parts, default = locate("Write", module, key)
	if type(value) ~= type(default) then
		error("KstyleUI.Options.Write: " .. module .. "." .. key .. " must be a " .. type(default) .. ", got " .. type(value), 2)
	end
	local row = Options.Row(module, key)
	if row and row.type == "order" then
		local problem = checkOrder(row, value)
		if problem then error("KstyleUI.Options.Write: " .. problem, 2) end
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

ns.Store.RegisterDefaults("OptionControls", { numericInput = true, changedSettings = true })
Options.Register("OptionControls", function() return {
	{ type = "header", label = L["Settings controls"] },
	{ type = "toggle", key = "numericInput", label = L["Type slider values"], help = L["Click a slider value to type a number. Off keeps the slider and its readout."] },
	{ type = "toggle", key = "changedSettings", label = L["Changed settings and quick reset"], help = L["Marks changed rows with a diamond and lets right-click reset them. Off keeps the usual rows."] },
} end)
