-- Rules.lua: the per-spell rules the settings' spell lists name (spell IDs, or names in any case, separated by commas), matched once per entry or spell and kept until the settings change.
local _, ns = ...

local Rules = {}
ns.Rules = Rules

local EMPTY = {}
Rules.EMPTY = EMPTY
local parsed, bySpell, any = {}, {}, {}
local stamp = 0

local function Parse(text)
	local set = parsed[text]
	if set then return set end
	set = {}
	for token in text:gmatch("[^,]+") do
		token = token:match("^%s*(.-)%s*$")
		if token:match("^[%d%s]+$") then
			for id in token:gmatch("%d+") do set[tonumber(id)] = true end
		elseif token ~= "" then
			set[token:lower()] = true
		end
	end
	parsed[text] = set
	return set
end

local function Name(spell)
	local api = C_Spell
	if ns.IsSecret(spell) or type(spell) ~= "number" or not (api and api.GetSpellName) then return nil end
	local ok, name = pcall(api.GetSpellName, spell)
	if ok and not ns.IsSecret(name) and type(name) == "string" then return name:lower() end
	return nil
end

local function Build(a, b, c)
	local rules, out, names = ns.Settings.current.rules, nil, nil
	for _, key in ipairs(ns.Settings.RULES) do
		if any[key] then
			local set = Parse(rules[key])
			local hit = set[a] or set[b] or set[c]
			if not hit then
				names = names or { Name(a) or false, Name(b) or false }
				hit = set[names[1]] or set[names[2]]
			end
			if hit then
				out = out or {}
				out[key] = true
			end
		end
	end
	return out or EMPTY
end

function Rules.Reset()
	stamp = stamp + 1
	for spell in pairs(bySpell) do bySpell[spell] = nil end
	local rules = ns.Settings.current.rules
	for _, key in ipairs(ns.Settings.RULES) do any[key] = rules[key] ~= "" end
end

function Rules.Any(key)
	return any[key] == true
end

function Rules.For(entry)
	if not entry then return EMPTY end
	if entry.ruleStamp ~= stamp then
		entry.rule, entry.ruleStamp = Build(entry.spell, entry.spellID, entry.overrideSpellID), stamp
	end
	return entry.rule
end

function Rules.ForSpell(spell)
	if ns.IsSecret(spell) or type(spell) ~= "number" then return EMPTY end
	local rule = bySpell[spell]
	if not rule then
		rule = Build(spell)
		bySpell[spell] = rule
	end
	return rule
end
