-- Store.lua: SavedVariables, profiles, defaults, migrations, export and import.
local addonName, ns = ...

local Store = {}
ns.Store = Store

local L = ns.L
local Codec = ns.Codec
local format, sub, floor = string.format, string.sub, math.floor

Store.DB_VERSION = 15
Store.migrations = {}

Store.migrations[2] = function(data)
	for _, profile in pairs(data.profiles) do
		local appearance = type(profile) == "table" and profile.Appearance
		if type(appearance) == "table" and appearance.reducedMotion ~= nil then
			if appearance.motion == nil and appearance.reducedMotion == true then
				appearance.motion = "off"
			end
			appearance.reducedMotion = nil
		end
	end
end

Store.migrations[3] = function(data)
	for _, profile in pairs(data.profiles) do
		if type(profile) == "table" then
			profile.Icons = nil
			profile.IconsColour = nil
		end
	end
end

local MENU_DEFAULTS = {
	micro = { size = 26, spacing = 4, rows = 1, backdrop = true, tint = "none", shape = "round", set = "compact" },
	bags = { size = 26, spacing = 4, rows = 1, backdrop = true, freeSlots = true, shape = "round" },
}

local function tunedMenu(bar, defaults)
	for key, default in pairs(defaults) do
		if bar[key] ~= nil and bar[key] ~= default then
			return true
		end
	end
	return false
end

Store.migrations[4] = function(data)
	for _, profile in pairs(data.profiles) do
		local databars = type(profile) == "table" and profile.DataBars
		if type(databars) == "table" then
			local free = type(databars.strip) == "table" and databars.strip.menus == false
			for id, defaults in pairs(MENU_DEFAULTS) do
				local bar = databars[id]
				if bar == nil and free then
					databars[id] = { shown = true }
				elseif type(bar) == "table" and bar.shown == nil and bar.enabled ~= false and (free or tunedMenu(bar, defaults)) then
					bar.shown = true
				end
			end
		end
	end
end

local SET_UP_MODULES = {
	"UnitFrames", "GroupFrames", "ActionBars", "Cooldowns", "Auras", "Nameplates", "CombatText",
	"Minimap", "Chat", "Bags", "Tooltips", "DataBars", "Meters", "Skins",
}

local function setUp(profile)
	for _, name in ipairs(SET_UP_MODULES) do
		local section = profile[name]
		if type(section) == "table" and section.enabled == true then
			return true
		end
	end
	return false
end

Store.migrations[5] = function(data)
	for _, profile in pairs(data.profiles) do
		if type(profile) == "table" and setUp(profile) then
			local qol = profile.QoL
			if qol == nil then
				profile.QoL = { enabled = true }
			elseif type(qol) == "table" and qol.enabled == nil then
				qol.enabled = true
			end
		end
	end
end

Store.migrations[6] = function(data)
	for _, profile in pairs(data.profiles) do
		local minimap = type(profile) == "table" and profile.Minimap
		if type(minimap) == "table" then
			minimap.compass = nil
			if type(minimap.coords) == "table" then
				minimap.coords.position = nil
			end
		end
	end
	if type(data.layouts) == "table" then
		for _, layout in pairs(data.layouts) do
			local entry = type(layout) == "table" and layout["minimap.main"]
			if type(entry) == "table" then
				entry.width, entry.height = nil, nil
			end
		end
	end
end

Store.migrations[7] = function(data)
	local layouts = ns.Setup and ns.Setup.Layouts
	if not (layouts and type(layouts.Upgrade) == "function") then
		return
	end
	for name, layout in pairs(data.layouts) do
		local profile = type(data.profiles[name]) == "table" and data.profiles[name] or {}
		local section = type(profile.Layout) == "table" and profile.Layout or {}
		local appearance = type(profile.Appearance) == "table" and profile.Appearance or {}
		local size = appearance.uiScale
		if type(size) ~= "number" or size ~= size or size <= 0 then
			size = ns.Appearance.defaults.uiScale
		end
		layouts.Upgrade(layout, section.preset or "DPS", 1080 / size)
	end
end

Store.migrations[8] = function(data)
	for _, profile in pairs(data.profiles) do
		local auras = type(profile) == "table" and profile.Auras
		if type(auras) == "table" then
			auras.card = nil
			local buffs = auras.buffs
			if type(buffs) == "table" and buffs.rows == 1 then
				buffs.rows = nil
			end
			local debuffs = auras.debuffs
			if type(debuffs) == "table" then
				debuffs.dispelFirst = nil
			end
		end
	end
end

local CHAT_CARD = "chat.main"
local CHAT_V9 = {
	{ width = 372, height = 260, toWidth = 393, toHeight = 200 },
	{ width = 318, height = 260, toWidth = 318, toHeight = 200 },
}

Store.migrations[10] = function(data)
	for _, layout in pairs(type(data.layouts) == "table" and data.layouts or {}) do
		local entry = type(layout) == "table" and layout[CHAT_CARD]
		if type(entry) == "table" then
			for _, old in ipairs(CHAT_V9) do
				if entry.width == old.width and entry.height == old.height then
					entry.width, entry.height = old.toWidth, old.toHeight
				end
			end
		end
	end
end

local RAIL_CARDS = { "meters.damage", "meters.threat" }
local RAIL_CARD_V8 = { anchor = "TOPRIGHT", x = -28, y = -236 }

Store.migrations[9] = function(data)
	for _, layout in pairs(data.layouts) do
		for _, key in ipairs(type(layout) == "table" and RAIL_CARDS or {}) do
			local entry = layout[key]
			if type(entry) == "table" and (entry.anchor ~= nil or entry.x ~= nil or entry.y ~= nil) then
				entry.anchor = entry.anchor == nil and RAIL_CARD_V8.anchor or entry.anchor
				entry.x = entry.x == nil and RAIL_CARD_V8.x or entry.x
				entry.y = entry.y == nil and RAIL_CARD_V8.y or entry.y
			end
		end
	end
end

Store.migrations[11] = function(data)
	local layouts = ns.Setup and ns.Setup.Layouts
	if not (layouts and layouts.UpgradeCentre) then
		return
	end
	for name, layout in pairs(data.layouts) do
		local profile = type(data.profiles[name]) == "table" and data.profiles[name] or {}
		local appearance = type(profile.Appearance) == "table" and profile.Appearance or {}
		local size = appearance.uiScale
		if type(size) ~= "number" or size ~= size or size <= 0 then
			size = ns.Appearance.defaults.uiScale
		end
		layouts.UpgradeCentre(layout, 1080 / size)
	end
	local defaults = {
		UnitFrames = {
			player = { style = "lumen", healthColor = "class", castbarColor = "class", castbarCaps = false, powerHeight = 5 },
			target = { style = "lumen", healthColor = "reaction", castbarCaps = false, castbarIcon = true, healthOrientation = "RIGHT", powerOrientation = "RIGHT", auraSpacing = 2, auraSize = 28, auraColumns = 14, auraPosition = "CENTER" },
		},
		ActionBars = { bar1 = { size = 38, spacing = 3 }, bar2 = { enabled = false, size = 38, spacing = 3, showEmpty = false } },
		Cooldowns = { essential = { size = 38, spacing = 3, timerSize = 13, countSize = 11, readyGlow = true }, buffs = { size = 38, spacing = 3, growth = "center", timerSize = 12, countSize = 10 } },
		DataBars = { xp = { text = "percentRested", border = true } },
	}
	for _, profile in pairs(data.profiles) do
		for module, groups in pairs(defaults) do
			local section = type(profile) == "table" and profile[module]
			for group, fields in pairs(type(section) == "table" and groups or {}) do
				local values = section[group]
				if type(values) == "table" and (module ~= "UnitFrames" or values.style == nil or values.style == "lumen") then
					if module == "UnitFrames" then
						local texture = ns.Tokens.MediaList("statusbar")[1].path
						for _, key in ipairs({ "healthTexture", "powerTexture" }) do
							if values[key] == texture then
								values[key] = nil
							end
						end
						local fonts = values.fonts
						if type(fonts) == "table" then
							if type(fonts.name) == "table" and fonts.name.size == 17 then
								fonts.name.size = nil
							end
							if group == "target" and type(fonts.health) == "table" and fonts.health.size == 12 then
								fonts.health.size = nil
							end
							if group == "target" and type(fonts.cast) == "table" and fonts.cast.size == 13 then
								fonts.cast.size = nil
							end
						end
					end
					for key, value in pairs(fields) do
						if values[key] == value then
							values[key] = nil
						end
					end
				end
			end
		end
		local bars = type(profile) == "table" and profile.DataBars
		local cooldowns = type(profile) == "table" and profile.Cooldowns
		if type(cooldowns) == "table" and cooldowns.accent == "class" then
			cooldowns.accent = nil
		end
		local xp = type(bars) == "table" and bars.xp
		local color = type(xp) == "table" and xp.restedColor
		local r, g, b = ns.Tokens.Color("rare")
		if type(color) == "table" and color.r == r and color.g == g and color.b == b and color.a == 0.5 then
			xp.restedColor = nil
		end
	end
end

local RAIL_V9 = {
	["minimap.main"] = { "TOPRIGHT", -28, -28, 160, 160 },
	["auras.buffs"] = { "TOPRIGHT", -204, -28, 282, 88 },
	["auras.debuffs"] = { "TOPRIGHT", -204, -132, 282, 88 },
	["meters.damage"] = { "BOTTOMRIGHT", -28, 162, 318, 190 },
	["meters.threat"] = { "BOTTOMRIGHT", -28, 162, 318, 144 },
	["databars.strip"] = { "BOTTOMRIGHT", -28, 28, 318 },
	["databars.micro"] = { "BOTTOMRIGHT", -28, 28 },
	["databars.bags"] = { "BOTTOMRIGHT", -28, 72 },
	["actionbars.bar4"] = { "RIGHT", -362, 0 },
	["actionbars.bar5"] = { "RIGHT", -403, 0 },
	["actionbars.bar6"] = { "RIGHT", -444, 0 },
	["tooltips.anchor"] = { "BOTTOMRIGHT", -28, 360 },
}
local RAIL_V8 = { "TOPRIGHT", -28, -236 }
local RAIL_BARS = { "bar4", "bar5" }

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.01
end

local function atPlace(entry, place)
	return place and entry.anchor == place[1] and near(entry.x, place[2]) and near(entry.y, place[3])
end

local function railEntry(entry, key, now, places)
	local old = places[key]
	local whole = {
		anchor = entry.anchor == nil and old[1] or entry.anchor,
		x = entry.x == nil and old[2] or entry.x,
		y = entry.y == nil and old[3] or entry.y,
	}
	local default = atPlace(whole, old) or atPlace(whole, now)
	if key == "meters.damage" or key == "meters.threat" then
		default = default or atPlace(whole, RAIL_V8)
	end
	if default then
		entry.anchor, entry.x, entry.y = nil, nil, nil
	else
		entry.anchor, entry.x, entry.y = whole.anchor, whole.x, whole.y
	end
	if old[4] and (entry.width == nil or near(entry.width, old[4])) and (entry.height == nil or old[5] == nil or near(entry.height, old[5])) then
		entry.width, entry.height = nil, nil
	end
end

Store.migrations[12] = function(data)
	local layouts = ns.Setup and ns.Setup.Layouts
	for name, layout in pairs(type(data.layouts) == "table" and data.layouts or {}) do
		local profile = type(data.profiles[name]) == "table" and data.profiles[name] or {}
		local section = type(profile.Layout) == "table" and profile.Layout or {}
		local preset = section.preset or "DPS"
		local current = layouts and type(layouts.Get) == "function" and layouts.Get(preset) or {}
		for key in pairs(type(layout) == "table" and RAIL_V9 or {}) do
			local entry = layout[key]
			if type(entry) == "table" and not (key == "meters.threat" and preset == "Tank") then
				local now = current[key]
				railEntry(entry, key, now and { now.anchor, now.x, now.y }, RAIL_V9)
				if next(entry) == nil then
					layout[key] = nil
				end
			end
		end
	end
	for _, profile in pairs(data.profiles) do
		local bars = type(profile) == "table" and profile.ActionBars
		for _, bar in ipairs(type(bars) == "table" and RAIL_BARS or {}) do
			if type(bars[bar]) == "table" and bars[bar].showEmpty == false then
				bars[bar].showEmpty = nil
			end
		end
	end
end

Store.migrations[13] = function(data)
	local oldWidth, oldHeight = 154, 12
	for _, layout in pairs(type(data.layouts) == "table" and data.layouts or {}) do
		local entry = type(layout) == "table" and layout["nameplates.plate"]
		if type(entry) == "table" then
			if entry.width == oldWidth then
				entry.width = nil
			end
			if entry.height == oldHeight then
				entry.height = nil
			end
			if next(entry) == nil then
				layout["nameplates.plate"] = nil
			end
		end
	end
end

Store.migrations[14] = function(data)
	for name, layout in pairs(type(data.layouts) == "table" and data.layouts or {}) do
		local profile = type(data.profiles[name]) == "table" and data.profiles[name] or {}
		local settings = type(profile.Layout) == "table" and profile.Layout or {}
		local entry = type(layout) == "table" and layout["meters.threat"]
		if settings.preset ~= "Tank" and type(entry) == "table" then
			local anchor = entry.anchor or "BOTTOMRIGHT"
			local x = entry.x == nil and -17 or entry.x
			local y = entry.y == nil and 17 or entry.y
			local width = entry.width == nil or near(entry.width, 269)
			local height = entry.height == nil or near(entry.height, 144)
			if anchor == "BOTTOMRIGHT" and near(x, -17) and near(y, 17) and width and height then
				entry.anchor, entry.x, entry.y, entry.width, entry.height = nil, nil, nil, nil, nil
			elseif entry.anchor ~= nil or entry.x ~= nil or entry.y ~= nil or not width or not height then
				entry.anchor, entry.x, entry.y = anchor, x, y
			end
			if next(entry) == nil then
				layout["meters.threat"] = nil
			end
		end
	end
end

local RAIL_V12 = {
	["auras.buffs"] = { "TOPRIGHT", -217, -17, 307, 42 },
	["auras.debuffs"] = { "TOPRIGHT", -217, -67, 307, 42 },
	["actionbars.bar4"] = { "BOTTOMRIGHT", -17, 203 },
	["actionbars.bar5"] = { "BOTTOMRIGHT", -58, 203 },
	["actionbars.bar6"] = { "BOTTOMRIGHT", -99, 203 },
	["databars.micro"] = { "BOTTOMRIGHT", -152, 203 },
	["databars.bags"] = { "BOTTOMRIGHT", -152, 247 },
	["tooltips.anchor"] = { "BOTTOMRIGHT", -152, 295 },
	["qol.lootfeed"] = { "BOTTOMLEFT", 17, 233 },
}
local CHAT_V12 = {
	{ width = 393, height = 200, toWidth = 393, toHeight = 186 },
	{ width = 318, height = 200, toWidth = 318, toHeight = 186 },
}
local AURA_V12 = { iconSize = 28, spacing = 3 }
local BAR_V12 = { size = 37, spacing = 4 }
local RAIL_BARS_V12 = { "bar4", "bar5", "bar6" }

Store.migrations[15] = function(data)
	local layouts = ns.Setup and ns.Setup.Layouts
	for name, layout in pairs(type(data.layouts) == "table" and data.layouts or {}) do
		local profile = type(data.profiles[name]) == "table" and data.profiles[name] or {}
		local section = type(profile.Layout) == "table" and profile.Layout or {}
		local current = layouts and type(layouts.Get) == "function" and layouts.Get(section.preset or "DPS") or {}
		for key in pairs(type(layout) == "table" and RAIL_V12 or {}) do
			local entry = layout[key]
			if type(entry) == "table" then
				local now = current[key]
				railEntry(entry, key, now and { now.anchor, now.x, now.y }, RAIL_V12)
				if next(entry) == nil then
					layout[key] = nil
				end
			end
		end
		local chat = type(layout) == "table" and layout[CHAT_CARD]
		if type(chat) == "table" and (chat.width ~= nil or chat.height ~= nil) then
			local width, height = chat.width, chat.height
			if width == nil then
				width = section.preset == "Healer" and CHAT_V12[2].width or CHAT_V12[1].width
			end
			if height == nil then
				height = CHAT_V12[1].height
			end
			chat.width, chat.height = width, height
			for _, old in ipairs(CHAT_V12) do
				if width == old.width and height == old.height then
					chat.width, chat.height = old.toWidth, old.toHeight
				end
			end
		end
	end
	for _, profile in pairs(data.profiles) do
		local auras = type(profile) == "table" and profile.Auras
		local bars = type(profile) == "table" and profile.ActionBars
		for _, bar in ipairs(type(bars) == "table" and RAIL_BARS_V12 or {}) do
			local values = bars[bar]
			for field, old in pairs(type(values) == "table" and BAR_V12 or {}) do
				if values[field] == old then
					values[field] = nil
				end
			end
		end
		for _, group in ipairs(type(auras) == "table" and { "buffs", "debuffs" } or {}) do
			local values = auras[group]
			for field, old in pairs(type(values) == "table" and AURA_V12 or {}) do
				if values[field] == old then
					values[field] = nil
				end
			end
		end
	end
end

local PREFIX = "KSUI1:"
local LUA_MAGIC = "KSL1:"
local KIND = "KstyleUI profile"
local DEFAULT_PROFILE = "Default"
local ZLIB = 1
local MAX_INPUT = 131072
local MAX_INFLATED = 2097152
local MAX_DEPTH = 12
local MAX_NODES = 20000
local MAX_STRING = 1024
local MAX_KEY = 64
local MAX_NAME = 48
local MAX_INTEGER_KEY = 2147483647
local FIELDS = { "profiles", "characters", "layouts", "account", "devlog" }
local PAYLOAD_FIELDS = { kind = true, version = true, name = true, settings = true, layout = true }
local ENCODING_FUNCTIONS = { "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }

local PASTE = L["Paste a KstyleUI profile string first."]
local NOT_OURS = L["This is not a KstyleUI profile string. KstyleUI profile strings start with KSUI1:."]
local NEWER = L["This profile comes from a newer version of KstyleUI. Update KstyleUI and try again."]
local DAMAGED = L["This profile string is damaged or incomplete. Copy the whole string and try again."]
local NOT_LOADED = L["KstyleUI has not loaded its saved settings yet."]

local db, active, activeName, account, charKey
local registered = {}
local implicit = {}
local logged = {}

local function log(message)
	local DevTest = ns.DevTest
	if DevTest and DevTest.Log then
		DevTest.Log("Store", message)
	end
end

local function logOnce(key, message)
	if not logged[key] then
		logged[key] = true
		log(message)
	end
end

local function isAtomic(t)
	return next(t) == nil or t[1] ~= nil
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function sectionDefaults(section)
	local defaults = registered[section]
	if defaults then
		return defaults
	end
	local switch = ns.Features.modules[section]
	if switch == nil then
		return nil
	end
	defaults = implicit[section]
	if not defaults then
		defaults = { enabled = switch }
		implicit[section] = defaults
	end
	return defaults
end

local function fill(dest, defaults)
	for key, default in pairs(defaults) do
		local value = dest[key]
		if type(default) == "table" then
			if isAtomic(default) then
				if type(value) ~= "table" then
					dest[key] = deepCopy(default)
				end
			else
				if type(value) ~= "table" then
					value = {}
					dest[key] = value
				end
				fill(value, default)
			end
		elseif type(value) ~= type(default) then
			dest[key] = default
		end
	end
end

local function strip(live, defaults)
	local out
	for key, value in pairs(live) do
		local default = defaults and defaults[key]
		local kept
		if type(value) == "table" then
			if type(default) == "table" and not isAtomic(default) then
				kept = strip(value, default)
			elseif type(default) == "table" then
				if not deepEqual(value, default) then
					kept = deepCopy(value)
				end
			elseif next(value) ~= nil then
				kept = deepCopy(value)
			end
		elseif value ~= default then
			kept = value
		end
		if kept ~= nil then
			out = out or {}
			out[key] = kept
		end
	end
	return out
end

local function stripProfile(profile)
	local out = {}
	for section, values in pairs(profile) do
		if type(values) == "table" then
			out[section] = strip(values, sectionDefaults(section))
		end
	end
	return out
end

local function fillSection(profile, section)
	local values = profile[section]
	if type(values) ~= "table" then
		values = {}
		profile[section] = values
	end
	local defaults = sectionDefaults(section)
	if defaults then
		fill(values, defaults)
	end
	return values
end

local function fillProfile(profile)
	for section in pairs(registered) do
		fillSection(profile, section)
	end
	for section in pairs(ns.Features.modules) do
		fillSection(profile, section)
	end
end

local function validName(name)
	if type(name) ~= "string" then
		return nil, L["A profile name must be text."]
	end
	local trimmed = name:match("^%s*(.-)%s*$")
	if trimmed == "" then
		return nil, L["A profile name cannot be empty."]
	end
	if #trimmed > MAX_NAME then
		return nil, format(L["A profile name must be %d characters or fewer."], MAX_NAME)
	end
	if trimmed:find("[%c|]") then
		return nil, L["A profile name cannot contain control characters or the | character."]
	end
	return trimmed
end

local function freeName(base)
	if not db.profiles[base] then
		return base
	end
	for i = 2, 999 do
		local suffix = " (" .. i .. ")"
		local name = sub(base, 1, MAX_NAME - #suffix) .. suffix
		if not db.profiles[name] then
			return name
		end
	end
	return base .. " " .. tostring(time and time() or 0)
end

local function resolveCharacter()
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then
		return nil
	end
	if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then
		return nil
	end
	return realm .. "-" .. name
end

local function upgrade(data, report)
	local target = Store.DB_VERSION
	for version = data.version + 1, target do
		local step = Store.migrations[version]
		if step ~= nil then
			local ok
			if type(step) ~= "function" then
				ok = false
			elseif report then
				ok = ns.Call(step, data)
			else
				ok = pcall(step, data)
			end
			if not ok then
				return false, version
			end
		end
		data.version = version
	end
	return true
end

local function repair(data)
	for _, field in ipairs(FIELDS) do
		if type(data[field]) ~= "table" then
			if data[field] ~= nil then
				log("replaced KstyleUIDB." .. field .. ", which was a " .. type(data[field]))
			end
			data[field] = {}
		end
	end
	for name, profile in pairs(data.profiles) do
		if type(name) ~= "string" or type(profile) ~= "table" then
			data.profiles[name] = nil
			log("dropped a damaged profile " .. tostring(name))
		end
	end
	for key, name in pairs(data.characters) do
		if type(key) ~= "string" or type(name) ~= "string" then
			data.characters[key] = nil
		end
	end
	for name, layout in pairs(data.layouts) do
		if type(layout) ~= "table" then
			data.layouts[name] = nil
		end
	end
	local version = data.version
	if type(version) ~= "number" or version < 1 or version ~= floor(version) then
		data.version = 1
	end
end

local function activate(name)
	local profile = db.profiles[name]
	if type(profile) ~= "table" then
		profile = {}
		db.profiles[name] = profile
	end
	if type(db.layouts[name]) ~= "table" then
		db.layouts[name] = {}
	end
	fillProfile(profile)
	active, activeName = profile, name
	if charKey then
		db.characters[charKey] = name
	end
end

local function load()
	local data = KstyleUIDB
	local fresh = type(data) ~= "table"
	if fresh then
		data = { version = Store.DB_VERSION }
		KstyleUIDB = data
	end
	repair(data)
	if data.version > Store.DB_VERSION then
		log("saved data is from a newer KstyleUI (version " .. data.version .. "); migrations skipped")
	elseif data.version < Store.DB_VERSION then
		local from = data.version
		local ok, failedAt = upgrade(data, true)
		if ok then
			log("migrated saved data from version " .. from .. " to " .. data.version)
		else
			log("migration to version " .. failedAt .. " failed; saved data stays at version " .. data.version)
		end
	end
	db = data
	account = data.account
	fill(account, ns.Features.account)
	charKey = resolveCharacter()
	local name = charKey and validName(db.characters[charKey]) or DEFAULT_PROFILE
	activate(name)
	log((fresh and "created saved data" or "loaded saved data") .. "; profile " .. name .. (charKey and "" or " (character not known yet)"))
end

local function login()
	if charKey or not db then
		return
	end
	charKey = resolveCharacter()
	if not charKey then
		log("character still unknown at PLAYER_LOGIN; profile assignment is not saved")
		return
	end
	local name = validName(db.characters[charKey])
	if name and name ~= activeName then
		Store.SetProfile(name)
	else
		db.characters[charKey] = activeName
	end
end

local function logout()
	if not db then
		return
	end
	for name, profile in pairs(db.profiles) do
		db.profiles[name] = stripProfile(profile)
	end
	db.account = strip(account, ns.Features.account) or {}
end

local function requireLoaded(fnName)
	if not db then
		error("KstyleUI.Store." .. fnName .. ": the saved settings load at ADDON_LOADED; read settings in Enable", 3)
	end
end

local function checkDefaults(value, path)
	for key, child in pairs(value) do
		local kt = type(key)
		if kt ~= "string" and kt ~= "number" then
			return path .. " has a " .. kt .. " key"
		end
		local ct = type(child)
		local childPath = path .. "." .. tostring(key)
		if ct == "table" then
			local problem = checkDefaults(child, childPath)
			if problem then
				return problem
			end
		elseif ct == "number" then
			if not Codec.IsFinite(child) then
				return childPath .. " is not a finite number"
			end
		elseif ct ~= "boolean" and ct ~= "string" then
			return childPath .. " is a " .. ct .. "; settings hold only booleans, numbers, strings and tables"
		end
	end
end

function Store.RegisterDefaults(section, defaults)
	if type(section) ~= "string" or not section:match("^%a[%w_]*$") then
		error("KstyleUI.Store.RegisterDefaults: section must be a name, got " .. tostring(section), 2)
	end
	if registered[section] then
		error("KstyleUI.Store.RegisterDefaults: " .. section .. " is already registered", 2)
	end
	if type(defaults) ~= "table" then
		error("KstyleUI.Store.RegisterDefaults: defaults for " .. section .. " must be a table", 2)
	end
	local switch = ns.Features.modules[section]
	if switch ~= nil and defaults.enabled ~= nil and defaults.enabled ~= switch then
		error("KstyleUI.Store.RegisterDefaults: " .. section .. " defaults.enabled must be " .. tostring(switch) .. ", its switch in Features.modules", 2)
	end
	local problem = checkDefaults(defaults, "defaults")
	if problem then
		error("KstyleUI.Store.RegisterDefaults: " .. section .. " " .. problem, 2)
	end
	local copy = deepCopy(defaults)
	if switch ~= nil then
		copy.enabled = switch
	end
	registered[section] = copy
	if active then
		fillSection(active, section)
	end
end

function Store.Defaults(section)
	return registered[section]
end

function Store.IsLoaded()
	return db ~= nil
end

function Store.Data()
	return db
end

function Store.Profile()
	requireLoaded("Profile")
	return active
end

function Store.Module(name)
	requireLoaded("Module")
	if not sectionDefaults(name) then
		error("KstyleUI.Store.Module: unknown settings section " .. tostring(name), 2)
	end
	local values = active[name]
	if type(values) ~= "table" then
		values = fillSection(active, name)
	end
	return values
end

function Store.Account()
	requireLoaded("Account")
	return account
end

function Store.Layout()
	requireLoaded("Layout")
	local layout = db.layouts[activeName]
	if type(layout) ~= "table" then
		layout = {}
		db.layouts[activeName] = layout
	end
	return layout
end

function Store.ProfileName()
	return activeName
end

function Store.ListProfiles()
	local names = {}
	if db then
		for name in pairs(db.profiles) do
			names[#names + 1] = name
		end
		table.sort(names)
	end
	return names
end

local function existing(name)
	local clean, err = validName(name)
	if not clean then
		return nil, err
	end
	if type(db.profiles[clean]) ~= "table" then
		return nil, format(L["There is no profile named %s."], clean)
	end
	return clean
end

function Store.SetProfile(name)
	if not db then
		return false, NOT_LOADED
	end
	local clean, err = validName(name)
	if not clean then
		return false, err
	end
	if clean == activeName then
		return true
	end
	local old = activeName
	activate(clean)
	ns.Callbacks.Fire("ProfileChanged", clean, old)
	return true
end

function Store.CreateProfile(name)
	if not db then
		return false, NOT_LOADED
	end
	local clean, err = validName(name)
	if not clean then
		return false, err
	end
	if db.profiles[clean] then
		return false, format(L["A profile named %s already exists."], clean)
	end
	db.profiles[clean] = {}
	db.layouts[clean] = {}
	return true, clean
end

function Store.CopyProfile(source, target)
	if not db then
		return false, NOT_LOADED
	end
	local from, err = existing(source)
	if not from then
		return false, err
	end
	local to
	to, err = validName(target)
	if not to then
		return false, err
	end
	if from == to then
		return true
	end
	db.profiles[to] = stripProfile(db.profiles[from])
	db.layouts[to] = deepCopy(db.layouts[from] or {})
	if to == activeName then
		activate(to)
		ns.Callbacks.Fire("ProfileChanged", to, to)
	end
	return true
end

function Store.RenameProfile(old, new)
	if not db then
		return false, NOT_LOADED
	end
	local from, err = existing(old)
	if not from then
		return false, err
	end
	local to
	to, err = validName(new)
	if not to then
		return false, err
	end
	if from == to then
		return true
	end
	if db.profiles[to] then
		return false, format(L["A profile named %s already exists."], to)
	end
	db.profiles[to], db.profiles[from] = db.profiles[from], nil
	db.layouts[to], db.layouts[from] = db.layouts[from] or {}, nil
	for key, name in pairs(db.characters) do
		if name == from then
			db.characters[key] = to
		end
	end
	if from == activeName then
		activeName = to
		ns.Callbacks.Fire("ProfileChanged", to, from)
	end
	return true
end

function Store.DeleteProfile(name)
	if not db then
		return false, NOT_LOADED
	end
	local clean, err = existing(name)
	if not clean then
		return false, err
	end
	if clean == activeName then
		return false, L["You cannot delete the active profile. Switch to another profile first."]
	end
	db.profiles[clean] = nil
	db.layouts[clean] = nil
	for key, assigned in pairs(db.characters) do
		if assigned == clean then
			db.characters[key] = nil
		end
	end
	return true
end

function Store.ResetProfile(name)
	if not db then
		return false, NOT_LOADED
	end
	local clean, err = existing(name or activeName)
	if not clean then
		return false, err
	end
	db.profiles[clean] = {}
	db.layouts[clean] = {}
	if clean == activeName then
		activate(clean)
		ns.Callbacks.Fire("ProfileChanged", clean, clean)
	end
	return true
end

function Store.CharacterKey()
	return charKey
end

function Store.Characters()
	local out = {}
	if db then
		for key, name in pairs(db.characters) do
			out[key] = name
		end
	end
	return out
end

function Store.AssignCharacter(key, name)
	if not db then
		return false, NOT_LOADED
	end
	if type(key) ~= "string" or (key ~= charKey and db.characters[key] == nil) then
		return false, format(L["KstyleUI does not know a character named %s."], tostring(key))
	end
	local clean, err = existing(name)
	if not clean then
		return false, err
	end
	if key == charKey then
		return Store.SetProfile(clean)
	end
	db.characters[key] = clean
	return true
end

local function encoding()
	local api = C_EncodingUtil
	if type(api) ~= "table" then
		return nil, "C_EncodingUtil is missing"
	end
	for _, fnName in ipairs(ENCODING_FUNCTIONS) do
		if type(api[fnName]) ~= "function" then
			return nil, "C_EncodingUtil." .. fnName .. " is missing"
		end
	end
	return api
end

local function zlib()
	local methods = Enum and Enum.CompressionMethod
	return methods and methods.Zlib or ZLIB
end

local function encodeCBOR(payload)
	local api, missing = encoding()
	if not api then
		return nil, missing
	end
	local ok, cbor = pcall(api.SerializeCBOR, payload)
	if not ok or type(cbor) ~= "string" then
		return nil, "SerializeCBOR failed: " .. tostring(cbor)
	end
	local packed
	ok, packed = pcall(api.CompressString, cbor, zlib())
	if not ok or type(packed) ~= "string" then
		return nil, "CompressString failed: " .. tostring(packed)
	end
	local encoded
	ok, encoded = pcall(api.EncodeBase64, packed)
	if not ok or type(encoded) ~= "string" then
		return nil, "EncodeBase64 failed: " .. tostring(encoded)
	end
	return encoded
end

local function encodeLua(payload)
	local ok, body = pcall(Codec.Serialize, payload)
	if not ok then
		return nil, tostring(body)
	end
	return Codec.EncodeBase64(LUA_MAGIC .. #body .. ":" .. Codec.Adler32(body) .. ":" .. body)
end

function Store.Export(name)
	if not db then
		return nil, NOT_LOADED
	end
	name = name or activeName
	local profile = db.profiles[name]
	if type(profile) ~= "table" then
		return nil, format(L["There is no profile named %s."], tostring(name))
	end
	local payload = {
		kind = KIND,
		version = Store.DB_VERSION,
		name = name,
		settings = stripProfile(profile),
		layout = deepCopy(db.layouts[name] or {}),
	}
	local text, why = encodeCBOR(payload)
	local path = "C_EncodingUtil"
	if not text then
		path = "Lua"
		local err
		text, err = encodeLua(payload)
		if not text then
			log("export failed: " .. tostring(err))
			return nil, L["This profile could not be exported."]
		end
		logOnce("export:Lua", "export via the Lua serializer (" .. tostring(why) .. ")")
	else
		logOnce("export:C_EncodingUtil", "export via C_EncodingUtil (CBOR, zlib, base64)")
	end
	return PREFIX .. text, path
end

local function readLua(raw)
	local length, checksum, start = raw:match("^KSL1:(%d+):(%d+):()")
	if not length or #length > 9 or #checksum > 10 then
		return nil, DAMAGED
	end
	local body = sub(raw, start)
	if #body ~= tonumber(length) or Codec.Adler32(body) ~= tonumber(checksum) then
		return nil, DAMAGED
	end
	local value = Codec.Deserialize(body)
	if value == nil then
		return nil, DAMAGED
	end
	return value
end

local function readCBOR(raw)
	if raw:byte(1) ~= 120 then
		return nil, DAMAGED
	end
	local api = encoding()
	if not api then
		return nil, L["This profile string was made with C_EncodingUtil, which this game client does not have."]
	end
	local ok, inflated = pcall(api.DecompressString, raw, zlib())
	if not ok or type(inflated) ~= "string" then
		return nil, DAMAGED
	end
	if #inflated > MAX_INFLATED then
		return nil, L["This profile string unpacks to something too large to be a KstyleUI profile."]
	end
	local value
	ok, value = pcall(api.DeserializeCBOR, inflated)
	if not ok or value == nil then
		return nil, DAMAGED
	end
	return value
end

local function decodeBase64(body)
	local api = encoding()
	if api then
		local ok, raw = pcall(api.DecodeBase64, body)
		if ok and type(raw) == "string" then
			return raw
		end
		logOnce("decode:Lua", "C_EncodingUtil.DecodeBase64 failed; decoding with Lua instead")
	end
	return Codec.DecodeBase64(body)
end

local function walk(value, path, depth, state)
	local t = type(value)
	if t == "table" then
		if depth > MAX_DEPTH then
			return format(L["The profile is nested too deeply at %s."], path)
		end
		for key, child in pairs(value) do
			state.nodes = state.nodes + 1
			if state.nodes > MAX_NODES then
				return L["The profile has too many values."]
			end
			local kt = type(key)
			local label
			if kt == "string" then
				if #key > MAX_KEY then
					return format(L["The profile has a key that is too long at %s."], path)
				end
				if key:find("[%c|]") then
					return format(L["The profile has a key with a control character at %s."], path)
				end
				label = path .. "." .. key
			elseif kt == "number" then
				if key ~= floor(key) or key < -MAX_INTEGER_KEY or key > MAX_INTEGER_KEY then
					return format(L["The profile has a key that is not a whole number at %s."], path)
				end
				label = path .. "[" .. key .. "]"
			else
				return format(L["The profile has a key that is not text or a number at %s."], path)
			end
			local problem = walk(child, label, depth + 1, state)
			if problem then
				return problem
			end
		end
	elseif t == "string" then
		if #value > MAX_STRING then
			return format(L["The profile has text that is too long at %s."], path)
		end
		if value:find("[%z\1-\8\11-\31\127]") then
			return format(L["The profile has a control character at %s."], path)
		end
	elseif t == "number" then
		if not Codec.IsFinite(value) then
			return format(L["The profile has a number that is not finite at %s."], path)
		end
	elseif t ~= "boolean" then
		return format(L["The profile has a value of type %s at %s."], t, path)
	end
end

local function checkRow(row, value, path)
	if row.type == "slider" then
		if value < row.min or value > row.max then
			return format(L["%s is out of range (%s to %s)."], path, tostring(row.min), tostring(row.max))
		end
	elseif row.type == "dropdown" then
		local options = row.options
		if type(options) == "function" then
			local ok, list = pcall(options)
			if not ok or type(list) ~= "table" then
				return format(L["%s could not be checked against its choices."], path)
			end
			options = list
		end
		if type(options) == "table" then
			for _, option in ipairs(options) do
				if type(option) == "table" and option.value == value then
					return nil
				end
			end
			return format(L["%s is not one of its choices."], path)
		end
	end
end

local function checkValue(value, default, section, path, key)
	if default == nil then
		return format(L["%s is not a setting KstyleUI knows."], path)
	end
	local dt, vt = type(default), type(value)
	if dt == "table" then
		if vt ~= "table" then
			return format(L["%s must be a table."], path)
		end
		if isAtomic(default) then
			return nil
		end
		for k, child in pairs(value) do
			if type(k) ~= "string" then
				return format(L["%s has a key that is not text."], path)
			end
			local problem = checkValue(child, default[k], section, path .. "." .. k, key == "" and k or key .. "." .. k)
			if problem then
				return problem
			end
		end
		return nil
	end
	if vt ~= dt then
		return format(L["%s must be a %s."], path, dt)
	end
	local Options = ns.Options
	local row = Options and Options.Row and Options.Row(section, key)
	if row then
		return checkRow(row, value, path)
	end
end

local function checkSettings(settings)
	for section, values in pairs(settings) do
		if type(section) ~= "string" then
			return L["The profile has settings under a name that is not text."]
		end
		if not sectionDefaults(section) then
			return format(L["The profile has settings for %s, which this KstyleUI does not know."], section)
		end
		if type(values) ~= "table" then
			return format(L["%s must be a table."], section)
		end
		local problem
		if registered[section] then
			problem = checkValue(values, registered[section], section, section, "")
		elseif values.enabled ~= nil and type(values.enabled) ~= "boolean" then
			problem = format(L["%s must be a %s."], section .. ".enabled", "boolean")
		end
		if problem then
			return problem
		end
	end
end

local function checkLayout(layout)
	for key, element in pairs(layout) do
		if type(key) ~= "string" then
			return L["The profile's layout has an element name that is not text."]
		end
		if type(element) ~= "table" then
			return format(L["The profile's layout entry %s is not a table."], key)
		end
	end
end

local function checkPayload(payload)
	if type(payload) ~= "table" or payload.kind ~= KIND then
		return nil, NOT_OURS
	end
	local problem = walk(payload, "profile", 1, { nodes = 0 })
	if problem then
		return nil, problem
	end
	for key in pairs(payload) do
		if not PAYLOAD_FIELDS[key] then
			return nil, format(L["The profile has an unexpected field: %s."], tostring(key))
		end
	end
	local version = payload.version
	if type(version) ~= "number" or version < 1 or version ~= floor(version) then
		return nil, L["The profile has no valid version number."]
	end
	if version > Store.DB_VERSION then
		return nil, NEWER
	end
	local name, nameErr = validName(payload.name)
	if not name then
		return nil, L["The profile's name is not valid: "] .. nameErr
	end
	if type(payload.settings) ~= "table" then
		return nil, L["The profile has no settings table."]
	end
	local layout = payload.layout
	if layout == nil then
		layout = {}
	elseif type(layout) ~= "table" then
		return nil, L["The profile's layout is not a table."]
	end
	local data = {
		version = version,
		profiles = { [name] = deepCopy(payload.settings) },
		layouts = { [name] = deepCopy(layout) },
		characters = {},
		account = {},
		devlog = {},
	}
	if not upgrade(data, false) or type(data.profiles[name]) ~= "table" or type(data.layouts[name]) ~= "table" then
		return nil, L["This profile comes from an older KstyleUI and could not be upgraded."]
	end
	problem = checkSettings(data.profiles[name]) or checkLayout(data.layouts[name])
	if problem then
		return nil, problem
	end
	return { kind = KIND, version = Store.DB_VERSION, name = name, settings = data.profiles[name], layout = data.layouts[name] }
end

function Store.Decode(text)
	if type(text) ~= "string" then
		return nil, PASTE
	end
	if #text > MAX_INPUT then
		return nil, L["This string is too long to be a KstyleUI profile."]
	end
	local compact = text:gsub("%s+", "")
	if compact == "" then
		return nil, PASTE
	end
	if sub(compact, 1, #PREFIX) ~= PREFIX then
		local version = tonumber(compact:match("^KSUI(%d+):") or "")
		if version and version > 1 then
			return nil, NEWER
		end
		return nil, NOT_OURS
	end
	local body = sub(compact, #PREFIX + 1)
	if body == "" or not Codec.IsBase64(body) then
		return nil, DAMAGED
	end
	local raw = decodeBase64(body)
	if not raw or raw == "" then
		return nil, DAMAGED
	end
	local payload, err
	if sub(raw, 1, #LUA_MAGIC) == LUA_MAGIC then
		payload, err = readLua(raw)
	else
		payload, err = readCBOR(raw)
	end
	if payload == nil then
		return nil, err
	end
	return checkPayload(payload)
end

function Store.Import(text, name)
	if not db then
		return false, NOT_LOADED
	end
	local payload, err = Store.Decode(text)
	if not payload then
		log("import rejected: " .. err)
		return false, err
	end
	local target = payload.name
	if name ~= nil then
		target, err = validName(name)
		if not target then
			return false, err
		end
	end
	target = freeName(target)
	db.profiles[target] = payload.settings
	db.layouts[target] = payload.layout
	Store.SetProfile(target)
	log("imported profile " .. target)
	return true, target
end

ns.Events.Register("Store", "ADDON_LOADED", function(_, name)
	if name == addonName then
		ns.Events.Unregister("Store", "ADDON_LOADED")
		load()
	end
end)
ns.Events.Register("Store", "PLAYER_LOGIN", function()
	ns.Events.Unregister("Store", "PLAYER_LOGIN")
	login()
end)
ns.Events.Register("Store", "PLAYER_LOGOUT", logout)
