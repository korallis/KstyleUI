-- Rules.lua: the per-spell rules the settings' spell lists name (spell IDs, or names in any case, separated by commas; a spell may carry its own colour, "Fireball #FF8000", or its own bar name, "Fireball=Fire"), matched once per entry or spell and kept until the settings change.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local EMPTY = {}
Rules.EMPTY = EMPTY
local parsed, bySpell = {}, {}
local stamp = 0

local function Hex(hex, from)
	return tonumber(hex:sub(from, from + 1), 16) / 255
end

local function Parse(text)
	local set = {}
	for token in text:gmatch("[^,]+") do
		local value = true
		local spell, label = token:match("^(.-)=%s*(.-)%s*$")
		local named, hex = token:match("^(.-)#(%x%x%x%x%x%x)%s*$")
		if spell and label ~= "" then
			token, value = spell, label
		elseif named then
			token, value = named, { Hex(hex, 1), Hex(hex, 3), Hex(hex, 5) }
		end
		token = token:match("^%s*(.-)%s*$")
		if token:match("^[%d%s]+$") then
			for id in token:gmatch("%d+") do set[tonumber(id)] = value end
		elseif token ~= "" then
			set[token] = value
		end
	end
	return set
end

local function Name(spell)
	local api = C_Spell
	if ns.IsSecret(spell) or type(spell) ~= "number" or not (api and api.GetSpellName) then return nil end
	local ok, name = pcall(api.GetSpellName, spell)
	if ok and not ns.IsSecret(name) and type(name) == "string" then return name end
end

local function Named(set, name)
	if not name then return false end
	for token, value in pairs(set) do
		if type(token) == "string" and (strcmputf8i and strcmputf8i(name, token) == 0 or name:lower() == token:lower()) then return value end
	end
	return false
end

local function Build(a, b)
	local out, names
	for _, key in ipairs(ns.Settings.RULES) do
		local set = parsed[key]
		if set then
			local hit = set[a] or set[b]
			if not hit then
				names = names or { Name(a) or false, Name(b) or false }
				hit = Named(set, names[1]) or Named(set, names[2])
			end
			if hit then
				out = out or {}
				out[key] = hit
			end
		end
	end
	return out or EMPTY
end

function Rules.Reset()
	stamp = stamp + 1
	bySpell = {}
	local rules = ns.Settings.current.rules
	for _, key in ipairs(ns.Settings.RULES) do parsed[key] = rules[key] ~= "" and Parse(rules[key]) or nil end
end

function Rules.For(entry)
	if not entry then return EMPTY end
	if entry.ruleStamp ~= stamp then
		entry.rule, entry.ruleStamp = Build(entry.spell, entry.spellID), stamp
	end
	return entry.rule
end

function Rules.ForSpell(spell)
	if ns.IsSecret(spell) or type(spell) ~= "number" then return EMPTY end
	if not bySpell[spell] then bySpell[spell] = Build(spell) end
	return bySpell[spell]
end

function Rules.Colour(value, key)
	if type(value) == "table" then return value[1], value[2], value[3] end
	return ns.Settings.SourceColor(key)
end
