-- Rules.lua: the per-spell rules the settings' spell lists name (spell IDs, or names in any case, separated by commas; a spell may carry its own colour, "Fireball #FF8000", its own bar name, "Fireball=Fire", its own tenths threshold, "Fireball=5", or its talent, "Shred=Feral Instinct"), matched once per entry or spell and kept until the settings change, and whether a named talent is known, kept until the spells change; the preview takes each list's first colour, name or threshold.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local EMPTY = {}
Rules.EMPTY = EMPTY
local parsed, samples, bySpell, known = {}, {}, {}, {}
local stamp = 0

local function Hex(hex, from)
	return tonumber(hex:sub(from, from + 1), 16) / 255
end

local function Parse(text)
	local set, first = {}, nil
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
		first = first or value ~= true and value or nil
	end
	return set, first
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
	bySpell, known = {}, {}
	local rules = ns.Settings.current.rules
	for _, key in ipairs(ns.Settings.RULES) do
		parsed[key], samples[key] = nil, nil
		if rules[key] ~= "" then parsed[key], samples[key] = Parse(rules[key]) end
	end
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

function Rules.Forget()
	known = {}
end

function Rules.Known(talent)
	local hit = known[talent]
	if hit == nil then
		local book, api, id = C_SpellBook, C_Spell, tonumber(talent)
		hit = true
		if book and type(book.IsSpellKnown) == "function" then
			if not id and api and type(api.GetSpellIDForSpellIdentifier) == "function" then
				local got, found = pcall(api.GetSpellIDForSpellIdentifier, talent)
				if got and not ns.IsSecret(found) then id, hit = found, found ~= nil end
			end
			if id then
				local ok, on = pcall(book.IsSpellKnown, id)
				hit = not ok or ns.IsSecret(on) or on == true
			end
		end
		known[talent] = hit
	end
	return hit
end

function Rules.Sample(key)
	return parsed[key] and (samples[key] or true) or nil
end

function Rules.Colour(value, key)
	if type(value) == "table" then return value[1], value[2], value[3] end
	return ns.Settings.SourceColor(key)
end
