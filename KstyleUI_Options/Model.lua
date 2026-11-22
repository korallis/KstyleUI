-- Model.lua: the settings window's rows as data: schema binding, showWhen and disableWhen, section pruning and search.
local _, ns = ...

local K = KstyleUI
local Model = {}
ns.Model = Model

local lower, find, gmatch = string.lower, string.find, string.gmatch

local logged = {}

function Model.Log(message)
	K.DevTest.Log("Options", message)
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Model.Log(message)
	end
end

function Model.Check(fn, settings, what)
	local ok, result = pcall(fn, settings)
	if not ok then
		LogOnce(tostring(what) .. tostring(result), tostring(what) .. " failed: " .. tostring(result))
		return nil
	end
	return result and true or false
end

local function Settings(item)
	local fn = item.settings
	if fn then
		local ok, settings = pcall(fn)
		if ok then
			return settings
		end
	end
	return nil
end

local function Scoped(settings, scope)
	if type(settings) ~= "table" or type(scope) ~= "table" or scope.key == nil then
		return settings
	end
	return setmetatable({ [scope.key] = scope.value }, { __index = settings })
end

function Model.IsShown(item, searching)
	if not item.showWhen then
		return true
	end
	local settings = Settings(item)
	if searching and item.scope then
		settings = Scoped(settings, item.scope)
	end
	return Model.Check(item.showWhen, settings, "showWhen of " .. tostring(item.label)) ~= false
end

function Model.IsDisabled(item)
	if item.disabled then
		return true
	end
	if not item.disableWhen then
		return false
	end
	return Model.Check(item.disableWhen, Settings(item), "disableWhen of " .. tostring(item.label)) == true
end

local function Level(item)
	return item.kind == "header" and (item.level or 1) or nil
end

function Model.Visible(items, searching)
	local shown = {}
	local hideBelow
	for i, item in ipairs(items) do
		local level = Level(item)
		if hideBelow and level and level <= hideBelow then
			hideBelow = nil
		end
		if hideBelow then
			shown[i] = false
		elseif Model.IsShown(item, searching) then
			shown[i] = true
		else
			shown[i] = false
			hideBelow = level
		end
	end
	local out = {}
	for i, item in ipairs(items) do
		local level = Level(item)
		local keep = shown[i]
		if keep and level then
			keep = false
			for j = i + 1, #items do
				local below = Level(items[j])
				if below and below <= level then
					break
				end
				if not below and shown[j] then
					keep = true
					break
				end
			end
		end
		if keep then
			out[#out + 1] = item
		end
	end
	return out
end

function Model.Sections(items)
	local out = {}
	for i, item in ipairs(items) do
		if Level(item) == 1 then
			out[#out + 1] = { label = item.label, index = i }
		end
	end
	return out
end

function Model.Terms(query)
	local terms = {}
	if type(query) == "string" then
		for term in gmatch(lower(query), "%S+") do
			terms[#terms + 1] = term
		end
	end
	return terms
end

function Model.Matches(text, terms)
	local haystack = lower(text or "")
	for _, term in ipairs(terms) do
		if not find(haystack, term, 1, true) then
			return false
		end
	end
	return true
end

function Model.PageItems(page)
	if page.items then
		return page.items
	end
	if page.Items then
		local ok, items = K.Call(page.Items, page)
		if ok and type(items) == "table" then
			return items
		end
	end
	return {}
end

local MAX_LEVEL = 3

local SYNONYMS = {
	{ "HudStyle", "style", K.L["change hud look style frames medallions portraits"] },
	{ "Readability", "preset", K.L["readable text bigger letters tiny small hard to read"] },
	{ "Appearance", "fontScale", K.L["readable text bigger letters tiny small hard to read"] },
	{ "GroupFrames", "auto.role", K.L["choose role tank healer dps damage"] },
	{ "GroupFrames", "clickCast.hint", K.L["healing clicks heal mouse click casting spells"] },
	{ "ActionBars", "bindingHints", K.L["bind keys keybind hotkeys keyboard shortcuts"] },
	{ "Integrations", "notices", K.L["existing addons other addons elvui bartender plater bigwigs dbm weakauras"] },
	{ "Nameplates", "cast.", K.L["make kicks obvious interrupt kick enemy spell casts"] },
}

local function Synonyms(item)
	if not K.Store.Module("OptionsPresentation").synonyms then return "" end
	for _, entry in ipairs(SYNONYMS) do
		if item.module == entry[1] and type(item.key) == "string" and item.key:sub(1, #entry[2]) == entry[2] then
			return "\n" .. entry[3]
		end
	end
	return ""
end

local function SectionText(sections)
	local parts = {}
	for level = 1, MAX_LEVEL do
		if sections[level] then
			parts[#parts + 1] = sections[level]
		end
	end
	return table.concat(parts, " / ")
end

function Model.Search(pages, query)
	local terms = Model.Terms(query)
	if #terms == 0 then
		return nil
	end
	local out = {}
	for _, page in ipairs(pages) do
		local sections = {}
		local pageShown, lastSection
		for _, item in ipairs(page.id ~= "Tasks" and Model.Visible(Model.PageItems(page), true) or {}) do
			local level = Level(item)
			if level then
				sections[level] = item.label
				for deeper = level + 1, MAX_LEVEL do
					sections[deeper] = nil
				end
			else
				local section = SectionText(sections)
				local text = page.label .. "\n" .. section .. "\n" .. tostring(item.label) .. "\n" .. tostring(item.help or "") .. Synonyms(item)
				if Model.Matches(text, terms) then
					if not pageShown then
						pageShown = true
						out[#out + 1] = { kind = "header", level = 1, label = page.label, page = page.id }
					end
					if section ~= "" and section ~= lastSection then
						out[#out + 1] = { kind = "header", level = 2, label = section, page = page.id }
					end
					lastSection = section
					item.page = item.page or page.id
					out[#out + 1] = item
				end
			end
		end
	end
	return out
end

function Model.Lookup(root, key)
	local node = root
	for part in gmatch(key, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

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
Model.Copy = Copy

local FIELDS = { "min", "max", "step", "shown", "options", "hasAlpha", "maxLetters", "scope", "pin" }

local function OrderItems(item, row)
	local out, options = {}, {}
	for _, option in ipairs(row.options) do options[option.value] = option end
	for _, value in ipairs(item.get() or {}) do
		local id, option = value.id, options[value.id]
		if option then
			local entry = {}
			for field, current in pairs(item) do entry[field] = current end
			entry.label, entry.help, entry.entry = option.label, nil, id
			local function locate(list)
				for i, current in ipairs(list) do if current.id == id then return i end end
			end
			entry.get = function()
				local list = item.get()
				local at = locate(list)
				return at and list[at]
			end
			entry.set = function(patch)
				local list = Copy(item.get())
				local at = locate(list)
				if not at then return end
				for field, changed in pairs(patch) do list[at][field] = changed end
				item.set(list)
			end
			entry.position = function()
				local list = item.get()
				return locate(list), #list
			end
			entry.move = function(delta)
				local list = Copy(item.get())
				local at = locate(list)
				if not at or at + delta < 1 or at + delta > #list then return end
				list[at], list[at + delta] = list[at + delta], list[at]
				item.set(list)
			end
			out[#out + 1] = entry
			for _, child in ipairs(Model.SchemaItems(item.module, option.rows, item.page)) do
				local showWhen = child.showWhen
				child.showWhen = function(settings)
					local current = entry.get()
					return Model.IsShown(entry) and current and current.shown and (not showWhen or showWhen(settings))
				end
				out[#out + 1] = child
			end
		end
	end
	return out
end

function Model.SchemaItems(module, schema, page)
	local items = {}
	local function settings()
		return K.Store.Module(module)
	end
	for _, row in ipairs(schema or {}) do
		local item = {
			kind = row.type, label = row.label, help = row.help, page = page, module = module, key = row.key,
			showWhen = row.showWhen, disableWhen = row.disableWhen, settings = settings,
		}
		for _, field in ipairs(FIELDS) do
			item[field] = row[field]
		end
		if row.key then
			local key = row.key
			item.get = function()
				return K.Options.Read(module, key)
			end
			item.set = function(value)
				K.Options.Write(module, key, value)
			end
		end
		if row.type == "order" then
			for _, entry in ipairs(OrderItems(item, row)) do items[#items + 1] = entry end
		else
			items[#items + 1] = item
		end
	end
	return items
end

function Model.ResetSchema(module, schema)
	local defaults = K.Store.Defaults(module)
	if not defaults then
		return 0
	end
	local count = 0
	for _, row in ipairs(schema or {}) do
		if row.type == "order" then
			for _, option in ipairs(row.options) do count = count + Model.ResetSchema(module, option.rows) end
		end
		if row.key and row.key ~= "enabled" then
			local default = Model.Lookup(defaults, row.key)
			if default ~= nil then
				K.Call(K.Options.Write, module, row.key, Copy(default))
				count = count + 1
			end
		end
	end
	return count
end
