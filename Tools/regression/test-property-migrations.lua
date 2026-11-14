-- test-property-migrations.lua: random saved data (missing keys, wrong types, damaged profiles and layouts, any saved version) loads through repair and every migration without an error, ends at the current schema version (newer data keeps its version), loads again to the same saved data, and each migration run a second time on its own output changes nothing.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Property = dofile("Tools/regression/property_lib.lua")

local DeepCopy, DeepEqual = CoreEnv.DeepCopy, CoreEnv.DeepEqual

local probe, PK = CoreEnv.New({})
CoreEnv.Boot(probe)
local Store, Layouts = PK.Store, PK.Setup.Layouts
local DB_VERSION = Store.DB_VERSION

-- The words each migration reads: the names, strings and numbers in Store.lua from the end of the migration before it to its own
-- end, so the tables it reads (PLATE_V20 and the like) count; the layouts also use the element keys and their Orbs keys.
local REGIONS, ALL = {}
do
	local handle = assert(io.open("Core/Store.lua", "rb"))
	local source = handle:read("*a"):gsub("\r", "")
	handle:close()
	local function Words(text)
		local words, seen = { keys = {}, strings = {}, numbers = {}, sections = {} }, {}
		local function Add(list, value)
			seen[list] = seen[list] or {}
			if value ~= nil and not seen[list][value] then
				seen[list][value] = true
				list[#list + 1] = value
			end
		end
		for name in text:gmatch("[%.:]([%a_][%w_]*)") do
			Add(name:match("^%u%l") and words.sections or words.keys, name)
		end
		for name in text:gmatch("([%a_][%w_]*)%s*=[^=]") do
			Add(words.keys, name)
		end
		for literal in text:gmatch('"([^"\n]*)"') do
			Add(words.strings, literal)
			if literal:match("^[%a_][%w_.:]*$") then
				Add(words.keys, literal)
			end
		end
		for number in text:gmatch("[^%w_.](%d+%.?%d*)") do
			Add(words.numbers, tonumber(number))
		end
		local alias = {}
		for name, field in text:gmatch("local%s+([%a_][%w_]*)%s*=[^\n]-[%.:]([%a_][%w_]*)[%s%)]*\n") do
			alias[name] = field
		end
		words.children = {}
		for parent, child in text:gmatch("([%a_][%w_]*)%.([%a_][%w_]*)") do
			for _, owner in ipairs({ parent, alias[parent] }) do
				words.children[owner] = words.children[owner] or {}
				Add(words.children[owner], child)
			end
		end
		words.elements, words.modules = {}, {}
		for _, element in ipairs(Layouts.ELEMENTS) do
			Add(words.elements, element.key)
			Add(words.elements, "orbs:" .. element.key)
			Add(words.modules, element.module)
		end
		if #words.sections == 0 then
			words.sections = words.modules
		end
		return words
	end
	local last = 1
	for version, finish in source:gmatch("\nStore%.migrations%[(%d+)%] = function%(data%)\n.-\nend()\n") do
		REGIONS[#REGIONS + 1] = { version = tonumber(version), words = Words(source:sub(last, finish)) }
		last = finish
	end
	ALL = Words(source)
	assert(#REGIONS >= 30, "found the migrations in Core/Store.lua, got " .. #REGIONS)
end
local ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local Value

local W

local function Number(g)
	if g:bool(0.6) then
		return g:pick(W.numbers) * (g:bool(0.15) and -1 or 1)
	end
	return g:bool(0.5) and g:int(-50, 2000) or g:float(-1000, 1000)
end

-- Table(g, depth, parent) prefers the keys the migrations read under a field of that name: bars.xp, then xp.segments.
local function Table(g, depth, parent)
	local t = {}
	local children = parent and W.children[parent]
	if g:bool(0.15) then
		return { r = g:float(0, 1), g = g:float(0, 1), b = g:float(0, 1), a = g:bool(0.5) and g:float(0, 1) or nil }
	end
	for _ = 1, g:int(0, 8) do
		local key = children and g:bool(0.7) and g:pick(children) or g:bool(0.85) and g:pick(W.keys) or (g:bool(0.5) and g:int(1, 4) or g:pick(W.strings))
		t[key] = Value(g, depth + 1, key)
	end
	return t
end

function Value(g, depth, key)
	if depth <= 2 and g:bool(W.children[key] and 0.7 or 0.4) then
		return Table(g, depth, key)
	end
	local kind = g:int(1, 10)
	if kind <= 2 then
		return g:bool(0.5)
	elseif kind <= 7 then
		return Number(g)
	end
	return g:bool(0.8) and g:pick(W.strings) or g:pick(ANCHORS)
end

local function Junk(g)
	return g:pick({ true, 7, "oops", 0.5 })
end

local function Profile(g)
	if g:bool(0.05) then
		return Junk(g)
	end
	local profile = {}
	for _ = 1, g:int(0, 10) do
		local section = g:pick(g:bool(0.8) and W.sections or W.modules)
		profile[section] = g:bool(0.9) and Table(g, 1, section) or Junk(g)
	end
	return profile
end

local function Layout(g)
	if g:bool(0.05) then
		return Junk(g)
	end
	local layout = {}
	for _ = 1, g:int(0, 8) do
		local entry = {}
		if g:bool(0.8) then
			entry.anchor = g:bool(0.9) and g:pick(ANCHORS) or Junk(g)
			entry.x, entry.y = Number(g), g:bool(0.9) and Number(g) or Junk(g)
		end
		for _, field in ipairs({ "width", "height", "scale", "shown", "alphaCombat", "strata" }) do
			if g:bool(0.2) then
				entry[field] = Value(g, 3)
			end
		end
		layout[g:bool(0.97) and g:pick(g:bool(0.7) and W.elements or W.keys) or g:int(1, 3)] = g:bool(0.95) and entry or Junk(g)
	end
	return layout
end

local function Saved(g, words)
	W = words
	if g:bool(0.03) then
		return { saved = Junk(g) }
	end
	local names = { "Default", "Raid", "Alt" }
	local db = { profiles = {}, layouts = {}, characters = {}, account = Table(g, 1) }
	local version = g:int(1, DB_VERSION)
	if g:bool(0.1) then
		version = g:pick({ 0, -3, 2.5, "12", DB_VERSION + 1, DB_VERSION + 3 })
	elseif g:bool(0.05) then
		version = nil
	end
	db.version = version
	for _ = 1, g:int(0, 3) do
		local name = g:bool(0.95) and g:pick(names) or g:int(1, 3)
		db.profiles[name] = Profile(g)
		if g:bool(0.8) then
			db.layouts[name] = Layout(g)
		end
	end
	db.characters["Realm-Tester"] = g:bool(0.8) and g:pick(names) or Junk(g)
	for _, field in ipairs({ "profiles", "layouts", "characters", "account" }) do
		if g:bool(0.04) then
			db[field] = Junk(g)
		elseif g:bool(0.04) then
			db[field] = nil
		end
	end
	return db
end

-- A case is saved data for the whole load, aimed at one migration's words or at all of Store.lua one time in five, and for each
-- migration its own saved data, aimed at its words, to run it twice.
local function Generate(g)
	local c = { saved = Saved(g, g:bool(0.2) and ALL or g:pick(REGIONS).words), steps = {} }
	for _, region in ipairs(REGIONS) do
		c.steps[region.version] = Saved(g, region.words)
	end
	return c
end

local function Load(saved)
	local env, K = CoreEnv.New({ saved = DeepCopy(saved) })
	CoreEnv.Boot(env)
	CoreEnv.Logout(env)
	return env, K
end

local function Stored(env)
	local copy = DeepCopy(env.KstyleUIDB)
	copy.devlog = nil
	return copy
end

-- Repaired(saved) -> a copy in the shape Store's repair gives the migrations: its tables are tables, and only string-named profiles
-- and layouts that are tables are kept.
local function Repaired(saved)
	local data = DeepCopy(saved)
	for _, field in ipairs({ "profiles", "layouts", "characters", "account" }) do
		if type(data[field]) ~= "table" then
			data[field] = {}
		end
	end
	for name, profile in pairs(data.profiles) do
		if type(name) ~= "string" or type(profile) ~= "table" then
			data.profiles[name] = nil
		end
	end
	for name, layout in pairs(data.layouts) do
		if type(layout) ~= "table" then
			data.layouts[name] = nil
		end
	end
	return data
end

-- KeyError(message) -> true for the error migrations 30 and 32 raise on a non-string layout key (LEE-1462).
local function KeyError(message)
	return (message:find("Store.lua:792:", 1, true) or message:find("Store.lua:828:", 1, true)) ~= nil and message:find("attempt to index local 'key' (a number value)", 1, true) ~= nil
end

local function Holds(c)
	local out = {}
	local function Fail(text, ...)
		out[#out + 1] = string.format(text, ...)
	end
	local env, K = Load(c.saved)
	for _, message in ipairs(env._errors) do
		c.keyError = c.keyError or KeyError(message)
		Fail("loading raised: %s", tostring(message))
	end
	local db = env.KstyleUIDB
	local from = type(c.saved) == "table" and c.saved.version
	local newer = type(from) == "number" and from > DB_VERSION and from == math.floor(from)
	if type(db) ~= "table" or db.version ~= (newer and from or DB_VERSION) then
		Fail("saved version %s loads as %s, not %s", tostring(from), tostring(type(db) == "table" and db.version), tostring(newer and from or DB_VERSION))
	end
	if type(K.Store.Profile()) ~= "table" then
		Fail("no active profile after loading")
	end
	local first = Stored(env)
	local again = Load(first)
	for _, message in ipairs(again._errors) do
		Fail("loading the saved data again raised: %s", tostring(message))
	end
	local same, where = DeepEqual(Stored(again), first)
	if not same then
		Fail("loading the saved data again changed it at %s", tostring(where))
	end
	for version = 2, DB_VERSION do
		local step = Store.migrations[version]
		if step and c.steps[version] then
			local data = Repaired(type(c.steps[version]) == "table" and c.steps[version] or {})
			local ok, err = pcall(step, data)
			if not ok then
				Fail("migration %d raised on its own: %s", version, tostring(err))
			else
				local once = DeepCopy(data)
				ok, err = pcall(step, data)
				local twice, at = DeepEqual(data, once)
				if not ok then
					Fail("migration %d raised on its own output: %s", version, tostring(err))
				elseif not twice then
					Fail("migration %d run again changed its own output at %s", version, tostring(at))
				end
			end
		end
	end
	return #out == 0, out
end

Property.Check({
	name = "store migrations",
	script = "Tools/regression/test-property-migrations.lua",
	iterations = 80,
	generate = Generate,
	show = function(c)
		return Property.Describe(c.saved) .. " (each migration's own data comes from the same seed and case)"
	end,
	property = Holds,
	known = {
		{
			issue = "LEE-1462", why = "migrations 30 and 32 index a non-string layout key; Linear LEE-5749",
			match = function(c, why)
				local version = why:match("^migration (%d+) raised on its own: ")
				if version then
					return (version == "30" or version == "32") and KeyError(why)
				end
				if why:find("^loading raised: ") or why:find("^loading the saved data again raised: ") then
					return KeyError(why)
				end
				return c.keyError == true and why:find("^saved version .- loads as ") ~= nil
			end,
		},
	},
})
