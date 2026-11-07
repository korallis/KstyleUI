-- Format.lua: the texts the data bars and the data strip show: grouped and short numbers, percentages, money and clock times.
local _, ns = ...

local L = ns.L
local floor, abs, format = math.floor, math.abs, string.format

local Format = {}
ns.Format = Format

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000
local HOURS_HALF_DAY = 12
local SHORT_STEPS = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local SHORT_DECIMAL_BELOW = 100

Format.BAR_TEXTS = {
	{ value = "none", label = L["No text"] },
	{ value = "percent", label = L["Percent"] },
	{ value = "value", label = L["Value"] },
	{ value = "valuePercent", label = L["Value and percent"] },
	{ value = "short", label = L["Short value"] },
	{ value = "remaining", label = L["Remaining"] },
	{ value = "label", label = L["Name"] },
	{ value = "labelPercent", label = L["Name and percent"] },
	{ value = "labelValue", label = L["Name and value"] },
	{ value = "shortPercent", label = L["Short name and percent"] },
}

local function Whole(n)
	if n < 0 then
		return -floor(-n)
	end
	return floor(n)
end

local function Group(n)
	local digits = tostring(n)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

function Format.Number(n)
	n = Whole(n)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, n)
		if ok and type(text) == "string" then
			return text
		end
	end
	if n < 0 then
		return "-" .. Group(-n)
	end
	return Group(n)
end

function Format.Short(n)
	local size = abs(n)
	for _, step in ipairs(SHORT_STEPS) do
		if size >= step[1] then
			local scaled = size / step[1]
			local text
			if scaled < SHORT_DECIMAL_BELOW then
				text = format("%.1f", floor(scaled * 10) / 10):gsub("%.0$", "")
			else
				text = tostring(floor(scaled))
			end
			return (n < 0 and "-" or "") .. text .. step[2]
		end
	end
	return tostring(Whole(n))
end

function Format.Percent(current, max)
	if max <= 0 then
		return 0
	end
	local percent = floor(current / max * 100)
	if percent < 0 then
		return 0
	elseif percent > 100 then
		return 100
	end
	return percent
end

local function Value(current, max)
	return Format.Number(current) .. " / " .. Format.Number(max)
end

local function Joined(label, text)
	if label and label ~= "" then
		return label .. " " .. text
	end
	return text
end

local BAR_TEXT = {
	percent = function(current, max)
		return Format.Percent(current, max) .. "%"
	end,
	value = Value,
	valuePercent = function(current, max)
		return Value(current, max) .. " (" .. Format.Percent(current, max) .. "%)"
	end,
	short = function(current, max)
		return Format.Short(current) .. " / " .. Format.Short(max)
	end,
	remaining = function(current, max)
		return format(L["%s to go"], Format.Number(max - current))
	end,
	label = function(_, _, label)
		return label
	end,
	labelPercent = function(current, max, label)
		return Joined(label, Format.Percent(current, max) .. "%")
	end,
	labelValue = function(current, max, label)
		return Joined(label, Value(current, max))
	end,
	shortPercent = function(current, max, label, short)
		return Joined(short or label, Format.Percent(current, max) .. "%")
	end,
}

function Format.BarText(style, current, max, label, short)
	local fn = BAR_TEXT[style]
	if not fn then
		return nil
	end
	return fn(current, max, label, short)
end

local function Coins(copper)
	local gold = floor(copper / COPPER_PER_GOLD)
	local silver = floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local rest = copper % COPPER_PER_SILVER
	return gold, silver, rest
end

local function FullMoney(copper)
	local gold, silver, rest = Coins(copper)
	if gold > 0 then
		return format(L["%sg"], Format.Number(gold)) .. " " .. format(L["%ss"], silver) .. " " .. format(L["%sc"], rest)
	elseif silver > 0 then
		return format(L["%ss"], silver) .. " " .. format(L["%sc"], rest)
	end
	return format(L["%sc"], rest)
end

function Format.Money(copper, style)
	copper = Whole(copper)
	if copper < 0 then
		return "-" .. Format.Money(-copper, style)
	end
	if style == "icons" and type(C_CurrencyInfo) == "table" and type(C_CurrencyInfo.GetCoinTextureString) == "function" then
		local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
		if ok and type(text) == "string" then
			return text
		end
	end
	if style == "gold" and copper >= COPPER_PER_GOLD then
		return format(L["%sg"], Format.Number(floor(copper / COPPER_PER_GOLD)))
	end
	return FullMoney(copper)
end

function Format.Clock(hour, minute, use24)
	if use24 then
		return format("%02d:%02d", hour, minute)
	end
	local shown = hour % HOURS_HALF_DAY
	if shown == 0 then
		shown = HOURS_HALF_DAY
	end
	return format("%d:%02d %s", shown, minute, hour < HOURS_HALF_DAY and L["AM"] or L["PM"])
end
