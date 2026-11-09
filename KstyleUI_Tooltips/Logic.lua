-- Logic.lua: the module's pure rules: the fixed anchor's corner, font flags, quality edges, softened line colours, an item's stat and footer lines, its title and caption text and the tooltip scale.
local _, ns = ...

local Logic = {}
ns.Logic = Logic

local abs, floor = math.abs, math.floor
local format = string.format

local UNCOMMON = 2
local COLOR_TOLERANCE = 0.02
local FLAGS = { OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local STAT = "^%+%d"
local FOOTER_GLOBALS = { "DURABILITY_TEMPLATE", "ITEM_MIN_LEVEL" }
local FOOTER_DEFAULTS = { "Durability %d / %d", "Requires Level %d" }
local LEVEL_GLOBAL, LEVEL_DEFAULT = "ITEM_LEVEL", "Item Level %d"
local THIN_SPACE = "\226\128\137"
local MIDDLE_DOT = " \194\183 "
local RESERVED = "\n "
local LEVEL_FORMAT = "Item level %d"

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function IsNumber(v)
	return not IsSecret(v) and type(v) == "number" and v == v
end
Logic.IsNumber = IsNumber
Logic.IsSecret = IsSecret

function Logic.Corner(left, bottom, width, height, rootWidth, rootHeight)
	if not (IsNumber(left) and IsNumber(bottom) and IsNumber(width) and IsNumber(height) and IsNumber(rootWidth) and IsNumber(rootHeight)) then
		return "BOTTOMRIGHT"
	end
	if rootWidth <= 0 or rootHeight <= 0 then
		return "BOTTOMRIGHT"
	end
	local vertical = (bottom + height / 2) > rootHeight / 2 and "TOP" or "BOTTOM"
	local horizontal = (left + width / 2) < rootWidth / 2 and "LEFT" or "RIGHT"
	return vertical .. horizontal
end

function Logic.Flags(outline)
	return FLAGS[outline] or ""
end

function Logic.EdgeQuality(quality)
	return IsNumber(quality) and quality >= UNCOMMON
end

function Logic.Soften(r, g, b, palette)
	if type(palette) ~= "table" or not (IsNumber(r) and IsNumber(g) and IsNumber(b)) then
		return nil
	end
	for _, soft in ipairs(palette) do
		if abs(r - soft[1]) < COLOR_TOLERANCE and abs(g - soft[2]) < COLOR_TOLERANCE and abs(b - soft[3]) < COLOR_TOLERANCE then
			return soft[4]
		end
	end
	return nil
end

local function Pattern(template)
	local escaped = template:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. (escaped:gsub("%%%%d", "%%d+"))
end

local footerPatterns

local function FooterPatterns()
	if not footerPatterns then
		footerPatterns = {}
		for i, name in ipairs(FOOTER_GLOBALS) do
			local template = rawget(_G, name)
			footerPatterns[i] = Pattern(type(template) == "string" and template or FOOTER_DEFAULTS[i])
		end
	end
	return footerPatterns
end

local levelPattern

function Logic.IsLevelLine(text)
	if IsSecret(text) or type(text) ~= "string" then
		return false
	end
	if not levelPattern then
		local template = rawget(_G, LEVEL_GLOBAL)
		levelPattern = Pattern(type(template) == "string" and template or LEVEL_DEFAULT)
	end
	return text:find(levelPattern) ~= nil
end

function Logic.IsStat(text)
	return not IsSecret(text) and type(text) == "string" and text:find(STAT) ~= nil
end

function Logic.IsFooter(text)
	if IsSecret(text) or type(text) ~= "string" then
		return false
	end
	for _, pattern in ipairs(FooterPatterns()) do
		if text:find(pattern) then
			return true
		end
	end
	return false
end

function Logic.Sections(lines, count)
	local stats, footer
	for i = 2, count or #lines do
		local text = lines[i]
		if not stats and Logic.IsStat(text) then
			stats = i
		end
		if not footer and Logic.IsFooter(text) then
			footer = i
		end
	end
	return stats, footer
end

function Logic.TooltipScale(rootScale, parentScale, elementScale)
	local element = IsNumber(elementScale) and elementScale > 0 and elementScale or 1
	if not (IsNumber(rootScale) and IsNumber(parentScale)) or rootScale <= 0 or parentScale <= 0 then
		return element
	end
	return rootScale / parentScale * element
end

function Logic.GuildText(guild, rank)
	if type(rank) == "string" and rank ~= "" then
		return format("<%s> %s", guild, rank)
	end
	return format("<%s>", guild)
end

function Logic.TitleText(text, reserve)
	if IsSecret(text) or type(text) ~= "string" or text == "" or text:find("|", 1, true) then
		return nil
	end
	local plain = text:gsub(RESERVED .. "$", "")
	plain = plain:gsub(THIN_SPACE, "")
	return reserve and plain .. RESERVED or plain
end

function Logic.Caption(level, rarity)
	if type(rarity) ~= "string" or rarity == "" then
		return nil
	end
	if IsNumber(level) and level > 0 then
		return format(LEVEL_FORMAT, floor(level)) .. MIDDLE_DOT .. rarity
	end
	return rarity
end

function Logic.IDText(id)
	if not IsNumber(id) or id ~= floor(id) then
		return nil
	end
	return format("%d", id)
end
