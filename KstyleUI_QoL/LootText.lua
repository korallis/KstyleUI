-- LootText.lua: reads the player's own loot and money chat lines through the client's global strings, so every locale parses, and never touches a secret.
local _, ns = ...

local LootText = {}
ns.LootText = LootText

local COPPER_PER_SILVER, SILVER_PER_GOLD = 100, 100

local ITEM_KEYS = {
	"LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF",
	"LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
	"LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF",
	"LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", "LOOT_ITEM_BONUS_ROLL_SELF",
}
local MONEY_KEYS = { "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT" }
local AMOUNT_KEYS = { "GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT" }

local compiled = {}

local function Compile(format, anchored)
	local pattern, kinds, at, count = {}, {}, 1, 0
	if anchored then
		pattern[1] = "^"
	end
	while true do
		local start = format:find("%", at, true)
		if not start then
			pattern[#pattern + 1] = format:sub(at):gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
			break
		end
		pattern[#pattern + 1] = format:sub(at, start - 1):gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
		if format:sub(start + 1, start + 1) == "%" then
			pattern[#pattern + 1] = "%%"
			at = start + 2
		else
			local first, last, position, kind = format:find("^%%(%d*)%$?([sd])", start)
			if not first then
				return nil
			end
			count = count + 1
			kinds[#kinds + 1] = { kind = kind, argument = tonumber(position) or count }
			pattern[#pattern + 1] = kind == "d" and "(%d[%d%.,]*)" or "(.-)"
			at = last + 1
		end
	end
	if anchored then
		pattern[#pattern + 1] = "$"
	end
	return { pattern = table.concat(pattern), kinds = kinds }
end

local function Entry(key, anchored)
	local cached = compiled[key]
	if cached == nil then
		local format = _G[key]
		cached = type(format) == "string" and Compile(format, anchored) or false
		compiled[key] = cached
	end
	return cached or nil
end

local function Match(entry, text)
	local found = { text:match(entry.pattern) }
	if found[1] == nil then
		return nil
	end
	local out = {}
	for i, spec in ipairs(entry.kinds) do
		out[spec.argument] = spec.kind == "d" and tonumber((found[i]:gsub("%D", ""))) or found[i]
	end
	return out
end

local function Plain(text)
	if type(text) ~= "string" then
		return false
	end
	return not (issecretvalue and issecretvalue(text) == true)
end

function LootText.Item(text)
	if not Plain(text) then
		return nil
	end
	for _, key in ipairs(ITEM_KEYS) do
		local entry = Entry(key, true)
		local args = entry and Match(entry, text)
		if args and type(args[1]) == "string" then
			local id = tonumber(args[1]:match("|Hitem:(%d+)"))
			if id then
				return id, args[1]:match("%[(.-)%]") or "", args[2] or 1
			end
		end
	end
	return nil
end

function LootText.Money(text)
	if not Plain(text) then
		return nil
	end
	for _, key in ipairs(MONEY_KEYS) do
		local entry = Entry(key, true)
		local args = entry and Match(entry, text)
		if args and type(args[1]) == "string" then
			local rest, amounts = args[1], {}
			for i, amountKey in ipairs(AMOUNT_KEYS) do
				local amount = Entry(amountKey, false)
				if not amount then
					return nil
				end
				local found = Match(amount, rest)
				amounts[i] = found and found[1] or 0
				rest = rest:gsub(amount.pattern, "", 1)
			end
			local total = amounts[1] * COPPER_PER_SILVER * SILVER_PER_GOLD + amounts[2] * COPPER_PER_SILVER + amounts[3]
			if total > 0 and not rest:find("[^%s%p]") then
				return total
			end
		end
	end
	return nil
end

function LootText.Reset()
	compiled = {}
end
